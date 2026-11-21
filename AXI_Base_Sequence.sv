// =============================================================================
// Class:    axi_base_seq
// Base:     uvm_sequence #(axi_seq_item)
// Purpose: Base sequence providing unified burst execution, atomic channel driving,
//          protocol boundary alignment, shared beat addressing, and WSTRB calculation.
// =============================================================================
virtual class axi_base_seq extends uvm_sequence #(axi_seq_item);

  `uvm_object_utils(axi_base_seq)

  // ---------------------------------------------------------------------------
  // Concurrency & Operational Knobs (Directly populated/overridden by tests)
  // ---------------------------------------------------------------------------
  bit                  enable_overlap    = 1'b0;
  bit                  enable_interleave = 1'b0;
  int                  num_streams       = 4;

  // Default burst attributes
  bit [SIZE_WIDTH-1:0] default_size      = $clog2(STRB_WIDTH);
  bit [1:0]            default_lock      = 2'b00;
  bit [3:0]            default_cache     = 4'b0000;
  bit [2:0]            default_prot      = 3'b000;

  function new(string name = "axi_base_seq");
    super.new(name);
  endfunction

  // ---------------------------------------------------------------------------
  // 1. Primitive Single Burst Driving Tasks (Original)
  // ---------------------------------------------------------------------------
  virtual task write_burst(
    input bit [ID_WIDTH-1:0]      id,
    input bit [ADDR_WIDTH-1:0]    addr,
    input bit [LEN_WIDTH-1:0]     len,
    input bit [SIZE_WIDTH-1:0]    size,
    input axi_burst_e             burst,
    input bit [DATA_WIDTH-1:0]    base_data,
    input bit [STRB_WIDTH-1:0]    strb_val = {STRB_WIDTH{1'b1}}
  );
    axi_seq_item wr_item;
    `uvm_create(wr_item)
    start_item(wr_item);

    wr_item.trans_type = AXI_WRITE;
    wr_item.id         = id;
    wr_item.addr       = addr;
    wr_item.len        = len;
    wr_item.size       = size;
    wr_item.burst      = burst;
    wr_item.lock       = default_lock;
    wr_item.cache      = default_cache;
    wr_item.prot       = default_prot;

    wr_item.wdata      = new[len + 1];
    wr_item.wstrb      = new[len + 1];

    foreach (wr_item.wdata[i]) begin
      wr_item.wdata[i] = base_data | i;
      wr_item.wstrb[i] = strb_val;
    end

    finish_item(wr_item);

    if (!wr_item.is_completed) begin
      @wr_item.done_event;
    end
  endtask : write_burst

  virtual task read_burst(
    input bit [ID_WIDTH-1:0]      id,
    input bit [ADDR_WIDTH-1:0]    addr,
    input bit [LEN_WIDTH-1:0]     len,
    input bit [SIZE_WIDTH-1:0]    size,
    input axi_burst_e             burst
  );
    axi_seq_item rd_item;
    `uvm_create(rd_item)
    start_item(rd_item);

    rd_item.trans_type = AXI_READ;
    rd_item.id         = id;
    rd_item.addr       = addr;
    rd_item.len        = len;
    rd_item.size       = size;
    rd_item.burst      = burst;
    rd_item.lock       = default_lock;
    rd_item.cache      = default_cache;
    rd_item.prot       = default_prot;

    finish_item(rd_item);

    if (!rd_item.is_completed) begin
      @rd_item.done_event;
    end
  endtask : read_burst

  virtual task write_read_ping_pong(
    input bit [ID_WIDTH-1:0]      wr_id,
    input bit [ID_WIDTH-1:0]      rd_id,
    input bit [ADDR_WIDTH-1:0]    addr,
    input bit [LEN_WIDTH-1:0]     len,
    input bit [SIZE_WIDTH-1:0]    size,
    input axi_burst_e             burst,
    input bit [DATA_WIDTH-1:0]    base_data
  );
    write_burst(wr_id, addr, len, size, burst, base_data);
    read_burst(rd_id, addr, len, size, burst);
  endtask : write_read_ping_pong

  // ---------------------------------------------------------------------------
  // 2. Extended Primitive Burst Driving Tasks (New for Atomic/Exclusive/Checks)
  // ---------------------------------------------------------------------------
  virtual task write_burst_ext(
    input  bit [ID_WIDTH-1:0]        id,
    input  bit [ADDR_WIDTH-1:0]      addr,
    input  bit [LEN_WIDTH-1:0]       len,
    input  bit [SIZE_WIDTH-1:0]      size,
    input  axi_burst_e               burst,
    input  bit [1:0]                 lock,
    input  bit [DATA_WIDTH-1:0]      base_data,
    input  bit [STRB_WIDTH-1:0]      strb_val = {STRB_WIDTH{1'b1}},
    output axi_resp_e                bresp_out,
    output bit [DATA_WIDTH-1:0]      wdata_out[]
  );
    axi_seq_item wr_item;
    `uvm_create(wr_item)
    start_item(wr_item);

    wr_item.trans_type = AXI_WRITE;
    wr_item.id         = id;
    wr_item.addr       = addr;
    wr_item.len        = len;
    wr_item.size       = size;
    wr_item.burst      = burst;
    wr_item.lock       = lock;
    wr_item.cache      = default_cache;
    wr_item.prot       = default_prot;

    wr_item.wdata      = new[len + 1];
    wr_item.wstrb      = new[len + 1];

    foreach (wr_item.wdata[i]) begin
      wr_item.wdata[i] = base_data ^ (i << 8);
      wr_item.wstrb[i] = strb_val;
    end

    // Return written data beats for scoreboard / readback comparison
    wdata_out = new[wr_item.wdata.size()](wr_item.wdata);

    finish_item(wr_item);

    if (!wr_item.is_completed) begin
      @wr_item.done_event;
    end

    bresp_out = wr_item.bresp;
  endtask : write_burst_ext

  virtual task read_burst_ext(
    input  bit [ID_WIDTH-1:0]        id,
    input  bit [ADDR_WIDTH-1:0]      addr,
    input  bit [LEN_WIDTH-1:0]       len,
    input  bit [SIZE_WIDTH-1:0]      size,
    input  axi_burst_e               burst,
    input  bit [1:0]                 lock,
    output axi_resp_e                rresp_out[],
    output bit [DATA_WIDTH-1:0]      rdata_out[]
  );
    axi_seq_item rd_item;
    `uvm_create(rd_item)
    start_item(rd_item);

    rd_item.trans_type = AXI_READ;
    rd_item.id         = id;
    rd_item.addr       = addr;
    rd_item.len        = len;
    rd_item.size       = size;
    rd_item.burst      = burst;
    rd_item.lock       = lock;
    rd_item.cache      = default_cache;
    rd_item.prot       = default_prot;

    finish_item(rd_item);

    if (!rd_item.is_completed) begin
      @rd_item.done_event;
    end

    // Return received beat responses and data
    rresp_out = new[rd_item.rresp.size()](rd_item.rresp);
    rdata_out = new[rd_item.rdata.size()](rd_item.rdata);
  endtask : read_burst_ext

  // ---------------------------------------------------------------------------
  // 3. Unified Burst Engine (Original)
  // ---------------------------------------------------------------------------
  virtual task execute_burst_engine(
    input axi_burst_e                burst_type,
    input int                        count        = 10,
    input bit [ADDR_WIDTH-1:0]       start_addr   = 'h1000,
    input bit [LEN_WIDTH-1:0]        manual_len   = 4'd3,
    input bit [DATA_WIDTH-1:0]       init_data    = 32'hDEAD_0000,
    input bit                        randomize_id = 1'b1
  );
    `uvm_info("BASE_SEQ", $sformatf("Unified Burst Engine: Burst=%0s, Count=%0d, Addr=0x%0h (Overlap=%0b, Interleave=%0b, Streams=%0d)",
              burst_type.name(), count, start_addr, enable_overlap, enable_interleave, num_streams), UVM_LOW)

    // =========================================================================
    // Mode A: Concurrent Mode (Overlap or Interleave active)
    // =========================================================================
    if (enable_overlap || enable_interleave) begin
      // Track lengths and addresses so read back matches exact written parameters
      bit [LEN_WIDTH-1:0]  batch_lens[16];
      bit [ADDR_WIDTH-1:0] batch_addrs[16];

      repeat (count) begin
        // Parallel Writes across streams with unique IDs
        for (int s = 0; s < num_streams; s++) begin
          automatic int stream_idx = s;
          fork
            begin
              bit [LEN_WIDTH-1:0]  stream_len;
              bit [ADDR_WIDTH-1:0] stream_addr;
              int                  total_bytes;

              calc_burst_parameters(burst_type, manual_len, start_addr, stream_idx, 'h200, stream_len, stream_addr, total_bytes);

              batch_lens[stream_idx]  = stream_len;
              batch_addrs[stream_idx] = stream_addr;

              write_burst(
                .id(stream_idx + 1),
                .addr(stream_addr),
                .len(stream_len),
                .size(default_size),
                .burst(burst_type),
                .base_data(init_data | (stream_idx << 8))
              );
            end
          join_none
        end
        wait fork;

        // Parallel Reads using the exact matched lengths and addresses
        for (int s = 0; s < num_streams; s++) begin
          automatic int stream_idx = s;
          fork
            begin
              read_burst(
                .id(stream_idx + 10),
                .addr(batch_addrs[stream_idx]),
                .len(batch_lens[stream_idx]),
                .size(default_size),
                .burst(burst_type)
              );
            end
          join_none
        end
        wait fork;
      end
    end

    // =========================================================================
    // Mode B: Normal Sequential Ping-Pong Mode
    // =========================================================================
    else begin
      bit [ADDR_WIDTH-1:0] cur_addr = start_addr;
      bit [DATA_WIDTH-1:0] cur_data = init_data;
      bit [ID_WIDTH-1:0]   id       = 'h1;
      bit [LEN_WIDTH-1:0]  cur_len;
      int                  total_bytes;

      repeat (count) begin
        case (burst_type)
          // 1. FIXED: Static target address
          BURST_FIXED: begin
            cur_len     = manual_len;
            total_bytes = (cur_len + 1) * (1 << default_size);
          end

          // 2. INCR: Dynamic length, address increment, 4KB protection
          BURST_INCR: begin
            cur_len     = (manual_len == 4'd0) ? $urandom_range(15) : manual_len;
            total_bytes = (cur_len + 1) * (1 << default_size);

            if (((cur_addr & 12'hFFF) + total_bytes) > 4096 || (cur_addr + total_bytes) > 'h1FF0) begin
              cur_addr = start_addr;
            end
          end

          // 3. WRAP: Power-of-2 length, aligned to total burst size
          BURST_WRAP: begin
            cur_len     = (manual_len == 4'd0) ? ((1 << $urandom_range(4, 1)) - 1) : manual_len; // 1, 3, 7, 15
            total_bytes = (cur_len + 1) * (1 << default_size);

            cur_addr = (cur_addr / total_bytes) * total_bytes;
            if ((cur_addr + total_bytes) > 'h1FF0) begin
              cur_addr = start_addr;
            end
          end

          default: begin
            cur_len     = manual_len;
            total_bytes = (cur_len + 1) * (1 << default_size);
          end
        endcase

        write_read_ping_pong(
          .wr_id(id),
          .rd_id(id + 5),
          .addr(cur_addr),
          .len(cur_len),
          .size(default_size),
          .burst(burst_type),
          .base_data(cur_data)
        );

        // Next iteration update
        case (burst_type)
          BURST_FIXED: cur_data += 'hF0;
          BURST_INCR:  begin cur_data += cur_len; cur_addr += total_bytes; end
          BURST_WRAP:  begin cur_data += (cur_len + 1); cur_addr += total_bytes; end
          default:     cur_addr += total_bytes;
        endcase

        id = randomize_id ? $random : (id + 1);
      end
    end
  endtask : execute_burst_engine

  // ---------------------------------------------------------------------------
  // Helper: Address & Length Resolver for Parallel Streams (Original)
  // ---------------------------------------------------------------------------
  virtual function void calc_burst_parameters(
    input  axi_burst_e          b_type,
    input  bit [LEN_WIDTH-1:0]  m_len,
    input  bit [ADDR_WIDTH-1:0] base_addr,
    input  int                  stream_idx,
    input  bit [ADDR_WIDTH-1:0] stride,
    output bit [LEN_WIDTH-1:0]  out_len,
    output bit [ADDR_WIDTH-1:0] out_addr,
    output int                  out_bytes
  );
    case (b_type)
      BURST_FIXED: begin
        out_len   = m_len;
        out_bytes = (out_len + 1) * (1 << default_size);
        out_addr  = base_addr + (stream_idx * stride);
      end

      BURST_INCR: begin
        // If manual_len is 0, randomize length across legal AXI3 beats (0..15 -> 1..16 beats)
        out_len   = (m_len == 4'd0) ? $urandom_range(15, 0) : m_len;
        out_bytes = (out_len + 1) * (1 << default_size);
        out_addr  = base_addr + (stream_idx * stride);

        // Ensure stream does not cross a 4KB boundary
        if (((out_addr & 12'hFFF) + out_bytes) > 4096) begin
          out_addr = (out_addr & ~12'hFFF); // Snap to base of current 4KB page
        end
      end

      BURST_WRAP: begin
        out_len   = (m_len == 4'd0) ? ((1 << $urandom_range(4, 1)) - 1) : m_len; // 2, 4, 8, 16 beats
        out_bytes = (out_len + 1) * (1 << default_size);
        out_addr  = base_addr + (stream_idx * stride);
        out_addr  = (out_addr / out_bytes) * out_bytes; // Aligned to total wrap size
      end

      default: begin
        out_len   = m_len;
        out_bytes = (out_len + 1) * (1 << default_size);
        out_addr  = base_addr;
      end
    endcase
  endfunction : calc_burst_parameters

  // ---------------------------------------------------------------------------
  // 4. Shared Protocol Helpers: Addressing & Strobe Generation (Section A3.4)
  // ---------------------------------------------------------------------------

  // Calculates exact beat address for FIXED, INCR, and WRAP bursts (Section A3.4.1)
  virtual function bit [ADDR_WIDTH-1:0] calc_axi_beat_addr(
    input bit [ADDR_WIDTH-1:0] base_addr,
    input axi_burst_e          burst_type,
    input bit [LEN_WIDTH-1:0]  len,
    input bit [SIZE_WIDTH-1:0] size,
    input int                  beat_idx
  );
    int num_bytes;
    int total_bytes;
    bit [ADDR_WIDTH-1:0] aligned_addr;
    bit [ADDR_WIDTH-1:0] wrap_boundary;
    bit [ADDR_WIDTH-1:0] cur_addr;

    num_bytes    = 1 << size;
    total_bytes  = (len + 1) * num_bytes;
    aligned_addr = (base_addr / num_bytes) * num_bytes;

    case (burst_type)
      BURST_FIXED: begin
        return base_addr;
      end

      BURST_INCR: begin
        if (beat_idx == 0) begin
          return base_addr;
        end else begin
          return aligned_addr + (beat_idx * num_bytes);
        end
      end

      BURST_WRAP: begin
        wrap_boundary = (aligned_addr / total_bytes) * total_bytes;
        cur_addr      = aligned_addr + (beat_idx * num_bytes);
        if (cur_addr >= (wrap_boundary + total_bytes)) begin
          cur_addr = cur_addr - total_bytes;
        end
        return cur_addr;
      end

      default: return base_addr + (beat_idx * num_bytes);
    endcase
  endfunction : calc_axi_beat_addr

  // Calculates active write strobes per AXI3 Spec Section A3.4.4
  // Supports aligned, unaligned, and narrow transfers (active_bytes <= 2^size)
  virtual function bit [STRB_WIDTH-1:0] calc_axi_wstrb(
    input bit [ADDR_WIDTH-1:0] beat_addr,
    input bit [SIZE_WIDTH-1:0] size_val,
    input int                  active_bytes,
    input int                  beat_idx
  );
    int num_bytes;
    bit [ADDR_WIDTH-1:0] aligned_addr;
    int lower_byte_lane;
    int upper_byte_lane;
    bit [STRB_WIDTH-1:0] strb;

    num_bytes    = 1 << size_val;
    aligned_addr = (beat_addr / num_bytes) * num_bytes;

    // First beat takes unaligned offset; subsequent beats take aligned lane offset
    if (beat_idx == 0) begin
      lower_byte_lane = beat_addr % STRB_WIDTH;
    end else begin
      lower_byte_lane = aligned_addr % STRB_WIDTH;
    end

    upper_byte_lane = (aligned_addr % STRB_WIDTH) + active_bytes - 1;
    strb            = '0;

    for (int lane = 0; lane < STRB_WIDTH; lane++) begin
      if (lane >= lower_byte_lane && lane <= upper_byte_lane) begin
        strb[lane] = 1'b1;
      end
    end
    return strb;
  endfunction : calc_axi_wstrb

endclass : axi_base_seq