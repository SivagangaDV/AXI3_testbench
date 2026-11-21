package axi_include_pkg;

  // Import UVM Macros and Package
  `include "uvm_macros.svh"
  import uvm_pkg::*;
  
  // ---------------------------------------------------------------------------
  // Global Protocol & Architecture Parameters
  // ---------------------------------------------------------------------------
  parameter int ID_WIDTH   = 4;
  parameter int ADDR_WIDTH = 16;
  parameter int DATA_WIDTH = 32;
  parameter int LEN_WIDTH  = 4;
  parameter int SIZE_WIDTH = 3;
  parameter int STRB_WIDTH = DATA_WIDTH / 8; // 4 bytes
  parameter int NUM_SLOTS  = 4;

  // ---------------------------------------------------------------------------
  // Protocol Enumerations
  // ---------------------------------------------------------------------------
  typedef enum bit {
    AXI_READ  = 1'b0,
    AXI_WRITE = 1'b1
  } axi_trans_type_e;

  typedef enum bit [1:0] {
    BURST_FIXED = 2'b00,
    BURST_INCR  = 2'b01,
    BURST_WRAP  = 2'b10,
    BURST_RSVD  = 2'b11
  } axi_burst_e;

  typedef enum bit [1:0] {
    RESP_OKAY   = 2'b00,
    RESP_EXOKAY = 2'b01,
    RESP_SLVERR = 2'b10,
    RESP_DECERR = 2'b11
  } axi_resp_e;
  
  `include "AXI_seq_item.sv"
  `include "AXI_sequencer.sv"
  `include "AXI_driver_config.sv"
  `include "AXI_master_driver.sv"
  `include "AXI_monitor_config.sv"
  `include "AXI_master_monitor.sv"
  `include "AXI_master_agent.sv"
  `include "AXI_slave_monitor.sv"
  `include "AXI_slave_agent.sv"
  `include "AXI_Coverage.sv"
  `include "AXI_Scoreboard.sv"
  `include "AXI_Env.sv"
  `include "AXI_Base_Test.sv"
  `include "AXI_Base_Sequence.sv"
  `include "AXI_Functional_Sequences.sv"
  `include "AXI_Err_sequences.sv"
  `include "AXI_Functional_Tests.sv"
  `include "AXI_ERR_tests.sv"
  
endpackage : axi_include_pkg
