// `include "sys_defs.svh"
 `include "ISA.svh"


// module cpu_test;

//   localparam CLOCK_PERIOD = 10;
//   logic clock = 0;
//   always #(CLOCK_PERIOD/2) clock = ~clock;

//   logic reset, flush, testing;
//   FETCH_DISPATCH_PACKET fetched [2];
//   COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt_TESTBENCH;

//   logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries, NumROBFreeEntriesAfterRetire;
//   logic halt;
//   logic [31:0][`PR_WIDTH:0] arch_map_out;
//   DATA [`PHYS_REG_SZ_R10K-1:0] PRF_dbg;
//   CDB_ENTRY_PACKET [1:0] complete_cdb_reg;
//   ISSUE_PACKET [`NUM_FU-1:0] S_out_packet;
//   COMMIT_PACKET [`N-1:0] committed_insts;
//   logic [`ROB_PTR_WIDTH:0] total_num_free_dbg;


//   cpu dut (
//     .clock(clock), .reset(reset), .flush(flush), .testing(testing),
//     .fetched_in(fetched),
//     .ex_to_complete_pkt_TESTBENCH(ex_to_complete_pkt_TESTBENCH),
//     .NumROBFreeEntries(NumROBFreeEntries),
//     .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
//     .halt(halt),
//     .arch_map_out(arch_map_out),
//     .PRF_dbg(PRF_dbg),
//     .complete_cdb_reg(complete_cdb_reg),
//     .S_out_packet(S_out_packet),
//     .committed_insts(committed_insts),
//     .total_num_free_dbg(total_num_free_dbg)

//   );
  

//   task reset_all();
//     begin
//       reset = 1;
//       flush = 0;
//       testing = 1;
//       fetched = '{default:0};
//       ex_to_complete_pkt_TESTBENCH = '{default:0};
//       @(posedge clock); @(posedge clock);
//       reset = 0;
//       @(posedge clock);
//     end
//   endtask

//   // Helper function to decode instruction type
//   function string inst_to_string(input INST inst);
//     case (inst.r.opcode)
//       7'b1110011: begin // SYSTEM opcode
//         if (inst.r.funct3 == 3'b000 && inst.r.funct7 == 7'b0001000 && inst.r.rs2 == 5'b00101)
//           return "WFI";
//         else
//           return "SYSTEM";
//       end
//       7'b0010011: return "I-type";
//       7'b0110011: return "R-type";
//       7'b0100011: return "S-type";
//       7'b1100011: return "B-type";
//       7'b0110111: return "U-type";
//       7'b1101111: return "J-type";
//       default: return "UNKNOWN";
//     endcase
//   endfunction

//   task show_pipeline;
//     begin


//       // Dispatch Stage
//       $display("\n--- Dispatch Stage ---");
//       for (int i = 0; i < `N; i++) begin
//         if (dut.dispatch_inst.rob_out[i].valid) begin
//           $display("DISPATCH[%0d]: PC=0x%08x dest_AR=%0d T=%0d Told=%0d halt=%b",
//             i,
//             dut.dispatch_inst.rob_out[i].PC,
//             dut.dispatch_inst.rob_out[i].dest_reg,
//             dut.dispatch_inst.rob_out[i].TD,
//             dut.dispatch_inst.rob_out[i].Told,
//             dut.dispatch_inst.rob_out[i].halt);
//         end
//       end

//       $display("Head = %0d | Tail = %0d | Total Free = %0d", 
//          dut.head_dbg, dut.tail_dbg, total_num_free_dbg);


//       // Reservation Stations
//       $display("\n--- Reservation Stations ---");
//       for (int i = 0; i < `RS_SZ; i++) begin
//         if (dut.rs_inst.rs[i].valid) begin
//           $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d",
//             i,
//             dut.rs_inst.rs[i].valid,
//             dut.rs_inst.rs[i].busy,
//             dut.rs_inst.rs[i].T1,
//             dut.rs_inst.rs[i].T1p,
//             dut.rs_inst.rs[i].T2,
//             dut.rs_inst.rs[i].T2p,
//             dut.rs_inst.rs[i].TD);
//         end
//       end

//       // Issue to Execute
//       $display("\n--- Issue → Execute ---");
//       for (int i = 0; i < `NUM_FU; i++) begin
//         if (S_out_packet[i].valid) begin
//           $display("FU[%0d]: PC=0x%08x TD=%0d",
//             i,
//             S_out_packet[i].PC,
//             S_out_packet[i].dest_reg_idx);
//         end
//       end

//       // Execute Stage
//       $display("\n--- Execute Stage ---");
//       for (int i = 0; i < `NUM_FU; i++) begin
//         if (dut.ex_stage.C_packet[i].valid) begin
//           $display("FU[%0d]: PC=0x%08x TD=%0d result=0x%08x",
//             i,
//             dut.ex_stage.C_packet[i].PC,
//             dut.ex_stage.C_packet[i].dest_reg_idx,
//             dut.ex_stage.C_packet[i].result);
//         end
//       end

//       // ROB
//       $display("\n--- Reorder Buffer ---");
//       for (int i = 0; i < 8; i++) begin
//         if (dut.rob_inst.rob_entries[i].valid) begin
//           $display("ROB[%0d]: valid=%b complete=%b PC=0x%08x AR=%0d T=%0d Told=%0d halt=%b",
//             i,
//             dut.rob_inst.rob_entries[i].valid,
//             dut.rob_inst.rob_entries[i].complete,
//             dut.rob_inst.rob_entries[i].PC,
//             dut.rob_inst.rob_entries[i].dest_reg,
//             dut.rob_inst.rob_entries[i].T,
//             dut.rob_inst.rob_entries[i].Told,
//             dut.rob_inst.rob_entries[i].halt);
//         end
//       end

