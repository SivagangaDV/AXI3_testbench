class axi_base_test extends uvm_test;

  `uvm_component_utils(axi_base_test)

  // ---------------------------------------------------------------------------
  // Environment & Configuration Handles
  // ---------------------------------------------------------------------------
  axi_env             env;
  axi_driver_config   master_drv_cfg;
  axi_monitor_config  master_mon_cfg;
  axi_monitor_config  slave_mon_cfg;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // Build Phase: Create configs, set in config_db, and instantiate env
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create Master Driver and Monitor Configuration Objects
    master_drv_cfg = axi_driver_config::type_id::create("master_drv_cfg");
    master_mon_cfg = axi_monitor_config::type_id::create("master_mon_cfg");
    slave_mon_cfg  = axi_monitor_config::type_id::create("slave_mon_cfg");

    // Assign configurations to their target component paths
    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);

    // Instantiate Verification Environment
    env = axi_env::type_id::create("env", this);
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // End of Elaboration Phase: Set verbosity and print topology
  // ---------------------------------------------------------------------------
  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);

    // Set overall testbench verbosity level
    uvm_top.set_report_verbosity_level(UVM_LOW);

    // Print testbench structure topology
    `uvm_info("AXI_BASE_TEST", "Printing AXI Testbench Topology...", UVM_LOW)
    uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  // ---------------------------------------------------------------------------
  // Report Phase: Categorize and display final execution status
  // ---------------------------------------------------------------------------
  virtual function void report_phase(uvm_phase phase);
    uvm_report_server svr;
    int err_count;
    int fatal_count;
    int warning_count;

    super.report_phase(phase);

    // Retrieve UVM report server instance and error/warning counts
    svr           = uvm_report_server::get_server();
    err_count     = svr.get_severity_count(UVM_ERROR);
    fatal_count   = svr.get_severity_count(UVM_FATAL);
    warning_count = svr.get_severity_count(UVM_WARNING);

    `uvm_info("AXI_BASE_TEST", "==========================================================", UVM_LOW)
    `uvm_info("AXI_BASE_TEST", "                 TEST EXECUTION SUMMARY                   ", UVM_LOW)
    `uvm_info("AXI_BASE_TEST", "==========================================================", UVM_LOW)
    `uvm_info("AXI_BASE_TEST", $sformatf(" Total Warnings : %0d", warning_count), UVM_LOW)
    `uvm_info("AXI_BASE_TEST", $sformatf(" Total Errors   : %0d", err_count), UVM_LOW)
    `uvm_info("AXI_BASE_TEST", $sformatf(" Total Fatals   : %0d", fatal_count), UVM_LOW)
    `uvm_info("AXI_BASE_TEST", "----------------------------------------------------------", UVM_LOW)

    // Evaluate final result
    if (err_count > 0 || fatal_count > 0) begin
      `uvm_error("TEST_FAIL", "==========================================================")
      `uvm_error("TEST_FAIL", "               TEST STATUS: TEST FAILED                   ")
      `uvm_error("TEST_FAIL", "==========================================================")
    end else if (warning_count > 0) begin
      `uvm_info("TEST_PASS_WARN", "==========================================================", UVM_LOW)
      `uvm_info("TEST_PASS_WARN", "         TEST STATUS: TEST PASSED WITH WARNINGS           ", UVM_LOW)
      `uvm_info("TEST_PASS_WARN", "==========================================================", UVM_LOW)
    end else begin
      `uvm_info("TEST_PASS", "==========================================================", UVM_LOW)
      `uvm_info("TEST_PASS", "               TEST STATUS: TEST PASSED                   ", UVM_LOW)
      `uvm_info("TEST_PASS", "==========================================================", UVM_LOW)
    end
  endfunction : report_phase

endclass : axi_base_test