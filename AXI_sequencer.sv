class axi_sequencer extends uvm_sequencer #(axi_seq_item);

  // 1. Factory Registration
  `uvm_component_utils(axi_sequencer)

  // 2. Standard UVM Constructor
  function new(string name = "axi_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction

endclass : axi_sequencer