//THIS WAS GIVEN, IT CAN BE MODIFIED AS NEEDED

/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  dcache.sv                                           //
//                                                                     //
//  Description :  The instruction cache module that reroutes memory   //
//                 accesses to decrease misses.                        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "verilog/sys_defs.svh"

/**
 * A quick overview of the cache and memory:
 *
 * We've increased the memory latency from 1 cycle to 100ns. which will be
 * multiple cycles for any reasonable processor. Thus, memory can have multiple
 * transactions pending and coordinates them via memory tags (different meaning
 * than cache tags) which represent a transaction it's working on. Memory tags
 * are 4 bits long since 15 mem accesses can be live at one time, and only one
 * access happens per cycle.
 *
 * On a request, memory responds with the tag it will use for that transaction.
 * Then, ceiling(100ns/clock period) cycles later, it will return the data with
 * the corresponding tag. The 0 tag is a sentinel value and unused. It would be
 * very difficult to push your clock period past 100ns/15=6.66ns, so 15 tags is
 * sufficient.
 *
 * This cache coordinates those memory tags to speed up fetching reused data.
 *
 * Note that this cache is blocking, and will wait on one memory request before
 * sending another (unless the input address changes, in which case it abandons
 * that request). Implementing a non-blocking cache can count towards simple
 * feature points, but will require careful management of memory tags.
 */

