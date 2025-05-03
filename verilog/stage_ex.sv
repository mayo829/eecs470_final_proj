/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  stage_ex.sv                                         //
//                                                                     //
//  Description :  instruction execute (EX) stage of the pipeline;     //
//                 given the instruction command code CMD, select the  //
//                 proper input A and B for the ALU, compute the       //
//                 result, and compute the condition for branches, and //
//                 pass all the results down the pipeline.             //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`include "ISA.svh"

// ALU: computes the result of FUNC applied with operands A and B
// This module is purely combinational
module alu (
    input          valid,
    input DATA     opa,
    input DATA     opb,
    input ALU_FUNC alu_func,

    output DATA result
);

    always_comb begin
        if (valid) begin
            case (alu_func)
                ALU_ADD:  result = opa + opb;
                ALU_SUB:  result = opa - opb;
                ALU_AND:  result = opa & opb;
                ALU_SLT:  result = signed'(opa) < signed'(opb);
                ALU_SLTU: result = opa < opb;
                ALU_OR:   result = opa | opb;
                ALU_XOR:  result = opa ^ opb;
                ALU_SRL:  result = opa >> opb[4:0];
                ALU_SLL:  result = opa << opb[4:0];
                ALU_SRA:  result = signed'(opa) >>> opb[4:0]; // arithmetic from logical shift
                // here to prevent latches:
                default:  result = 32'h00000000;
            endcase
        end else begin
            result = 32'hfaceface;
        end
    end

endmodule // alu

// Conditional branch module: compute whether to take conditional branches
// This module is purely combinational
module conditional_branch (
    input       valid,
    input DATA  rs1,
    input DATA  rs2,
    input [2:0] func, // Which branch condition to check

    output logic take // True/False condition result
);
    
    always_comb begin
        take = `FALSE;
        if (valid) begin
            case (func)
                3'b000:  take = signed'(rs1) == signed'(rs2); // BEQ
                3'b001:  take = signed'(rs1) != signed'(rs2); // BNE
                3'b100:  take = signed'(rs1) <  signed'(rs2); // BLT
                3'b101:  take = signed'(rs1) >= signed'(rs2); // BGE
                3'b110:  take = rs1 < rs2;                    // BLTU
                3'b111:  take = rs1 >= rs2;                   // BGEU
                default: take = `FALSE;
            endcase
        end else begin
            take = `FALSE;
        end
    end

endmodule // conditional_branch

module mult_pipeline (
    input clock, reset, start, valid, stall,
    input DATA rs1, rs2,
    input ISSUE_PACKET ex_packet_in,
    input MULT_FUNC func,

    output DATA result,
    output ISSUE_PACKET ex_packet_out,
    output done
);

    logic        [`MULT_STAGES-2:0]          internal_dones;
    ISSUE_PACKET [`MULT_STAGES-2:0]          internal_ex_packets;
    logic        [(64*(`MULT_STAGES-1))-1:0] internal_product_sums, internal_mcands, internal_mpliers;
    logic        [63:0]                      mcand_out, mplier_out;
    logic        [63:0]                      mcand, mplier, product;
    logic        [`MULT_STAGES-1:0]          internal_stalls;

    assign internal_stalls = {`MULT_STAGES{stall}};

    always_comb begin
        mcand  = 0;
        mplier = 0;
        if (valid) begin
            case (func)
                M_MUL, M_MULH, M_MULHSU: mcand  = {{(32){rs1[31]}}, rs1};
                default:                 mcand  = {32'b0, rs1};
            endcase
            case (func)
                M_MUL, M_MULH:           mplier = {{(32){rs2[31]}}, rs2};
                default:                 mplier = {32'b0, rs2};
            endcase
        end else begin
            mcand  = 0;
            mplier = 0;
        end
    end

    DATA internal_result;
    always_comb begin
        case (ex_packet_out.mult_func)
            M_MUL:     internal_result = product[31:0];
            M_MULH:    internal_result = signed'(product[63:32]);
            M_MULHSU:  internal_result = signed'(product[63:32]);
            M_MULHU:   internal_result = product[63:32];
            default:   internal_result = 32'hDEADBEEF;
        endcase
    end

    assign result = internal_result;

    mult_stage mstage [`MULT_STAGES-1:0] (
        .clock         (clock),
        .reset         (reset),
        .stall         (internal_stalls),
        .ex_packet_in  ({internal_ex_packets, ex_packet_in}),
        .ex_packet_out ({ex_packet_out, internal_ex_packets}),
        .start         ({internal_dones,        start}),
        .prev_sum      ({internal_product_sums, 64'h0}),
        .mplier        ({internal_mpliers,      mplier}),
        .mcand         ({internal_mcands,       mcand}),
        .product_sum   ({product,    internal_product_sums}),
        .next_mplier   ({mplier_out, internal_mpliers}),
        .next_mcand    ({mcand_out,  internal_mcands}),
        .done          ({done,       internal_dones})
    );

endmodule


module mult_stage (
    input clock, reset, start, stall,
    input [63:0] prev_sum, mplier, mcand,
    input ISSUE_PACKET ex_packet_in,

    output logic [63:0] product_sum, next_mplier, next_mcand,
    output ISSUE_PACKET ex_packet_out,
    output logic done
);

    parameter SHIFT = 64/`MULT_STAGES;

    logic [63:0] partial_product, shifted_mplier, shifted_mcand;

    assign partial_product = mplier[SHIFT-1:0] * mcand;

    assign shifted_mplier = {SHIFT'('b0), mplier[63:SHIFT]};
    assign shifted_mcand = {mcand[63-SHIFT:0], SHIFT'('b0)};

    always_ff @(posedge clock) begin
        if(reset) begin
            product_sum <= '0;
            next_mplier <= '0;
            next_mcand  <= '0;

        end if (!stall) begin
            product_sum <= prev_sum + partial_product;
            next_mplier <= shifted_mplier;
            next_mcand  <= shifted_mcand;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            done <= 1'b0;
            ex_packet_out <= '{default: '0};
        end else if (!stall) begin
            done <= start;
            ex_packet_out <= ex_packet_in;
        end
    end

