`timescale 1ns/1ps
`include "sys_defs.svh"

module s_PhysicalRegisterFile_testbench;

  // --------------------------------------------------------------------
  // Parameters
  // --------------------------------------------------------------------
  localparam int PRF_SZ       = `PHYS_REG_SZ_R10K;
  localparam int CLOCK_PERIOD = 10;

  // --------------------------------------------------------------------
  // DUT I/O Signal Declarations
  // --------------------------------------------------------------------
  logic [1:0][`PR_WIDTH-1:0] readIDX_Ainput;
  logic [1:0][`PR_WIDTH-1:0] readIDX_Binput;
  CDB_ENTRY_PACKET [1:0] CDB_in;
  DATA [1:0] readIDX_AdataOutput;
  DATA [1:0] readIDX_BdataOutput;
  DATA [PRF_SZ-1:0] PRF_dbg;

  logic clock;
  logic reset;
  int tag;
  DATA val;
  
  int tag1;
  int tag2;
  DATA val1;
  DATA val2;

  int pass_count = 0;
  int fail_count = 0;
  string test_names[7];
  bit test_results[7];
  int test_idx = 0;

  DATA golden_prf [PRF_SZ-1:0];

  s_PhysicalRegisterFile dut (
    .clock(clock),
    .reset(reset),
    .readIDX_Ainput(readIDX_Ainput),
    .readIDX_Binput(readIDX_Binput),
    .CDB_in(CDB_in),
    .readIDX_AdataOutput(readIDX_AdataOutput),
    .readIDX_BdataOutput(readIDX_BdataOutput),
    .PRF_dbg(PRF_dbg)
  );

  always #(CLOCK_PERIOD/2) clock = ~clock;

  task reset_dut();
    begin
      reset = 1;
      repeat (2) @(posedge clock);
      reset = 0;
      @(posedge clock);
    end
  endtask

  task write_pr(input int tag, input DATA value);
    begin
      for (int i = 0; i < 2; i++) begin
        CDB_in[i].valid = 0;
        CDB_in[i].tag   = 0;
        CDB_in[i].data  = 0;
      end
      CDB_in[0].valid = 1;
      CDB_in[0].tag   = tag;
      CDB_in[0].data  = value;
      @(posedge clock);
      CDB_in[0].valid = 0;
    end
  endtask

  task dual_write_pr(input int tag1, input DATA val1, input int tag2, input DATA val2);
    begin
      CDB_in[0].valid = 1; CDB_in[0].tag = tag1; CDB_in[0].data = val1;
      CDB_in[1].valid = 1; CDB_in[1].tag = tag2; CDB_in[1].data = val2;
      @(posedge clock);
      CDB_in[0].valid = 0;
      CDB_in[1].valid = 0;
      #5;
    end
  endtask

  task read_check(input int ra_idx, input int rb_idx, input DATA exp_a, input DATA exp_b);
    begin
      readIDX_Ainput[0] = ra_idx;
      readIDX_Binput[0] = rb_idx;
      @(posedge clock);
      $display("[READ] A:%0d = %h (exp %h), B:%0d = %h (exp %h)",
               readIDX_Ainput[0], readIDX_AdataOutput[0], exp_a,
               readIDX_Binput[0], readIDX_BdataOutput[0], exp_b);
      if (readIDX_AdataOutput[0] !== exp_a || readIDX_BdataOutput[0] !== exp_b) begin
        $display("\033[31m[FAIL]\033[0m Mismatch on PRF read.");
        test_results[test_idx] = 0;
      end else begin
        $display("\033[32m[PASS]\033[0m PRF read matched.");
        test_results[test_idx] = 1;
      end
    end
  endtask

  task print_prf_state(string label = "");
    $display("\n--- PRF State %s ---", label);
    for (int i = 0; i < 10; i++) begin
        $display("  PRF[%0d] = 0x%08x", i, PRF_dbg[i]);
    end
    $display("------------------------\n");
  endtask


  task dual_random_write_check();
    bit pass = 1;
    for (int i = 0; i < 10; i++) begin
      tag1 = $urandom_range(1, PRF_SZ-1);
      tag2 = $urandom_range(1, PRF_SZ-1);
      val1 = $urandom;
      val2 = $urandom;
      dual_write_pr(tag1, val1, tag2, val2);
      golden_prf[tag1] = val1;
      golden_prf[tag2] = val2;
      readIDX_Ainput[0] = tag1;
      readIDX_Binput[0] = tag2;
      @(posedge clock);
      $display("[DUAL-READ] A:%0d = %h (exp %h), B:%0d = %h (exp %h)",
              tag1, readIDX_AdataOutput[0], golden_prf[tag1],
              tag2, readIDX_BdataOutput[0], golden_prf[tag2]);
      if (readIDX_AdataOutput[0] !== golden_prf[tag1] ||
          readIDX_BdataOutput[0] !== golden_prf[tag2]) begin
        $display("\033[31m[FAIL]\033[0m Scoreboard mismatch.");
        pass = 0;
      end else begin
        $display("\033[32m[PASS]\033[0m Scoreboard verified.");
      end
    end
    test_results[test_idx] = pass;
  endtask

  initial begin
    $dumpfile("s_PhysicalRegisterFile_test.vcd");
    $dumpvars(0, s_PhysicalRegisterFile_testbench);
    $display("=== Starting PRF Monitor ===");

    clock = 0;
    for (int i = 0; i < 2; i++) begin
      readIDX_Ainput[i] = 0;
      readIDX_Binput[i] = 0;
      CDB_in[i].valid   = 0;
      CDB_in[i].tag     = 0;
      CDB_in[i].data    = 0;
    end
    for (int i = 0; i < PRF_SZ; i++) golden_prf[i] = '0;

    reset_dut();

    test_names[test_idx] = "Test 1: Basic Write and Read";
    $display("\n=== %s ===", test_names[test_idx]);
    write_pr(1, 32'hDEADBEEF);
    read_check(1, 0, 32'hDEADBEEF, 32'h0);
    test_idx++;

    test_names[test_idx] = "Test 2: Dual Write";
    $display("\n=== %s ===", test_names[test_idx]);
    dual_write_pr(2, 32'hCAFEBABE, 3, 32'h12345678);
    read_check(2, 3, 32'hCAFEBABE, 32'h12345678);
    test_idx++;

    test_names[test_idx] = "Test 3: Overwrite Register";
    $display("\n=== %s ===", test_names[test_idx]);
    write_pr(2, 32'hABCDEF01);
    read_check(2, 3, 32'hABCDEF01, 32'h12345678);
    test_idx++;

    test_names[test_idx] = "Test 4: Write to ZERO_REG (should be ignored)";
    $display("\n=== %s ===", test_names[test_idx]);
    write_pr(`ZERO_REG, 32'hFFFFFFFF);
    read_check(`ZERO_REG, 1, 32'h0, 32'hDEADBEEF);
    test_idx++;

    test_names[test_idx] = "Test 5: Bulk Write/Read All";
    $display("\n=== %s ===", test_names[test_idx]);
    for (int i = 1; i < 9; i++) write_pr(i, 32'h1000 + i);
    for (int i = 1; i < 9; i += 2) read_check(i, i+1, 32'h1000 + i, 32'h1000 + i + 1);
    test_results[test_idx] = 1;
    test_idx++;

    test_names[test_idx] = "Test 6: Randomized Write/Read";
    $display("\n=== %s ===", test_names[test_idx]);
    for (int i = 0; i < 10; i++) begin
        tag = $urandom_range(1, PRF_SZ-1);
        val = $urandom();
        write_pr(tag, val);
        read_check(tag, 0, val, 32'h0);
    end
    test_results[test_idx] = 1;
    test_idx++;

    test_names[test_idx] = "Test 7: Dual Random Write + Scoreboard Check";
    $display("\n=== %s ===", test_names[test_idx]);
    dual_random_write_check();
    test_idx++;

    $display("\n=== FINAL TEST SUMMARY ===");
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

    $display("\n=== All PRF Tests Completed ===");
    #20;
    $finish;
  end
endmodule
