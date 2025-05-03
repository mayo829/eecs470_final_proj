`include "sys_defs.svh"

module ROB_test;

  // --------------------------------------------------------------------
  // Adjustable parameters (tie them to your ROB module)
  // --------------------------------------------------------------------
  localparam integer ROB_SZ        = 16;
  localparam integer ROB_PTR_WIDTH = $clog2(ROB_SZ);
  localparam integer PR_WIDTH      = 6;
  
  // Clock period for simulation
  localparam integer CLOCK_PERIOD  = 50;

  // --------------------------------------------------------------------
  // DUT I/O
  // --------------------------------------------------------------------
  logic clock, reset, flush;

  // Dispatch interface
  logic [`N-1:0]          DispatchEntryValid;
  logic [1:0]   NumberToDispatch;
  ADDR  [`N-1:0] dispatch_PC;
  REG_IDX [`N-1:0]  dispatch_dest_reg;
  logic [`N-1:0][PR_WIDTH-1:0] dispatch_T;
  logic [`N-1:0][PR_WIDTH-1:0] dispatch_Told;
  // Modified width: Using ROB_PTR_WIDTH-1:0 (4 bits for ROB_SZ=16)
  logic [ROB_PTR_WIDTH:0] NumFreeEntries;
    
  // Update interface
  logic [`N-1:0]         complete;
  logic [`N-1:0][ROB_PTR_WIDTH-1:0]  completeEntryIndex;
    
  // Commit interface
  logic [`N-1:0]                     commit_valid;
  REG_IDX [`N-1:0]  commit_dest_reg;
  logic [`N-1:0][PR_WIDTH-1:0]       commit_T;
  logic [`N-1:0][PR_WIDTH-1:0]       commit_Told;
  ADDR [`N-1:0] commit_PC;

  // --------------------------------------------------------------------
  // Instantiate the ROB module (DUT)
  // --------------------------------------------------------------------
  rob #(
    .ROB_SZ       (ROB_SZ),
    .ROB_PTR_WIDTH(ROB_PTR_WIDTH),
    .PR_WIDTH     (PR_WIDTH)
  ) dut (
    .clock                (clock),
    .reset                (reset),
    .flush                (flush),
    .DispatchEntryValid   (DispatchEntryValid),
    .NumberToDispatch     (NumberToDispatch),
    .dispatch_PC          (dispatch_PC),
    .dispatch_dest_reg    (dispatch_dest_reg),
    .dispatch_T           (dispatch_T),
    .dispatch_Told        (dispatch_Told),
    .NumFreeEntries       (NumFreeEntries),
    .complete             (complete),
    .completeEntryIndex   (completeEntryIndex),
    .commit_valid         (commit_valid),
    .commit_dest_reg      (commit_dest_reg),
    .commit_T             (commit_T),
    .commit_Told          (commit_Told),
    .commit_PC            (commit_PC)
  );

  // --------------------------------------------------------------------
  // Variables declared at module scope
  // --------------------------------------------------------------------
  integer i, j;
  integer cycle;      // for loop cycle counter
  integer expectedFree1;
  integer test_index;
  integer t;          // for final summary loop
  integer remaining;

  // Overall pass/fail counters for sub-checks
  integer pass_count;
  integer fail_count;

  // Final summary counters for tests
  integer test_pass_count;
  integer test_fail_count;

  // We'll store pass/fail for each major test in an array
  localparam integer NUM_TESTS = 18;
  string test_names[NUM_TESTS];
  logic  test_outcomes[NUM_TESTS];
  
  // Per-test flag (reset for each test)
  logic this_test_pass;

  // For Michael Test 4, looping condition
  integer totalIters;

  // For Michael Test 5, pseudo-parameter
   integer totalInstr;
   integer dispPerCycle;

  // --------------------------------------------------------------------
  // Clock Generation
  // --------------------------------------------------------------------
  always begin
    #(CLOCK_PERIOD/2.0);
    clock = ~clock;
  end

  // --------------------------------------------------------------------
  // Helper Tasks
  // --------------------------------------------------------------------
  // Flush task
  task automatic do_flush();
    flush = 1;
    @(posedge clock);
    flush = 0;
    @(posedge clock);
  endtask

  // Initialize signals
  task automatic init_signals();
    reset = 1;
    clock = 0;
    flush = 0;
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i]        = '0;
      dispatch_dest_reg[i]  = '0;
      dispatch_T[i]         = '0;
      dispatch_Told[i]      = '0;
      completeEntryIndex[i] = '0;
    end
  endtask

  // Sub-check message task
  task automatic test_message(
    input bit pass,
    input string msg
  );
    if (pass)
      $display("   SUB-PASS: %s", msg);
    else
      $display("   SUB-FAIL: %s", msg);
  endtask


  // --------------------------------------------------------------------
  // MAIN TEST SEQUENCE
  // --------------------------------------------------------------------
  initial begin

    // $monitor(
    // "T:%4.0f | reset:%b | flush:%b | #FreeEntries:%0d | complete:%b | commit_vld:%b |  commit_T: %b |  commit_Told: %b",
    // $time, reset, flush, NumFreeEntries, complete, commit_valid, commit_T, commit_Told);

    $monitor(
    "T:%4.0f | reset:%b | flush:%b | #FreeEntries:%0d | complete:%b | commit_vld:%b",
    $time, reset, flush, NumFreeEntries, complete, commit_valid);

    $dumpfile("rob.vcd");
    $dumpvars(0, ROB_test);
    $display("\n===== ROB Testbench Start =====");

    pass_count = 0;
    fail_count = 0;
    test_index = 0;
    test_pass_count = 0;
    test_fail_count = 0;
    remaining = 0;


    init_signals();
    repeat (2) @(posedge clock);
    reset = 0;
    repeat (2) @(posedge clock);

    $display("\n===== ROB Michael's Testbench Start!!!! =====");

    // =============================================================
    // (Michael) Test 1: Full ROB
    // =============================================================
    $display("\n===== Michael Test 1: Full ROB =====");
    test_names[test_index] = "Michael Test 1: Full ROB";
    this_test_pass = 1;

    do_flush();
    // Clear any previous activity
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i]       = '0;
      dispatch_dest_reg[i] = '0;
      dispatch_T[i]        = '0;
      dispatch_Told[i]     = '0;
      completeEntryIndex[i]= '0;
    end

    // Dispatch instructions in multiple cycles using a loop
    while (NumFreeEntries > `N) begin
      DispatchEntryValid = {`N{1'b1}};
      NumberToDispatch   = `N;
      for (j = 0; j < `N; j = j + 1) begin
        dispatch_PC[j]       = 32'h100 + (((i * `N) + j) * 4);
        dispatch_dest_reg[j] = (((i * `N) + j)) % 32;
        dispatch_T[j]        = 6'd10 + ((i * `N) + j);
        dispatch_Told[j]     = 6'd3  + ((i * `N) + j);
      end
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);
    end

    remaining = NumFreeEntries;
    for (i = 0; i < remaining; i = i + 1) begin
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0]       = 32'h200;
      dispatch_dest_reg[0] = 5'd15;
      dispatch_T[0]        = 6'd25;
      dispatch_Told[0]     = 6'd5;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    end

    if (NumFreeEntries !== 0) begin
      $display("FAIL: Expected 0 free entries, got %0d", NumFreeEntries);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: ROB is full => free=0");
      pass_count = pass_count + 1;
    end
    
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    do_flush();
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;


    // =============================================================
    // (Michael) Test 2: NumberToDispatch=0
    // =============================================================
    $display("\n===== Michael Test 2: NumberToDispatch=0 =====");
    test_names[test_index] = "Michael Test 2: NumberToDispatch=0";
    this_test_pass = 1;

    // Clear signals
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i] = '0;
      dispatch_dest_reg[i] = '0;
      dispatch_T[i] = '0;
      dispatch_Told[i] = '0;
      completeEntryIndex[i] = '0;
    end

    // Attempt dispatching with NumberToDispatch=0
    DispatchEntryValid = {`N{1'b1}};
    NumberToDispatch = 0;  
    for (j = 0; j < `N; j = j + 1) begin
      dispatch_PC[j] = 32'h400 + j * 4;
      dispatch_dest_reg[j] = j;
      dispatch_T[j] = 6'd30 + j;
      dispatch_Told[j] = 6'd10 + j;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    if (NumFreeEntries !== ROB_SZ) begin
      $display("FAIL: Free entries changed with NTD=0 => now %0d (exp %0d)", NumFreeEntries, ROB_SZ);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: Free entries unchanged => still %0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end

    do_flush();
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // =============================================================
    // (Michael) Test 3: Commit logic with wrap-around
    // =============================================================
    $display("\n===== Michael Test 3: Commit logic w/ wrap-around =====");
    test_names[test_index] = "Michael Test 3: Commit logic w/ wrap-around";
    this_test_pass = 1;

    // Clear signals manually
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i++) begin
      dispatch_PC[i]        = '0;
      dispatch_dest_reg[i]  = '0;
      dispatch_T[i]         = '0;
      dispatch_Told[i]      = '0;
      completeEntryIndex[i] = '0;
    end

    // We'll do enough iterations to exceed the total size of the ROB

    totalIters = (ROB_SZ / `N) + 5; // The +5 ensures repeat wrap-around

    for (i = 0; i < totalIters; i++) begin
      
      // 1) Dispatch `N instructions
      DispatchEntryValid = {`N{1'b1}}; // e.g. 3'b111 if `N=3
      NumberToDispatch   = `N;

      for (j = 0; j < `N; j++) begin
        dispatch_PC[j]       = 32'h500 + ((i * `N) + j) * 4;
        dispatch_dest_reg[j] = ((i * `N) + j) % 32;
        dispatch_T[j]        = 6'd40 + ((i * `N) + j);
        dispatch_Told[j]     = 6'd20 + ((i * `N) + j);
      end
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);

      // 2) Mark them complete
      for (j = 0; j < `N; j++) begin
        complete[j]           = 1'b1;
        completeEntryIndex[j] = ((i * `N) + j) % ROB_SZ;
      end
      @(posedge clock);
      complete = '0;
      @(posedge clock);

      // 3) Check if ROB is empty after commit
      if (NumFreeEntries !== ROB_SZ - `N) begin
        $display("FAIL: After iteration %0d, free entries=%0d (expected %0d)",
                i, NumFreeEntries, ROB_SZ - `N);
                fail_count = fail_count + 1;
                this_test_pass = 0;
      end else begin
        $display("PASS: Iteration %0d committed properly, free entries=%0d", i, NumFreeEntries);
        pass_count = pass_count + 1;
      end
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // =============================================================
    // (Michael) Test 4: Flush during pending update
    // =============================================================
    $display("\n===== Michael Test 4: Flush during pending update =====");
    test_names[test_index] = "Michael Test 4: Flush during pending update";
    this_test_pass = 1;

    do_flush();

    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) DispatchEntryValid[0] = 1;
    if (`N > 1) DispatchEntryValid[1] = 1;
    NumberToDispatch = (`N > 1) ? 2 : 1;
    if (`N > 0) begin
      dispatch_PC[0] = 32'h600; dispatch_dest_reg[0] = 5'd7;
      dispatch_T[0] = 6'd50; dispatch_Told[0] = 6'd25;
    end
    if (`N > 1) begin
      dispatch_PC[1] = 32'h604; dispatch_dest_reg[1] = 5'd8;
      dispatch_T[1] = 6'd51; dispatch_Told[1] = 6'd26;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    complete = '0;
    @(posedge clock);

    do_flush();
    if (NumFreeEntries == ROB_SZ) begin
      $display("PASS: Flush cleared pending updates => free=%0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Flush failed => free=%0d (exp %0d)", NumFreeEntries, ROB_SZ);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // =============================================================
    // (Michael) Test 4b, Flushing during the commit stage
    // =============================================================

    $display("\n===== Michael Test 4b: Flush during commit stage =====");
    test_names[test_index] = "Michael Test 4b: Flush during commit stage";
    this_test_pass = 1;

    // Clear signals manually
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i++) begin
      dispatch_PC[i]        = '0;
      dispatch_dest_reg[i]  = '0;
      dispatch_T[i]         = '0;
      dispatch_Told[i]      = '0;
      completeEntryIndex[i] = '0;
    end

    do_flush();

    
    // Dispatch 4 instructions in a couple of cycles
    totalInstr = 4;
    dispPerCycle = 2; // dispatch 2 at a time
    for (i = 0; i < totalInstr; i += dispPerCycle) begin
      for (j = 0; j < `N; j++) begin
        if (j < dispPerCycle) begin
          DispatchEntryValid[j] = 1'b1;
          dispatch_PC[j]        = 32'hB000 + (i + j)*4;
          dispatch_dest_reg[j]  = (i + j) % 32;
          dispatch_T[j]         = 6'(80 + i + j);
          dispatch_Told[j]      = 6'(40 + i + j);
        end
        else begin
          DispatchEntryValid[j] = 1'b0;
        end
      end
      NumberToDispatch = dispPerCycle;
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);
    end

    // Complete half of them so that some are ready to commit
    for (i = 0; i < totalInstr/2; i++) begin
      complete[i]           = 1'b1;
      completeEntryIndex[i] = i;
    end
    @(posedge clock);
    complete = '0;

    // Now, presumably the commit logic might proceed. We'll flush right away!
    flush = 1;
    @(posedge clock);
    flush = 0;
    @(posedge clock);

    if (NumFreeEntries == ROB_SZ) begin
      $display("PASS (Interspersed Flush): ROB cleared, free entries = %0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL (Interspersed Flush): Some entries remain, free entries = %0d", NumFreeEntries);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // =============================================================
    // (Michael) Test 5, Out of Order Commiting
    // =============================================================

    $display("\n===== Michael Test 5: Out of Order Commiting =====");
    test_names[test_index] = "Michael Test 5: Out of Order Commiting";
    this_test_pass = 1;

    do_flush();
    
    // Clear signals manually
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i++) begin
      dispatch_PC[i]        = '0;
      dispatch_dest_reg[i]  = '0;
      dispatch_T[i]         = '0;
      dispatch_Told[i]      = '0;
      completeEntryIndex[i] = '0;
    end

    // Dispatch three instructions but complete them across multiple cycles in a shuffled order.
    // Check that commits still happen in order (head-first).

    // Dispatch three instructions
    DispatchEntryValid = 3'b111;
    NumberToDispatch   = 3;
    for (j = 0; j < `N; j++) begin
      dispatch_PC[j] = 32'h750 + j*4;
      dispatch_dest_reg[j] = 5'(j + 12);
      dispatch_T[j] = 6'(j + 65);
      dispatch_Told[j] = 6'(j + 35);
    end
    @(posedge clock);
    DispatchEntryValid = 3'b000;
    @(posedge clock);

    // Complete the third instruction first (index 2) - out of order completion
    complete[1] = 1'b1;
    completeEntryIndex[1] = 2;
    @(posedge clock);
    complete = '0;
    @(posedge clock);

    // We do not commit yet, because instructions at index 0 and index 1 haven't completed
    if (commit_valid[0] || commit_valid[1]) begin
        $display("Fail, committed an instruction while older ones are incomplete!");
        fail_count = fail_count + 1;
        this_test_pass = 0;

    end else begin
        $display("Pass, no commit because older instructions are incomplete.");
        pass_count = pass_count + 1;
    end

    // Now complete the instruction at index 0
    complete[0]           = 1'b1;
    completeEntryIndex[0] = 0;
    @(posedge clock);
    complete = '0;
    @(posedge clock);

    // Check for commit: instruction 0 can commit, but instruction 1 is still incomplete
    if (commit_valid[0] && ~commit_valid[1]) begin
        $display("Pass, only the oldest completed instruction commits.");
        pass_count = pass_count + 1;
    end else begin
        $display("Fail, commit logic is incorrect. commit_valid: %b", commit_valid);
        fail_count = fail_count + 1;
        this_test_pass = 0;
    end

    // Finally complete the instruction at index 1
    complete[1]           = 1'b1;
    completeEntryIndex[1] = 1;
    @(posedge clock);
    complete = '0;
    @(posedge clock);

    @(posedge clock); // waiting for the other ones to commit per cycle.
    complete = '0;
    @(posedge clock);

    // Now all can commit eventually, check if free entries is back to full
    if (NumFreeEntries == ROB_SZ) begin
        $display("Pass, all instructions eventually committed. free entries = %0d", NumFreeEntries);
        pass_count = pass_count + 1;
    end else begin
        $display("Fail, some instructions didn't properly free. free entries = %0d", NumFreeEntries);
        fail_count = fail_count + 1;
        this_test_pass = 0;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    do_flush();
    

    // -------------------------------------------------
    // (Given) Tests
    // -------------------------------------------------
    $display("\n===== ROB Given Testbench Start!!!! =====");

    // (Given) Test 1: Dispatch Three Instructions
    $display("\n===== (Given) Test 1: Dispatch 3 Inst =====");
    test_names[test_index] = "(Given) Test 1: Dispatch 3 Instr";
    this_test_pass = 1;

    // Use a loop and a case statement to assign different values based on index
    DispatchEntryValid = {`N{1'b1}};
    NumberToDispatch = `N;
    for (i = 0; i < `N; i = i + 1) begin
      case(i)
        0: begin
             dispatch_PC[i] = 32'h100;
             dispatch_dest_reg[i] = 5'd1;
             dispatch_T[i] = 6'd10;
             dispatch_Told[i] = 6'd3;
           end
        1: begin
             dispatch_PC[i] = 32'h104;
             dispatch_dest_reg[i] = 5'd2;
             dispatch_T[i] = 6'd11;
             dispatch_Told[i] = 6'd4;
           end
        2: begin
             dispatch_PC[i] = 32'h108;
             dispatch_dest_reg[i] = 5'd3;
             dispatch_T[i] = 6'd12;
             dispatch_Told[i] = 6'd5;
           end
        default: begin
             dispatch_PC[i] = 32'h100 + (i*4);
             dispatch_dest_reg[i] = 5'd1 + i;
             dispatch_T[i] = 6'd10 + i;
             dispatch_Told[i] = 6'd3 + i;
           end
      endcase
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    expectedFree1 = ROB_SZ - `N;
    if (NumFreeEntries !== expectedFree1) begin
      $display("FAIL: After dispatch, exp free=%0d, got %0d", expectedFree1, NumFreeEntries);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: Dispatch => freeEntries=%0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Given) Test 2: Update Instruction 0
    $display("\n===== (Given) Test 2: Update Instr 0 =====");
    test_names[test_index] = "(Given) Test 2: Update Instr 0";
    this_test_pass = 1;

    if (`N > 0) begin
      complete[0] = 1'b1;
      completeEntryIndex[0] = 0;
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);
    if (commit_valid[0]) begin
      $display("PASS: Instruction @index0 is ready for commit.");
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Instruction @index0 not ready for commit.");
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Given) Test 3: Commit Stage
    $display("\n===== (Given) Test 3: Commit Stage =====");
    test_names[test_index] = "(Given) Test 3: Commit Stage";
    this_test_pass = 1;
    @(posedge clock);
    $display("After commit, NumFreeEntries=%0d", NumFreeEntries);
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Given) Test 4: Additional Dispatch (Wrap)
    $display("\n===== (Given) Test 4: Additional Dispatch (Wrap) =====");
    test_names[test_index] = "(Given) Test 4: Additional Dispatch (Wrap)";
    this_test_pass = 1;

    DispatchEntryValid = {`N{1'b1}};
    for (i = 0; i < `N; i = i + 1) begin
      case(i)
        0: begin
             dispatch_PC[i] = 32'h10C;
             dispatch_dest_reg[i] = 5'd4;
             dispatch_T[i] = 6'd13;
             dispatch_Told[i] = 6'd6;
           end
        1: begin
             dispatch_PC[i] = 32'h110;
             dispatch_dest_reg[i] = 5'd5;
             dispatch_T[i] = 6'd14;
             dispatch_Told[i] = 6'd7;
           end
        2: begin
             dispatch_PC[i] = 32'h114;
             dispatch_dest_reg[i] = 5'd6;
             dispatch_T[i] = 6'd15;
             dispatch_Told[i] = 6'd8;
           end
        default: begin
             dispatch_PC[i] = 32'h10C + (i*4);
             dispatch_dest_reg[i] = 5'd4 + i;
             dispatch_T[i] = 6'd13 + i;
             dispatch_Told[i] = 6'd6 + i;
           end
      endcase
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    $display("After additional dispatch, NumFreeEntries=%0d", NumFreeEntries);
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Given) Test 5: Flush Test
    $display("\n===== (Given) Test 5: Flush Test =====");
    test_names[test_index] = "(Given) Test 5: Flush Test";
    this_test_pass = 1;
    do_flush();
    if (NumFreeEntries == ROB_SZ) begin
      $display("PASS: Flush => ROB cleared, free=%0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Flush => free=%0d (exp %0d)", NumFreeEntries, ROB_SZ);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;


    @(posedge clock);
    // (Given) Test 6: Update & Check Commit
    $display("\n===== (Given) Test 6: Update & Check Commit =====");
    test_names[test_index] = "(Given) Test 6: Update & Check Commit";
    this_test_pass = 1;

    // Dispatch only specific entries based on `N:
    DispatchEntryValid = {`N{1'b0}};
    if (`N == 1) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0] = 32'h200;
      dispatch_dest_reg[0] = 5'd4;
      dispatch_T[0] = 6'd9;
      dispatch_Told[0] = 6'd1;
    end else if (`N == 2) begin
      DispatchEntryValid[0] = 1;
      DispatchEntryValid[1] = 1;
      NumberToDispatch = 2;
      dispatch_PC[0] = 32'h200;
      dispatch_dest_reg[0] = 5'd4;
      dispatch_T[0] = 6'd9;
      dispatch_Told[0] = 6'd1;
      dispatch_PC[1] = 32'h208;
      dispatch_dest_reg[1] = 5'd6;
      dispatch_T[1] = 6'd7;
      dispatch_Told[1] = 6'd3;
    end 
    // else begin  // `N>=3
    //   DispatchEntryValid[0] = 1;
    //   DispatchEntryValid[2] = 1;
    //   NumberToDispatch = 2;
    //   dispatch_PC[0] = 32'h200;
    //   dispatch_dest_reg[0] = 5'd4;
    //   dispatch_T[0] = 6'd9;
    //   dispatch_Told[0] = 6'd1;
    //   dispatch_PC[2] = 32'h208;
    //   dispatch_dest_reg[2] = 5'd6;
    //   dispatch_T[2] = 6'd7;
    //   dispatch_Told[2] = 6'd3;
    // end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    if (`N == 1)
      expectedFree1 = ROB_SZ - 1;
    else
      expectedFree1 = ROB_SZ - 2;
    if (NumFreeEntries !== expectedFree1) begin
      $display("FAIL: After dispatch, exp free=%0d, got %0d", expectedFree1, NumFreeEntries);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: Dispatch => free=%0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end

    if (`N == 1) begin
      complete[0] = 1'b1; completeEntryIndex[0] = 0;
    end else if (`N == 2) begin
      complete[0] = 1'b1; completeEntryIndex[0] = 0;
      complete[1] = 1'b1; completeEntryIndex[1] = 1;
    end else begin
      complete[0] = 1'b1; completeEntryIndex[0] = 0;
      complete[1] = 1'b1; completeEntryIndex[1] = 2;
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);

    if (`N == 1) begin
      if (commit_valid[0]) begin
        $display("PASS: Instruction committed properly.");
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL: Expected commit at index 0, but commit_valid=%b", commit_valid);
        fail_count = fail_count + 1;
        this_test_pass = 0;
      end
    end else begin
      if (commit_valid[0]) begin
        $display("PASS: Instr 0 & %0d committed properly.", (`N==2? 1 : 2));
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL: Expected commits, but commit_valid=%b", commit_valid);
        fail_count = fail_count + 1;
        this_test_pass = 0;
      end
    end

    @(posedge clock);
    if (`N == 1) begin
      if (NumFreeEntries !== ROB_SZ) begin
        $display("FAIL: After commit, free=%0d (exp %0d)", NumFreeEntries, ROB_SZ);
        fail_count = fail_count + 1;
        this_test_pass = 0;
      end else begin
        $display("PASS: Commit => free=%0d", NumFreeEntries);
        pass_count = pass_count + 1;
      end
    end else begin
      if (NumFreeEntries !== (ROB_SZ - 1)) begin
        $display("FAIL: After commit, free=%0d (exp %0d)", NumFreeEntries, ROB_SZ - 1);
        fail_count = fail_count + 1;
        this_test_pass = 0;
      end else begin
        $display("PASS: Commit => free=%0d", NumFreeEntries);
        pass_count = pass_count + 1;
      end
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // -------------------------------------------------
    // Farhan Tests
    // -------------------------------------------------
    $display("\n--- farhan begin ---");

    // (Farhan) Test 7: Basic Dispatch & Commit
    test_names[test_index] = "(Farhan) Test 7: Basic Dispatch & Commit";
    this_test_pass = 1;

    do_flush();
    DispatchEntryValid = {`N{1'b1}};
    NumberToDispatch = `N;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i] = 32'h300 + (i * 4);
      dispatch_dest_reg[i] = 5'd10 + i;
      dispatch_T[i] = 6'd20 + i;
      dispatch_Told[i] = 6'd5 + i;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    complete = {`N{1'b1}};
    for (i = 0; i < `N; i = i + 1) begin
      completeEntryIndex[i] = i;
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);

    if (commit_valid !== {`N{1'b1}}) begin
      $display("FAIL: commit_valid=%b, expected %0b", commit_valid, {`N{1'b1}});
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: All instructions committed correctly");
      pass_count = pass_count + 1;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;


    // (Farhan) Test 9: Out-of-Order Completion
    test_names[test_index] = "(Farhan) Test 9: OoO Completion";
    this_test_pass = 1;

    do_flush();
    DispatchEntryValid = {`N{1'b1}};
    NumberToDispatch   = `N;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i] = 32'h600 + (i * 4);
      dispatch_dest_reg[i] = 5'd15 + i;
      dispatch_T[i] = 6'd40 + i;
      dispatch_Told[i] = 6'd10 + i;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    if (`N > 2) begin
      complete[0] = 1; completeEntryIndex[0] = 2;
      @(posedge clock);
      complete[0] = 1; completeEntryIndex[0] = 1;
      @(posedge clock);
      complete[0] = 1; completeEntryIndex[0] = 0;
    end else begin
      for (i = 0; i < `N; i = i + 1) begin
        complete[i] = 1; completeEntryIndex[i] = i;
      end
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);
    if ((commit_valid !== {`N{1'b1}})) begin
      $display("FAIL: OoO completion => commit mismatch => commit_valid=%b", commit_valid);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end else begin
      $display("PASS: In-order commit despite OoO completion");
      pass_count = pass_count + 1;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Farhan) Test 10: Flush During Execution
    test_names[test_index] = "(Farhan) Test 10: Flush During Execution";
    this_test_pass = 1;

    DispatchEntryValid = {`N{1'b1}};
    NumberToDispatch   = `N;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i] = 32'h700 + (i*4);
    end
    @(posedge clock);
    // For a case where fewer than `N instructions are dispatched:
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) DispatchEntryValid[0] = 1;
    if (`N > 1) DispatchEntryValid[1] = 1;
    NumberToDispatch   = (`N > 1) ? 2 : 1;
    if (`N > 0) dispatch_PC[0] = 32'h70C;
    if (`N > 1) dispatch_PC[1] = 32'h710;
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    if (`N > 0) begin
      complete[0] = 1; completeEntryIndex[0] = 0;
    end
    if (`N > 1) begin
      complete[1] = 1; completeEntryIndex[1] = 1;
    end
    @(posedge clock);
    complete = '0;
    do_flush();
    if (NumFreeEntries !== ROB_SZ) begin
      $display("FAIL: Flush => free=%0d, exp %0d", NumFreeEntries, ROB_SZ);
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end

    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0] = 32'h800;
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);
      if (commit_valid[0] && (commit_PC[0] == 32'h800)) begin
        $display("PASS: Post-flush dispatch successful");
        pass_count = pass_count + 1;
      end else begin
        $display("FAIL: Post-flush dispatch failed");
        fail_count = fail_count + 1;
        this_test_pass = 0;
      end
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // (Farhan) Test 11: Back-to-Back Dispatch & Commit
    test_names[test_index] = "(Farhan) Test 11: Back-to-Back Dispatch & Commit";
    this_test_pass = 1;

    do_flush();
    for (cycle = 0; cycle < 5; cycle = cycle + 1) begin
      DispatchEntryValid = {`N{1'b1}};
      NumberToDispatch = `N;
      for (j = 0; j < `N; j = j + 1) begin
        dispatch_PC[j] = 32'h900 + (((cycle * `N) + j) * 4);
        dispatch_Told[j] = 6'd20 + ((cycle * `N) + j);
      end
      complete = {`N{1'b1}};
      for (j = 0; j < `N; j = j + 1)
        completeEntryIndex[j] = (((cycle * `N) + j)) % ROB_SZ;
      @(posedge clock);
    end
    DispatchEntryValid = '0;
    complete = '0;
    @(posedge clock);
    if (NumFreeEntries == (ROB_SZ - `N)) begin
      $display("PASS: Stable back-to-back operation => free=%0d", NumFreeEntries);
      pass_count = pass_count + 1;
    end else begin
      $display("FAIL: Back-to-back => free=%0d, expected %0d", NumFreeEntries, (ROB_SZ - `N));
      fail_count = fail_count + 1;
      this_test_pass = 0;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    $display("\n--- farhan end ---");


    // -------------------------------------------------
    // Luke Tests
    // -------------------------------------------------
    // Luke Test 1: Program Simulation ROB
    $display("\n--- luke start ---");
    $display("\n===== Luke Test 1: Program Simulation ROB =====");
    test_names[test_index] = "Luke Test 1: Program Simulation ROB";
    this_test_pass = 1;

    do_flush();
    // Clear any previous activity
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i]       = '0;
      dispatch_dest_reg[i] = '0;
      dispatch_T[i]        = '0;
      dispatch_Told[i]     = '0;
      completeEntryIndex[i]= '0;
    end

    // Dispatch instructions in multiple cycles using a loop until ROB is full
    while (NumFreeEntries > `N) begin
      DispatchEntryValid = {`N{1'b1}};
      NumberToDispatch   = `N;
      for (j = 0; j < `N; j = j + 1) begin
        dispatch_PC[j]       = 32'h100 + (((i * `N) + j) * 4);
        dispatch_dest_reg[j] = (((i * `N) + j)) % 32;
        dispatch_T[j]        = 6'd10 + ((i * `N) + j);
        dispatch_Told[j]     = 6'd3  + ((i * `N) + j);
      end
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);
    end

    remaining = NumFreeEntries;
    for (i = 0; i < remaining; i = i + 1) begin
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0]       = 32'h200;
      dispatch_dest_reg[0] = 5'd15;
      dispatch_T[0]        = 6'd25;
      dispatch_Told[0]     = 6'd5;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    end

    // try to dispatch another instructions after ROB is full
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0]       = 32'h200;
      dispatch_dest_reg[0] = 5'd15;
      dispatch_T[0]        = 6'd25;
      dispatch_Told[0]     = 6'd5;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);

    if (NumFreeEntries !== 0) begin
      $display("FAIL: Expected 0 free entries, got %0d", NumFreeEntries);
      this_test_pass = 0;
    end else begin
      $display("PASS: ROB is full => free=0");
    end

    // complete 3 entries
    complete = {`N{1'b0}};
    for (i = 0; i < 3; i++) begin
      complete[i]           = 1'b1;
      completeEntryIndex[i] = i;
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);
    @(posedge clock); // not sure why this takes 2 more cycles

    if (NumFreeEntries !== 3) begin
      $display("FAIL: Expected 3 free entries, got %0d", NumFreeEntries);
      this_test_pass = 0;
    end else begin
      $display("PASS: ROB has 3 free entires");
    end

    // wait for 5 cycles
    #250;

    // try to dispatch another instructions
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0]       = 32'h200;
      dispatch_dest_reg[0] = 5'd15;
      dispatch_T[0]        = 6'd25;
      dispatch_Told[0]     = 6'd5;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    @(posedge clock);

    if (NumFreeEntries !== 2) begin
      $display("FAIL: Expected 2 free entries, got %0d", NumFreeEntries);
      this_test_pass = 0;
    end else begin
      $display("PASS: ROB has 2 free entires!!!");
    end

    // simulate branch taken
    do_flush();

    // start at branched location and fill ROB again
    while (NumFreeEntries > `N) begin
      DispatchEntryValid = {`N{1'b1}};
      NumberToDispatch   = `N;
      for (j = 0; j < `N; j = j + 1) begin
        dispatch_PC[j]       = 32'h500 + (((i * `N) + j) * 4);
        dispatch_dest_reg[j] = (((i * `N) + j)) % 32;
        dispatch_T[j]        = 6'd10 + ((i * `N) + j);
        dispatch_Told[j]     = 6'd3  + ((i * `N) + j);
      end
      @(posedge clock);
      DispatchEntryValid = '0;
      @(posedge clock);
    end

    // wait 10 cycles
    #500;

    remaining = NumFreeEntries;
    for (i = 0; i < remaining; i = i + 1) begin
    DispatchEntryValid = {`N{1'b0}};
    if (`N > 0) begin
      DispatchEntryValid[0] = 1;
      NumberToDispatch = 1;
      dispatch_PC[0]       = 32'h200;
      dispatch_dest_reg[0] = 5'd15;
      dispatch_T[0]        = 6'd25;
      dispatch_Told[0]     = 6'd5;
    end
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    end

    // big multiplication instruction maybe, wait 20 cycles
    #1000;

    // complete `N entries
    complete = {`N{1'b0}};
    for (i = 0; i < `N; i++) begin
      complete[i]           = 1'b1;
      completeEntryIndex[i] = i;
    end
    @(posedge clock);
    complete = '0;
    @(posedge clock);
    @(posedge clock); // not sure why this takes 2 more cycles

    if (NumFreeEntries !== `N) begin
      $display("FAIL: Expected %0d free entries, got %0d", `N, NumFreeEntries);
      this_test_pass = 0;
    end else begin
      $display("PASS: ROB has %0d free entires!!!", `N);
    end

    if (this_test_pass) begin
      pass_count = pass_count + 1;
    end else begin
      fail_count = fail_count + 1;
    end
    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;
    
    // reset for next test
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    do_flush();


    // -------------------------------------------------
    // Luke Test 2: Dispatch more than `N instructions
    // -------------------------------------------------
    $display("\n===== Luke Test 2: Dispatch more than `N inst =====");
    test_names[test_index] = "Luke Test 2: Dispatch more than `N inst";
    this_test_pass = 1;

    do_flush();
    // Clear any previous activity
    DispatchEntryValid = '0;
    NumberToDispatch   = `N;
    complete           = '0;
    for (i = 0; i < `N; i = i + 1) begin
      dispatch_PC[i]       = '0;
      dispatch_dest_reg[i] = '0;
      dispatch_T[i]        = '0;
      dispatch_Told[i]     = '0;
      completeEntryIndex[i]= '0;
    end

    // Try to dispatch more than `N instructions
    DispatchEntryValid = {`N+1{1'b1}};
    NumberToDispatch   = `N + 1;
    for (j = 0; j < `N + 1; j = j + 1) begin
      dispatch_PC[j]       = 32'h100 + (j * 4);
      dispatch_dest_reg[j] = 5'd10 + j;
      dispatch_T[j]        = 6'd20 + j;
      dispatch_Told[j]     = 6'd5 + j;
    end

    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    @(posedge clock);

    if (NumFreeEntries !== ROB_SZ - `N) begin
      $display("FAIL: Expected %0d free entries, got %0d", ROB_SZ - `N, NumFreeEntries);
      this_test_pass = 0;
      fail_count = fail_count + 1;
    end else begin
      $display("PASS: ROB has %0d free entires!!!", ROB_SZ - `N);
      pass_count = pass_count + 1;
    end

    test_outcomes[test_index] = this_test_pass;
    test_index = test_index + 1;

    // reset for next test
    @(posedge clock);
    DispatchEntryValid = '0;
    @(posedge clock);
    do_flush();

    $display("\n--- luke end ---");

    // --------------------------------------------------------------------
    // Final Summary of All Tests
    // --------------------------------------------------------------------
    $display("\n===== ROB Testbench End =====");
    $display("\n=== FINAL TEST SUMMARY ===");

    test_pass_count = 0;
    test_fail_count = 0;
    for (t = 0; t < test_index; t = t + 1) begin
      if (test_outcomes[t]) begin
        // Green color for pass using ANSI escape codes
        $display("\033[32m[PASS]\033[0m %s", test_names[t]);
        test_pass_count = test_pass_count + 1;
      end else begin
        // Red color for fail
        $display("\033[31m[FAIL]\033[0m %s", test_names[t]);
        test_fail_count = test_fail_count + 1;
      end
    end
    $display("--------------------------------------");
    $display("TOTAL PASSED: %0d, TOTAL FAILED: %0d", test_pass_count, test_fail_count);
    $display("ROB_SZ: %0d, %0d - WAY", ROB_SZ, `N);
    $display("--------------------------------------\n");

    $finish;
  end

endmodule
