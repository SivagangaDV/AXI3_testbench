interface axi_interface #(
    parameter int ID_WIDTH   = 4,
    parameter int ADDR_WIDTH = 16,
    parameter int DATA_WIDTH = 32,
    parameter int LEN_WIDTH  = 4,
    parameter int SIZE_WIDTH = 3,
    parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
    input wire ACLK,
    input wire ARESETn
);
    // Write Address Channel (AW)
    logic [ID_WIDTH-1:0]   AWID;
    logic [ADDR_WIDTH-1:0] AWADDR;
    logic [LEN_WIDTH-1:0]  AWLEN;
    logic [SIZE_WIDTH-1:0] AWSIZE;
    logic [1:0]            AWBURST;
    logic [1:0]            AWLOCK;
    logic [3:0]            AWCACHE;
    logic [2:0]            AWPROT;
    logic                  AWVALID;
    logic                  AWREADY;

    // Write Data Channel (W)
    logic [ID_WIDTH-1:0]   WID;
    logic [DATA_WIDTH-1:0] WDATA;
    logic [STRB_WIDTH-1:0] WSTRB;
    logic                  WLAST;
    logic                  WVALID;
    logic                  WREADY;

    // Write Response Channel (B)
    logic [ID_WIDTH-1:0]   BID;
    logic [1:0]            BRESP;
    logic                  BVALID;
    logic                  BREADY;

    // Read Address Channel (AR)
    logic [ID_WIDTH-1:0]   ARID;
    logic [ADDR_WIDTH-1:0] ARADDR;
    logic [LEN_WIDTH-1:0]  ARLEN;
    logic [SIZE_WIDTH-1:0] ARSIZE;
    logic [1:0]            ARBURST;
    logic [1:0]            ARLOCK;
    logic [3:0]            ARCACHE;
    logic [2:0]            ARPROT;
    logic                  ARVALID;
    logic                  ARREADY;

    // Read Data Channel (R)
    logic [ID_WIDTH-1:0]   RID;
    logic [DATA_WIDTH-1:0] RDATA;
    logic [1:0]            RRESP;
    logic                  RLAST;
    logic                  RVALID;
    logic                  RREADY;

endinterface : axi_interface