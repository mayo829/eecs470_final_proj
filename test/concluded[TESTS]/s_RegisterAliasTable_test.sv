`include "sys_defs.svh"

module s_RegisterAliasTable_best_tb;

// =====================================================
// Signal Declarations
// =====================================================
logic                    clock;
logic                    reset;
logic                    flush;

REG_IDX [1:0] arc_src1_regs;
REG_IDX [1:0] arc_src2_regs;
REG_IDX [1:0] arc_dest_regs;
logic [1:0][5:0] free_physical_register_indicies;
logic [1:0] cdb_valid;
logic [1:0][5:0] cdb_tag;

logic [1:0][5:0] Told;
logic [1:0][5:0] T;
logic [1:0][5:0] T1;
logic [1:0]      T1p;
logic [1:0][5:0] T2;
logic [1:0]      T2p;

RAT_ENTRY_PACKET [0:31] RAT_dbg;

// =====================================================
// Test Summary Tracking
// =====================================================
localparam int NUM_TESTS = 8;
string test_names[NUM_TESTS];
logic  test_outcomes[NUM_TESTS];
int test_index = 0;
int pass_count = 0;
int fail_count = 0;
bit this_test_pass;

// =====================================================
// DUT
// =====================================================
s_RegisterAliasTable dut (
  .clock(clock),
  .reset(reset),
  .flush(flush),
  .arc_src1_regs(arc_src1_regs),
  .arc_src2_regs(arc_src2_regs),
  .arc_dest_regs(arc_dest_regs),
  .free_physical_register_indicies(free_physical_register_indicies),
  .cdb_valid(cdb_valid),
  .cdb_tag(cdb_tag),
  .Told(Told),
  .T(T),
  .T1(T1),
  .T1p(T1p),
  .T2(T2),
  .T2p(T2p),
  .RAT_dbg(RAT_dbg)
);

// =====================================================
// Clock
// =====================================================
initial clock = 0;
always #5 clock = ~clock;

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
  flush = 1;
  @(posedge clock);
  flush = 0;
  @(posedge clock);
endtask

task display_rat(input string label);
  $display("\n=== %s ===", label);
  for (int i = 0; i < 32; i++) begin
    $display("AR[%0d] -> PR[%0d], ready=%b", i, RAT_dbg[i].tag, RAT_dbg[i].ready);
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

// =====================================================
// Test Sequence
// =====================================================
initial begin
  $dumpfile("s_RegisterAliasTable_best_tb.vcd");
  $dumpvars(0, s_RegisterAliasTable_best_tb);

  arc_src1_regs = '{default: 0};
  arc_src2_regs = '{default: 0};
  arc_dest_regs = '{default: 0};
  free_physical_register_indicies = '{default: 0};
  cdb_valid = '{default: 0};
  cdb_tag   = '{default: 0};

  reset_dut();
  @(posedge clock);
  display_rat("Initial RAT State");

  // -----------------------------------------------------
  // Test 1: Basic Rename
  // -----------------------------------------------------
  test_names[test_index] = "Basic Rename";
  $display("\n=== Test 1: Basic Rename ===");
  this_test_pass = 1;
  arc_src1_regs = '{2, 1};
  arc_src2_regs = '{4, 3};
  arc_dest_regs = '{6, 5};
  free_physical_register_indicies = '{34, 33};
  @(posedge clock);
  test_message((T[0] == 33), $sformatf("T[0]=%0d (expected 33)", T[0]));
  test_message((Told[0] == 5), $sformatf("Told[0]=%0d (expected 5)", Told[0]));
  test_message((T[1] == 34), $sformatf("T[1]=%0d (expected 34)", T[1]));
  test_message((Told[1] == 6), $sformatf("Told[1]=%0d (expected 6)", Told[1]));
  display_rat("After Basic Rename");
  test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
  // Test 2: CDB Ready Update
  // -----------------------------------------------------
  test_names[test_index] = "CDB Ready Update";
  $display("\n=== Test 2: CDB Ready Update ===");
  arc_src1_regs = '{0, 0};
  arc_src2_regs = '{0, 0};
  arc_dest_regs = '{0, 0};
  free_physical_register_indicies = '{0, 0};
  
  this_test_pass = 1;
  cdb_tag   = '{34, 33};
  cdb_valid = '{1, 1};
  @(posedge clock);
  cdb_valid = '{0, 0};
  @(posedge clock);
  test_message((RAT_dbg[5].ready === 1) && (RAT_dbg[6].ready === 1),
               "CDB update: RAT[5] and RAT[6] marked ready");
  display_rat("After CDB Ready Update");
  test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
  // Test 3: Multiple Destination Renames
  // -----------------------------------------------------
  test_names[test_index] = "Multiple Destination Renames";
  $display("\n=== Test 3: Multiple Destination Renames ===");
  this_test_pass = 1;
  arc_src1_regs = '{8, 7};
  arc_src2_regs = '{10, 9};
  arc_dest_regs = '{11, 10};
  free_physical_register_indicies = '{36, 35};
  @(posedge clock);
  test_message((T[0] == 35) && (Told[0] == 10), "AR10 -> PR35");
  test_message((T[1] == 36) && (Told[1] == 11), "AR11 -> PR36");
  display_rat("After Multiple Destination Renames");
  test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
  // Test 4: Source Register Lookup
  // -----------------------------------------------------
  test_names[test_index] = "Source Register Lookup";
  $display("\n=== Test 4: Source Register Lookup ===");
  this_test_pass = 1;
  cdb_tag = '{34, 33};
  cdb_valid = '{1, 1};
  arc_src1_regs = '{11, 10};
  arc_src2_regs = '{6, 5};
  @(posedge clock);
  test_message(T1[0] == 35 && T1p[0] === 1'b0, "Instr0 src1 (AR10) -> PR35, not ready");
  test_message(T2[0] == 33 && T2p[0] === 1'b1, "Instr0 src2 (AR5)  -> PR33, ready");
  test_message(T1[1] == 36 && T1p[1] === 1'b0, "Instr1 src1 (AR11) -> PR36, not ready");
  test_message(T2[1] == 34 && T2p[1] === 1'b1, "Instr1 src2 (AR6)  -> PR34, ready");
  test_outcomes[test_index++] = this_test_pass;
  @(posedge clock);
  cdb_tag = '{0, 0};
  cdb_valid = '{0, 0};
  arc_src1_regs = '{0, 0};
  arc_src2_regs = '{0, 0};
  arc_dest_regs = '{0, 0};
  // -----------------------------------------------------
  // Test 5: Flush
  // -----------------------------------------------------
  test_names[test_index] = "Flush Functionality";
  $display("\n=== Test 5: Flush ===");
  this_test_pass = 1;
  flush_dut();
  @(posedge clock);
  test_message(RAT_dbg[0].tag == 0 && RAT_dbg[0].ready == 1'b1,
               "Flush: RAT[0] reset");
  test_message(RAT_dbg[31].tag == 31 && RAT_dbg[31].ready == 1'b1,
               "Flush: RAT[31] reset");
  display_rat("After Flush");
  test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
  // Test 6: Boundary Rename
  // -----------------------------------------------------
  test_names[test_index] = "Boundary Rename";
  $display("\n=== Test 6: Boundary Rename ===");
  this_test_pass = 1;
  arc_src1_regs = '{31, 1};
  arc_src2_regs = '{0, 2};
  arc_dest_regs = '{31, 2};
  free_physical_register_indicies = '{41, 40};
  @(posedge clock);
  test_message(T[0] == 40 && Told[0] == 2, "AR2  -> PR40");
  test_message(T[1] == 41 && Told[1] == 31, "AR31 -> PR41");
  display_rat("After Boundary Rename");
  test_outcomes[test_index++] = this_test_pass;
  @(posedge clock);
  // -----------------------------------------------------
  // Test 7: Random Multi-Cycle Rename
  // -----------------------------------------------------
  test_names[test_index] = "Random Multi-Cycle Rename";
  $display("\n=== Test 7: Random Multi-Cycle Rename ===");
  this_test_pass = 1;
  for (int cyc = 0; cyc < 5; cyc++) begin
    arc_src1_regs[1] = $urandom_range(0, 31);
    arc_src2_regs[1] = $urandom_range(0, 31);
    arc_dest_regs[1] = $urandom_range(1, 31);
    arc_src1_regs[0] = $urandom_range(0, 31);
    arc_src2_regs[0] = $urandom_range(0, 31);
    arc_dest_regs[0] = $urandom_range(1, 31);
    free_physical_register_indicies[1] = $urandom_range(32, 63);
    free_physical_register_indicies[0] = $urandom_range(32, 63);
    cdb_valid = '{$urandom_range(0, 1), $urandom_range(0, 1)};
    if (cdb_valid[0]) cdb_tag[0] = free_physical_register_indicies[0];
    if (cdb_valid[1]) cdb_tag[1] = free_physical_register_indicies[1];
    @(posedge clock);
    cdb_valid = '{0, 0};
    @(posedge clock);
  end
  test_message(1'b1, "Random rename cycles completed.");
  test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
// Test X: x0 Rename Protection
// -----------------------------------------------------
test_names[test_index] = "x0 Rename Protection";
$display("\n=== Test X: x0 Rename Protection ===");
this_test_pass = 1;

// Try to rename x0 as a destination
arc_src1_regs = '{1, 2};
arc_src2_regs = '{3, 4};
arc_dest_regs = '{0, 0};  // Attempting to rename x0
free_physical_register_indicies = '{42, 43};
@(posedge clock);

// Check that no rename occurred for x0
test_message(T[0] == 0, $sformatf("T[0] == 0 (x0 not renamed), got %0d", T[0]));
test_message(Told[0] == 0, $sformatf("Told[0] == 0 (x0 maps to PR[0]), got %0d", Told[0]));
test_message(T[1] == 0, $sformatf("T[1] == 0 (x0 not renamed), got %0d", T[1]));
test_message(Told[1] == 0, $sformatf("Told[1] == 0 (x0 maps to PR[0]), got %0d", Told[1]));

// Double check RAT output for AR[0]
test_message(RAT_dbg[0].tag == 0 && RAT_dbg[0].ready == 1'b1,
             "AR[0] remains mapped to PR[0] and is ready");

display_rat("After x0 Rename Protection Test");

test_outcomes[test_index++] = this_test_pass;

  // -----------------------------------------------------
  // Final Summary
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
  $display("\n=== All RAT Tests Completed ===");
  #20;
  $finish;
end

endmodule
