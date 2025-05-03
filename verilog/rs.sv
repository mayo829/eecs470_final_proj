`include "sys_defs.svh"


module rs (
    // System Signals
    input  logic                                        clock,
    input  logic                                        reset,
    
    // Pipeline Interface
    input  DISPATCH_RS_PACKET     [`N-1:0]              RS_in,
    input  FIFO_STALL_PACKET                            fifo_full,
    output RS_ISSUE_PACKET  [`N-1:0]                    issue_out,
    
    input  logic [1:0]                                  NumberToDispatch,

    // Hazard Interfaces
    output logic [$clog2(`RS_SZ):0]                     NumFreeEntriesAfterIssue,  //if the number of instructions being loaded does not equal numebr of available slots //should this be an integer
    
    // Common Data Bus
    input  CDB_ENTRY_PACKET [`N-1:0]                    cdb,

    input  logic [$clog2(`ROB_SZ)-1:0]                  head,

    //DEBUG
    output DISPATCH_RS_PACKET [`RS_SZ-1:0]              rs_dbg
    
);
//send output saying we should stall because rs is full



//array of RS entries
DISPATCH_RS_PACKET [`RS_SZ-1:0]   rs;
DISPATCH_RS_PACKET [`RS_SZ-1:0]   rs_next;

logic stall;

//the input will be 2 instrctions, and i hsould put them where there is avaiable slots
logic [$clog2(`RS_SZ):0] usedEntries; 
logic [$clog2(`RS_SZ):0] next_usedEntries; 
logic [1:0]              numIssued;
logic [$clog2(`RS_SZ):0] last_issued;


always_comb begin
    // Initialize all outputs to default values
    issue_out = '{default: '0};
    numIssued = 0;
    rs_next = rs;
    stall = 0;

    
   //is bro an unc or nah?
   //this could be a problem if you make sq store more than 1 insturction per cycle
   //TODO THERE IS NOTHING TO DO, JUST READ THIS IF U EVER CHANGE THE ARCHITECTURE TO STORE 2 PER CYCLE
    for(int i = 0; i < `RS_SZ; i++) begin
      if(head == rs_next[i].sq_pos) begin //I think this should be good, doesn't need to be gated by !uncstatus because there is no "else" where it is set to 0
        rs_next[i].UncStatus = 1'b1; // However, if causing bugs, just gate it to loads only and gate it to not unc status only
      end
    end

    
    // Broadcast CDB and update tags
    for(int i = 0; i < `RS_SZ; i++) begin
        if (((rs[i].T1 == cdb[0].tag) && cdb[0].valid) || ((rs[i].T1 == cdb[1].tag) && cdb[1].valid))
            rs_next[i].T1p = 1'b1;
        if (((rs[i].T2 == cdb[0].tag) && cdb[0].valid) || ((rs[i].T2 == cdb[1].tag) && cdb[1].valid))
            rs_next[i].T2p = 1'b1;
    end



    // Issue ready instructionssobieski
    for (int j = 0; j < `RS_SZ && numIssued < `N; j++) begin
       stall = ((fifo_full[0] && rs_next[j].FuncUnitType == ALU0) || (fifo_full[1] && rs_next[j].FuncUnitType == MULT) || (fifo_full[2] && rs_next[j].FuncUnitType == LS) || (fifo_full[3] && rs_next[j].FuncUnitType == BRANCH));
        if (rs_next[j].T1p && rs_next[j].T2p && rs_next[j].valid && !stall && !(rs_next[j].FuncUnitType == LS && !rs_next[j].UncStatus)) begin
            issue_out[numIssued].valid         = 1'b1;
            issue_out[numIssued].FuncUnitType  = rs[j].FuncUnitType;  // Changed from rs to rs_next
            issue_out[numIssued].alu_func      = rs[j].alu_func;
            issue_out[numIssued].mult_func     = rs[j].mult_func;
            issue_out[numIssued].PC            = rs[j].PC;
            issue_out[numIssued].NPC           = rs[j].NPC;
            issue_out[numIssued].opa_select    = rs[j].opa_select;
            issue_out[numIssued].opb_select    = rs[j].opb_select;
            issue_out[numIssued].inst          = rs[j].inst;
            issue_out[numIssued].dest_reg_idx  = rs[j].TD;
            issue_out[numIssued].T1            = rs[j].T1;
            issue_out[numIssued].T2            = rs[j].T2;
            issue_out[numIssued].T1_ready      = rs[j].T1p;
            issue_out[numIssued].T2_ready      = rs[j].T2p;
            issue_out[numIssued].mem_size      = rs[j].mem_size;
            issue_out[numIssued].sq_pos        = rs[j].sq_pos;
            issue_out[numIssued].rob_ptr       = rs[j].rob_ptr;
            rs_next[j]                         = '{default: '0};
            numIssued++;
        end
    end







  /*////////////////////////////////////////
  LOAD instruciton(s) into RS 
*////////////////////////////////////////
    for (int i = 0; i < `N; i++) begin
      for (int entry = 0; entry < `RS_SZ; entry++) begin
        if (!rs_next[entry].busy && RS_in[i].valid 
       // && (i < NumberToDispatch)
        ) begin
          rs_next[entry]            = RS_in[i];
          rs_next[entry].valid      = 1'b1;
          rs_next[entry].busy       = 1'b1;

          // Only override readiness *after inserting*
          case (RS_in[i].opa_select)
            OPA_IS_NPC,
            OPA_IS_ZERO: rs_next[entry].T1p = 1'b1;
            default: ;
          endcase

          case (RS_in[i].opb_select)
            OPB_IS_I_IMM,
            OPB_IS_U_IMM,
            OPB_IS_J_IMM: rs_next[entry].T2p = 1'b1;
            default: ;
          endcase

          break;
        end
      end
    end
end



always_comb begin
/*////////////////////////////////////////
rs stall counter logic
*////////////////////////////////////////
next_usedEntries = 0;
  for(int i = 0; i < `RS_SZ; i++) begin
      if(rs[i].busy == 1'b1) begin
        next_usedEntries = next_usedEntries + 1;
      end
  end
end

assign NumFreeEntriesAfterIssue = `RS_SZ - next_usedEntries;


// Sequential logic for RS updates
always_ff @(posedge clock) begin
   if (reset) begin
        rs <='{default :'0};
        usedEntries <= '0;
    end else begin
        rs <= rs_next;
        usedEntries <= next_usedEntries;
    end
end


assign rs_dbg = rs;


endmodule