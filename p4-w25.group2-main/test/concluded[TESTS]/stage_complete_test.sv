`include "sys_defs.svh"

module stage_complete_test;
  // Clock & Reset
  logic clock, reset;

  // Inputs to DUT
  COMPLETE_PACKET [3:0] complete_in;

  // Outputs from DUT
  logic [3:0] complete_stall;
  CDB_ENTRY_PACKET [1:0] complete_cdb_out;

  // DUT instantiation
  stage_complete dut (
    .clock(clock),
    .reset(reset),
    .complete_in(complete_in),
    .complete_stall(complete_stall),
    .complete_cdb_out(complete_cdb_out)
  );

  // Clock generation
  initial clock = 0;
  always #5 clock = ~clock;

  // Test tracking
  string test_names[15];
  bit test_results[15];
  int test_idx = 0;
  int pass_count = 0;
  int fail_count = 0;

  // Task to reset the DUT
  task reset_dut();
    reset = 1;
    @(posedge clock);
    @(posedge clock);
    reset = 0;
    @(posedge clock);
    @(posedge clock);
  endtask

  // Task to apply a single packet
  task apply_packet(int idx, bit valid, logic [5:0] tag, DATA data);
    complete_in[idx].valid         = valid;
    complete_in[idx].dest_reg_idx  = tag;
    complete_in[idx].result        = data;
  endtask

  // Task to apply two packets at once
  task apply_two_packets(
    int idx0, bit valid0, logic [5:0] tag0, DATA data0,
    int idx1, bit valid1, logic [5:0] tag1, DATA data1
  );
    complete_in[idx0].valid         = valid0;
    complete_in[idx0].dest_reg_idx  = tag0;
    complete_in[idx0].result        = data0;

    complete_in[idx1].valid         = valid1;
    complete_in[idx1].dest_reg_idx  = tag1;
    complete_in[idx1].result        = data1;
  endtask

  // Task to clear all input packets
  task clear_inputs();
    for (int i = 0; i < 4; i++) begin
      complete_in[i].valid        = 0;
      complete_in[i].dest_reg_idx = 0;
      complete_in[i].result       = 0;
    end
  endtask

  // Task to check the CDB output valid bits
  task check_cdb_output(bit expected_valid0, bit expected_valid1);
    if ((complete_cdb_out[0].valid !== expected_valid0) ||
        (complete_cdb_out[1].valid !== expected_valid1)) begin
      $display("\033[31m[FAIL]\033[0m Expected valid0 = %0b, valid1 = %0b, got %0b, %0b",
               expected_valid0, expected_valid1,
               complete_cdb_out[0].valid, complete_cdb_out[1].valid);
      test_results[test_idx] = 0;
    end else begin
      $display("\033[32m[PASS]\033[0m Valid bits OK: %0b, %0b",
               complete_cdb_out[0].valid, complete_cdb_out[1].valid);
      test_results[test_idx] = 1;
    end
  endtask

  // =================== Test Sequence =====================
  initial begin
    // Monitor key signals
    $monitor("[%0t] complete_in = {%b, %b, %b, %b} | grant_mask = %b | CDB0: {v=%b, t=%0d, d=0x%h} | CDB1: {v=%b, t=%0d, d=0x%h}",
         $time,
         complete_in[3].valid, complete_in[2].valid,
         complete_in[1].valid, complete_in[0].valid,
         dut.grant_mask,
         complete_cdb_out[0].valid, complete_cdb_out[0].tag, complete_cdb_out[0].data,
         complete_cdb_out[1].valid, complete_cdb_out[1].tag, complete_cdb_out[1].data
    );

    // Initialize inputs
    reset = 0;
    @(posedge clock);
    for (int i = 0; i < 4; i++) begin
      complete_in[i].valid         = 0;
      complete_in[i].dest_reg_idx  = 0;
      complete_in[i].result        = 0;
    end 

    @(posedge clock);
    reset_dut();
    $display("\n=== Starting Complete Stage Tests ===\n");
    @(posedge clock);
    reset_dut();
    @(posedge clock);

    // Test 1: Zero valid inputs
    test_names[test_idx] = "Test 1: Zero valid inputs";
    clear_inputs();
    @(posedge clock);
    check_cdb_output(0, 0);
    test_idx++;

    // Test 2: One valid input (index 0)
    test_names[test_idx] = "Test 2: One valid input (index 0)";
    clear_inputs();
    apply_packet(0, 1, 6'd1, 32'h11111111);
    @(posedge clock);
    check_cdb_output(1, 0);
    test_idx++;

    // Test 3: One valid input (index 2)
    test_names[test_idx] = "Test 3: One valid input (index 2)";
    clear_inputs();
    apply_packet(2, 1, 6'd2, 32'h22222222);
    @(posedge clock);
    check_cdb_output(1, 0);
    test_idx++;

    // Test 4: Two valid inputs (indices 0 and 1)
    test_names[test_idx] = "Test 4: Two valid inputs (indices 0 and 1)";
    clear_inputs();
    apply_two_packets(0, 1, 6'd3, 32'h33333333, 1, 1, 6'd4, 32'h44444444);
    @(posedge clock);
    check_cdb_output(1, 1);
    test_idx++;

    // Test 5: Three valid inputs (indices 0, 1, 2) - only two should grant
    test_names[test_idx] = "Test 5: Three valid inputs (indices 0,1,2)";
    clear_inputs();
    apply_packet(0, 1, 6'd5, 32'h55555555);
    apply_packet(1, 1, 6'd6, 32'h66666666);
    apply_packet(2, 1, 6'd7, 32'h77777777);
    @(posedge clock);
    check_cdb_output(1, 1);
    test_idx++;

    // Test 6: All four valid inputs
    test_names[test_idx] = "Test 6: All four valid inputs";
    clear_inputs();
    for (int i = 0; i < 4; i++) begin
      apply_packet(i, 1, 6'd10 + i, 32'hAAAA0000 + i);
    end
    @(posedge clock);
    check_cdb_output(1, 1);
    $display("  Stalls: %b", complete_stall);
    test_idx++;

    // Test 7: Random mix (only indices 1 and 2 valid)
    test_names[test_idx] = "Test 7: Random mix (indices 1 and 2 valid)";
    clear_inputs();
    apply_packet(0, 0, 6'd0, 32'h0);
    apply_packet(1, 1, 6'd11, 32'hDEAD0001);
    apply_packet(2, 1, 6'd12, 32'hDEAD0002);
    apply_packet(3, 0, 6'd0, 32'h0);
    @(posedge clock);
    check_cdb_output(1, 1);
    test_idx++;

    // Test 8: Only last input valid (index 3)
    test_names[test_idx] = "Test 8: Only last input valid (index 3)";
    clear_inputs();
    apply_packet(3, 1, 6'd20, 32'hCAFEBABE);
    @(posedge clock);
    check_cdb_output(1, 0);
    test_idx++;

    // Test 9: Two valid non-adjacent (indices 1 and 3)
    test_names[test_idx] = "Test 9: Two valid inputs (indices 1 and 3)";
    clear_inputs();
    apply_packet(1, 1, 6'd30, 32'h12345678);
    apply_packet(3, 1, 6'd31, 32'h87654321);
    @(posedge clock);
    check_cdb_output(1, 1);
    test_idx++;

    // Test 10: Sequential tests over multiple cycles
    test_names[test_idx] = "Test 10: Sequential tests over multiple cycles";
    clear_inputs();
    // Cycle 1: Only index 0 valid
    apply_packet(0, 1, 6'd40, 32'hAAAA1111);
    @(posedge clock);
    check_cdb_output(1, 0);
    clear_inputs();
    // Cycle 2: Indices 0 and 2 valid
    apply_packet(0, 1, 6'd41, 32'hAAAA2222);
    apply_packet(2, 1, 6'd42, 32'hAAAA3333);
    @(posedge clock);
    check_cdb_output(1, 1);
    test_idx++;

    // FINAL SUMMARY
    $display("\n=== FINAL TEST SUMMARY ===");
    pass_count = 0;
    fail_count = 0;
    for (int i = 0; i < test_idx; i++) begin
      if (test_results[i]) begin
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

    $display("=== Complete Stage Testbench Finished ===\n");
    #20;
    $finish;
  end
endmodule
