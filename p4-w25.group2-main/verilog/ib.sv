`include "sys_defs.svh"

module ib (
    input  logic                                   clock,
    input  logic                                   reset,
    input  logic [`N-1:0]                          rd_EN,
    input  logic [`N-1:0]                          wr_EN,
    input  FETCH_DISPATCH_PACKET [`N-1:0]          fifo_pckt_in,
    output logic                                   full,
    output FETCH_DISPATCH_PACKET [`N-1:0]          fifo_pckt_out,
    // output logic [1:0]                             fifo_top_valid,
    output FETCH_DISPATCH_PACKET [`FIFO_SZ_IB-1:0]    fifo,
    output logic [$clog2(`FIFO_SZ_IB)-1:0]            head
);
//

    //-------------------------------------------------------------------------
    // Internal Storage (current state)
    //-------------------------------------------------------------------------
    logic               [$clog2(`FIFO_SZ_IB)-1:0]   tail;
    logic               [$clog2(`FIFO_SZ_IB):0]   usedEntries;
    logic               [$clog2(`FIFO_SZ_IB):0]   NumFreeEntries; 

    //-------------------------------------------------------------------------
    // Next State (combinational)
    //-------------------------------------------------------------------------
    //ISSUE_FU_PACKET                              fifo         [`FIFO_SZ_IB-1:0];
    FETCH_DISPATCH_PACKET        [`FIFO_SZ_IB-1:0]    next_fifo    ;
    logic               [$clog2(`FIFO_SZ_IB)-1:0]     next_head, next_tail;
    logic               [$clog2(`FIFO_SZ_IB):0]     next_usedEntries;

    //-------------------------------------------------------------------------
    // NumFreeEntries: just a read of (`FIFO_SZ_IB - usedEntries)
    //-------------------------------------------------------------------------
    assign NumFreeEntries = `FIFO_SZ_IB - usedEntries;


    //-------------------------------------------------------------------------
    // fifo_pckt_out Decision Logic (Combinational)
    //-------------------------------------------------------------------------

    always_comb begin
        // 1) Copy current state into next-state by default
        next_fifo           = fifo;
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
                next_head = (next_head + 1) % `FIFO_SZ_IB;
                next_usedEntries = next_usedEntries - 1;
            end
        end

        // Write packets into FIFO, if space allows
        for (int i = 0; i < `N; i++) begin
            if (!reset && fifo_pckt_in[i].valid && !next_fifo[next_tail].valid && wr_EN[i]) begin
                next_fifo[next_tail] = fifo_pckt_in[i];
                next_tail = (next_tail + 1) % `FIFO_SZ_IB;
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
            fifo        <= '{default: '0};
            full        <= 1'b0;
        end else begin
            // Copy next-state to current
            head        <= next_head;
            tail        <= next_tail;
            usedEntries <= next_usedEntries;
            fifo        <= next_fifo;
            full        <= (next_usedEntries >= `FIFO_SZ_IB - 2);
        end
    end
endmodule