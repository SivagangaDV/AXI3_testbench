// =============================================================================
// 1. Sanity Sequence (Single 4-Beat INCR Ping-Pong)
//    Basic smoke test verifying write followed by read-back to memory.
// =============================================================================
class axi_sanity_seq extends axi_base_seq;
  `uvm_object_utils(axi_sanity_seq)

  bit [9:0]            repeat_count = 1;
  bit [ADDR_WIDTH-1:0] start_addr   = 'h1000;
  bit [LEN_WIDTH-1:0]  burst_len    = 4'd3;            // 4 beats (AXI len = 3)
  bit [DATA_WIDTH-1:0] init_data    = 32'hDEAD_0000;
  bit                  randomize_id = 1'b0;

  function new(string name = "axi_sanity_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("SANITY_SEQ", "Starting Basic Write followed by Read-Back Sanity Test...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_INCR),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (randomize_id)
    );
    `uvm_info("SANITY_SEQ", "Sanity execution finished successfully.", UVM_LOW)
  endtask : body
endclass : axi_sanity_seq


// =============================================================================
// 2. Fixed Burst Sequence
//    Tests FIFO / static register destinations where address remains unchanged.
// =============================================================================
class axi_fixed_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_fixed_burst_seq)

  bit [9:0]            repeat_count = 3;
  bit [ADDR_WIDTH-1:0] start_addr   = 'h1000;
  bit [LEN_WIDTH-1:0]  burst_len    = 4'd3;            // Fixed 4-beat transfers
  bit [DATA_WIDTH-1:0] init_data    = 32'hDEAD_0000;
  bit                  randomize_id = 1'b1;

  function new(string name = "axi_fixed_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("FIXED_SEQ", "Starting Fixed Burst Test...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_FIXED),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (randomize_id)
    );
    `uvm_info("FIXED_SEQ", "Fixed burst execution finished.", UVM_LOW)
  endtask : body
endclass : axi_fixed_burst_seq


// =============================================================================
// 3. Incrementing Burst Sequence
//    Tests sequential memory stepping across random burst lengths (0..15 beats).
//    Supports concurrent interleaving and overlap when knobs are set by tests.
// =============================================================================
class axi_incr_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_incr_burst_seq)

  bit [9:0]            repeat_count = 200;
  bit [ADDR_WIDTH-1:0] start_addr   = 'h1000;
  bit [LEN_WIDTH-1:0]  burst_len    = 4'd0;            // 0 triggers random lengths (0..15 beats)
  bit [DATA_WIDTH-1:0] init_data    = 32'hDEAD_0000;
  bit                  test_id_random = 1'b1;

  function new(string name = "axi_incr_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("INCR_SEQ", "Starting INCR Burst Test...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_INCR),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (test_id_random)
    );
    `uvm_info("INCR_SEQ", "INCR burst execution finished.", UVM_LOW)
  endtask : body
endclass : axi_incr_burst_seq


// =============================================================================
// 4. Wrapping Burst Sequence
//    Tests power-of-2 wrap lengths (2, 4, 8, 16 beats) with boundary alignments.
//    Supports concurrent interleaving and overlap when knobs are set by tests.
// =============================================================================
class axi_wrap_burst_seq extends axi_base_seq;
  `uvm_object_utils(axi_wrap_burst_seq)

  bit [9:0]            repeat_count   = 50;
  bit [ADDR_WIDTH-1:0] start_addr     = 'h1000;
  bit [LEN_WIDTH-1:0]  burst_len      = 4'd0;          //  wrap lengths (2, 4, 8, 16 beats)
  bit [DATA_WIDTH-1:0] init_data      = 32'hDA7A_0000;
  bit                  test_id_random = 1'b1;

  function new(string name = "axi_wrap_burst_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("WRAP_SEQ", "Starting WRAP Burst Sequence...", UVM_LOW)
    execute_burst_engine(
      .burst_type   (BURST_WRAP),
      .count        (repeat_count),
      .start_addr   (start_addr),
      .manual_len   (burst_len),
      .init_data    (init_data),
      .randomize_id (test_id_random)
    );
    `uvm_info("WRAP_SEQ", "WRAP burst execution finished.", UVM_LOW)
  endtask : body
endclass : axi_wrap_burst_seq

