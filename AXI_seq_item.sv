// =============================================================================
// Class:   axi_seq_item
// Base:    uvm_sequence_item
// Purpose: Encapsulates an AMBA AXI3/AXI4 transaction spanning address (AW/AR),
//          write-data (W), write-response (B), and read-data (R) channels.
// =============================================================================
class axi_seq_item extends uvm_sequence_item;

  // ---------------------------------------------------------------------------
  // 1. Transaction Protocol Fields (Address / Request Channel Attributes)
  // ---------------------------------------------------------------------------
  rand axi_trans_type_e        trans_type;
  rand bit [ID_WIDTH-1:0]      id;
  rand bit [ADDR_WIDTH-1:0]    addr;
  rand bit [LEN_WIDTH-1:0]     len;
  rand bit [SIZE_WIDTH-1:0]    size;
  rand axi_burst_e             burst;
  rand bit [1:0]               lock;
  rand bit [3:0]               cache;
  rand bit [2:0]               prot;

  // ---------------------------------------------------------------------------
  // 2. Write Data Channel Payloads (WDATA & WSTRB)
  // ---------------------------------------------------------------------------
  rand bit [DATA_WIDTH-1:0]    wdata[];
  rand bit [STRB_WIDTH-1:0]    wstrb[];

  // ---------------------------------------------------------------------------
  // 3. Slave Response Fields (Sampled by Driver / Monitor)
  // ---------------------------------------------------------------------------
  bit [ID_WIDTH-1:0]           bid;
  axi_resp_e                   bresp;
  bit [ID_WIDTH-1:0]           rid[];
  bit [DATA_WIDTH-1:0]         rdata[];
  axi_resp_e                   rresp[];

  // ---------------------------------------------------------------------------
  // 4. Testbench Synchronization & Internal State Tracking
  // ---------------------------------------------------------------------------
  int                          current_beat;
  bit                          aw_handshaked;
  bit                          w_completed;
  bit                          w_before_aw_mode;
  bit                          is_completed;
  event                        done_event;
  axi_seq_item                 orig_item;

  // ---------------------------------------------------------------------------
  // 5. Protocol Constraints
  // ---------------------------------------------------------------------------
  constraint c_default_size {
    size == $clog2(STRB_WIDTH);
  }

  constraint c_payload_sizes {
    solve len before wdata;
    solve len before wstrb;
    wdata.size() == len + 1;
    wstrb.size() == len + 1;
  }

  constraint c_4k_boundary {
    if (burst == BURST_INCR) {
      ((addr & 12'hFFF) + ((len + 1) * (1 << size))) <= 4096;
    }
  }

  constraint c_wrap_rules {
    if (burst == BURST_WRAP) {
      len inside {4'd1, 4'd3, 4'd7, 4'd15};
      (addr % ((len + 1) * (1 << size))) == 0;
    }
  }

  // ---------------------------------------------------------------------------
  // 6. UVM Automation Macros (Field Registration)
  // ---------------------------------------------------------------------------
  `uvm_object_utils_begin(axi_seq_item)
    `uvm_field_enum(axi_trans_type_e, trans_type,   UVM_ALL_ON)
    `uvm_field_int(id,                              UVM_ALL_ON)
    `uvm_field_int(addr,                            UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(len,                             UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(size,                            UVM_ALL_ON | UVM_DEC)
    `uvm_field_enum(axi_burst_e,      burst,        UVM_ALL_ON)
    `uvm_field_int(lock,                            UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(cache,                           UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(prot,                            UVM_ALL_ON | UVM_BIN)
    `uvm_field_array_int(wdata,                     UVM_ALL_ON | UVM_HEX)
    `uvm_field_array_int(wstrb,                     UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(bid,                             UVM_ALL_ON)
    `uvm_field_enum(axi_resp_e,       bresp,        UVM_ALL_ON)
    `uvm_field_array_int(rid,                       UVM_ALL_ON)
    `uvm_field_array_int(rdata,                     UVM_ALL_ON | UVM_HEX)
    `uvm_field_array_enum(axi_resp_e, rresp,        UVM_ALL_ON)
    `uvm_field_int(current_beat,                    UVM_DEFAULT | UVM_DEC | UVM_NOPRINT)
    `uvm_field_int(aw_handshaked,                   UVM_DEFAULT | UVM_NOPRINT)
    `uvm_field_int(w_completed,                     UVM_DEFAULT | UVM_NOPRINT)
    `uvm_field_int(w_before_aw_mode,                UVM_DEFAULT | UVM_NOPRINT)
    `uvm_field_int(is_completed,                    UVM_DEFAULT | UVM_NOPRINT)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // 7. Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_seq_item");
    super.new(name);
    current_beat     = 0;
    aw_handshaked    = 1'b0;
    w_completed      = 1'b0;
    w_before_aw_mode = 1'b0;
    is_completed     = 1'b0;
    orig_item        = null;
  endfunction

  // ---------------------------------------------------------------------------
  // 8. Post-Randomize Hook
  // ---------------------------------------------------------------------------
  function void post_randomize();
    super.post_randomize();
    if (wdata.size() != (len + 1)) begin
      wdata = new[len + 1];
    end
    if (wstrb.size() != (len + 1)) begin
      wstrb = new[len + 1];
    end
  endfunction

  // ---------------------------------------------------------------------------
  // 9. Manual Copy Hook
  // ---------------------------------------------------------------------------
  virtual function void do_copy(uvm_object rhs);
    axi_seq_item rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COPY", "Cast failed in axi_seq_item::do_copy")
      return;
    end
    super.do_copy(rhs);
    this.trans_type       = rhs_.trans_type;
    this.id               = rhs_.id;
    this.addr             = rhs_.addr;
    this.len              = rhs_.len;
    this.size             = rhs_.size;
    this.burst            = rhs_.burst;
    this.lock             = rhs_.lock;
    this.cache            = rhs_.cache;
    this.prot             = rhs_.prot;
    this.wdata            = rhs_.wdata;
    this.wstrb            = rhs_.wstrb;
    this.bid              = rhs_.bid;
    this.bresp            = rhs_.bresp;
    this.rid              = rhs_.rid;
    this.rdata            = rhs_.rdata;
    this.rresp            = rhs_.rresp;
    this.current_beat     = rhs_.current_beat;
    this.aw_handshaked    = rhs_.aw_handshaked;
    this.w_completed      = rhs_.w_completed;
    this.w_before_aw_mode = rhs_.w_before_aw_mode;
    this.is_completed     = rhs_.is_completed;
    this.orig_item        = rhs_.orig_item;
  endfunction : do_copy

endclass : axi_seq_item