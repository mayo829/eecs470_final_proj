
`include "sys_defs.svh"
`include "ISA.svh"
module cpu (
  input  logic clock,
  input  logic reset,
  input  logic flush,

  input  MEM_TAG   mem2proc_transaction_tag,
  input  MEM_BLOCK mem2proc_data,
  input  MEM_TAG   mem2proc_data_tag,

  output MEM_COMMAND proc2mem_command,
  output ADDR        proc2mem_addr,
  output MEM_BLOCK   proc2mem_data,
  output MEM_SIZE    proc2mem_size,

  output ADDR  if_id_NPC_dbg,
  output DATA  if_id_inst_dbg,
  output logic if_id_valid_dbg,
  output ADDR  id_ROB_NPC_dbg,
  output DATA  id_ROB_inst_dbg,
  output logic id_ROB_valid_dbg,
  output ADDR  id_RS_NPC_dbg,
  output DATA  id_RS_inst_dbg,
  output logic id_RS_valid_dbg,
  output ADDR  RS_IS_NPC_dbg,
  output DATA  RS_IS_inst_dbg,
  output logic RS_IS_valid_dbg,
  output ADDR  Ex_C_NPC_dbg,
  output DATA  Ex_C_inst_dbg,
  output logic Ex_C_valid_dbg,

  output COMMIT_PACKET [`N-1:0] committed_insts
);

  // IF stage
  FETCH_DISPATCH_PACKET if_packet [`N];
  logic if_valid = 1'b1;
  MEM_COMMAND Imem_command;
  ADDR Imem_addr;

      // Outputs from MEM-Stage to memory
    ADDR        Dmem_addr;
    MEM_BLOCK   Dmem_store_data;
    MEM_COMMAND Dmem_command;
    MEM_SIZE    Dmem_size;


    always_comb begin
        Dmem_command = MEM_NONE;
    if (Dmem_command != MEM_NONE) begin  // read or write DATA from memory
        proc2mem_command = Dmem_command;
        proc2mem_size    = Dmem_size;   // size is never DOUBLE in project 3
        proc2mem_addr    = Dmem_addr;
    end else begin                      // read an INSTRUCTION from memory
        proc2mem_command = Imem_command;
        proc2mem_addr    = Imem_addr;
        proc2mem_size    = DOUBLE;      // instructions load a full memory line (64 bits)
    end
    proc2mem_data = Dmem_store_data;
end


  stage_if stage_if_0 (
    .clock(clock), .reset(reset),
    .if_valid(if_valid),
    .Imem_data(mem2proc_data),
    .Imem2proc_transaction_tag(mem2proc_transaction_tag),
    .Imem2proc_data_tag(mem2proc_data_tag),
    .Imem_command(Imem_command),
    .Imem_addr(Imem_addr),
    .if_packet(if_packet)
  );

  assign if_id_NPC_dbg   = if_packet[0].NPC;
  assign if_id_inst_dbg  = if_packet[0].inst;
  assign if_id_valid_dbg = if_packet[0].valid;

  // === Free List ===
  FREELIST_PACKET_IN  freeList_in;
  FREELIST_PACKET_OUT freeList_out;
  logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg;
  logic [`ROB_PTR_WIDTH-1:0] head_dbg, tail_dbg;

  freeList freelist_inst (
    .clock(clock), .reset(reset),
    .freeList_in(freeList_in),
    .put_back(2'b0),
    .freeList_out(freeList_out),
    .freeList_dbg(freeList_dbg),
    .head_dbg(head_dbg), .tail_dbg(tail_dbg)
  );

  logic [1:0][`PR_WIDTH-1:0] free_pr = freeList_out.free_tags;
  //logic [1:0]                free_valid = freeList_out.valid;

  // === RAT ===
  logic [1:0][`PR_WIDTH-1:0] Told, T, T1, T2;
  logic [1:0] T1p, T2p;
  REG_IDX [1:0] arc_src1_regs, arc_src2_regs, arc_dest_regs;


  CDB_ENTRY_PACKET [1:0] complete_cdb_reg; 
  CDB_ENTRY_PACKET cdb_entry_0, cdb_entry_1;
  assign cdb_entry_0 = complete_cdb_reg[0];
  assign cdb_entry_1 = complete_cdb_reg[1];

  logic [1:0] cdb_valid_local;
  logic [1:0][`PR_WIDTH-1:0] cdb_tag_local;

  assign cdb_valid_local[0] = cdb_entry_0.valid;
  assign cdb_valid_local[1] = cdb_entry_1.valid;
  assign cdb_tag_local[0]   = cdb_entry_0.tag;
  assign cdb_tag_local[1]   = cdb_entry_1.tag;


  s_RegisterAliasTable rat_inst (
    .clock(clock), .reset(reset), .flush(flush),
    .arc_src1_regs(arc_src1_regs),
    .arc_src2_regs(arc_src2_regs),
    .arc_dest_regs(arc_dest_regs),
    .free_physical_register_indicies(free_pr),
    .cdb_valid(cdb_valid_local),
    .cdb_tag(cdb_tag_local),
    .Told(Told), .T(T),
    .T1(T1), .T1p(T1p),
    .T2(T2), .T2p(T2p)
  );


  // === Dispatch ===
DISPATCH_RS_PACKET [`N-1:0] rs_dispatch_pkt;
DISPATCH_ROB_PACKET [`N-1:0] rob_in;
  logic [1:0] rs_stall = 2'b0;
  logic [1:0] rob_stall = 2'b0;
  logic [1:0] dispatch_stall;
  logic [1:0] DispatchEntryValid;
  logic [1:0] NumberToDispatch;
  logic [1:0][`PR_WIDTH-1:0] dispatch_T = T;
  logic [1:0][`PR_WIDTH-1:0] dispatch_Told = Told;
  ADDR [1:0] dispatch_PC;

  dispatch_stage dispatch_inst (
    .clock(clock), .reset(reset),
    .fetched_in(if_packet),
    .rs_stall_i(rs_stall),
    .rob_stall_i(rob_stall),
    //.free_valid_i(free_valid),
    .dispatch_stall_o(dispatch_stall),
    .free_pr_i(free_pr),
    .rob_index_i('0),
    .rob_out(rob_in),
    .maptable_arch_o(arc_dest_regs),
    .maptable_new_pr_o(),
    .reg1_ar_o(arc_src1_regs),
    .reg2_ar_o(arc_src2_regs),
    .reg1_pr_i(T1),
    .reg2_pr_i(T2),
    .reg1_ready_i(T1p),
    .reg2_ready_i(T2p),
    .rs_in(rs_dispatch_pkt)
  );

  assign DispatchEntryValid = {~dispatch_stall[1], ~dispatch_stall[0]};
  assign NumberToDispatch = DispatchEntryValid[0] + DispatchEntryValid[1];
  assign dispatch_PC[0] = if_packet[0].NPC;
  assign dispatch_PC[1] = if_packet[1].NPC;

  // === RS ===
RS_ISSUE_PACKET [`N-1:0] rs_issue_pkt;
DISPATCH_RS_PACKET [`RS_SZ-1:0] rs_debug_unused;
  FIFO_STALL_PACKET fifo_full;

  rs rs_inst (
    .clock(clock), .reset(reset),
    .RS_in(rs_dispatch_pkt),
    .fifo_full(fifo_full),
    .issue_out(rs_issue_pkt),
    .NumberToDispatch(NumberToDispatch),
    .NumFreeEntriesAfterIssue(),
    .cdb(complete_cdb_reg),
    .rs(rs_debug_unused)
  );

  // === ROB ===
  logic [`N-1:0] commit_valid;
  REG_IDX [`N-1:0] commit_dest_reg;
  logic [`N-1:0][`PR_WIDTH-1:0] commit_T, commit_Told;
  ADDR [`N-1:0] commit_PC;
  ROB_RETIRE_PACKET [`N-1:0] RobEntriesToRetire;
  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries, NumROBFreeEntriesAfterRetire;

  rob rob_inst (
    .clock(clock), .reset(reset), .flush(flush),
    .DispatchEntryValid(DispatchEntryValid),
    .NumberToDispatch(NumberToDispatch),
    .dispatch_PC(dispatch_PC),
    .dispatch_dest_reg(arc_dest_regs),
    .dispatch_T(dispatch_T),
    .dispatch_Told(dispatch_Told),
    .NumFreeEntries(NumROBFreeEntries),
    .CDB_in(complete_cdb_reg),
    .commit_valid(commit_valid),
    .commit_dest_reg(commit_dest_reg),
    .commit_T(commit_T),
    .commit_Told(commit_Told),
    .commit_PC(commit_PC),
    .RobEntriesToRetire(RobEntriesToRetire)
  );

  // === Retire ===
  RETIRE_ARCHMAP_PACKET [1:0] retireOutArchmapIn;
  logic halt;

  stage_retire retire_inst (
    .NumROBFreeEntries(NumROBFreeEntries),
    .RobEntriesToRetire(RobEntriesToRetire),
    .retireOutArchmapIn(retireOutArchmapIn),
    .RetireToFreeList(freeList_in),
    .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
    .committed_insts(committed_insts)
  );

  // === Arch Map ===
  logic [31:0][`PR_WIDTH:0] arch_map_out;
  s_ArchitecturalMap archmap_inst (
    .clock(clock), .reset(reset), .flush(flush),
    .commit_valid({retireOutArchmapIn[1].commit_valid, retireOutArchmapIn[0].commit_valid}),
    .commit_arch_reg({retireOutArchmapIn[1].commit_arch_reg, retireOutArchmapIn[0].commit_arch_reg}),
    .commit_phys_reg({retireOutArchmapIn[1].commit_phys_reg, retireOutArchmapIn[0].commit_phys_reg}),
    .arch_map_out(arch_map_out)
  );

  // === Complete ===
  COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt;
  CDB_ENTRY_PACKET [1:0] complete_cdb_out;
  logic [3:0] complete_stall;

  stage_complete complete_stage (
    .clock(clock), .reset(reset),
    .complete_in(ex_to_complete_pkt),
    .complete_stall(complete_stall),
    .complete_cdb_out(complete_cdb_out)
  );

  always_ff @(posedge clock) begin
    if (reset)
      complete_cdb_reg <= '{default:'0};
    else
      complete_cdb_reg <= complete_cdb_out;
  end

  // === PRF + Operand Selection ===
  logic [`N-1:0][`PR_WIDTH-1:0] T1_idx, T2_idx;
  DATA [`N-1:0] PRF_read_T1, PRF_read_T2, read_T1, read_T2;

  s_PhysicalRegisterFile prf_inst (
    .clock(clock), .reset(reset),
    .readIDX_Ainput(T1_idx),
    .readIDX_Binput(T2_idx),
    .CDB_in(complete_cdb_reg),
    .readIDX_AdataOutput(PRF_read_T1),
    .readIDX_BdataOutput(PRF_read_T2),
    .PRF_dbg()
  );

  always_comb begin
    for (int i = 0; i < `N; i++) begin
      read_T1[i] = PRF_read_T1[i];
      read_T2[i] = PRF_read_T2[i];
    end
  end

  // === Issue & EX ===
ISSUE_PACKET [`NUM_FU-1:0] S_out_packet;
  ISSUE_PACKET [`FIFO_SZ-1:0] alu_fifo_display, mult_fifo_display, br_fifo_display, ls_fifo_display;

  stage_issue issue_stage (
    .clock(clock), .reset(reset),
    .rs_entry(rs_issue_pkt),
    .complete_stall(complete_stall),
    .read_T1(read_T1), .read_T2(read_T2),
    .T1_idx(T1_idx), .T2_idx(T2_idx),
    .S_out_packet(S_out_packet),
    .fifo_full(fifo_full),
    .alu_fifo_display(alu_fifo_display),
    .mult_fifo_display(mult_fifo_display),
    .br_fifo_display(br_fifo_display),
    .ls_fifo_display(ls_fifo_display)
  );

  stage_ex ex_stage (
    .Ex_packet(S_out_packet),
    .C_packet(ex_to_complete_pkt)
  );

  // === Debug Committed Instructions ===
  assign id_ROB_NPC_dbg   = dispatch_PC[0];
  assign id_ROB_inst_dbg  = if_packet[0].inst;
  assign id_ROB_valid_dbg = if_packet[0].valid;

  assign id_RS_NPC_dbg   = rs_dispatch_pkt[0].NPC;
  assign id_RS_inst_dbg  = rs_dispatch_pkt[0].inst;
  assign id_RS_valid_dbg = rs_dispatch_pkt[0].valid;

  assign RS_IS_NPC_dbg   = rs_issue_pkt[0].NPC;
  assign RS_IS_inst_dbg  = rs_issue_pkt[0].inst;
  assign RS_IS_valid_dbg = rs_issue_pkt[0].valid;

  assign Ex_C_NPC_dbg   = S_out_packet[0].NPC;
  assign Ex_C_inst_dbg  = S_out_packet[0].inst;
  assign Ex_C_valid_dbg = S_out_packet[0].valid;

endmodule







// `include "sys_defs.svh"
// `include "ISA.svh"

// module cpu (
//     input clock, // System clock
//     input reset, // System reset

//     input MEM_TAG   mem2proc_transaction_tag, // Memory tag for current transaction
//     input MEM_BLOCK mem2proc_data,            // Data coming back from memory
//     input MEM_TAG   mem2proc_data_tag,        // Tag for which transaction data is for

//     output MEM_COMMAND proc2mem_command, // Command sent to memory
//     output ADDR        proc2mem_addr,    // Address sent to memory
//     output MEM_BLOCK   proc2mem_data,    // Data sent to memory
//     output MEM_SIZE    proc2mem_size,    // Data size sent to memory

//     // Committed instructions
//     //output COMMIT_PACKET [`N-1:0] committed_insts,
//     output ADDR  if_id_NPC_dbg,    
//     output DATA  if_id_inst_dbg,   
//     output logic if_id_valid_dbg,  
//     output ADDR  id_ROB_NPC_dbg,   
//     output DATA  id_ROB_inst_dbg,  
//     output logic id_ROB_valid_dbg, 
//     output ADDR  id_RS_NPC_dbg,   
//     output DATA  id_RS_inst_dbg,   
//     output logic id_RS_valid_dbg,  
//     output ADDR  RS_IS_NPC_dbg,    
//     output DATA  RS_IS_inst_dbg,   
//     output logic RS_IS_valid_dbg,  
//     output ADDR  Ex_C_NPC_dbg,     
//     output DATA  Ex_C_inst_dbg,    
//     output logic Ex_C_valid_dbg   
//    // output ADDR  ROB_RE_NPC_dbg,   
//    // output DATA  ROB_RE_inst_dbg,  
//    // output logic ROB_RE_valid_dbg 
// );  


//     // Memory transaction connections
//     ADDR Imem_addr;
//     MEM_COMMAND Imem_command;
//     MEM_SIZE Dmem_size;
//     MEM_BLOCK Dmem_store_data;
//     MEM_COMMAND Dmem_command;

//     // Stalling and reset logic
//     logic halt;
//     logic if_valid;
//     // Control Signals
//     logic dispatch_EN;
//     FU_STATE fu_finish_packet;

//     // // Maptable signals
//     // logic [`PR_WIDTH-1:0] map_ar_pr;
//     // logic [4:0] map_ar;
//     // logic [31:0][`PR_WIDTH-1:0] archi_maptable, archi_maptable_out;

//     /* Fetch Stage */
//     IF_ID_PACKET           if_d_packet, if_packet;
//     /* Dispatch Stage */
//     // outputs
//     RS_PACKET_IN       dis_rs_packet;
//     ROB_PACKET_IN      dis_rob_packet;
//     logic              dis_new_pr_en;
//     logic              dis_stall; // if 1, corresponding inst stall due to structural hazard

//     // // go to maptable
//     // logic [`PR_WIDTH-1:0]	maptable_allocate_pr;
//     // logic [4:0]		maptable_allocate_ar;
//     // logic [4:0]		maptable_lookup_reg1_ar;
//     // logic [4:0]		maptable_lookup_reg2_ar;

//     // /* Reservation Station */
//     // logic              rs_stall;
//     // RS_S_PACKET        rs_is_packet;

//     // /* free list */
//     // logic               free_pr_valid;
//     // logic [`PR_WIDTH-1:0]     free_pr;
//     // logic 		        DispatchEN;
//     // logic  		        RetireEN;
//     // logic [`PR_WIDTH-1:0] 	RetireReg;
//     // logic [`ROB-1:0] 	BPRecoverHead;
//     // logic [`ROB-1:0] 	FreelistHead;
//     // logic [4:0]         fl_distance;


//     // /* map table */
//     // logic BPRecoverEN;
//     // logic [31:0][`PR_WIDTH-1:0] 	archi_maptable;
//     // logic [`PR_WIDTH-1:0]         maptable_old_pr;
//     // logic [`PR_WIDTH-1:0]         maptable_reg1_pr;
//     // logic [`PR_WIDTH-1:0]         maptable_reg2_pr;
//     // logic                   maptable_reg1_ready;
//     // logic                   maptable_reg2_ready;
//     // logic [31:0][`PR_WIDTH-1:0] 	archi_maptable_out;


//     // /* Issue stage */
//     // RS_S_PACKET        is_packet_in;
//     // ISSUE_FU_PACKET [2**`FU-1:0] is_fu_packet;
//     // FU_FIFO_PACKET          fu_fifo_stall;
//     // logic [`PR_WIDTH-1:0]    is_pr1_idx, is_pr2_idx; // access pr

//     // /* physical register */
//     // logic [`XLEN-1:0]  pr1_read, pr2_read;

//     // /* Reorder Buffer */
//     // logic [`ROB-1:0]           new_rob_index;  // ROB.dispatch_index <-> dispatch.rob_index
//     // //ROB_ENTRY_PACKET           rob_in;       // rob_in = dis_rob_packet
//     // logic                      complete_valid;
//     // logic       [`ROB-1:0]     complete_entry;  // which ROB entry is done
//     // ROB_ENTRY_PACKET           rob_retire_entry;  // which ENTRY to be retired
//     // logic                      rob_stall;
//     // ROB_ENTRY_PACKET [`ROBW-1:0]    rob_entries; //not used maybe visual debug
//     // ROB_ENTRY_PACKET [`ROBW-1:0]    rob_debug;   //not used maybe visual debug
//     // logic       [`ROB-1:0]          head;
//     // logic       [`ROB-1:0]          tail;
//     // logic                      SQRetireEN;

//     // /* functional unit */
//     // FU_STATE                     fu_ready;
//     // ISSUE_FU_PACKET     [2**`FU-1:0]    fu_packet_in;
//     // FU_STATE                     complete_stall;
//     // FU_COMPLETE_PACKET  [2**`FU-1:0]    fu_c_packet;
//     // FU_STATE                     fu_finish;

//     // /* Complete Stage */
//     // CDB_T_PACKET                    cdb_t;
//     // FU_COMPLETE_PACKET [2:0]        fu_c_in;
//     // FU_STATE                 fu_finish;
//     // logic       [`XLEN-1:0]    wb_value;
//     // logic                      precise_state_valid;
//     // logic       [`XLEN-1:0]    target_pc;

//     // /* Retire Stage */
//     // logic       [`PR_WIDTH-1:0]			map_ar_pr;
//     // logic       [4:0]			    map_ar;
//     // logic       [31:0][`PR_WIDTH-1:0]         recover_maptable;
//     // ADDR             fetch_pc;
//     // logic 		 			        RetireEN;
//     // ROB_ENTRY_PACKET               retire_entry;
//     assign Dmem_command = MEM_NONE;
//     // Memory interface logic
//     always_comb begin
//         proc2mem_command = (Dmem_command != MEM_NONE) ? Dmem_command : Imem_command;
//         proc2mem_addr = (Dmem_command != MEM_NONE) ? Dmem_store_data : Imem_addr;
//         proc2mem_data = Dmem_store_data;
//         proc2mem_size = (Dmem_command != MEM_NONE) ? Dmem_size : DOUBLE;
//     end

//     assign if_valid = 1;
//     //////////////////////////////////////////////////
//     //                  IF-Stage                    //
//     //////////////////////////////////////////////////

//     stage_if stage_if_0 (
//         .clock(clock),
//         .reset(reset),
//         .if_valid(if_valid),
// //        .take_branch(ex_mem_reg.take_branch),
// //        .branch_target(ex_mem_reg.alu_result),
//         .Imem_data(mem2proc_data),
//         .Imem2proc_transaction_tag(mem2proc_transaction_tag),
//         .Imem2proc_data_tag(mem2proc_data_tag),
//         .Imem_command(Imem_command),
//         .if_packet(if_packet),
//         .Imem_addr(Imem_addr)
//     );

//     assign if_NPC_dbg = if_packet.NPC;
//     assign if_inst_dbg = if_packet.inst;
//     assign if_valid_dbg = if_packet.valid;

//     assign committed_insts[0].halt    = if_packet.inst == `WFI;
//     assign committed_insts[0].valid    = if_packet.valid;

//     //////////////////////////////////////////////////
//     //            IF/D  Pipeline Register           //
//     //////////////////////////////////////////////////

//     always_ff @(posedge clock) begin
//         if (reset) begin
//             if_d_packet <= '{default: '0};
//         end else begin
//             if_d_packet <= if_packet;
//         end
//     end

//     assign if_id_NPC_dbg = if_d_packet.NPC;
//     assign if_id_inst_dbg = if_d_packet.inst;
//     assign if_id_valid_dbg = if_d_packet.valid;

//     //////////////////////////////////////////////////
//     //               DISPATCH-Stage                 //
//     //////////////////////////////////////////////////

//     dispatch_stage dispatch_0(
//         .if_id_packet_in(if_d_packet),
//         .rs_stall(rs_stall),
//         .rs_in(dis_rs_packet),
//         .rob_stall(rob_stall),
//         .rob_index(new_rob_index),
//         .rob_in(dis_rob_packet),
//         .free_reg_valid(free_pr_valid),
//         .free_pr_in(free_pr),
//         .maptable_new_pr(maptable_allocate_pr),
//         .maptable_ar(maptable_allocate_ar),
//         .maptable_old_pr(maptable_old_pr),
//         .reg1_ar(maptable_lookup_reg1_ar),
//         .reg2_ar(maptable_lookup_reg2_ar),
//         .reg1_pr(maptable_reg1_pr),
//         .reg2_pr(maptable_reg2_pr),
//         .reg1_ready(maptable_reg1_ready), // Attach readiness logic or signals
//         .reg2_ready(maptable_reg2_ready), // Attach readiness logic or signals
//         .new_pr_en(dis_new_pr_en),
//         .d_stall(dis_stall)
//         //.bp_EN(dispatch_EN),
//         //.bp_pc(fetch_pc)
//     );

//         assign id_ROB_NPC_dbg   = dis_rob_packet.NPC;
//         assign id_ROB_inst_dbg  = dis_rob_packet.inst;
//         assign id_ROB_valid_dbg = dis_rob_packet.valid;

//         assign id_RS_NPC_dbg    = dis_rs_packet.NPC;
//         assign id_RS_inst_dbg   = dis_rs_packet.inst;
//         assign id_RS_valid_dbg  = dis_rs_packet.valid;

//     //////////////////////////////////////////////////
//     //               Maptable Connections           //
//     //////////////////////////////////////////////////

// //     map_table map_table_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .archi_maptable(archi_maptable),
// //         .BPRecoverEN(BPRecoverEN),
// //         .cdb_t_in(cdb_t),
// //         .maptable_new_ar(maptable_allocate_ar),
// //         .maptable_new_pr(maptable_allocate_pr),
// //         .reg1_ar(maptable_lookup_reg1_ar),
// //         .reg2_ar(maptable_lookup_reg2_ar),
// //         .reg1_tag(maptable_reg1_pr), // Connect PR_WIDTH read outputs
// //         .reg2_tag(maptable_reg2_pr), // Connect PR_WIDTH read outputs
// //         .reg1_ready(maptable_reg1_ready),
// //         .reg2_ready(maptable_reg2_ready),
// //         .Told_out(maptable_old_pr) // Provide the right connection
// //     );

// //     arch_maptable arch_maptable_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .Tnew_in(map_ar_pr),
// //         .Retire_AR(map_ar),
// //         .Retire_EN(RetireEN),
// //         .archi_maptable(archi_maptable_out)
// //     );

// //     //////////////////////////////////////////////////
// //     //          Reservation Station (RS)            //
// //     //////////////////////////////////////////////////

// //     RS RS_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .rs_in(dis_rs_packet),
// //         .cdb_t(cdb_t),
// //         .fu_fifo_stall(fu_fifo_stall),
// //         .issue_inst(rs_is_packet),
// //         .struct_stall(rs_stall)
// //     );

// //     assign RS_IS_NPC_dbg    = rs_is_packet.NPC;
// //     assign RS_IS_inst_dbg   = rs_is_packet.inst;
// //     assign RS_IS_valid_dbg  = rs_is_packet.valid;


// //     //////////////////////////////////////////////////
// //     //                RS-IS-Register                //
// //     //////////////////////////////////////////////////

// //     always_ff @(posedge clock) begin
// //         if (reset) 
// //             is_packet_in <= `SD 0;
// //         else 
// //             is_packet_in <= `SD rs_is_packet;
// //     end

// //     //////////////////////////////////////////////////
// //     //                  ISSUE-Stage                 //
// //     //////////////////////////////////////////////////

// //     issue_stage issue_0(
// //         .clock(clock),
// //         .reset(reset || BPRecoverEN),
// //         .rs_out(is_packet_in),
// //         .read_rda(pr1_read),
// //         .read_rdb(pr2_read),
// //         .fu_ready(fu_ready & ~complete_stall),
// //         .rda_idx(is_pr1_idx),
// //         .rdb_idx(is_pr2_idx),
// //         .issue_2_fu(is_fu_packet),
// //         .fu_fifo_stall(fu_fifo_stall)
// //     );

// //     //////////////////////////////////////////////////
// //     //                Physical Regfile              //
// //     //////////////////////////////////////////////////

// //     physical_regfile pr_0(
// //         .rda_idx(is_pr1_idx),
// //         .rdb_idx(is_pr2_idx),
// //         .wr_data(wb_value),
// //         .wr_idx(cdb_t),
// //         .clock(clock),
// //         .reset(reset),
// //         .rda_out(pr1_read),
// //         .rdb_out(pr2_read)
// //     `ifdef TEST_MODE
// //         , .pr_reg_display(pr_display)
// //     `endif
// //     );

// //     //////////////////////////////////////////////////
// //     //                IS-FU-Register                //
// //     //////////////////////////////////////////////////

// //     always_ff @(posedge clock) begin
// //         if (reset) 
// //             fu_packet_in <= `SD 0;
// //         else 
// //             fu_packet_in <= `SD is_fu_packet;
// //     end


// //     //////////////////////////////////////////////////
// //     //                  EX-Stage                    //
// //     //////////////////////////////////////////////////

// //     stage_ex alu_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .complete_stall(complete_stall),
// //         .fu_packet_in(fu_packet_in),
// //         .fu_ready(fu_ready),
// //         .want_to_complete(want_to_complete),
// //         .fu_packet_out(fu_c_packet)
// //     );

// // //    assign Ex_C_NPC_dbg = fu_c_packet.target_pc;
// // //    assign Ex_C_inst_dbg = fu_c_packet.inst;
// // //    assign Ex_C_valid_dbg = fu_c_packet.valid;

// //     //////////////////////////////////////////////////
// //     //                FU-C-Register                 //
// //     //////////////////////////////////////////////////

// //     always_ff @(posedge clock) begin
// //         if (reset) begin
// //             fu_finish <= 0;
// //             fu_c_in <= 0;
// //         end else begin
// //             fu_finish <= fu_finish_packet;
// //             fu_c_in <= fu_c_packet;
// //         end
// //     end

// //     //////////////////////////////////////////////////
// //     //               Complete Stage                 //
// //     //////////////////////////////////////////////////

// //     complete_stage complete_stage_0(
// //         .fu_finish(fu_finish),
// //         .fu_c_in(fu_c_in),
// //         .fu_c_stall(complete_stall),
// //         .cdb_t(cdb_t),
// //         .wb_value(wb_value),
// //         .complete_valid(complete_valid),
// //         .complete_entry(complete_entry),
// //         .precise_state_valid(precise_state_valid),
// //         .target_pc(target_pc)
// //     );


// //     //////////////////////////////////////////////////
// //     //                      ROB                     //
// //     //////////////////////////////////////////////////

// //     ROB rob_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .rob_in(retire_entry),
// //         .complete_valid(complete_valid),
// //         .complete_entry(complete_entry),
// //         .precise_state_valid(precise_state_valid),
// //         .target_pc(target_pc),
// //         .BPRecoverEN(BPRecoverEN),
// //         .struct_stall(rob_stall),
// //         .dispatch_index(new_rob_index),
// //         .retire_entry(retire_entry)
// //     );

// //     //////////////////////////////////////////////////
// //     //                 Retire Stage                 //
// //     //////////////////////////////////////////////////

// //     retire_stage retire_0(
// //         .rob_head_entry(retire_entry),
// //         .fl_distance(fl_distance),
// //         .BPRecoverEN(BPRecoverEN),
// //         .target_pc(fetch_pc),
// //         .archi_maptable(archi_maptable_out),
// //         .map_ar_pr(map_ar_pr),
// //         .map_ar(map_ar),
// //         .recover_maptable(archi_maptable),
// //         .FreelistHead(FreelistHead),
// //         .Retire_EN(RetireEN),
// //         .Tolds_out(RetireReg),
// //         .BPRecoverHead(BPRecoverHead),
// //         .halt(halt)
// //     );

// // //    assign ROB_RE_NPC_dbg   = fetch_pc;
// // //    assign ROB_RE_inst_dbg  = fu_c_packet.inst;
// // //    assign ROB_RE_valid_dbg = complete_valid;

// //     //////////////////////////////////////////////////
// //     //                   Free List                  //
// //     //////////////////////////////////////////////////

// //     Freelist freelist_0(
// //         .clock(clock),
// //         .reset(reset),
// //         .DispatchEN(dis_new_pr_en),
// //         .RetireEN(RetireEN),
// //         .RetireReg(RetireReg),
// //         .BPRecoverEN(BPRecoverEN),
// //         .FreeReg(free_pr),
// //         .FreeRegValid(free_reg_valid)
// //     );

// //     //////////////////////////////////////////////////
// //     //               Pipeline Outputs               //
// //     //////////////////////////////////////////////////

// //     generate
// //         genvar i;
// //         for (i = 0; i < `N; i = i + 1) begin : gen_commit_packets
// //             always_comb begin
// //                 committed_insts[i].NPC     = fetch_pc; // This is a placeholder; adjust for correct per-instr fetch PC 
// //                 committed_insts[i].data    = wb_value; // Adjust for data you want committed, typically from the ROB
// //                 committed_insts[i].reg_idx = map_ar;  // Correct according to actual register
// //                 committed_insts[i].halt    = halt;
// //                 committed_insts[i].illegal = 0; // Set this based on your design logic
// //                 committed_insts[i].valid   = complete_valid; // Confirm this reflects per-instruction completion
// //             end
// //         end
// //     endgenerate
// endmodule // cpu