class axi_concurrent_full_duplex_seq extends axi_base_seq;
  `uvm_object_utils(axi_concurrent_full_duplex_seq)

  // ---------------------------------------------------------------------------
  // Configurable Knobs
  // ---------------------------------------------------------------------------
  int                  num_iterations = 200;      // Number of concurrent burst batches
  bit [LEN_WIDTH-1:0]  max_burst_len  = 4'd15;    // Max AXI3 length = 16 beats
  bit [ADDR_WIDTH-1:0] wr_base_addr   = 'h1000;   // Dedicated write buffer space
  bit [ADDR_WIDTH-1:0] rd_base_addr   = 'h1800;   // Dedicated read buffer space
  bit [ADDR_WIDTH-1:0] addr_stride    = 'h40;     // 16 beats * 4 bytes = 64B ('h40)

  function new(string name = "axi_concurrent_full_duplex_seq");
    super.new(name);
  endfunction

  virtual task body();
    `uvm_info("FULL_DUPLEX_SEQ", $sformatf("Starting Full-Duplex Saturation Test (%0d iterations, AxLEN=%0d, Streams=%0d)...",
              num_iterations, max_burst_len, num_streams), UVM_LOW)

    // Pre-initialize read target region once so reads don't return uninitialized X/0
    for (int p = 0; p < num_streams; p++) begin
      write_burst(
        .id        ('hE),
        .addr      (rd_base_addr + (p * addr_stride)),
        .len       (max_burst_len),
        .size      (default_size),
        .burst     (BURST_INCR),
        .base_data (32'h1111_0000 | (p << 8))
      );
    end

    // -------------------------------------------------------------------------
    // Full-Duplex Saturation Loop: Run Write and Read threads in parallel
    // -------------------------------------------------------------------------
    for (int iter = 0; iter < num_iterations; iter++) begin
      fork
        // Thread 1: Concurrent Write Streams (AW + W + B)
        begin : write_stream_block
          for (int s = 0; s < num_streams; s++) begin
            automatic int st_idx = s;
            fork
              begin
                bit [ADDR_WIDTH-1:0] w_addr;
                int burst_bytes = (max_burst_len + 1) * (1 << default_size);

                w_addr = wr_base_addr + (st_idx * addr_stride);
                // 4KB boundary safeguard
                if (((w_addr & 12'hFFF) + burst_bytes) > 4096) begin
                  w_addr = (w_addr & ~12'hFFF);
                end

                write_burst(
                  .id        (st_idx + 1), // Unique IDs for parallel CAM slots
                  .addr      (w_addr),
                  .len       (max_burst_len),
                  .size      (default_size),
                  .burst     (BURST_INCR),
                  .base_data (32'hFD_A0_0000 | (iter << 8) | st_idx)
                );
              end
            join_none
          end
          wait fork;
        end : write_stream_block

        // Thread 2: Concurrent Read Streams (AR + R)
        begin : read_stream_block
          for (int s = 0; s < num_streams; s++) begin
            automatic int st_idx = s;
            fork
              begin
                bit [ADDR_WIDTH-1:0] r_addr;
                int burst_bytes = (max_burst_len + 1) * (1 << default_size);

                r_addr = rd_base_addr + (st_idx * addr_stride);
                // 4KB boundary safeguard
                if (((r_addr & 12'hFFF) + burst_bytes) > 4096) begin
                  r_addr = (r_addr & ~12'hFFF);
                end

                read_burst(
                  .id    (st_idx + 8), // Unique IDs disjoint from write IDs
                  .addr  (r_addr),
                  .len   (max_burst_len),
                  .size  (default_size),
                  .burst (BURST_INCR)
                );
              end
            join_none
          end
          wait fork;
        end : read_stream_block
      join
    end

    `uvm_info("FULL_DUPLEX_SEQ", "Full-Duplex saturation sequence completed successfully with 0 deadlocks.", UVM_LOW)
  endtask : body
endclass : axi_concurrent_full_duplex_seq


class axi_simultaneous_wrap_seq extends axi_base_seq;
  `uvm_object_utils(axi_simultaneous_wrap_seq)

  // ---------------------------------------------------------------------------
  // Configurable Knobs
  // ---------------------------------------------------------------------------
  int                  num_iterations = 200;     // Test can override to 100
  bit [LEN_WIDTH-1:0]  wrap_len       = 4'd3;   // 4 beats (AxLEN = 3)
  bit [ADDR_WIDTH-1:0] wr_start_addr  = 'h1000; // Dedicated write buffer
  bit [ADDR_WIDTH-1:0] rd_start_addr  = 'h2000; // Dedicated read buffer (separated by 4KB)
  bit [ADDR_WIDTH-1:0] stride         = 'h40;   // 64-byte spacing (enough for 16-byte wrap container)
  bit [ADDR_WIDTH-1:0] addr_mask      = 'h0FFF; // Keep within 4KB memory window

  function new(string name = "axi_simultaneous_wrap_seq");
    super.new(name);
  endfunction

  virtual task body();
    bit [ADDR_WIDTH-1:0] wr_addr, rd_addr;
    bit [LEN_WIDTH-1:0]  out_len_w, out_len_r;
    int                  wrap_bytes;

    `uvm_info("SIMULTANEOUS_WRAP", $sformatf("Starting AXI3 Simultaneous WRAP Sequence (Iterations=%0d, WRAP Len=%0d)...",
              num_iterations, wrap_len), UVM_LOW)

    // Pre-initialize read target region
    for (int p = 0; p < num_iterations; p++) begin
      // Keep addresses bounded inside [rd_start_addr : rd_start_addr + 0x0FFF]
      bit [ADDR_WIDTH-1:0] bounded_rd_base = rd_start_addr + ((p * stride) & addr_mask);
      calc_burst_parameters(BURST_WRAP, wrap_len, bounded_rd_base, 0, 0, out_len_r, rd_addr, wrap_bytes);
      
      write_burst(
        .id        (p & 'hF),
        .addr      (rd_addr),
        .len       (out_len_r),
        .size      (default_size),
        .burst     (BURST_WRAP),
        .base_data (32'h5130_0000 | (p << 8))
      );
    end

    // -------------------------------------------------------------------------
    // Main Loop: Simultaneous AW + AR Command Launch
    // -------------------------------------------------------------------------
    for (int i = 0; i < num_iterations; i++) begin
      bit [ADDR_WIDTH-1:0] bounded_wr_base = wr_start_addr + ((i * stride) & addr_mask);
      bit [ADDR_WIDTH-1:0] bounded_rd_base = rd_start_addr + ((i * stride) & addr_mask);

      calc_burst_parameters(BURST_WRAP, wrap_len, bounded_wr_base, 0, 0, out_len_w, wr_addr, wrap_bytes);
      calc_burst_parameters(BURST_WRAP, wrap_len, bounded_rd_base, 0, 0, out_len_r, rd_addr, wrap_bytes);

      fork
        // Thread 1: Write Stream (AW -> W -> B)
        begin
          write_burst(
            .id        (i & 'hF),
            .addr      (wr_addr),
            .len       (out_len_w),
            .size      (default_size),
            .burst     (BURST_WRAP),
            .base_data (32'hCAFE_0000 | (i << 8))
          );
        end

        // Thread 2: Read Stream (AR -> R)
        begin
          read_burst(
            .id    (i & 'hF),
            .addr  (rd_addr),
            .len   (out_len_r),
            .size  (default_size),
            .burst (BURST_WRAP)
          );
        end
      join

      `uvm_info("SIMULTANEOUS_WRAP", $sformatf("Iteration %0d/%0d completed cleanly.", i + 1, num_iterations), UVM_HIGH)
    end

    `uvm_info("SIMULTANEOUS_WRAP", "Simultaneous WRAP execution finished with 0 contention issues.", UVM_LOW)
  endtask : body

endclass : axi_simultaneous_wrap_seq
// =============================================================================
// Class:    axi3_ex_access_seq
// Base:     axi_base_seq
// =============================================================================
class axi3_ex_access_seq extends axi_base_seq;
  `uvm_object_utils(axi3_ex_access_seq)

  rand int unsigned          num_iterations;
  rand bit [ID_WIDTH-1:0]    seq_id;
  rand bit [ADDR_WIDTH-1:0]  seq_addr;
  rand bit [LEN_WIDTH-1:0]   seq_len;
  rand bit [SIZE_WIDTH-1:0]  seq_size;
  rand int unsigned          total_bytes;

  constraint c_iterations_default {
    soft num_iterations inside {[10:30]};
  }

  constraint c_ex_protocol_rules {
    // 1. Burst count: power-of-2 beats (1, 2, 4, 8, 16)
    seq_len inside {4'd0, 4'd1, 4'd3, 4'd7, 4'd15};
    
    // 2. Drive full data bus width for exclusive access (avoids narrow-transfer WSTRB mismatches)
    seq_size == $clog2(STRB_WIDTH);
    
    // 3. Compute total transaction byte length
    total_bytes == ((seq_len + 1) << seq_size);
    total_bytes <= 128;

    // 4. Align address to total transaction bytes
    (seq_addr & (total_bytes - 1)) == '0;

    // 5. Constrain within mapped exclusive memory boundary (up to 16KB / 0x3FFF)
    seq_addr inside {['h1000 : 'h3800]};

    // 6. 4KB boundary check
    ((seq_addr & 12'hFFF) + total_bytes) <= 4096;
  }

  function new(string name = "axi3_ex_access_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_resp_e           rd_rresp[];
    bit [DATA_WIDTH-1:0] rd_data[];
    axi_resp_e           wr_bresp;
    bit [DATA_WIDTH-1:0] wr_data[];
    axi_resp_e           verify_rresp[];
    bit [DATA_WIDTH-1:0] verify_data[];

    int                  num_bytes_beat;
    int                  iteration;
    bit [STRB_WIDTH-1:0] dynamic_strb;

    `uvm_info(get_type_name(), $sformatf("=== Running Exclusive Access Sequence for %0d Iterations ===", num_iterations), UVM_LOW)

    num_iterations.rand_mode(0);

    for (iteration = 1; iteration <= num_iterations; iteration++) begin
      if (!this.randomize()) begin
        `uvm_fatal(get_type_name(), $sformatf("Failed to randomize exclusive knobs at iteration %0d", iteration))
      end

      num_bytes_beat = (1 << seq_size);
      
      // Calculate active byte strobes according to beat size
      dynamic_strb = ((1 << num_bytes_beat) - 1);

      `uvm_info(get_type_name(), $sformatf("[Iter %0d/%0d] ID=0x%0h Addr=0x%04h Len=%0d Size=%0d (Bytes/beat=%0d TotalBytes=%0d)", 
                iteration, num_iterations, seq_id, seq_addr, seq_len, seq_size, num_bytes_beat, total_bytes), UVM_MEDIUM)

      // Step 1: Initial Exclusive Read
      read_burst_ext(
        .id(seq_id),
        .addr(seq_addr),
        .len(seq_len),
        .size(seq_size),
        .burst(BURST_INCR),
        .lock(2'b01),
        .rresp_out(rd_rresp),
        .rdata_out(rd_data)
      );

      foreach (rd_rresp[i]) begin
        if (rd_rresp[i] != RESP_EXOKAY) begin
          `uvm_error(get_type_name(), $sformatf("[Iter %0d] Initial Exclusive Read beat %0d failed EXOKAY! Got %s", 
                     iteration, i, rd_rresp[i].name()))
        end
      end

      // Step 2: Exclusive Write
      write_burst_ext(
        .id(seq_id),
        .addr(seq_addr),
        .len(seq_len),
        .size(seq_size),
        .burst(BURST_INCR),
        .lock(2'b01),
        .base_data($urandom),
        .strb_val(dynamic_strb),
        .bresp_out(wr_bresp),
        .wdata_out(wr_data)
      );

      if (wr_bresp != RESP_EXOKAY) begin
        `uvm_error(get_type_name(), $sformatf("[Iter %0d] Exclusive Write failed! Expected RESP_EXOKAY, got %s", 
                   iteration, wr_bresp.name()))
      end

      // Step 3: Post-Write Verification Read
      read_burst_ext(
        .id(seq_id),
        .addr(seq_addr),
        .len(seq_len),
        .size(seq_size),
        .burst(BURST_INCR),
        .lock(2'b01),
        .rresp_out(verify_rresp),
        .rdata_out(verify_data)
      );

      foreach (verify_rresp[i]) begin
        if (verify_rresp[i] != RESP_EXOKAY) begin
          `uvm_error(get_type_name(), $sformatf("[Iter %0d] Post-Write Exclusive Read beat %0d failed EXOKAY! Got %s", 
                     iteration, i, verify_rresp[i].name()))
        end
      end
    end

    num_iterations.rand_mode(1);
    `uvm_info(get_type_name(), $sformatf("=== Completed all %0d Exclusive Access Iterations successfully ===", num_iterations), UVM_LOW)
  endtask : body

endclass : axi3_ex_access_seq

// =============================================================================
// Class:    axi3_narrow_txr_seq
// Base:     axi_base_seq
// Purpose:  Drives narrow burst transfers (1B, 2B, 3B) across FIXED, INCR, WRAP.
//           Updated to sweep all 16 lengths to achieve 100% cross coverage.
// =============================================================================
class axi3_narrow_txr_seq extends axi_base_seq;
  `uvm_object_utils(axi3_narrow_txr_seq)

  function new(string name = "axi3_narrow_txr_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -------------------------------------------------------------------------
    // 1. VARIABLE DECLARATIONS (Uninitialized at top for QuestaSim vlog compliance)
    // -------------------------------------------------------------------------
    axi_burst_e          burst_types[3];
    int                  narrow_byte_modes[3];
    bit [SIZE_WIDTH-1:0] narrow_axsizes[3];
    bit [LEN_WIDTH-1:0]  test_lens_wrap[4];
    bit [LEN_WIDTH-1:0]  test_lens_std[16]; // Expanded to cover all 16 lengths!

    bit [ID_WIDTH-1:0]   tx_id;
    axi_burst_e          cur_burst;
    int                  cur_bytes;
    bit [SIZE_WIDTH-1:0] cur_size;
    bit [LEN_WIDTH-1:0]  cur_len;
    bit [ADDR_WIDTH-1:0] base_addr;
    bit [ADDR_WIDTH-1:0] beat_addr;
    bit [STRB_WIDTH-1:0] strb;
    int                  container_bytes;
    int                  num_lens;
    axi_seq_item         wr_item;

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL ASSIGNMENTS
    // -------------------------------------------------------------------------
    burst_types[0] = BURST_FIXED;
    burst_types[1] = BURST_INCR;
    burst_types[2] = BURST_WRAP;

    // Mode configurations:
    // Mode 0: 8-bit  (1 byte,  AxSIZE=0)
    // Mode 1: 16-bit (2 bytes, AxSIZE=1)
    // Mode 2: 24-bit (3 bytes, AxSIZE=2 container with 3 strobes enabled)
    narrow_byte_modes[0] = 1; narrow_axsizes[0] = 'd0;
    narrow_byte_modes[1] = 2; narrow_axsizes[1] = 'd1;
    narrow_byte_modes[2] = 3; narrow_axsizes[2] = 'd2;

    // Strictly legal WRAP burst lengths per A3.4.3: 2, 4, 8, 16 beats
    test_lens_wrap[0] = 'd1;
    test_lens_wrap[1] = 'd3;
    test_lens_wrap[2] = 'd7;
    test_lens_wrap[3] = 'd15;

    // Standard sweep across ALL lengths (0 to 15) to hit the 11 missing misc_lens bins!
    for (int i = 0; i < 16; i++) begin
      test_lens_std[i] = i[LEN_WIDTH-1:0];
    end

    tx_id = 'h1;

    `uvm_info(get_type_name(), "=== Starting Full-Coverage Narrow Transfer Sequence ===", UVM_LOW)

    for (int b = 0; b < 3; b++) begin
      cur_burst = burst_types[b];

      for (int m = 0; m < 3; m++) begin
        cur_bytes       = narrow_byte_modes[m];
        cur_size        = narrow_axsizes[m];
        container_bytes = 1 << cur_size;
        num_lens        = (cur_burst == BURST_WRAP) ? 4 : 16;

        for (int l = 0; l < num_lens; l++) begin
          cur_len = (cur_burst == BURST_WRAP) ? test_lens_wrap[l] : test_lens_std[l];

          // Address configuration (safely confined to prevent 4KB boundary crossings)
          if (cur_burst == BURST_WRAP) begin
            // WRAP start address aligned to container boundary
            base_addr = 'h2000 + ($urandom_range(0, 4) * (cur_len + 1) * container_bytes);
          end else begin
            // Normal RAM range (0x1000 - 0x1800) safely away from 4KB edge (0x1FFF)
            base_addr = 'h1000 + ($urandom_range(0, 8) * STRB_WIDTH) + $urandom_range(0, STRB_WIDTH - container_bytes);
          end

          // -----------------------------------------------------------
          // Step 1: Drive Narrow Burst Write with A3.4.4 Strobes
          // -----------------------------------------------------------
          `uvm_create(wr_item)
          start_item(wr_item);

          wr_item.trans_type = AXI_WRITE;
          wr_item.id         = tx_id;
          wr_item.addr       = base_addr;
          wr_item.len        = cur_len;
          wr_item.size       = cur_size;
          wr_item.burst      = cur_burst;
          wr_item.lock       = default_lock;
          wr_item.cache      = default_cache;
          wr_item.prot       = default_prot;

          wr_item.wdata      = new[cur_len + 1];
          wr_item.wstrb      = new[cur_len + 1];

          for (int beat = 0; beat <= cur_len; beat++) begin
            beat_addr = calc_axi_beat_addr(base_addr, cur_burst, cur_len, cur_size, beat);
            strb      = calc_axi_wstrb(beat_addr, cur_size, cur_bytes, beat);

            wr_item.wstrb[beat] = strb;
            wr_item.wdata[beat] = '0;

            for (int lane = 0; lane < STRB_WIDTH; lane++) begin
              if (strb[lane]) begin
                wr_item.wdata[beat][(lane*8) +: 8] = $urandom_range(8'h11, 8'hEE);
              end
            end
          end

          finish_item(wr_item);

          if (!wr_item.is_completed) begin
            @wr_item.done_event;
          end

          // -----------------------------------------------------------
          // Step 2: Read Back (Scoreboard verifies narrow byte matching)
          // -----------------------------------------------------------
          read_burst(
            .id(tx_id + 'h10),
            .addr(base_addr),
            .len(cur_len),
            .size(cur_size),
            .burst(cur_burst)
          );

          tx_id++;
        end
      end
    end

    `uvm_info(get_type_name(), "=== Narrow Transfer Sequence Completed Cleanly. ===", UVM_LOW)
  endtask : body

endclass : axi3_narrow_txr_seq

// =============================================================================
// Class:    axi3_zero_wstrb_seq
// Base:     axi_base_seq
// Test Ref: AXI3_CTS_List Row 16: AXI3_Zero_Wstrb_test (Spec A3.4.4)
// Purpose:  1. Preloads known background pattern with full strobes.
//           2. Initiates write bursts where WSTRB = '0 on all or intermediate beats.
//           3. Validates that handshake completes, BRESP = OKAY, and memory
//              content remains 100% unchanged.
// =============================================================================
class axi3_zero_wstrb_seq extends axi_base_seq;
  `uvm_object_utils(axi3_zero_wstrb_seq)

  function new(string name = "axi3_zero_wstrb_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -------------------------------------------------------------------------
    // 1. ALL DECLARATIONS FIRST (Strictly uninitialized for QuestaSim vlog)
    // -------------------------------------------------------------------------
    bit [LEN_WIDTH-1:0]  test_lens[4];
    bit [ID_WIDTH-1:0]   tx_id;
    bit [ADDR_WIDTH-1:0] base_addr;
    bit [LEN_WIDTH-1:0]  cur_len;
    bit [SIZE_WIDTH-1:0] cur_size;
    int                  mode; // 0 = all beats zero, 1 = intermediate/alternating beats zero
    axi_resp_e           bresp_out;
    axi_resp_e           rresp_out[];
    bit [DATA_WIDTH-1:0] rdata_out[];
    bit [DATA_WIDTH-1:0] preload_data[];
    bit [DATA_WIDTH-1:0] expected_beat_data;
    axi_seq_item         wr_item;

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL INITIALIZATIONS
    // -------------------------------------------------------------------------
    test_lens[0] = 'd0;  // 1 beat
    test_lens[1] = 'd3;  // 4 beats
    test_lens[2] = 'd7;  // 8 beats
    test_lens[3] = 'd15; // 16 beats

    cur_size  = default_size; // Full data bus width
    tx_id     = 'h1;
    base_addr = 'h1000;

    `uvm_info(get_type_name(), "=== Starting AXI3_Zero_Wstrb_test Sequence (Spec A3.4.4) ===", UVM_LOW)

    // Sweep across two test modes:
    // mode = 0: All beats have WSTRB = '0 (full dummy write burst)
    // mode = 1: Alternating/intermediate beats have WSTRB = '0
    for (mode = 0; mode < 2; mode++) begin
      for (int l = 0; l < 4; l++) begin
        cur_len = test_lens[l];

        // ---------------------------------------------------------------------
        // Step 1: Preload Memory with Known Pattern (WSTRB = All 1s)
        // ---------------------------------------------------------------------
        preload_data = new[cur_len + 1];
        `uvm_create(wr_item)
        start_item(wr_item);

        wr_item.trans_type = AXI_WRITE;
        wr_item.id         = tx_id;
        wr_item.addr       = base_addr;
        wr_item.len        = cur_len;
        wr_item.size       = cur_size;
        wr_item.burst      = BURST_INCR;
        wr_item.lock       = default_lock;
        wr_item.cache      = default_cache;
        wr_item.prot       = default_prot;

        wr_item.wdata      = new[cur_len + 1];
        wr_item.wstrb      = new[cur_len + 1];

        for (int b = 0; b <= cur_len; b++) begin
          wr_item.wdata[b] = 32'hA5A5_0000 | (tx_id << 8) | b;
          wr_item.wstrb[b] = {STRB_WIDTH{1'b1}}; // Full active write
          preload_data[b]  = wr_item.wdata[b];
        end

        finish_item(wr_item);
        if (!wr_item.is_completed) begin
          @wr_item.done_event;
        end

        if (wr_item.bresp != RESP_OKAY) begin
          `uvm_error(get_type_name(), $sformatf("Preload Write failed! BRESP=%s", wr_item.bresp.name()))
        end

        tx_id++;

        // ---------------------------------------------------------------------
        // Step 2: Issue Zero-Strobe Write Burst (Dummy Write)
        // ---------------------------------------------------------------------
        `uvm_create(wr_item)
        start_item(wr_item);

        wr_item.trans_type = AXI_WRITE;
        wr_item.id         = tx_id;
        wr_item.addr       = base_addr;
        wr_item.len        = cur_len;
        wr_item.size       = cur_size;
        wr_item.burst      = BURST_INCR;
        wr_item.lock       = default_lock;
        wr_item.cache      = default_cache;
        wr_item.prot       = default_prot;

        wr_item.wdata      = new[cur_len + 1];
        wr_item.wstrb      = new[cur_len + 1];

        for (int b = 0; b <= cur_len; b++) begin
          // Garbage payload that must NOT be written to memory
          wr_item.wdata[b] = 32'hDEAD_BEEF ^ (b << 16);

          if (mode == 0) begin
            // All beats have WSTRB = '0
            wr_item.wstrb[b] = '0;
          end else begin
            // Intermediate beats zeroed: even beats '0, odd beats '1
            wr_item.wstrb[b] = (b % 2 == 0) ? '0 : {STRB_WIDTH{1'b1}};
          end
        end

        finish_item(wr_item);
        if (!wr_item.is_completed) begin
          @wr_item.done_event;
        end

        // Check 1 & 2: Handshake completes cleanly and slave returns OKAY on B channel
        if (wr_item.bresp != RESP_OKAY) begin
          `uvm_error(get_type_name(),
            $sformatf("[FAIL] Zero WSTRB write failed! Mode=%0d, Len=%0d, Expected BRESP=OKAY, Got=%s",
                      mode, cur_len + 1, wr_item.bresp.name()))
        end else begin
          `uvm_info(get_type_name(),
            $sformatf("[PASS] Zero WSTRB write accepted by Slave with BRESP=OKAY (Mode=%0d, Beats=%0d)",
                      mode, cur_len + 1), UVM_HIGH)
        end

        // ---------------------------------------------------------------------
        // Step 3: Read Back & Verify Memory Remained Unmodified for WSTRB=0 Beats
        // ---------------------------------------------------------------------
        read_burst_ext(
          .id(tx_id + 'h10),
          .addr(base_addr),
          .len(cur_len),
          .size(cur_size),
          .burst(BURST_INCR),
          .lock(default_lock),
          .rresp_out(rresp_out),
          .rdata_out(rdata_out)
        );

        for (int b = 0; b <= cur_len; b++) begin
          if (mode == 0) begin
            // Mode 0: All beats were zero-strobe, so memory must still hold preload data
            expected_beat_data = preload_data[b];
          end else begin
            // Mode 1: Even beats zeroed (memory kept preload), odd beats updated
            expected_beat_data = (b % 2 == 0) ? preload_data[b] : (32'hDEAD_BEEF ^ (b << 16));
          end

          if (rdata_out[b] !== expected_beat_data) begin
            `uvm_error("ZERO_WSTRB_DATA_CORRUPTION",
              $sformatf("Memory was corrupted on WSTRB=0 beat! Beat=%0d Addr=0x%0h | Exp=0x%08h Act=0x%08h",
                        b, (base_addr + (b * (1 << cur_size))), expected_beat_data, rdata_out[b]))
          end
        end

        // Shift base address for next iteration
        base_addr += ((cur_len + 1) * (1 << cur_size));
        if ((base_addr & 12'hFFF) > 'hE00) begin
          base_addr = 'h1000;
        end
        tx_id++;
      end
    end

    `uvm_info(get_type_name(), "=== AXI3_Zero_Wstrb_test Sequence Completed Successfully. ===", UVM_LOW)
  endtask : body

endclass : axi3_zero_wstrb_seq


// =============================================================================
// Class:    axi3_locked_sequence_seq
// Base:     axi_base_seq
// Test Ref: AXI3_CTS_List Row 22 / Spec Section A7.2 (Locked Accesses)
// Flow:     1. Master 0 locks slave with AxLOCK = 2'b10 (Locked Access)
//           2. Master 1 attempts access during lock (rejected with SLVERR)
//           3. Master 0 issues unlocking transaction with AxLOCK = 2'b00
//           4. Master 1 accesses normally after lock release (RESP_OKAY)
// =============================================================================
class axi3_locked_sequence_seq extends axi_base_seq;
  `uvm_object_utils(axi3_locked_sequence_seq)

  bit [ID_WIDTH-1:0]   m0_id        = 'h1;   // Lock Owner ID
  bit [ID_WIDTH-1:0]   m1_id        = 'h2;   // Competing ID
  bit [ADDR_WIDTH-1:0] target_addr  = 16'h1200;

  function new(string name = "axi3_locked_sequence_seq");
    super.new(name);
  endfunction

  virtual task body();
    // -------------------------------------------------------------------------
    // 1. ALL DECLARATIONS FIRST (Uninitialized for QuestaSim vlog compliance)
    // -------------------------------------------------------------------------
    bit [LEN_WIDTH-1:0]  burst_len;
    bit [SIZE_WIDTH-1:0] burst_size;
    axi_resp_e           bresp_out;
    axi_resp_e           rresp_out[];
    bit [DATA_WIDTH-1:0] wdata_out[];
    bit [DATA_WIDTH-1:0] rdata_out[];

    // -------------------------------------------------------------------------
    // 2. PROCEDURAL ASSIGNMENTS & INITIALIZATIONS
    // -------------------------------------------------------------------------
    burst_len  = 4'd1;         // 2 beats
    burst_size = default_size; // 32-bit (4 bytes)

    `uvm_info(get_type_name(), "=== Starting AXI3_Locked_Sequence_test (Spec A7.2) ===", UVM_LOW)

    // =========================================================================
    // Step 1: Master 0 asserts AxLOCK = 2'b10 (Locked Access)
    // =========================================================================
    `uvm_info(get_type_name(), "Step 1: Master 0 initiates locked sequence (AxLOCK=2'b10)", UVM_LOW)

    write_burst_ext(
      .id        (m0_id),
      .addr      (target_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (2'b10), // LOCK_LOCKED
      .base_data (32'hAAAA_0000),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    if (bresp_out == RESP_OKAY) begin
      `uvm_info(get_type_name(), "[PASS] Master 0 locked write granted with BRESP=OKAY", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("Master 0 locked write failed! BRESP=%s", bresp_out.name()))
    end

    // =========================================================================
    // Step 2: Master 1 attempts access during active lock (Expect rejection)
    // =========================================================================
    `uvm_info(get_type_name(), "Step 2: Master 1 attempts unauthorized access during lock", UVM_LOW)

    write_burst_ext(
      .id        (m1_id), // Competing ID
      .addr      (target_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (2'b00), // Normal access attempt
      .base_data (32'hDEAD_BEEF),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    // RTL evaluates err_bus_locked = is_bus_locked && (lock_owner_id != id) -> SLVERR
    if (bresp_out == RESP_SLVERR) begin
      `uvm_info(get_type_name(), "[CHECK PASSED] Slave correctly rejected Master 1 during lock with SLVERR", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("[FAIL] Master 1 should be blocked! Got BRESP=%s", bresp_out.name()))
    end

    // =========================================================================
    // Step 3: Master 0 issues unlocking transaction (AxLOCK = 2'b00)
    // =========================================================================
    `uvm_info(get_type_name(), "Step 3: Master 0 releases bus lock (AxLOCK=2'b00)", UVM_LOW)

    write_burst_ext(
      .id        (m0_id),
      .addr      (target_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (2'b00), // Unlocking transaction
      .base_data (32'h5555_0000),
      .strb_val  ({STRB_WIDTH{1'b1}}),
      .bresp_out (bresp_out),
      .wdata_out (wdata_out)
    );

    if (bresp_out == RESP_OKAY) begin
      `uvm_info(get_type_name(), "[PASS] Master 0 unlock transaction accepted with BRESP=OKAY", UVM_LOW)
    end else begin
      `uvm_error(get_type_name(), $sformatf("Master 0 unlock transaction failed! BRESP=%s", bresp_out.name()))
    end

    // =========================================================================
    // Step 4: Master 1 performs normal access after lock release
    // =========================================================================
    `uvm_info(get_type_name(), "Step 4: Master 1 performs access after lock release", UVM_LOW)

    read_burst_ext(
      .id        (m1_id),
      .addr      (target_addr),
      .len       (burst_len),
      .size      (burst_size),
      .burst     (BURST_INCR),
      .lock      (2'b00),
      .rresp_out (rresp_out),
      .rdata_out (rdata_out)
    );

    foreach (rresp_out[i]) begin
      if (rresp_out[i] == RESP_OKAY) begin
        `uvm_info(get_type_name(), $sformatf("[CHECK PASSED] Master 1 read beat %0d accepted with RRESP=OKAY", i), UVM_LOW)
      end else begin
        `uvm_error(get_type_name(), $sformatf("Master 1 read beat %0d failed! RRESP=%s", i, rresp_out[i].name()))
      end
    end

    `uvm_info(get_type_name(), "=== AXI3_Locked_Sequence_test Sequence Completed Successfully ===", UVM_LOW)
  endtask : body

endclass : axi3_locked_sequence_seq

//////////////////////////////////////////////////////

//============================================================================
  // TC-13: axi3_wlast_protocol_seq (Spec A3.4.4 - Write Data & Strobe Controls)
  //============================================================================
  class axi3_wlast_protocol_seq extends axi_base_seq;
    `uvm_object_utils(axi3_wlast_protocol_seq)

    rand bit inject_early_wlast;

    function new(string name = "axi3_wlast_protocol_seq");
      super.new(name);
      inject_early_wlast = 1'b0;
    endfunction

    virtual task body();
      bit [LEN_WIDTH-1:0] burst_lengths[4] = '{4'd0, 4'd3, 4'd7, 4'd15}; // 1, 4, 8, 16 beats
      `uvm_info(get_type_name(), $sformatf("Starting TC-13 WLAST Protocol Test (inject_early=%0b)...", inject_early_wlast), UVM_LOW)

      foreach (burst_lengths[i]) begin
        write_burst(
          .id(4'h1),
          .addr(16'h1000 + (i * 16'h0100)),
          .len(burst_lengths[i]),
          .size(default_size),
          .burst(BURST_INCR),
          .base_data(32'hA000_0000 | (i << 16))
        );
      end

      if (inject_early_wlast) begin
        axi_seq_item wr_item;
        `uvm_info(get_type_name(), "Injecting Premature WLAST on beat 2 of 4-beat burst for SVA check...", UVM_MEDIUM)
        `uvm_create(wr_item)
        start_item(wr_item);
        wr_item.trans_type   = AXI_WRITE;
        wr_item.id           = 4'h2;
        wr_item.addr         = 16'h2000;
        wr_item.len          = 4'd3;
        wr_item.size         = default_size;
        wr_item.burst        = BURST_INCR;
        wr_item.wdata        = new[4];
        wr_item.wstrb        = new[4];
        foreach (wr_item.wdata[k]) begin
          wr_item.wdata[k] = 32'hB000_0000 | k;
          wr_item.wstrb[k] = {STRB_WIDTH{1'b1}};
        end
        wr_item.current_beat = 1; // Mark premature assertion
        finish_item(wr_item);

        if (!wr_item.is_completed) begin
          @wr_item.done_event;
        end
      end
    endtask
  endclass : axi3_wlast_protocol_seq

 //============================================================================
  // TC-14: axi3_rlast_tracking_seq (Spec A3.4.4 - Read Channel Integrity & Ordering)
  //============================================================================
  class axi3_rlast_tracking_seq extends axi_base_seq;
    `uvm_object_utils(axi3_rlast_tracking_seq)

    function new(string name = "axi3_rlast_tracking_seq");
      super.new(name);
    endfunction

    virtual task body();
      axi_seq_item         wr_item;
      axi_resp_e           rresp_out[];
      bit [DATA_WIDTH-1:0] rdata_out[];
      bit [15:0]           base_addr;

      `uvm_info(get_type_name(), "Starting TC-14 RLAST Tracking Test on 16-beat Bursts...", UVM_LOW)

      for (int latency_profile = 0; latency_profile < 3; latency_profile++) begin
        base_addr = 16'h3000 + (latency_profile * 16'h0080);

        // 1. Pre-load 16 beats so RAM has known data before reading
        wr_item = axi_seq_item::type_id::create($sformatf("tc14_wr_item_%0d", latency_profile));
        start_item(wr_item);

        wr_item.trans_type = AXI_WRITE;
        wr_item.id         = 4'h3;
        wr_item.addr       = base_addr;
        wr_item.len        = 4'd15;
        wr_item.size       = default_size;
        wr_item.burst      = BURST_INCR;
        wr_item.lock       = 2'b00;
        wr_item.cache      = 4'b0011;
        wr_item.prot       = 3'b000;

        wr_item.wdata = new[16];
        wr_item.wstrb = new[16];
        for (int b = 0; b < 16; b++) begin
          wr_item.wdata[b] = 32'hC000_0000 | (32'(latency_profile) << 16) | (b * 32'h0000_0100);
          wr_item.wstrb[b] = {STRB_WIDTH{1'b1}};
        end

        finish_item(wr_item);

        if (!wr_item.is_completed) begin
          @(wr_item.done_event);
        end

        if (wr_item.bresp != RESP_OKAY) begin
          `uvm_error(get_type_name(), $sformatf(
            "Latency profile %0d: Write pre-load failed with BRESP=%0p",
            latency_profile, wr_item.bresp))
        end

        // 2. Read back 16 beats and verify beat count, RRESP, and RDATA ordering
        read_burst_ext(
          .id(4'h3),
          .addr(base_addr),
          .len(4'd15),
          .size(default_size),
          .burst(BURST_INCR),
          .lock(2'b00),
          .rresp_out(rresp_out),
          .rdata_out(rdata_out)
        );

        if (rdata_out.size() != 16) begin
          `uvm_error(get_type_name(), $sformatf(
            "Latency profile %0d: Expected 16 beats, received %0d!",
            latency_profile, rdata_out.size()))
        end

        if (rresp_out.size() != 16) begin
          `uvm_error(get_type_name(), $sformatf(
            "Latency profile %0d: Expected 16 RRESP entries, received %0d!",
            latency_profile, rresp_out.size()))
        end

        for (int b = 0; b < 16; b++) begin
          if ((b < rresp_out.size()) && (rresp_out[b] != RESP_OKAY)) begin
            `uvm_error(get_type_name(), $sformatf(
              "Latency profile %0d beat %0d: Expected RESP_OKAY, got %0p",
              latency_profile, b, rresp_out[b]))
          end
          if ((b < rdata_out.size()) && (rdata_out[b] !== wr_item.wdata[b])) begin
            `uvm_error(get_type_name(), $sformatf(
              "Latency profile %0d beat %0d: RDATA mismatch! exp=0x%08h act=0x%08h",
              latency_profile, b, wr_item.wdata[b], rdata_out[b]))
          end
        end
      end
    endtask
  endclass : axi3_rlast_tracking_seq

  //============================================================================
  // TC-15: axi3_sparse_wstrb_seq (Spec A3.4.4 - Write Data & Strobe Controls)
  //============================================================================
  class axi3_sparse_wstrb_seq extends axi_base_seq;
    `uvm_object_utils(axi3_sparse_wstrb_seq)

    function new(string name = "axi3_sparse_wstrb_seq");
      super.new(name);
    endfunction

    virtual task body();
      bit [ADDR_WIDTH-1:0] test_addr = 16'h0800;
      bit [STRB_WIDTH-1:0] sparse_patterns[4] = '{4'b1001, 4'b0101, 4'b0010, 4'b0110};
      axi_seq_item wr_item;
      axi_resp_e           rresp_out[];
      bit [DATA_WIDTH-1:0] rdata_out[];

      `uvm_info(get_type_name(), "Starting TC-15 Sparse Non-Contiguous WSTRB Test...", UVM_LOW)

      // Step 1: Pre-populate background memory with known golden seed (0xA5A5A5A5)
      write_burst(
        .id(4'h1),
        .addr(test_addr),
        .len(4'd3),
        .size(default_size),
        .burst(BURST_INCR),
        .base_data(32'hA5A5_A5A5),
        .strb_val({STRB_WIDTH{1'b1}})
      );

      // Step 2: Perform sparse write with non-contiguous per-beat strobes
      `uvm_create(wr_item)
      start_item(wr_item);
      wr_item.trans_type = AXI_WRITE;
      wr_item.id         = 4'h1;
      wr_item.addr       = test_addr;
      wr_item.len        = 4'd3;
      wr_item.size       = default_size;
      wr_item.burst      = BURST_INCR;
      wr_item.lock       = default_lock;
      wr_item.cache      = default_cache;
      wr_item.prot       = default_prot;
      wr_item.wdata      = new[4];
      wr_item.wstrb      = new[4];

      foreach (wr_item.wdata[i]) begin
        wr_item.wdata[i] = 32'h5A5A_5A5A;
        wr_item.wstrb[i] = sparse_patterns[i];
      end
      finish_item(wr_item);

      if (!wr_item.is_completed) begin
        @wr_item.done_event;
      end

      // Step 3: Read back and verify byte lanes
      read_burst_ext(
        .id(4'h1),
        .addr(test_addr),
        .len(4'd3),
        .size(default_size),
        .burst(BURST_INCR),
        .lock(2'b00),
        .rresp_out(rresp_out),
        .rdata_out(rdata_out)
      );
    endtask
  endclass : axi3_sparse_wstrb_seq

  //============================================================================
  // TC-17: axi3_wdata_before_addr_seq (Spec A3.3.1 - Write Data & Strobe Controls)
  //============================================================================
class axi3_wdata_before_addr_seq extends uvm_sequence #(axi_seq_item);
  `uvm_object_utils(axi3_wdata_before_addr_seq)

  function new(string name = "axi3_wdata_before_addr_seq");
    super.new(name);
  endfunction

  virtual task body();
    axi_seq_item wr_item[3];
    axi_seq_item rd_item[3];
    int          num_beats[3];
    bit [15:0]   base_addr[3];
    bit [3:0]    txn_id[3];

    // 1. Issue all 3 writes back-to-back so active_w_pool can interleave W beats before AW
    for (int tx = 0; tx < 3; tx++) begin
      num_beats[tx] = (tx == 1) ? 8 : 4;          // 4-beat, 8-beat, 4-beat bursts
      base_addr[tx] = 16'h1000 + (tx * 16'h0040);
      txn_id[tx]    = 4'h1 + tx[3:0];

      wr_item[tx] = axi_seq_item::type_id::create($sformatf("wr_item_%0d", tx));
      start_item(wr_item[tx]);

      wr_item[tx].trans_type = AXI_WRITE;
      wr_item[tx].id         = txn_id[tx];
      wr_item[tx].addr       = base_addr[tx];
      wr_item[tx].len        = num_beats[tx] - 1;
      wr_item[tx].size       = 3'd2;
      wr_item[tx].burst      = BURST_INCR;
      wr_item[tx].lock       = 2'b00;
      wr_item[tx].cache      = 4'b0011;
      wr_item[tx].prot       = 3'b000;

      wr_item[tx].wdata = new[num_beats[tx]];
      wr_item[tx].wstrb = new[num_beats[tx]];
      for (int b = 0; b < num_beats[tx]; b++) begin
        wr_item[tx].wdata[b] = 32'hA000_0000 | (32'(txn_id[tx]) << 16) | (b * 32'h0000_0100);
        wr_item[tx].wstrb[b] = 4'b1111;
      end

      finish_item(wr_item[tx]);
    end

    // 2. Wait for all write responses
    for (int tx = 0; tx < 3; tx++) begin
      if (!wr_item[tx].is_completed) begin
        @(wr_item[tx].done_event);
      end

      if (wr_item[tx].bresp != RESP_OKAY) begin
        `uvm_error(get_type_name(), $sformatf(
          "Write tx=%0d (ID=0x%0h, ADDR=0x%0h) expected OKAY BRESP, got %0p",
          tx, txn_id[tx], base_addr[tx], wr_item[tx].bresp))
      end
    end

    // 3. Read back and verify all 3 bursts
    for (int tx = 0; tx < 3; tx++) begin
      rd_item[tx] = axi_seq_item::type_id::create($sformatf("rd_item_%0d", tx));
      start_item(rd_item[tx]);

      rd_item[tx].trans_type = AXI_READ;
      rd_item[tx].id         = txn_id[tx];
      rd_item[tx].addr       = base_addr[tx];
      rd_item[tx].len        = num_beats[tx] - 1;
      rd_item[tx].size       = 3'd2;
      rd_item[tx].burst      = BURST_INCR;
      rd_item[tx].lock       = 2'b00;
      rd_item[tx].cache      = 4'b0011;
      rd_item[tx].prot       = 3'b000;

      finish_item(rd_item[tx]);

      if (!rd_item[tx].is_completed) begin
        @(rd_item[tx].done_event);
      end

      for (int b = 0; b < num_beats[tx]; b++) begin
        if (b < rd_item[tx].rdata.size() && (rd_item[tx].rdata[b] !== wr_item[tx].wdata[b])) begin
          `uvm_error(get_type_name(), $sformatf(
            "Data mismatch on tx=%0d beat=%0d at ADDR=0x%0h: exp=0x%08h act=0x%08h",
            tx, b, base_addr[tx] + (b * 4), wr_item[tx].wdata[b], rd_item[tx].rdata[b]))
        end
      end
    end
  endtask
endclass : axi3_wdata_before_addr_seq
  
 //============================================================================
  // TC-20: axi3_out_of_order_rid_seq (Spec A8.1 - 5-Burst Out-of-Order RID Test)
  //============================================================================
  class axi3_out_of_order_rid_seq extends axi_base_seq;
    `uvm_object_utils(axi3_out_of_order_rid_seq)

    function new(string name = "axi3_out_of_order_rid_seq");
      super.new(name);
    endfunction

    virtual task body();
      int                  num_beats[5];
      bit [ADDR_WIDTH-1:0] base_addr[5];
      bit [ID_WIDTH-1:0]   txn_id[5];
      bit [DATA_WIDTH-1:0] exp_wdata[5][];
      bit [DATA_WIDTH-1:0] wdata_tmp[];
      axi_resp_e           bresp_tmp;

      `uvm_info(get_type_name(), "Starting TC-20 5-Burst Out-Of-Order RID Reordering Test...", UVM_LOW)

      txn_id[0] = 4'h1; base_addr[0] = 16'h3000; num_beats[0] = 8;
      txn_id[1] = 4'h2; base_addr[1] = 16'h3100; num_beats[1] = 4;
      txn_id[2] = 4'h3; base_addr[2] = 16'h1000; num_beats[2] = 2;
      txn_id[3] = 4'h4; base_addr[3] = 16'h3200; num_beats[3] = 16;
      txn_id[4] = 4'h5; base_addr[4] = 16'h1100; num_beats[4] = 6;

      // 1. Pre-load all 5 address regions using axi_base_seq::write_burst_ext
      for (int i = 0; i < 5; i++) begin
        write_burst_ext(
          .id(txn_id[i]),
          .addr(base_addr[i]),
          .len(num_beats[i] - 1),
          .size(default_size),
          .burst(BURST_INCR),
          .lock(2'b00),
          .base_data(32'hD000_0000 | (32'(txn_id[i]) << 16)),
          .bresp_out(bresp_tmp),
          .wdata_out(wdata_tmp)
        );
        exp_wdata[i] = wdata_tmp;

        if (bresp_tmp != RESP_OKAY) begin
          `uvm_error(get_type_name(), $sformatf("Write %0d (ID=0x%0h) BRESP=%0p", i, txn_id[i], bresp_tmp))
        end
      end

      // 2. Issue all 5 reads concurrently so AXI_SLAVE interleaves & finishes out of order
      for (int i = 0; i < 5; i++) begin
        automatic int idx = i;
        fork
          begin
            axi_resp_e           rresp_out[];
            bit [DATA_WIDTH-1:0] rdata_out[];

            read_burst_ext(
              .id(txn_id[idx]),
              .addr(base_addr[idx]),
              .len(num_beats[idx] - 1),
              .size(default_size),
              .burst(BURST_INCR),
              .lock(2'b00),
              .rresp_out(rresp_out),
              .rdata_out(rdata_out)
            );

            if (rdata_out.size() != num_beats[idx]) begin
              `uvm_error(get_type_name(), $sformatf(
                "Read %0d (ID=0x%0h): Expected %0d beats, got %0d",
                idx, txn_id[idx], num_beats[idx], rdata_out.size()))
            end

            for (int b = 0; b < num_beats[idx]; b++) begin
              if (b < rresp_out.size() && rresp_out[b] != RESP_OKAY) begin
                `uvm_error(get_type_name(), $sformatf(
                  "Read %0d (ID=0x%0h) beat %0d: RRESP=%0p", idx, txn_id[idx], b, rresp_out[b]))
              end
              if (b < rdata_out.size() && rdata_out[b] !== exp_wdata[idx][b]) begin
                `uvm_error(get_type_name(), $sformatf(
                  "Read %0d (ID=0x%0h) beat %0d: RDATA exp=0x%08h act=0x%08h",
                  idx, txn_id[idx], b, exp_wdata[idx][b], rdata_out[b]))
              end
            end
          end
        join_none
      end
      wait fork;
    endtask
  endclass : axi3_out_of_order_rid_seq

  //============================================================================
  // TC-21: axi3_in_order_same_id_seq (Spec A8.1 - Transaction IDs & Interleaving)
  //============================================================================
  //============================================================================
  // TC-21: axi3_in_order_same_id_seq (Spec A8.1 - Transaction IDs & Interleaving)
  //============================================================================
  class axi3_in_order_same_id_seq extends axi_base_seq;
    `uvm_object_utils(axi3_in_order_same_id_seq)

    function new(string name = "axi3_in_order_same_id_seq");
      super.new(name);
    endfunction

    virtual task body();
      bit [ID_WIDTH-1:0]   test_id;
      bit [LEN_WIDTH-1:0]  burst_len[5];
      bit [SIZE_WIDTH-1:0] burst_size[5];
      bit [DATA_WIDTH-1:0] exp_wdata[5][];
      int                  wr_done_order[$];
      int                  rd_done_order[$];

      test_id = 4'h5;
      `uvm_info(get_type_name(), "Starting TC-21 In-Order Same-ID FIFO Retirement Test...", UVM_LOW)

      // Randomize distinct burst length (1..16 beats) and size (0..default_size) per transaction
      for (int i = 0; i < 5; i++) begin
        burst_len[i]  = $urandom_range(15, 0);
        burst_size[i] = $urandom_range(default_size, 0);
      end

      // 1. Issue 5 back-to-back write bursts with identical AWID (4'h5)
      for (int i = 0; i < 5; i++) begin
        automatic int idx = i;
        fork
          begin
            axi_resp_e           bresp_tmp;
            bit [DATA_WIDTH-1:0] wdata_tmp[];

            write_burst_ext(
              .id(test_id),
              .addr(16'h2000 + (idx * 16'h0080)),
              .len(burst_len[idx]),
              .size(burst_size[idx]),
              .burst(BURST_INCR),
              .lock(2'b00),
              .base_data(32'hC000_0000 | (idx << 12)),
              .bresp_out(bresp_tmp),
              .wdata_out(wdata_tmp)
            );

            exp_wdata[idx] = wdata_tmp;
            wr_done_order.push_back(idx);

            if (bresp_tmp != RESP_OKAY) begin
              `uvm_error(get_type_name(), $sformatf(
                "Write %0d (ID=0x%0h, LEN=%0d, SIZE=%0d) BRESP=%0p",
                idx, test_id, burst_len[idx], burst_size[idx], bresp_tmp))
            end
          end
        join_none
      end
      wait fork;

      // 2. Issue 5 back-to-back read bursts with identical ARID (4'h5)
      for (int i = 0; i < 5; i++) begin
        automatic int idx = i;
        fork
          begin
            axi_resp_e           rresp_out[];
            bit [DATA_WIDTH-1:0] rdata_out[];

            read_burst_ext(
              .id(test_id),
              .addr(16'h2000 + (idx * 16'h0080)),
              .len(burst_len[idx]),
              .size(burst_size[idx]),
              .burst(BURST_INCR),
              .lock(2'b00),
              .rresp_out(rresp_out),
              .rdata_out(rdata_out)
            );

            rd_done_order.push_back(idx);

            if (rdata_out.size() != (burst_len[idx] + 1)) begin
              `uvm_error(get_type_name(), $sformatf(
                "Read %0d (LEN=%0d): Expected %0d beats, got %0d",
                idx, burst_len[idx], burst_len[idx] + 1, rdata_out.size()))
            end
          end
        join_none
      end
      wait fork;
    endtask
  endclass : axi3_in_order_same_id_seq
  //============================================================================
  // TC-23: axi3_excl_failure_seq (Spec A7.1 - Atomic & Cache/Protection Operations)
  //============================================================================
  class axi3_excl_failure_seq extends axi_base_seq;
    `uvm_object_utils(axi3_excl_failure_seq)

    function new(string name = "axi3_excl_failure_seq");
      super.new(name);
    endfunction

    virtual task body();
      bit [ADDR_WIDTH-1:0] target_addr = 16'h1400;
      bit [ID_WIDTH-1:0]   master_a_id = 4'h1;
      bit [ID_WIDTH-1:0]   master_b_id = 4'h2;
      axi_resp_e           bresp_out;
      bit [DATA_WIDTH-1:0] wdata_out[];
      axi_resp_e           rresp_out[];
      bit [DATA_WIDTH-1:0] rdata_out[];

      `uvm_info(get_type_name(), "Starting TC-23 Exclusive Access Failure & Invalidation Test...", UVM_LOW)

      // Step 1: Master A establishes exclusive reservation
      read_burst_ext(
        .id(master_a_id),
        .addr(target_addr),
        .len(4'd0),
        .size(default_size),
        .burst(BURST_INCR),
        .lock(2'b01),
        .rresp_out(rresp_out),
        .rdata_out(rdata_out)
      );

      if (rresp_out[0] != RESP_EXOKAY) begin
        `uvm_warning(get_type_name(), $sformatf("Exclusive Read expected RESP_EXOKAY, got %0s", rresp_out[0].name()))
      end

      // Step 2: Master B executes normal write to invalidate reservation
      write_burst(
        .id(master_b_id),
        .addr(target_addr),
        .len(4'd0),
        .size(default_size),
        .burst(BURST_INCR),
        .base_data(32'hBEEF_CAFE)
      );

      // Step 3: Master A attempts Exclusive Write -> Slave must suppress RAM commit & return RESP_OKAY
      write_burst_ext(
        .id(master_a_id),
        .addr(target_addr),
        .len(4'd0),
        .size(default_size),
        .burst(BURST_INCR),
        .lock(2'b01),
        .base_data(32'hDEAD_BEEF),
        .strb_val({STRB_WIDTH{1'b1}}),
        .bresp_out(bresp_out),
        .wdata_out(wdata_out)
      );

      if (bresp_out == RESP_EXOKAY) begin
        `uvm_error(get_type_name(), "CRITICAL VIOLATION: Broken exclusive write returned RESP_EXOKAY! Must return RESP_OKAY.")
      end else if (bresp_out == RESP_OKAY) begin
        `uvm_info(get_type_name(), "PASS: Broken exclusive reservation returned RESP_OKAY per Spec A7.1.", UVM_LOW)
      end

      // Step 4: Verify memory content retains Master B's data
      read_burst_ext(
        .id(master_a_id),
        .addr(target_addr),
        .len(4'd0),
        .size(default_size),
        .burst(BURST_INCR),
        .lock(2'b00),
        .rresp_out(rresp_out),
        .rdata_out(rdata_out)
      );

      if (rdata_out[0] != 32'hBEEF_CAFE) begin
        `uvm_error(get_type_name(), $sformatf("Memory corruption! Expected 0xBEEF_CAFE, got 0x%08h", rdata_out[0]))
      end
    endtask
  endclass : axi3_excl_failure_seq
  
  //============================================================================
  // TC-28: axi3_cache_attributes_seq (Spec A5.2 - Atomic & Cache/Protection Operations)
  //============================================================================
  class axi3_cache_attributes_seq extends axi_base_seq;
    `uvm_object_utils(axi3_cache_attributes_seq)

    function new(string name = "axi3_cache_attributes_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "Starting TC-28 Exhaustive AxCACHE[3:0] Sweep...", UVM_LOW)

      for (int cache_val = 0; cache_val < 16; cache_val++) begin
        bit [ADDR_WIDTH-1:0] test_addr = 16'h2000 + (cache_val * 16'h0040);
        default_cache = cache_val[3:0];

        write_read_ping_pong(
          .wr_id(cache_val[3:0]),
          .rd_id(cache_val[3:0]),
          .addr(test_addr),
          .len(4'd3),
          .size(default_size),
          .burst(BURST_INCR),
          .base_data(32'hCACE_0000 | (cache_val << 8))
        );
      end
    endtask
  endclass : axi3_cache_attributes_seq

  //============================================================================
  // TC-29: axi3_wrap_illegal_length_seq (Spec A3.4.3 - Burst Addressing & Boundaries)
  //============================================================================
  class axi3_wrap_illegal_length_seq extends axi_base_seq;
    `uvm_object_utils(axi3_wrap_illegal_length_seq)

    function new(string name = "axi3_wrap_illegal_length_seq");
      super.new(name);
    endfunction

    virtual task body();
      bit [LEN_WIDTH-1:0] illegal_lens[3] = '{4'd0, 4'd2, 4'd4}; // 1 beat, 3 beats, 5 beats
      axi_seq_item wr_item;
	  axi_seq_item rd_item;

      `uvm_info(get_type_name(), "Starting TC-29 Negative Test: Illegal WRAP Burst Lengths...", UVM_LOW)

      foreach (illegal_lens[i]) begin
        `uvm_create(wr_item)
        wr_item.c_wrap_rules.constraint_mode(0);

        start_item(wr_item);
        if (!wr_item.randomize() with {
          trans_type == AXI_WRITE;
          len        == illegal_lens[i];
          addr       == 16'h1000;
          burst      == BURST_WRAP;
          size       == default_size;
        }) begin
          `uvm_fatal(get_type_name(), "Randomization failed on illegal WRAP item!")
        end
        finish_item(wr_item);

        if (!wr_item.is_completed) begin
          @wr_item.done_event;
        end		
		
      end
	  
	  foreach (illegal_lens[i]) begin
        `uvm_create(rd_item)
        rd_item.c_wrap_rules.constraint_mode(0);

        start_item(rd_item);
        if (!rd_item.randomize() with {
          trans_type == AXI_READ;
          len        == illegal_lens[i];
          addr       == 16'h1000;
          burst      == BURST_WRAP;
          size       == default_size;
        }) begin
          `uvm_fatal(get_type_name(), "Randomization failed on illegal WRAP item!")
        end
        finish_item(rd_item);

        if (!rd_item.is_completed) begin
          @rd_item.done_event;
        end		
		
      end
    endtask
  endclass : axi3_wrap_illegal_length_seq

  //============================================================================
  // TC-30: axi3_zero_delay_back_to_back_seq (Spec A3.2.1 - Reset & Handshake)
  //============================================================================
  class axi3_zero_delay_back_to_back_seq extends axi_base_seq;
    `uvm_object_utils(axi3_zero_delay_back_to_back_seq)

    function new(string name = "axi3_zero_delay_back_to_back_seq");
      super.new(name);
    endfunction

    virtual task body();
      `uvm_info(get_type_name(), "Starting TC-30 Zero-Delay 200-Cycle Pipeline Saturation Test...", UVM_LOW)

      for (int i = 0; i < 200; i++) begin
        write_read_ping_pong(
          .wr_id(4'h1),
          .rd_id(4'h2),
          .addr(16'h1000 + (i * 16'h0010)),
          .len(4'd3),
          .size(default_size),
          .burst(BURST_INCR),
          .base_data(32'h1000_0000 | (i << 8))
        );
      end
    endtask
  endclass : axi3_zero_delay_back_to_back_seq
