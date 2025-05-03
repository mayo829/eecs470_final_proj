`timescale 1ns/1ps
`include "sys_defs.svh"

module s_ArchitecturalMap_test;

  // =====================================================
  // Signal Declarations
  // =====================================================
  logic clock;
  logic reset;
  logic flush;

  localparam int CLOCK_PERIOD = 10;

  logic [1:0]       commit_valid;
  REG_IDX [1:0]     commit_arch_reg;
  logic [1:0][5:0]  commit_phys_reg;

  logic [31:0][5:0] arch_map_out;

  // Test tracking
  string test_names[20];
  logic  test_outcomes[20];
  int test_index = 0;
  int pass_count = 0;
  int fail_count = 0;
  bit this_test_pass;

  // =====================================================
  // DUT
  // =====================================================
  s_ArchitecturalMap dut (
    .clock(clock),
    .reset(reset),
    .flush(flush),
    .commit_valid(commit_valid),
    .commit_arch_reg(commit_arch_reg),
    .commit_phys_reg(commit_phys_reg),
    .arch_map_out(arch_map_out)
  );

  // =====================================================
  // Clock
  // =====================================================
  initial clock = 0;
  always #(CLOCK_PERIOD/2) clock = ~clock;

  // =====================================================
  // Tasks
  // =====================================================
    task reset_dut();
    reset = 1;
    flush = 0;
    @(posedge clock);
    @(posedge clock);
    reset = 0;
    @(posedge clock);
    endtask

  task flush_dut();
    // 📝 NOTE: Clear inputs before flushing to prevent false commits!
    commit_valid = '{0, 0};
    commit_arch_reg = '{0, 0};
    commit_phys_reg = '{0, 0};
    flush = 1;
    @(posedge clock);
    flush = 0;
    @(posedge clock);
  endtask

  task test_message(input bit pass, input string msg);
    if (pass) begin
      $display("   \033[32m[PASS]\033[0m %s", msg);
    end else begin
      $display("   \033[31m[FAIL]\033[0m %s", msg);
      this_test_pass = 0;
    end
  endtask

  task display_map(string label);
    $display("\n=== %s ===", label);
    for (int i = 0; i < 32; i++) begin
      $display("AR[%0d] -> PR[%0d]", i, arch_map_out[i]);
    end
  endtask

  // =====================================================
  // Test Sequence
  // =====================================================
  initial begin
    $display("\n=== Starting ArchMap Tests ===");
    
    commit_valid                = '{default: 0};
    commit_arch_reg             = '{default: 0};
    commit_phys_reg             = '{default: 0};
    

    @(posedge clock);
    reset_dut();
    @(posedge clock);
    @(posedge clock);
    #10;
    // -----------------------------------------------------
    test_names[test_index] = "Reset Identity Mapping";
    $display("\n=== Test 1: Reset Identity Mapping ===");
    this_test_pass = 1;
    display_map("Arch Map after Reset");
    for (int i = 0; i < 32; i++) begin
      test_message(arch_map_out[i] == i, $sformatf("AR[%0d] == PR[%0d]", i, i));
    end
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Single Commit";
    $display("\n=== Test 2: Single Commit ===");
    display_map("Before Single Commit");
    this_test_pass = 1;
    commit_valid = '{1, 0};
    commit_arch_reg = '{5, 0};
    commit_phys_reg = '{40, 0};
    @(posedge clock);
    display_map("After Single Commit");
    test_message(arch_map_out[5] == 40, "AR[5] → PR40");
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Dual Commit";
    $display("\n=== Test 3: Dual Commit ===");
    display_map("Before Dual Commit");
    this_test_pass = 1;
    commit_valid = '{1, 1};
    commit_arch_reg = '{10, 15};
    commit_phys_reg = '{42, 43};
    @(posedge clock);
    display_map("After Dual Commit");
    test_message(arch_map_out[10] == 42, "AR[10] → PR42");
    test_message(arch_map_out[15] == 43, "AR[15] → PR43");
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Overwrite Mapping";
    $display("\n=== Test 4: Overwrite Mapping ===");
    display_map("Before Overwrite Mapping");
    this_test_pass = 1;
    commit_valid = '{1, 0};
    commit_arch_reg = '{10, 0};
    commit_phys_reg = '{44, 0};
    @(posedge clock);
    display_map("After Overwrite Mapping");
    test_message(arch_map_out[10] == 44, "AR[10] updated → PR44");
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Flush Resets Map";
    $display("\n=== Test 5: Flush ===");
    display_map("Before Flush");
    this_test_pass = 1;
    flush_dut();
    #5;
    display_map("After Flush");
    for (int i = 0; i < 32; i++) begin
      test_message(arch_map_out[i] == i, $sformatf("After flush: AR[%0d] == PR[%0d]", i, i));
    end
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Random Commits";
    $display("\n=== Test 6: Random Commits ===");
    display_map("Before Random Commits");
    this_test_pass = 1;
    for (int cycle = 0; cycle < 5; cycle++) begin
      commit_valid[0] = $urandom_range(0, 1);
      commit_valid[1] = $urandom_range(0, 1);
      commit_arch_reg[0] = $urandom_range(0, 31);
      commit_arch_reg[1] = $urandom_range(0, 31);
      commit_phys_reg[0] = $urandom_range(32, 63);
      commit_phys_reg[1] = $urandom_range(32, 63);
      @(posedge clock);
    end
    display_map("After Random Commits");
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Idle Cycle (no commits)";
    $display("\n=== Test 7: Idle Cycle (no commits) ===");
    display_map("Before Idle Cycle");
    this_test_pass = 1;
    commit_valid = '{0, 0};
    commit_arch_reg = '{0, 0};
    commit_phys_reg = '{0, 0};
    @(posedge clock);
    $display("No change should occur (check manually if needed).");
    display_map("After Idle Cycle");
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    test_names[test_index] = "Back-to-Back Commits";
    $display("\n=== Test 8: Back-to-Back Commits ===");
    display_map("Before Back-to-Back Commits");
    this_test_pass = 1;
    for (int i = 0; i < 3; i++) begin
      commit_valid = '{1, 1};
      commit_arch_reg = '{i*2, i*2+1};
      commit_phys_reg = '{60 - i*2, 60 - i*2 - 1};
      @(posedge clock);
    end
    display_map("After Back-to-Back Commits");
    for (int i = 0; i < 6; i++) begin
      test_message(arch_map_out[i] == (60 - i), $sformatf("AR[%0d] → PR[%0d]", i, 60 - i));
    end
    test_outcomes[test_index++] = this_test_pass;

    @(posedge clock);

    // -----------------------------------------------------
    // Summary
    // -----------------------------------------------------
    $display("\n=== FINAL TEST SUMMARY ===");
    for (int i = 0; i < test_index; i++) begin
      if (test_outcomes[i]) begin
        $display("\033[32m[PASS]\033[0m %s", test_names[i]);
        pass_count++;
      end else begin
        $display("\033[31m[FAIL]\033[0m %s", test_names[i]);
        fail_count++;
      end
    end
    $display("--------------------------------------");
    $display("TOTAL PASSED: %0d, TOTAL FAILED: %0d", pass_count, fail_count);
    $display("--------------------------------------\n");
    $display("\n=== All ArchMap Tests Completed ===");
    #20;
    $finish;
  end

endmodule
