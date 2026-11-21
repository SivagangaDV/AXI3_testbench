class axi_master_drv extends uvm_driver #(axi_seq_item);

  `uvm_component_utils(axi_master_drv)

  virtual axi_interface   vif;
  axi_driver_config       drv_cfg;

  // Transaction staging queues from sequencer
  axi_seq_item aw_q[$];
  axi_seq_item ar_q[$];

  // In-flight tracking pools
  axi_seq_item active_w_pool[$];
  axi_seq_item active_b_pool[bit [ID_WIDTH-1:0]][$];
  axi_seq_item active_r_pool[bit [ID_WIDTH-1:0]][$];

  // Interleaving tracking
  bit [ID_WIDTH-1:0] locked_interleave_wid;
  bit                wid_lock_active = 1'b0;

  function new(string name = "axi_master_drv", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual axi_interface)::get(this, "", "vif", vif)) begin
      `uvm_fatal("NO_VIF", "Virtual interface 'vif' not found in uvm_config_db")
    end
    if (!uvm_config_db#(axi_driver_config)::get(this, "", "master_driver_config", drv_cfg)) begin
      drv_cfg = axi_driver_config::type_id::create("drv_cfg");
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // Main Execution Phase (Synchronized with Initial & Mid-Burst Reset)
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    forever begin
      reset_signals();
      flush_queues();

      // Step 1: Wait for reset to be asserted active-low (0) first,
      // handling cases where ARESETn starts high at 0ns
      if (vif.ARESETn !== 1'b0) begin
        wait (vif.ARESETn === 1'b0);
      end

      // Step 2: Wait until reset is cleanly deasserted to 1'b1
      wait (vif.ARESETn === 1'b1);
      @(posedge vif.ACLK);

      `uvm_info("MST_DRV/RESET_DONE", "Reset released. Master driver threads active.", UVM_MEDIUM)

      // Step 3: Run worker threads in parallel with an active-low reset watchdog
      fork
        begin : RUN_THREADS
          fork
            item_fetch_loop();
            drive_aw_channel();
            drive_w_channel();
            drive_b_channel();
            drive_ar_channel();
            drive_r_channel();
          join
        end

        begin : RESET_WATCHDOG
          // Trigger the exact moment ARESETn goes low mid-burst
          @(negedge vif.ARESETn);
          `uvm_info("MST_DRV/RESET_ASSERT", "ARESETn dropped to 0! Aborting in-flight driver loops.", UVM_MEDIUM)
        end
      join_any

      // Step 4: Immediately kill all active driving threads
      disable fork;

      // Drop all valid outputs to idle per AXI spec
      reset_signals();
      flush_queues();
    end
  endtask : run_phase

  virtual function void flush_queues();
    aw_q.delete();
    ar_q.delete();
    active_w_pool.delete();
    active_b_pool.delete();
    active_r_pool.delete();
    wid_lock_active = 1'b0;
  endfunction : flush_queues

  // ---------------------------------------------------------------------------
  // 0. Item Fetcher
  // ---------------------------------------------------------------------------
  virtual task item_fetch_loop();
    axi_seq_item item_clone;
    forever begin
      seq_item_port.get_next_item(req);
      $cast(item_clone, req.clone());
      item_clone.set_id_info(req);
      item_clone.orig_item = req;

      if (item_clone.trans_type == AXI_WRITE) begin
        aw_q.push_back(item_clone);
      end else begin
        ar_q.push_back(item_clone);
      end

      seq_item_port.item_done();
    end
  endtask : item_fetch_loop

  // ---------------------------------------------------------------------------
  // 1. Write Address Channel (AW)
  // ---------------------------------------------------------------------------
  virtual task drive_aw_channel();
    axi_seq_item item;
    bit [3:0]    effective_awlen;

    forever begin
      wait(aw_q.size() > 0);

      if (!drv_cfg.enable_aw_overlap) begin
        wait(active_w_pool.size() == 0);
      end else begin
        wait(active_w_pool.size() < drv_cfg.max_inflight_aw);
      end

      item = aw_q.pop_front();

      if (drv_cfg.inject_illegal_awburst == 1'b1) begin
        item.burst = BURST_RSVD;
        drv_cfg.inject_illegal_awburst = (drv_cfg.inject_Error_only_once == 1'b1) ? 1'b0 : 1'b1;
      end

      if (drv_cfg.inject_AW_wrap_burst_len && (item.burst == BURST_WRAP)) begin
        effective_awlen = item.len ^ 4'h1;
        drv_cfg.inject_AW_wrap_burst_len = (drv_cfg.inject_Error_only_once == 1'b1) ? 1'b0 : 1'b1;
      end else begin
        effective_awlen = item.len;
      end
      item.len = effective_awlen;

      @(posedge vif.ACLK);
      vif.AWID    <= item.id;
      vif.AWADDR  <= (drv_cfg.inject_misaligned_wrap_addr && (item.burst == BURST_WRAP)) ?
                     (item.addr | 16'h0001) : item.addr;
      vif.AWLEN   <= effective_awlen;
      vif.AWSIZE  <= item.size;
      vif.AWBURST <= item.burst;
      vif.AWLOCK  <= item.lock;
      vif.AWCACHE <= item.cache;
      vif.AWPROT  <= item.prot;
      vif.AWVALID <= 1'b1;

      do begin
        @(posedge vif.ACLK);
      end while (!vif.AWREADY && vif.ARESETn === 1'b1);

      vif.AWVALID <= 1'b0;

      if (vif.ARESETn === 1'b1) begin
        active_w_pool.push_back(item);
        active_b_pool[item.id].push_back(item);
      end
    end
  endtask : drive_aw_channel

  // ---------------------------------------------------------------------------
  // 2. Write Data Channel (W)
  // ---------------------------------------------------------------------------
  virtual task drive_w_channel();
    int pick_idx;
    axi_seq_item item;
    bit wlast_val;
    int candidate_indices[$];

    forever begin
      wait(active_w_pool.size() > 0);

      if (!drv_cfg.enable_write_interleaving) begin
        pick_idx = 0;
        item     = active_w_pool[pick_idx];
      end else begin
        candidate_indices.delete();
        foreach (active_w_pool[i]) begin
          if (!wid_lock_active || (active_w_pool[i].id != locked_interleave_wid) || (active_w_pool[i].current_beat > 0)) begin
            candidate_indices.push_back(i);
          end
        end

        if (candidate_indices.size() == 0) candidate_indices.push_back(0);
        pick_idx = candidate_indices[$urandom_range(candidate_indices.size() - 1, 0)];
        item     = active_w_pool[pick_idx];

        locked_interleave_wid = item.id;
        wid_lock_active       = 1'b1;
      end

      if (drv_cfg.wvalid_beat_delay_clk > 0) begin
        vif.WVALID <= 1'b0;
        vif.WLAST  <= 1'b0;
        repeat (drv_cfg.wvalid_beat_delay_clk) @(posedge vif.ACLK);
      end

      if (drv_cfg.inject_corrupt_wlast) begin
        wlast_val = (item.current_beat == drv_cfg.inject_corrupt_wlast_beat);
      end else begin
        wlast_val = (item.current_beat == item.len);
      end

      @(posedge vif.ACLK);
      vif.WID    <= item.id;
      vif.WDATA  <= (item.current_beat < item.wdata.size()) ? item.wdata[item.current_beat] : '0;
      vif.WSTRB  <= drv_cfg.inject_corrupt_wstrb_zero ? '0 : 
                    ((item.current_beat < item.wstrb.size()) ? item.wstrb[item.current_beat] : '1);
      vif.WLAST  <= wlast_val;
      vif.WVALID <= 1'b1;

      do begin
        @(posedge vif.ACLK);
      end while (!vif.WREADY && vif.ARESETn === 1'b1);

      vif.WVALID <= 1'b0;
      vif.WLAST  <= 1'b0;

      item.current_beat++;

      if (item.current_beat > item.len || (drv_cfg.inject_corrupt_wlast && wlast_val)) begin
        if (pick_idx < active_w_pool.size()) begin
          active_w_pool.delete(pick_idx);
        end
        wid_lock_active = 1'b0;
      end
    end
  endtask : drive_w_channel

  // ---------------------------------------------------------------------------
  // 3. Write Response Channel (B)
  // ---------------------------------------------------------------------------
  virtual task drive_b_channel();
    int b_delay;
    axi_seq_item item;
    bit [ID_WIDTH-1:0] resp_id;

    forever begin
      b_delay = drv_cfg.bready_rand_delay_enable ?
                $urandom_range(drv_cfg.bready_max_rand_delay, 1) :
                drv_cfg.bready_delay_clk;

      if (b_delay > 0) begin
        vif.BREADY <= 1'b0;
        repeat (b_delay) @(posedge vif.ACLK);
      end

      vif.BREADY <= 1'b1;

      do begin
        @(posedge vif.ACLK);
      end while (!vif.BVALID && vif.ARESETn === 1'b1);

      if (vif.ARESETn !== 1'b1) continue;

      resp_id = vif.BID;

      if (active_b_pool.exists(resp_id) && active_b_pool[resp_id].size() > 0) begin
        item       = active_b_pool[resp_id].pop_front();
        item.bid   = resp_id;
        item.bresp = axi_resp_e'(vif.BRESP);

        if (active_b_pool[resp_id].size() == 0) begin
          active_b_pool.delete(resp_id);
        end

        item.is_completed = 1'b1;
        ->item.done_event;

        if (item.orig_item != null) begin
          item.orig_item.bid          = item.bid;
          item.orig_item.bresp        = item.bresp;
          item.orig_item.is_completed = 1'b1;
          ->item.orig_item.done_event;
        end
      end else if (vif.ARESETn === 1'b1) begin
        `uvm_error("DRV_UNEXP_B", $sformatf("Received unexpected BID: 0x%0h with no pending write", resp_id))
      end

      if (b_delay > 0) begin
        vif.BREADY <= 1'b0;
      end
    end
  endtask : drive_b_channel

  // ---------------------------------------------------------------------------
  // 4. Read Address Channel (AR)
  // ---------------------------------------------------------------------------
  virtual task drive_ar_channel();
    axi_seq_item item;
    int inflight_r_count;
    bit [3:0] effective_arlen;

    forever begin
      wait(ar_q.size() > 0);

      forever begin
        inflight_r_count = 0;
        foreach (active_r_pool[id]) inflight_r_count += active_r_pool[id].size();

        if (!drv_cfg.enable_ar_overlap && inflight_r_count >= 1) begin
          @(posedge vif.ACLK);
        end else if (drv_cfg.enable_ar_overlap && inflight_r_count >= drv_cfg.max_inflight_ar) begin
          @(posedge vif.ACLK);
        end else begin
          break;
        end
      end

      item = ar_q.pop_front();

      if (drv_cfg.inject_illegal_arburst == 1'b1) begin
        item.burst = BURST_RSVD;
        drv_cfg.inject_illegal_arburst = (drv_cfg.inject_Error_only_once == 1'b1) ? 1'b0 : 1'b1;
      end

      if (drv_cfg.inject_AR_wrap_burst_len && (item.burst == BURST_WRAP)) begin
        effective_arlen = item.len ^ 4'h1;
        drv_cfg.inject_AR_wrap_burst_len = (drv_cfg.inject_Error_only_once == 1'b1) ? 1'b0 : 1'b1;
      end else begin
        effective_arlen = item.len;
      end
      item.len = effective_arlen;

      item.rid          = new[item.len + 1];
      item.rdata        = new[item.len + 1];
      item.rresp        = new[item.len + 1];
      item.current_beat = 0;

      @(posedge vif.ACLK);
      vif.ARID    <= item.id;
      vif.ARADDR  <= (drv_cfg.inject_misaligned_wrap_addr && (item.burst == BURST_WRAP)) ?
                     (item.addr | 16'h0001) : 
                     (drv_cfg.inject_4k_crossing_ar ? 16'h0FF0 : item.addr);
      vif.ARLEN   <= effective_arlen;
      vif.ARSIZE  <= item.size;
      vif.ARBURST <= item.burst;
      vif.ARLOCK  <= item.lock;
      vif.ARCACHE <= item.cache;
      vif.ARPROT  <= item.prot;
      vif.ARVALID <= 1'b1;

      do begin
        @(posedge vif.ACLK);
      end while (!vif.ARREADY && vif.ARESETn === 1'b1);

      vif.ARVALID <= 1'b0;

      if (vif.ARESETn === 1'b1) begin
        active_r_pool[item.id].push_back(item);
      end
    end
  endtask : drive_ar_channel

  // ---------------------------------------------------------------------------
  // 5. Read Data Channel (R)
  // ---------------------------------------------------------------------------
  virtual task drive_r_channel();
    int r_delay;
    axi_seq_item item;
    bit [ID_WIDTH-1:0] read_id;

    forever begin
      r_delay = drv_cfg.rready_rand_delay_enable ?
                $urandom_range(drv_cfg.rready_max_rand_delay, 1) :
                drv_cfg.rready_delay_clk;

      if (r_delay > 0) begin
        vif.RREADY <= 1'b0;
        repeat (r_delay) @(posedge vif.ACLK);
      end

      vif.RREADY <= 1'b1;

      do begin
        @(posedge vif.ACLK);
      end while (!vif.RVALID && vif.ARESETn === 1'b1);

      if (vif.ARESETn !== 1'b1) continue;

      read_id = vif.RID;

      if (active_r_pool.exists(read_id) && active_r_pool[read_id].size() > 0) begin
        item = active_r_pool[read_id][0];

        if (item.current_beat >= item.rdata.size()) begin
          item.rid   = new[item.current_beat + 1](item.rid);
          item.rdata = new[item.current_beat + 1](item.rdata);
          item.rresp = new[item.current_beat + 1](item.rresp);
        end

        item.rid[item.current_beat]   = read_id;
        item.rdata[item.current_beat] = vif.RDATA;
        item.rresp[item.current_beat] = axi_resp_e'(vif.RRESP);
        item.current_beat++;

        if (vif.RLAST || (item.current_beat > item.len)) begin
          void'(active_r_pool[read_id].pop_front());
          if (active_r_pool[read_id].size() == 0) begin
            active_r_pool.delete(read_id);
          end

          item.is_completed = 1'b1;
          ->item.done_event;

          if (item.orig_item != null) begin
            item.orig_item.rid          = item.rid;
            item.orig_item.rdata        = item.rdata;
            item.orig_item.rresp        = item.rresp;
            item.orig_item.is_completed = 1'b1;
            ->item.orig_item.done_event;
          end
        end
      end else if (vif.ARESETn === 1'b1) begin
        `uvm_error("DRV_UNEXP_R", $sformatf("Received unexpected or orphan RID: 0x%0h on R channel", read_id))
      end

      if (r_delay > 0) begin
        vif.RREADY <= 1'b0;
      end
    end
  endtask : drive_r_channel

  // ---------------------------------------------------------------------------
  // 6. Reset Helper
  // ---------------------------------------------------------------------------
  virtual task reset_signals();
    vif.AWID    <= '0;
    vif.AWADDR  <= '0;
    vif.AWLEN   <= '0;
    vif.AWSIZE  <= '0;
    vif.AWBURST <= '0;
    vif.AWLOCK  <= '0;
    vif.AWCACHE <= '0;
    vif.AWPROT  <= '0;
    vif.AWVALID <= 1'b0;

    vif.WID     <= '0;
    vif.WDATA   <= '0;
    vif.WSTRB   <= '0;
    vif.WLAST   <= 1'b0;
    vif.WVALID  <= 1'b0;

    vif.BREADY  <= 1'b0;

    vif.ARID    <= '0;
    vif.ARADDR  <= '0;
    vif.ARLEN   <= '0;
    vif.ARSIZE  <= '0;
    vif.ARBURST <= '0;
    vif.ARLOCK  <= '0;
    vif.ARCACHE <= '0;
    vif.ARPROT  <= '0;
    vif.ARVALID <= 1'b0;

    vif.RREADY  <= 1'b0;
  endtask : reset_signals

endclass : axi_master_drv