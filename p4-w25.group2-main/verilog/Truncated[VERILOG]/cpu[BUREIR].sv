`include "sys_defs.svh"


module cpu (
 input  logic clock,
 input  logic reset,
 input  logic flush,
 input  logic testing,

 input  FETCH_DISPATCH_PACKET fetched_in [2],
 input  COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt_TESTBENCH,

 output logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries,
 output logic [`ROB_PTR_WIDTH:0] NumROBFreeEntriesAfterRetire,
 output logic halt,
 output logic [31:0][`PR_WIDTH:0] arch_map_out,
 output DATA [`PHYS_REG_SZ_R10K-1:0] PRF_dbg,
 output CDB_ENTRY_PACKET [1:0] complete_cdb_reg,
 output ISSUE_PACKET [`NUM_FU-1:0] S_out_packet,
 output COMMIT_PACKET [`N-1:0] committed_insts,
 output logic [`ROB_PTR_WIDTH:0] total_num_free_dbg,
 output RAT_ENTRY_PACKET [0:31] RAT_dbg,
 output logic [`ROB_PTR_WIDTH:0] NumFreeListFreeEntriesAfterRetire_dbg,
 output logic [$clog2(`RS_SZ):0] NumFreeRSEntriesAfterIssue_dbg,
 output logic [1:0] dispatch_request_dbg

);

 logic [`N-1:0][`PR_WIDTH-1:0] T1_idx, T2_idx;
 DATA [`N-1:0] read_T1, read_T2;
 DATA [`N-1:0] PRF_read_T1, PRF_read_T2;
 logic [`N-1:0][`PR_WIDTH-1:0] maptable_new_pr;
 FIFO_STALL_PACKET fifo_full;

 FETCH_DISPATCH_PACKET if_packet [2];
 DISPATCH_ROB_PACKET [`N-1:0] rob_dispatch_pkt;
 DISPATCH_RS_PACKET [`N-1:0] rs_dispatch_pkt_internal;
 RS_ISSUE_PACKET [`N-1:0] rs_issue_pkt;

 ROB_RETIRE_PACKET [`N-1:0] RobEntriesToRetire;

logic [`ROB_PTR_WIDTH:0] total_num_free;
// logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries;

 REG_IDX [`N-1:0] rat_src1, rat_src2, rat_dest;
 logic [`N-1:0][`PR_WIDTH-1:0] rat_T, rat_Told, rat_T1, rat_T2;
 logic [`N-1:0] rat_T1p, rat_T2p;
 logic [`N-1:0][`PR_WIDTH-1:0] free_tags;

 logic [`N-1:0] commit_valid;
 REG_IDX [`N-1:0] commit_dest_reg;
 logic [`N-1:0][`PR_WIDTH-1:0] commit_T, commit_Told;
 ADDR [`N-1:0] commit_PC;

 RETIRE_ARCHMAP_PACKET [`N-1:0] retireOutArchmapIn;
 RETIRE_TO_FREELIST_PACKET RetireToFreeList;
 FREELIST_PACKET_OUT freeList_out;
 logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg;
 logic [`ROB_PTR_WIDTH-1:0] head_dbg, tail_dbg;

 CDB_ENTRY_PACKET [1:0] complete_cdb_out;
 logic [3:0] complete_stall;

 COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt_internal;
 COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt;
 assign ex_to_complete_pkt_internal = ex_to_complete_pkt_TESTBENCH;


logic [`ROB_PTR_WIDTH:0] NumFreeListFreeEntriesAfterRetire;
// logic [`ROB_PTR_WIDTH:0] NumROBFreeEntriesAfterRetire;
logic [$clog2(`RS_SZ):0] NumFreeRSEntriesAfterIssue;

assign NumFreeListFreeEntriesAfterRetire_dbg = NumFreeListFreeEntriesAfterRetire;
assign NumFreeRSEntriesAfterIssue_dbg = NumFreeRSEntriesAfterIssue;
assign dispatch_request_dbg = request;

logic ib_full;
logic if_valid;
FETCH_DISPATCH_PACKET if_packet_fetch [1:0];  // output from fetch stage
FETCH_DISPATCH_PACKET ib_pckt_out [1:0];      // output from IB
assign if_valid = !ib_full;


logic [1:0] numbertodispatch;
logic [1:0] request;
logic [1:0] num_ib_entries_valid;

always_comb begin
  automatic logic [$clog2(`RS_SZ+1):0] min_slots;

  // Compute how many IB entries are valid at the head
  case ({ib_pckt_out[1].valid, ib_pckt_out[0].valid})
    2'b00: num_ib_entries_valid = 2'd0;
    2'b01: num_ib_entries_valid = 2'd1;
    2'b10: num_ib_entries_valid = 2'd0; // shouldn't happen, index 0 must be valid first
    2'b11: num_ib_entries_valid = 2'd2;
    default: num_ib_entries_valid = 2'd0;
  endcase

  // Defaults
  request = 2'b00;
  numbertodispatch = 2'd0;
  min_slots = `N;

  // Include all constraints in dispatch window
  if (NumFreeListFreeEntriesAfterRetire < min_slots)
    min_slots = NumFreeListFreeEntriesAfterRetire;

  if (NumROBFreeEntriesAfterRetire < min_slots)
    min_slots = NumROBFreeEntriesAfterRetire;

  if (NumFreeRSEntriesAfterIssue < min_slots)
    min_slots = NumFreeRSEntriesAfterIssue;

  if (num_ib_entries_valid < min_slots)
    min_slots = num_ib_entries_valid;

  // Determine how many instructions to dispatch
  if (min_slots >= 2) begin
    request = 2'b11;
    numbertodispatch = 2'd2;
  end
  else if (min_slots == 1) begin
    request = 2'b01;
    numbertodispatch = 2'd1;
  end
  // else: request stays 0, numbertodispatch stays 0
end





stage_if stage_if_0 (
  .clock(clock),
  .reset(reset),
  .if_valid(if_valid),
  .take_branch(1'b0), // wire up later when branch prediction is done
  .branch_target('0),
  .Imem_data(mem2proc_data),
  .Imem2proc_transaction_tag(mem2proc_transaction_tag),
  .Imem2proc_data_tag(mem2proc_data_tag),
  .Imem_command(Imem_command),
  .Imem_addr(Imem_addr),
  .if_packet(if_packet_fetch)
);

ib instb (
  .clock(clock),
  .reset(reset),
  .rd_EN(request), // read 2 entries every cycle
  .wr_EN({if_packet_fetch[1].valid, if_packet_fetch[0].valid}),
  .fifo_pckt_in(if_packet_fetch),
  .full(ib_full),
  .fifo_pckt_out(ib_pckt_out),
  .fifo(ibust) // debug output
);


//  logic start_valid_on_reset;
//     always_ff @(posedge clock) begin
//         // Start valid on reset. Other stages (ID,EX,MEM,WB) start as invalid
//         // Using a separate always_ff is necessary since if_valid is combinational
//         // Assigning if_valid = reset doesn't work as you'd hope :/
//         start_valid_on_reset <= reset;
//     end
//     // ==========================
//     // Fetch stage
//     // ==========================
//     logic ib_full;
//     logic if_valid;
//     // ==========================
//     // Fetch stage
//     // ==========================

//     assign if_valid = start_valid_on_reset | !ib_full;
//     stage_if stage_if_0 (
//         .clock(clock),
//         .reset(reset),
//         .if_valid(if_valid ),
//         .take_branch  (0),
//         .branch_target(0),
//         .Imem_data(mem2proc_data),
//         .Imem2proc_transaction_tag(mem2proc_transaction_tag),
//         .Imem2proc_data_tag(mem2proc_data_tag),
//         .Imem_command(Imem_command),
//         .if_packet(if_packet),
//         .Imem_addr(Imem_addr)

//     );

//     ib instb (
//         .clock(clock),
//         .reset(reset),
//         .rd_EN({'1,'1}),
//         .wr_EN({if_packet[1].valid, if_packet[0].valid}),
//         .fifo_pckt_in(if_packet),
//         .full(ib_full),
//         .fifo_pckt_out(ib_pckt_out),
//         .fifo(ibust)// Debug output
//     );



s_RegisterAliasTable rat_inst (
  .clock(clock), .reset(reset), .flush(flush),
  .arc_src1_regs(rat_src1), .arc_src2_regs(rat_src2), .arc_dest_regs(rat_dest),
  .free_physical_register_indicies(testing ? '{default:6'b0} : freeList_out),
  .cdb_valid({complete_cdb_reg[1].valid, complete_cdb_reg[0].valid}),
  .cdb_tag({complete_cdb_reg[1].tag, complete_cdb_reg[0].tag}),
  .Told(rat_Told), .T(rat_T), .T1(rat_T1), .T1p(rat_T1p),
  .T2(rat_T2), .T2p(rat_T2p),
  .RAT_dbg(RAT_dbg)
);

logic [1:0] free_valid;
assign free_valid = freeList_out.valid;

 stage_dispatch dispatch_inst (
   .clock(clock), .reset(reset),
   .fetched_in(ib_pckt_out),
   .NumFreeEntriesAfterIssue(NumFreeRSEntriesAfterIssue),
   .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
   .dispatch_stall_o(),
   .free_valid_i({free_valid[1], free_valid[0]}),
   .rob_out(rob_dispatch_pkt),
   .maptable_arch_o(rat_dest),
   .maptable_old_pr_i(rat_Told),
   .maptable_new_pr_i(rat_T),
   .maptable_new_pr_o(maptable_new_pr),
   .reg1_ar_o(rat_src1),
   .reg2_ar_o(rat_src2),
   .reg1_pr_i(rat_T1),
   .reg2_pr_i(rat_T2),
   .reg1_ready_i(rat_T1p),
   .reg2_ready_i(rat_T2p),
   .rs_in(rs_dispatch_pkt_internal)
 );






 rs rs_inst (
   .clock(clock), .reset(reset),
   .RS_in(rs_dispatch_pkt_internal),
   .fifo_full(fifo_full),
   .issue_out(rs_issue_pkt),
   .NumberToDispatch(numbertodispatch),
   .NumFreeEntriesAfterIssue(NumFreeRSEntriesAfterIssue),
   .cdb(complete_cdb_reg)
 );


 rob rob_inst (
   .clock(clock), .reset(reset), .flush(flush),
   .DispatchEntryValid({rob_dispatch_pkt[1].valid, rob_dispatch_pkt[0].valid}),
   .NumberToDispatch(numbertodispatch),
   .dispatch_PC({rob_dispatch_pkt[1].PC, rob_dispatch_pkt[0].PC}),
   .dispatch_dest_reg({rob_dispatch_pkt[1].dest_reg, rob_dispatch_pkt[0].dest_reg}),
   .dispatch_T({rob_dispatch_pkt[1].TD, rob_dispatch_pkt[0].TD}),
   .dispatch_Told({rob_dispatch_pkt[1].Told, rob_dispatch_pkt[0].Told}),
   .halt({rob_dispatch_pkt[1].halt, rob_dispatch_pkt[0].halt}),
   .NumFreeEntries(NumROBFreeEntries),
   .CDB_in(complete_cdb_reg),
   .commit_valid(commit_valid),
   .commit_dest_reg(commit_dest_reg),
   .commit_T(commit_T),
   .commit_Told(commit_Told),
   .commit_PC(commit_PC),
   .RobEntriesToRetire(RobEntriesToRetire)
 );


  COMMIT_PACKET [`N-1:0] committed_insts_wire;
 stage_retire retire_stage (
   .NumROBFreeEntries(NumROBFreeEntries),
   .total_num_free(total_num_free),
   .RobEntriesToRetire(RobEntriesToRetire),
   .retireOutArchmapIn(retireOutArchmapIn),
   .RetireToFreeList(RetireToFreeList),
   .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
   .NumFreeListFreeEntriesAfterRetire(NumFreeListFreeEntriesAfterRetire),
   .committed_insts(committed_insts_wire)
 );


 s_ArchitecturalMap archmap_inst (
   .clock(clock), .reset(reset), .flush(flush),
   .commit_valid({retireOutArchmapIn[1].commit_valid, retireOutArchmapIn[0].commit_valid}),
   .commit_arch_reg({retireOutArchmapIn[1].commit_arch_reg, retireOutArchmapIn[0].commit_arch_reg}),
   .commit_phys_reg({retireOutArchmapIn[1].commit_phys_reg, retireOutArchmapIn[0].commit_phys_reg}),
   .arch_map_out(arch_map_out)
 );


 stage_complete complete_stage (
   .clock(clock), .reset(reset),
   .complete_in(testing ? ex_to_complete_pkt_internal : ex_to_complete_pkt),
   .complete_stall(complete_stall),
   .complete_cdb_out(complete_cdb_out)
 );


 s_PhysicalRegisterFile prf_inst (
   .clock(clock), .reset(reset),
   .readIDX_Ainput(T1_idx),
   .readIDX_Binput(T2_idx),
   .CDB_in(complete_cdb_reg),
   .readIDX_AdataOutput(read_T1),
   .readIDX_BdataOutput(read_T2),
   .PRF_dbg(PRF_dbg)
 );


 stage_ex ex_stage (
   .Ex_packet(S_out_packet),
   .C_packet(ex_to_complete_pkt)
 );