//       // CDB
//       $display("\n--- Common Data Bus ---");
//       for (int i = 0; i < 2; i++) begin
//         if (complete_cdb_reg[i].valid) begin
//           $display("CDB[%0d]: T=%0d Data=0x%08x",
//             i,
//             complete_cdb_reg[i].tag,
//             complete_cdb_reg[i].data);
//         end
//       end

//       $display("\n--- Physical Register File (PRF) ---");
//     for (int i = 31; i < 48; i++) begin
//       $display("PRF[%0d] = 0x%08h", i, PRF_dbg[i]);
//     end
//     // ArchMap
//     $display("\n--- Architectural Map Table ---");
//     for (int i = 0; i < 8; i++) begin
//       $display("AR[%0d] → PR[%0d]", i, arch_map_out[i]);
//     end

    

//       // Halt Status
//       $display("\n--- Halt Status ---");
//       $display("Halt signal: %b", {committed_insts[1].halt, committed_insts[0].halt});
//       if (committed_insts[0].valid && 
//               committed_insts[0].halt || committed_insts[1].valid && 
//               committed_insts[1].halt) begin
//         $display("  ^^^ PROCESSOR HALTED ^^^");
//       end
//     end
//   endtask

//   initial begin
//     int cycle = 0;
//     $display("\n=== CPU WFI Instruction Test ===\n");
//     $display("Testing WFI (Wait For Interrupt) instruction flow through pipeline\n");

//     reset_all();

//     $dumpfile("../dump/wfi_test.vcd");
//     $dumpvars(0, cpu_test);

//     // Initialize PRF with some values
//     ex_to_complete_pkt_TESTBENCH[0].valid = 1;
//     ex_to_complete_pkt_TESTBENCH[0].dest_reg_idx = 6'd1;
//     ex_to_complete_pkt_TESTBENCH[0].result = 32'hCAFE0000;

//     ex_to_complete_pkt_TESTBENCH[1].valid = 1;
//     ex_to_complete_pkt_TESTBENCH[1].dest_reg_idx = 6'd2;
//     ex_to_complete_pkt_TESTBENCH[1].result = 32'h0000BEEF;

//     @(posedge clock);
//     ex_to_complete_pkt_TESTBENCH = '{default:0};
//     testing = 0;
    
//     // Feed WFI instruction (0x10500073) followed by NOP
//     fetched[0].valid = 1;
//     fetched[0].inst  = 32'h00208133; // WFI (encoded as csrrwi x0, 0x105, 0)
//     fetched[0].PC    = 32'h1000;
//     fetched[0].NPC   = 32'h1004;

//     fetched[1].valid = 1;
//     fetched[1].inst  = `WFI; // nop
//     fetched[1].PC    = 32'h1004;
//     fetched[1].NPC   = 32'h1008;

//     // Run for enough cycles to see WFI go through entire pipeline
//     repeat (4) begin
//       @(posedge clock);
//       fetched = '{default:0}; // Only feed instructions first cycle
//       testing = 0;
//       #1;
//       $display("\n==================== CYCLE %0d ====================\n", cycle++);

//       show_pipeline();
      
//       // Check if we should terminate early if halt is detected
//       if (committed_insts[0].halt || committed_insts[1].halt) begin
//         $display("\n=== WFI Halt Detected - Test Successful ===");
//         $display("Processor halted as expected after WFI instruction retirement");
//         $display("WFI instruction completed in %0d cycles", cycle);
//         $finish;
//       end
//     end

//     if (!committed_insts[0].halt || !committed_insts[1].halt) begin
//       $display("\n=== TEST FAILED ===");
//       $display("Processor did not halt after WFI instruction retirement");
//       $display("Possible issues:");
//       $display("1. WFI instruction not properly recognized");
//       $display("2. Halt signal not generated on WFI retirement");
//       $display("3. Pipeline stall issues preventing WFI from retiring");
//     end
    
//     $finish;
//   end
// endmodule



