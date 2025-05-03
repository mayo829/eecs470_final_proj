`include "sys_defs.svh"

module FIFO (
    input  logic                          clock,
    input  logic                          reset,
    input  logic [`N-1:0]                 rd_EN,
    input  logic [`N-1:0]                 wr_EN,
    input  ISSUE_PACKET [`N-1:0]          fifo_pckt_in,
    output logic                          full,
    output ISSUE_PACKET [`N-1:0]          fifo_pckt_out,
    output ISSUE_PACKET [`FIFO_SZ-1:0]    fifo,
    output logic [$clog2(`FIFO_SZ)-1:0]   head
);

    //-------------------------------------------------------------------------
    // Internal Storage (current state)
    //-------------------------------------------------------------------------
    logic               [$clog2(`FIFO_SZ)-1:0]   tail;
    logic               [$clog2(`FIFO_SZ):0]   usedEntries;
    logic               [$clog2(`FIFO_SZ):0]   NumFreeEntries; 


    //-------------------------------------------------------------------------
    // Next State (combinational)
    //-------------------------------------------------------------------------
    //ISSUE_FU_PACKET                              fifo         [`FIFO_SZ-1:0];
    ISSUE_PACKET        [`FIFO_SZ-1:0]           next_fifo    ;
    logic               [$clog2(`FIFO_SZ)-1:0]   next_head, next_tail;
    logic               [$clog2(`FIFO_SZ):0]   next_usedEntries;

    //-------------------------------------------------------------------------
    // NumFreeEntries: just a read of (`FIFO_SZ - usedEntries)
    //-------------------------------------------------------------------------
    assign NumFreeEntries = `FIFO_SZ - usedEntries;
    
    //-------------------------------------------------------------------------
    // fifo_pckt_out Decision Logic (Combinational)
    //-------------------------------------------------------------------------

    always_comb begin
        // 1) Copy current state into next-state by default
        next_fifo = fifo;
        next_head           = head;
        next_tail           = tail;
        next_usedEntries    = usedEntries;
        
        // By default, zero out FIFO outputs
        fifo_pckt_out = '{default: '0};
        
        // Read and update FIFO output packets
        for (int i = 0; i < `N; i++) begin
            if (!reset && rd_EN[i] && next_fifo[next_head].valid) begin
                fifo_pckt_out[i] = next_fifo[next_head];
                next_fifo[next_head].valid = 1'b0; // Clear the valid flag
                next_head = (next_head + 1) % `FIFO_SZ;
                next_usedEntries = next_usedEntries - 1;
            end
        end

        // Write packets into FIFO, if space allows
        for (int i = 0; i < `N; i++) begin
            if (!reset && fifo_pckt_in[i].valid && !next_fifo[next_tail].valid && wr_EN[i]) begin
                next_fifo[next_tail] = fifo_pckt_in[i];
                next_tail = (next_tail + 1) % `FIFO_SZ;
                next_usedEntries = next_usedEntries + 1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Sequential Update (All state updated here)
    //-------------------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (reset) begin
            // Clear everything
            head        <= '0;
            tail        <= '0;
            usedEntries <= '0;
            fifo <= '{default: '0};
        end else begin
            // Copy next-state to current
            head        <= next_head;
            tail        <= next_tail;
            usedEntries <= next_usedEntries;
            fifo        <= next_fifo;
            full <= (next_usedEntries >= `FIFO_SZ - 2);
        end
    end
endmodule

module cache_buffer (
    input  logic                                 clock,
    input  logic                                 reset,
    input  logic                                 rd_EN,
    input  logic                                 wr_EN,
    input  CACHE_BUFFER_PACKET                   fifo_pckt_in,
    output logic                                 full,
    output CACHE_BUFFER_PACKET                   fifo_pckt_out,
    output CACHE_BUFFER_PACKET [`FIFO_SZ-1:0]    fifo,
    output logic [$clog2(`FIFO_SZ)-1:0]          head
);

    //-------------------------------------------------------------------------
    // Internal Storage (current state)
    //-------------------------------------------------------------------------
    logic               [$clog2(`FIFO_SZ)-1:0]   tail;
    logic               [$clog2(`FIFO_SZ):0]   usedEntries;
    logic               [$clog2(`FIFO_SZ):0]   NumFreeEntries; 


    //-------------------------------------------------------------------------
    // Next State (combinational)
    //-------------------------------------------------------------------------
    //ISSUE_FU_PACKET                              fifo         [`FIFO_SZ-1:0];
    CACHE_BUFFER_PACKET        [`FIFO_SZ-1:0]           next_fifo    ;
    logic               [$clog2(`FIFO_SZ)-1:0]   next_head, next_tail;
    logic               [$clog2(`FIFO_SZ):0]   next_usedEntries;

    //-------------------------------------------------------------------------
    // NumFreeEntries: just a read of (`FIFO_SZ - usedEntries)
    //-------------------------------------------------------------------------
    assign NumFreeEntries = `FIFO_SZ - usedEntries;
    
    //-------------------------------------------------------------------------
    // fifo_pckt_out Decision Logic (Combinational)
    //-------------------------------------------------------------------------

    always_comb begin
        // 1) Copy current state into next-state by default
        next_fifo = fifo;
        next_head           = head;
        next_tail           = tail;
        next_usedEntries    = usedEntries;
        
        // By default, zero out FIFO outputs
        fifo_pckt_out = '{default: '0};
        
        // Read and update FIFO output packets
        for (int i = 0; i < 1; i++) begin
            if (!reset && rd_EN && next_fifo[next_head].valid) begin
                fifo_pckt_out = next_fifo[next_head];
                next_fifo[next_head].valid = 1'b0; // Clear the valid flag
                next_head = (next_head + 1) % `FIFO_SZ;
                next_usedEntries = next_usedEntries - 1;
            end
        end

        // Write packets into FIFO, if space allows
        for (int i = 0; i < 1; i++) begin
            if (!reset && fifo_pckt_in.valid && !next_fifo[next_tail].valid && wr_EN) begin
                next_fifo[next_tail] = fifo_pckt_in;
                next_tail = (next_tail + 1) % `FIFO_SZ;
                next_usedEntries = next_usedEntries + 1;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Sequential Update (All state updated here)
    //-------------------------------------------------------------------------
    always_ff @(posedge clock) begin
        if (reset) begin
            // Clear everything
            head        <= '0;
            tail        <= '0;
            usedEntries <= '0;
            fifo <= '{default: '0};
        end else begin
            // Copy next-state to current
            head        <= next_head;
            tail        <= next_tail;
            usedEntries <= next_usedEntries;
            fifo        <= next_fifo;
            full <= (next_usedEntries >= `FIFO_SZ - 2);
        end
    end
endmodule