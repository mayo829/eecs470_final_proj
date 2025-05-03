`include "sys_defs.svh"

module rs (
    input  logic                      clock,
    input  logic                      reset,

    // Dispatch stage input (up to N new entries per cycle)
    input  DISPATCH_RS_PACKET        [`N-1:0] RS_in,
    input  logic [1:0]               NumberToDispatch,

    // Issue stage output (up to N instructions per cycle)
    output RS_ISSUE_PACKET           [`N-1:0] issue_out,

    // FIFO full signals for each FU (to block issuing)
    input  FIFO_STALL_PACKET         fifo_full,

    // Free entry counter
    output logic [$clog2(`RS_SZ):0]  NumFreeEntriesAfterIssue,

    // CDB input for waking up instructions
    input  CDB_ENTRY_PACKET          [`N-1:0] cdb,

    // Debug output: current RS contents
    output DISPATCH_RS_PACKET       [`RS_SZ-1:0] rs
);

    // ----------------------
    // Internal State
    // ----------------------
    DISPATCH_RS_PACKET [`RS_SZ-1:0] rs_next;
    logic [$clog2(`RS_SZ):0] usedEntries, next_usedEntries;
    logic [3:0] issued_FU_types;
    logic [1:0] numIssued;
    logic stall;
    int dispatched;

    // ----------------------
    // Combinational Logic
    // ----------------------
    always_comb begin
        rs_next = rs;
        numIssued = 0;
        issue_out = '{default: '0};
        issued_FU_types = 4'b0000;

        // ============
        // Wakeup via CDB (tag CAM)
        // ============
        for (int i = 0; i < `RS_SZ; i++) begin
            if (rs_next[i].valid) begin
                for (int c = 0; c < `N; c++) begin
                    if (cdb[c].valid) begin
                        if (rs_next[i].T1 == cdb[c].tag) rs_next[i].T1p = 1;
                        if (rs_next[i].T2 == cdb[c].tag) rs_next[i].T2p = 1;
                    end
                end
            end
        end

        // ============
        // Issue Selection (up to N instructions)
        // ============
        for (int i = 0; i < `N; i++) begin
            for (int j = 0; j < `RS_SZ; j++) begin
                if (numIssued >= `N) break;

                stall = 0;
                case (rs_next[j].FuncUnitType)
                    ALU0, ALU1: stall = fifo_full.alu;
                    MULT:       stall = fifo_full.mult;
                    BRANCH:     stall = fifo_full.branch;
                    default:    stall = 1'b1; // unknown type => don't issue
                endcase

                if (rs_next[j].valid && rs_next[j].T1p && rs_next[j].T2p &&
                    !stall && !issued_FU_types[rs_next[j].FuncUnitType]) begin

                    // Fill output packet
                    issue_out[i].valid         = 1'b1;
                    issue_out[i].FuncUnitType  = rs_next[j].FuncUnitType;
                    issue_out[i].alu_func      = rs_next[j].alu_func;
                    issue_out[i].mult_func     = rs_next[j].mult_func;
                    issue_out[i].PC            = rs_next[j].PC;
                    issue_out[i].NPC           = rs_next[j].NPC;
                    issue_out[i].opa_select    = rs_next[j].opa_select;
                    issue_out[i].opb_select    = rs_next[j].opb_select;
                    issue_out[i].inst          = rs_next[j].inst;
                    issue_out[i].dest_reg_idx  = rs_next[j].TD;
                    issue_out[i].T1            = rs_next[j].T1;
                    issue_out[i].T2            = rs_next[j].T2;
                    issue_out[i].T1_ready      = 1'b1;
                    issue_out[i].T2_ready      = 1'b1;

                    // Mark FU type as used, free RS slot
                    issued_FU_types[rs_next[j].FuncUnitType] = 1'b1;
                    rs_next[j].valid = 1'b0;
                    rs_next[j].busy = 1'b0;
                    numIssued++;
                    break;
                end
            end
        end

        // ============
        // Dispatch New Instructions
        // ============
        dispatched = 0;
        for (int i = 0; i < `N; i++) begin
            if (!RS_in[i].busy) continue;
            for (int j = 0; j < `RS_SZ; j++) begin
                if (!rs_next[j].busy) begin
                    rs_next[j] = RS_in[i];
                    rs_next[j].busy = 1'b1;
                    rs_next[j].valid = 1'b1;
                    dispatched++;
                    break;
                end
            end
            if (dispatched >= NumberToDispatch) break;
        end

        // ============
        // Update used entries count
        // ============
        next_usedEntries = 0;
        for (int i = 0; i < `RS_SZ; i++) begin
            if (rs_next[i].busy) next_usedEntries++;
        end
    end

    assign NumFreeEntriesAfterIssue = (`RS_SZ - usedEntries) - numIssued;

    // ----------------------
    // Sequential Updates
    // ----------------------
    always_ff @(posedge clock) begin
        if (reset) begin
            rs <= '{default: '0};
            usedEntries <= '0;
        end else begin
            rs <= rs_next;
            usedEntries <= next_usedEntries;
        end
    end

endmodule
