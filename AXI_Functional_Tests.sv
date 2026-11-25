// -----------------------------------------------------------------------------
// AXI3 Sanity Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_Sanity_test extends axi_base_test;

  `uvm_component_utils(AXI3_Sanity_test)

  function new(string name = "AXI3_Sanity_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b0; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_sanity_seq seq;

    phase.raise_objection(this);

    `uvm_info("SANITY_TEST", "Executing axi_sanity_seq on Master Sequencer...", UVM_LOW)
    seq = axi_sanity_seq::type_id::create("seq");
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_Sanity_test

// -----------------------------------------------------------------------------
// AXI3 Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_Fixed_Burst_test extends axi_base_test;

  `uvm_component_utils(AXI3_Fixed_Burst_test)

  function new(string name = "AXI3_Fixed_Burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b0; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_fixed_burst_seq seq;

    phase.raise_objection(this);

    `uvm_info("FIXED_BURST_TEST", "Executing axi_fixed_burst_seq on Master Sequencer...", UVM_LOW)
    seq = axi_fixed_burst_seq::type_id::create("seq");
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_Fixed_Burst_test

// -----------------------------------------------------------------------------
// AXI3 Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_incr_Burst_test extends axi_base_test;

  `uvm_component_utils(AXI3_incr_Burst_test)

  function new(string name = "AXI3_incr_Burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b0; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_incr_burst_seq seq;

    phase.raise_objection(this);

    `uvm_info("INCR_BURST_TEST", "Executing axi_incr_burst_seq on Master Sequencer...", UVM_LOW)
    seq = axi_incr_burst_seq::type_id::create("seq");
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_incr_Burst_test

// -----------------------------------------------------------------------------
// AXI3 Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_wrap_Burst_test extends axi_base_test;

  `uvm_component_utils(AXI3_wrap_Burst_test)

  function new(string name = "AXI3_wrap_Burst_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b0; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_wrap_burst_seq seq;

    phase.raise_objection(this);

    `uvm_info("WRAP_BURST_TEST", "Executing axi_wrap_burst_seq on Master Sequencer...", UVM_LOW)
    seq = axi_wrap_burst_seq::type_id::create("seq");
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_wrap_Burst_test

// -----------------------------------------------------------------------------
// AXI3 Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_Wdata_Interleave_test extends axi_base_test;

  `uvm_component_utils(AXI3_Wdata_Interleave_test)

  axi_incr_burst_seq seq;

  function new(string name = "AXI3_Wdata_Interleave_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b1; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    // Assign configurations to their target component paths
    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
 
    seq = axi_incr_burst_seq::type_id::create("seq");
    
    seq.repeat_count = 5;
    seq.test_id_random = 0;
    seq.enable_overlap = 1;
    seq.enable_interleave = 1;

  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info("WRAP_BURST_TEST", "Executing axi_incr_burst_seq on Master Sequencer...", UVM_LOW)
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_Wdata_Interleave_test

// -----------------------------------------------------------------------------
// AXI3 Test (Extending axi_base_test)
// -----------------------------------------------------------------------------
class AXI3_Addr_Before_Wdata_test extends axi_base_test;

  `uvm_component_utils(AXI3_Addr_Before_Wdata_test)

  axi_incr_burst_seq seq;

  function new(string name = "AXI3_Addr_Before_Wdata_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b0; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_drv_cfg.wvalid_beat_delay_clk     = 'd30;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    // Assign configurations to their target component paths
    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
 
    seq = axi_incr_burst_seq::type_id::create("seq");
    
    seq.repeat_count = 2;
    seq.test_id_random = 0;
    seq.enable_overlap = 1;
    seq.enable_interleave = 0;
    seq.burst_len = 3;

  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);

    phase.raise_objection(this);

    `uvm_info("TEST", "Executing axi_incr_burst_seq on Master Sequencer...", UVM_LOW)
    seq.start(env.mstr_agent.sqr);

    // Drain time for monitor and scoreboard completion
    #1ns;

    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_Addr_Before_Wdata_test

class AXI3_Concurrent_Full_Duplex_test extends axi_base_test;
  `uvm_component_utils(AXI3_Concurrent_Full_Duplex_test)

  function new(string name = "AXI3_Concurrent_Full_Duplex_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Unthrottle master driver to achieve theoretical peak throughput
    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b1; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_concurrent_full_duplex_seq seq;
    seq = axi_concurrent_full_duplex_seq::type_id::create("seq");

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "Executing AXI3_Concurrent_Full_Duplex_test...", UVM_LOW)

    // Configure concurrency knobs in sequence
    seq.enable_overlap    = 1'b1;
    seq.enable_interleave = 1'b1;
    seq.num_iterations    = 'd10000; // Set iterations for regression (e.g. 100 batches = 800 total bursts)

    seq.start(env.mstr_agent.sqr);

    #200ns;
    phase.drop_objection(this);
  endtask : run_phase
