`include "sys_defs.svh"
`include "ISA.svh"
`timescale 1ns/1ps

module stage_ex_tb;

  // Define constants here
  localparam int CLOCK_PERIOD = 10;

  // Clock and reset
  logic                                  clock;
  logic                                  reset;

  // Input/Output Declarations
  ISSUE_PACKET        [`NUM_FU-1:0]      Ex_packet;  // Input to stage_ex
  logic               [3:0]              fu_ready;   // Output from stage_ex
  logic               [3:0]              C_ready;    // Output from stage_ex
  COMPLETE_PACKET     [`NUM_FU-1:0]      C_packet;   // Output from stage_ex

  // Instantiate the stage_ex
  stage_ex Dut (
      .Ex_packet(Ex_packet),

      .C_packet(C_packet)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Apply reset initially
  initial begin
    reset = 1;
    #50;
    reset = 0;
  end

  // Task to initialize ISSUE_PACKET
  task init_issue_packet(
    input int idx, logic valid, ALU_FUNC alu_func, MULT_FUNC mult_func, FUNC_UNIT op_sel, ADDR NPC, ADDR PC, 
    ALU_OPA_SELECT opa_select, ALU_OPB_SELECT opb_select, INST inst, logic [$clog2(`RS_SZ)-1:0] rs_idx, 
    logic [`PR_WIDTH-1:0] dest_reg_idx, DATA r1_value, DATA r2_value);
    Ex_packet[idx].valid = valid;
    Ex_packet[idx].alu_func = alu_func;
    Ex_packet[idx].mult_func = mult_func;
    Ex_packet[idx].op_sel = op_sel;
    Ex_packet[idx].NPC = NPC;
    Ex_packet[idx].PC = PC;
    Ex_packet[idx].opa_select = opa_select;
    Ex_packet[idx].opb_select = opb_select;
    Ex_packet[idx].inst = inst;
    Ex_packet[idx].rs_idx = rs_idx;
    Ex_packet[idx].dest_reg_idx = dest_reg_idx;
    Ex_packet[idx].r1_value = r1_value;
    Ex_packet[idx].r2_value = r2_value;
  endtask

  // Task to display complete packets
  task display_complete_packets;
      $display("Time: %0t ps | Complete Packet [%0d]: NPC: %h | PC: %h | target_pc: %h | dest_reg_idx: %h | result: %h | if_take_branch: %b | valid: %b",
        $time, ALU0, C_packet[ALU0].NPC, C_packet[ALU0].PC, C_packet[ALU0].target_pc, C_packet[ALU0].dest_reg_idx, C_packet[ALU0].result, C_packet[ALU0].if_take_branch, C_packet[ALU0].valid);
      $display("Time: %0t ps | Complete Packet [%0d]: NPC: %h | PC: %h | target_pc: %h | dest_reg_idx: %h | result: %h | if_take_branch: %b | valid: %b",
        $time, ALU1, C_packet[ALU1].NPC, C_packet[ALU1].PC, C_packet[ALU1].target_pc, C_packet[ALU1].dest_reg_idx, C_packet[ALU1].result, C_packet[ALU1].if_take_branch, C_packet[ALU1].valid);
      $display("Time: %0t ps | Complete Packet [%0d]: NPC: %h | PC: %h | target_pc: %h | dest_reg_idx: %h | result: %h | if_take_branch: %b | valid: %b",
        $time, MULT, C_packet[MULT].NPC, C_packet[MULT].PC, C_packet[MULT].target_pc, C_packet[MULT].dest_reg_idx, C_packet[MULT].result, C_packet[MULT].if_take_branch, C_packet[MULT].valid);
      $display("Time: %0t ps | Complete Packet [%0d]: NPC: %h | PC: %h | target_pc: %h | dest_reg_idx: %h | result: %h | if_take_branch: %b | valid: %b",
        $time, BRANCH, C_packet[BRANCH].NPC, C_packet[BRANCH].PC, C_packet[BRANCH].target_pc, C_packet[BRANCH].dest_reg_idx, C_packet[BRANCH].result, C_packet[BRANCH].if_take_branch, C_packet[BRANCH].valid);
  endtask


  // Test procedure
  initial begin
    $monitor("Time: %0t | fu_ready: %b | C_ready: %b", $time, fu_ready, C_ready);

    reset = 1;
    repeat(2) @(posedge clock);
    reset = 0;

    // Test case 1: ALU operation
    init_issue_packet(0, 1, ALU_ADD, 0, ALU0, 32'h8, 32'h4, OPA_IS_RS1, OPB_IS_RS2, 32'h00000000, 0, 5, 32'hA, 32'h5);

    // Test case 2: Branch operation (BEQ)
    // Here, we're testing BEQ with rs1_value equal to rs2_value, expecting the branch to be taken.
    init_issue_packet(3, 1, ALU_FUNC'(3'b000), 0, BRANCH, 32'hC, 32'h8, OPA_IS_RS1, OPB_IS_RS2, 32'h00000001, 1, 11, 32'h8, 32'h8);
    
    repeat(4) @(posedge clock);

    // Check and display results
    display_complete_packets();

    // Additional test cases can be added here
    
    // End of simulation
    $finish;
  end

endmodule