`include "sys_defs.svh"

module cpu_test;

  localparam CLOCK_PERIOD = 50;
  logic clock = 0;
  always #(CLOCK_PERIOD/2) clock = ~clock;

  logic reset, flush, testing;
  FETCH_DISPATCH_PACKET fetched [2];
  COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt_TESTBENCH;

  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries, NumROBFreeEntriesAfterRetire;
  logic halt;
  logic [31:0][`PR_WIDTH:0] arch_map_out;
  DATA [`PHYS_REG_SZ_R10K-1:0] PRF_dbg;
  CDB_ENTRY_PACKET [1:0] complete_cdb_reg;
  ISSUE_PACKET [`NUM_FU-1:0] S_out_packet;

  RAT_ENTRY_PACKET [0:31] RAT_dbg;

  COMMIT_PACKET [`N-1:0] committed_insts;

  logic [`ROB_PTR_WIDTH:0] NumFreeListFreeEntriesAfterRetire_dbg;
  logic [$clog2(`RS_SZ):0] NumFreeRSEntriesAfterIssue_dbg;
  logic [1:0] dispatch_request_dbg;




  cpu dut (
    .clock(clock), .reset(reset), .flush(flush), .testing(testing),
    .fetched_in(fetched),
    .ex_to_complete_pkt_TESTBENCH(ex_to_complete_pkt_TESTBENCH),
    .NumROBFreeEntries(NumROBFreeEntries),
    .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
    .halt(halt),
    .arch_map_out(arch_map_out),
    .PRF_dbg(PRF_dbg),
    .complete_cdb_reg(complete_cdb_reg),
    .committed_insts(committed_insts),
    .S_out_packet(S_out_packet),
    .RAT_dbg(RAT_dbg),
    .NumFreeListFreeEntriesAfterRetire_dbg(NumFreeListFreeEntriesAfterRetire_dbg),
    .NumFreeRSEntriesAfterIssue_dbg(NumFreeRSEntriesAfterIssue_dbg),
    .dispatch_request_dbg(dispatch_request_dbg)

  );

  task reset_all();
    begin
      reset = 1;
      flush = 0;
      testing = 1;
      fetched = '{default:0};
      ex_to_complete_pkt_TESTBENCH = '{default:0};
      @(posedge clock); @(posedge clock);
      reset = 0;
      @(posedge clock);
    end
  endtask

  function string func_unit_to_string(FUNC_UNIT fu);
  case (fu)
    ALU0:    return "ALU0";
    ALU1:    return "ALU1";
    MULT:    return "MULT";
    BRANCH:  return "BRANCH";
    default: return "UNKNOWN";
  endcase
endfunction


function string alu_func_to_string(ALU_FUNC af);
  case (af)
    ALU_ADD: return "ADD";
    ALU_SUB: return "SUB";
    ALU_AND: return "AND";
    ALU_OR:  return "OR";
    ALU_SLL: return "SLL";
    ALU_SRL: return "SRL";
    ALU_SLT: return "SLT";
    default: return "???";
  endcase
endfunction

function string mult_func_to_string(MULT_FUNC mf);
  case (mf)
    M_MUL: return "MUL";
    M_MULH: return "MULH";
    default: return "???";
  endcase
endfunction



initial begin
  int cycle = 0;
  $display("\n=== CPU Integration Test: Full Pipeline Visibility ===\n");

  reset_all();

  $dumpfile("../dump/test.vcd");
  $dumpvars(0, cpu_test);

  // Initialize PRF manually (fake values to PRF for operands)
  ex_to_complete_pkt_TESTBENCH[0].valid = 1;
  ex_to_complete_pkt_TESTBENCH[0].dest_reg_idx = 6'd1;
  ex_to_complete_pkt_TESTBENCH[0].result = 32'h11111111;

  ex_to_complete_pkt_TESTBENCH[1].valid = 1;
  ex_to_complete_pkt_TESTBENCH[1].dest_reg_idx = 6'd2;
  ex_to_complete_pkt_TESTBENCH[1].result = 32'h11111111;

  @(posedge clock);
  ex_to_complete_pkt_TESTBENCH = '{default:0};
  testing = 0;

  // Feed two instructions
  fetched[0].valid = 1;
  fetched[0].inst  = 32'h00208133; // add x2, x1, x2
  fetched[0].PC    = 32'h1000;
  fetched[0].NPC   = 32'h1004;

  fetched[1].valid = 1;
  fetched[1].inst  = 32'h00208133; // add x2, x1, x2
  fetched[1].PC    = 32'h1004;
  fetched[1].NPC   = 32'h1008;
  #1;
    //     $display("\n--- RS Entries ---");
    // for (int i = 0; i < `RS_SZ; i++) begin
    //   $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x PC=0x%08x",
    //     i,
    //     dut.rs_inst.rs[i].valid,
    //     dut.rs_inst.rs[i].busy,
    //     dut.rs_inst.rs[i].T1,
    //     dut.rs_inst.rs[i].T1p,
    //     dut.rs_inst.rs[i].T2,
    //     dut.rs_inst.rs[i].T2p,
    //     dut.rs_inst.rs[i].TD,
    //     dut.rs_inst.rs[i].inst,
    //     dut.rs_inst.rs[i].PC);
    // end
      $display("\n--- Dispatch Counters ---");
    $display("NumFreeListFreeEntriesAfterRetire = %0d", NumFreeListFreeEntriesAfterRetire_dbg);
    $display("NumFreeRSEntriesAfterIssue        = %0d", NumFreeRSEntriesAfterIssue_dbg);
    $display("Dispatch Request                   = 2'b%b", dispatch_request_dbg);
        $display("\n--- Register Alias Table (RAT) ---");
    for (int i = 0; i < 8; i++) begin
      $display("AR[%0d] → PR[%0d] (ready=%b)", 
              i, dut.RAT_dbg[i].tag, dut.RAT_dbg[i].ready);
    end
    

  // Step pipeline for a number of cycles
  @(posedge clock);

    fetched[0].valid = 1;
    fetched[0].inst  = 32'h00208133; // WFI (encoded as csrrwi x0, 0x105, 0)
    fetched[0].PC    = 32'h1008;
    fetched[0].NPC   = 32'h100C;

    fetched[1].valid = 1;
    fetched[1].inst  = 32'h00208133;
    fetched[1].PC    = 32'h100C;
    fetched[1].NPC   = 32'h1010;
    #1;
      $display("\n--- Dispatch Counters ---");
      $display("NumFreeListFreeEntriesAfterRetire = %0d", NumFreeListFreeEntriesAfterRetire_dbg);
      $display("NumFreeRSEntriesAfterIssue        = %0d", NumFreeRSEntriesAfterIssue_dbg);
      $display("Dispatch Request                   = 2'b%b", dispatch_request_dbg);
        $display("\n--- RS Entries ---");
    for (int i = 0; i < `RS_SZ; i++) begin
      $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x PC=0x%08x",
        i,
        dut.rs_inst.rs[i].valid,
        dut.rs_inst.rs[i].busy,
        dut.rs_inst.rs[i].T1,
        dut.rs_inst.rs[i].T1p,
        dut.rs_inst.rs[i].T2,
        dut.rs_inst.rs[i].T2p,
        dut.rs_inst.rs[i].TD,
        dut.rs_inst.rs[i].inst,
        dut.rs_inst.rs[i].PC);
    end
    
        $display("\n--- Register Alias Table (RAT) ---");
    for (int i = 0; i < 8; i++) begin
      $display("AR[%0d] → PR[%0d] (ready=%b)", 
              i, dut.RAT_dbg[i].tag, dut.RAT_dbg[i].ready);
    end

  @(posedge clock);
  fetched[0].valid = 1;
  fetched[0].inst  = `WFI; // WFI (encoded as csrrwi x0, 0x105, 0)
  fetched[0].PC    = 32'h1010;
  fetched[0].NPC   = 32'h1014;

  fetched[1].valid = 0;
  fetched[1].inst  = `WFI; // nop
  fetched[1].PC    = 32'h1014;
  fetched[1].NPC   = 32'h1018;
  #1;
  $display("\n--- Dispatch Counters ---");
  $display("NumFreeListFreeEntriesAfterRetire = %0d", NumFreeListFreeEntriesAfterRetire_dbg);
  $display("NumFreeRSEntriesAfterIssue        = %0d", NumFreeRSEntriesAfterIssue_dbg);
  $display("Dispatch Request                   = 2'b%b", dispatch_request_dbg);


        $display("\n--- RS Entries ---");
    for (int i = 0; i < `RS_SZ; i++) begin
      $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x PC=0x%08x",
        i,
        dut.rs_inst.rs[i].valid,
        dut.rs_inst.rs[i].busy,
        dut.rs_inst.rs[i].T1,
        dut.rs_inst.rs[i].T1p,
        dut.rs_inst.rs[i].T2,
        dut.rs_inst.rs[i].T2p,
        dut.rs_inst.rs[i].TD,
        dut.rs_inst.rs[i].inst,
        dut.rs_inst.rs[i].PC);
    end
    
        $display("\n--- Register Alias Table (RAT) ---");
    for (int i = 0; i < 8; i++) begin
      $display("AR[%0d] → PR[%0d] (ready=%b)", 
              i, dut.RAT_dbg[i].tag, dut.RAT_dbg[i].ready);
    end
    
  repeat (15) begin
    @(posedge clock);
    fetched = '{default:0};
    testing = 0;
    #1;
      $display("\n--- Halt Status ---");
  $display("Halt signal: %b", {committed_insts[1].halt, committed_insts[0].halt});
  if ((committed_insts[0].valid && committed_insts[0].halt) || 
      (committed_insts[1].valid && committed_insts[1].halt)) begin
    $display("  ^^^ PROCESSOR HALTED ^^^");
    $finish;
  end
    $display("\n==================== CYCLE %0d ====================\n", cycle++);
    $display("\n--- Dispatch Counters ---");