DATA [`N-1:0] issue_T1, issue_T2;
 always_comb begin
  for (int i = 0; i < `N; i++) begin
    issue_T1[i] = read_T1[i];
    issue_T2[i] = read_T2[i];

    for (int c = 0; c < 2; c++) begin
      if (complete_cdb_reg[c].valid && complete_cdb_reg[c].tag == T1_idx[i]) begin
        issue_T1[i] = complete_cdb_reg[c].data;
      end
      if (complete_cdb_reg[c].valid && complete_cdb_reg[c].tag == T2_idx[i]) begin
        issue_T2[i] = complete_cdb_reg[c].data;
      end
    end
  end
end


stage_issue issue_stage (
  .clock(clock), .reset(reset),
  .rs_entry(rs_issue_pkt),
  .complete_stall(complete_stall),
  .read_T1(issue_T1), // ← now muxed
  .read_T2(issue_T2), // ← now muxed
  .T1_idx(T1_idx),
  .T2_idx(T2_idx),
  .S_out_packet(S_out_packet),
  .fifo_full(fifo_full),
  .alu_fifo_display(),
  .mult_fifo_display(),
  .br_fifo_display(),
  .ls_fifo_display()
);


 freeList freeList_inst (
   .clock(clock), .reset(reset),
   .freeList_in(RetireToFreeList),
   .dispatch_req(testing? 2'b00 : request),
   .put_back(4'b0000),
   .freeList_out(freeList_out),
   .freeList_dbg(freeList_dbg),
   .head_dbg(head_dbg),
   .tail_dbg(tail_dbg),
   .total_num_free(total_num_free)
 );


 always_ff @(posedge clock) begin
   if (reset)
     complete_cdb_reg <= '{default:'0};
   else
     complete_cdb_reg <= complete_cdb_out;
 end

  always_ff @(posedge clock) begin
    if (reset)
      committed_insts <= '{default: 0};
    else
      committed_insts <= committed_insts_wire;
  end


//  always_ff @(posedge clock) begin
//    if (reset)
//      if_packet <= '{default:'0};
//    else
//      if_packet <= fetched_in;
//  end




endmodule