endclass : AXI3_Concurrent_Full_Duplex_test

class AXI3_Simultaneous_test extends axi_base_test;
  `uvm_component_utils(AXI3_Simultaneous_test)

  function new(string name = "AXI3_Simultaneous_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Unthrottle master driver to achieve theoretical peak throughput
    // Ensure driver and monitor protocol assertions are clean and active
    master_drv_cfg.enable_write_interleaving = 1'b1; // Atomic burst for baseline sanity
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_simultaneous_wrap_seq seq;
    seq = axi_simultaneous_wrap_seq::type_id::create("seq");

    phase.raise_objection(this);
    `uvm_info(get_type_name(), "Executing AXI3_Simultaneous_Wrap_test...", UVM_LOW)

    // Configure concurrency knobs in sequence
    seq.enable_overlap    = 1'b0;
    seq.enable_interleave = 1'b0;
    seq.num_iterations    = 'd100; // Set iterations for regression (e.g. 100 batches = 800 total bursts)

    seq.start(env.mstr_agent.sqr);

    #200ns;
    phase.drop_objection(this);
  endtask : run_phase
endclass : AXI3_Simultaneous_test

class AXI3_Ex_access_test extends axi_base_test;
  `uvm_component_utils(AXI3_Ex_access_test)

  axi3_ex_access_seq ex_seq;

  function new(string name = "AXI3_Ex_access_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);

    `uvm_info(get_type_name(), "=== Starting Test: AXI3_Ex_access_test (Multi-Iteration Burst Sweep) ===", UVM_LOW)

    ex_seq = axi3_ex_access_seq::type_id::create("ex_seq");

    // Configure the repetition count across random legal exclusive burst profiles
    if (!ex_seq.randomize() with {
      num_iterations == 20; // Number of repeated iterations
    }) begin
      `uvm_fatal(get_type_name(), "Failed to randomize exclusive access sequence!")
    end

    // Execute on the master agent sequencer
    ex_seq.start(env.mstr_agent.sqr);

    #100ns; // Post-test drain time
    phase.drop_objection(this);
  endtask : run_phase

endclass : AXI3_Ex_access_test

class AXI3_Narrow_txr_test extends axi_base_test;
  `uvm_component_utils(AXI3_Narrow_txr_test)

  axi3_narrow_txr_seq narrow_seq;

  function new(string name = "AXI3_Narrow_txr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    narrow_seq = axi3_narrow_txr_seq::type_id::create("narrow_seq");
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Narrow_txr_test");

    `uvm_info(get_type_name(), "=== Starting AXI3_Narrow_txr_test (All Burst Types) ===", UVM_LOW)

    // Execute the narrow sequence on the master sequencer
    narrow_seq.start(env.mstr_agent.sqr);

    #50ns; // Drain time to complete outstanding slave write/read responses

    `uvm_info(get_type_name(), "=== Completed AXI3_Narrow_txr_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Narrow_txr_test");
  endtask : run_phase

endclass : AXI3_Narrow_txr_test

// =============================================================================
// Class:    AXI3_Zero_Wstrb_test
// Base:     axi_base_test
// Test Ref: AXI3_CTS_List Row 16 / Spec Section A3.4.4 (Write Data & Strobe Controls)
// Purpose:  Validates that bursts with WSTRB = '0 complete without hangs,
//           return BRESP = OKAY, and leave memory content completely unmodified.
// =============================================================================
class AXI3_Zero_Wstrb_test extends axi_base_test;
  `uvm_component_utils(AXI3_Zero_Wstrb_test)

  axi3_zero_wstrb_seq zero_wstrb_seq;

  function new(string name = "AXI3_Zero_Wstrb_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    zero_wstrb_seq = axi3_zero_wstrb_seq::type_id::create("zero_wstrb_seq");
	
	///Mask the Monitor Expected errors
    master_mon_cfg.mask_wstrb_zero_err	= 1'b1;    
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    
    slave_mon_cfg.mask_wstrb_zero_err	= 1'b1;    
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Zero_Wstrb_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_Zero_Wstrb_test (Spec Section A3.4.4) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Execute the sequence on the master sequencer
    zero_wstrb_seq.start(env.mstr_agent.sqr);

    #50ns; // Drain time to allow slave responses and scoreboard checks to complete

    `uvm_info(get_type_name(), "=== Completed AXI3_Zero_Wstrb_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Zero_Wstrb_test");
  endtask : run_phase

endclass : AXI3_Zero_Wstrb_test

// =============================================================================
// Report Catcher to Demote Expected SLVERR Reports During Lock Conflict
// =============================================================================
class axi_locked_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();
    if (id == "MST_MON/B_RESP_ERR"   || id == "SLV_MON/BRESP_ERR" ||
        id == "MST_MON/R_RESP_ERR"   || id == "SLV_MON/RDATA_UNEXP_ERR") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// =============================================================================
// Class:    AXI3_Locked_Sequence_test
// Base:     axi_base_test
// Test Ref: AXI3_CTS_List Row 22 / Spec Section A7.2 (Atomic Operations)
// =============================================================================
class AXI3_Locked_Sequence_test extends axi_base_test;
  `uvm_component_utils(AXI3_Locked_Sequence_test)

  axi3_locked_sequence_seq locked_seq;
  axi_locked_catcher       err_catcher;

  function new(string name = "AXI3_Locked_Sequence_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    locked_seq  = axi3_locked_sequence_seq::type_id::create("locked_seq");
    err_catcher = new();
    uvm_report_cb::add(null, err_catcher);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Locked_Sequence_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_Locked_Sequence_test (Spec A7.2)     ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Run the locked sequence on the master sequencer
    locked_seq.start(env.mstr_agent.sqr);

    #500ns;

    `uvm_info(get_type_name(), "=== Completed AXI3_Locked_Sequence_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Locked_Sequence_test");
  endtask : run_phase

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, err_catcher);
  endfunction