endmodule

//purely combinational
module stage_ex (
    input  logic clock, reset, stall,
    input  ISSUE_PACKET    [`NUM_FU-1:0] Ex_packet, // this from fifo issue this will also hold data to retire rs entry
    
    output COMPLETE_PACKET [`NUM_FU-1:0] C_packet,


    input MEM_BLOCK                      dcache2load_data_out,    // Data is mem[proc2Icache_addr]
    input logic                          dcache2load_valid_out,    // When valid is high

    output ADDR                          load2Dcache_addr,   // Address sent to Data memory
    output logic                         load2Dcache_valid,

    output logic                         ld_read_en,

    output logic                         functional_req_ld
);

    ISSUE_PACKET mult_packet_out;
    DATA  alu0_result; 
    DATA  alu1_result; 
	DATA  mult_result; 
	DATA  [1:0] opa_mux_out; 
	DATA  [1:0] opb_mux_out;
    logic take_conditional;


    // ALU opA mux
    always_comb begin
        case (Ex_packet[int'(ALU0)].opa_select)
            OPA_IS_RS1:  opa_mux_out[int'(ALU0)] = Ex_packet[int'(ALU0)].r1_value;
            OPA_IS_NPC:  opa_mux_out[int'(ALU0)] = Ex_packet[int'(ALU0)].NPC;
            OPA_IS_PC:   opa_mux_out[int'(ALU0)] = Ex_packet[int'(ALU0)].PC;
            OPA_IS_ZERO: opa_mux_out[int'(ALU0)] = 0;
            default:     opa_mux_out[int'(ALU0)] = 32'h00000000; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (Ex_packet[int'(ALU0)].opb_select)
            OPB_IS_RS2:   opb_mux_out[int'(ALU0)] = Ex_packet[int'(ALU0)].r2_value;
            OPB_IS_I_IMM: opb_mux_out[int'(ALU0)] = `RV32_signext_Iimm(Ex_packet[int'(ALU0)].inst);
            OPB_IS_S_IMM: opb_mux_out[int'(ALU0)] = `RV32_signext_Simm(Ex_packet[int'(ALU0)].inst);
            OPB_IS_B_IMM: opb_mux_out[int'(ALU0)] = `RV32_signext_Bimm(Ex_packet[int'(ALU0)].inst);
            OPB_IS_U_IMM: opb_mux_out[int'(ALU0)] = `RV32_signext_Uimm(Ex_packet[int'(ALU0)].inst);
            OPB_IS_J_IMM: opb_mux_out[int'(ALU0)] = `RV32_signext_Jimm(Ex_packet[int'(ALU0)].inst);
            default:      opb_mux_out[int'(ALU0)] = 32'h00000000; // face feed
        endcase
    end

    // Instantiate the ALU
    alu alu_0 (
        // Inputs
        .valid    (Ex_packet[int'(ALU0)].valid),
        .opa      (opa_mux_out[int'(ALU0)]),
        .opb      (opb_mux_out[int'(ALU0)]),
        .alu_func (Ex_packet[int'(ALU0)].alu_func),
        // Output
        .result   (alu0_result)
    );

    always_comb begin
        C_packet[int'(ALU0)].valid           = Ex_packet[int'(ALU0)].valid;
        C_packet[int'(ALU0)].NPC             = Ex_packet[int'(ALU0)].NPC;
        C_packet[int'(ALU0)].PC              = Ex_packet[int'(ALU0)].PC;
        C_packet[int'(ALU0)].dest_reg_idx    = Ex_packet[int'(ALU0)].dest_reg_idx;
        C_packet[int'(ALU0)].rob_ptr         = Ex_packet[int'(ALU0)].rob_ptr;
        C_packet[int'(ALU0)].result          = alu0_result;
        C_packet[int'(ALU0)].if_take_branch  = '0;
        C_packet[int'(ALU0)].is_branch       = 1'b0;
    //         if (Ex_packet[int'(ALU0)].valid) begin
    //     $display("[EX] int'(ALU0) EXEC: valid=%0b inst=0x%08x PC=0x%08x TD=%0d → result=0x%08x",
    //              Ex_packet[int'(ALU0)].valid,
    //              Ex_packet[int'(ALU0)].inst, Ex_packet[int'(ALU0)].PC,
    //              Ex_packet[int'(ALU0)].dest_reg_idx, alu0_result);
    // end
    end

    // ALU opA mux
    always_comb begin
        case (Ex_packet[int'(ALU1)].opa_select)
            OPA_IS_RS1:  opa_mux_out[int'(ALU1)] = Ex_packet[int'(ALU1)].r1_value;
            OPA_IS_NPC:  opa_mux_out[int'(ALU1)] = Ex_packet[int'(ALU1)].NPC;
            OPA_IS_PC:   opa_mux_out[int'(ALU1)] = Ex_packet[int'(ALU1)].PC;
            OPA_IS_ZERO: opa_mux_out[int'(ALU1)] = 0;
            default:     opa_mux_out[int'(ALU1)] = 32'h00000000; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (Ex_packet[int'(ALU1)].opb_select)
            OPB_IS_RS2:   opb_mux_out[int'(ALU1)] = Ex_packet[int'(ALU1)].r2_value;
            OPB_IS_I_IMM: opb_mux_out[int'(ALU1)] = `RV32_signext_Iimm(Ex_packet[int'(ALU1)].inst);
            OPB_IS_S_IMM: opb_mux_out[int'(ALU1)] = `RV32_signext_Simm(Ex_packet[int'(ALU1)].inst);
            OPB_IS_B_IMM: opb_mux_out[int'(ALU1)] = `RV32_signext_Bimm(Ex_packet[int'(ALU1)].inst);
            OPB_IS_U_IMM: opb_mux_out[int'(ALU1)] = `RV32_signext_Uimm(Ex_packet[int'(ALU1)].inst);
            OPB_IS_J_IMM: opb_mux_out[int'(ALU1)] = `RV32_signext_Jimm(Ex_packet[int'(ALU1)].inst);
            default:      opb_mux_out[int'(ALU1)] = 32'h00000000; // face feed
        endcase
    end

        // Instantiate the ALU
    alu alu_1 (
        // Inputs
        .valid    (Ex_packet[int'(ALU1)].valid),
        .opa      (opa_mux_out[int'(ALU1)]),
        .opb      (opb_mux_out[int'(ALU1)]),
        .alu_func (Ex_packet[int'(ALU1)].alu_func),
        // Output  
        .result   (alu1_result)
    );

    always_comb begin
        C_packet[int'(ALU1)].valid              = Ex_packet[int'(ALU1)].valid;
        C_packet[int'(ALU1)].NPC                = Ex_packet[int'(ALU1)].NPC;
        C_packet[int'(ALU1)].PC                 = Ex_packet[int'(ALU1)].PC;
        C_packet[int'(ALU1)].dest_reg_idx       = Ex_packet[int'(ALU1)].dest_reg_idx;
        C_packet[int'(ALU1)].rob_ptr            = Ex_packet[int'(ALU1)].rob_ptr;
        C_packet[int'(ALU1)].result             = alu1_result;
        C_packet[int'(ALU1)].if_take_branch     = '0;
        C_packet[int'(ALU1)].is_branch          = 1'b0;
    //         if (Ex_packet[int'(ALU1)].valid) begin
    //     $display("[EX] int'(ALU1) EXEC: inst=0x%08x PC=0x%08x TD=%0d → result=0x%08x",
    //              Ex_packet[int'(ALU1)].inst, Ex_packet[int'(ALU1)].PC,
    //              Ex_packet[int'(ALU1)].dest_reg_idx, alu1_result);
    // end
    end


    // Instantiate the multiplier
    mult_pipeline mult_0 (
        .clock         (clock),
        .reset         (reset),
        .stall         (stall),
        .valid         (Ex_packet[MULT].valid),
        .rs1           (Ex_packet[MULT].r1_value),
        .rs2           (Ex_packet[MULT].r2_value),
        .ex_packet_in  (Ex_packet[MULT]),
        .ex_packet_out (mult_packet_out),
        .func          (Ex_packet[MULT].mult_func),
        .start         (Ex_packet[MULT].valid),
        .result        (mult_result),
        .done          (C_packet[MULT].valid)
    );

    always_comb begin
        // C_packet[MULT].valid        = Ex_packet[MULT].valid;
        C_packet[MULT].NPC              = mult_packet_out.NPC;
        C_packet[MULT].PC               = mult_packet_out.PC;
        C_packet[MULT].dest_reg_idx     = mult_packet_out.dest_reg_idx;
        C_packet[MULT].rob_ptr          = mult_packet_out.rob_ptr;
        C_packet[MULT].result           = mult_result;
        C_packet[MULT].if_take_branch   = '0;
    end

    // Instantiate the conditional branch module
    conditional_branch conditional_branch_0 (
        // Inputs
        .valid    (Ex_packet[int'(BRANCH)].valid),
        .rs1      (Ex_packet[int'(BRANCH)].r1_value),
        .rs2      (Ex_packet[int'(BRANCH)].r2_value),
        .func     (Ex_packet[int'(BRANCH)].inst.b.funct3), // Which branch condition to check
        // Output
        .take     (take_conditional)
    );
    

    always_comb begin
        C_packet[int'(BRANCH)].if_take_branch   = '0;
        C_packet[int'(BRANCH)].is_branch        = '0;
        C_packet[int'(BRANCH)].valid            = Ex_packet[int'(BRANCH)].valid;
        C_packet[int'(BRANCH)].NPC              = Ex_packet[int'(BRANCH)].NPC;
        C_packet[int'(BRANCH)].PC               = Ex_packet[int'(BRANCH)].PC;
        C_packet[int'(BRANCH)].dest_reg_idx     = Ex_packet[int'(BRANCH)].dest_reg_idx;
        C_packet[int'(BRANCH)].rob_ptr          = Ex_packet[int'(BRANCH)].rob_ptr;

        if(Ex_packet[int'(BRANCH)].inst[6:0] == `RV32_JALR_OP) begin
        C_packet[int'(BRANCH)].if_take_branch   = '1;
        C_packet[int'(BRANCH)].is_branch        = '0;
        end else if (Ex_packet[int'(BRANCH)].inst[6:0] == `RV32_BRANCH) begin
        C_packet[int'(BRANCH)].if_take_branch = take_conditional;
        C_packet[int'(BRANCH)].is_branch        = '1;
        end


        C_packet[int'(BRANCH)].target_pc = Ex_packet[int'(BRANCH)].NPC;
        C_packet[int'(BRANCH)].result    = '0;

        if (take_conditional && Ex_packet[3].inst[6:0] != `RV32_JAL_OP  && Ex_packet[3].inst[6:0] != `RV32_JALR_OP) begin

            C_packet[int'(BRANCH)].target_pc = Ex_packet[int'(BRANCH)].PC + `RV32_signext_Bimm(Ex_packet[int'(BRANCH)].inst);

        end else if (Ex_packet[int'(BRANCH)].inst[6:0] == `RV32_JAL_OP) begin
            
            C_packet[int'(BRANCH)].target_pc = Ex_packet[int'(BRANCH)].PC + `RV32_signext_Jimm(Ex_packet[int'(BRANCH)].inst);
            C_packet[int'(BRANCH)].result    = Ex_packet[int'(BRANCH)].NPC;

        end else if (Ex_packet[int'(BRANCH)].inst[6:0] == `RV32_JALR_OP) begin

            C_packet[int'(BRANCH)].target_pc = Ex_packet[int'(BRANCH)].r1_value + `RV32_signext_Iimm(Ex_packet[int'(BRANCH)].inst);
            C_packet[int'(BRANCH)].result    = Ex_packet[int'(BRANCH)].NPC;

        end 
    end



    // I think I can use misprediction here, and have that. I can assign it to be if C_packet[int'(BRANCH)].target_pc != the BP's pc, then we have a misprediction. I'm pretty sure the if statement right above this calculates the right pc based on the branch.
    // Need to make pred_pc

    //load instantiation 

    // MEM_BLOCK   dcache2load_data_out;
    // logic       dcache2load_valid_out;

    // ADDR        load2Dcache_addr;
    // logic       load2Dcache_valid;


    load load_unit (
        // Inputs
        .clock    (clock),
        .reset    (reset),
        .Ex_packet(Ex_packet[int'(LS)]),
        .C_packet(C_packet[int'(LS)]),

        // .sq_result(),
        // .load2SQ_pkt(),

        .Dcache_data_in(dcache2load_data_out),
        .Dcache_valid_in(dcache2load_valid_out),

        .proc2Dcache_addr(load2Dcache_addr),
        .load2Dcache_valid(load2Dcache_valid),

        .arbitrateOnThis(),
        
        .ld_read_en(ld_read_en),
        .functional_req_ld(functional_req_ld)
    );
    


endmodule 