$display("NumFreeListFreeEntriesAfterRetire = %0d", NumFreeListFreeEntriesAfterRetire_dbg);
$display("NumFreeRSEntriesAfterIssue        = %0d", NumFreeRSEntriesAfterIssue_dbg);
$display("Dispatch Request                   = 2'b%b", dispatch_request_dbg);

    // Dispatch Debug
    $display("--- Dispatch Stage ---");
    for (int i = 0; i < `N; i++) begin
      if (dut.dispatch_inst.rob_out[i].valid) begin
        $display("DISPATCH[%0d]: inst=0x%08x PC=0x%08x dest_AR=%0d T=%0d Told=%0d",
          i,
          dut.dispatch_inst.rob_out[i].instruction,
          dut.dispatch_inst.rob_out[i].PC,
          dut.dispatch_inst.rob_out[i].dest_reg,
          dut.dispatch_inst.rob_out[i].TD,
          dut.dispatch_inst.rob_out[i].Told);
        $display("             src1_AR=%0d -> PR[%0d] (ready=%b), src2_AR=%0d -> PR[%0d] (ready=%b)",
          dut.dispatch_inst.reg1_ar_o[i],
          dut.dispatch_inst.reg1_pr_i[i],
          dut.dispatch_inst.reg1_ready_i[i],
          dut.dispatch_inst.reg2_ar_o[i],
          dut.dispatch_inst.reg2_pr_i[i],
          dut.dispatch_inst.reg2_ready_i[i]);
      end
    end

    // Reservation Station
        $display("\n--- RS Entries ---");
    for (int i = 0; i < `RS_SZ; i++) begin
      $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x PC=0x%08x",
        i,
        dut.rs_inst.rs[i].valid,
        dut.rs_inst.rs[i].busy,
        dut.rs_inst.rs[i].T1,
        dut.rs_inst.rs[i].T1p,
        dut.rs_inst.rs[i].T2,
        dut.rs_inst.rs[i].T2p,
        dut.rs_inst.rs[i].TD,
        dut.rs_inst.rs[i].inst,
        dut.rs_inst.rs[i].PC);
    end
    
    

    // // S_out_packet
    // $display("\n--- Issue → Execute (S_out_packet) ---");
    // for (int i = 0; i < `NUM_FU; i++) begin
    //   if (dut.S_out_packet[i].valid)
    //     $display("S_out[%0d]: TD=%0d inst=0x%08x PC=0x%08x", i, dut.S_out_packet[i].dest_reg_idx, dut.S_out_packet[i].inst, dut.S_out_packet[i].PC);
    //   else
    //     $display("S_out[%0d]: ---", i);

        
    // $display("[FIFO RD] ALU[%0d] → valid=%b inst=0x%08x TD=%0d", 
    //       i, S_out_packet[i].valid, S_out_packet[i].inst, S_out_packet[i].dest_reg_idx);
    // end


    // Execute to Complete
    // $display("\n--- Execute → Complete Packets ---");
    // for (int i = 0; i < `NUM_FU; i++) begin
    //   $display("EX[%0d]: valid=%b TD=%0d result=0x%08h",
    //     i,
    //     dut.ex_to_complete_pkt[i].valid,
    //     dut.ex_to_complete_pkt[i].dest_reg_idx,
    //     dut.ex_to_complete_pkt[i].result);
    // end

    // ROB Snapshot

        // CDB + Retirement Debug
    // $display("\n--- CDB Broadcast ---");
    // for (int i = 0; i < 2; i++) begin
    //   if (dut.complete_cdb_reg[i].valid)
    //     $display("CDB[%0d]: T=%0d Data=0x%08x", i, dut.complete_cdb_reg[i].tag, dut.complete_cdb_reg[i].data);
    //   else
    //     $display("CDB[%0d]: ---", i);
    // end

