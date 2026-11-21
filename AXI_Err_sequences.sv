// -----------------------------------------------------------------------------
// Sequence: axi_all_slverr_interleaved_seq
// Pattern : Normal -> SLVERR_1 -> Normal -> SLVERR_2 -> Normal -> SLVERR_3 ...
// Base    : Reuses write_read_ping_pong, write_burst, and read_burst from axi_base_seq
// -----------------------------------------------------------------------------
class axi_all_slverr_interleaved_seq extends axi_base_seq;
  `uvm_object_utils(axi_all_slverr_interleaved_seq)

  bit [9:0]            repeat_count = 3;
  bit [ADDR_WIDTH-1:0] start_addr   = 'h1000;
  bit [LEN_WIDTH-1:0]  burst_len    = 4'd3;            // Fixed 4-beat transfers
  bit [DATA_WIDTH-1:0] init_data    = 32'hDEAD_0000;
  bit                  randomize_id = 1'b1;

  function new(string name = "axi_all_slverr_interleaved_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SLVERR_SEQ", "Starting interleaved normal and SLVERR sequence...", UVM_LOW)

    // =========================================================================
    // 1. NORMAL TRANSACTION (Baseline OKAY)
    // =========================================================================

    `uvm_info("SLVERR_SEQ", "Word write & read at 0x1000", UVM_LOW)
    `uvm_info("FIXED_SEQ", "Starting Fixed Burst Test...", UVM_LOW)
   
   execute_burst_engine(
      .burst_type   (BURST_FIXED),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (randomize_id)
    );

    `uvm_info("INCR_SEQ", "Starting INCR Burst Test...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_INCR),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (randomize_id)
    );

    `uvm_info("WRAP_SEQ", "Starting WRAP Burst Sequence...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_WRAP),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (randomize_id)
    );

    `uvm_info("SLVERR_SEQ", "Interleaved SLVERR sequence completed successfully.", UVM_LOW)
  endtask : body

endclass : axi_all_slverr_interleaved_seq


