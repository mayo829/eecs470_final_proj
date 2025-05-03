/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  stage_if.sv                                         //
//                                                                     //
//  Description :  instruction fetch (IF) stage of the pipeline;       //
//                 fetch instruction, compute next PC location, and    //
//                 send them down the pipeline.                        //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

module stage_if (
    input           clock,          // system clock
    input           reset,          // system reset
    input           if_valid,       // only go to next PC when true
    input           BP_Prediction,    // taken-branch signal from prediction

    input ADDR      correct_pc,  // Correct PC if mispredict
    input MEM_BLOCK Imem_data,      // data coming back from Instruction memory
    input           ib_full,

    // tags from memory
    input MEM_TAG   Imem2proc_transaction_tag, // Should be zero unless there is a response
    input MEM_TAG   Imem2proc_data_tag,

    input           misprediction,

    input logic     jalr_resolved,

    output MEM_COMMAND  Imem_command, // Command sent to memory
    output FETCH_DISPATCH_PACKET [`N-1:0] if_packet,
    output ADDR         Imem_addr // address sent to Instruction memory
);

    ADDR      PC_reg; // PC we are currently fetching
    // ADDR      PC_copy;
    MEM_BLOCK icache_out;
    logic     icache_valid;
    logic     valid_out;


    // logic     branch_stall;
    // logic     branch_stall_q;
    logic     b_seen;
    logic     j_seen;
    logic     if_valid_q;

    logic [31:0]    branch_target;
    logic if_packet_0_has_branch;
    logic if_cache_0_has_branch; 

    logic [1:0] target_change_0;
    logic jalr_seen;
    logic jalr_stall;

    icache icache_0 (
        // inputs
        .clock                      (clock),
        .reset                      (reset),
        .Imem2proc_transaction_tag  (Imem2proc_transaction_tag),
        .Imem2proc_data             (Imem_data),
        .Imem2proc_data_tag         (Imem2proc_data_tag),
        .proc2Icache_addr           (PC_reg),
        // outputs
        .proc2Imem_command          (Imem_command),
        .proc2Imem_addr             (Imem_addr),
        .Icache_data_out            (icache_out), // Data is mem[proc2Icache_addr]
        .Icache_valid_out           (icache_valid), // When valid is high
        .misprediction              (misprediction)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            jalr_stall <= 1'b0;
        end else if (jalr_resolved || misprediction) begin
            jalr_stall <= 1'b0;
        end else if (valid_out && jalr_seen) begin
            jalr_stall <= 1'b1;
        end
    end


    always_ff @(posedge clock) begin
        if (reset) begin
            PC_reg <= '0;             // initial PC value is 0 (the memory address where our program starts)
        end else if (misprediction || jalr_resolved) begin
            PC_reg <= correct_pc;
        end else if (jalr_stall | ib_full) begin
            PC_reg <= PC_reg;
        end else if (valid_out && ((b_seen && BP_Prediction) || j_seen)) begin
            PC_reg <= branch_target; // update to a taken branch PC+4+offset
        end else if (valid_out) begin
            PC_reg <= PC_reg + (PC_reg[2] ? 4 : 8);
        end
    end


// add another else if, pass in "yo im a jalr coming from the retire stage (in cpu.sv)"
// set PC_reg equal to the branch target that is being passed in NOT THE BRANCH TARGET 
// THAT YOU CALCULATED HERE, it should be "correct_pc"


    // Keep if valid until it gets valid data out
    always_ff @(posedge clock) begin
        if (reset) begin
            if_valid_q <= 1'b0;
        end else begin
            if_valid_q <= if_valid || (if_valid_q && !valid_out);
        end
    end

    // If we have a branch and it is taken, we need to update the PC, else we operate like normal (pc + 4) AB or BA
always_comb begin
    branch_target = '0;
    target_change_0 = 2'b10; // default = no branch/jump


    if (!valid_out) begin
        // Do nothing
    end else if (PC_reg[2] == 1'b0) begin
        // Aligned fetch (fetching both word 0 and word 1)
        if (icache_out.word_level[0][6:0] == `RV32_BRANCH && BP_Prediction) begin
            branch_target = PC_reg + `RV32_signext_Bimm(icache_out.word_level[0]);
            target_change_0 = 2'b00;
        end else if (icache_out.word_level[0][6:0] == `RV32_JAL_OP) begin
            branch_target = PC_reg + `RV32_signext_Jimm(icache_out.word_level[0]);
            target_change_0 = 2'b00;
        end else if (icache_out.word_level[1][6:0] == `RV32_BRANCH && BP_Prediction) begin
            branch_target = PC_reg + 4 + `RV32_signext_Bimm(icache_out.word_level[1]); // 💡 offset from upper word
            target_change_0 = 2'b01;
        end else if (icache_out.word_level[1][6:0] == `RV32_JAL_OP) begin
            branch_target = PC_reg + 4 + `RV32_signext_Jimm(icache_out.word_level[1]); // 💡 offset from upper word
            target_change_0 = 2'b01;
        end
    end else begin
        // Unaligned fetch (only fetching upper word)
        if (icache_out.word_level[1][6:0] == `RV32_BRANCH && BP_Prediction) begin
            branch_target = PC_reg + `RV32_signext_Bimm(icache_out.word_level[1]);
            target_change_0 = 2'b01;
        end else if (icache_out.word_level[1][6:0] == `RV32_JAL_OP) begin
            branch_target = PC_reg + `RV32_signext_Jimm(icache_out.word_level[1]);
            target_change_0 = 2'b01;
        end
    end
end

    // 

    assign valid_out = icache_valid && if_valid_q;
    

    // Be seen if branch is seen from icache or something
    //assign j_seen =  (icache_out.word_level[0][6:0] == `RV32_JAL_OP || icache_out.word_level[1][6:0] == `RV32_JAL_OP);
    //assign b_seen = (icache_out.word_level[0][6:0] == `RV32_BRANCH || icache_out.word_level[1][6:0] == `RV32_BRANCH);

    assign b_seen = (PC_reg[2] == 1'b0) ? (icache_out.word_level[0][6:0] == `RV32_BRANCH || icache_out.word_level[1][6:0] == `RV32_BRANCH) : (icache_out.word_level[1][6:0] == `RV32_BRANCH);

    assign j_seen = (PC_reg[2] == 1'b0) ? (icache_out.word_level[0][6:0] == `RV32_JAL_OP || icache_out.word_level[1][6:0] == `RV32_JAL_OP) : (icache_out.word_level[1][6:0] == `RV32_JAL_OP) ;


    //from here
    assign jalr_seen = (PC_reg[2] == 1'b0) ? (icache_out.word_level[0][6:0] == `RV32_JALR_OP && if_packet[0].valid)
     || (icache_out.word_level[1][6:0] == `RV32_JALR_OP && if_packet[1].valid) : (icache_out.word_level[1][6:0] == `RV32_JALR_OP);

    assign if_packet[0].inst  = (valid_out && !PC_reg[2]) ? icache_out.word_level[0] : (valid_out && PC_reg[2]) ? icache_out.word_level[1] : `NOP;
    assign if_packet[0].PC    = PC_reg;
    assign if_packet[0].NPC   = PC_reg + 4; // do we add 4 
    assign if_packet[0].valid = (jalr_stall || ib_full) ? 1'b0 : (valid_out && !PC_reg[2]) ? '1 : (valid_out && PC_reg[2]) ? '1 : '0;

    assign if_packet[0].SPEC_PC = ((if_packet[0].inst[6:0] == `RV32_JAL_OP))  ? if_packet[0].PC + `RV32_signext_Jimm(if_packet[0].inst) :
    ((if_packet[0].inst[6:0] == `RV32_BRANCH) && b_seen && BP_Prediction)  ? if_packet[0].PC + `RV32_signext_Bimm(if_packet[0].inst) : PC_reg + 4; // do we add 4 in this case?

    // Only fetch second instruction if:
    // - valid_out is true
    // - PC_reg[2] is 0 (aligned)
    // - branch_stall_q is not asserted    
    assign if_packet[1].inst  = (valid_out  && !PC_reg[2]) ? icache_out.word_level[1] : `NOP;
    assign if_packet[1].PC    = if_packet[0].PC + 4;
    assign if_packet[1].NPC   = if_packet[0].NPC + 4;


    assign if_packet[1].valid = (jalr_stall || ib_full) ? 1'b0 : (((if_packet[0].inst[6:0] == `RV32_BRANCH) && BP_Prediction) || (if_packet[0].inst[6:0] == `RV32_JAL_OP) || (if_packet[0].inst[6:0] == `RV32_JALR_OP) ? 1'b0 : (valid_out  && !PC_reg[2])); //maybe bug here
    
    //assign if_packet[1].valid = (jalr_stall) ? 1'b0 : (((if_packet[0].inst[6:0] == `RV32_BRANCH) && BP_Prediction) || (if_packet[0].inst[6:0] == `RV32_JAL_OP) || (if_packet[0].inst[6:0] == `RV32_JALR_OP)) ? 1'b0 : (valid_out && !PC_reg[2]) ? 1'b1 : 1'b0; //maybe bug here

    assign if_packet_0_has_branch = (if_packet[0].inst[6:0] == `RV32_BRANCH);
    assign if_cache_0_has_branch = (icache_out.word_level[0][6:0] == `RV32_BRANCH);

    assign if_packet[1].SPEC_PC = ((if_packet[1].inst[6:0] == `RV32_JAL_OP) && if_packet[1].valid) ? if_packet[1].PC + `RV32_signext_Jimm(if_packet[1].inst) :
    ((if_packet[1].inst[6:0] == `RV32_BRANCH) && if_packet[1].valid && BP_Prediction) ? if_packet[1].PC + `RV32_signext_Bimm(if_packet[1].inst) : if_packet[1].PC + 4;

    // Need to implement a rendition for Jalr (Don't know if this is right)
    // assign if_packet[1].valid = ((icache_out.word_level[0][6:0] == `RV32_JAL_OPR)) ? 1'b0 : (valid_out  && !PC_reg[2]);



endmodule // stage_if