endclass : AXI3_Locked_Sequence_test

// =============================================================================
// Class:    AXI3_Mid_Reset_test
// Base:     axi_base_test
// =============================================================================
class AXI3_Mid_Reset_test extends axi_base_test;

  `uvm_component_utils(AXI3_Mid_Reset_test)

  virtual axi_interface #(
    .ID_WIDTH   (ID_WIDTH),
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .LEN_WIDTH  (LEN_WIDTH),
    .SIZE_WIDTH (SIZE_WIDTH)
  ) vif;

  function new(string name = "AXI3_Mid_Reset_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    uvm_root root_top;
    super.build_phase(phase);

    if (!uvm_config_db#(virtual axi_interface #(
      .ID_WIDTH   (ID_WIDTH),
      .ADDR_WIDTH (ADDR_WIDTH),
      .DATA_WIDTH (DATA_WIDTH),
      .LEN_WIDTH  (LEN_WIDTH),
      .SIZE_WIDTH (SIZE_WIDTH)
    ))::get(this, "", "vif", vif)) begin
      if (!uvm_config_db#(virtual axi_interface #(
        .ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (LEN_WIDTH),
        .SIZE_WIDTH (SIZE_WIDTH)
      ))::get(null, "uvm_test_top", "vif", vif)) begin
        `uvm_fatal("VIF_ERR", "Could not get virtual interface 'vif'")
      end
    end

    // Apply global severity overrides to suppress expected protocol noise during reset injection
      
   // master_mon_cfg.mask_early_wlast_err = 'd1; ///Mask the Monitor Expected errors
	//master_mon_cfg.mask_missing_wlast_err = 'd1;
    
    //slave_mon_cfg.mask_early_wlast_err = 'd1; ///Mask the Monitor Expected errors
	//slave_mon_cfg.mask_missing_wlast_err = 'd1; ///Mask the Monitor Expected errors
	
    master_drv_cfg.enable_write_interleaving = 1'b1;
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    axi_concurrent_full_duplex_seq traffic_seq;
    axi_concurrent_full_duplex_seq post_reset_seq;

    phase.raise_objection(this, "Starting AXI3_Mid_Reset_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [STAGE 1] Launching Pre-Reset High-Density Traffic ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Enable scoreboard skip_data_comparison knob during mid-reset saturation traffic 
    // to accommodate race conditions between parallel reads/writes and reset aborts.
   // env.sb.skip_data_comparison = 1'b1;

    traffic_seq = axi_concurrent_full_duplex_seq::type_id::create("traffic_seq");
    traffic_seq.enable_overlap    = 1'b1;
    traffic_seq.enable_interleave = 1'b1;
    traffic_seq.num_iterations    = 'd50;

    // -------------------------------------------------------------------------
    // Phase 1: Pre-reset concurrent traffic with mid-flight reset injection
    // -------------------------------------------------------------------------
    fork
      begin : TRAFFIC_THREAD
        traffic_seq.start(env.mstr_agent.sqr);
      end

      begin : RESET_INJECT_THREAD
        wait (vif.ARESETn === 1'b1);
        repeat (10) @(posedge vif.ACLK);

        @(posedge vif.ACLK iff (vif.AWVALID || vif.WVALID || vif.ARVALID));
        repeat (15) @(posedge vif.ACLK);

        `uvm_info(get_type_name(), "=== [STAGE 2] In-Flight Traffic Detected. Asserting ARESETn = 0 ===", UVM_LOW)
        void'(uvm_hdl_force("axi_tb_top.ARESETn", 1'b0));

        repeat (12) @(posedge vif.ACLK);

        `uvm_info(get_type_name(), "=== [STAGE 3] Deasserting ARESETn = 1 ===", UVM_LOW)
        void'(uvm_hdl_force("axi_tb_top.ARESETn", 1'b1));
        void'(uvm_hdl_release("axi_tb_top.ARESETn"));
      end
    join_any

    disable fork;

    // -------------------------------------------------------------------------
    // Phase 2: Flush sequencer and scoreboard
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "=== [STAGE 4] Flushing Sequencer, Scoreboard & Settling Bus ===", UVM_LOW)
    env.mstr_agent.sqr.stop_sequences();

    // Flush scoreboard queues and reset mismatch count
    env.sb.flush();

    repeat (25) @(posedge vif.ACLK);

    // -------------------------------------------------------------------------
    // Phase 3: Launch Post-Reset Validation Traffic
    // -------------------------------------------------------------------------
    `uvm_info(get_type_name(), "=== [STAGE 5] Launching Post-Reset Concurrent Full-Duplex Sequence ===", UVM_LOW)

    // Re-enable strict data payload and memory model checks for post-reset stability

    post_reset_seq = axi_concurrent_full_duplex_seq::type_id::create("post_reset_seq");
    post_reset_seq.enable_overlap    = 1'b1;
    post_reset_seq.enable_interleave = 1'b1;
    post_reset_seq.num_iterations    = 'd25;

    post_reset_seq.start(env.mstr_agent.sqr);

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [STAGE 6] Post-Reset Concurrent Traffic Passed     ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    repeat (20) @(posedge vif.ACLK);
    phase.drop_objection(this, "Completed AXI3_Mid_Reset_test");
  endtask : run_phase

endclass : AXI3_Mid_Reset_test

///////////////////////////////////////////////////

// =============================================================================
// Report Catcher for TC-13 (Premature WLAST Error Demotion)
// =============================================================================
class axi_wlast_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();
    if (id == "MST_MON/WLAST_ERR"            ||
        id == "SLV_MON/WLAST_ERR"            ||
        id == "AXI_ERRM_WLAST_NUM_BEATS"     ||
        id == "MST_MON/WLAST_EARLY_ERR"      ||
        id == "SLV_MON/WLAST_EARLY_ERR") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// =============================================================================
// TC-13: AXI3_Wlast_Protocol_test
// Spec Ref : ARM IHI 0022E Section A3.4.4 (Write Data & Strobe Controls)
// =============================================================================
class AXI3_Wlast_Protocol_test extends axi_base_test;
  `uvm_component_utils(AXI3_Wlast_Protocol_test)

  axi3_wlast_protocol_seq wlast_seq;
  axi_wlast_catcher       err_catcher;

  function new(string name = "AXI3_Wlast_Protocol_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wlast_seq = axi3_wlast_protocol_seq::type_id::create("wlast_seq");
    err_catcher = new();
    uvm_report_cb::add(null, err_catcher);

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
	
	master_mon_cfg.mask_early_wlast_err = 'd1;
	master_mon_cfg.mask_slverr_bresp_err = 'd1;
	
	slave_mon_cfg.mask_early_wlast_err = 'd1;
	slave_mon_cfg.mask_slverr_bresp_err = 'd1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Wlast_Protocol_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-13] Starting AXI3_Wlast_Protocol_test (Spec A3.4.4) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Phase 1: Compliant WLAST sweep (1, 4, 8, 16 beats)
    wlast_seq.inject_early_wlast = 1'b0;
    wlast_seq.start(env.mstr_agent.sqr);

    #100ns;

    // Phase 2: Negative early WLAST injection
    wlast_seq.inject_early_wlast = 1'b1;
    wlast_seq.start(env.mstr_agent.sqr);

    #200ns;
    `uvm_info(get_type_name(), "=== [TC-13] Completed AXI3_Wlast_Protocol_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Wlast_Protocol_test");
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, err_catcher);
  endfunction
endclass : AXI3_Wlast_Protocol_test

// =============================================================================
// TC-14: AXI3_Rlast_Tracking_test
// Spec Ref : ARM IHI 0022E Section A3.4.4 (Read Channel Integrity & Ordering)
// =============================================================================
class AXI3_Rlast_Tracking_test extends axi_base_test;
  `uvm_component_utils(AXI3_Rlast_Tracking_test)

  axi3_rlast_tracking_seq rlast_seq;

  function new(string name = "AXI3_Rlast_Tracking_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    rlast_seq = axi3_rlast_tracking_seq::type_id::create("rlast_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Rlast_Tracking_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-14] Starting AXI3_Rlast_Tracking_test (16 Beats) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    rlast_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-14] Completed AXI3_Rlast_Tracking_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Rlast_Tracking_test");
  endtask
