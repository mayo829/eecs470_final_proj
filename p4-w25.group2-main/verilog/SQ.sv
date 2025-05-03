//////////////////////////////////////////////////////////////////////////
//                                                                      //
//                          Store Queue Module                          //
//                                                                      //
//////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

module SQ (
    input  logic                                            reset,
    input  logic                                            clock,
    input  logic                                            branch_mispredict,

    //---------------------------- execute interface ---------------------------//
    input  COMPLETE_SQ_PACKET [`N-1:0]                      complete_sq_packet,
    //--------------------------------------------------------------------------//

    //---------------------------- retire interface ----------------------------//
    input  logic              [`N-1:0]                      retired_req,
    input  logic                                            store_done,
    output SQ_PACKET          [`N-1:0]                      sQueue_packet_out,
    //--------------------------------------------------------------------------//

    //---------------------------- dispatch interface --------------------------//
    input  logic              [`N-1:0]                      dispatch_req,
    output logic              [`N-1:0][$clog2(`ROB_SZ)-1:0] sq_pos,
    output logic              [`N-1:0]                      sq_pos_valid,
    output logic                                            full,
    output logic              [$clog2(`ROB_SZ)-1:0]         usedEntries,
    output logic              [$clog2(`ROB_SZ)-1:0]         tail_comb,
    output logic              [$clog2(`ROB_SZ)-1:0]         tail_seq,
    //--------------------------------------------------------------------------//

    //---------------------------- other signals -------------------------------//
    output SQ_ENTRY           [`ROB_SZ-1:0]                 sQueue,
    output logic              [$clog2(`ROB_SZ)-1:0]         head
    //--------------------------------------------------------------------------//
);

    // Internal state
    logic [$clog2(`ROB_SZ)-1:0] head_next, tail_next, tail_reg;
    logic [$clog2(`ROB_SZ)-1:0] used_next, used_reg;
    SQ_ENTRY [`ROB_SZ-1:0] sQueue_reg, sQueue_next;
    SQ_ENTRY [`ROB_SZ-1:0] clean;
    assign full        = used_reg == `ROB_SZ;
    assign tail_comb   = tail_next;
    assign tail_seq    = tail_reg;

    always_comb begin
        sQueue_next       = sQueue_reg;
        head_next         = head;
        tail_next         = tail_reg;
        used_next         = used_reg;
        sq_pos            = '{default: '0};
        sq_pos_valid      = '{default: '0};
        sQueue_packet_out = '{default: '0};
        clean             = '{default: '0};

        // Dispatch new entries
        for (int i = 0; i < `N; i++) begin
            if (!reset && !sQueue_next[tail_next].valid && dispatch_req[i]) begin
                sq_pos[i]                        = tail_next;
                sq_pos_valid[i]                  = 1'b1;
                sQueue_next[tail_next].allocated = 1'b1;
                tail_next                        = (tail_next + 1) % `ROB_SZ;
                used_next                        = used_next + 1;
            end
        end

        // Complete store values
        for (int i = 0; i < `N; i++) begin
            if (!reset && complete_sq_packet[i].valid && sQueue_next[complete_sq_packet[i].sq_pos].allocated) begin
                sQueue_next[complete_sq_packet[i].sq_pos].valid      = 1'b1;
                sQueue_next[complete_sq_packet[i].sq_pos].address    = complete_sq_packet[i].address;
                sQueue_next[complete_sq_packet[i].sq_pos].value      = complete_sq_packet[i].value;
                sQueue_next[complete_sq_packet[i].sq_pos].mem_size   = complete_sq_packet[i].mem_size;
                sQueue_next[complete_sq_packet[i].sq_pos].rob_ptr    = complete_sq_packet[i].rob_ptr;
            end
        end

        // Mark store as retired
        for (int i = 0; i < `N; i++) begin
            if (!reset && retired_req[i] && sQueue_next[head_next].valid) begin
                sQueue_next[head_next].retired = 1'b1;
                sQueue_next[head_next].pending_retirement = 1'b1;
            end
        end

        // Output store if pending retirement and store_done
        for (int i = 0; i < `N; i++) begin
            if (!reset && sQueue_next[head_next].pending_retirement && sQueue_next[head_next].valid) begin
                sQueue_packet_out[i].valid     = sQueue_next[head_next].valid;
                sQueue_packet_out[i].value     = sQueue_next[head_next].value;
                sQueue_packet_out[i].mem_size  = sQueue_next[head_next].mem_size;
                sQueue_packet_out[i].address   = sQueue_next[head_next].address;
                sQueue_packet_out[i].rob_ptr   = sQueue_next[head_next].rob_ptr;
                if (store_done) begin
                    sQueue_next[head_next].valid = 1'b0;
                    sQueue_next[head_next].pending_retirement = 1'b0;
                    head_next = (head_next + 1) % `ROB_SZ;
                    used_next = used_next - 1;
                end
                break;
            end
        end

        // // Handle mispredict flush
        // if (branch_mispredict) begin
        //     int new_tail = 0;
        //     int new_count = 0;
        //     for (int i = 0; i < `ROB_SZ; i++) begin
        //         if (sQueue_next[i].retired) begin
        //             clean[new_tail] = sQueue_next[i];
        //             new_tail++;
        //             new_count++;
        //         end
        //     end
        //     sQueue_next = clean;
        //     head_next   = 0;
        //     tail_next   = new_tail;
        //     used_next   = new_count;
        // end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            head        <= 0;
            tail_reg    <= 0;
            used_reg    <= 0;
            sQueue_reg  <= '{default: '0};
        end else begin
            head        <= head_next;
            tail_reg    <= tail_next;
            used_reg    <= used_next;
            sQueue_reg  <= sQueue_next;
        end
    end

    assign sQueue = sQueue_reg;
    assign usedEntries = used_reg;
    assign tail = tail_reg;

endmodule