//   $display("\n--- CDB Broadcast ---");
// for (int i = 0; i < 2; i++) begin
//   if (complete_cdb_reg[i].valid)
//     $display("CDB[%0d]: T=%0d Data=0x%08x", i, complete_cdb_reg[i].tag, complete_cdb_reg[i].data);
//   else
//     $display("CDB[%0d]: ---", i);
// end


    // $display("\n--- Retirement Activity ---");
    // for (int i = 0; i < 2; i++) begin
    //   if (dut.retire_stage.retireOutArchmapIn[i].commit_valid)
    //     $display("RETIRE[%0d]: AR=%0d PR=%0d PC=0x%08x", i,
    //              dut.retire_stage.retireOutArchmapIn[i].commit_arch_reg,
    //              dut.retire_stage.retireOutArchmapIn[i].commit_phys_reg,
    //              dut.retire_stage.retireOutArchmapIn[i].PC);
    //   else
    //     $display("RETIRE[%0d]: ---", i);
    // end


    $display("\n--- Reorder Buffer (ROB) ---");
    for (int i = 0; i < 8; i++) begin
      $display("ROB[%0d]: valid=%b complete=%b AR=%0d T=%0d Told=%0d PC=0x%08h HALT=%b",
        i,
        dut.rob_inst.rob_entries[i].valid,
        dut.rob_inst.rob_entries[i].complete,
        dut.rob_inst.rob_entries[i].dest_reg,
        dut.rob_inst.rob_entries[i].T,
        dut.rob_inst.rob_entries[i].Told,
        dut.rob_inst.rob_entries[i].PC,
        dut.rob_inst.rob_entries[i].halt);
    end

    // PRF
    $display("\n--- Physical Register File (PRF) ---");
    for (int i = 32; i < 48; i++)
      $display("PRF[%0d] = 0x%08h", i, PRF_dbg[i]);

    $display("\n--- Register Alias Table (RAT) ---");
    for (int i = 0; i < 8; i++) begin
      $display("AR[%0d] → PR[%0d] (ready=%b)", 
              i, dut.RAT_dbg[i].tag, dut.RAT_dbg[i].ready);
    end

    // ArchMap
    $display("\n--- Architectural Map Table ---");
    for (int i = 0; i < 8; i++)
      $display("AR[%0d] → PR[%0d]", i, arch_map_out[i]);
  end




  $display("\n=== Test Done ===\n");
  $finish;
end
endmodule










// module cpu_test;

//   localparam CLOCK_PERIOD = 50;
//   logic clock = 0;
//   always #(CLOCK_PERIOD/2) clock = ~clock;

//   logic reset, flush, testing;
//   FETCH_DISPATCH_PACKET fetched [2];
//   COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt_TESTBENCH;

//   logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries, NumROBFreeEntriesAfterRetire;
//   logic halt;
//   logic [31:0][`PR_WIDTH:0] arch_map_out;
//   DATA [`PHYS_REG_SZ_R10K-1:0] PRF_dbg;
//   CDB_ENTRY_PACKET [1:0] complete_cdb_reg;
//   ISSUE_PACKET [`NUM_FU-1:0] S_out_packet;

//   cpu dut (
//     .clock(clock), .reset(reset), .flush(flush), .testing(testing),
//     .fetched_in(fetched),
//     .ex_to_complete_pkt_TESTBENCH(ex_to_complete_pkt_TESTBENCH),
//     .NumROBFreeEntries(NumROBFreeEntries),
//     .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
//     .halt(halt),
//     .arch_map_out(arch_map_out),
//     .PRF_dbg(PRF_dbg),
//     .complete_cdb_reg(complete_cdb_reg),
//     .S_out_packet(S_out_packet)
//   );

//   task reset_all();
//     begin
//       reset = 1;
//       flush = 0;
//       testing = 1;
//       fetched = '{default:0};
//       ex_to_complete_pkt_TESTBENCH = '{default:0};
//       @(posedge clock); @(posedge clock);
//       reset = 0;
//       @(posedge clock);
//     end
//   endtask

//   function string func_unit_to_string(FUNC_UNIT fu);
//   case (fu)
//     ALU0:    return "ALU0";
//     ALU1:    return "ALU1";
//     MULT:    return "MULT";
//     BRANCH:  return "BRANCH";
//     default: return "UNKNOWN";
//   endcase
// endfunction


// function string alu_func_to_string(ALU_FUNC af);
//   case (af)
//     ALU_ADD: return "ADD";
//     ALU_SUB: return "SUB";
//     ALU_AND: return "AND";
//     ALU_OR:  return "OR";
//     ALU_SLL: return "SLL";
//     ALU_SRL: return "SRL";
//     ALU_SLT: return "SLT";
//     default: return "???";
//   endcase
// endfunction

// function string mult_func_to_string(MULT_FUNC mf);
//   case (mf)
//     M_MUL: return "MUL";
//     M_MULH: return "MULH";
//     default: return "???";
//   endcase
// endfunction

// task show_rs;
//   begin
//     // Reservation Station
//     $display("\n--- RS Entries ---");
//     for (int i = 0; i < `RS_SZ; i++) begin
//       $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x",
//         i,
//         dut.rs_inst.rs[i].valid,
//         dut.rs_inst.rs[i].busy,
//         dut.rs_inst.rs[i].T1,
//         dut.rs_inst.rs[i].T1p,
//         dut.rs_inst.rs[i].T2,
//         dut.rs_inst.rs[i].T2p,
//         dut.rs_inst.rs[i].TD,
//         dut.rs_inst.rs[i].inst);
//     end
//   end
// endtask

// task show_issue_to_ex;
//   begin
//     $display("\n--- Issue → Execute (S_out_packet) ---");
//       for (int i = 0; i < `NUM_FU; i++) begin
//         if (dut.issue_stage.S_out_packet[i].valid) begin
//           $display("S_out[%0d]: TD=%0d inst=0x%08x PC=0x%08x", i, dut.issue_stage.S_out_packet[i].dest_reg_idx, dut.issue_stage.S_out_packet[i].inst, dut.issue_stage.S_out_packet[i].PC);
//           $display("Complete stall: %1d", dut.issue_stage.complete_stall[i]);
//         end else begin
//           $display("S_out[%0d]: ---", i);
//           $display("Complete stall: %1d", dut.issue_stage.complete_stall[i]);
//         end