endclass : AXI3_Rlast_Tracking_test

// =============================================================================
// TC-15: AXI3_Sparse_Wstrb_test
// Spec Ref : ARM IHI 0022E Section A3.4.4 (Write Data & Strobe Controls)
// =============================================================================
class AXI3_Sparse_Wstrb_test extends axi_base_test;
  `uvm_component_utils(AXI3_Sparse_Wstrb_test)

  axi3_sparse_wstrb_seq sparse_seq;

  function new(string name = "AXI3_Sparse_Wstrb_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sparse_seq = axi3_sparse_wstrb_seq::type_id::create("sparse_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Sparse_Wstrb_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-15] Starting AXI3_Sparse_Wstrb_test (Spec A3.4.4) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    sparse_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-15] Completed AXI3_Sparse_Wstrb_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Sparse_Wstrb_test");
  endtask
endclass : AXI3_Sparse_Wstrb_test

// =============================================================================
// TC-17: AXI3_Wdata_Before_Addr_test
// Spec Ref : ARM IHI 0022E Section A3.3.1 (Write Data Before Write Address)
// =============================================================================
class AXI3_Wdata_Before_Addr_test extends axi_base_test;
  `uvm_component_utils(AXI3_Wdata_Before_Addr_test)

  axi3_wdata_before_addr_seq w_before_aw_seq;

  function new(string name = "AXI3_Wdata_Before_Addr_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    w_before_aw_seq = axi3_wdata_before_addr_seq::type_id::create("w_before_aw_seq");

    // Enable decoupled leading write data streaming (multiple W beats before AW)
    master_drv_cfg.enable_write_interleaving     = 1'b1;
    master_drv_cfg.enable_aw_overlap             = 1'b1;
    master_drv_cfg.enable_ar_overlap             = 1'b0;
    master_drv_cfg.enable_wdata_before_addr      = 1'b1;
    master_drv_cfg.pre_aw_wdata_beats            = 3;     // Complete 3 W beats before asserting AW
    master_drv_cfg.wdata_before_addr_delay_clk   = 5;     // Delay/window before releasing AW
    master_drv_cfg.post_wlast_delay_clk          = 1;     // Clean idle gap after WLAST before next burst
    master_drv_cfg.wait_aw_before_next_wdata     = 1'b1;
    master_drv_cfg.max_pre_aw_wait_cycles        = 50;    // Safety timeout in clock cycles
    master_drv_cfg.inject_wdata_before_addr_once = 1'b0;

    master_mon_cfg.enable_protocol_checks        = 1'b1;
    slave_mon_cfg.enable_protocol_checks         = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Wdata_Before_Addr_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-17] Starting AXI3_Wdata_Before_Addr_test (Spec A3.3.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    w_before_aw_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-17] Completed AXI3_Wdata_Before_Addr_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Wdata_Before_Addr_test");
  endtask
