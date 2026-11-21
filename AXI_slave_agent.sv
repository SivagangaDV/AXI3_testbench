class axi_slave_agent extends uvm_agent;

  `uvm_component_utils(axi_slave_agent)

  axi_slave_mon mon;

  function new(string name = "axi_slave_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Purely passive agent - only builds the slave-side monitor
    mon = axi_slave_mon::type_id::create("mon", this);
  endfunction : build_phase

endclass : axi_slave_agent