//         $display("[FIFO RD] ALU[%0d] → valid=%b inst=0x%08x TD=%0d", 
//           i, S_out_packet[i].valid, S_out_packet[i].inst, S_out_packet[i].dest_reg_idx);
//       end
//   end
// endtask

// task show_ex;
//   begin
//     $display("\n--- Execute ---");
//     $display("ALU0: valid=%b PC=0x%08x TD=%0d result=0x%08x",
//       dut.ex_stage.C_packet[ALU0].valid,
//       dut.ex_stage.C_packet[ALU0].PC,
//       dut.ex_stage.C_packet[ALU0].dest_reg_idx,
//       dut.ex_stage.C_packet[ALU0].result
//     );
//     $display("ALU1: valid=%b PC=0x%08x TD=%0d result=0x%08x",
//       dut.ex_stage.C_packet[ALU1].valid,
//       dut.ex_stage.C_packet[ALU1].PC,
//       dut.ex_stage.C_packet[ALU1].dest_reg_idx,
//       dut.ex_stage.C_packet[ALU1].result
//     );
//     $display("Mult0: valid=%b PC=0x%08x TD=%0d result=0x%08x",
//       dut.ex_stage.C_packet[MULT].valid,
//       dut.ex_stage.C_packet[MULT].PC,
//       dut.ex_stage.C_packet[MULT].dest_reg_idx,
//       dut.ex_stage.C_packet[MULT].result
//     );
//     $display("Branch0: valid=%b PC=0x%08x TD=%0d result=0x%08x",
//       dut.ex_stage.C_packet[BRANCH].valid,
//       dut.ex_stage.C_packet[BRANCH].PC,
//       dut.ex_stage.C_packet[BRANCH].dest_reg_idx,
//       dut.ex_stage.C_packet[BRANCH].result
//     );
//   end
// endtask

// task show_issue_FIFOs();
//   begin
//     $display(
//       "\n\033[38;5;13mALU FIFO:\n \033[0m----------------------------------------------------------------------\n |\033[38;5;13m v \033[0m|\033[38;5;13m     PC     \033[0m|\033[38;5;13m    NPC     \033[0m|\033[38;5;13m    Inst    \033[0m|\033[38;5;13m      R1    \033[0m|\033[38;5;13m      R2    \033[0m|\n \033[0m----------------------------------------------------------------------"
//     );

//     for (int i = 0; i < `FIFO_SZ; i++) begin
//       $display("\033[0m |\033[38;5;13m %b \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\n ----------------------------------------------------------------------",
//       dut.issue_stage.alu_fifo_display[i].valid, 
//       dut.issue_stage.alu_fifo_display[i].PC, 
//       dut.issue_stage.alu_fifo_display[i].NPC,
//       dut.issue_stage.alu_fifo_display[i].inst,
//       dut.issue_stage.alu_fifo_display[i].r1_value,
//       dut.issue_stage.alu_fifo_display[i].r2_value
//       );
//     end

//     $display(
//       "\n\033[38;5;13mMult FIFO:\n \033[0m----------------------------------------------------------------------\n |\033[38;5;13m v \033[0m|\033[38;5;13m     PC     \033[0m|\033[38;5;13m    NPC     \033[0m|\033[38;5;13m    Inst    \033[0m|\033[38;5;13m      R1    \033[0m|\033[38;5;13m      R2    \033[0m|\n \033[0m----------------------------------------------------------------------"
//     );

//     for (int i = 0; i < `FIFO_SZ; i++) begin
//       $display("\033[0m |\033[38;5;13m %b \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\n ----------------------------------------------------------------------",
//       dut.issue_stage.mult_fifo_display[i].valid, 
//       dut.issue_stage.mult_fifo_display[i].PC, 
//       dut.issue_stage.mult_fifo_display[i].NPC,
//       dut.issue_stage.mult_fifo_display[i].inst,
//       dut.issue_stage.mult_fifo_display[i].r1_value,
//       dut.issue_stage.mult_fifo_display[i].r2_value
//       );
//     end

//     $display(
//       "\n\033[38;5;13mBranch FIFO:\n \033[0m----------------------------------------------------------------------\n |\033[38;5;13m v \033[0m|\033[38;5;13m     PC     \033[0m|\033[38;5;13m    NPC     \033[0m|\033[38;5;13m    Inst    \033[0m|\033[38;5;13m      R1    \033[0m|\033[38;5;13m      R2    \033[0m|\n \033[0m----------------------------------------------------------------------"
//     );

//   // Step pipeline for a number of cycles
//   repeat (5) begin
//     @(posedge clock);
//     fetched = '{default:0};
//     testing = 0;
//     #1;
//     $display("\n==================== CYCLE %0d ====================\n", cycle++);

//     $display(
//       "\n\033[38;5;13mLS FIFO:\n \033[0m----------------------------------------------------------------------\n |\033[38;5;13m v \033[0m|\033[38;5;13m     PC     \033[0m|\033[38;5;13m    NPC     \033[0m|\033[38;5;13m    Inst    \033[0m|\033[38;5;13m      R1    \033[0m|\033[38;5;13m      R2    \033[0m|\n \033[0m----------------------------------------------------------------------"
//     );

//     for (int i = 0; i < `FIFO_SZ; i++) begin
//       $display("\033[0m |\033[38;5;13m %b \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m %10d \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\033[38;5;13m 0x%08x \033[0m|\n ----------------------------------------------------------------------",
//       dut.issue_stage.ls_fifo_display[i].valid, 
//       dut.issue_stage.ls_fifo_display[i].PC, 
//       dut.issue_stage.ls_fifo_display[i].NPC,
//       dut.issue_stage.ls_fifo_display[i].inst,
//       dut.issue_stage.ls_fifo_display[i].r1_value,
//       dut.issue_stage.ls_fifo_display[i].r2_value
//       );
//     end
      