endclass : AXI3_Wdata_Before_Addr_test

// =============================================================================
// TC-20: AXI3_Out_Of_Order_Rid_test
// Spec Ref : ARM IHI 0022E Section A8.1 (Transaction Ordering / Multi-ID)
// =============================================================================
class AXI3_Out_Of_Order_Rid_test extends axi_base_test;
  `uvm_component_utils(AXI3_Out_Of_Order_Rid_test)

  axi3_out_of_order_rid_seq ooo_seq;

  function new(string name = "AXI3_Out_Of_Order_Rid_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ooo_seq = axi3_out_of_order_rid_seq::type_id::create("ooo_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Out_Of_Order_Rid_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-20] Starting AXI3_Out_Of_Order_Rid_test (Spec A8.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    ooo_seq.start(env.mstr_agent.sqr);

    #200ns;
    `uvm_info(get_type_name(), "=== [TC-20] Completed AXI3_Out_Of_Order_Rid_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Out_Of_Order_Rid_test");
  endtask
endclass : AXI3_Out_Of_Order_Rid_test

// =============================================================================
// TC-21: AXI3_In_Order_Same_Id_test
// Spec Ref : ARM IHI 0022E Section A8.1 (In-Order Ordering per Transaction ID)
// =============================================================================
class AXI3_In_Order_Same_Id_test extends axi_base_test;
  `uvm_component_utils(AXI3_In_Order_Same_Id_test)

  axi3_in_order_same_id_seq in_order_seq;

  function new(string name = "AXI3_In_Order_Same_Id_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    in_order_seq = axi3_in_order_same_id_seq::type_id::create("in_order_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_In_Order_Same_Id_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-21] Starting AXI3_In_Order_Same_Id_test (Spec A8.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    in_order_seq.start(env.mstr_agent.sqr);

    #200ns;
    `uvm_info(get_type_name(), "=== [TC-21] Completed AXI3_In_Order_Same_Id_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_In_Order_Same_Id_test");
  endtask
