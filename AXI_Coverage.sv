// =============================================================================
// Class   : axi_coverage
// Purpose : SystemVerilog Functional Coverage Subscriber for AMBA AXI3 Protocol.
//           Tracks all protocol features, transaction types, burst modes,
//           cache/protection, byte strobes, and cross metrics.
// =============================================================================
class axi_coverage extends uvm_subscriber #(axi_seq_item);

  `uvm_component_utils(axi_coverage)

  // ---------------------------------------------------------------------------
  // Internal Transaction Container & Local Sample Variables
  // ---------------------------------------------------------------------------
  axi_seq_item tr;

  // Local helper variables to avoid indexing empty dynamic arrays inside CG
  bit [STRB_WIDTH-1:0] cur_wstrb;
  axi_resp_e           cur_rresp;
  bit [1:0]            cur_addr_offset;

  // ---------------------------------------------------------------------------
  // Functional Coverage Group
  // ---------------------------------------------------------------------------
  covergroup axi_trans_cg;
    option.per_instance = 1;
    option.name         = "axi_protocol_and_features_cov";

    // 1. Transaction Type
    cp_trans_type: coverpoint tr.trans_type {
      bins write_trans = {AXI_WRITE};
      bins read_trans  = {AXI_READ};
    }

    // 2. Transaction ID Space (AXI3 multi-threading & slot interleaving)
    cp_id: coverpoint tr.id {
      bins zero_id    = {'0};
      bins low_ids[]  = {[1:3]};
      bins mid_ids[]  = {[4:11]};
      bins high_ids[] = {[12:(1 << ID_WIDTH)-1]};
    }

    // 3. Transfer Length (AXI3 len 0..15 corresponding to 1..16 beats)
    cp_len: coverpoint tr.len {
      bins single_beat = {4'd0};
      bins wrap_lens[] = {4'd1, 4'd3, 4'd7, 4'd15}; // 2, 4, 8, 16 beats
      bins misc_lens[] = {[4'd2:4'd14]} with (!(item inside {4'd3, 4'd7}));
    }

    // 4. Burst Size (Bytes per beat: 1B, 2B, 4B)
    cp_size: coverpoint tr.size {
      bins size_1B        = {3'b000};
      bins size_2B        = {3'b001};
      bins size_4B        = {3'b010};
      bins size_max       = {$clog2(STRB_WIDTH)};
      // 8B is illegal/unreachable on a 32-bit data bus; ignore directly without constant 'with' expr
      ignore_bins size_8B = {3'b011};
    }

    // 5. Burst Type
    cp_burst: coverpoint tr.burst {
      bins fixed_burst       = {BURST_FIXED};
      bins incr_burst        = {BURST_INCR};
      bins wrap_burst        = {BURST_WRAP};
      ignore_bins rsvd_burst = {BURST_RSVD}; // Excluded; automatically omitted from crosses
    }

    // 6. Address Alignment & 4KB Boundary Proximity
    cp_addr_align: coverpoint cur_addr_offset {
      bins aligned   = {2'b00};
      bins unaligned = {[2'b01 : 2'b11]};
    }

    cp_4k_page_offset: coverpoint (tr.addr & 12'hFFF) {
      bins page_start = {12'h000};
      bins page_mid   = {[12'h001 : 12'hF00]};
      bins near_4k    = {[12'hF01 : 12'hFFF]};
    }

    // 7. Protection & Lock Signals
    cp_prot: coverpoint tr.prot {
      bins normal_secure_data     = {3'b000};
      bins privileged_secure_data = {3'b001};
      bins normal_nonsec_data     = {3'b010};
      bins normal_secure_instr    = {3'b100};
      bins other_prot[]           = default;
    }

    cp_lock: coverpoint tr.lock {
      bins normal_access    = {2'b00};
      bins exclusive_access = {2'b01};
      bins locked_access    = {2'b10};
    }

    // 8. Write Strobes Analysis
    cp_wstrb: coverpoint cur_wstrb iff (tr.trans_type == AXI_WRITE) {
      bins all_active  = {(1 << STRB_WIDTH) - 1};
      bins single_byte = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins all_zeros   = {'0};
      bins sparse_strb = default;
    }

    // 9. Slave Response Status
    cp_bresp: coverpoint tr.bresp iff (tr.trans_type == AXI_WRITE) {
      bins okay   = {RESP_OKAY};
      bins exokay = {RESP_EXOKAY};
      bins slverr = {RESP_SLVERR};
      bins decerr = {RESP_DECERR};
    }

    cp_rresp: coverpoint cur_rresp iff (tr.trans_type == AXI_READ) {
      bins okay   = {RESP_OKAY};
      bins exokay = {RESP_EXOKAY};
      bins slverr = {RESP_SLVERR};
      bins decerr = {RESP_DECERR};
    }

    // -------------------------------------------------------------------------
    // Cross Coverage
    // -------------------------------------------------------------------------
    // Transfer type with length and size (size_8B is already an ignore_bin)
    cross_trans_len_size: cross cp_trans_type, cp_len, cp_size;

    // Burst type with length (WRAP bursts strictly 2, 4, 8, 16 beats)
    cross_burst_len: cross cp_burst, cp_len {
      ignore_bins invalid_wrap_lens = binsof(cp_burst.wrap_burst) &&
                                      binsof(cp_len.misc_lens);
      ignore_bins single_beat_wrap  = binsof(cp_burst.wrap_burst) &&
                                      binsof(cp_len.single_beat);
    }

    // Response with transfer type
    cross_trans_bresp: cross cp_trans_type, cp_bresp {
      ignore_bins read_with_bresp = binsof(cp_trans_type.read_trans);
    }

    cross_trans_rresp: cross cp_trans_type, cp_rresp {
      ignore_bins write_with_rresp = binsof(cp_trans_type.write_trans);
    }

    // ID with transfer type
    cross_id_type: cross cp_id, cp_trans_type;

    // Address alignment with burst type (WRAP bursts cannot have unaligned start addresses)
    cross_align_burst: cross cp_addr_align, cp_burst {
      ignore_bins unaligned_wrap = binsof(cp_addr_align.unaligned) &&
                                   binsof(cp_burst.wrap_burst);
    }

  endgroup : axi_trans_cg

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_coverage", uvm_component parent = null);
    super.new(name, parent);
    axi_trans_cg = new();
  endfunction : new

  // ---------------------------------------------------------------------------
  // Subscriber Write Implementation
  // ---------------------------------------------------------------------------
  virtual function void write(axi_seq_item t);
    if (t == null) begin
      `uvm_error("COV/NULL_ITEM", "Sampled null sequence item in axi_coverage!")
      return;
    end

    this.tr = t;

    // Compute byte offset from address according to transfer size
    cur_addr_offset = (t.addr & ((1 << t.size) - 1));

    // Safe extraction of WSTRB (guard against empty dynamic arrays)
    if (t.trans_type == AXI_WRITE) begin
      if (t.wstrb.size() > 0) begin
        cur_wstrb = t.wstrb[0];
      end else begin
        cur_wstrb = {STRB_WIDTH{1'b1}};
      end
    end else begin
      cur_wstrb = '0;
    end

    // Safe extraction of RRESP (guard against empty dynamic arrays)
    if (t.trans_type == AXI_READ) begin
      if (t.rresp.size() > 0) begin
        cur_rresp = t.rresp[0];
      end else begin
        cur_rresp = RESP_OKAY;
      end
    end else begin
      cur_rresp = RESP_OKAY;
    end

    // Sample covergroup
    axi_trans_cg.sample();
  endfunction : write

  // ---------------------------------------------------------------------------
  // Report Phase
  // ---------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COV/FINAL", $sformatf("Overall Functional Coverage = %0.2f%%",
              axi_trans_cg.get_inst_coverage()), UVM_LOW)
  endfunction : report_phase

endclass : axi_coverage
