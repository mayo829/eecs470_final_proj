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
    input DATA     opa,
    input DATA     opb,
    input ALU_FUNC alu_func,

    output DATA result
);

    always_comb begin
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
            default:  result = 32'hfacebeec;
        endcase
    end

endmodule // alu

// Conditional branch module: compute whether to take conditional branches
// This module is purely combinational
module conditional_branch (
    input DATA  rs1,
    input DATA  rs2,
    input [2:0] func, // Which branch condition to check

    output logic take // True/False condition result
);

    always_comb begin
        case (func)
            3'b000:  take = signed'(rs1) == signed'(rs2); // BEQ
            3'b001:  take = signed'(rs1) != signed'(rs2); // BNE
            3'b100:  take = signed'(rs1) <  signed'(rs2); // BLT
            3'b101:  take = signed'(rs1) >= signed'(rs2); // BGE
            3'b110:  take = rs1 < rs2;                    // BLTU
            3'b111:  take = rs1 >= rs2;                   // BGEU
            default: take = `FALSE;
        endcase
    end

endmodule // conditional_branch

module mult_no_pipeline (
    input clock, reset, start,
    input DATA rs1, rs2,
    input MULT_FUNC func,

    output DATA  result,
    output logic done
);

    logic [63:0] mcand, mplier, product;

    assign product = mcand * mplier;

    // Sign-extend the multiplier inputs based on the operation
    always_comb begin
        case (func)
            M_MUL, M_MULH, M_MULHSU: mcand = {{(32){rs1[31]}}, rs1};
            default:                 mcand = {32'b0, rs1};
        endcase
        case (func)
            M_MUL, M_MULH: mplier = {{(32){rs2[31]}}, rs2};
            default:       mplier = {32'b0, rs2};
        endcase
    end

    // Use the high or low bits of the product based on the output func
    assign result = (func == M_MUL) ? product[31:0] : product[63:32];

endmodule


//purely combinational
module stage_ex (
	input                     			 clock,
	input                     			 reset,
	// TODO needs to be able to stall from complete as a input
	input  [3:0]               			 complete_stall, 
    input  ISSUE_PACKET [`SCALAR-1:0]    Ex_packet, // this from fifo issue this will also hold data to retire rs entry
	output [3:0]           				 fu_ready,
	output [3:0]           				 C_ready,
    output COMPLETE_PACKET [`SCALAR-1:0] C_packet
);
	typedef struct packed{
		logic 				            valid;
		ALU_FUNC                        alu_func;
		logic                           mult;       // Is inst a multiply instruction?
		FUNC_UNIT			            op_sel;
		ADDR                            NPC;        // PC + 4
		ADDR                            PC;         // PC
		ALU_OPA_SELECT                  opa_select; // ALU opa mux select (ALU_OPA_xxx *)
		ALU_OPB_SELECT                  opb_select; // ALU opb mux select (ALU_OPB_xxx *)
		INST          		            inst;
		logic [$clog2(`ROB_SZ)-1:0]	    rob_idx; // this needs to be checked later 
		logic [$clog2(`RS_SZ)-1:0]	    rs_idx;  // this needs to be checked later
		logic [`PR_WIDTH-1:0] 	        dest_reg_idx;
		DATA	                        r1_value;
		DATA 	                        r2_value;
	} ISSUE_PACKET;

	typedef struct packed{
		logic                 if_take_branch;
		logic                 valid;
		ADDR                  NPC;   // PC + 4
		ADDR                  PC;    // PC
		ADDR                  target_pc;
		logic [`PR_WIDTH-1:0] dest_reg_idx;
		DATA                  result;
		logic [`ROB_SZ-1:0]   rob_idx;
	} COMPLETE_PACKET;


    DATA alu_result; 
	DATA mult_result; 
	DATA opa_mux_out; 
	DATA opb_mux_out;
    logic take_conditional;

    // ALU opA mux
    always_comb begin
		for (int i = 0; i < `SCALAR; i++) begin
			case (Ex_packet[i].opa_select)
				OPA_IS_RS1:  opa_mux_out = Ex_packet[i].r1_value;
				OPA_IS_NPC:  opa_mux_out = Ex_packet[i].NPC;
				OPA_IS_PC:   opa_mux_out = Ex_packet[i].PC;
				OPA_IS_ZERO: opa_mux_out = 0;
				default:     opa_mux_out = 32'hdeadface; // dead face
			endcase
		end
    end

    // ALU opB mux
    always_comb begin
		for (int i = 0; i < `SCALAR; i++) begin
			case (Ex_packet[i].opb_select)
				OPB_IS_RS2:   opb_mux_out = Ex_packet[i].r2_value;
				OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(Ex_packet[i].inst);
				OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(Ex_packet[i].inst);
				OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(Ex_packet[i].inst);
				OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(Ex_packet[i].inst);
				OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(Ex_packet[i].inst);
				default:      opb_mux_out = 32'hfacefeed; // face feed
			endcase
		end
    end

    // Instantiate the ALU
    alu alu_0 (
        // Inputs
        .opa(Ex_packet[0].opa_select),
        .opb(Ex_packet[0].opb_select),
        .alu_func(Ex_packet[0].alu_func),
		// TODO ADD COMPLETE_STALL
        // Output
        .result(Ex_packet[0].result)
    );

    // Instantiate the multiplier
    mult_no_pipeline mult_0 (
        // Inputs
        .rs1(Ex_packet[1].rs1_value),
        .rs2(Ex_packet[1].rs2_value),
        .func(Ex_packet[1].inst.r.funct3), // which mult operation to perform
		// TODO ADD COMPLETE_STALL
        // Output
        .result(Ex_packet[1].result)
    );

    // Instantiate the conditional branch module
    conditional_branch conditional_branch_0 (
        // Inputs
        .rs1(Ex_packet[3].rs1_value),
        .rs2(Ex_packet[3].rs2_value),
        .func(Ex_packet[3].inst.b.funct3), // Which branch condition to check
		// TODO ADD COMPLETE_STALL
        // Output
        .take(Ex_packet[3].if_take_branch)
    );

endmodule // sta
