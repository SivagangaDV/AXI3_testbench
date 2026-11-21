class axi_monitor_config extends uvm_object;

  // ---------------------------------------------------------------------------
  // Protocol & Negative Scenario Error Masking Bits (0 = Error, 1 = Masked/Ignored)
  // ---------------------------------------------------------------------------
  bit mask_early_wlast_err      = 1'b0; // Mask premature WLAST protocol errors
  bit mask_missing_wlast_err    = 1'b0; // Mask missing WLAST on final beat errors
  bit mask_early_rlast_err        = 1'b0;
  bit mask_missing_rlast_err      = 1'b0;
  bit mask_wstrb_zero_err       = 1'b0; // Mask all-zero strobe assertions
  bit mask_illegal_burst_err    = 1'b0; // Mask reserved burst type (2'b11) errors
  bit mask_wrap_rules_err       = 1'b0; // Mask WRAP unaligned address / length violations
  bit mask_4k_boundary_err      = 1'b0; // Mask 4KB page boundary crossing violations
  bit mask_burst_size_err       = 1'b0; // Mask AxSIZE exceeding bus width violations
  bit mask_id_order_err         = 1'b0; // Mask out-of-order responses on identical IDs (AXI3 §A5.2)
  bit mask_stability_err        = 1'b0; // Mask signal mutation while VALID is HIGH without READY
  bit mask_unexpected_resp_err  = 1'b0; // Mask unexpected BID / RID assertions
  bit mask_slverr_bresp_err  = 1'b0; // Mask SLAVE Error for Write
  bit mask_slverr_rresp_err  = 1'b0; // Mask SLAVE Error for Read
  bit mask_decerr_bresp_err  = 1'b0; // Mask DECODE Error for Write
  bit mask_decerr_rresp_err  = 1'b0; // Mask DECODE Error for Read

  // ---------------------------------------------------------------------------
  // General Monitor Controls
  // ---------------------------------------------------------------------------
  bit enable_coverage           = 1'b0;
  bit enable_protocol_checks    = 1'b1;

  // ---------------------------------------------------------------------------
  // UVM Field Automation Macros
  // ---------------------------------------------------------------------------
  `uvm_object_utils_begin(axi_monitor_config)
    `uvm_field_int(mask_early_wlast_err,     UVM_DEFAULT)
    `uvm_field_int(mask_missing_wlast_err,   UVM_DEFAULT)
    `uvm_field_int(mask_early_rlast_err,     UVM_DEFAULT)
    `uvm_field_int(mask_missing_rlast_err,   UVM_DEFAULT)
    `uvm_field_int(mask_wstrb_zero_err,      UVM_DEFAULT)
    `uvm_field_int(mask_illegal_burst_err,   UVM_DEFAULT)
    `uvm_field_int(mask_wrap_rules_err,      UVM_DEFAULT)
    `uvm_field_int(mask_4k_boundary_err,     UVM_DEFAULT)
    `uvm_field_int(mask_burst_size_err,      UVM_DEFAULT)
    `uvm_field_int(mask_id_order_err,        UVM_DEFAULT)
    `uvm_field_int(mask_stability_err,       UVM_DEFAULT)
    `uvm_field_int(mask_unexpected_resp_err, UVM_DEFAULT)
    `uvm_field_int(mask_slverr_bresp_err, UVM_DEFAULT)
    `uvm_field_int(mask_slverr_rresp_err, UVM_DEFAULT)
    `uvm_field_int(mask_decerr_bresp_err, UVM_DEFAULT)
    `uvm_field_int(mask_decerr_rresp_err, UVM_DEFAULT)
    `uvm_field_int(enable_coverage,          UVM_DEFAULT)
    `uvm_field_int(enable_protocol_checks,   UVM_DEFAULT)
  `uvm_object_utils_end

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_monitor_config");
    super.new(name);
  endfunction

endclass : axi_monitor_config
