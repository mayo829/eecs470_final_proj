module tb_two_bit_bp;

  // Inputs to the DUT
  logic clock;
  logic reset;         // Synchronous active-high reset
  logic valid_branch;
  logic branch_result; // 0: Not Taken, 1: Taken

  // DUT output
  logic predicted_branch;

  // Instantiate the DUT
  bp2b DUT (
    .clock(clock),
    .reset(reset),
    .valid_branch(valid_branch),
    .branch_result(branch_result),
    .predicted_branch(predicted_branch)
  );

  // Expected state tracking:
  // 0 = STRONGLY_NT, 1 = WEAKLY_NT, 2 = WEAKLY_T, 3 = STRONGLY_T
  int expected_state;

  // Function to convert expected state to predicted branch output.
  // Since the DUT assigns predicted_branch = state[1],
  // the expected prediction is 1 when expected_state is 2 or 3, and 0 otherwise.
  function logic expected_prediction();
    return (expected_state >= 2);
  endfunction

  // A task to check the output after each cycle.
  task check_output(string cycle_label);
    #1; // Allow signals to settle after the posedge clock
    if (predicted_branch !== expected_prediction()) begin
      $display("ERROR at %s: expected predicted_branch = %0d (expected_state=%0d), got %0d", 
               cycle_label, expected_prediction(), expected_state, predicted_branch);
      $fatal(1);
    end else begin
      $display("PASS  at %s: predicted_branch = %0d, expected_state = %0d", 
               cycle_label, predicted_branch, expected_state);
    end
  endtask

  // Test Sequence
  initial begin
    // Initialize signals
    clock        = 0;
    @(negedge clock);
    reset        = 1;      // Initially assert reset to force initialization.
    valid_branch = 0;
    branch_result= 0;
    expected_state = 2;    // WEAKLY_T

    // Cycle 0: With reset active, the DUT sets state to WEAKLY_T (2).
    @(negedge clock);
    check_output("Cycle 0 (reset active)");

    // Release reset so that state updates occur
    reset = 0;

    // Cycle 1: No valid branch; state remains the same.
    valid_branch = 0;
    branch_result = 0;

    @(negedge clock);
    check_output("Cycle 1 (no branch)");

    // Cycle 2: Branch not taken;
    // For a not-taken branch, the state should decrement:
    // WEAKLY_T (2) -> WEAKLY_NT (1)
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    if (expected_state > 0)
      expected_state = expected_state - 1;
    check_output("Cycle 2 (branch not taken: 2 -> 1)");

    // Cycle 3: Branch not taken;
    // WEAKLY_NT (1) -> STRONGLY_NT (0)
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    if (expected_state > 0)
      expected_state = expected_state - 1;
    check_output("Cycle 3 (branch not taken: 1 -> 0)");

    // Cycle 4: Branch not taken; already at 0, so should remain saturated.
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    check_output("Cycle 4 (branch not taken, saturates at 0)");

    // Cycle 5: Branch taken;
    // STRONGLY_NT (0) -> WEAKLY_NT (1)
    valid_branch = 1;
    branch_result = 1;

    @(negedge clock);
    if (expected_state < 3)
      expected_state = expected_state + 1;
    check_output("Cycle 5 (branch taken: 0 -> 1)");

    // Cycle 6: Branch taken;
    // WEAKLY_NT (1) -> WEAKLY_T (2)
    valid_branch = 1;
    branch_result = 1;

    @(negedge clock);
    if (expected_state < 3)
      expected_state = expected_state + 1;
    check_output("Cycle 6 (branch taken: 1 -> 2)");

    // Cycle 7: Branch taken;
    // WEAKLY_T (2) -> STRONGLY_T (3)
    valid_branch = 1;
    branch_result = 1;

    @(negedge clock);
    if (expected_state < 3)
      expected_state = expected_state + 1;
    check_output("Cycle 7 (branch taken: 2 -> 3)");

    // Cycle 8: Branch taken; already saturated at STRONGLY_T (3).
    valid_branch = 1;
    branch_result = 1;

    @(negedge clock);
    check_output("Cycle 8 (branch taken, saturates at 3)");

    // Cycle 9: Branch not taken;
    // STRONGLY_T (3) -> WEAKLY_T (2)
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    if (expected_state > 0)
      expected_state = expected_state - 1;
    check_output("Cycle 9 (branch not taken: 3 -> 2)");

    // Cycle 10: Branch not taken;
    // WEAKLY_T (2) -> WEAKLY_NT (1)
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    if (expected_state > 0)
      expected_state = expected_state - 1;
    check_output("Cycle 10 (branch not taken: 2 -> 1)");

    // Cycle 11: Branch not taken;
    // WEAKLY_NT (1) -> STRONGLY_NT (0)
    valid_branch = 1;
    branch_result = 0;

    @(negedge clock);
    if (expected_state > 0)
      expected_state = expected_state - 1;
    check_output("Cycle 11 (branch not taken: 1 -> 0)");

    // Cycle 12: No valid branch; even though branch_result is 1, state should not change.
    valid_branch = 0;
    branch_result = 1;

    @(negedge clock);
    check_output("Cycle 12 (no branch, state remains)");

    // Cycle 13: Assert reset mid-sequence; DUT should reset to WEAKLY_T (state = 2).
    reset = 1;         // Activate reset
    valid_branch = 0;  // Branch inputs are ignored during reset.
    branch_result = 0;
    expected_state = 2;

    @(negedge clock);
    check_output("Cycle 13 (reset active)");

    // Cycle 14: Deassert reset and no branch; state remains at WEAKLY_T.
    reset = 0;
    valid_branch = 0;
    branch_result = 0;

    @(negedge clock);
    check_output("Cycle 14 (post reset, no branch)");

    #10;
    $display("All tests passed.");
    $finish;
  end

  // Clock generation: Toggle clock every 5 time units => period = 10 time units.
  always #5 clock = ~clock;

endmodule