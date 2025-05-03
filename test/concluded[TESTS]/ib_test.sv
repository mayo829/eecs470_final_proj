`include "sys_defs.svh"
`timescale 1ns/1ps

module Instr_Buffer_tb;

  // Parameters
  parameter CLOCK_PERIOD = 10; // Adjust for effective simulation timing

  // Clock and reset
  logic clock;
  logic reset;

  // Inputs to Instr_Buffer
  logic flush;
  logic [`N-1:0] rd_EN;
  IF_ID_PACKET [`N-1:0] fifo_pckt_in ;
  logic [`N-1:0] wr_EN;
  logic [`N-1:0] putback;

  // Outputs from Instr_Buffer
  logic full;
  IF_ID_PACKET [`N-1:0] fifo_pckt_out ;
  IF_ID_PACKET [`FIFO_SZ-1:0]    fifo ;
  
  // Instantiate the Instr_Buffer
  ib uut (
    .clock(clock),
    .reset(reset),
    .flush(flush),
    .rd_EN(rd_EN),
    .wr_EN(wr_EN),
    .putback(putback),
    .fifo_pckt_in(fifo_pckt_in),
    .full(full),
    .fifo_pckt_out(fifo_pckt_out),
    .fifo(fifo)   // Debug output
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Initial conditions for signals
  initial begin
    reset = 1;
    flush = 0;
    rd_EN = '0;
    wr_EN = '0;
    putback = '0;
  end

  // Apply reset process
  initial begin
    #100;
    reset = 0;
  end

  // Display FIFO packet out contents visually
  task display_fifo_out;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | fifo_pckt_out[%0d] | valid: %b | inst: %0x | PC: %0x | NPC: %0x",
              $time, i,
              fifo_pckt_out[i].valid,
              fifo_pckt_out[i].inst,
              fifo_pckt_out[i].PC,
              fifo_pckt_out[i].NPC);
    end
  endtask

  task display_fifo_in;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | fifo_pckt_in[%0d] | valid: %b | inst: %0x | PC: %0x | NPC: %0x",
              $time, i,
              fifo_pckt_in[i].valid,
              fifo_pckt_in[i].inst,
              fifo_pckt_in[i].PC,
              fifo_pckt_in[i].NPC);
    end
  endtask

  // Initialize packet contents
  task init_packet(input int idx, logic valid, int inst, int PC);
    fifo_pckt_in[idx].valid = valid;
    fifo_pckt_in[idx].inst = inst;
    fifo_pckt_in[idx].PC = PC;
    fifo_pckt_in[idx].NPC = PC + 4; // Assuming NPC is PC + 4
  endtask

  // Instr_Buffer operational test
  task test_instr_buffer;
    begin
      $display("--- Performing Test 1 ---");

      // Writing to Instr_Buffer
      @(posedge clock);
      wr_EN = 2'b11;
      rd_EN = 2'b00;
      putback = 2'b00;

      init_packet(0, 1, 32'h12345678, 32'h00400000);
      init_packet(1, 1, 32'h87654321, 32'h00400004);
      display_fifo_in();

      @(posedge clock);
      wr_EN = 1'b0;
      rd_EN = 2'b11;
      @(posedge clock);
    //   display_fifo_out(); // should see packets coming out
    //   @(posedge clock);   // on this cycle packets should be gone
    end
  endtask

  task test_full;
    begin
      $display("--- Performing Full Test ---");
      rd_EN = '0; // Ensure no read is taking place initially
      wr_EN = 2'b11;
      putback = 2'b00;

      // Simulate filling up the buffer
      @(negedge clock);
      init_packet(0, 1, 32'h12345678, 32'h00400000);
      init_packet(1, 1, 32'h87654321, 32'h00400004);
      display_fifo_in();
      @(posedge clock);

      // Repeat to fill the FIFO
      @(negedge clock);
      init_packet(0, 1, 32'h87654321, 32'h00400008);
      init_packet(1, 1, 32'h12345678, 32'h0040000C);
      display_fifo_in();
      @(posedge clock);

      wr_EN = 2'b00;

      // Allow one additional clock cycle for state change
      @(posedge clock);

      // Check if Instr_Buffer is full
      if (full) $display("Instr_Buffer is correctly full at time %0t ps", $time);
      else $display("WARNING: Instr_Buffer is not full at time %0t ps", $time);

      // Display final FIFO state
      $display("Time %0t ps | Full Test FIFO State:", $time);
      for (int j = 0; j < `FIFO_SZ; j++) begin
        $display("fifo[%0d] | valid: %b | inst: %0x | PC: %0x | NPC: %0x",
                j,
                fifo[j].valid,
                fifo[j].inst,
                fifo[j].PC,
                fifo[j].NPC);
      end
    end
  endtask

  // Reset test for Instr_Buffer
  task reset_instr_buffer_test;
    begin
      @(posedge clock);
      $display("--- Performing Reset ---");
      init_packet(0, 0, 32'h12345678, 32'h00400000);
      init_packet(1, 0, 32'h87654321, 32'h00400004);
      // Apply reset
      reset = 1;
      @(posedge clock);
      reset = 0;
      @(posedge clock);

      // Check that fifo_pckt_out is cleared
      $display("Time %0t ps | Check Outputs After Reset:", $time);
      display_fifo_out();

      // Re-initialize and test Instr_Buffer again after reset
      //test_instr_buffer();
    end
  endtask

  task test_empty;
    begin
      $display("--- Performing Empty Test ---");
      // Empty the Instructions Buffer
      rd_EN = 2'b11;
      @(posedge clock);
      display_fifo_out();
      
      @(posedge clock);
      display_fifo_out(); // Expect no packets
    end
  endtask

  // Testbench Main Execution
  initial begin
    reset = 1;
    flush = 0;
    rd_EN = '0;
    wr_EN = '0;
    putback = '0;
    fifo_pckt_in = '{default: '{default: '0}};

    // Wait for reset to be released
    @(negedge reset);
    #10;
    test_instr_buffer();

    $display("Time %0t ps | Test 1 Internal FIFO State:", $time);
    for (int j = 0; j < `FIFO_SZ; j++) begin
      $display("fifo[%0d] | valid: %b | inst: %0x | PC: %0x | NPC: %0x",
               j,
               fifo[j].valid,
               fifo[j].inst,
               fifo[j].PC,
               fifo[j].NPC);
    end

    test_full();
    test_empty();

    // Perform reset test
    reset_instr_buffer_test();

    $display("Time %0t ps | Reset Internal FIFO State:", $time);
    for (int j = 0; j < `FIFO_SZ; j++) begin
      $display("fifo[%0d] | valid: %b | inst: %0x | PC: %0x | NPC: %0x",
               j,
               fifo[j].valid,
               fifo[j].inst,
               fifo[j].PC,
               fifo[j].NPC);
    end

    // Simulation end
    $finish;
  end

endmodule