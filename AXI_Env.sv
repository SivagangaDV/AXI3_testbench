class axi_env extends uvm_env;

  `uvm_component_utils(axi_env)

  // ---------------------------------------------------------------------------
  // Verification Components
  // ---------------------------------------------------------------------------
  axi_master_agent mstr_agent; // Active Master Agent (Driver, Monitor, Sequencer)
  axi_slave_agent  slv_agt;    // Passive Slave Agent (Monitor only)
  axi_scoreboard   sb;         // Dual-input Scoreboard (MST vs SLV checking)
  axi_coverage     cov;        // Functional Coverage Subscriber

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  function new(string name = "axi_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // ---------------------------------------------------------------------------
  // Build Phase
  // ---------------------------------------------------------------------------
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Explicitly configure the slave agent as passive for RTL slave DUT verification
    uvm_config_db#(uvm_active_passive_enum)::set(this, "slv_agt", "is_active", UVM_PASSIVE);

    // Instantiate Agents, Scoreboard, and Coverage components
    mstr_agent = axi_master_agent::type_id::create("mstr_agent", this);
    slv_agt    = axi_slave_agent::type_id::create("slv_agt", this);
    sb         = axi_scoreboard::type_id::create("sb", this);
    cov        = axi_coverage::type_id::create("cov", this);
  endfunction : build_phase

  // ---------------------------------------------------------------------------
  // Connect Phase
  // ---------------------------------------------------------------------------
  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    // Connect Master Monitor directly to Scoreboard master input
    mstr_agent.mon.mon_ap.connect(sb.mst_export);

    // Connect Slave Monitor directly to Scoreboard slave input
    slv_agt.mon.mon_ap.connect(sb.slv_export);

    // Connect Master Monitor to Coverage model
    mstr_agent.mon.mon_ap.connect(cov.analysis_export);
  endfunction : connect_phase

endclass : axi_env
