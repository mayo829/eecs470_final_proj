`timescale 1ns/1ps
`include "sys_defs.svh"
`include "ISA.svh"

module stage_id_superscalar_rf_tb;

  // Parameter for number of lanes (must match the decode module’s parameter)
  localparam integer NUM_WAYS = 1;

  // Declare clock and reset signals.
  logic clock;
  logic reset;

  // Create arrays for IF/ID packets and ID/EX packets (assumed types defined in ISA.svh)
  IF_ID_PACKET if_id_packets [NUM_WAYS-1:0];
  ID_EX_PACKET id_packets     [NUM_WAYS-1:0];

  // Write-back interface signals for the regfile.
  logic wb_regfile_en [NUM_WAYS-1:0];
  REG_IDX wb_regfile_idx [NUM_WAYS-1:0];
  DATA wb_regfile_data [NUM_WAYS-1:0];

  // Clock generation: 10 ns period.
  initial begin
    clock = 0;
  end
  always #5 clock = ~clock;

  // Test stimulus.
  initial begin
    $dumpfile("stage_id_superscalar_rf_tb.vcd");
    $dumpvars(0, stage_id_superscalar_rf_tb);

    // Initialize reset and write-back signals.
    reset = 1;
    for (int i = 0; i < NUM_WAYS; i++) begin
      wb_regfile_en[i]   = 0;
      wb_regfile_idx[i]  = 0;
      wb_regfile_data[i] = 0;
    end

    // Remain in reset for a couple of clock cycles.
    repeat (2) @(posedge clock);
    reset = 0;

    // Preload the register file.
    // For demonstration, we write known values into registers 5, 6, and 7.
    // The regfile write occurs at the clock edge.
    wb_regfile_en[0]  = 1;
    wb_regfile_en[1]  = 1;
    wb_regfile_en[2]  = 1;
    wb_regfile_idx[0] = 6'd5;       // Write to register 5.
    wb_regfile_idx[1] = 6'd6;       // Write to register 6.
    wb_regfile_idx[2] = 6'd7;       // Write to register 7.
    wb_regfile_data[0]= 32'h11111111;
    wb_regfile_data[1]= 32'h22222222;
    wb_regfile_data[2]= 32'h33333333;
    @(posedge clock);
    // Clear write enables after one cycle.
    for (int i = 0; i < NUM_WAYS; i++) begin
      wb_regfile_en[i] = 0;
    end

    // Wait a cycle for the register file updates to take effect.
    @(posedge clock);

    // Drive test IF/ID packets for each lane.
    // Lane 0: Test with a LUI instruction.
    if_id_packets[0].inst      = `RV32_LUI;  // Macro should expand to appropriate bit pattern.
    if_id_packets[0].inst.r.rs1 = 6'd5;       // Reads register 5 (should be 0x11111111).
    if_id_packets[0].inst.r.rs2 = 6'd0;       // Not used for LUI.
    if_id_packets[0].inst.r.rd  = 6'd10;
    if_id_packets[0].PC         = 32'h1000;
    if_id_packets[0].NPC        = 32'h1004;
    if_id_packets[0].valid      = 1;

    // Lane 1: Test with an ADD instruction.
    if_id_packets[1].inst      = `RV32_ADD;
    if_id_packets[1].inst.r.rs1 = 6'd6;       // Reads register 6 (should be 0x22222222).
    if_id_packets[1].inst.r.rs2 = 6'd7;       // Reads register 7 (should be 0x33333333).
    if_id_packets[1].inst.r.rd  = 6'd11;
    if_id_packets[1].PC         = 32'h1004;
    if_id_packets[1].NPC        = 32'h1008;
    if_id_packets[1].valid      = 1;

    // Lane 2: Test with a SUB instruction.
    if_id_packets[2].inst      = `RV32_SUB;
    if_id_packets[2].inst.r.rs1 = 6'd5;       // Reads register 5.
    if_id_packets[2].inst.r.rs2 = 6'd6;       // Reads register 6.
    if_id_packets[2].inst.r.rd  = 6'd12;
    if_id_packets[2].PC         = 32'h1008;
    if_id_packets[2].NPC        = 32'h100C;
    if_id_packets[2].valid      = 1;

    // Allow several cycles for the decode stage and regfile read outputs to propagate.
    repeat (5) @(posedge clock);

    // Display output for each lane.
    for (int i = 0; i < NUM_WAYS; i++) begin
      $display("Lane %0d:", i);
      $display("  PC = 0x%08h, NPC = 0x%08h", id_packets[i].PC, id_packets[i].NPC);
      $display("  rs1_value = 0x%08h, rs2_value = 0x%08h", id_packets[i].rs1_value, id_packets[i].rs2_value);
      $display("  opa_select = %0d, opb_select = %0d, alu_func = 0x%0h",
               id_packets[i].opa_select, id_packets[i].opb_select, id_packets[i].alu_func);
      $display("  dest_reg_idx = %0d, halt = %0d, illegal = %0d",
               id_packets[i].dest_reg_idx, id_packets[i].halt, id_packets[i].illegal);
    end

    $display("Test completed.");
    $finish;
  end

  // Instantiate the stage_id_superscalar_rf module.
  stage_id_superscalar_rf #(.NUM_WAYS(NUM_WAYS)) DUT (
    .clock            (clock),
    .reset            (reset),
    .if_id_packets    (if_id_packets),
    .wb_regfile_en    (wb_regfile_en),
    .wb_regfile_idx   (wb_regfile_idx),
    .wb_regfile_data  (wb_regfile_data),
    .id_packets       (id_packets)
  );

endmodule