//   end
// endtask

// task show_dispatch;
//   begin
//     $display("--- Dispatch Stage ---");
//     for (int i = 0; i < `N; i++) begin
//       if (dut.dispatch_inst.rob_out[i].valid) begin
//         $display("DISPATCH[%0d]: inst=0x%08x PC=0x%08x dest_AR=%0d T=%0d Told=%0d",
//           i,
//           dut.dispatch_inst.rob_out[i].instruction,
//           dut.dispatch_inst.rob_out[i].PC,
//           dut.dispatch_inst.rob_out[i].dest_reg,
//           dut.dispatch_inst.rob_out[i].TD,
//           dut.dispatch_inst.rob_out[i].Told);
//         $display("             src1_AR=%0d -> PR[%0d] (ready=%b), src2_AR=%0d -> PR[%0d] (ready=%b)",
//           dut.dispatch_inst.reg1_ar_o[i],
//           dut.dispatch_inst.reg1_pr_i[i],
//           dut.dispatch_inst.reg1_ready_i[i],
//           dut.dispatch_inst.reg2_ar_o[i],
//           dut.dispatch_inst.reg2_pr_i[i],
//           dut.dispatch_inst.reg2_ready_i[i]);
//       end
//     end
//   end
// endtask

//     // Reservation Station
//     $display("\n--- RS Entries ---");
//     for (int i = 0; i < `RS_SZ; i++) begin
//       $display("RS[%0d]: valid=%b busy=%b T1=%0d(%b) T2=%0d(%b) TD=%0d inst=0x%08x",
//         i,
//         dut.rs_inst.rs[i].valid,
//         dut.rs_inst.rs[i].busy,
//         dut.rs_inst.rs[i].T1,
//         dut.rs_inst.rs[i].T1p,
//         dut.rs_inst.rs[i].T2,
//         dut.rs_inst.rs[i].T2p,
//         dut.rs_inst.rs[i].TD,
//         dut.rs_inst.rs[i].inst);
//     end
    

//     // S_out_packet
//     $display("\n--- Issue → Execute (S_out_packet) ---");
//     for (int i = 0; i < `NUM_FU; i++) begin
//       if (dut.S_out_packet[i].valid)
//         $display("S_out[%0d]: TD=%0d inst=0x%08x PC=0x%08x", i, dut.S_out_packet[i].dest_reg_idx, dut.S_out_packet[i].inst, dut.S_out_packet[i].PC);
//       else
//         $display("S_out[%0d]: ---", i);

        
//     $display("[FIFO RD] ALU[%0d] → valid=%b inst=0x%08x TD=%0d", 
//           i, dut.S_out_packet[i].valid, dut.S_out_packet[i].inst, dut.S_out_packet[i].dest_reg_idx);
//     end

//   $display("\n--- Execute Stage Output ---");
//   for (int i = 0; i < `NUM_FU; i++) begin
//     if (dut.ex_stage.C_packet[i].valid)
//       $display("EX[%0d]: PC=0x%08x TD=%0d result=0x%08x", i,
//              dut.ex_stage.C_packet[i].PC,
//              dut.ex_stage.C_packet[i].dest_reg_idx,
//              dut.ex_stage.C_packet[i].result);
//     else
//       $display("EX[%0d]: ---", i);
//   end



//     // Execute to Complete
//     // $display("\n--- Execute → Complete Packets ---");
//     // for (int i = 0; i < `NUM_FU; i++) begin
//     //   $display("EX[%0d]: valid=%b TD=%0d result=0x%08h",
//     //     i,
//     //     dut.ex_to_complete_pkt[i].valid,
//     //     dut.ex_to_complete_pkt[i].dest_reg_idx,
//     //     dut.ex_to_complete_pkt[i].result);
//     // end

//     // ROB Snapshot

//         // CDB + Retirement Debug
//     $display("\n--- CDB Broadcast ---");
//     for (int i = 0; i < 2; i++) begin
//       if (dut.complete_cdb_reg[i].valid)
//         $display("CDB[%0d]: T=%0d Data=0x%08x", i, dut.complete_cdb_reg[i].tag, dut.complete_cdb_reg[i].data);
//       else
//         $display("CDB[%0d]: ---", i);
//     end

//   $display("\n--- CDB Broadcast ---");
// for (int i = 0; i < 2; i++) begin
//   if (complete_cdb_reg[i].valid)
//     $display("CDB[%0d]: T=%0d Data=0x%08x", i, complete_cdb_reg[i].tag, complete_cdb_reg[i].data);
//   else
//     $display("CDB[%0d]: ---", i);
// end


//     // $display("\n--- Retirement Activity ---");
//     // for (int i = 0; i < 2; i++) begin
//     //   if (dut.retire_stage.retireOutArchmapIn[i].commit_valid)
//     //     $display("RETIRE[%0d]: AR=%0d PR=%0d PC=0x%08x", i,
//     //              dut.retire_stage.retireOutArchmapIn[i].commit_arch_reg,
//     //              dut.retire_stage.retireOutArchmapIn[i].commit_phys_reg,
//     //              dut.retire_stage.retireOutArchmapIn[i].PC);
//     //   else
//     //     $display("RETIRE[%0d]: ---", i);
//     // end


//     $display("\n--- Reorder Buffer (ROB) ---");
//     for (int i = 0; i < 8; i++) begin
//       $display("ROB[%0d]: valid=%b complete=%b AR=%0d T=%0d Told=%0d PC=0x%08h",
//         i,
//         dut.rob_inst.rob_entries[i].valid,
//         dut.rob_inst.rob_entries[i].complete,
//         dut.rob_inst.rob_entries[i].dest_reg,
//         dut.rob_inst.rob_entries[i].T,
//         dut.rob_inst.rob_entries[i].Told,
//         dut.rob_inst.rob_entries[i].PC);
//     end