endclass : AXI3_In_Order_Same_Id_test

// =============================================================================
// TC-23: AXI3_Excl_Failure_test
// Spec Ref : ARM IHI 0022E Section A7.1 (Exclusive Access Invalidation & Failure)
// =============================================================================
class AXI3_Excl_Failure_test extends axi_base_test;
  `uvm_component_utils(AXI3_Excl_Failure_test)

  axi3_excl_failure_seq excl_fail_seq;

  function new(string name = "AXI3_Excl_Failure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    excl_fail_seq = axi3_excl_failure_seq::type_id::create("excl_fail_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Excl_Failure_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-23] Starting AXI3_Excl_Failure_test (Spec A7.1)   ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    excl_fail_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-23] Completed AXI3_Excl_Failure_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Excl_Failure_test");
  endtask
endclass : AXI3_Excl_Failure_test

// =============================================================================
// TC-24: AXI3_Slave_Backpressure_test
// Spec Ref : ARM IHI 0022E Section A3.2.1 (Handshake Dependencies & Backpressure)
// =============================================================================
class AXI3_Slave_Backpressure_test extends axi_base_test;
  `uvm_component_utils(AXI3_Slave_Backpressure_test)

  axi_sanity_seq slv_bp_seq;

  function new(string name = "AXI3_Slave_Backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    slv_bp_seq = axi_sanity_seq::type_id::create("slv_bp_seq");
	slv_bp_seq.repeat_count = 10;

    // Enable high concurrency with overlap
    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
	
	// Enable extended pseudo-random AWREADY, WREADY and ARREADY backpressure in master driver
	////

    uvm_config_db#(axi_driver_config)::set(this, "*", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "*", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "*", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Slave_Backpressure_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-24] Starting AXI3_Slave_Backpressure_test (A3.2.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)		

    slv_bp_seq.start(env.mstr_agent.sqr);

    #30ns;
    `uvm_info(get_type_name(), "=== [TC-24] Completed AXI3_Slave_Backpressure_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Slave_Backpressure_test");
  endtask
endclass : AXI3_Slave_Backpressure_test

// =============================================================================
// TC-25: AXI3_Master_Backpressure_test
// Spec Ref : ARM IHI 0022E Section A3.2.1 (Master RREADY/BREADY Stalls)
// =============================================================================
class AXI3_Master_Backpressure_test extends axi_base_test;
  `uvm_component_utils(AXI3_Master_Backpressure_test)

  axi_sanity_seq mst_bp_seq;

  function new(string name = "AXI3_Master_Backpressure_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    mst_bp_seq = axi_sanity_seq::type_id::create("mst_bp_seq");
	mst_bp_seq.repeat_count = 10;

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;
		
	// Enable extended pseudo-random BREADY and RREADY backpressure in master driver
	master_drv_cfg.bready_rand_delay_enable = 1'b1;
	master_drv_cfg.bready_delay_clk = 50;
	master_drv_cfg.rready_rand_delay_enable = 1'b1;
	master_drv_cfg.rready_delay_clk = 50;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Master_Backpressure_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-25] Starting AXI3_Master_Backpressure_test        ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    mst_bp_seq.start(env.mstr_agent.sqr);

    #200ns;
    `uvm_info(get_type_name(), "=== [TC-25] Completed AXI3_Master_Backpressure_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Master_Backpressure_test");
  endtask
endclass : AXI3_Master_Backpressure_test

// =============================================================================
// TC-28: AXI3_Cache_Attributes_test
// Spec Ref : ARM IHI 0022E Section A5.2 (Memory Type & Cache Attributes)
// =============================================================================
class AXI3_Cache_Attributes_test extends axi_base_test;
  `uvm_component_utils(AXI3_Cache_Attributes_test)

  axi3_cache_attributes_seq cache_seq;

  function new(string name = "AXI3_Cache_Attributes_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cache_seq = axi3_cache_attributes_seq::type_id::create("cache_seq");

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Cache_Attributes_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-28] Starting AXI3_Cache_Attributes_test (Spec A5.2) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    cache_seq.start(env.mstr_agent.sqr);

    #200ns;
    `uvm_info(get_type_name(), "=== [TC-28] Completed AXI3_Cache_Attributes_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Cache_Attributes_test");
  endtask
endclass : AXI3_Cache_Attributes_test

// =============================================================================
// Report Catcher for TC-29 (Illegal WRAP Length Error Demotion)
// =============================================================================
class axi_wrap_len_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();
    if (id == "MST_MON/WRAP_RULES_ERR"       ||
        id == "SLV_MON/WRAP_RULES_ERR"       ||
        id == "AXI_ERRM_WRAP_BURST_LEN"      ||
        id == "MST_MON/B_RESP_ERR"           ||
        id == "SLV_MON/BRESP_ERR") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// =============================================================================
// TC-29: AXI3_Wrap_Illegal_Length_test
// Spec Ref : ARM IHI 0022E Section A3.4.3 (WRAP Burst Length Constraints)
// =============================================================================
class AXI3_Wrap_Illegal_Length_test extends axi_base_test;
  `uvm_component_utils(AXI3_Wrap_Illegal_Length_test)

  axi3_wrap_illegal_length_seq wrap_err_seq;
  axi_wrap_len_catcher         err_catcher;

  function new(string name = "AXI3_Wrap_Illegal_Length_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    wrap_err_seq = axi3_wrap_illegal_length_seq::type_id::create("wrap_err_seq");
    err_catcher  = new();
    uvm_report_cb::add(null, err_catcher);

    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b0;
    master_drv_cfg.enable_ar_overlap         = 1'b0;

    // Mask wrap rules in monitor to allow SVA to check violation without fatal exit
    master_mon_cfg.mask_wrap_rules_err       = 1'b1;
    master_mon_cfg.mask_slverr_bresp_err     = 1'b1;
	master_mon_cfg.mask_slverr_rresp_err	 = 1'b1;
    slave_mon_cfg.mask_wrap_rules_err        = 1'b1;
    slave_mon_cfg.mask_slverr_bresp_err      = 1'b1;
	slave_mon_cfg.mask_slverr_rresp_err		 = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Wrap_Illegal_Length_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-29] Starting AXI3_Wrap_Illegal_Length_test        ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    wrap_err_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-29] Completed AXI3_Wrap_Illegal_Length_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Wrap_Illegal_Length_test");
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, err_catcher);
  endfunction
