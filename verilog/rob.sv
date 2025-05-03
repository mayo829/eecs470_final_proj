//THIS SHOULD BE GOOD, DOES NOT HANDLE REWIND

`include "sys_defs.svh"

module rob #(
    parameter ROB_SZ          = 16,          // Number of ROB entries
    parameter ROB_PTR_WIDTH   = $clog2(ROB_SZ),
    parameter PR_WIDTH        = 6,           // Physical register tag width
    parameter ROB_ENTRY_WIDTH = 1 + 1 + 5 + PR_WIDTH + PR_WIDTH + 32
) (
    input   logic                                       clock,
    input   logic                                       reset,

    // ---------------- Dispatch Interface ----------------
    input   logic   [`N-1:0]                            DispatchEntryValid,
    input   logic   [1:0]                               NumberToDispatch,
    input   ADDR    [`N-1:0]                            dispatch_PC,
    input   REG_IDX [`N-1:0]                            dispatch_dest_reg,
    // I believe this may be to interact with the map table
    input   logic [`N-1:0][PR_WIDTH-1:0]                dispatch_T,
    input   logic [`N-1:0][PR_WIDTH-1:0]                dispatch_Told,
    input   ADDR  [`N-1:0]                              dispatch_SPEC_PC,
    input   logic [`N-1:0]                              halt,
    input   logic [`N-1:0]                              is_branch,
    input   logic [`N-1:0]                              is_store,
    input   INST  [`N-1:0]                              inst,

    // T old, also known as dispatch old tag
    output  logic [ROB_PTR_WIDTH:0]                     NumFreeEntries,
    // The number of free entries shared to outside the module
    // This is so we know the min(min(freeROBentries, freeRSentries, freeListRegisters), scalarN)
    // So we know how many we can actually dispatch 

    // ---------------- Update Interface ----------------
    // input   logic        [`N-1:0]                       complete, //Essentially the complete stage
    // input   logic [`N-1:0][ROB_PTR_WIDTH-1:0]           completeEntryIndex,
    input  CDB_ENTRY_PACKET [1:0] CDB_in,  // CDB Input for writeback

    input logic [`N-1:0]                     store_complete,
    input logic [`N-1:0][ROB_PTR_WIDTH-1:0]  store_rob_ptr,

    // dont forget to cam from store queue
    // also, dont forget to make sure commit is perfect with these new changes
    // make sure you can not commit more than one store per cycle

    // ---------------- Commit Interface ----------------
    input   logic                                       performStoreReq,
    input   logic                                       store_done,
    input   logic                                       stallStore,
    output  logic        [`N-1:0]                       commit_valid,
    output  REG_IDX      [`N-1:0]                       commit_dest_reg,
    output  logic        [`N-1:0][PR_WIDTH-1:0]         commit_T,
    output  logic        [`N-1:0][PR_WIDTH-1:0]         commit_Told,
    output  ADDR         [`N-1:0]                       commit_PC,

    output ROB_RETIRE_PACKET [`N-1:0]                   RobEntriesToRetire,
    output logic                                        sq_retired_req,
    output logic [ROB_PTR_WIDTH-1:0]                    tail,

    output ROB_RETIRE_PACKET [`ROB_SZ-1:0]              rob_dbg
    );

    //-------------------------------------------------------------------------
    // Internal Storage (current state)
    //-------------------------------------------------------------------------
    ROB_RETIRE_PACKET   [`ROB_SZ-1:0]               rob_entries;
    logic               [ROB_PTR_WIDTH-1:0]         head;
    logic               [ROB_PTR_WIDTH:0]           usedEntries;

    //-------------------------------------------------------------------------
    // Next State (combinational)
    //-------------------------------------------------------------------------
    ROB_RETIRE_PACKET [`ROB_SZ-1:0] next_rob_entries;
    logic               [ROB_PTR_WIDTH-1:0] next_head, next_tail;
    logic               [ROB_PTR_WIDTH:0]   next_usedEntries;

    //-------------------------------------------------------------------------
    // NumFreeEntries: just a read of (ROB_SZ - usedEntries)
    //-------------------------------------------------------------------------
    assign NumFreeEntries = ROB_SZ - usedEntries;

    logic internal_stall;
    logic internal_stall_next;


    //-------------------------------------------------------------------------
    // Commit Decision Logic (Combinational)
    //-------------------------------------------------------------------------
    always_comb begin
        // By default, zero out commit outputs
        sq_retired_req = '0;
        internal_stall_next = internal_stall;
        if(store_done) begin
        internal_stall_next = '0;
        end
        for (int i = 0; i < `N; i++) begin
            commit_valid[i]         = 1'b0;
            commit_dest_reg[i]      = '0;
            commit_T[i]             = '0;
            commit_Told[i]          = '0;
            commit_PC[i]            = '0;
            RobEntriesToRetire[i]     = '{default: '0};
        end

        // For up to `N consecutive entries from head, if valid&complete, commit
        for (int i = 0; i < `N; i++) begin
            if ((usedEntries > i)       &&
                rob_entries[(head + i) % ROB_SZ].valid     &&
                rob_entries[(head + i) % ROB_SZ].complete  &&
                !(rob_entries[(head + i) % ROB_SZ].is_store && (stallStore || internal_stall)) &&
                !(rob_entries[(head + i) % ROB_SZ].halt && internal_stall) &&
                !(rob_entries[(head + i) % ROB_SZ].is_branch && internal_stall) && 
                !(rob_entries[(head + i) % ROB_SZ].if_take_branch && internal_stall))begin
                commit_valid[i]         = 1'b1;
                commit_dest_reg[i]      = rob_entries[(head + i) % ROB_SZ].dest_reg;
                commit_T[i]             = rob_entries[(head + i) % ROB_SZ].T;
                commit_Told[i]          = rob_entries[(head + i) % ROB_SZ].Told;
                commit_PC[i]            = rob_entries[(head + i) % ROB_SZ].PC;
                RobEntriesToRetire[i]   = rob_entries[(head + i) % ROB_SZ];
                if(rob_entries[(head + i) % ROB_SZ].is_branch || rob_entries[(head + i) % ROB_SZ].if_take_branch) begin
                break;
                end
                if(rob_entries[(head + i) % ROB_SZ].is_store) begin
                    sq_retired_req      = 1'b1;
                    if(!store_done) begin
                    internal_stall_next = 1'b1;
                    end
                    
                    break;
                    // I think this will make sure only one store gets committed, 
                    // hopefully by next cycle, store stall will kick in
                    // if(rob_entries[(head + i + '1) % ROB_SZ].is_store) begin
                    //     break;
                    // end
                end
            end 
            else begin
                // stop at the first not-complete or invalid
                break;
            end
        end
    end

    //-------------------------------------------------------------------------
    // Next-Cycle Preparation 
    //   1) Copy current -> next
    //   2) Apply commit
    //   3) Apply update
    //   4) Apply dispatch
    //-------------------------------------------------------------------------
    always_comb begin
        // 1) Copy current state into next-state by default
        for (int k = 0; k < ROB_SZ; k++) begin
            next_rob_entries[k] = rob_entries[k];
        end
        next_head           = head;
        next_tail           = tail;
        next_usedEntries    = usedEntries;



        //2) COMMIT Stage
        for (int i = 0; i < `N; i++) begin
            // If there's at least one entry and the head entry is valid+complete
            if (


                (next_usedEntries > 0)           &&
                rob_entries[next_head].valid     &&
                rob_entries[next_head].complete  &&


                !(rob_entries[next_head].is_store && (stallStore || internal_stall))    &&
                !(rob_entries[next_head].halt && internal_stall)                        &&
                !(rob_entries[(head + i) % ROB_SZ].is_branch && internal_stall)         && 
                !(rob_entries[(head + i) % ROB_SZ].if_take_branch && internal_stall)) begin
                if(rob_entries[next_head].is_store || rob_entries[next_head].is_branch || (rob_entries[next_head].if_take_branch && !rob_entries[next_head].is_store)) begin
                next_rob_entries[next_head]             = '{default: '0};
                next_head                               = (next_head + 1) % ROB_SZ;
                next_usedEntries                        = next_usedEntries - 1;    
                break;
                end else begin
                next_rob_entries[next_head]             = '{default: '0};
                next_head                               = (next_head + 1) % ROB_SZ;
                next_usedEntries                        = next_usedEntries - 1;    
                end
                end else begin
                break;
            end
        end

        // 😊 - Bureir's smiley face


        // // 3) UPDATE Stage
        // for (int i = 0; i < `N; i++) begin
        //     if (complete[i] && (completeEntryIndex[i] < ROB_SZ)) begin
        //         next_rob_entries[completeEntryIndex[i]].complete = complete[i];
        //     end
        // end
        // 3) COMPLETE Stage
        for (int i = 0; i < ROB_SZ; i++) begin
            if ((CDB_in[0].valid && (CDB_in[0].tag == rob_entries[i].T && CDB_in[0].rob_ptr == i)) || (store_complete[0] && store_rob_ptr[0] == i)) begin
                next_rob_entries[i].complete        = 1'b1;
                if(!next_rob_entries[i].is_store) begin
                next_rob_entries[i].if_take_branch  = CDB_in[0].if_take_branch;
                next_rob_entries[i].target_pc       = CDB_in[0].target_pc;
                end
            end else if ((CDB_in[1].valid && ((CDB_in[1].tag == rob_entries[i].T) && CDB_in[1].rob_ptr == i)) || (store_complete[1] && store_rob_ptr[1] == i)) begin
                next_rob_entries[i].complete        = 1'b1;
                if(!next_rob_entries[i].is_store) begin
                next_rob_entries[i].if_take_branch  = CDB_in[1].if_take_branch;
                next_rob_entries[i].target_pc       = CDB_in[1].target_pc;
                end
            end
        end


        // 4) DISPATCH Stage
        for (int i = 0; i < `N; i++) begin
            if (!reset && DispatchEntryValid[i] && i < NumberToDispatch) begin // commented out "&& next_usedEntries < ROB_SZ" also 
                next_rob_entries[next_tail].valid           = 1'b1;
                next_rob_entries[next_tail].complete        = halt[i] ? 1'b1 : 1'b0;
                next_rob_entries[next_tail].dest_reg        = dispatch_dest_reg[i];
                next_rob_entries[next_tail].T               = dispatch_T[i];
                next_rob_entries[next_tail].Told            = dispatch_Told[i];
                next_rob_entries[next_tail].PC              = dispatch_PC[i];
                next_rob_entries[next_tail].halt            = halt[i];
                next_rob_entries[next_tail].is_branch       = is_branch[i];
                next_rob_entries[next_tail].is_store        = is_store[i];
                next_rob_entries[next_tail].inst            = inst[i];
                next_rob_entries[next_tail].SPEC_PC         = dispatch_SPEC_PC[i];//might need to change
                next_tail                                   = (next_tail + 1) % ROB_SZ;
                next_usedEntries                            = next_usedEntries + 1;      
                
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
            internal_stall <= '0;
            for (int k = 0; k < ROB_SZ; k++) begin
                rob_entries[k]       <= '{default: '0};
            end
        end else begin
            // Copy next-state to current
            head        <= next_head;
            tail        <= next_tail;
            usedEntries <= next_usedEntries;
            internal_stall <= internal_stall_next;
            for (int k = 0; k < ROB_SZ; k++) begin
                rob_entries[k] <= next_rob_entries[k];
            end
        end
    end

assign rob_dbg = rob_entries;

endmodule