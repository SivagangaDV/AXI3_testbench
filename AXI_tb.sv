`timescale 1ns / 1ps

`include "uvm_macros.svh"
import uvm_pkg::*; 

`include "AXI_SLAVE.v"
`include "axi_intf.sv"

`include "axi_include_pkg.sv"
import axi_include_pkg::*;

module axi_tb_top;

    bit ACLK;
    bit ARESETn;

    // -------------------------------------------------------------------------
    // 1. Interface Instantiation
    // Mapping package constants (ID_WIDTH, ADDR_WIDTH, etc.) to interface params
    // -------------------------------------------------------------------------
    axi_interface #(
        .ID_WIDTH   (ID_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .LEN_WIDTH  (LEN_WIDTH),
        .SIZE_WIDTH (SIZE_WIDTH)
    ) vif (
        .ACLK    (ACLK),
        .ARESETn (ARESETn)
    );

    // -------------------------------------------------------------------------
    // 2. DUT Instantiation
    // -------------------------------------------------------------------------
    AXI_SLAVE #(
        .AXI_ID_WIDTH   (ID_WIDTH),
        .AXI_ADDR_WIDTH (ADDR_WIDTH),
        .AXI_DATA_WIDTH (DATA_WIDTH),
        .AXI_LEN_WIDTH  (LEN_WIDTH),
        .AXI_SIZE_WIDTH (SIZE_WIDTH),
        .NUM_SLOTS      (NUM_SLOTS)
    ) DUT (
        .ACLK    (ACLK),
        .ARESETn (ARESETn),

        // Write Address Channel (AW)
        .AWID    (vif.AWID),
        .AWADDR  (vif.AWADDR),
        .AWLEN   (vif.AWLEN),
        .AWSIZE  (vif.AWSIZE),
        .AWBURST (vif.AWBURST),
        .AWLOCK  (vif.AWLOCK),
        .AWCACHE (vif.AWCACHE),
        .AWPROT  (vif.AWPROT),
        .AWVALID (vif.AWVALID),
        .AWREADY (vif.AWREADY),

        // Write Data Channel (W)
        .WID     (vif.WID),
        .WDATA   (vif.WDATA),
        .WSTRB   (vif.WSTRB),
        .WLAST   (vif.WLAST),
        .WVALID  (vif.WVALID),
        .WREADY  (vif.WREADY),

        // Write Response Channel (B)
        .BID     (vif.BID),
        .BRESP   (vif.BRESP),
        .BVALID  (vif.BVALID),
        .BREADY  (vif.BREADY),

        // Read Address Channel (AR)
        .ARID    (vif.ARID),
        .ARADDR  (vif.ARADDR),
        .ARLEN   (vif.ARLEN),
        .ARSIZE  (vif.ARSIZE),
        .ARBURST (vif.ARBURST),
        .ARLOCK  (vif.ARLOCK),
        .ARCACHE (vif.ARCACHE),
        .ARPROT  (vif.ARPROT),
        .ARVALID (vif.ARVALID),
        .ARREADY (vif.ARREADY),

        // Read Data Channel (R)
        .RID     (vif.RID),
        .RDATA   (vif.RDATA),
        .RRESP   (vif.RRESP),
        .RLAST   (vif.RLAST),
        .RVALID  (vif.RVALID),
        .RREADY  (vif.RREADY)
    );

    // -------------------------------------------------------------------------
    // 3. UVM Configuration DB Registration & Test Start
    // -------------------------------------------------------------------------
    initial begin
        uvm_config_db#(virtual axi_interface #(
            .AXI_ID_WIDTH   (ID_WIDTH),
            .AXI_ADDR_WIDTH (ADDR_WIDTH),
            .AXI_DATA_WIDTH (DATA_WIDTH),
            .AXI_LEN_WIDTH  (LEN_WIDTH),
            .AXI_SIZE_WIDTH (SIZE_WIDTH)
        ))::set(null, "*", "vif", vif);

        run_test();
    end

    // -------------------------------------------------------------------------
    // 4. Clock and Reset Generation
    // -------------------------------------------------------------------------
    // 250MHz Clock (4ns period)
    always begin
        ACLK = #2ns ~ACLK;
    end

    initial begin
        ACLK    = 1'b0;
        ARESETn = 1'b1;
		@(posedge ACLK); 
		@(posedge ACLK); 
		ARESETn = 1'b0;				// Assert reset immediately at time 0
        repeat (4) @(posedge ACLK);    // Hold in reset for 4 cycles
        ARESETn = 1'b1;                // Deassert reset synchronously
    end

    initial begin
        $timeformat(-9, 0, " ns", 10);
    end

endmodule : axi_tb_top