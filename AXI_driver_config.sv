class axi_driver_config extends uvm_object;

  // ---------------------------------------------------------------------------
  // Pipeline & In-Flight Burst Capacity Controls
  // ---------------------------------------------------------------------------
  int max_inflight_aw               = NUM_SLOTS;    // Max concurrent outstanding AW requests
  int max_inflight_ar               = NUM_SLOTS;    // Max concurrent outstanding AR requests
  bit enable_write_interleaving     = 1'b0;
  bit enable_aw_overlap             = 1'b0;
  bit enable_ar_overlap             = 1'b0;

  // ---------------------------------------------------------------------------
  // Write Data (W) Channel Timing & W-Before-AW Controls
  // ---------------------------------------------------------------------------
  int wvalid_beat_delay_clk         = 0;    // Clock delay between write data beats
  int wdata_before_addr_delay_clk   = 0;    // Clock delay/window before releasing AW
  int post_wlast_delay_clk          = 1;    // Idle cycles after WLAST before next write burst asserts WVALID
  bit wait_aw_before_next_wdata     = 1'b1; // Requires AW handshake before W starts when W-before-AW is off
  bit enable_wdata_before_addr      = 1'b0; // Starts W beats before AW is driven
  int pre_aw_wdata_beats            = 2;    // W beats to complete before AW starts (set >= len+1 for full burst)
  int max_pre_aw_wait_cycles        = 20;   // Max cycles to wait for pre-AW beats before releasing AW
  bit inject_wdata_before_addr_once = 1'b0; // Auto-clears enable_wdata_before_addr after 1 transaction

  // ---------------------------------------------------------------------------
  // Write Response (B) Channel Ready Timing
  // ---------------------------------------------------------------------------
  bit bready_rand_delay_enable      = 1'b0;
  int bready_max_rand_delay         = 3;
  int bready_delay_clk              = 0;

  // ---------------------------------------------------------------------------
  // Read Data (R) Channel Ready Timing
  // ---------------------------------------------------------------------------
  bit rready_rand_delay_enable      = 1'b0;
  int rready_max_rand_delay         = 3;
  int rready_delay_clk              = 0;

  // ---------------------------------------------------------------------------
  // Error Injection Knobs expected by axi_master_drv
  // ---------------------------------------------------------------------------
  bit inject_illegal_awburst        = 1'b0; // Forces AWBURST = 2'b11
  bit inject_misaligned_wrap_addr   = 1'b0; // Unaligns WRAP start address
  bit inject_corrupt_wlast          = 1'b0; // Injects corrupt/early/missing WLAST
  int inject_corrupt_wlast_beat     = 0;    // Beat index to assert early WLAST
  bit inject_corrupt_wstrb_zero     = 1'b0; // Forces WSTRB = '0
  bit inject_illegal_arburst        = 1'b0; // Forces ARBURST = 2'b11
  bit inject_4k_crossing_ar         = 1'b0; // Forces ARADDR to cross 4KB page boundary
  bit inject_AW_wrap_burst_len      = 1'b0; // Forces AWLEN illegal values in Wrap
  bit inject_AR_wrap_burst_len      = 1'b0; // Forces ARLEN illegal values in Wrap
  bit inject_Error_only_once        = 1'b0; // Forces Error only once

  `uvm_object_utils_begin(axi_driver_config)
    `uvm_field_int(max_inflight_aw,               UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(max_inflight_ar,               UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(enable_write_interleaving,     UVM_DEFAULT)
    `uvm_field_int(enable_aw_overlap,             UVM_DEFAULT)
    `uvm_field_int(enable_ar_overlap,             UVM_DEFAULT)
    `uvm_field_int(wvalid_beat_delay_clk,         UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(wdata_before_addr_delay_clk,   UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(post_wlast_delay_clk,          UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(wait_aw_before_next_wdata,     UVM_DEFAULT)
    `uvm_field_int(enable_wdata_before_addr,      UVM_DEFAULT)
    `uvm_field_int(pre_aw_wdata_beats,            UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(max_pre_aw_wait_cycles,        UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(inject_wdata_before_addr_once, UVM_DEFAULT)
    `uvm_field_int(bready_rand_delay_enable,      UVM_DEFAULT)
    `uvm_field_int(bready_max_rand_delay,         UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(bready_delay_clk,              UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(rready_rand_delay_enable,      UVM_DEFAULT)
    `uvm_field_int(rready_max_rand_delay,         UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(rready_delay_clk,              UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(inject_illegal_awburst,        UVM_DEFAULT)
    `uvm_field_int(inject_misaligned_wrap_addr,   UVM_DEFAULT)
    `uvm_field_int(inject_corrupt_wlast,          UVM_DEFAULT)
    `uvm_field_int(inject_corrupt_wlast_beat,     UVM_DEFAULT | UVM_DEC)
    `uvm_field_int(inject_corrupt_wstrb_zero,     UVM_DEFAULT)
    `uvm_field_int(inject_illegal_arburst,        UVM_DEFAULT)
    `uvm_field_int(inject_4k_crossing_ar,         UVM_DEFAULT)
    `uvm_field_int(inject_AW_wrap_burst_len,      UVM_DEFAULT)
    `uvm_field_int(inject_AR_wrap_burst_len,      UVM_DEFAULT)
    `uvm_field_int(inject_Error_only_once,        UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "axi_driver_config");
    super.new(name);
  endfunction

endclass : axi_driver_config