module dcache (
    input clock,
    input reset,
    input mispredict,

    // From memory
    input MEM_TAG   Dmem2proc_transaction_tag, // Should be zero unless there is a response
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,

    // To memory
    output MEM_COMMAND proc2Dmem_command, // this goes to the memory arbiter
    output ADDR        proc2Dmem_addr,    // this goes to memory
    output MEM_BLOCK   proc2Dmem_data_out, // this goes to memory

    // From load 
    input ADDR  load2Dcache_addr, // this goes to Dcache_data_in on FU load
    input logic load2Dcache_valid,// this goes to Dcache_valid_in on FU load

    // To load unit
    output MEM_BLOCK dcache2load_data_out, // Data is mem[load2Dcache_addr]
    output logic     dcache2load_valid_out, // When valid is high

    // From store 
    input ADDR store2Dcache_addr,
    input MEM_SIZE store2Dcache_size,
    input DATA store2Dcache_data,
    input logic store2Dcache_valid,

    output logic dontallowicachebruh,

    // To store queue
    output logic store_done, // When valid is high

    
    //DEBUG ONLY
    output logic [`ICACHE_LINES-1:0][$bits(MEM_BLOCK)-1:0]  memDataDebug,
    output DCACHE_TAG [`ICACHE_LINES-1:0] dcache_tags_debug
    );

    // Note: cache tags, not memory tags
    logic [12-`ICACHE_LINE_BITS:0] current_tag,   last_tag;
    logic [`ICACHE_LINE_BITS -1:0] current_index, last_index;
    logic                          got_mem_data;

    // flags for the cache
    CACHE_STATUS cache_status;
    logic read_en;
    logic write_en;
    logic cache_hit;
    logic valid_out;

    // writeback logic
    MEM_BLOCK                      dcache_write_data;
    logic                          writeback_en;


    // aligned store data logic
    MEM_BLOCK                      store_data; // Data is mem[proc2Dcache_addr]m
    MEM_BLOCK                      aligned_store_data;
    MEM_BLOCK                      aligned_store_data_negate;

    // ---- Cache data ---- //
    DCACHE_TAG [`ICACHE_LINES-1:0] dcache_tags;
    logic [$bits(MEM_BLOCK)-1:0] dcache_data;

    // ---- Cache control logic ---- //
    assign read_en   = load2Dcache_valid || store2Dcache_valid;
    //assign write_en  = (got_mem_data && (!dcache_tags[current_index].dirty || load2Dcache_valid)) || (store2Dcache_valid);
    assign write_en = got_mem_data || (store2Dcache_valid && cache_hit);
    assign writeback_en = (store2Dcache_valid || load2Dcache_valid) && dcache_tags[current_index].valid && 
                          (dcache_tags[current_index].tags != current_tag) && dcache_tags[current_index].dirty && cache_status != MEM_STAGE;
    assign cache_hit = dcache_tags[current_index].valid && (dcache_tags[current_index].tags == current_tag);
    assign dcache_write_data = (store2Dcache_valid && cache_hit) ? store_data : Dmem2proc_data; // Handle as necessary

    // store data logic with WB

// store data logic with masking and shifting
always_comb begin
    logic [63:0] mask;
    logic [63:0] shifted_data;
    store_data = dcache_data; // default to original cache line

    case (store2Dcache_size)
        BYTE: begin
            mask = 64'hFF << (store2Dcache_addr[2:0] * 8);
            shifted_data = store2Dcache_data[7:0] << (store2Dcache_addr[2:0] * 8);
        end
        HALF: begin
            mask = 64'hFFFF << (store2Dcache_addr[2:0] * 8);
            shifted_data = store2Dcache_data[15:0] << (store2Dcache_addr[2:0] * 8);
        end
        WORD: begin
            mask = 64'hFFFFFFFF << (store2Dcache_addr[2:0] * 8);
            shifted_data = store2Dcache_data[31:0] << (store2Dcache_addr[2:0] * 8);
        end
        default: begin
            mask = 64'h0;
            shifted_data = 64'h0;
        end
    endcase

    store_data = (dcache_data & ~mask) | (shifted_data & mask);
end

    memDP #(
        .WIDTH     ($bits(MEM_BLOCK)),
        .DEPTH     (`ICACHE_LINES),
        .READ_PORTS(1),
        .BYPASS_EN (0))
    dcache_mem (
        .clock(clock),
        .reset(reset),
        // read enable only when there is a load or if there is a cache miss, the index is dirty, and the instruction is not a store
        .re   (read_en), 
        .raddr(current_index),
        .rdata(dcache_data),
        .we   (write_en),      // write when it finds the data from memory
        .waddr(current_index),
        .wdata(dcache_write_data),
        .memDataDebug(memDataDebug)
    );

    assign proc2Dmem_data_out      = cache_status == WRITEBACK ? dcache_data : '0;
    assign dcache2load_data_out    = cache_status == DONE && load2Dcache_valid ? dcache_data : '0;

    // ---- Addresses and final outputs ---- //
    // it prioritizes load2Dcache_addr over store2Dcache_addr
    assign {current_tag, current_index} = load2Dcache_valid ? load2Dcache_addr[15:3] : (store2Dcache_valid ? store2Dcache_addr[15:3] : '0);
    assign valid_out = dcache_tags[current_index].valid && (dcache_tags[current_index].tags == current_tag);
    assign dcache2load_valid_out = load2Dcache_valid && valid_out && cache_status == DONE;
    assign store_done = store2Dcache_valid && cache_hit && cache_status == DONE;

    // ---- Main cache logic ---- //
    MEM_TAG current_mem_tag; // The current memory tag we might be waiting on
    logic miss_outstanding, unanswered_miss; // Whether a miss has received its response tag to wait on
    logic changed_addr;
    logic update_mem_tag;

    assign got_mem_data = (current_mem_tag == Dmem2proc_data_tag) && (current_mem_tag != 0);
    assign changed_addr = (current_index != last_index) || (current_tag != last_tag);

    // Set mem tag to zero if we changed_addr, and keep resetting while there is
    // a miss_outstanding. Then set to zero when we got_mem_data.
    // (this relies on Dmem2proc_transaction_tag being zero when there is no request)
    assign update_mem_tag = changed_addr || miss_outstanding || got_mem_data;

    // If we have a new miss or still waiting for the response tag, we might
    // need to wait for the response tag because dcache has priority over icache
    assign unanswered_miss = changed_addr ? !valid_out : miss_outstanding && (Dmem2proc_transaction_tag == 0);

    // Keep sending memory requests until we receive a response tag or change addresses

    assign proc2Dmem_command = (miss_outstanding && !changed_addr || cache_status == WRITEBACK) ? 
                            ((cache_status == WRITEBACK) ? MEM_STORE : 
                            ((load2Dcache_valid || (!cache_hit && store2Dcache_valid))) ? MEM_LOAD : MEM_NONE) : MEM_NONE; 
    assign proc2Dmem_addr    =  writeback_en ? {dcache_tags[current_index].tags, current_index, 3'b0} : 
                            ((cache_status == MEM_STAGE)  ? {current_tag, current_index, 3'b0} :  '0);

    // ---- Cache state registers ---- //
    always_ff @(posedge clock) begin
        if (reset) begin
            last_index       <= -1; // These are -1 to get ball rolling when
            last_tag         <= -1; // reset goes low because addr "changes"
            current_mem_tag  <= '0;
            miss_outstanding <= '0;
            cache_status     <= IDLE_CACHE;
            dcache_tags      <= '{default: '0}; // Set all cache tags and valid bits to 0
        end else begin

            miss_outstanding <= unanswered_miss;
            // Only track the memory tag when we launch a new request and get a tag back
            if (update_mem_tag) begin
                current_mem_tag <= Dmem2proc_transaction_tag;
            end
            if (write_en) begin // If data came from memory, meaning tag matches
                dcache_tags[current_index].tags  <= current_tag;
                dcache_tags[current_index].valid <= 1'b1;
                dcache_tags[current_index].dirty <= store2Dcache_valid; // Set dirty bit if store
            end
            case (cache_status)
                IDLE_CACHE: begin
                    if (writeback_en) begin
                        cache_status <= mispredict ? IDLE_CACHE : WRITEBACK;
                    end else if (valid_out) begin
                        cache_status <= DONE;
                    end else if (load2Dcache_valid || store2Dcache_valid) begin
                        cache_status <= MEM_STAGE;
                    end 
                end
                MEM_STAGE: begin
                    if (valid_out) begin
                        cache_status <= DONE;
                    end
                    last_index       <= current_index;
                    last_tag         <= current_tag;
                end
                WRITEBACK: begin
                    cache_status <= MEM_STAGE;
                    last_index       <= current_index;
                    last_tag         <= current_tag;
                end
                DONE: begin
                    cache_status <= IDLE_CACHE;
                end
                default: begin
                end
            endcase
        end

    end

    assign dcache_tags_debug = dcache_tags;

endmodule // dcache