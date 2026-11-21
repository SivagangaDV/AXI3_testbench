`timescale 1ns / 1ps

module AXI_SLAVE #(
    parameter AXI_ID_WIDTH   = 4,
    parameter AXI_ADDR_WIDTH = 16,    // 64 KB total address space
    parameter AXI_DATA_WIDTH = 32,    // 32-bit data bus (4 byte lanes)
    parameter AXI_LEN_WIDTH  = 4,     // AXI3 strictly 4-bit AxLEN (1 to 16 beats)
    parameter AXI_SIZE_WIDTH = 3,     // AxSIZE: 0=1B, 1=2B, 2=4B
    parameter NUM_SLOTS      = 4      // Supported: 2, 4, 8, 16
)(
    input  wire                           ACLK,
    input  wire                           ARESETn,

    // Write Address Channel (AW)
    input  wire [AXI_ID_WIDTH-1:0]        AWID,
    input  wire [AXI_ADDR_WIDTH-1:0]      AWADDR,
    input  wire [AXI_LEN_WIDTH-1:0]       AWLEN,
    input  wire [AXI_SIZE_WIDTH-1:0]      AWSIZE,
    input  wire [1:0]                     AWBURST,
    input  wire [1:0]                     AWLOCK,
    input  wire [3:0]                     AWCACHE,
    input  wire [2:0]                     AWPROT,
    input  wire                           AWVALID,
    output wire                           AWREADY,

    // Write Data Channel (W)
    input  wire [AXI_ID_WIDTH-1:0]        WID,
    input  wire [AXI_DATA_WIDTH-1:0]      WDATA,
    input  wire [(AXI_DATA_WIDTH/8)-1:0]  WSTRB,
    input  wire                           WLAST,
    input  wire                           WVALID,
    output wire                           WREADY,

    // Write Response Channel (B)
    output reg  [AXI_ID_WIDTH-1:0]        BID,
    output reg  [1:0]                     BRESP,
    output reg                            BVALID,
    input  wire                           BREADY,

    // Read Address Channel (AR)
    input  wire [AXI_ID_WIDTH-1:0]        ARID,
    input  wire [AXI_ADDR_WIDTH-1:0]      ARADDR,
    input  wire [AXI_LEN_WIDTH-1:0]       ARLEN,
    input  wire [AXI_SIZE_WIDTH-1:0]      ARSIZE,
    input  wire [1:0]                     ARBURST,
    input  wire [1:0]                     ARLOCK,
    input  wire [3:0]                     ARCACHE,
    input  wire [2:0]                     ARPROT,
    input  wire                           ARVALID,
    output wire                           ARREADY,

    // Read Data Channel (R)
    output reg  [AXI_ID_WIDTH-1:0]        RID,
    output reg  [AXI_DATA_WIDTH-1:0]      RDATA,
    output reg  [1:0]                     RRESP,
    output reg                            RLAST,
    output reg                            RVALID,
    input  wire                           RREADY
);

    // -------------------------------------------------------------------------
    // Constant Calculation Functions
    // -------------------------------------------------------------------------
    function integer clog2;
        input integer val;
        integer result;
        begin
            result = 0;
            for (val = val - 1; val > 0; val = val >> 1)
                result = result + 1;
            clog2 = (result == 0) ? 1 : result;
        end
    endfunction

    localparam STRB_WIDTH    = AXI_DATA_WIDTH / 8;
    localparam BYTE_OFFSET   = clog2(STRB_WIDTH);
    
    // Valid Address Space: 0x0000 to 0x7FFF (32 KB mapped RAM)
    // Any address >= 0x8000 generates DECERR
    localparam VALID_ADDR_LIMIT = 16'h7FFF;
    localparam SECURE_BASE_ADDR = 16'h4000;
    localparam RAM_DEPTH        = (1 << (AXI_ADDR_WIDTH - 1 - BYTE_OFFSET)); // 8192 words (32KB)
    localparam RAM_ADDR_W       = AXI_ADDR_WIDTH - 1 - BYTE_OFFSET;
    localparam SLOT_PTR_W       = clog2(NUM_SLOTS);
    localparam [SLOT_PTR_W-1:0] SLOT_MASK = NUM_SLOTS - 1;

    localparam RESP_OKAY   = 2'b00;
    localparam RESP_EXOKAY = 2'b01;
    localparam RESP_SLVERR = 2'b10;
    localparam RESP_DECERR = 2'b11;

    localparam BURST_FIXED    = 2'b00;
    localparam BURST_INCR     = 2'b01;
    localparam BURST_WRAP     = 2'b10;
    localparam BURST_RESERVED = 2'b11;

    localparam NUM_IDS = (1 << AXI_ID_WIDTH);

    // -------------------------------------------------------------------------
    // Dual-Port RAM with Byte-Write Enable (32KB)
    // -------------------------------------------------------------------------
    reg [AXI_DATA_WIDTH-1:0] ram [0:RAM_DEPTH-1];

    // -------------------------------------------------------------------------
    // Exclusive Monitor & Hardware Lock Registers
    // -------------------------------------------------------------------------
    reg                      ex_mon_valid [0:NUM_IDS-1];
    reg [AXI_ADDR_WIDTH-1:0] ex_mon_addr  [0:NUM_IDS-1];
    reg [AXI_LEN_WIDTH-1:0]  ex_mon_len   [0:NUM_IDS-1];
    reg [AXI_SIZE_WIDTH-1:0] ex_mon_size  [0:NUM_IDS-1];

    reg                      is_bus_locked;
    reg [AXI_ID_WIDTH-1:0]   lock_owner_id;

    function [AXI_ADDR_WIDTH-1:0] get_num_bytes;
        input [AXI_SIZE_WIDTH-1:0] size;
        begin
            case (size)
                3'd0:    get_num_bytes = 16'd1;
                3'd1:    get_num_bytes = 16'd2;
                3'd2:    get_num_bytes = 16'd4;
                default: get_num_bytes = 16'd4;
            endcase
        end
    endfunction

    function [AXI_ADDR_WIDTH-1:0] get_wrap_mask;
        input [AXI_SIZE_WIDTH-1:0] size;
        input [AXI_LEN_WIDTH-1:0]  len;
        reg [AXI_ADDR_WIDTH-1:0] total_bytes;
        begin
            case ({size, len})
                {3'd0, 4'd1}:  get_wrap_mask = 16'h0001;
                {3'd0, 4'd3}:  get_wrap_mask = 16'h0003;
                {3'd0, 4'd7}:  get_wrap_mask = 16'h0007;
                {3'd0, 4'd15}: get_wrap_mask = 16'h000F;
                {3'd1, 4'd1}:  get_wrap_mask = 16'h0003;
                {3'd1, 4'd3}:  get_wrap_mask = 16'h0007;
                {3'd1, 4'd7}:  get_wrap_mask = 16'h000F;
                {3'd1, 4'd15}: get_wrap_mask = 16'h001F;
                {3'd2, 4'd1}:  get_wrap_mask = 16'h0007;
                {3'd2, 4'd3}:  get_wrap_mask = 16'h000F;
                {3'd2, 4'd7}:  get_wrap_mask = 16'h001F;
                {3'd2, 4'd15}: get_wrap_mask = 16'h003F;
                default: begin
                    total_bytes = get_num_bytes(size) * ({{(AXI_ADDR_WIDTH-AXI_LEN_WIDTH){1'b0}}, len} + 1'b1);
                    get_wrap_mask = total_bytes - 1'b1;
                end
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Protocol, Address Decode & Protection Checkers
    // -------------------------------------------------------------------------
    function check_decerr;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [AXI_LEN_WIDTH-1:0]  len;
        input [AXI_SIZE_WIDTH-1:0] size;
        reg [AXI_ADDR_WIDTH-1:0]   total_bytes;
        reg [AXI_ADDR_WIDTH-1:0]   end_addr;
        begin
            total_bytes  = ({{(AXI_ADDR_WIDTH-AXI_LEN_WIDTH){1'b0}}, len} + 1'b1) << size;
            end_addr     = addr + total_bytes - 1'b1;
            check_decerr = (addr > VALID_ADDR_LIMIT) || (end_addr > VALID_ADDR_LIMIT);
        end
    endfunction

    function check_prot_error;
        input [AXI_ADDR_WIDTH-1:0] addr;
        input [AXI_LEN_WIDTH-1:0]  len;
        input [AXI_SIZE_WIDTH-1:0] size;
        input [1:0]                burst;
        input [2:0]                prot;
        input [AXI_ID_WIDTH-1:0]   id;
        reg [AXI_ADDR_WIDTH-1:0]   size_mask;
        reg [AXI_ADDR_WIDTH-1:0]   total_bytes;
        reg [AXI_ADDR_WIDTH-1:0]   end_addr;
        reg                        err_wrap_len;
        reg                        err_wrap_align;
        reg                        err_4k;
        reg                        err_prot_sec;
        reg                        err_prot_instr;
        reg                        err_bus_locked;
        begin
            size_mask   = get_num_bytes(size) - 1'b1;
            total_bytes = ({{(AXI_ADDR_WIDTH-AXI_LEN_WIDTH){1'b0}}, len} + 1'b1) << size;
            end_addr    = addr + total_bytes - 1'b1;

            err_wrap_len   = (burst == BURST_WRAP) && (len != 4'd1 && len != 4'd3 && len != 4'd7 && len != 4'd15);
            err_wrap_align = (burst == BURST_WRAP) && (|(addr & size_mask));
            err_4k         = (burst == BURST_INCR) && (addr[AXI_ADDR_WIDTH-1:12] != end_addr[AXI_ADDR_WIDTH-1:12]);

            // AxPROT checks:
            // prot[2]: 1 = Instruction access (Illegal for data RAM)
            // prot[1]: 1 = Non-Secure (Illegal in secure region >= 0x4000)
            // prot[0]: 0 = User mode (Illegal in secure region >= 0x4000)
            err_prot_instr = prot[2];
            err_prot_sec   = (addr >= SECURE_BASE_ADDR) && (prot[1] || !prot[0]);

            // Locked Access violation: Locked by another master
            err_bus_locked = is_bus_locked && (lock_owner_id != id);

            check_prot_error = (burst == BURST_RESERVED) || err_wrap_len || err_wrap_align || 
                               err_4k || err_prot_sec || err_prot_instr || err_bus_locked;
        end
    endfunction

    // -------------------------------------------------------------------------
    // Address progression generator
    // -------------------------------------------------------------------------
    function [AXI_ADDR_WIDTH-1:0] calc_next_addr;
        input [AXI_ADDR_WIDTH-1:0] current_addr;
        input [AXI_SIZE_WIDTH-1:0] size;
        input [1:0]                burst;
        input [AXI_LEN_WIDTH-1:0]  len;
        reg   [AXI_ADDR_WIDTH-1:0] num_bytes;
        reg   [AXI_ADDR_WIDTH-1:0] aligned_addr;
        reg   [AXI_ADDR_WIDTH-1:0] wrap_mask;
        begin
            num_bytes    = get_num_bytes(size);
            aligned_addr = current_addr & ~(num_bytes - 1'b1);
            wrap_mask    = get_wrap_mask(size, len);

            case (burst)
                BURST_FIXED: calc_next_addr = current_addr;
                BURST_INCR:  calc_next_addr = aligned_addr + num_bytes;
                BURST_WRAP:  calc_next_addr = (aligned_addr & ~wrap_mask) | ((aligned_addr + num_bytes) & wrap_mask);
                default:     calc_next_addr = aligned_addr + num_bytes;
            endcase
        end
    endfunction

    // =========================================================================
    // WRITE PATH REGISTERS
    // =========================================================================
    reg [NUM_SLOTS-1:0]      w_slot_valid;
    reg [NUM_SLOTS-1:0]      w_slot_complete;
    reg [NUM_SLOTS-1:0]      w_slot_err;
    reg [NUM_SLOTS-1:0]      w_slot_decerr;
    reg [NUM_SLOTS-1:0]      w_slot_is_ex;     
    reg [NUM_SLOTS-1:0]      w_slot_ex_pass;   
    reg [AXI_ID_WIDTH-1:0]   w_slot_id        [0:NUM_SLOTS-1];
    reg [AXI_ADDR_WIDTH-1:0] w_slot_addr      [0:NUM_SLOTS-1];
    reg [AXI_LEN_WIDTH-1:0]  w_slot_len       [0:NUM_SLOTS-1];
    reg [AXI_SIZE_WIDTH-1:0] w_slot_size      [0:NUM_SLOTS-1];
    reg [1:0]                w_slot_burst     [0:NUM_SLOTS-1];
    reg [3:0]                w_slot_cache     [0:NUM_SLOTS-1];
    reg [AXI_LEN_WIDTH-1:0]  w_slot_beat_cnt  [0:NUM_SLOTS-1];
    reg [NUM_SLOTS-1:0]      w_dep_matrix     [0:NUM_SLOTS-1];

    reg free_w_slot_found;
    reg [SLOT_PTR_W-1:0] free_w_slot_idx;
    integer k_aw;
    always @(*) begin
        free_w_slot_found = 1'b0;
        free_w_slot_idx   = {SLOT_PTR_W{1'b0}};
        for (k_aw = 0; k_aw < NUM_SLOTS; k_aw = k_aw + 1) begin
            if (!w_slot_valid[k_aw] && !free_w_slot_found) begin
                free_w_slot_found = 1'b1;
                free_w_slot_idx   = k_aw[SLOT_PTR_W-1:0];
            end
        end
    end
    assign AWREADY = free_w_slot_found;

    reg wid_matched;
    reg [SLOT_PTR_W-1:0] matched_w_slot_idx;
    reg w_has_prior;
    integer k_w, k_w_sub;
    always @(*) begin
        wid_matched        = 1'b0;
        matched_w_slot_idx = {SLOT_PTR_W{1'b0}};
        for (k_w = 0; k_w < NUM_SLOTS; k_w = k_w + 1) begin
            if (w_slot_valid[k_w] && !w_slot_complete[k_w] && (w_slot_id[k_w] == WID)) begin
                w_has_prior = 1'b0;
                for (k_w_sub = 0; k_w_sub < NUM_SLOTS; k_w_sub = k_w_sub + 1) begin
                    if (w_dep_matrix[k_w][k_w_sub] && (w_slot_id[k_w_sub] == WID) && !w_slot_complete[k_w_sub]) begin
                        w_has_prior = 1'b1;
                    end
                end
                if (!w_has_prior && !wid_matched) begin
                    wid_matched        = 1'b1;
                    matched_w_slot_idx = k_w[SLOT_PTR_W-1:0];
                end
            end
        end
    end
    assign WREADY = wid_matched;

    reg b_arb_found;
    reg [SLOT_PTR_W-1:0] b_arb_slot;
    reg b_blocked;
    integer k_b, k_b_sub;
    always @(*) begin
        b_arb_found = 1'b0;
        b_arb_slot  = {SLOT_PTR_W{1'b0}};
        for (k_b = 0; k_b < NUM_SLOTS; k_b = k_b + 1) begin
            if (w_slot_valid[k_b] && w_slot_complete[k_b] && !b_arb_found) begin
                b_blocked = 1'b0;
                for (k_b_sub = 0; k_b_sub < NUM_SLOTS; k_b_sub = k_b_sub + 1) begin
                    if (w_dep_matrix[k_b][k_b_sub] && (w_slot_id[k_b_sub] == w_slot_id[k_b])) begin
                        b_blocked = 1'b1;
                    end
                end
                if (!b_blocked) begin
                    b_arb_found = 1'b1;
                    b_arb_slot  = k_b[SLOT_PTR_W-1:0];
                end
            end
        end
    end

    wire [RAM_ADDR_W-1:0] w_ram_addr = w_slot_addr[matched_w_slot_idx][RAM_ADDR_W+BYTE_OFFSET-1:BYTE_OFFSET];

    integer rst_i;
    integer clr_dep_i;
    integer strb_i;
    integer inv_i;
    reg [SLOT_PTR_W-1:0] b_active_slot;

    wire is_aw_ex_candidate = (AWLOCK == 2'b01);
    wire aw_ex_matches      = ex_mon_valid[AWID] && (ex_mon_addr[AWID] == AWADDR);

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            BVALID          <= 1'b0;
            BID             <= {AXI_ID_WIDTH{1'b0}};
            BRESP           <= RESP_OKAY;
            b_active_slot   <= {SLOT_PTR_W{1'b0}};
            w_slot_valid    <= {NUM_SLOTS{1'b0}};
            w_slot_complete <= {NUM_SLOTS{1'b0}};
            w_slot_err      <= {NUM_SLOTS{1'b0}};
            w_slot_decerr   <= {NUM_SLOTS{1'b0}};
            w_slot_is_ex    <= {NUM_SLOTS{1'b0}};
            w_slot_ex_pass  <= {NUM_SLOTS{1'b0}};
            is_bus_locked   <= 1'b0;
            lock_owner_id   <= {AXI_ID_WIDTH{1'b0}};
            for (rst_i = 0; rst_i < NUM_SLOTS; rst_i = rst_i + 1) begin
                w_dep_matrix[rst_i] <= {NUM_SLOTS{1'b0}};
            end
            for (rst_i = 0; rst_i < NUM_IDS; rst_i = rst_i + 1) begin
                ex_mon_valid[rst_i] <= 1'b0;
                ex_mon_addr[rst_i]  <= {AXI_ADDR_WIDTH{1'b0}};
                ex_mon_len[rst_i]   <= {AXI_LEN_WIDTH{1'b0}};
                ex_mon_size[rst_i]  <= {AXI_SIZE_WIDTH{1'b0}};
            end
        end else begin
            // -----------------------------------------------------------------
            // 1. Bus Locking Arbitration (AWLOCK / ARLOCK == 2'b10)
            // -----------------------------------------------------------------
            if (AWVALID && AWREADY) begin
                if (AWLOCK == 2'b10) begin
                    is_bus_locked <= 1'b1;
                    lock_owner_id <= AWID;
                end else if (is_bus_locked && (lock_owner_id == AWID) && (AWLOCK == 2'b00)) begin
                    is_bus_locked <= 1'b0;
                end
            end else if (ARVALID && ARREADY) begin
                if (ARLOCK == 2'b10) begin
                    is_bus_locked <= 1'b1;
                    lock_owner_id <= ARID;
                end else if (is_bus_locked && (lock_owner_id == ARID) && (ARLOCK == 2'b00)) begin
                    is_bus_locked <= 1'b0;
                end
            end

            // -----------------------------------------------------------------
            // 2. Exclusive Monitor Update by AR Channel
            // -----------------------------------------------------------------
            if (ARVALID && ARREADY && (ARLOCK == 2'b01)) begin
                ex_mon_valid[ARID] <= 1'b1;
                ex_mon_addr[ARID]  <= ARADDR;
                ex_mon_len[ARID]   <= ARLEN;
                ex_mon_size[ARID]  <= ARSIZE;
            end

            // -----------------------------------------------------------------
            // 3. AW Channel Handshake
            // -----------------------------------------------------------------
            if (AWVALID && AWREADY) begin
                w_slot_valid[free_w_slot_idx]    <= 1'b1;
                w_slot_complete[free_w_slot_idx] <= 1'b0;
                w_slot_decerr[free_w_slot_idx]   <= check_decerr(AWADDR, AWLEN, AWSIZE);
                w_slot_err[free_w_slot_idx]      <= check_prot_error(AWADDR, AWLEN, AWSIZE, AWBURST, AWPROT, AWID);
                w_slot_id[free_w_slot_idx]       <= AWID;
                w_slot_addr[free_w_slot_idx]     <= AWADDR;
                w_slot_len[free_w_slot_idx]      <= AWLEN;
                w_slot_size[free_w_slot_idx]     <= AWSIZE;
                w_slot_burst[free_w_slot_idx]    <= AWBURST;
                w_slot_cache[free_w_slot_idx]    <= AWCACHE;
                w_slot_beat_cnt[free_w_slot_idx] <= {AXI_LEN_WIDTH{1'b0}};
                w_dep_matrix[free_w_slot_idx]    <= w_slot_valid;
                w_slot_is_ex[free_w_slot_idx]    <= is_aw_ex_candidate;
                w_slot_ex_pass[free_w_slot_idx]  <= is_aw_ex_candidate && aw_ex_matches;

                if (is_aw_ex_candidate && aw_ex_matches) begin
                    ex_mon_valid[AWID] <= 1'b0;
                end else if (!is_aw_ex_candidate) begin
                    for (inv_i = 0; inv_i < NUM_IDS; inv_i = inv_i + 1) begin
                        if (ex_mon_valid[inv_i] && (ex_mon_addr[inv_i] == AWADDR)) begin
                            ex_mon_valid[inv_i] <= 1'b0;
                        end
                    end
                end
            end

            // -----------------------------------------------------------------
            // 4. W Channel Execution
            // -----------------------------------------------------------------
            if (WVALID && WREADY) begin
                // Only commit to RAM if neither DECERR nor SLVERR occurred, and Exclusive matches
                if (!w_slot_err[matched_w_slot_idx] && !w_slot_decerr[matched_w_slot_idx] &&
                    (!w_slot_is_ex[matched_w_slot_idx] || w_slot_ex_pass[matched_w_slot_idx])) begin
                    for (strb_i = 0; strb_i < STRB_WIDTH; strb_i = strb_i + 1) begin
                        if (WSTRB[strb_i]) begin
                            ram[w_ram_addr][(strb_i*8) +: 8] <= WDATA[(strb_i*8) +: 8];
                        end
                    end
                end

                if (WLAST != (w_slot_beat_cnt[matched_w_slot_idx] == w_slot_len[matched_w_slot_idx])) begin
                    w_slot_err[matched_w_slot_idx] <= 1'b1;
                end

                if ((w_slot_beat_cnt[matched_w_slot_idx] == w_slot_len[matched_w_slot_idx]) || WLAST) begin
                    w_slot_complete[matched_w_slot_idx] <= 1'b1;
                end else begin
                    w_slot_beat_cnt[matched_w_slot_idx] <= w_slot_beat_cnt[matched_w_slot_idx] + 1'b1;
                    w_slot_addr[matched_w_slot_idx]     <= calc_next_addr(
                        w_slot_addr[matched_w_slot_idx],
                        w_slot_size[matched_w_slot_idx],
                        w_slot_burst[matched_w_slot_idx],
                        w_slot_len[matched_w_slot_idx]
                    );
                end
            end

            // -----------------------------------------------------------------
            // 5. B Channel Execution & Response Evaluation
            // -----------------------------------------------------------------
            if (BVALID && BREADY) begin
                BVALID                         <= 1'b0;
                w_slot_valid[b_active_slot]    <= 1'b0;
                w_slot_complete[b_active_slot] <= 1'b0;
                for (clr_dep_i = 0; clr_dep_i < NUM_SLOTS; clr_dep_i = clr_dep_i + 1) begin
                    w_dep_matrix[clr_dep_i][b_active_slot] <= 1'b0;
                end
            end else if (!BVALID && b_arb_found) begin
                BVALID        <= 1'b1;
                b_active_slot <= b_arb_slot;
                BID           <= w_slot_id[b_arb_slot];

                // Determine BRESP Priority: DECERR > SLVERR > EXOKAY > OKAY
                if (w_slot_decerr[b_arb_slot]) begin
                    BRESP <= RESP_DECERR;
                end else if (w_slot_err[b_arb_slot]) begin
                    BRESP <= RESP_SLVERR;
                end else if (w_slot_is_ex[b_arb_slot] && w_slot_ex_pass[b_arb_slot]) begin
                    BRESP <= RESP_EXOKAY;
                end else begin
                    BRESP <= RESP_OKAY;
                end
            end
        end
    end

    // =========================================================================
    // READ PATH REGISTERS & LOGIC
    // =========================================================================
    localparam R_IDLE  = 1'b0;
    localparam R_BURST = 1'b1;

    reg                      r_state;
    reg [NUM_SLOTS-1:0]      r_slot_valid;
    reg [NUM_SLOTS-1:0]      r_slot_err;
    reg [NUM_SLOTS-1:0]      r_slot_decerr;
    reg [NUM_SLOTS-1:0]      r_slot_is_ex;     
    reg [AXI_ID_WIDTH-1:0]   r_slot_id        [0:NUM_SLOTS-1];
    reg [AXI_ADDR_WIDTH-1:0] r_slot_addr      [0:NUM_SLOTS-1];
    reg [AXI_LEN_WIDTH-1:0]  r_slot_len       [0:NUM_SLOTS-1];
    reg [AXI_SIZE_WIDTH-1:0] r_slot_size      [0:NUM_SLOTS-1];
    reg [1:0]                r_slot_burst     [0:NUM_SLOTS-1];
    reg [3:0]                r_slot_cache     [0:NUM_SLOTS-1];
    reg [AXI_LEN_WIDTH-1:0]  r_slot_beat_cnt  [0:NUM_SLOTS-1];
    reg [NUM_SLOTS-1:0]      r_dep_matrix     [0:NUM_SLOTS-1];
    reg [SLOT_PTR_W-1:0]     r_rr_ptr;
    reg [SLOT_PTR_W-1:0]     r_active_slot;

    reg free_r_slot_found;
    reg [SLOT_PTR_W-1:0] free_r_slot_idx;
    integer k_ar;
    always @(*) begin
        free_r_slot_found = 1'b0;
        free_r_slot_idx   = {SLOT_PTR_W{1'b0}};
        for (k_ar = 0; k_ar < NUM_SLOTS; k_ar = k_ar + 1) begin
            if (!r_slot_valid[k_ar] && !free_r_slot_found) begin
                free_r_slot_found = 1'b1;
                free_r_slot_idx   = k_ar[SLOT_PTR_W-1:0];
            end
        end
    end
    assign ARREADY = free_r_slot_found;

    reg sched_found;
    reg [SLOT_PTR_W-1:0] sched_r_slot;
    reg [SLOT_PTR_W-1:0] r_candidate;
    reg r_blocked;
    integer k_rr, k_rr_dep;
    always @(*) begin
        sched_found  = 1'b0;
        sched_r_slot = {SLOT_PTR_W{1'b0}};
        for (k_rr = 0; k_rr < NUM_SLOTS; k_rr = k_rr + 1) begin
            r_candidate = (r_rr_ptr + k_rr[SLOT_PTR_W-1:0]) & SLOT_MASK;
            if (r_slot_valid[r_candidate] && !sched_found) begin
                r_blocked = 1'b0;
                for (k_rr_dep = 0; k_rr_dep < NUM_SLOTS; k_rr_dep = k_rr_dep + 1) begin
                    if (r_dep_matrix[r_candidate][k_rr_dep] && 
                        (r_slot_id[k_rr_dep] == r_slot_id[r_candidate]) &&
                        r_slot_valid[k_rr_dep]) begin
                        r_blocked = 1'b1;
                    end
                end
                if (!r_blocked) begin
                    sched_found  = 1'b1;
                    sched_r_slot = r_candidate;
                end
            end
        end
    end

    wire [AXI_ADDR_WIDTH-1:0] next_r_addr = calc_next_addr(
        r_slot_addr[r_active_slot],
        r_slot_size[r_active_slot],
        r_slot_burst[r_active_slot],
        r_slot_len[r_active_slot]
    );

    wire [RAM_ADDR_W-1:0] cur_r_ram_addr  = r_slot_addr[sched_r_slot][RAM_ADDR_W+BYTE_OFFSET-1:BYTE_OFFSET];
    wire [RAM_ADDR_W-1:0] next_r_ram_addr = next_r_addr[RAM_ADDR_W+BYTE_OFFSET-1:BYTE_OFFSET];

    integer rst_r_i;
    integer clr_rdep_i;

    always @(posedge ACLK or negedge ARESETn) begin
        if (!ARESETn) begin
            RVALID        <= 1'b0;
            RLAST         <= 1'b0;
            RID           <= {AXI_ID_WIDTH{1'b0}};
            RDATA         <= {AXI_DATA_WIDTH{1'b0}};
            RRESP         <= RESP_OKAY;
            r_state       <= R_IDLE;
            r_rr_ptr      <= {SLOT_PTR_W{1'b0}};
            r_active_slot <= {SLOT_PTR_W{1'b0}};
            r_slot_valid  <= {NUM_SLOTS{1'b0}};
            r_slot_err    <= {NUM_SLOTS{1'b0}};
            r_slot_decerr <= {NUM_SLOTS{1'b0}};
            r_slot_is_ex  <= {NUM_SLOTS{1'b0}};
            for (rst_r_i = 0; rst_r_i < NUM_SLOTS; rst_r_i = rst_r_i + 1) begin
                r_dep_matrix[rst_r_i] <= {NUM_SLOTS{1'b0}};
            end
        end else begin
            // -----------------------------------------------------------------
            // 1. AR Channel Handshake
            // -----------------------------------------------------------------
            if (ARVALID && ARREADY) begin
                r_slot_valid[free_r_slot_idx]    <= 1'b1;
                r_slot_decerr[free_r_slot_idx]   <= check_decerr(ARADDR, ARLEN, ARSIZE);
                r_slot_err[free_r_slot_idx]      <= check_prot_error(ARADDR, ARLEN, ARSIZE, ARBURST, ARPROT, ARID);
                r_slot_id[free_r_slot_idx]       <= ARID;
                r_slot_addr[free_r_slot_idx]     <= ARADDR;
                r_slot_len[free_r_slot_idx]      <= ARLEN;
                r_slot_size[free_r_slot_idx]     <= ARSIZE;
                r_slot_burst[free_r_slot_idx]    <= ARBURST;
                r_slot_cache[free_r_slot_idx]    <= ARCACHE;
                r_slot_is_ex[free_r_slot_idx]    <= (ARLOCK == 2'b01);
                r_slot_beat_cnt[free_r_slot_idx] <= {AXI_LEN_WIDTH{1'b0}};
                r_dep_matrix[free_r_slot_idx]    <= r_slot_valid;
            end

            // -----------------------------------------------------------------
            // 2. Read Channel FSM
            // -----------------------------------------------------------------
            case (r_state)
                R_IDLE: begin
                    if (sched_found) begin
                        r_state       <= R_BURST;
                        r_active_slot <= sched_r_slot;

                        // Drive beat 0
                        RVALID <= 1'b1;
                        RID    <= r_slot_id[sched_r_slot];
                        
                        if (r_slot_decerr[sched_r_slot]) begin
                            RRESP <= RESP_DECERR;
                            RDATA <= {AXI_DATA_WIDTH{1'b0}};
                        end else if (r_slot_err[sched_r_slot]) begin
                            RRESP <= RESP_SLVERR;
                            RDATA <= {AXI_DATA_WIDTH{1'b0}};
                        end else if (r_slot_is_ex[sched_r_slot]) begin
                            RRESP <= RESP_EXOKAY;
                            RDATA <= ram[cur_r_ram_addr];
                        end else begin
                            RRESP <= RESP_OKAY;
                            RDATA <= ram[cur_r_ram_addr];
                        end

                        RLAST  <= (r_slot_beat_cnt[sched_r_slot] == r_slot_len[sched_r_slot]);
                    end else begin
                        RVALID <= 1'b0;
                        RLAST  <= 1'b0;
                    end
                end

                R_BURST: begin
                    if (RVALID && RREADY) begin
                        if (RLAST) begin
                            RVALID                      <= 1'b0;
                            RLAST                       <= 1'b0;
                            r_state                     <= R_IDLE;
                            r_slot_valid[r_active_slot] <= 1'b0;

                            for (clr_rdep_i = 0; clr_rdep_i < NUM_SLOTS; clr_rdep_i = clr_rdep_i + 1) begin
                                r_dep_matrix[clr_rdep_i][r_active_slot] <= 1'b0;
                            end

                            r_rr_ptr <= (r_active_slot + 1'b1) & SLOT_MASK;
                        end else begin
                            r_slot_beat_cnt[r_active_slot] <= r_slot_beat_cnt[r_active_slot] + 1'b1;
                            r_slot_addr[r_active_slot]     <= next_r_addr;

                            RVALID <= 1'b1;
                            RID    <= r_slot_id[r_active_slot];
                            
                            if (r_slot_decerr[r_active_slot]) begin
                                RRESP <= RESP_DECERR;
                                RDATA <= {AXI_DATA_WIDTH{1'b0}};
                            end else if (r_slot_err[r_active_slot]) begin
                                RRESP <= RESP_SLVERR;
                                RDATA <= {AXI_DATA_WIDTH{1'b0}};
                            end else if (r_slot_is_ex[r_active_slot]) begin
                                RRESP <= RESP_EXOKAY;
                                RDATA <= ram[next_r_ram_addr];
                            end else begin
                                RRESP <= RESP_OKAY;
                                RDATA <= ram[next_r_ram_addr];
                            end

                            RLAST  <= (r_slot_beat_cnt[r_active_slot] + 1'b1 == r_slot_len[r_active_slot]);
                        end
                    end
                end
            endcase
        end
    end

endmodule