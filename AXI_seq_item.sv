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
  // Operation selector: AXI_WRITE (AW+W+B channels) or AXI_READ (AR+R channels)
  rand axi_trans_type_e        trans_type;

  // Transaction Identifier (AWID/ARID): Enables out-of-order & interleaved flows
  rand bit [ID_WIDTH-1:0]      id;

  // Base byte start address for the burst (AWADDR/ARADDR)
  rand bit [ADDR_WIDTH-1:0]    addr;

  // Burst length minus 1 (AWLEN/ARLEN): e.g., 4'd3 denotes 4 total transfers (beats)
  rand bit [LEN_WIDTH-1:0]     len;

  // Transfer size (AWSIZE/ARSIZE): 2^size bytes per beat (e.g., 2 -> 4 bytes / 32 bits)
  rand bit [SIZE_WIDTH-1:0]    size;

  // Burst type (AWBURST/ARBURST): FIXED (2'b00), INCR (2'b01), or WRAP (2'b10)
  rand axi_burst_e             burst;

  // Atomic access controls: 2'b00 = Normal, 2'b01 = Exclusive, 2'b10 = Locked (AXI3)
  rand bit [1:0]               lock;

  // Memory bufferable/cacheable attributes (AWCACHE/ARCACHE)
  rand bit [3:0]               cache;

  // Access protection level: Privileged/Secure/Instruction qualifiers (AWPROT/ARPROT)
  rand bit [2:0]               prot;

  // ---------------------------------------------------------------------------
  // 2. Write Data Channel Payloads (WDATA & WSTRB)
  // ---------------------------------------------------------------------------
  // Dynamic array carrying data for each beat; explicitly dimensioned to len + 1
  rand bit [DATA_WIDTH-1:0]    wdata[];

  // Byte lane enable strobes per beat; 1 bit corresponds to 1 active byte on WDATA
  rand bit [STRB_WIDTH-1:0]    wstrb[];

  // ---------------------------------------------------------------------------
  // 3. Slave Response Fields (Sampled by Driver / Monitor)
  // ---------------------------------------------------------------------------
  // Write response identifier returned on B channel; must match originating AWID
  bit [ID_WIDTH-1:0]           bid;

  // Final write status (BRESP): OKAY, EXOKAY, SLVERR, or DECERR
  axi_resp_e                   bresp;

  // Read transfer identifiers sampled beat-by-beat on R channel (RID)
  bit [ID_WIDTH-1:0]           rid[];

  // Read data beats received from the slave / memory (RDATA)
  bit [DATA_WIDTH-1:0]         rdata[];

  // Read status qualification per beat (RRESP)
  axi_resp_e                   rresp[];

  // ---------------------------------------------------------------------------
  // 4. Testbench Synchronization & Internal State Tracking
  // (NOTE: Kept outside `uvm_field_*` macros to prevent vlog-2294 compiler errors)
  // ---------------------------------------------------------------------------
  // Tracks current beat progression during multi-beat driving or monitoring
  int                          current_beat;

  // Handshake flag asserted when all transaction phases (Addr, Data, Resp) finish
  bit                          is_completed;

  // Event triggered to unblock sequence threads waiting on burst completion
  event                        done_event;

  // Pointer to the original sequence item; prevents event deadlocks when driver clones
  axi_seq_item                 orig_item;

  // ---------------------------------------------------------------------------
  // 5. Protocol Constraints
  // ---------------------------------------------------------------------------
  // Ensure transfer beat size does not exceed the physical data bus width
  constraint c_default_size {
    size == $clog2(STRB_WIDTH);
  }

  // Force payload dynamic array allocations to match the burst transfer count
  constraint c_payload_sizes {
    solve len before wdata;
    solve len before wstrb;
    wdata.size() == len + 1;
    wstrb.size() == len + 1;
  }

  // AMBA Spec: Bursts must never cross a 4KB (4096-byte) slave boundary
  constraint c_4k_boundary {
    if (burst == BURST_INCR) {
      ((addr & 12'hFFF) + ((len + 1) * (1 << size))) <= 4096;
    }
  }

  // AMBA Spec: WRAP bursts must be power-of-2 (2, 4, 8, 16 beats) and aligned to total bytes
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
    `uvm_field_int(is_completed,                    UVM_DEFAULT | UVM_NOPRINT)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // 7. Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_seq_item");
    super.new(name);
    current_beat = 0;
    is_completed = 0;
    orig_item    = null;
  endfunction

  // ---------------------------------------------------------------------------
  // 8. Post-Randomize Hook
  // ---------------------------------------------------------------------------
  // Fallback safety to guarantee array sizing if constraints are overridden
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
  // Extends standard UVM copy to preserve response arrays and orig_item reference
  virtual function void do_copy(uvm_object rhs);
    axi_seq_item rhs_;
    if (!$cast(rhs_, rhs)) begin
      `uvm_error("DO_COPY", "Cast failed in axi_seq_item::do_copy")
      return;
    end
    super.do_copy(rhs);
    this.trans_type   = rhs_.trans_type;
    this.id           = rhs_.id;
    this.addr         = rhs_.addr;
    this.len          = rhs_.len;
    this.size         = rhs_.size;
    this.burst        = rhs_.burst;
    this.lock         = rhs_.lock;
    this.cache        = rhs_.cache;
    this.prot         = rhs_.prot;
    this.wdata        = rhs_.wdata;
    this.wstrb        = rhs_.wstrb;
    this.bid          = rhs_.bid;
    this.bresp        = rhs_.bresp;
    this.rid          = rhs_.rid;
    this.rdata        = rhs_.rdata;
    this.rresp        = rhs_.rresp;
    this.current_beat = rhs_.current_beat;
    this.is_completed = rhs_.is_completed;
    this.orig_item    = rhs_.orig_item; // Preserves upstream thread link
  endfunction : do_copy

endclass : axi_seq_item