// =============================================================================
// Class:    axi3_unaligned_address_seq
// Base:     axi_base_seq
// Test Ref: AXI3_Unaligned_Address_test (Spec A3.4.1 & A3.4.4)
// Purpose:  Issues 32-bit (AxSIZE=2'b010) unaligned transfers (e.g. 0x1001, 0x1002, 0x1003)
//           across INCR, FIXED, and WRAP bursts.
//           Reuses calc_axi_beat_addr and calc_axi_wstrb from axi_base_seq.
// =============================================================================
class axi3_unaligned_address_seq extends axi_base_seq;
  `uvm_object_utils(axi3_unaligned_address_seq)

  function new(string name = "axi3_unaligned_address_seq");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // Sequence Body
  // ---------------------------------------------------------------------------
  virtual task body();
    // -------------------------------------------------------------------------
    // 1. DECLARATIONS FIRST (Strictly uninitialized for QuestaSim vlog compliance)
    // -------------------------------------------------------------------------
    axi_burst_e          burst_types[3];       // INCR, FIXED, and WRAP
    bit [1:0]            unaligned_offsets[3]; // +1, +2, +3 offsets (e.g., 0x1001, 0x1002, 0x1003)
    bit [LEN_WIDTH-1:0]  test_lens_std[4];     // For INCR and FIXED: 1, 2, 4, 8 beats
    bit [LEN_WIDTH-1:0]  test_lens_wrap[4];    // For WRAP: 2, 4, 8, 16 beats

    bit [ID_WIDTH-1:0]   tx_id;
    axi_burst_e          cur_burst;
    bit [1:0]            offset;
    bit [LEN_WIDTH-1:0]  cur_len;
    bit [SIZE_WIDTH-1:0] cur_size;
    bit [ADDR_WIDTH-1:0] base_aligned_addr;
    bit [ADDR_WIDTH-1:0] unaligned_start_addr;
    bit [ADDR_WIDTH-1:0] beat_addr;
    bit [STRB_WIDTH-1:0] strb;
    int                  num_lens;
    int                  container_bytes;
    axi_seq_item         wr_item;

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL ASSIGNMENTS & INITIALIZATIONS
    // -------------------------------------------------------------------------
    burst_types[0] = BURST_INCR;
    burst_types[1] = BURST_FIXED;
    burst_types[2] = BURST_WRAP;

    // Unaligned byte offsets: 1, 2, 3 within a 4-byte container
    unaligned_offsets[0] = 2'd1;
    unaligned_offsets[1] = 2'd2;
    unaligned_offsets[2] = 2'd3;

    // Burst lengths for INCR and FIXED (len = 0, 1, 3, 7 -> 1, 2, 4, 8 beats)
    test_lens_std[0]  = 'd0;
    test_lens_std[1]  = 'd1;
    test_lens_std[2]  = 'd3;
    test_lens_std[3]  = 'd7;

    // Legal AXI WRAP lengths: 2, 4, 8, 16 beats (len = 1, 3, 7, 15)
    test_lens_wrap[0] = 'd1;
    test_lens_wrap[1] = 'd3;
    test_lens_wrap[2] = 'd7;
    test_lens_wrap[3] = 'd15;

    cur_size = 3'b010; // AxSIZE = 32-bit (4 bytes)
    tx_id    = 'h1;

    `uvm_info(get_type_name(), "=== Starting AXI3_Unaligned_Address_test Sequence (INCR, FIXED, WRAP | AxSIZE=32-bit) ===", UVM_LOW)

    for (int b = 0; b < 3; b++) begin
      cur_burst = burst_types[b];
      num_lens  = 4;

      for (int off_idx = 0; off_idx < 3; off_idx++) begin
        offset = unaligned_offsets[off_idx];

        for (int l = 0; l < num_lens; l++) begin
          cur_len = (cur_burst == BURST_WRAP) ? test_lens_wrap[l] : test_lens_std[l];
          container_bytes = (cur_len + 1) * 4;

          // Address generation
          if (cur_burst == BURST_WRAP) begin
            // Aligned wrap base container + unaligned byte offset
            base_aligned_addr    = 'h2000 + ($urandom_range(0, 8) * container_bytes);
            unaligned_start_addr = base_aligned_addr + offset;
          end else begin
            // Unaligned address for INCR and FIXED
            base_aligned_addr    = 'h1000 + ($urandom_range(0, 16) * 'h10);
            unaligned_start_addr = base_aligned_addr + offset; // e.g. 0x1001, 0x1002, 0x1003

            // Safeguard against crossing 4KB page boundaries
            if (((unaligned_start_addr & 12'hFFF) + container_bytes) > 4096) begin
              unaligned_start_addr = ('h1000 | offset);
            end
          end

          // -----------------------------------------------------------
          // Step 1: Drive Unaligned 32-bit Write Burst
          // -----------------------------------------------------------
          `uvm_create(wr_item)
          start_item(wr_item);

          wr_item.trans_type = AXI_WRITE;
          wr_item.id         = tx_id;
          wr_item.addr       = unaligned_start_addr;
          wr_item.len        = cur_len;
          wr_item.size       = cur_size; // AxSIZE = 32-bit
          wr_item.burst      = cur_burst;
          wr_item.lock       = default_lock;
          wr_item.cache      = default_cache;
          wr_item.prot       = default_prot;

          wr_item.wdata      = new[cur_len + 1];
          wr_item.wstrb      = new[cur_len + 1];

          for (int beat = 0; beat <= cur_len; beat++) begin
            // Reusing calc_axi_beat_addr and calc_axi_wstrb from axi_base_seq
            beat_addr = calc_axi_beat_addr(unaligned_start_addr, cur_burst, cur_len, cur_size, beat);
            strb      = calc_axi_wstrb(beat_addr, cur_size, (1 << cur_size), beat);

            wr_item.wstrb[beat] = strb;
            wr_item.wdata[beat] = '0;

            // Steer valid payload only to lanes asserted by dynamic WSTRB
            for (int lane = 0; lane < STRB_WIDTH; lane++) begin
              if (strb[lane]) begin
                wr_item.wdata[beat][(lane*8) +: 8] = $urandom_range(8'h11, 8'hFE);
              end
            end
          end

          finish_item(wr_item);

          if (!wr_item.is_completed) begin
            @wr_item.done_event;
          end

          // -----------------------------------------------------------
          // Step 2: Drive Matching Unaligned Read Burst
          // -----------------------------------------------------------
          read_burst(
            .id(tx_id + 'h10),
            .addr(unaligned_start_addr),
            .len(cur_len),
            .size(cur_size),
            .burst(cur_burst)
          );

          tx_id++;
        end
      end
    end

    `uvm_info(get_type_name(), "=== AXI3 Unaligned Address Sequence Completed Successfully (All 3 Bursts). ===", UVM_LOW)
  endtask : body

endclass : axi3_unaligned_address_seq

// =============================================================================
// Class:    axi3_prot_privilege_security_seq
// Base:     axi_base_seq
// Test Ref: AXI3_CTS_List Row 27: AXI3_Prot_Privilege_Security_test (Spec A5.1)
// RTL Map:  Normal Data RAM: 0x0000 - 0x3FFF
//           Secure RAM:      0x4000 - 0x7FFF (SECURE_BASE_ADDR in AXI_SLAVE)
//           DECERR:          >= 0x8000
// =============================================================================
class axi3_prot_privilege_security_seq extends axi_base_seq;
  `uvm_object_utils(axi3_prot_privilege_security_seq)

  // Address map configuration matching AXI_SLAVE RTL localparams
  bit [ADDR_WIDTH-1:0] normal_mem_addr        = 16'h1000;
  bit [ADDR_WIDTH-1:0] secure_peripheral_addr = 16'h4000; // Matches SECURE_BASE_ADDR

  function new(string name = "axi3_prot_privilege_security_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -------------------------------------------------------------------------
    // 1. ALL DECLARATIONS FIRST (Strictly uninitialized for QuestaSim vlog)
    // -------------------------------------------------------------------------
    bit [2:0]            prot_combos[4];
    bit [2:0]            cur_prot;
    bit [ID_WIDTH-1:0]   tx_id;
    bit [ADDR_WIDTH-1:0] cur_normal_addr;
    bit [LEN_WIDTH-1:0]  burst_len;
    bit [SIZE_WIDTH-1:0] burst_size;
    bit [DATA_WIDTH-1:0] secure_golden_data;
    
    axi_seq_item         wr_item;
    axi_seq_item         rd_item;

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL ASSIGNMENTS & INITIALIZATIONS
    // -------------------------------------------------------------------------
    // Legal Data Access Combinations (prot[2]=0) tested on normal space (0x1000):
    prot_combos[0] = 3'b000; // Normal, Secure, Data
    prot_combos[1] = 3'b001; // Privileged, Secure, Data
    prot_combos[2] = 3'b010; // Normal, Non-Secure, Data
    prot_combos[3] = 3'b011; // Privileged, Non-Secure, Data

    tx_id              = 'h1;
    burst_len          = 4'd1;           // 2 beats
    burst_size         = default_size;   // 32-bit (4 bytes)
    cur_normal_addr    = normal_mem_addr;
    secure_golden_data = 32'h5AFE_CAFE;

    `uvm_info(get_type_name(), "=== Starting AXI3_Prot_Privilege_Security_test (Spec A5.1) ===", UVM_LOW)

    // =========================================================================
    // Step 1: Drive Varying Legal AxPROT Data Combinations on Normal Memory (< 0x4000)
    // =========================================================================
    `uvm_info(get_type_name(), "Step 1: Driving Legal AxPROT Data Combinations on Normal Memory", UVM_LOW)

    for (int p = 0; p < 4; p++) begin
      cur_prot = prot_combos[p];

      // Write transaction
      `uvm_create(wr_item)
      start_item(wr_item);
      wr_item.trans_type = AXI_WRITE;
      wr_item.id         = tx_id;
      wr_item.addr       = cur_normal_addr;
      wr_item.len        = burst_len;
      wr_item.size       = burst_size;
      wr_item.burst      = BURST_INCR;
      wr_item.lock       = default_lock;
      wr_item.cache      = default_cache;
      wr_item.prot       = cur_prot;
      wr_item.wdata      = new[burst_len + 1];
      wr_item.wstrb      = new[burst_len + 1];
      foreach (wr_item.wdata[i]) begin
        wr_item.wdata[i] = 32'hA000_0000 | (cur_prot << 16) | (tx_id << 8) | i;
        wr_item.wstrb[i] = {STRB_WIDTH{1'b1}};
      end
      finish_item(wr_item);
      if (!wr_item.is_completed) @wr_item.done_event;

      if (wr_item.bresp != RESP_OKAY) begin
        `uvm_error(get_type_name(), $sformatf("Normal Write failed for PROT=3'b%03b! BRESP=%s", cur_prot, wr_item.bresp.name()))
      end

      // Read transaction
      `uvm_create(rd_item)
      start_item(rd_item);
      rd_item.trans_type = AXI_READ;
      rd_item.id         = tx_id + 'h10;
      rd_item.addr       = cur_normal_addr;
      rd_item.len        = burst_len;
      rd_item.size       = burst_size;
      rd_item.burst      = BURST_INCR;
      rd_item.lock       = default_lock;
      rd_item.cache      = default_cache;
      rd_item.prot       = cur_prot;
      finish_item(rd_item);
      if (!rd_item.is_completed) @rd_item.done_event;

      foreach (rd_item.rresp[i]) begin
        if (rd_item.rresp[i] != RESP_OKAY) begin
          `uvm_error(get_type_name(), $sformatf("Normal Read failed for PROT=3'b%03b Beat=%0d! RRESP=%s", cur_prot, i, rd_item.rresp[i].name()))
        end
      end

      cur_normal_addr += 'h40;
      tx_id++;
    end

    // =========================================================================
    // Step 2: Verify Normal Secure Instruction Access (AxPROT = 3'b100)
    // prot[0] = 0 (Normal), prot[1] = 0 (Secure), prot[2] = 1 (Instruction)
    // RTL Execute-Never check: err_prot_instr = prot[2] -> Returns RESP_SLVERR
    // =========================================================================
    `uvm_info(get_type_name(), "Step 2: Testing Normal Secure Instruction Access (AxPROT=3'b100)", UVM_LOW)

    // 2a. Normal Secure Instruction Write Attempt
    `uvm_create(wr_item)
    start_item(wr_item);
    wr_item.trans_type = AXI_WRITE;
    wr_item.id         = tx_id;
    wr_item.addr       = normal_mem_addr;
    wr_item.len        = burst_len;
    wr_item.size       = burst_size;
    wr_item.burst      = BURST_INCR;
    wr_item.lock       = default_lock;
    wr_item.cache      = default_cache;
    wr_item.prot       = 3'b100; // Normal, Secure, Instruction
    wr_item.wdata      = new[burst_len + 1];
    wr_item.wstrb      = new[burst_len + 1];
    foreach (wr_item.wdata[i]) begin
      wr_item.wdata[i] = 32'h1000_CAFE | i;
      wr_item.wstrb[i] = {STRB_WIDTH{1'b1}};
    end
    finish_item(wr_item);
    if (!wr_item.is_completed) @wr_item.done_event;

    if (wr_item.bresp == RESP_SLVERR) begin
      `uvm_info(get_type_name(),
        "[CHECK PASSED] Slave correctly blocked Normal Secure Instruction Write with SLVERR", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(),
        $sformatf("Expected SLVERR for Instruction Write (3'b100), but got %s", wr_item.bresp.name()))
    end
    tx_id++;

    // 2b. Normal Secure Instruction Read Attempt
    `uvm_create(rd_item)
    start_item(rd_item);
    rd_item.trans_type = AXI_READ;
    rd_item.id         = tx_id;
    rd_item.addr       = normal_mem_addr;
    rd_item.len        = burst_len;
    rd_item.size       = burst_size;
    rd_item.burst      = BURST_INCR;
    rd_item.lock       = default_lock;
    rd_item.cache      = default_cache;
    rd_item.prot       = 3'b100; // Normal, Secure, Instruction
    finish_item(rd_item);
    if (!rd_item.is_completed) @rd_item.done_event;

    foreach (rd_item.rresp[i]) begin
      if (rd_item.rresp[i] == RESP_SLVERR) begin
        `uvm_info(get_type_name(),
          $sformatf("[CHECK PASSED] Slave correctly blocked Normal Secure Instruction Read Beat %0d with SLVERR", i), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(),
          $sformatf("Expected SLVERR on Beat %0d for Instruction Read (3'b100), but got %s", i, rd_item.rresp[i].name()))
      end
    end
    tx_id++;

    // =========================================================================
    // Step 3: Authorized Preload of Secure Space (addr=0x4000, AxPROT=3'b001 Privileged Secure)
    // In RTL: (addr >= 0x4000) && (!prot[1] && prot[0]) -> Clean access with RESP_OKAY
    // =========================================================================
    `uvm_info(get_type_name(), "Step 3: Authorized Secure Preload (addr=0x4000, AxPROT=3'b001)", UVM_LOW)

    `uvm_create(wr_item)
    start_item(wr_item);
    wr_item.trans_type = AXI_WRITE;
    wr_item.id         = tx_id;
    wr_item.addr       = secure_peripheral_addr; // 0x4000
    wr_item.len        = burst_len;
    wr_item.size       = burst_size;
    wr_item.burst      = BURST_INCR;
    wr_item.lock       = default_lock;
    wr_item.cache      = default_cache;
    wr_item.prot       = 3'b001; // Secure (bit 1=0), Privileged (bit 0=1)
    wr_item.wdata      = new[burst_len + 1];
    wr_item.wstrb      = new[burst_len + 1];
    foreach (wr_item.wdata[i]) begin
      wr_item.wdata[i] = secure_golden_data | i;
      wr_item.wstrb[i] = {STRB_WIDTH{1'b1}};
    end
    finish_item(wr_item);
    if (!wr_item.is_completed) @wr_item.done_event;

    if (wr_item.bresp != RESP_OKAY) begin
      `uvm_error(get_type_name(), $sformatf("Authorized Secure Preload failed! BRESP=%s", wr_item.bresp.name()))
    end else begin
      `uvm_info(get_type_name(), "Authorized Secure Preload accepted by Slave with RESP_OKAY.", UVM_LOW)
    end
    tx_id++;

    // =========================================================================
    // Step 4: Unauthorized Access Attack on Secure Space (addr=0x4000, prot[1]=1 Non-Secure)
    // In RTL: (addr >= 0x4000) && (prot[1] || !prot[0]) -> err_prot_sec = 1
    // =========================================================================
    `uvm_info(get_type_name(), "Step 4: Unauthorized Non-Secure Write & Read Attack (addr=0x4000, AxPROT[1]=1)", UVM_LOW)

    // 4a. Unauthorized Non-Secure Write Attempt
    `uvm_create(wr_item)
    start_item(wr_item);
    wr_item.trans_type = AXI_WRITE;
    wr_item.id         = tx_id;
    wr_item.addr       = secure_peripheral_addr; // 0x4000
    wr_item.len        = burst_len;
    wr_item.size       = burst_size;
    wr_item.burst      = BURST_INCR;
    wr_item.lock       = default_lock;
    wr_item.cache      = default_cache;
    wr_item.prot       = 3'b010; // Non-Secure (bit 1=1) -> Blocked by firewall
    wr_item.wdata      = new[burst_len + 1];
    wr_item.wstrb      = new[burst_len + 1];
    foreach (wr_item.wdata[i]) begin
      wr_item.wdata[i] = 32'hDEAD_BEEF; // Hostile payload
      wr_item.wstrb[i] = {STRB_WIDTH{1'b1}};
    end
    finish_item(wr_item);
    if (!wr_item.is_completed) @wr_item.done_event;

    if (wr_item.bresp == RESP_SLVERR) begin
      `uvm_info(get_type_name(),
        $sformatf("[CHECK PASSED] RTL TrustZone Firewall blocked Non-Secure Write with %s", wr_item.bresp.name()), UVM_LOW)
    end else begin
      `uvm_error(get_type_name(),
        $sformatf("[SECURITY BREACH] Non-Secure Write was NOT blocked! Got BRESP=%s", wr_item.bresp.name()))
    end
    tx_id++;

    // 4b. Unauthorized Non-Secure Read Attempt
    `uvm_create(rd_item)
    start_item(rd_item);
    rd_item.trans_type = AXI_READ;
    rd_item.id         = tx_id;
    rd_item.addr       = secure_peripheral_addr; // 0x4000
    rd_item.len        = burst_len;
    rd_item.size       = burst_size;
    rd_item.burst      = BURST_INCR;
    rd_item.lock       = default_lock;
    rd_item.cache      = default_cache;
    rd_item.prot       = 3'b010; // Non-Secure (bit 1=1) -> Blocked by firewall
    finish_item(rd_item);
    if (!rd_item.is_completed) @rd_item.done_event;

    foreach (rd_item.rresp[i]) begin
      if (rd_item.rresp[i] == RESP_SLVERR) begin
        `uvm_info(get_type_name(),
          $sformatf("[CHECK PASSED] RTL TrustZone Firewall blocked Non-Secure Read Beat %0d with %s", i, rd_item.rresp[i].name()), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(),
          $sformatf("[SECURITY BREACH] Non-Secure Read was NOT blocked on Beat %0d! Got RRESP=%s", i, rd_item.rresp[i].name()))
      end
    end
    tx_id++;

    // =========================================================================
    // Step 5: Verify Secure Memory Invariance (addr=0x4000, prot=3'b001 Authorized)
    // =========================================================================
    `uvm_info(get_type_name(), "Step 5: Verifying Secure Peripheral Memory Invariance", UVM_LOW)

    `uvm_create(rd_item)
    start_item(rd_item);
    rd_item.trans_type = AXI_READ;
    rd_item.id         = tx_id;
    rd_item.addr       = secure_peripheral_addr; // 0x4000
    rd_item.len        = burst_len;
    rd_item.size       = burst_size;
    rd_item.burst      = BURST_INCR;
    rd_item.lock       = default_lock;
    rd_item.cache      = default_cache;
    rd_item.prot       = 3'b001; // Authorized Privileged Secure Read
    finish_item(rd_item);
    if (!rd_item.is_completed) @rd_item.done_event;

    foreach (rd_item.rdata[i]) begin
      bit [DATA_WIDTH-1:0] exp_val = secure_golden_data | i;
      if (rd_item.rdata[i] !== exp_val) begin
        `uvm_error("SECURE_MEMORY_CORRUPTED",
          $sformatf("Secure memory corrupted! Beat=%0d Exp=0x%08h Act=0x%08h", i, exp_val, rd_item.rdata[i]))
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("[CHECK PASSED] Secure memory beat %0d preserved: 0x%08h", i, rd_item.rdata[i]), UVM_HIGH)
      end
    end

    `uvm_info(get_type_name(), "=== AXI3_Prot_Privilege_Security_test Sequence Completed Successfully ===", UVM_LOW)
  endtask : body

endclass : axi3_prot_privilege_security_seq

// =============================================================================
// Class:    axi3_decerr_recovery_seq
// Base:     axi_base_seq
// Test Ref: AXI3_CTS_List Row 12: AXI3_Decerr_init_test (Spec A3.4.5)
// Flow:     Reuses write_burst_ext, read_burst_ext, and write_read_ping_pong
//           Phase 1: Normal Ping-Pong (0x1000 -> RESP_OKAY)
//           Phase 2: DECERR Injection  (0x8000 -> RESP_DECERR)
//           Phase 3: Normal Recovery   (0x2000 -> RESP_OKAY)
// =============================================================================
class axi3_decerr_recovery_seq extends axi_base_seq;
  `uvm_object_utils(axi3_decerr_recovery_seq)

  bit [ADDR_WIDTH-1:0] normal_addr_1 = 16'h1000;
  bit [ADDR_WIDTH-1:0] unmapped_addr  = 16'h8000; // >= 0x8000 triggers check_decerr in RTL
  bit [ADDR_WIDTH-1:0] normal_addr_2 = 16'h2000;

  function new(string name = "axi3_decerr_recovery_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -------------------------------------------------------------------------
    // 1. ALL DECLARATIONS FIRST (Uninitialized for QuestaSim vlog compliance)
    // -------------------------------------------------------------------------
    bit [ID_WIDTH-1:0]   tx_id;
    bit [LEN_WIDTH-1:0]  burst_len;
    bit [SIZE_WIDTH-1:0] burst_size;
    
    axi_resp_e           bresp_out;
    axi_resp_e           rresp_out[];
    bit [DATA_WIDTH-1:0] wdata_out[];
    bit [DATA_WIDTH-1:0] rdata_out[];

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL ASSIGNMENTS & INITIALIZATIONS
    // -------------------------------------------------------------------------
    tx_id      = 'h1;
    burst_len  = 4'd1;         // 2 beats
    burst_size = default_size; // 32-bit (4 bytes)

    `uvm_info(get_type_name(), "=== Starting Normal -> DECERR -> Normal Verification Sequence ===", UVM_LOW)

    // =========================================================================
    // PHASE 1: Normal Transfer (Reusing write_read_ping_pong)
    // =========================================================================
    `uvm_info(get_type_name(), "--- Phase 1: Normal Transfer at 0x1000 (Expect RESP_OKAY) ---", UVM_LOW)

    write_read_ping_pong(
      .wr_id     (tx_id),
      .rd_id     (tx_id + 'h10),
      .addr      (normal_addr_1),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .base_data (32'h1111_0000)
    );

    `uvm_info(get_type_name(), "[PHASE 1 PASS] Phase 1 Normal Transfer Completed", UVM_LOW)
    tx_id++;

    // =========================================================================
    // PHASE 2: DECERR Injection (Reusing write_burst_ext & read_burst_ext)
    // =========================================================================
    `uvm_info(get_type_name(), "--- Phase 2: Unmapped Hole Transfer at 0x8000 (Expect RESP_DECERR) ---", UVM_LOW)

    // 2a. Unmapped Write using write_burst_ext
    write_burst_ext(
      .id        (tx_id),
      .addr      (unmapped_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .base_data (32'hDEAD_BEEF),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    if (bresp_out == RESP_DECERR) begin
      `uvm_info(get_type_name(), "[PHASE 2 PASS] Unmapped Write returned BRESP=DECERR", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("[PHASE 2 FAIL] Expected BRESP=DECERR, got %s", bresp_out.name()))
    end

    // 2b. Unmapped Read using read_burst_ext
    read_burst_ext(
      .id        (tx_id + 'h10),
      .addr      (unmapped_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .rresp_out (rresp_out),
      .rdata_out (rdata_out)
    );

    foreach (rresp_out[i]) begin
      if (rresp_out[i] == RESP_DECERR) begin
        `uvm_info(get_type_name(), $sformatf("[PHASE 2 PASS] Unmapped Read beat %0d returned RRESP=DECERR", i), UVM_HIGH)
      end else begin
        `uvm_error(get_type_name(), $sformatf("[PHASE 2 FAIL] Beat %0d expected RRESP=DECERR, got %s", i, rresp_out[i].name()))
      end
    end
    tx_id++;

    // =========================================================================
    // PHASE 3: Recovery Normal Transfer (Reusing write_read_ping_pong)
    // =========================================================================
    `uvm_info(get_type_name(), "--- Phase 3: Post-DECERR Normal Recovery at 0x2000 (Expect RESP_OKAY) ---", UVM_LOW)

    write_read_ping_pong(
      .wr_id     (tx_id),
      .rd_id     (tx_id + 'h10),
      .addr      (normal_addr_2),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .base_data (32'h2222_0000)
    );

    `uvm_info(get_type_name(), "[PHASE 3 PASS] Recovery Normal Transfer Completed Cleanly", UVM_LOW)
    `uvm_info(get_type_name(), "=== Normal -> DECERR -> Normal Flow Completed Successfully ===", UVM_LOW)
  endtask : body

endclass : axi3_decerr_recovery_seq

class axi3_4kb_boundary_seq extends axi_base_seq;
  `uvm_object_utils(axi3_4kb_boundary_seq)

  bit [ADDR_WIDTH-1:0] legal_near_4k_addr = 16'h0FC0;
  bit [ADDR_WIDTH-1:0] illegal_cross_addr = 16'h0FE0;
  bit [ADDR_WIDTH-1:0] recovery_addr      = 16'h2000;

  function new(string name = "axi3_4kb_boundary_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [ID_WIDTH-1:0]   tx_id;
    bit [LEN_WIDTH-1:0]  burst_len;
    bit [SIZE_WIDTH-1:0] burst_size;
    axi_resp_e           bresp_out;
    axi_resp_e           rresp_out[];
    bit [DATA_WIDTH-1:0] wdata_out[];
    bit [DATA_WIDTH-1:0] rdata_out[];

    tx_id      = 'h1;
    burst_len  = 4'd15;
    burst_size = default_size;

    `uvm_info(get_type_name(), "=== Starting AXI3_4KB_Boundary_test Sequence (Spec A3.4.1) ===", UVM_LOW)

    `uvm_info(get_type_name(), 
      $sformatf("Step 1: Driving Legal Near-4KB Write/Read (Addr=0x%04h, Len=%0d, Size=%0d)",
      legal_near_4k_addr, burst_len, burst_size), UVM_LOW)

    write_burst_ext(
      .id        (tx_id),
      .addr      (legal_near_4k_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .base_data (32'h4B00_0000),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    if (bresp_out == RESP_OKAY) begin
      `uvm_info(get_type_name(), "[STEP 1 PASS] Legal Near-4KB Write accepted with BRESP=OKAY", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("[STEP 1 FAIL] Expected BRESP=OKAY, got %s", bresp_out.name()))
    end

    read_burst_ext(
      .id        (tx_id + 'h10),
      .addr      (legal_near_4k_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .rresp_out (rresp_out),
      .rdata_out (rdata_out)
    );

    foreach (rresp_out[i]) begin
      if (rresp_out[i] == RESP_OKAY) begin
        `uvm_info(get_type_name(), $sformatf("[STEP 1 PASS] Legal Near-4KB Read beat %0d returned RRESP=OKAY", i), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), $sformatf("[STEP 1 FAIL] Beat %0d expected RRESP=OKAY, got %s", i, rresp_out[i].name()))
      end
    end
    tx_id++;

    `uvm_info(get_type_name(), 
      $sformatf("Step 2: Injecting Illegal 4KB Boundary Crossing (Addr=0x%04h, Len=%0d)",
      illegal_cross_addr, burst_len), UVM_LOW)

    write_burst_ext(
      .id        (tx_id),
      .addr      (illegal_cross_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .base_data (32'hBAD0_0000),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    if (bresp_out == RESP_SLVERR) begin
      `uvm_info(get_type_name(), 
        "[STEP 2 CHECK PASSED] Slave correctly blocked 4KB boundary write violation with SLVERR", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), 
        $sformatf("[STEP 2 FAIL] Expected SLVERR for 4KB boundary crossing, but got %s", bresp_out.name()))
    end

    read_burst_ext(
      .id        (tx_id + 'h10),
      .addr      (illegal_cross_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (default_lock),
      .rresp_out (rresp_out),
      .rdata_out (rdata_out)
    );

    foreach (rresp_out[i]) begin
      if (rresp_out[i] == RESP_SLVERR) begin
        `uvm_info(get_type_name(), 
          $sformatf("[STEP 2 CHECK PASSED] Read beat %0d correctly blocked with SLVERR", i), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), 
          $sformatf("[STEP 2 FAIL] Read beat %0d expected SLVERR, got %s", i, rresp_out[i].name()))
      end
    end
    tx_id++;

    `uvm_info(get_type_name(), "Step 3: Verifying clean bus pipeline recovery after 4KB violation", UVM_LOW)

    write_read_ping_pong(
      .wr_id     (tx_id),
      .rd_id     (tx_id + 'h10),
      .addr      (recovery_addr),
      .len       (4'd3),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .base_data (32'h2222_0000)
    );

    `uvm_info(get_type_name(), "=== AXI3_4KB_Boundary_test Sequence Completed Successfully ===", UVM_LOW)
  endtask : body

endclass : axi3_4kb_boundary_seq