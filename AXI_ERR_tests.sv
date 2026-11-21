// =============================================================================
// Test Name : AXI3_Slverr_init_test
// Spec Ref  : AMBA AXI3 Protocol Specification v1.0, Section A3.4.5 (SLVERR)
// =============================================================================
class AXI3_Slverr_init_test extends axi_base_test;

  `uvm_component_utils(AXI3_Slverr_init_test)

  axi_all_slverr_interleaved_seq slverr_seq;

  function new(string name = "AXI3_Slverr_init_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction : new
  
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Assert error injection bits
    master_drv_cfg.inject_AW_wrap_burst_len         = 1'b1;
    master_drv_cfg.inject_AR_wrap_burst_len         = 1'b1;
    master_drv_cfg.inject_Error_only_once	    = 1'b1;
    master_drv_cfg.inject_illegal_awburst	    = 1'b1;
    master_drv_cfg.inject_illegal_arburst	    = 1'b1;

    uvm_config_db#(axi_driver_config)::set(this, "env.mstr_agent.drv", "master_driver_config", master_drv_cfg);

    ///Mask the Monitor Expected errors
    master_mon_cfg.mask_illegal_burst_err	= 1'b1;
    master_mon_cfg.mask_slverr_bresp_err	= 1'b1;
    master_mon_cfg.mask_slverr_rresp_err	= 1'b1;
    master_mon_cfg.mask_wrap_rules_err	= 1'b1;
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    
    slave_mon_cfg.mask_illegal_burst_err	= 1'b1;
    slave_mon_cfg.mask_slverr_bresp_err	= 1'b1;
    slave_mon_cfg.mask_slverr_rresp_err	= 1'b1;
    slave_mon_cfg.mask_wrap_rules_err	= 1'b1;
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction : build_phase

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Slverr_init_test");

    `uvm_info(get_type_name(), "=== [Sno 10: AXI3_Slverr_init_test Started] ===", UVM_LOW)

    slverr_seq = axi_all_slverr_interleaved_seq::type_id::create("slverr_seq");
	
    slverr_seq.start(env.mstr_agent.sqr);

    #50ns; // Drain time to settle bus pipelines and lingering handshakes

    `uvm_info(get_type_name(), "=== [Sno 10: AXI3_Slverr_init_test Completed] ===", UVM_LOW)

    phase.drop_objection(this, "Completed AXI3_Slverr_init_test");
  endtask : run_phase

endclass : AXI3_Slverr_init_test


class AXI3_Unaligned_Address_test extends axi_base_test;
  `uvm_component_utils(AXI3_Unaligned_Address_test)

  axi3_unaligned_address_seq unaligned_seq;

  function new(string name = "AXI3_Unaligned_Address_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    unaligned_seq = axi3_unaligned_address_seq::type_id::create("unaligned_seq");
	
	///Mask the Monitor Expected errors
    master_mon_cfg.mask_slverr_bresp_err	= 1'b1;
    master_mon_cfg.mask_slverr_rresp_err	= 1'b1;
    master_mon_cfg.mask_wrap_rules_err	= 1'b1;
    uvm_config_db#(axi_monitor_config)::set(this, "env.mstr_agent.mon", "master_mon_cfg", master_mon_cfg);
    
    slave_mon_cfg.mask_slverr_bresp_err	= 1'b1;
    slave_mon_cfg.mask_slverr_rresp_err	= 1'b1;
    slave_mon_cfg.mask_wrap_rules_err	= 1'b1;
    uvm_config_db#(axi_monitor_config)::set(this, "env.slv_agt.mon", "slave_mon_cfg", slave_mon_cfg);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Unaligned_Address_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_Unaligned_Address_test (Spec A3.4.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Execute the unaligned sequence on the master agent sequencer
    unaligned_seq.start(env.mstr_agent.sqr);

    // Drain time to allow final read data packets, responses, and scoreboard checks to complete
    #50ns;

    `uvm_info(get_type_name(), "=== Completed AXI3_Unaligned_Address_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Unaligned_Address_test");
  endtask : run_phase

endclass : AXI3_Unaligned_Address_test

// =============================================================================
// Report Catcher to Demote Expected SLVERR/DECERR from Monitor Checkers
// =============================================================================
class axi_prot_security_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();
    if (id == "MST_MON/B_RESP_ERR"   || id == "SLV_MON/BRESP_ERR" ||
        id == "MST_MON/R_RESP_ERR"   || id == "SLV_MON/RDATA_UNEXP_ERR" ||
        id == "MST_MON/PROT_SEC_ERR" || id == "SLV_MON/PROT_SEC_ERR") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// =============================================================================
// Class:    AXI3_Prot_Privilege_Security_test
// Base:     axi_base_test
// Test Ref: AXI3_CTS_List Row 27 / Spec Section A5.1 (Protection Unit Support)
// =============================================================================
class AXI3_Prot_Privilege_Security_test extends axi_base_test;
  `uvm_component_utils(AXI3_Prot_Privilege_Security_test)

  axi3_prot_privilege_security_seq prot_seq;
  axi_prot_security_catcher        sec_catcher;

  function new(string name = "AXI3_Prot_Privilege_Security_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    prot_seq    = axi3_prot_privilege_security_seq::type_id::create("prot_seq");
    sec_catcher = new();
    uvm_report_cb::add(null, sec_catcher);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Prot_Privilege_Security_test");

    `uvm_info(get_type_name(), "================================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_Prot_Privilege_Security_test (Spec A5.1) ===", UVM_LOW)
    `uvm_info(get_type_name(), "================================================================", UVM_LOW)

    // Start sequence on master sequencer
    prot_seq.start(env.mstr_agent.sqr);

    #50ns;

    `uvm_info(get_type_name(), "=== Completed AXI3_Prot_Privilege_Security_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Prot_Privilege_Security_test");
  endtask : run_phase

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, sec_catcher);
  endfunction

endclass : AXI3_Prot_Privilege_Security_test

// =============================================================================
// Report Catcher to Demote Expected DECERR Response Messages
// =============================================================================
class axi_decerr_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();
    // Demote monitor error reports generated when targeting unmapped hole (>= 0x8000)
    if (id == "MST_MON/B_RESP_ERR"   || id == "SLV_MON/BRESP_ERR" ||
        id == "MST_MON/R_RESP_ERR"   || id == "SLV_MON/RDATA_UNEXP_ERR") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

// =============================================================================
// Class:    AXI3_Decerr_init_test
// Base:     axi_base_test
// Test Ref: AXI3_CTS_List Row 12: AXI3_Decerr_init_test (Spec A3.4.5)
// Flow:     Normal (0x1000) -> DECERR (0x8000) -> Recovery Normal (0x2000)
// =============================================================================
class AXI3_Decerr_init_test extends axi_base_test;
  `uvm_component_utils(AXI3_Decerr_init_test)

  axi3_decerr_recovery_seq decerr_seq;
  axi_decerr_catcher       err_catcher;

  function new(string name = "AXI3_Decerr_init_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    decerr_seq  = axi3_decerr_recovery_seq::type_id::create("decerr_seq");
    err_catcher = new();
    uvm_report_cb::add(null, err_catcher);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_Decerr_init_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_Decerr_init_test Recovery Flow       ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    // Execute the recovery sequence on the master sequencer
    decerr_seq.start(env.mstr_agent.sqr);

    #500ns; // Drain time to allow slave responses and scoreboard checks to settle

    `uvm_info(get_type_name(), "=== Completed AXI3_Decerr_init_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_Decerr_init_test");
  endtask : run_phase

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, err_catcher);
  endfunction

endclass : AXI3_Decerr_init_test

class axi_4k_boundary_catcher extends uvm_report_catcher;
  virtual function action_e catch();
    string id = get_id();

    // Demote expected protocol check errors during deliberate 4KB violation injection
    if (id == "MST_MON/PROT_4K_AW"           || 
        id == "MST_MON/PROT_4K_AR"           || 
        id == "SLV_MON/PROT_4K_VIOLATION"    ||
        id == "SLV_MON/PROT_4K_AR"           || // Added slave monitor read 4KB violation tag
        id == "MST_MON/B_RESP_ERR"           || 
        id == "SLV_MON/BRESP_ERR"            ||
        id == "MST_MON/R_RESP_ERR"           || 
        id == "SLV_MON/RDATA_UNEXP_ERR"      ||
        id == "AXI_ERRM_AWADDR_BOUNDARY_4KB" || 
        id == "AXI_ERRM_ARADDR_BOUNDARY_4KB") begin
      set_severity(UVM_INFO);
      return THROW;
    end
    return THROW;
  endfunction
endclass

class AXI3_4KB_Boundary_test extends axi_base_test;
  `uvm_component_utils(AXI3_4KB_Boundary_test)

  axi3_4kb_boundary_seq   boundary_seq;
  axi_4k_boundary_catcher err_catcher;

  function new(string name = "AXI3_4KB_Boundary_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    boundary_seq = axi3_4kb_boundary_seq::type_id::create("boundary_seq");
    err_catcher  = new();
    uvm_report_cb::add(null, err_catcher);
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this, "Starting AXI3_4KB_Boundary_test");

    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)
    `uvm_info(get_type_name(), "=== Starting AXI3_4KB_Boundary_test (Spec A3.4.1)      ===", UVM_LOW)
    `uvm_info(get_type_name(), "==========================================================", UVM_LOW)

    boundary_seq.start(env.mstr_agent.sqr);

    #50ns;

    `uvm_info(get_type_name(), "=== Completed AXI3_4KB_Boundary_test ===", UVM_LOW)
    phase.drop_objection(this, "Completed AXI3_4KB_Boundary_test");
  endtask : run_phase

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    uvm_report_cb::delete(null, err_catcher);
  endfunction

endclass : AXI3_4KB_Boundary_test