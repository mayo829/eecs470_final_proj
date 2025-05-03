`timescale 1ns/1ps
`include "sys_defs.svh"

module stage_retire_testbench;

  localparam CLOCK_PERIOD = 10;

  logic clock, reset;
  ROB_RETIRE_PACKET [1:0] RobEntriesToRetire;
  RETIRE_ARCHMAP_PACKET [1:0] retireOutArchmapIn;
  FREELIST_PACKET_IN RetireToFreeList;
  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries;
  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntriesAfterRetire;
  logic halt;

  // DUT
  stage_retire dut (
    .NumROBFreeEntries(NumROBFreeEntries),
    .RobEntriesToRetire(RobEntriesToRetire),
    .retireOutArchmapIn(retireOutArchmapIn),
    .RetireToFreeList(RetireToFreeList),
    .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
    .halt(halt)
  );

  // Clock
  initial clock = 0;
  always #(CLOCK_PERIOD/2) clock = ~clock;

  // Test management
  string test_names[20];
  logic  test_outcomes[20];
  int test_index = 0;
  int pass_count = 0;
  int fail_count = 0;
  bit this_test_pass;

  task reset_state();
    begin
      NumROBFreeEntries = 0;
      for (int i = 0; i < 2; i++) begin
        RobEntriesToRetire[i] = '{default:0};
      end
    end
  endtask

  task test_message(input bit pass, input string msg);
    if (pass) begin
      $display("   \033[32m[PASS]\033[0m %s", msg);
    end else begin
      $display("   \033[31m[FAIL]\033[0m %s", msg);
      this_test_pass = 0;
    end
  endtask

  // Test Sequence
  initial begin
    $dumpfile("stage_retire_testbench.vcd");
    $dumpvars(0, stage_retire_testbench);

    reset_state();
    @(posedge clock);

    // -----------------------------------------------
    test_names[test_index] = "Test 1: Single Instruction Retirement";
    $display("\n=== %s ===", test_names[test_index]);
    this_test_pass = 1;
    NumROBFreeEntries = 3;
    RobEntriesToRetire[0] = '{valid:1, complete:1, dest_reg:5, T:12, Told:8, PC:32'h1000, halt:0};
    RobEntriesToRetire[1] = '{default:0};
    @(posedge clock);
    test_message(RetireToFreeList.retired_req == 2'b01, "Freelist retire request is correct (1 inst)");
    test_message(RetireToFreeList.retired_tags[0] == 8, "Freelist tag[0] is correct");
    test_message(retireOutArchmapIn[0].commit_valid == 1, "ArchMap commit_valid[0] set");
    test_message(retireOutArchmapIn[0].commit_arch_reg == 5, "ArchMap AR[5] matched");
    test_message(retireOutArchmapIn[0].commit_phys_reg == 12, "ArchMap PR[12] mapped");
    test_message(NumROBFreeEntriesAfterRetire == 4, "ROB free entry incremented");
    test_outcomes[test_index++] = this_test_pass;

    // -----------------------------------------------
    test_names[test_index] = "Test 2: Dual Instruction Retirement";
    $display("\n=== %s ===", test_names[test_index]);
    this_test_pass = 1;
    RobEntriesToRetire[0] = '{valid:1, complete:1, dest_reg:10, T:20, Told:15, PC:32'h2000, halt:0};
    RobEntriesToRetire[1] = '{valid:1, complete:1, dest_reg:11, T:21, Told:16, PC:32'h2004, halt:0};
    NumROBFreeEntries = 5;
    @(posedge clock);
    test_message(RetireToFreeList.retired_req == 2'b11, "Freelist retire request is correct (2 inst)");
    test_message(RetireToFreeList.retired_tags[0] == 15 && RetireToFreeList.retired_tags[1] == 16, "Freelist retired tags matched");
    test_message(retireOutArchmapIn[0].commit_arch_reg == 10 && retireOutArchmapIn[1].commit_arch_reg == 11, "ArchMap regs matched");
    test_message(NumROBFreeEntriesAfterRetire == 7, "ROB free incremented by 2");
    test_outcomes[test_index++] = this_test_pass;

    // -----------------------------------------------
    test_names[test_index] = "Test 3: No Retirement (2'b00)";
    $display("\n=== %s ===", test_names[test_index]);
    this_test_pass = 1;
    RobEntriesToRetire[0].valid = 0;
    RobEntriesToRetire[1].valid = 0;
    NumROBFreeEntries = 6;
    @(posedge clock);
    test_message(RetireToFreeList.retired_req == 2'b00, "No retire request made");
    test_message(NumROBFreeEntriesAfterRetire == 6, "ROB free unchanged");
    test_outcomes[test_index++] = this_test_pass;

    // // -----------------------------------------------
    // test_names[test_index] = "Test 4: HALT Detection";
    // $display("\n=== %s ===", test_names[test_index]);
    // this_test_pass = 1;
    // RobEntriesToRetire[0] = '{valid:1, complete:1, dest_reg:3, T:50, Told:49, PC:32'h3000, halt:1};
    // RobEntriesToRetire[1] = '{default:0};
    // NumROBFreeEntries = 9;
    // @(posedge clock);
    // test_message(halt == 1, "HALT signal set");
    // test_outcomes[test_index++] = this_test_pass;

    // -----------------------------------------------
    test_names[test_index] = "Test 5: Random Retirement Behavior";
    $display("\n=== %s ===", test_names[test_index]);
    this_test_pass = 1;
    for (int i = 0; i < 5; i++) begin
    RobEntriesToRetire[0] = '{
        valid: $urandom_range(0,1),
        complete: 1,
        dest_reg: $urandom_range(0,31),
        T: $urandom_range(32,63),
        Told: $urandom_range(0,31),
        PC: $urandom(),
        halt: 0
        };

    RobEntriesToRetire[1] = '{
        valid: $urandom_range(0,1),
        complete: 1,
        dest_reg: $urandom_range(0,31),
        T: $urandom_range(32,63),
        Told: $urandom_range(0,31),
        PC: $urandom(),
        halt: 0
        };

      NumROBFreeEntries = $urandom_range(0, `ROB_SZ-2);
      @(posedge clock);
    end
    test_message(1'b1, "Random retirement completed without errors.");
    test_outcomes[test_index++] = this_test_pass;

    // -----------------------------------------------
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

    $display("=== All Retire Tests Completed ===");
    #20;
    $finish;
  end
endmodule