endclass : AXI3_Wrap_Illegal_Length_test

// =============================================================================
// TC-30: AXI3_Zero_Delay_BackToBack_test
// Spec Ref : ARM IHI 0022E Section A3.2.1 (Full Pipeline Saturation)
// =============================================================================
class AXI3_Zero_Delay_BackToBack_test extends axi_base_test;
  `uvm_component_utils(AXI3_Zero_Delay_BackToBack_test)

  axi3_zero_delay_back_to_back_seq zero_seq;

  function new(string name = "AXI3_Zero_Delay_BackToBack_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    zero_seq = axi3_zero_delay_back_to_back_seq::type_id::create("zero_seq");

    // Unthrottle driver pipeline for zero wait state
    master_drv_cfg.enable_write_interleaving = 1'b0;
    master_drv_cfg.enable_aw_overlap         = 1'b1;
    master_drv_cfg.enable_ar_overlap         = 1'b1;

    master_mon_cfg.enable_protocol_checks    = 1'b1;
    slave_mon_cfg.enable_protocol_checks     = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Zero_Delay_BackToBack_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== [TC-30] Starting AXI3_Zero_Delay_BackToBack_test      ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    zero_seq.start(env.mstr_agent.sqr);

    #100ns;
    `uvm_info(get_type_name(), "=== [TC-30] Completed AXI3_Zero_Delay_BackToBack_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Zero_Delay_BackToBack_test");
  endtask
endclass : AXI3_Zero_Delay_BackToBack_test
