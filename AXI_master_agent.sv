class axi_master_agent extends uvm_agent;

  `uvm_component_utils(axi_master_agent)

  axi_master_drv drv;
  axi_master_mon mon;
  axi_sequencer  sqr;

  function new(string name = "axi_master_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Monitor is instantiated unconditionally (active or passive mode)
    mon = axi_master_mon::type_id::create("mon", this);

    if (get_is_active() == UVM_ACTIVE) begin
      drv = axi_master_drv::type_id::create("drv", this);
      sqr = axi_sequencer::type_id::create("sqr", this);
    end
  endfunction : build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    if (get_is_active() == UVM_ACTIVE) begin
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction : connect_phase

endclass : axi_master_agent