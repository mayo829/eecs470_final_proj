`include "sys_defs.svh"
`timescale 1ns/1ps

module FIFO_tb;

  // Parameters
  parameter CLOCK_PERIOD = 10; // Adjust for effective simulation timing

  logic clock;
  logic reset;
  logic flush;
  logic [`N-1:0] rd_EN;
  ISSUE_PACKET [`N-1:0] fifo_pckt_in ;
  logic [`N-1:0] wr_EN;
  logic full;
  ISSUE_PACKET [`N-1:0] fifo_pckt_out ;
  ISSUE_PACKET [`FIFO_SZ-1:0] fifo ;

  FIFO uut (
    .clock(clock),
    .reset(reset),
    .flush(flush),
    .rd_EN(rd_EN),
    .wr_EN(wr_EN),
    .fifo_pckt_in(fifo_pckt_in),
    .full(full),
    .fifo_pckt_out(fifo_pckt_out),
    .fifo(fifo)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Assign initial states
  initial begin
    reset = 1;
    flush = 0;
    rd_EN = '0;
    wr_EN = '0;
  end

  // Apply reset process
  initial begin
    #100;
    reset = 0;
  end

  // Display FIFO packet out contents visually
  task display_fifo_out;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | fifo_pckt_out[%0d] | valid: %b | FuncUnitType: %0d | NPC: %0x | PC: %0x | opa_select: %0d | opb_select: %0d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x",
              $time, i,
              fifo_pckt_out[i].valid,
              fifo_pckt_out[i].FuncUnitType,
              fifo_pckt_out[i].NPC,
              fifo_pckt_out[i].PC,
              fifo_pckt_out[i].opa_select,
              fifo_pckt_out[i].opb_select,
              fifo_pckt_out[i].inst,
              fifo_pckt_out[i].rob_idx,
              fifo_pckt_out[i].dest_reg_idx,
              fifo_pckt_out[i].r1_value,
              fifo_pckt_out[i].r2_value);
    end
  endtask

  task display_fifo_in;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | fifo_pckt_in[%0d] | valid: %b | FuncUnitType: %0d | NPC: %0x | PC: %0x | opa_select: %0d | opb_select: %0d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x", 
              $time, i,
              fifo_pckt_in[i].valid,
              fifo_pckt_in[i].FuncUnitType,
              fifo_pckt_in[i].NPC,
              fifo_pckt_in[i].PC,
              fifo_pckt_in[i].opa_select,
              fifo_pckt_in[i].opb_select,
              fifo_pckt_in[i].inst,
              fifo_pckt_in[i].rob_idx,
              fifo_pckt_in[i].dest_reg_idx,
              fifo_pckt_in[i].r1_value,
              fifo_pckt_in[i].r2_value);
    end
  endtask

  // Initialize packets
  task init_packet(input int idx, logic valid, FUNC_UNIT FuncUnitType, int NPC, int PC, 
                   ALU_OPA_SELECT opa_sel, ALU_OPB_SELECT opb_sel, int inst, 
                   int r1, int r2);
    fifo_pckt_in[idx].valid = valid;
    fifo_pckt_in[idx].FuncUnitType = FuncUnitType;
    fifo_pckt_in[idx].NPC = NPC;
    fifo_pckt_in[idx].PC = PC;
    fifo_pckt_in[idx].opa_select = opa_sel;
    fifo_pckt_in[idx].opb_select = opb_sel;
    fifo_pckt_in[idx].inst = inst;
    fifo_pckt_in[idx].r1_value = r1;
    fifo_pckt_in[idx].r2_value = r2;
  endtask

  // FIFO operational test
  task test_fifo;
    begin
      $display("--- Performing Test 1 ---");

      // Writing to FIFO
      @(posedge clock);
      wr_EN = 2'b11;
      rd_EN = 2'b00;

      init_packet(0, 1, ALU0, 32'h04, 32'h00, OPA_IS_RS1, OPB_IS_RS2, 32'h12345678, 32'h0001, 32'h0002);
      init_packet(1, 1, ALU1, 32'h08, 32'h04, OPA_IS_NPC, OPB_IS_I_IMM, 32'h87654321, 32'h0003, 32'h0004);
      display_fifo_in();

      @(posedge clock);
      wr_EN = 1'b0;
      rd_EN = 2'b11;
      @(posedge clock);
      display_fifo_out(); // we should see packets coming out
      @(posedge clock);   // on this cycle packets should be gone
    end
  endtask

  task test_full;
    begin
      $display("--- Performing Full Test ---");
      rd_EN = '0; // Ensure no read is taking place initially
      wr_EN = 2'b11;

      // Run enough iterations to potentially fill the FIFO
      @(negedge clock);
      init_packet(0, 1, ALU0, 32'd4, 32'h0, OPA_IS_RS1, OPB_IS_RS2, 32'h12345678, 32'h0001, 32'h0002);
      init_packet(1, 1, ALU1, 32'd8, 32'd4, OPA_IS_NPC, OPB_IS_I_IMM, 32'h87654321, 32'h0003, 32'h0004);
      display_fifo_in();
      @(posedge clock);

      @(negedge clock);
      init_packet(0, 1, ALU0, 32'd12, 32'd8, OPA_IS_RS1, OPB_IS_RS2, 32'h12345678, 32'h0005, 32'h0006);
      init_packet(1, 1, ALU1, 32'd16, 32'd12, OPA_IS_NPC, OPB_IS_I_IMM, 32'h87654321, 32'h0007, 32'h0008);
      display_fifo_in();
      @(posedge clock);

      // Stop writing
      wr_EN = 2'b00;

      // Allow one additional clock cycle for state change
      @(posedge clock);

      // Check if FIFO is full
      if (full) $display("FIFO is correctly full at time %0t ps", $time);
      else $display("WARNING: FIFO is not full at time %0t ps", $time);

      // Display final FIFO state
      $display("Time %0t ps | Full Test FIFO State:", $time);
      for (int j = 0; j < `FIFO_SZ; j++) begin
        $display("fifo[%0d] | valid: %b | FuncUnitType: %d | NPC: %0x | PC: %0x | opa_select: %d | opb_select: %d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x",
                j,
                fifo[j].valid,
                fifo[j].FuncUnitType,
                fifo[j].NPC,
                fifo[j].PC,
                fifo[j].opa_select,
                fifo[j].opb_select,
                fifo[j].inst,
                fifo[j].rob_idx,
                fifo[j].dest_reg_idx,
                fifo[j].r1_value,
                fifo[j].r2_value);
      end
    end
  endtask

  task reset_fifo_test;
    begin
      @(posedge clock);
      $display("--- Performing Reset ---");
      init_packet(0, 0, ALU0, 32'h04, 32'h00, OPA_IS_RS1, OPB_IS_RS2, 32'h12345678, 32'h0001, 32'h0002);
      init_packet(1, 0, ALU1, 32'h08, 32'h04, OPA_IS_NPC, OPB_IS_I_IMM, 32'h87654321, 32'h0003, 32'h0004);
      // Apply reset
      reset = 1;
      @(posedge clock);
      reset = 0;
      @(posedge clock);

      // For verification, check that fifo_pckt_out is cleared
      $display("Time %0t ps | Check Outputs After Reset:", $time);
      display_fifo_out();

      // Re-initialize and test FIFO again after reset
      //test_fifo();
    end
  endtask

  task test_empty;
    begin
      // Reusing full test setup
      $display("--- Performing empty Test ---");
      // Empty the FIFO
      $display("--- Emptying FIFO ---");
      @(posedge clock);
      wr_EN = 2'b00;
      rd_EN = 2'b11;
      @(posedge clock);
      display_fifo_out(); // we should see packets coming out
      @(posedge clock);   // on this cycle 2 packets should be gone
      display_fifo_out(); // we should see packets coming out
      @(posedge clock);   // on this cycle all packets should be gone
      display_fifo_out(); // we should see packets coming out
      @(posedge clock);   // on this cycle all packets should be gone
      
      // Display final state
      $display("Time %0t ps | Final FIFO State After Empty:", $time);
        for (int j = 0; j < `FIFO_SZ; j++) begin
          $display("fifo[%0d] | valid: %b | FuncUnitType: %d | NPC: %0x | PC: %0x | opa_select: %d | opb_select: %d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x",
                  j,
                  fifo[j].valid,
                  fifo[j].FuncUnitType,
                  fifo[j].NPC,
                  fifo[j].PC,
                  fifo[j].opa_select,
                  fifo[j].opb_select,
                  fifo[j].inst,
                  fifo[j].rob_idx,
                  fifo[j].dest_reg_idx,
                  fifo[j].r1_value,
                  fifo[j].r2_value);
        end
      end
  endtask

  // Testbench Main Execution
  initial begin
    reset = 1;
    flush = 0;
    rd_EN = '0;
    wr_EN = '0;
    fifo_pckt_in = '{default: '0};

    // Wait for reset to be released
    @(negedge reset);
    #10;
    test_fifo();

    // Display Final States
    $display("Time %0t ps | Test1 Internal FIFO State:", $time);
    for (int j = 0; j < `FIFO_SZ; j++) begin
      $display("fifo[%0d] | valid: %b | FuncUnitType: %d | NPC: %0x | PC: %0x | opa_select: %d | opb_select: %d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x",
               j,
               fifo[j].valid,
               fifo[j].FuncUnitType,
               fifo[j].NPC,
               fifo[j].PC,
               fifo[j].opa_select,
               fifo[j].opb_select,
               fifo[j].inst,
               fifo[j].rob_idx,
               fifo[j].dest_reg_idx,
               fifo[j].r1_value,
               fifo[j].r2_value);
    end

    test_full();
    test_empty();

    // Perform reset test
    reset_fifo_test();

    // Display Final States
    $display("Time %0t ps | RESET Internal FIFO State:", $time);
    for (int j = 0; j < `FIFO_SZ; j++) begin
      $display("fifo[%0d] | valid: %b | FuncUnitType: %d | NPC: %0x | PC: %0x | opa_select: %d | opb_select: %d | inst: %0x | rob_idx: %d | dest_reg_idx: %d | r1_value: %0x | r2_value: %0x",
               j,
               fifo[j].valid,
               fifo[j].FuncUnitType,
               fifo[j].NPC,
               fifo[j].PC,
               fifo[j].opa_select,
               fifo[j].opb_select,
               fifo[j].inst,
               fifo[j].rob_idx,
               fifo[j].dest_reg_idx,
               fifo[j].r1_value,
               fifo[j].r2_value);
    end

    // Simulation end
    $finish;
  end

endmodule