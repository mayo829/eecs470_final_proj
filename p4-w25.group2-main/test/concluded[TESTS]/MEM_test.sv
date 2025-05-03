`timescale 1ns / 1ps
`include "sys_defs.svh"

module mem_fu_tb;

    // Clock and reset signals
    logic clock;
    logic reset;
    logic squash_in;

    // Inputs to mem_fu
    IS_EX_PACKET mem_packet_in;

    // Output from mem_fu
    EX_MEM_PACKET ex_mem_out;

    // Instantiate the DUT (Device Under Test)
    mem_fu dut (
        .clock(clock),
        .reset(reset),
        .squash_in(squash_in),
        .mem_packet_in(mem_packet_in),
        .ex_mem_out(ex_mem_out)
    );

    // Clock generation
    always #5 clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;
        squash_in = 0;

        // Initialize input packet
        mem_packet_in = '0;

        // Wait and release reset
        #10;
        reset = 0;

        // Test case 1: Load operation with I-immediate
        mem_packet_in.rs1_value = 32'h1000_0000;
        mem_packet_in.inst = '{ r: '{ funct3: 3'b010, imm: 12'h004, default: '0 }};
        mem_packet_in.opb_select = OPB_IS_I_IMM;
        mem_packet_in.rd_mem = 1;
        mem_packet_in.wr_mem = 0;
        mem_packet_in.valid = 1;

        #10;
        $display("Test 1: alu_result = %h (expected 0x10000004)", ex_mem_out.alu_result);

        // Test case 2: Store operation with S-immediate
        mem_packet_in.rs1_value = 32'h2000_0000;
        mem_packet_in.inst = '{ r: '{ funct3: 3'b010, imm: 12'h008, default: '0 }};
        mem_packet_in.opb_select = OPB_IS_S_IMM;
        mem_packet_in.rd_mem = 0;
        mem_packet_in.wr_mem = 1;
        mem_packet_in.rs2_value = 32'hDEADBEEF;
        mem_packet_in.valid = 1;

        #10;
        $display("Test 2: alu_result = %h (expected 0x20000008)", ex_mem_out.alu_result);

        // Test case 3: Pass-through without memory ops
        mem_packet_in.rs1_value = 32'h3000_0000;
        mem_packet_in.opb_select = OPB_IS_I_IMM;
        mem_packet_in.inst = '{ r: '{ funct3: 3'b000, imm: 12'h010, default: '0 }};
        mem_packet_in.rd_mem = 0;
        mem_packet_in.wr_mem = 0;
        mem_packet_in.valid = 1;

        #10;
        $display("Test 3: alu_result = %h (expected 0x30000010)", ex_mem_out.alu_result);

        // End simulation
        #10;
        $finish;
    end

endmodule