//     // PRF
//     $display("\n--- Physical Register File (PRF) ---");
//     for (int i = 0; i < 16; i++)
//       $display("PRF[%0d] = 0x%08h", i, PRF_dbg[i]);

//     // ArchMap
//     $display("\n--- Architectural Map Table ---");
//     for (int i = 0; i < 9; i++)
//       $display("AR[%0d] → PR[%0d]", i, arch_map_out[i]);
//   end
// endtask

// task show_ex_to_complete();
//   begin
//     // Execute to Complete
//     // $display("\n--- Execute → Complete Packets ---");
//     // for (int i = 0; i < `NUM_FU; i++) begin
//     //   $display("EX[%0d]: valid=%b TD=%0d result=0x%08h",
//     //     i,
//     //     dut.ex_to_complete_pkt[i].valid,
//     //     dut.ex_to_complete_pkt[i].dest_reg_idx,
//     //     dut.ex_to_complete_pkt[i].result);
//     // end
//   end
// endtask

// task show_cdb();
//   begin
//     // CDB + Retirement Debug
//     $display("\n--- CDB Broadcast ---");
//     for (int i = 0; i < 2; i++) begin
//       if (dut.complete_cdb_reg[i].valid)
//         $display("CDB[%0d]: T=%0d Data=0x%08x", i, dut.complete_cdb_reg[i].tag, dut.complete_cdb_reg[i].data);
//       else
//         $display("CDB[%0d]: ---", i);
//     end

//     $display("\n--- CDB Broadcast ---");
//     for (int i = 0; i < 2; i++) begin
//       if (complete_cdb_reg[i].valid)
//         $display("CDB[%0d]: T=%0d Data=0x%08x", i, complete_cdb_reg[i].tag, complete_cdb_reg[i].data);
//       else
//         $display("CDB[%0d]: ---", i);
//     end
//   end
// endtask

// task show_retire();
//   begin
//     // $display("\n--- Retirement Activity ---");
//     // for (int i = 0; i < 2; i++) begin
//     //   if (dut.retire_stage.retireOutArchmapIn[i].commit_valid)
//     //     $display("RETIRE[%0d]: AR=%0d PR=%0d PC=0x%08x", i,
//     //              dut.retire_stage.retireOutArchmapIn[i].commit_arch_reg,
//     //              dut.retire_stage.retireOutArchmapIn[i].commit_phys_reg,
//     //              dut.retire_stage.retireOutArchmapIn[i].PC);
//     //   else
//     //     $display("RETIRE[%0d]: ---", i);
//     // end
//   end
// endtask

// task show_arch_map();
//   begin
//     $display("\n--- Architectural Map Table ---");
//     for (int i = 0; i < 8; i++) begin
//       $display("AR[%0d] → PR[%0d]", i, arch_map_out[i]);
//     end
//   end
// endtask

// task show_prf();
//   begin
//     $display("\n--- Physical Register File (PRF) ---");
//     for (int i = 0; i < 16; i++) begin
//       $display("PRF[%0d] = 0x%08h", i, PRF_dbg[i]);
//     end
//   end
// endtask

// task show_complete();
//   begin
//     $display("\n--- Complete Stage ---");
//     $display("Complete_in valid: [3]:%b [2]:%b [1]:%b [0]:%b",
//       dut.complete_stage.complete_in[3].valid,
//       dut.complete_stage.complete_in[2].valid,
//       dut.complete_stage.complete_in[1].valid,
//       dut.complete_stage.complete_in[0].valid
//     );
//     $display("Gnt mask: 0x%4x Count: %2d Req: %4x", dut.complete_stage.grant_mask, dut.complete_stage.u_selector.count, dut.complete_stage.u_selector.request);
//   end
// endtask

//   initial begin
//     int cycle = 0;
//     $display("\n=== CPU Integration Test: Full Pipeline Visibility ===\n");

//     reset_all();

//     $dumpfile("../dump/test.vcd");
//     $dumpvars(0, cpu_test);

//     // Initialize PRF manually (fake values to PRF for operands)
//     ex_to_complete_pkt_TESTBENCH[0].valid = 1;
//     ex_to_complete_pkt_TESTBENCH[0].dest_reg_idx = 6'd1;
//     ex_to_complete_pkt_TESTBENCH[0].result = 32'hCAFE0000;

//     ex_to_complete_pkt_TESTBENCH[1].valid = 1;
//     ex_to_complete_pkt_TESTBENCH[1].dest_reg_idx = 6'd2;
//     ex_to_complete_pkt_TESTBENCH[1].result = 32'h0000BEEF;

//     @(posedge clock);
//     ex_to_complete_pkt_TESTBENCH = '{default:0};
//     testing = 0;
//     // Feed two instructions
//     fetched[0].valid = 1;
//     fetched[0].inst  = 32'h00208133; // add x3, x2, x1
//     fetched[0].PC    = 32'h1000;
//     fetched[0].NPC   = 32'h1004;

//     fetched[1].valid = 1;
//     fetched[1].inst  = 32'h00000013; // nop
//     fetched[1].PC    = 32'h1004;
//     fetched[1].NPC   = 32'h1008;

//     // Step pipeline for a number of cycles
//     repeat (4) begin
//       @(posedge clock);
//       fetched = '{default:0};
//       testing = 0;
//       #1;
//       $display("\n==================== CYCLE %0d ====================\n", cycle++);

//       // show_dispatch();
//       // show_rs();
//       show_issue_to_ex();
//       // show_issue_FIFOs();
//       show_ex();
//       show_cdb();
//       show_complete();
//       // show_rob();
//       show_prf();
//     end

//       $display("\n=== Test Done ===\n");
//       $finish;
//   end
// endmodule

