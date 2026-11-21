`uvm_analysis_imp_decl(_mst)
`uvm_analysis_imp_decl(_slv)

class axi_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(axi_scoreboard)

  // ---------------------------------------------------------------------------
  // Dedicated Analysis Implementation Ports
  // ---------------------------------------------------------------------------
  uvm_analysis_imp_mst #(axi_seq_item, axi_scoreboard) mst_export;
  uvm_analysis_imp_slv #(axi_seq_item, axi_scoreboard) slv_export;

  // ---------------------------------------------------------------------------
  // Control Knobs & Configuration Properties
  // ---------------------------------------------------------------------------
  // When set to 1'b1, the scoreboard bypasses payload data checks and golden 
  // memory model updates. This is useful for stress/saturation traffic or 
  // mid-transfer reset recovery tests where read-after-write data races occur.
  bit skip_data_comparison = 1'b0;

  // ---------------------------------------------------------------------------
  // Internal Tracking Queues & Golden Memory
  // ---------------------------------------------------------------------------
  axi_seq_item mst_wr_pool[bit [ID_WIDTH-1:0]][$];
  axi_seq_item slv_wr_pool[bit [ID_WIDTH-1:0]][$];
  axi_seq_item mst_rd_pool[bit [ID_WIDTH-1:0]][$];
  axi_seq_item slv_rd_pool[bit [ID_WIDTH-1:0]][$];

  // Byte-addressable Golden Memory Model
  bit [7:0] mem_model [bit [ADDR_WIDTH-1:0]];

  // ---------------------------------------------------------------------------
  // Scoreboard Exclusive Monitor Reference Model
  // ---------------------------------------------------------------------------
  typedef struct {
    bit                 valid;
    bit [ADDR_WIDTH-1:0] addr;
    bit [LEN_WIDTH-1:0]  len;
    bit [SIZE_WIDTH-1:0] size;
  } ex_mon_ref_t;

  ex_mon_ref_t scb_ex_table[bit [ID_WIDTH-1:0]];

  // ---------------------------------------------------------------------------
  // Statistics & Counters
  // ---------------------------------------------------------------------------
  int unsigned wr_matches       = 0;
  int unsigned wr_mismatches    = 0;
  int unsigned rd_matches       = 0;
  int unsigned rd_mismatches    = 0;
  int unsigned mst_wr_cnt       = 0;
  int unsigned slv_wr_cnt       = 0;
  int unsigned mst_rd_cnt       = 0;
  int unsigned slv_rd_cnt       = 0;

  function new(string name = "axi_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    mst_export = new("mst_export", this);
    slv_export = new("slv_export", this);
  endfunction : new

  // ---------------------------------------------------------------------------
  // Mid-Test Reset Flush Function
  // ---------------------------------------------------------------------------
  virtual function void flush();
    `uvm_info("SCB/FLUSH", "Flushing scoreboard pools and resetting mismatch counters for post-reset verification.", UVM_LOW)

    // Clear all in-flight transfer queues
    mst_wr_pool.delete();
    slv_wr_pool.delete();
    mst_rd_pool.delete();
    slv_rd_pool.delete();

    // Reset error & mismatch counters accumulated during mid-transfer reset abort
    wr_mismatches = 0;
    rd_mismatches = 0;

    // Clear exclusive monitor reservations
    scb_ex_table.delete();
  endfunction : flush

  // ---------------------------------------------------------------------------
  // Master Monitor Hook
  // ---------------------------------------------------------------------------
  virtual function void write_mst(axi_seq_item tr);
    axi_seq_item tr_clone;
    $cast(tr_clone, tr.clone());

    if (tr_clone.trans_type == AXI_WRITE) begin
      mst_wr_cnt++;
      if (slv_wr_pool.exists(tr_clone.id) && slv_wr_pool[tr_clone.id].size() > 0) begin
        axi_seq_item slv_tr = slv_wr_pool[tr_clone.id].pop_front();
        check_write_transaction(tr_clone, slv_tr);
      end else begin
        mst_wr_pool[tr_clone.id].push_back(tr_clone);
      end
    end else begin
      mst_rd_cnt++;
      if (slv_rd_pool.exists(tr_clone.id) && slv_rd_pool[tr_clone.id].size() > 0) begin
        axi_seq_item slv_tr = slv_rd_pool[tr_clone.id].pop_front();
        check_read_transaction(tr_clone, slv_tr);
      end else begin
        mst_rd_pool[tr_clone.id].push_back(tr_clone);
      end
    end
  endfunction : write_mst

  // ---------------------------------------------------------------------------
  // Slave Monitor Hook
  // ---------------------------------------------------------------------------
  virtual function void write_slv(axi_seq_item tr);
    axi_seq_item tr_clone;
    $cast(tr_clone, tr.clone());

    if (tr_clone.trans_type == AXI_WRITE) begin
      slv_wr_cnt++;
      if (mst_wr_pool.exists(tr_clone.id) && mst_wr_pool[tr_clone.id].size() > 0) begin
        axi_seq_item mst_tr = mst_wr_pool[tr_clone.id].pop_front();
        check_write_transaction(mst_tr, tr_clone);
      end else begin
        slv_wr_pool[tr_clone.id].push_back(tr_clone);
      end
    end else begin
      slv_rd_cnt++;
      if (mst_rd_pool.exists(tr_clone.id) && mst_rd_pool[tr_clone.id].size() > 0) begin
        axi_seq_item mst_tr = mst_rd_pool[tr_clone.id].pop_front();
        check_read_transaction(mst_tr, tr_clone);
      end else begin
        slv_rd_pool[tr_clone.id].push_back(tr_clone);
      end
    end
  endfunction : write_slv

  // ---------------------------------------------------------------------------
  // Write Transaction Integrity & Memory Update
  // ---------------------------------------------------------------------------
  virtual function void check_write_transaction(axi_seq_item mst_tr, axi_seq_item slv_tr);
    bit is_match = 1'b1;
    bit is_ex_write = (mst_tr.lock == 2'b01);
    bit ex_reservation_matched = 1'b0;

    // 1. Check Address & Control Attributes
    if (mst_tr.addr !== slv_tr.addr || mst_tr.len !== slv_tr.len ||
        mst_tr.size !== slv_tr.size || mst_tr.burst !== slv_tr.burst ||
        mst_tr.lock !== slv_tr.lock) begin
      `uvm_error("SCB/WR_CTRL_MISMATCH", $sformatf(
        "[SCB] Write Control Mismatch ID 0x%0h!\n  MST: Addr=0x%0h Len=%0d Size=%0d Burst=%0s Lock=2'b%02b\n  SLV: Addr=0x%0h Len=%0d Size=%0d Burst=%0s Lock=2'b%02b",
        mst_tr.id, mst_tr.addr, mst_tr.len, mst_tr.size, mst_tr.burst.name(), mst_tr.lock,
        slv_tr.addr, slv_tr.len, slv_tr.size, slv_tr.burst.name(), slv_tr.lock))
      is_match = 1'b0;
    end

    // 2. Check WDATA & WSTRB Across Every Beat (Skipped if skip_data_comparison is set)
    if (!skip_data_comparison) begin
      for (int beat = 0; beat <= mst_tr.len; beat++) begin
        if (mst_tr.wdata[beat] !== slv_tr.wdata[beat] || mst_tr.wstrb[beat] !== slv_tr.wstrb[beat]) begin
          `uvm_error("SCB/WDATA_MISMATCH", $sformatf(
            "[SCB] Write Data Mismatch ID 0x%0h Beat %0d/%0d!\n  MST: WDATA=0x%08h WSTRB=0x%01h\n  SLV: WDATA=0x%08h WSTRB=0x%01h",
            mst_tr.id, beat + 1, mst_tr.len + 1, mst_tr.wdata[beat], mst_tr.wstrb[beat],
            slv_tr.wdata[beat], slv_tr.wstrb[beat]))
          is_match = 1'b0;
        end
      end
    end else begin
      `uvm_info("SCB/BYPASS_DATA_CHECK", $sformatf("skip_data_comparison=1: Bypassed write data payload checks for WID=0x%0h", mst_tr.id), UVM_HIGH)
    end

    // 3. Check Slave Response (B Channel)
    if (mst_tr.bresp !== slv_tr.bresp) begin
      `uvm_error("SCB/BRESP_MISMATCH", $sformatf(
        "[SCB] Write Response Mismatch ID 0x%0h! MST observed BRESP=%0s, SLV drove BRESP=%0s",
        mst_tr.id, mst_tr.bresp.name(), slv_tr.bresp.name()))
      is_match = 1'b0;
    end

    // 4. Validate Exclusive Access Reservation Status
    if (is_ex_write) begin
      if (scb_ex_table.exists(mst_tr.id) && scb_ex_table[mst_tr.id].valid &&
          (scb_ex_table[mst_tr.id].addr == mst_tr.addr)) begin
        ex_reservation_matched = 1'b1;
      end

      if (ex_reservation_matched && slv_tr.bresp != RESP_EXOKAY) begin
        `uvm_error("SCB/EX_BRESP_FAIL", $sformatf(
          "[SCB] Valid Exclusive Write ID 0x%0h at Addr 0x%0h expected RESP_EXOKAY, got %0s",
          mst_tr.id, mst_tr.addr, slv_tr.bresp.name()))
        is_match = 1'b0;
      end else if (!ex_reservation_matched && slv_tr.bresp == RESP_EXOKAY) begin
        `uvm_error("SCB/EX_ILLEGAL_EXOKAY", $sformatf(
          "[SCB] Exclusive Write ID 0x%0h at Addr 0x%0h had NO active reservation but returned RESP_EXOKAY!",
          mst_tr.id, mst_tr.addr))
        is_match = 1'b0;
      end
    end

    // 5. Update Reference Memory & Monitor State
    if (is_match) begin
      wr_matches++;

      // Update memory only if skip_data_comparison is disabled and:
      // a) Normal write with OKAY, or
      // b) Exclusive write with a valid reservation match and EXOKAY
      if (!skip_data_comparison) begin
        if ((!is_ex_write && (slv_tr.bresp == RESP_OKAY)) ||
            (is_ex_write && ex_reservation_matched && (slv_tr.bresp == RESP_EXOKAY))) begin
          update_golden_memory(slv_tr);
        end
      end

      // Update Exclusive Monitor Table:
      if (is_ex_write && ex_reservation_matched) begin
        scb_ex_table[mst_tr.id].valid = 1'b0;
      end else if (!is_ex_write && (slv_tr.bresp == RESP_OKAY)) begin
        foreach (scb_ex_table[mon_id]) begin
          if (scb_ex_table[mon_id].valid && (scb_ex_table[mon_id].addr == mst_tr.addr)) begin
            scb_ex_table[mon_id].valid = 1'b0;
          end
        end
      end
    end else begin
      wr_mismatches++;
    end
  endfunction : check_write_transaction

  // ---------------------------------------------------------------------------
  // Read Transaction Integrity & Data Verification
  // ---------------------------------------------------------------------------
  virtual function void check_read_transaction(axi_seq_item mst_tr, axi_seq_item slv_tr);
    bit is_match = 1'b1;
    bit [ADDR_WIDTH-1:0] addr = mst_tr.addr;
    int num_bytes_beat;
    int byte_offset;
    bit [DATA_WIDTH-1:0] active_lane_mask;

    // 1. Check Read Request Controls (AR)
    if (mst_tr.addr !== slv_tr.addr || mst_tr.len !== slv_tr.len ||
        mst_tr.size !== slv_tr.size || mst_tr.burst !== slv_tr.burst ||
        mst_tr.lock !== slv_tr.lock) begin
      `uvm_error("SCB/RD_CTRL_MISMATCH", $sformatf(
        "[SCB] Read Command Mismatch ID 0x%0h!\n  MST: Addr=0x%0h Len=%0d Size=%0d Burst=%0s Lock=2'b%02b\n  SLV: Addr=0x%0h Len=%0d Size=%0d Burst=%0s Lock=2'b%02b",
        mst_tr.id, mst_tr.addr, mst_tr.len, mst_tr.size, mst_tr.burst.name(), mst_tr.lock,
        slv_tr.addr, slv_tr.len, slv_tr.size, slv_tr.burst.name(), slv_tr.lock))
      is_match = 1'b0;
    end

    // 2. Track Exclusive Read Reservation in Reference Model
    if (mst_tr.lock == 2'b01) begin
      scb_ex_table[mst_tr.id].valid = 1'b1;
      scb_ex_table[mst_tr.id].addr  = mst_tr.addr;
      scb_ex_table[mst_tr.id].len   = mst_tr.len;
      scb_ex_table[mst_tr.id].size  = mst_tr.size;
    end

    // 3. Check Read Payload Beats with Active Byte-Lane Masking (Skipped if skip_data_comparison is set)
    num_bytes_beat = (1 << mst_tr.size);

    for (int beat = 0; beat <= mst_tr.len; beat++) begin
      bit [ADDR_WIDTH-1:0] base_aligned = addr & ~(STRB_WIDTH - 1);
      bit [DATA_WIDTH-1:0] golden_word  = '0;

      // Check Master received what Slave drove
      if (mst_tr.rdata[beat] !== slv_tr.rdata[beat] || mst_tr.rresp[beat] !== slv_tr.rresp[beat]) begin
        `uvm_error("SCB/RDATA_PIN_MISMATCH", $sformatf(
          "[SCB] Read Bus Transfer Mismatch ID 0x%0h Beat %0d/%0d!\n  SLV drove: RDATA=0x%08h RRESP=%0s\n  MST sampled: RDATA=0x%08h RRESP=%0s",
          mst_tr.id, beat + 1, mst_tr.len + 1, slv_tr.rdata[beat], slv_tr.rresp[beat].name(),
          mst_tr.rdata[beat], mst_tr.rresp[beat].name()))
        is_match = 1'b0;
      end

      // Check Read Data against Golden Reference Model
      if (!skip_data_comparison) begin
        if (slv_tr.rresp[beat] == RESP_OKAY || slv_tr.rresp[beat] == RESP_EXOKAY) begin
          for (int b = 0; b < STRB_WIDTH; b++) begin
            if (mem_model.exists(base_aligned + b))
              golden_word[(b * 8) +: 8] = mem_model[base_aligned + b];
            else
              golden_word[(b * 8) +: 8] = 8'h00;
          end

          byte_offset = addr % STRB_WIDTH;
          active_lane_mask = '0;
          for (int b = 0; b < num_bytes_beat; b++) begin
            active_lane_mask[(byte_offset + b)*8 +: 8] = 8'hFF;
          end

          if ((slv_tr.rdata[beat] & active_lane_mask) !== (golden_word & active_lane_mask)) begin
            `uvm_error("SCB/RDATA_MEM_MISMATCH", $sformatf(
              "[SCB] Read Data Model Mismatch ID 0x%0h Beat %0d/%0d at Addr 0x%0h!\n  Mask: 0x%08h\n  Expected (Memory): 0x%08h\n  Actual (Read Beat): 0x%08h",
              mst_tr.id, beat + 1, mst_tr.len + 1, addr, active_lane_mask, 
              (golden_word & active_lane_mask), (slv_tr.rdata[beat] & active_lane_mask)))
            is_match = 1'b0;
          end
        end
      end

      addr = get_next_addr(addr, mst_tr.size, mst_tr.burst, mst_tr.len);
    end

    if (skip_data_comparison) begin
      `uvm_info("SCB/BYPASS_DATA_CHECK", $sformatf("skip_data_comparison=1: Bypassed read memory model comparison for RID=0x%0h", mst_tr.id), UVM_HIGH)
    end

    if (is_match) begin
      rd_matches++;
    end else begin
      rd_mismatches++;
    end
  endfunction : check_read_transaction

  // ---------------------------------------------------------------------------
  // Memory Update Helper
  // ---------------------------------------------------------------------------
  virtual function void update_golden_memory(axi_seq_item tr);
    bit [ADDR_WIDTH-1:0] addr = tr.addr;
    for (int beat = 0; beat <= tr.len; beat++) begin
      bit [ADDR_WIDTH-1:0] base_aligned = addr & ~(STRB_WIDTH - 1);
      for (int b = 0; b < STRB_WIDTH; b++) begin
        if (tr.wstrb[beat][b]) begin
          mem_model[base_aligned + b] = tr.wdata[beat][(b * 8) +: 8];
        end
      end
      addr = get_next_addr(addr, tr.size, tr.burst, tr.len);
    end
  endfunction : update_golden_memory

  // ---------------------------------------------------------------------------
  // Address Increment & Wrap Helper
  // ---------------------------------------------------------------------------
  virtual function bit [ADDR_WIDTH-1:0] get_next_addr(
    bit [ADDR_WIDTH-1:0] current_addr,
    bit [SIZE_WIDTH-1:0] size,
    axi_burst_e          burst,
    bit [LEN_WIDTH-1:0]  len
  );
    bit [ADDR_WIDTH-1:0] num_bytes;
    bit [ADDR_WIDTH-1:0] aligned_addr;
    bit [ADDR_WIDTH-1:0] wrap_mask;

    num_bytes    = (1 << size);
    aligned_addr = current_addr & ~(num_bytes - 1'b1);

    case (burst)
      BURST_FIXED: get_next_addr = current_addr;
      BURST_INCR:  get_next_addr = aligned_addr + num_bytes;
      BURST_WRAP:  begin
        wrap_mask     = (num_bytes * (len + 1)) - 1;
        get_next_addr = (aligned_addr & ~wrap_mask) | ((aligned_addr + num_bytes) & wrap_mask);
      end
      default:     get_next_addr = aligned_addr + num_bytes;
    endcase
  endfunction : get_next_addr

  // ---------------------------------------------------------------------------
  // Report & Final Checks
  // ---------------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    foreach (mst_wr_pool[id]) begin
      if (mst_wr_pool[id].size() > 0)
        `uvm_error("SCB/ORPHAN_MST_WR", $sformatf("[SCB] %0d pending Master write transaction(s) with ID 0x%0h never reached Slave!", mst_wr_pool[id].size(), id))
    end
    foreach (slv_wr_pool[id]) begin
      if (slv_wr_pool[id].size() > 0)
        `uvm_error("SCB/ORPHAN_SLV_WR", $sformatf("[SCB] %0d pending Slave write transaction(s) with ID 0x%0h never originated from Master!", slv_wr_pool[id].size(), id))
    end
    foreach (mst_rd_pool[id]) begin
      if (mst_rd_pool[id].size() > 0)
        `uvm_error("SCB/ORPHAN_MST_RD", $sformatf("[SCB] %0d pending Master read transaction(s) with ID 0x%0h never reached Slave!", mst_rd_pool[id].size(), id))
    end
    foreach (slv_rd_pool[id]) begin
      if (slv_rd_pool[id].size() > 0)
        `uvm_error("SCB/ORPHAN_SLV_RD", $sformatf("[SCB] %0d pending Slave read transaction(s) with ID 0x%0h never originated from Master!", slv_rd_pool[id].size(), id))
    end
  endfunction : check_phase

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("SCB/REPORT", {
      "\n============================================================\n",
      "                 AXI MASTER-SLAVE SCOREBOARD REPORT            \n",
      "============================================================\n",
      $sformatf("  Master Writes Observed : %0d | Slave Writes Observed : %0d\n", mst_wr_cnt, slv_wr_cnt),
      $sformatf("  Write Matches          : %0d | Write Mismatches       : %0d\n", wr_matches, wr_mismatches),
      $sformatf("  Master Reads Observed  : %0d | Slave Reads Observed  : %0d\n", mst_rd_cnt, slv_rd_cnt),
      $sformatf("  Read Matches           : %0d | Read Mismatches        : %0d\n", rd_matches, rd_mismatches),
      "============================================================"
    }, UVM_LOW)

    if (wr_mismatches > 0 || rd_mismatches > 0) begin
      `uvm_error("SCB/STATUS", "[SCB] TEST FAILED with data or protocol mismatches.")
    end else begin
      `uvm_info("SCB/STATUS", "[SCB] TEST PASSED with all transactions matching.", UVM_LOW)
    end
  endfunction : report_phase

endclass : axi_scoreboard