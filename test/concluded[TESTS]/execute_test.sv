`timescale 1ns/1ps
`include "sys_defs.svh"

module stage_ex_tb;

    // Clock and reset signals
    logic clock;
    logic reset;

    // Pipeline packets
    ID_EX_PACKET id_ex_reg;
    EX_MEM_PACKET ex_packet;

    // Instantiate DUT
    stage_ex dut (
        .id_ex_reg(id_ex_reg),
        .ex_packet(ex_packet)
    );

    // Clock generation
    always begin
        #5 clock = ~clock;
    end

    // Test procedure
    initial begin
        clock = 0;
        reset = 1;

        // Initialize inputs
        id_ex_reg = '{
            NPC: 0,
            PC: 0,
            rs1_value: 0,
            rs2_value: 0,
            alu_func: ALU_ADD,
            opa_select: OPA_IS_RS1,
            opb_select: OPB_IS_RS2,
            cond_branch: 0,
            uncond_branch: 0,
            rd_mem: 0,
            wr_mem: 0,
            dest_reg_idx: 0,
            halt: 0,
            illegal: 0,
            csr_op: 0,
            valid: 0,
            inst: '{default:0}
        };

        // Apply reset
        #10 reset = 0;

        // Test Case 1: Basic ALU Operations
        $display("\n=== Testing Basic ALU Operations ===");
        test_alu(32'd5, 32'd3, ALU_ADD, 32'd8);
        test_alu(32'd10, 32'd4, ALU_SUB, 32'd6);
        test_alu(32'hF0, 32'h0F, ALU_AND, 32'h00);
        test_alu(32'hF0, 32'h0F, ALU_OR, 32'hFF);
        test_alu(32'hF0, 32'h0F, ALU_XOR, 32'hFF);
        test_alu(-32'd5, 32'd3, ALU_SLT, 32'd1);
        test_alu(32'd5, 32'd3, ALU_SLTU, 32'd0);

        // Test Case 2: Shift Operations
        $display("\n=== Testing Shift Operations ===");
        test_alu(32'h12345678, 32'd4, ALU_SLL, 32'h23456780);
        test_alu(32'h12345678, 32'd4, ALU_SRL, 32'h01234567);
        test_alu(32'hF2345678, 32'd4, ALU_SRA, 32'hFF234567);

        // Test Case 3: Multiplier Operations
        $display("\n=== Testing Multiplier Operations ===");
        test_mult(32'd6, 32'd7, M_MUL, 32'd42);
        test_mult(32'h80000000, 32'h80000000, M_MULH, 32'h40000000);
        test_mult(32'h80000000, 32'd2, M_MULHSU, 32'hFFFFFFFF);
        test_mult(32'hFFFFFFFF, 32'hFFFFFFFF, M_MULHU, 32'hFFFFFFFE);

        // Test Case 4: Branch Conditions
        $display("\n=== Testing Branch Conditions ===");
        test_branch(32'd5, 32'd5, 3'b000, 1'b1);  // BEQ
        test_branch(32'd5, 32'd3, 3'b001, 1'b1);  // BNE
        test_branch(-32'd5, 32'd3, 3'b100, 1'b1); // BLT
        test_branch(32'd5, 32'd3, 3'b101, 1'b1);  // BGE
        test_branch(32'hFFFFFFFF, 32'd1, 3'b110, 1'b1); // BLTU
        test_branch(32'd5, 32'd3, 3'b111, 1'b1);  // BGEU

        // Test Case 5: Operand Selection
        $display("\n=== Testing Operand Selection ===");
        test_operand_selection(OPA_IS_NPC, 32'h1000, OPB_IS_I_IMM, 32'h004, 32'h1004);
        test_operand_selection(OPA_IS_PC, 32'h2000, OPB_IS_U_IMM, 32'h3000, 32'h5000);

        // Finish simulation
        #100 $display("\nAll tests completed!");
        $finish;
    end

    // Test task for ALU operations
    task test_alu(input DATA a, b, input ALU_FUNC func, expected);
        begin
            id_ex_reg.opa_select = OPA_IS_RS1;
            id_ex_reg.opb_select = OPB_IS_RS2;
            id_ex_reg.rs1_value = a;
            id_ex_reg.rs2_value = b;
            id_ex_reg.alu_func = func;
            id_ex_reg.valid = 1;
            #10 check_result("ALU", ex_packet.alu_result, expected);
        end
    endtask

    // Test task for multiplier operations
   task test_mult(input DATA a, b, input MULT_FUNC func, input DATA expected);
        begin
            id_ex_reg.opa_select = OPA_IS_RS1;
            id_ex_reg.opb_select = OPB_IS_RS2;
            id_ex_reg.rs1_value = a;
            id_ex_reg.rs2_value = b;
            id_ex_reg.inst.r.funct3 = func;
            id_ex_reg.mult = 1;
            id_ex_reg.valid = 1;
            #10 check_result("MULT", ex_packet.alu_result, expected);
        end
    endtask

    // Test task for branch conditions
    task test_branch(input DATA a, b, input [2:0] func, expected);
        begin
            id_ex_reg.cond_branch = 1;
            id_ex_reg.rs1_value = a;
            id_ex_reg.rs2_value = b;
            id_ex_reg.inst.b.funct3 = func;
            id_ex_reg.valid = 1;
            #10 check_result("BRANCH", ex_packet.take_branch, expected);
        end
    endtask

    // Test task for operand selection
    task test_operand_selection(
        input ALU_OPA_SELECT opa_sel,
        input DATA opa_val,
        input ALU_OPB_SELECT opb_sel,
        input DATA opb_val,
        expected
    );
        begin
            id_ex_reg.opa_select = opa_sel;
            id_ex_reg.opb_select = opb_sel;
            id_ex_reg.PC = opa_val;  // For OPA_IS_PC
            id_ex_reg.NPC = opa_val; // For OPA_IS_NPC
            id_ex_reg.inst = get_imm_inst(opb_sel, opb_val);
            id_ex_reg.valid = 1;
            #10 check_result("OPERAND", ex_packet.alu_result, expected);
        end
    endtask

    // Helper function to create immediate instructions
    function INST get_imm_inst(input ALU_OPB_SELECT sel, DATA val);
        INST inst;
        case (sel)
            OPB_IS_I_IMM: inst.i.imm = val[11:0];
            OPB_IS_S_IMM: {inst.s.off, inst.s.set} = val[11:0];
            OPB_IS_B_IMM: {inst.b.of, inst.b.f, inst.s, inst.j.et} = val[12:1];
            OPB_IS_U_IMM: inst.u.imm = val[31:12];
            OPB_IS_J_IMM: {inst.j.of, inst.j.f, inst.j.s, inst.j.et} = val[20:1];
            default: inst = '0;
        endcase
        return inst;
    endfunction

    // Result checking routine
    task check_result(input string test_type, input DATA actual, expected);
        if (actual !== expected) begin
            $display("[%0t] %s TEST FAILED: Expected 0x%h, Got 0x%h",
                    $time, test_type, expected, actual);
        end
        else begin
            $display("[%0t] %s TEST PASSED: 0x%h", $time, test_type, actual);
        end
    endtask

endmodule