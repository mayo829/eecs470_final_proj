`include "sys_defs.svh"

module DISPATCH_STAGE_test;

  // Parameters for the DUT (Device Under Test)
  parameter int N = 4;
  parameter int RS_SIZE = 16;
  parameter ADDR = 32;
  parameter REG_IDX = 5;

  // Signals for the DUT
  logic clock;
  logic reset;
  logic flush_dispatch;
  logic stall_dispatch;

  // Input from decode
  DISPATCH_STAGE::ID_EX_PACKET decode_in [N];

  // Freed-list interface
  logic can_alloc;
  logic [$clog2(N+1)-1:0] num_alloc_req;
  logic [$clog2(64)-1:0] alloc_reg_id [N];

  // Reservation Station interface
  logic [N-1:0] rs_dispatch_valid;
  RS_ENT rs_dispatch_in [N];
  logic rs_can_accept;

  // ROB interface
  logic [`ROB_PTR_WIDTH:0] rob_NumFreeEntries;
  logic [N-1:0] DispatchEntryValid;
  logic [$clog2(N+1)-1:0] NumberToDispatch;
  ADDR dispatch_PC [N];
  REG_IDX dispatch_dest_reg [N];
  logic [`PR_WIDTH-1:0] dispatch_T [N];
  logic [`PR_WIDTH-1:0] dispatch_Told [N];

  // Instantiate the DUT
  DISPATCH_STAGE #(
    .N(N),
    .RS_SIZE(RS_SIZE)
  ) dut (
    .clock(clock),
    .reset(reset),
    .flush_dispatch(flush_dispatch),
    .stall_dispatch(stall_dispatch),
    .decode_in(decode_in),
    .can_alloc(can_alloc),
    .num_alloc_req(num_alloc_req),
    .alloc_reg_id(alloc_reg_id),
    .rs_dispatch_valid(rs_dispatch_valid),
    .rs_dispatch_in(rs_dispatch_in),
    .rs_can_accept(rs_can_accept),
    .rob_NumFreeEntries(rob_NumFreeEntries),
    .DispatchEntryValid(DispatchEntryValid),
    .NumberToDispatch(NumberToDispatch),
    .dispatch_PC(dispatch_PC),
    .dispatch_dest_reg(dispatch_dest_reg),
    .dispatch_T(dispatch_T),
    .dispatch_Told(dispatch_Told)
  );

  // Clock generation
  always #5 clock = ~clock;  // Clock toggles every 5 time units

  // Stimulus generation
  initial begin
    // Initialize signals
    clock = 0;
    reset = 1;
    flush_dispatch = 0;
    can_alloc = 1;
    num_alloc_req = 0;
    rs_can_accept = 1;
    rob_NumFreeEntries = N;

    // Initialize decode input
    for (int i = 0; i < N; i++) begin
      decode_in[i].valid = 0;
      decode_in[i].PC = 32'h00000000 + i * 4; // Example PC values
      decode_in[i].dest_reg_idx = i;  // Example destination register
      decode_in[i].alu_func = 0;      // Example ALU function
      decode_in[i].inst = 32'h0;      // Example instruction
      decode_in[i].rob_index = i;     // Example ROB index
    end

    // Apply reset
    #10 reset = 0;
    
    // Test 1: No valid instructions (all decode_in valid = 0)
    #10;
    for (int i = 0; i < N; i++) begin
      decode_in[i].valid = 0;
    end
    #10;

    // Test 2: All instructions valid (decode_in valid = 1)
    #10;
    for (int i = 0; i < N; i++) begin
      decode_in[i].valid = 1;
    end
    #10;

    // Test 3: Flush Dispatch signal active
    #10;
    flush_dispatch = 1;
    #10;
    flush_dispatch = 0;

    // Test 4: Check stall_dispatch logic
    #10;
    can_alloc = 0;  // Disable allocation
    #10;

    // Test 5: Verify dispatching with ROB entries and Reservation Station can accept
    #10;
    rob_NumFreeEntries = 4;  // Only 4 entries available in ROB
    rs_can_accept = 0;       // Reservation Station can't accept
    #10;

    // Test 6: Check flush dispatch signal functionality
    #10;
    flush_dispatch = 1;  // Assert flush signal
    #10;
    flush_dispatch = 0;

    // Finish simulation
    $finish;
  end

  // Monitor outputs
  initial begin
    $monitor("Time: %0t, Stall: %0d, DispatchEntryValid: %0b, NumberToDispatch: %0d", 
              $time, stall_dispatch, DispatchEntryValid, NumberToDispatch);
  end

endmodule