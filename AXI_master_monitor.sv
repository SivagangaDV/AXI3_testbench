class axi_master_mon extends uvm_monitor;

  // ---------------------------------------------------------------------------
  // Interface, Configuration Handle & Analysis Port
  // ---------------------------------------------------------------------------
  virtual axi_interface                  vif;
  axi_monitor_config                     mon_cfg;
  uvm_analysis_port #(axi_seq_item)      mon_ap;

  // ---------------------------------------------------------------------------
  // Master-Side Tracking Structures
  // ---------------------------------------------------------------------------
  axi_seq_item aw_pending_pool[bit [ID_WIDTH-1:0]][$]; // AW completed, awaiting WDATA
  axi_seq_item w_unpaired_pool[bit [ID_WIDTH-1:0]][$]; // WDATA arrived before AW phase
  axi_seq_item w_active_pool[bit [ID_WIDTH-1:0]][$];   // AW completed, W burst in progress
  axi_seq_item b_pending_pool[bit [ID_WIDTH-1:0]][$];  // W completed, awaiting B response
  axi_seq_item r_active_pool[bit [ID_WIDTH-1:0]][$];   // AR completed, R burst in progress

  // In-flight Master issue queues for tracking return ordering per ID (AXI3 §A5.2)
  bit [ID_WIDTH-1:0] write_id_order_q[$];
  bit [ID_WIDTH-1:0] read_id_order_q[$];

  `uvm_component_utils(axi_master_mon)

  function new(string name = "axi_master_mon", uvm_component parent = null);
    super.new(name, parent);
    mon_ap = new("mon_ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi_interface)::get(this, "", "vif", vif)) begin
      `uvm_fatal("MST_MON/NO_VIF", "[AXI_MASTER_MON] Virtual interface 'vif' not found in uvm_config_db")
    end

    if (!uvm_config_db#(axi_monitor_config)::get(this, "", "master_mon_cfg", mon_cfg)) begin
      `uvm_info("MST_MON/NO_CFG", "[AXI_MASTER_MON] axi_monitor_config not found in config_db; using defaults", UVM_MEDIUM)
      mon_cfg = axi_monitor_config::type_id::create("mon_cfg");
    end
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // Robust Run Phase with Mid-Reset Interruption & Thread Killing
  // ---------------------------------------------------------------------------
  virtual task run_phase(uvm_phase phase);
    forever begin
      // 1. Wait for reset assertion (if not already asserted)
      if (vif.ARESETn !== 1'b0) begin
        @(negedge vif.ARESETn);
      end

      // 2. Reset detected: purge all stale state immediately
      reset_internal_pools();
      `uvm_info("MST_MON/RESET_ASSERTED", "[AXI_MASTER_MON] Reset asserted. Internal tracking pools cleared.", UVM_MEDIUM)

      // 3. Wait for reset de-assertion
      @(posedge vif.ARESETn);
      @(posedge vif.ACLK);

      `uvm_info("MST_MON/START", "[AXI_MASTER_MON] Reset de-asserted. Master bus monitor active.", UVM_MEDIUM)

      // 4. Fork monitoring tasks and a reset watcher thread to kill tasks on mid-reset
      fork
        begin
          fork
            sample_aw_channel();
            sample_w_channel();
            sample_b_channel();
            sample_ar_channel();
            sample_r_channel();
            check_handshake_stability();
          join
        end
        // Reset watcher: if ARESETn drops mid-flight, exit the fork immediately
        begin
          @(negedge vif.ARESETn);
          `uvm_info("MST_MON/RESET_MID_TEST", "[AXI_MASTER_MON] Mid-test reset detected! Aborting active monitoring loops.", UVM_MEDIUM)
        end
      join_any
      disable fork;
    end
  endtask : run_phase

  virtual function void reset_internal_pools();
    aw_pending_pool.delete();
    w_unpaired_pool.delete();
    w_active_pool.delete();
    b_pending_pool.delete();
    r_active_pool.delete();
    write_id_order_q.delete();
    read_id_order_q.delete();
  endfunction : reset_internal_pools

  // ---------------------------------------------------------------------------
  // 1. Write Address Channel (AW) - Master Request Sent
  // ---------------------------------------------------------------------------
  virtual task sample_aw_channel();
    axi_seq_item tr;

    forever @(posedge vif.ACLK) begin
      if (vif.ARESETn && vif.AWVALID && vif.AWREADY) begin
        tr             = axi_seq_item::type_id::create("mst_aw_tr");
        tr.trans_type  = AXI_WRITE;
        tr.id          = vif.AWID;
        tr.addr        = vif.AWADDR;
        tr.len         = vif.AWLEN;
        tr.size        = vif.AWSIZE;
        tr.burst       = axi_burst_e'(vif.AWBURST);
        tr.lock        = vif.AWLOCK;
        tr.cache       = vif.AWCACHE;
        tr.prot        = vif.AWPROT;
        tr.wdata       = new[tr.len + 1];
        tr.wstrb       = new[tr.len + 1];
        tr.current_beat = 0;

        `uvm_info("MST_MON/AW_ISSUED", $sformatf("[AXI_MASTER_MON] AW accepted: AWID=0x%0h Addr=0x%08h Len=%0d Size=%0d Burst=%0s",
                  tr.id, tr.addr, tr.len, tr.size, tr.burst.name()), UVM_HIGH)

        if (mon_cfg.enable_protocol_checks) begin
          check_aw_protocol(tr);
        end

        // Check if write data arrived prior to AW handshake (Legal in AXI3)
        if (w_unpaired_pool.exists(tr.id) && w_unpaired_pool[tr.id].size() > 0) begin
          axi_seq_item early_tr = w_unpaired_pool[tr.id].pop_front();
          tr.wdata        = early_tr.wdata;
          tr.wstrb        = early_tr.wstrb;
          tr.current_beat = early_tr.current_beat;

          if (tr.current_beat > tr.len || (tr.current_beat == (tr.len + 1))) begin
            b_pending_pool[tr.id].push_back(tr);
          end else begin
            w_active_pool[tr.id].push_back(tr);
          end
        end else begin
          aw_pending_pool[tr.id].push_back(tr);
        end

        write_id_order_q.push_back(tr.id);
      end
    end
  endtask : sample_aw_channel

  // ---------------------------------------------------------------------------
  // 2. Write Data Channel (W) - Master Data Transmitted
  // ---------------------------------------------------------------------------
  virtual task sample_w_channel();
    bit [ID_WIDTH-1:0] wid;
    axi_seq_item       tr;

    forever @(posedge vif.ACLK) begin
      if (vif.ARESETn && vif.WVALID && vif.WREADY) begin
        wid = vif.WID;

        if (w_active_pool.exists(wid) && w_active_pool[wid].size() > 0) begin
          tr = w_active_pool[wid][0];
        end else if (aw_pending_pool.exists(wid) && aw_pending_pool[wid].size() > 0) begin
          tr = aw_pending_pool[wid].pop_front();
          w_active_pool[wid].push_back(tr);
        end else begin
          // W-before-AW resolution
          if (!w_unpaired_pool.exists(wid) || w_unpaired_pool[wid].size() == 0) begin
            tr             = axi_seq_item::type_id::create("w_early_tr");
            tr.trans_type  = AXI_WRITE;
            tr.id          = wid;
            tr.current_beat = 0;
            w_unpaired_pool[wid].push_back(tr);
          end else begin
            tr = w_unpaired_pool[wid][0];
          end
        end

        // Expand dynamic arrays safely if burst size is undetermined (unpaired W)
        if (tr.current_beat >= tr.wdata.size()) begin
          tr.wdata = new[tr.current_beat + 1](tr.wdata);
          tr.wstrb = new[tr.current_beat + 1](tr.wstrb);
        end

        tr.wdata[tr.current_beat] = vif.WDATA;
        tr.wstrb[tr.current_beat] = vif.WSTRB;

        `uvm_info("MST_MON/W_TRANSMITTED", $sformatf("[AXI_MASTER_MON] W beat: WID=0x%0h Beat=%0d WDATA=0x%08h WSTRB=0x%0h WLAST=%0b",
                  wid, tr.current_beat + 1, vif.WDATA, vif.WSTRB, vif.WLAST), UVM_HIGH)

        if (mon_cfg.enable_protocol_checks) begin
          check_w_protocol(tr);
        end

        tr.current_beat++;

        if (vif.WLAST) begin
          if (w_active_pool.exists(wid) && w_active_pool[wid].size() > 0) begin
            void'(w_active_pool[wid].pop_front());
            b_pending_pool[wid].push_back(tr);
          end
        end
      end
    end
  endtask : sample_w_channel

  // ---------------------------------------------------------------------------
  // 3. Write Response Channel (B) - Master Received Response from Slave
  // ---------------------------------------------------------------------------
  virtual task sample_b_channel();
    bit [ID_WIDTH-1:0] bid;
    axi_seq_item       completed_tr;

    forever @(posedge vif.ACLK) begin
      if (vif.ARESETn && vif.BVALID && vif.BREADY) begin
        bid = vif.BID;

        if (!b_pending_pool.exists(bid) || (b_pending_pool[bid].size() == 0)) begin
          if (mon_cfg.enable_protocol_checks && !mon_cfg.mask_unexpected_resp_err) begin
            `uvm_error("MST_MON/UNEXP_B", $sformatf("[AXI_MASTER_MON] Unsolicited B response: BID=0x%0h with no pending write completion!", bid))
          end
        end else begin
          completed_tr       = b_pending_pool[bid].pop_front();
          completed_tr.bid   = bid;
          completed_tr.bresp = axi_resp_e'(vif.BRESP);

          if (completed_tr.bresp inside {RESP_SLVERR, RESP_DECERR}) begin
            if (!mon_cfg.mask_slverr_bresp_err) begin
              `uvm_error("MST_MON/B_RESP_ERR", $sformatf("[AXI_MASTER_MON] Slave error response: BID=0x%0h BRESP=%0s", bid, completed_tr.bresp.name()))
            end else begin
              `uvm_info("MST_MON/B_RECEIVED_ERR_MASKED", $sformatf("[AXI_MASTER_MON] Masked error response: BID=0x%0h BRESP=%0s", bid, completed_tr.bresp.name()), UVM_MEDIUM)
            end
          end else begin
            `uvm_info("MST_MON/B_RECEIVED", $sformatf("[AXI_MASTER_MON] B response accepted: BID=0x%0h BRESP=%0s", bid, completed_tr.bresp.name()), UVM_MEDIUM)
          end

          // Verify strict in-order retirement per ID (AXI3 §A5.2)
          if (mon_cfg.enable_protocol_checks && !mon_cfg.mask_id_order_err) begin
            check_b_order(bid);
          end

          mon_ap.write(completed_tr);
        end
      end
    end
  endtask : sample_b_channel

  // ---------------------------------------------------------------------------
  // 4. Read Address Channel (AR) - Master Request Sent
  // ---------------------------------------------------------------------------
  virtual task sample_ar_channel();
    axi_seq_item tr;

    forever @(posedge vif.ACLK) begin
      if (vif.ARESETn && vif.ARVALID && vif.ARREADY) begin
        tr             = axi_seq_item::type_id::create("mst_ar_tr");
        tr.trans_type  = AXI_READ;
        tr.id          = vif.ARID;
        tr.addr        = vif.ARADDR;
        tr.len         = vif.ARLEN;
        tr.size        = vif.ARSIZE;
        tr.burst       = axi_burst_e'(vif.ARBURST);
        tr.lock        = vif.ARLOCK;
        tr.cache       = vif.ARCACHE;
        tr.prot        = vif.ARPROT;
        tr.rid         = new[tr.len + 1];
        tr.rdata       = new[tr.len + 1];
        tr.rresp       = new[tr.len + 1];
        tr.current_beat = 0;

        `uvm_info("MST_MON/AR_ISSUED", $sformatf("[AXI_MASTER_MON] AR accepted: ARID=0x%0h Addr=0x%08h Len=%0d Size=%0d Burst=%0s",
                  tr.id, tr.addr, tr.len, tr.size, tr.burst.name()), UVM_HIGH)

        if (mon_cfg.enable_protocol_checks) begin
          check_ar_protocol(tr);
        end

        r_active_pool[tr.id].push_back(tr);
        read_id_order_q.push_back(tr.id);
      end
    end
  endtask : sample_ar_channel

  // ---------------------------------------------------------------------------
  // 5. Read Data Channel (R) - Master Received Data Beat from Slave
  // ---------------------------------------------------------------------------
  virtual task sample_r_channel();
    bit [ID_WIDTH-1:0] rid;
    axi_seq_item       tr;

    forever @(posedge vif.ACLK) begin
      if (vif.ARESETn && vif.RVALID && vif.RREADY) begin
        rid = vif.RID;

        if (!r_active_pool.exists(rid) || (r_active_pool[rid].size() == 0)) begin
          if (mon_cfg.enable_protocol_checks && !mon_cfg.mask_unexpected_resp_err) begin
            `uvm_error("MST_MON/UNEXP_R", $sformatf("[AXI_MASTER_MON] Unsolicited R beat: RID=0x%0h with no pending AR request!", rid))
          end
        end else begin
          tr = r_active_pool[rid][0];

          if (tr.current_beat >= tr.rdata.size()) begin
            tr.rid   = new[tr.current_beat + 1](tr.rid);
            tr.rdata = new[tr.current_beat + 1](tr.rdata);
            tr.rresp = new[tr.current_beat + 1](tr.rresp);
          end

          tr.rid[tr.current_beat]   = rid;
          tr.rdata[tr.current_beat] = vif.RDATA;
          tr.rresp[tr.current_beat] = axi_resp_e'(vif.RRESP);

          if (tr.rresp[tr.current_beat] inside {RESP_SLVERR, RESP_DECERR}) begin
            if (!mon_cfg.mask_slverr_rresp_err) begin
              `uvm_error("MST_MON/R_RESP_ERR", $sformatf("[AXI_MASTER_MON] Read error beat: RID=0x%0h Beat=%0d/%0d RRESP=%0s",
                         rid, tr.current_beat + 1, tr.len + 1, tr.rresp[tr.current_beat].name()))
            end else begin
              `uvm_info("MST_MON/R_RECEIVED_ERR_MASKED", $sformatf("[AXI_MASTER_MON] Masked read error beat: RID=0x%0h Beat=%0d/%0d RRESP=%0s",
                        rid, tr.current_beat + 1, tr.len + 1, tr.rresp[tr.current_beat].name()), UVM_MEDIUM)
            end
          end

          if (mon_cfg.enable_protocol_checks) begin
            check_r_protocol(tr);
          end

          tr.current_beat++;

          if (vif.RLAST || (tr.current_beat > tr.len)) begin
            void'(r_active_pool[rid].pop_front());

            `uvm_info("MST_MON/R_COMPLETED", $sformatf("[AXI_MASTER_MON] Read transfer completed: RID=0x%0h TotalBeats=%0d",
                      rid, tr.current_beat), UVM_MEDIUM)

            // Remove from global ID order tracker
            for (int k = 0; k < read_id_order_q.size(); k++) begin
              if (read_id_order_q[k] == rid) begin
                read_id_order_q.delete(k);
                break;
              end
            end

            mon_ap.write(tr);
          end
        end
      end
    end
  endtask : sample_r_channel

  // ---------------------------------------------------------------------------
  // 6. Bus Handshake Stability Checks (AXI §A3.1.2)
  // ---------------------------------------------------------------------------
  virtual task check_handshake_stability();
    bit                 prev_awvalid, prev_awready;
    bit [ID_WIDTH-1:0]  prev_awid;
    bit [ADDR_WIDTH-1:0] prev_awaddr;
    bit [LEN_WIDTH-1:0]  prev_awlen;
    bit [SIZE_WIDTH-1:0] prev_awsize;
    bit [1:0]            prev_awburst, prev_awlock;
    bit [3:0]            prev_awcache;
    bit [2:0]            prev_awprot;

    bit                 prev_wvalid, prev_wready;
    bit [ID_WIDTH-1:0]  prev_wid;
    bit [DATA_WIDTH-1:0] prev_wdata;
    bit [STRB_WIDTH-1:0] prev_wstrb;
    bit                 prev_wlast;

    bit                 prev_arvalid, prev_arready;
    bit [ID_WIDTH-1:0]  prev_arid;
    bit [ADDR_WIDTH-1:0] prev_araddr;
    bit [LEN_WIDTH-1:0]  prev_arlen;
    bit [SIZE_WIDTH-1:0] prev_arsize;
    bit [1:0]            prev_arburst, prev_arlock;
    bit [3:0]            prev_arcache;
    bit [2:0]            prev_arprot;

    bit                 prev_rvalid, prev_rready;
    bit [ID_WIDTH-1:0]  prev_rid;
    bit [DATA_WIDTH-1:0] prev_rdata;
    bit [1:0]            prev_rresp;
    bit                 prev_rlast;

    bit                 prev_bvalid, prev_bready;
    bit [ID_WIDTH-1:0]  prev_bid;
    bit [1:0]            prev_bresp;

    forever @(posedge vif.ACLK) begin
      if (!vif.ARESETn) begin
        prev_awvalid = 1'b0;
        prev_wvalid  = 1'b0;
        prev_arvalid = 1'b0;
        prev_rvalid  = 1'b0;
        prev_bvalid  = 1'b0;
      end else begin
        if (mon_cfg.enable_protocol_checks && !mon_cfg.mask_stability_err) begin
          // AW Stability
          if (prev_awvalid && !prev_awready) begin
            if (!vif.AWVALID) begin
              `uvm_error("MST_MON/STABILITY_AW_DEASSERT", "[AXI_MASTER_MON] AWVALID deasserted before AWREADY handshake!")
            end else if ((vif.AWID !== prev_awid) || (vif.AWADDR !== prev_awaddr) ||
                         (vif.AWLEN !== prev_awlen) || (vif.AWSIZE !== prev_awsize) ||
                         (vif.AWBURST !== prev_awburst) || (vif.AWLOCK !== prev_awlock) ||
                         (vif.AWCACHE !== prev_awcache) || (vif.AWPROT !== prev_awprot)) begin
              `uvm_error("MST_MON/STABILITY_AW", "[AXI_MASTER_MON] AW payload modified while AWVALID high without AWREADY!")
            end
          end

          // W Stability
          if (prev_wvalid && !prev_wready) begin
            if (!vif.WVALID) begin
              `uvm_error("MST_MON/STABILITY_W_DEASSERT", "[AXI_MASTER_MON] WVALID deasserted before WREADY handshake!")
            end else if ((vif.WID !== prev_wid) || (vif.WDATA !== prev_wdata) ||
                         (vif.WSTRB !== prev_wstrb) || (vif.WLAST !== prev_wlast)) begin
              `uvm_error("MST_MON/STABILITY_W", "[AXI_MASTER_MON] W payload modified while WVALID high without WREADY!")
            end
          end

          // AR Stability
          if (prev_arvalid && !prev_arready) begin
            if (!vif.ARVALID) begin
              `uvm_error("MST_MON/STABILITY_AR_DEASSERT", "[AXI_MASTER_MON] ARVALID deasserted before ARREADY handshake!")
            end else if ((vif.ARID !== prev_arid) || (vif.ARADDR !== prev_araddr) ||
                         (vif.ARLEN !== prev_arlen) || (vif.ARSIZE !== prev_arsize) ||
                         (vif.ARBURST !== prev_arburst) || (vif.ARLOCK !== prev_arlock) ||
                         (vif.ARCACHE !== prev_arcache) || (vif.ARPROT !== prev_arprot)) begin
              `uvm_error("MST_MON/STABILITY_AR", "[AXI_MASTER_MON] AR payload modified while ARVALID high without ARREADY!")
            end
          end

          // R Stability (Slave driven)
          if (prev_rvalid && !prev_rready) begin
            if (!vif.RVALID) begin
              `uvm_error("MST_MON/STABILITY_R_DEASSERT", "[AXI_MASTER_MON] RVALID deasserted before RREADY handshake!")
            end else if ((vif.RID !== prev_rid) || (vif.RDATA !== prev_rdata) ||
                         (vif.RRESP !== prev_rresp) || (vif.RLAST !== prev_rlast)) begin
              `uvm_error("MST_MON/STABILITY_R", "[AXI_MASTER_MON] R payload modified while RVALID high without RREADY!")
            end
          end

          // B Stability (Slave driven)
          if (prev_bvalid && !prev_bready) begin
            if (!vif.BVALID) begin
              `uvm_error("MST_MON/STABILITY_B_DEASSERT", "[AXI_MASTER_MON] BVALID deasserted before BREADY handshake!")
            end else if ((vif.BID !== prev_bid) || (vif.BRESP !== prev_bresp)) begin
              `uvm_error("MST_MON/STABILITY_B", "[AXI_MASTER_MON] B payload modified while BVALID high without BREADY!")
            end
          end
        end

        // Sample current states
        prev_awvalid = vif.AWVALID; prev_awready = vif.AWREADY; prev_awid    = vif.AWID;
        prev_awaddr  = vif.AWADDR;  prev_awlen   = vif.AWLEN;   prev_awsize  = vif.AWSIZE;
        prev_awburst = vif.AWBURST; prev_awlock  = vif.AWLOCK;  prev_awcache = vif.AWCACHE;
        prev_awprot  = vif.AWPROT;

        prev_wvalid  = vif.WVALID;  prev_wready  = vif.WREADY;  prev_wid     = vif.WID;
        prev_wdata   = vif.WDATA;   prev_wstrb   = vif.WSTRB;   prev_wlast   = vif.WLAST;

        prev_arvalid = vif.ARVALID; prev_arready = vif.ARREADY; prev_arid    = vif.ARID;
        prev_araddr  = vif.ARADDR;  prev_arlen   = vif.ARLEN;   prev_arsize  = vif.ARSIZE;
        prev_arburst = vif.ARBURST; prev_arlock  = vif.ARLOCK;  prev_arcache = vif.ARCACHE;
        prev_arprot  = vif.ARPROT;

        prev_rvalid  = vif.RVALID;  prev_rready  = vif.RREADY;  prev_rid     = vif.RID;
        prev_rdata   = vif.RDATA;   prev_rresp   = vif.RRESP;   prev_rlast   = vif.RLAST;

        prev_bvalid  = vif.BVALID;  prev_bready  = vif.BREADY;  prev_bid     = vif.BID;
        prev_bresp   = vif.BRESP;
      end
    end
  endtask : check_handshake_stability

  // ---------------------------------------------------------------------------
  // Protocol Checking Helper Routines
  // ---------------------------------------------------------------------------
  virtual function void check_aw_protocol(axi_seq_item tr);
    if (vif.AWBURST == 2'b11 && !mon_cfg.mask_illegal_burst_err) begin
      `uvm_error("MST_MON/PROT_AWBURST", $sformatf("[AXI_MASTER_MON] AW reserved burst 2'b11! AWID=0x%0h", tr.id))
    end

    if ((((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 13'h1000) && !mon_cfg.mask_4k_boundary_err) begin
      `uvm_error("MST_MON/PROT_4K_AW", $sformatf("[AXI_MASTER_MON] AW burst crosses 4KB boundary! AWID=0x%0h Addr=0x%08h Len=%0d Size=%0d",
                 tr.id, tr.addr, tr.len, tr.size))
    end

    if (tr.burst == BURST_WRAP && !mon_cfg.mask_wrap_rules_err) begin
      if (!(tr.len inside {4'd1, 4'd3, 4'd7, 4'd15})) begin
        `uvm_error("MST_MON/PROT_WRAP_LEN", $sformatf("[AXI_MASTER_MON] Invalid WRAP length=%0d! AWID=0x%0h", tr.len + 1, tr.id))
      end
      if ((tr.addr & ((1 << tr.size) - 1)) != '0) begin
        `uvm_error("MST_MON/PROT_WRAP_ALIGN", $sformatf("[AXI_MASTER_MON] Unaligned WRAP address=0x%08h for size=%0d bytes! AWID=0x%0h",
                   tr.addr, (1 << tr.size), tr.id))
      end
    end

    if (((1 << tr.size) > STRB_WIDTH) && !mon_cfg.mask_burst_size_err) begin
      `uvm_error("MST_MON/PROT_AWSIZE", $sformatf("[AXI_MASTER_MON] Transfer size %0d bytes exceeds data bus width %0d bytes! AWID=0x%0h",
                 (1 << tr.size), STRB_WIDTH, tr.id))
    end
  endfunction : check_aw_protocol

  virtual function void check_ar_protocol(axi_seq_item tr);
    if (vif.ARBURST == 2'b11 && !mon_cfg.mask_illegal_burst_err) begin
      `uvm_error("MST_MON/PROT_ARBURST", $sformatf("[AXI_MASTER_MON] AR reserved burst 2'b11! ARID=0x%0h", tr.id))
    end

    if ((((tr.addr & 12'hFFF) + ((tr.len + 1) * (1 << tr.size))) > 13'h1000) && !mon_cfg.mask_4k_boundary_err) begin
      `uvm_error("MST_MON/PROT_4K_AR", $sformatf("[AXI_MASTER_MON] AR burst crosses 4KB boundary! ARID=0x%0h Addr=0x%08h Len=%0d Size=%0d",
                 tr.id, tr.addr, tr.len, tr.size))
    end

    if (tr.burst == BURST_WRAP && !mon_cfg.mask_wrap_rules_err) begin
      if (!(tr.len inside {4'd1, 4'd3, 4'd7, 4'd15})) begin
        `uvm_error("MST_MON/PROT_WRAP_LEN_AR", $sformatf("[AXI_MASTER_MON] Invalid WRAP read length=%0d! ARID=0x%0h", tr.len + 1, tr.id))
      end
      if ((tr.addr & ((1 << tr.size) - 1)) != '0) begin
        `uvm_error("MST_MON/PROT_WRAP_ALIGN_AR", $sformatf("[AXI_MASTER_MON] Unaligned WRAP read address=0x%08h for size=%0d bytes! ARID=0x%0h",
                   tr.addr, (1 << tr.size), tr.id))
      end
    end

    if (((1 << tr.size) > STRB_WIDTH) && !mon_cfg.mask_burst_size_err) begin
      `uvm_error("MST_MON/PROT_ARSIZE", $sformatf("[AXI_MASTER_MON] Read size %0d bytes exceeds bus width %0d bytes! ARID=0x%0h",
                 (1 << tr.size), STRB_WIDTH, tr.id))
    end
  endfunction : check_ar_protocol

  virtual function void check_w_protocol(axi_seq_item tr);
    if ((vif.WSTRB == '0) && !mon_cfg.mask_wstrb_zero_err) begin
      `uvm_error("MST_MON/PROT_WSTRB_ZERO", $sformatf("[AXI_MASTER_MON] All-zero WSTRB on beat %0d for WID=0x%0h!", tr.current_beat, vif.WID))
    end

    // Only validate bounds if address phase has paired (tr.len is known)
    if (tr.trans_type == AXI_WRITE && tr.len != 0) begin
      if (vif.WLAST && (tr.current_beat != tr.len) && !mon_cfg.mask_early_wlast_err) begin
        `uvm_error("MST_MON/PROT_EARLY_WLAST", $sformatf("[AXI_MASTER_MON] Premature WLAST on beat %0d of %0d for WID=0x%0h!",
                   tr.current_beat + 1, tr.len + 1, vif.WID))
      end

      if (!vif.WLAST && (tr.current_beat == tr.len) && !mon_cfg.mask_missing_wlast_err) begin
        `uvm_error("MST_MON/PROT_MISSING_WLAST", $sformatf("[AXI_MASTER_MON] Omitted WLAST on expected final beat %0d for WID=0x%0h!",
                   tr.len + 1, vif.WID))
      end
    end
  endfunction : check_w_protocol

  virtual function void check_r_protocol(axi_seq_item tr);
    if (vif.RLAST && (tr.current_beat != tr.len) && !mon_cfg.mask_early_rlast_err) begin
      `uvm_error("MST_MON/PROT_EARLY_RLAST", $sformatf("[AXI_MASTER_MON] Premature RLAST on beat %0d of %0d for RID=0x%0h!",
                 tr.current_beat + 1, tr.len + 1, vif.RID))
    end

    if (!vif.RLAST && (tr.current_beat == tr.len) && !mon_cfg.mask_missing_rlast_err) begin
      `uvm_error("MST_MON/PROT_MISSING_RLAST", $sformatf("[AXI_MASTER_MON] Omitted RLAST on expected final beat %0d for RID=0x%0h!",
                 tr.len + 1, vif.RID))
    end
  endfunction : check_r_protocol

  virtual function void check_b_order(bit [ID_WIDTH-1:0] bid);
    int first_match_idx = -1;

    for (int k = 0; k < write_id_order_q.size(); k++) begin
      if (write_id_order_q[k] == bid) begin
        first_match_idx = k;
        break;
      end
    end

    if (first_match_idx != -1) begin
      write_id_order_q.delete(first_match_idx);
    end
  endfunction : check_b_order

endclass : axi_master_mon