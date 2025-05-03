`include "sys_defs.svh"
`timescale 1ns/1ps

module load_tb;

  // Parameters
  parameter CLOCK_PERIOD = 10; // Clock period for simulation

  // Clock and reset
  logic clock;
  logic reset;

  // Inputs to the load module
  ISSUE_PACKET Ex_packet;
  SQ2LOAD_PACKET sq_result;
  MEM_BLOCK Dcache_data_in;
  logic Dcache_valid_in;

  // Outputs from the load module
  COMPLETE_PACKET C_packet;
  LOAD2SQ_PACKET load2SQ_pkt;
  ADDR proc2Dcache_addr;

  // Instantiate the load module
  load uut (
    .clock(clock),
    .reset(reset),
    .Ex_packet(Ex_packet),
    .C_packet(C_packet),
    .sq_result(sq_result),
    .load2SQ_pkt(load2SQ_pkt),
    .Dcache_data_in(Dcache_data_in),
    .Dcache_valid_in(Dcache_valid_in),
    .proc2Dcache_addr(proc2Dcache_addr)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Initial setup for signals
  initial begin
    reset = 1;
    Ex_packet = '{default: '0};
    sq_result = '{default: '0};
    Dcache_data_in = '0;
    Dcache_valid_in = 0;
    #100;
    reset = 0; // Release reset after some time
  end

// Modify this segment to provide more detailed timing between operations
// and observe if resetting sufficiently clears the state.
initial begin
  $display("--- Starting Basic Functionality Test ---");
  $monitor("Time: %t, status: %d", $time, uut.status);
  // Basic Sanity Test
  @(negedge reset);
  @(posedge clock);
  Ex_packet.valid = 1;
  Ex_packet.r1_value = 32'h1000;
  Ex_packet.inst = 32'h00002003; // Example instruction
  Dcache_data_in = 32'hDEADBEEF;
  Dcache_valid_in = 1;

  // Wait for processing
  repeat (2) @(posedge clock);

  // Observe and display outputs
  if (C_packet.valid) begin
    $display("Instruction Address: %h", proc2Dcache_addr);
    $display("Loaded Data: %h", C_packet.result);
    $display("Complete Packet is Valid: %b", C_packet.valid);
  end else begin
    $display("Packet is Invalid at Time: %t", $time);
  end

  // Reset Operations Test
  reset = 1;
  @(posedge clock);
  reset = 0;

  //@(posedge clock - deliberately wait longer to see state transition
  //repeat (4) @(posedge clock);

  // After reset, check outputs
  $display("--- Reset Test ---");
  $display("After Reset - Complete Packet is Valid: %b", C_packet.valid);

  $finish;
end

endmodule