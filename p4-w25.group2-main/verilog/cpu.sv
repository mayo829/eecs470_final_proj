`include "sys_defs.svh"
`include "ISA.svh"

module cpu (
  input  logic clock,
  input  logic reset,

  input  MEM_TAG   mem2proc_transaction_tag,
  input  MEM_BLOCK mem2proc_data,
  input  MEM_TAG   mem2proc_data_tag,

  output MEM_COMMAND proc2mem_command,
  output ADDR        proc2mem_addr,
  output MEM_BLOCK   proc2mem_data,
  output MEM_SIZE    proc2mem_size,

  output FETCH_DBG_PACKET     fetch_dbg,
  output DISPATCH_DBG_PACKET  dispatch_dbg,
  output ISSUE_DBG_PACKET     issue_dbg,
  output EXECUTE_DBG_PACKET   execute_dbg,
  output COMPLETE_DBG_PACKET  complete_dbg,
  output RETIRE_DBG_PACKET    retire_dbg,

  output COMMIT_PACKET [`N-1:0] committed_insts,
  //FOR ROB RS RAT RRAT PRF FREELIST DEBUG
  output ROB_RETIRE_PACKET [`ROB_SZ-1:0] rob_dbg,
  output DISPATCH_RS_PACKET [`RS_SZ-1:0] rs_dbg,
  output RAT_ENTRY_PACKET [0:31] RAT_dbg,
  output logic [31:0][`PR_WIDTH-1:0] arch_map_dbg,
  output CDB_ENTRY_PACKET [1:0] cdb_dbg,
  output DATA [`PHYS_REG_SZ_R10K-1:0] prf_dbg,
  output logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg,
  output logic [`ROB_PTR_WIDTH-1:0] freeList_head_dbg,
  output logic [`ROB_PTR_WIDTH-1:0] freeList_tail_dbg,

  //DEBUG ONLY

  output logic [`ICACHE_LINES-1:0][$bits(MEM_BLOCK)-1:0]  memDataDebug,
  output DCACHE_TAG [`ICACHE_LINES-1:0] dcache_tags_debug
  

);

  // ======== Local Wires & State ========
  logic [`N-1:0][`PR_WIDTH-1:0] T1_idx, T2_idx;
  DATA [`N-1:0] read_T1, read_T2, PRF_read_T1, PRF_read_T2;
  logic [`N-1:0][`PR_WIDTH-1:0] maptable_new_pr;
  FIFO_STALL_PACKET fifo_full;

  DISPATCH_ROB_PACKET [`N-1:0] rob_dispatch_pkt;
  DISPATCH_RS_PACKET  [`N-1:0] rs_dispatch_pkt_internal;
  RS_ISSUE_PACKET     [`N-1:0] rs_issue_pkt;
  logic [1:0]                 num_to_retire;
  logic [31:0][`PR_WIDTH-1:0] arch_map_out_to_RAT;

  ROB_RETIRE_PACKET   [`N-1:0] RobEntriesToRetire;

  logic [`ROB_PTR_WIDTH:0] total_num_free;
  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntries;

  REG_IDX [`N-1:0] rat_src1, rat_src2, rat_dest;
  logic [`N-1:0][`PR_WIDTH-1:0] rat_T, rat_Told, rat_T1, rat_T2;
  logic [`N-1:0] rat_T1p, rat_T2p;
  logic [`N-1:0][`PR_WIDTH-1:0] free_tags;

  logic [`N-1:0] commit_valid;
  REG_IDX [`N-1:0] commit_dest_reg;
  logic [`N-1:0][`PR_WIDTH-1:0] commit_T, commit_Told;
  ADDR  [`N-1:0] commit_PC;

  RETIRE_ARCHMAP_PACKET [`N-1:0] retireOutArchmapIn;
  RETIRE_TO_FREELIST_PACKET RetireToFreeList;
  FREELIST_PACKET_OUT freeList_out;
  logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg_internal;
  logic [`ROB_PTR_WIDTH-1:0] head_dbg, tail_dbg;

  logic  [`ROB_PTR_WIDTH-1:0]         rob_tail;
  logic  [`ROB_PTR_WIDTH-1:0]         ROB_head;
  logic                               dontallowicachebruh;

  CDB_ENTRY_PACKET [1:0] complete_cdb_reg;
  CDB_ENTRY_PACKET [1:0] complete_cdb_out;
  logic [4:0] allowed_to_go;
  logic ld_read_en;
  logic functional_req_ld;

  COMPLETE_PACKET [`NUM_FU-1:0] ex_to_complete_pkt;
  ISSUE_PACKET    [`NUM_FU-1:0] S_out_packet;
  ISSUE_PACKET    [`N-1:0]      store_in;
  SQ_ENTRY [`ROB_SZ-1:0]        sQueue;
  logic [$clog2(`ROB_SZ)-1:0]   SQhead;


  logic [`N-1:0][$clog2(`ROB_SZ)-1:0] sq_pos;
  logic [`N-1:0]                      sq_pos_valid; 
  logic [$clog2(`ROB_SZ)-1:0]         tail_comb;
  logic [$clog2(`ROB_SZ)-1:0]         tail_seq;  
  

 
  logic [`ROB_PTR_WIDTH:0] NumFreeListFreeEntriesAfterRetire;
  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntriesAfterRetire;
  logic [$clog2(`RS_SZ):0] NumFreeRSEntriesAfterIssue;

  // logic [31:0] branch_target_pc;
  logic        misprediction;
  logic sq_retired_req;
  logic store_done;
  logic stall_SQ_retirement;


  ADDR      load2Dcache_addr; 
  logic     load2Dcache_valid;
  MEM_BLOCK dcache2load_data_out; 
  logic     dcache2load_valid_out;


  SQ_PACKET [`N-1:0] sQueue_packet_out;

  //extra debug wires

  logic [`ROB_PTR_WIDTH-1:0] freeList_head_dbg_internal; 
  logic [`ROB_PTR_WIDTH-1:0] freeList_tail_dbg_internal;

  assign freeList_head_dbg = freeList_head_dbg_internal;
  assign freeList_tail_dbg = freeList_tail_dbg_internal;

  // // ======== Memory Control ========
  // MEM_COMMAND Imem_command;
  // ADDR Imem_addr;

  // ADDR        Dmem_addr;
  // MEM_BLOCK   Dmem_store_data;
  // MEM_COMMAND Dmem_command;
  // MEM_SIZE    Dmem_size;

  // always_comb begin
  //   if (Dmem_command != MEM_NONE) begin
  //     proc2mem_command = Dmem_command;
  //     proc2mem_size    = Dmem_size;
  //     proc2mem_addr    = Dmem_addr;
  //   end else begin
  //     proc2mem_command = Imem_command;
  //     proc2mem_addr    = Imem_addr;
  //     proc2mem_size    = DOUBLE;
  //   end
  // end

  // ======== Memory Control ========
  MEM_COMMAND Imem_command;
  ADDR        Imem_addr;

  ADDR        Dmem_addr;
  MEM_BLOCK   Dmem_store_data;
  MEM_COMMAND Dmem_command;
  MEM_SIZE    Dmem_size;
  CACHE_BUFFER_PACKET cache_buffer_packet_in;
  CACHE_BUFFER_PACKET cache_buffer_packet_out;
  logic  cache_buffer_full;
  MEM_TAG   Imem2proc_transaction_tag;
  MEM_TAG   Dmem2proc_transaction_tag;
  logic     Dgot_mem_data, Igot_mem_data;

  
always_comb begin
    // Default: fetch can go if D-cache isn't active
    cache_buffer_packet_in.valid = 1'b0;
    cache_buffer_packet_in.cache_type = RESTARTED;
    Imem2proc_transaction_tag = '0;
    Dmem2proc_transaction_tag = '0;
    if (Dmem_command != MEM_NONE) begin
      proc2mem_command = Dmem_command; // check this on wave
      proc2mem_addr    = Dmem_addr; // this is a stable request
      cache_buffer_packet_in.valid = 1'b1;
      cache_buffer_packet_in.cache_type = DTYPE;
      proc2mem_data    = (Dmem_command == MEM_STORE) ? Dmem_store_data : '0; // not used yet, safe default
      Dmem2proc_transaction_tag = mem2proc_transaction_tag;
    end else begin
      proc2mem_command = Imem_command; 
      proc2mem_addr    = Imem_addr; // this is a stable requr
      proc2mem_data    = '0;      // don't drive garbage if Dmem isn't active
      cache_buffer_packet_in.valid = (Imem_command == MEM_LOAD) ? 1'b1 : 1'b0;
      cache_buffer_packet_in.cache_type = (Imem_command == MEM_LOAD) ? ITYPE : RESTARTED;
      Imem2proc_transaction_tag = (Imem_command == MEM_LOAD) ? mem2proc_transaction_tag : '0;
    end
  end

  cache_buffer cache_buffer_inst (
    .clock(clock),
    .reset(reset | misprediction),
    .rd_EN({mem2proc_transaction_tag > '0}),
    .wr_EN(cache_buffer_packet_in.valid),
    .fifo_pckt_in(cache_buffer_packet_in),
    .full(cache_buffer_full), // this will never happen lol
    .fifo_pckt_out(cache_buffer_packet_out)
  );




  // information that will be constantly streaming to the I cache and d cache
  // have a got_mem_data variable that will be high when Dca == 


  // ======== Fetch + IB ========
  logic ib_full;
  logic if_valid;
  logic jalr_resolved;
  logic [1:0] request;
  logic [1:0] FreeListRequest;
  logic [1:0] sq_req;
  FETCH_DISPATCH_PACKET  [1:0]                    if_packet_fetch;
  FETCH_DISPATCH_PACKET  [1:0]                    ib_pckt_out;
  FETCH_DISPATCH_PACKET  [`FIFO_SZ_IB-1:0]           fifo;
  logic                  [$clog2(`FIFO_SZ_IB)-1:0]   head;

  
  logic                   [$clog2(`ROB_SZ)-1:0]   robs_head;

  ADDR      correct_pc;


  //assign if_valid = 'b1;

  logic start_valid_on_reset;

  always_ff@(posedge clock) begin
    if(reset)begin
    start_valid_on_reset  <= 1;
    // Dmem_command <= MEM_NONE;
    end
  end

  COMMIT_PACKET [`N-1:0] committed_insts_wire;

  logic predicted_branch;


  assign if_valid = start_valid_on_reset;

      stage_if stage_if_0 (
        .clock(clock),
        .reset(reset),
        .ib_full(ib_full),
        .if_valid(if_valid),
        .BP_Prediction(predicted_branch),
        .correct_pc(correct_pc),
        .jalr_resolved(jalr_resolved),
        .Imem_data(mem2proc_data),
        .Imem2proc_transaction_tag(Imem2proc_transaction_tag),
        .Imem2proc_data_tag(mem2proc_data_tag),
        .misprediction(misprediction),
        .Imem_command(Imem_command),
        .if_packet(if_packet_fetch),
        .Imem_addr(Imem_addr)
        
      );   
     
      bp2b bp2b (
        .clock(clock),
        .reset(reset),
        .committed_inst(committed_insts_wire),
        .predicted_branch(predicted_branch)
      ); 

      ib instb (
        .clock(clock),
        .reset(reset | misprediction),
        .rd_EN(request),
        .wr_EN({if_packet_fetch[1].valid, if_packet_fetch[0].valid}),
        .fifo_pckt_in(if_packet_fetch),
        .full(ib_full),
        .fifo_pckt_out(ib_pckt_out),
        .fifo(fifo),
        .head(head)
      );

  // ======== Dispatch Decision Logic ========//
  logic [1:0] numbertodispatch;
  logic [1:0] num_ib_entries_valid;
  logic [1:0] kys;

  always_comb begin
    automatic logic [$clog2(`RS_SZ+1):0] min_slots;

    case ({fifo[(head + 1) % `FIFO_SZ_IB].valid, fifo[head].valid})
      2'b00: num_ib_entries_valid = 2'd0;
      2'b01: num_ib_entries_valid = 2'd1;
      2'b10: num_ib_entries_valid = 2'd0;
      2'b11: num_ib_entries_valid = 2'd2;
      default: num_ib_entries_valid = 2'd0;
    endcase

    request = 2'b00;
    numbertodispatch = 2'd0;
    min_slots = `N;

    if (NumFreeListFreeEntriesAfterRetire < min_slots)
      min_slots = NumFreeListFreeEntriesAfterRetire;
    if (NumROBFreeEntriesAfterRetire < min_slots)
      min_slots = NumROBFreeEntriesAfterRetire;
    if (NumFreeRSEntriesAfterIssue < min_slots)
      min_slots = NumFreeRSEntriesAfterIssue;
    if (num_ib_entries_valid < min_slots)
      min_slots = num_ib_entries_valid;

    if (min_slots >= 2) begin
      request = 2'b11;
      numbertodispatch = 2'd2;
    end else if (min_slots == 1) begin
      request = 2'b01;
      numbertodispatch = 2'd1;
    end
    FreeListRequest = kys & request;
  end


  // ======== Dispatch ========
  logic [1:0] free_valid;
  assign free_valid = freeList_out.valid;

      stage_dispatch dispatch_inst (
        .clock(clock), .reset(reset | misprediction),
        .fetched_in(ib_pckt_out),
        .NumFreeEntriesAfterIssue(NumFreeRSEntriesAfterIssue),
        .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
        .dispatch_stall_i(request),
        .free_valid_i(free_valid),
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
        .rs_in(rs_dispatch_pkt_internal),
        .sq_pos(sq_pos),
        .sq_pos_valid(sq_pos_valid),
        .tail_comb(tail_comb),
        .tail_seq(tail_seq),
        .sq_req(sq_req),
        .rob_tail(rob_tail),
        .kys(kys)
      );


  // ======== RAT ========
      s_RegisterAliasTable rat_inst (
        .clock(clock), .reset(reset),
        .misprediction(misprediction),
        .arc_src1_regs(rat_src1), .arc_src2_regs(rat_src2), .arc_dest_regs(rat_dest),
        .free_physical_register_indicies(freeList_out),
        .cdb_valid({complete_cdb_reg[1].valid, complete_cdb_reg[0].valid}),
        .cdb_tag({complete_cdb_reg[1].tag, complete_cdb_reg[0].tag}),
        .arch_map_out_to_RAT(arch_map_out_to_RAT),
        .Told(rat_Told), .T(rat_T), .T1(rat_T1), .T1p(rat_T1p),
        .T2(rat_T2), .T2p(rat_T2p),
        .RAT_dbg(RAT_dbg)
      );

  // ======== RS ========
      rs rs_inst (
        .clock(clock), .reset(reset | misprediction),
        .RS_in(rs_dispatch_pkt_internal),
        .fifo_full(fifo_full),
        .issue_out(rs_issue_pkt),
        .NumberToDispatch(numbertodispatch),
        .NumFreeEntriesAfterIssue(NumFreeRSEntriesAfterIssue),
        .cdb(complete_cdb_reg),
        .head(SQhead),
        .rs_dbg(rs_dbg)
      );

  // ======== ROB ========
      rob rob_inst (
        .clock(clock), .reset(reset | misprediction),
        .DispatchEntryValid({rob_dispatch_pkt[1].valid, rob_dispatch_pkt[0].valid}),
        .NumberToDispatch(numbertodispatch),
        .dispatch_PC({rob_dispatch_pkt[1].PC, rob_dispatch_pkt[0].PC}),
        .dispatch_dest_reg({rob_dispatch_pkt[1].dest_reg, rob_dispatch_pkt[0].dest_reg}),
        .dispatch_T({rob_dispatch_pkt[1].TD, rob_dispatch_pkt[0].TD}),
        .dispatch_Told({rob_dispatch_pkt[1].Told, rob_dispatch_pkt[0].Told}),
        .halt({rob_dispatch_pkt[1].halt, rob_dispatch_pkt[0].halt}),
        .is_branch({rob_dispatch_pkt[1].is_branch, rob_dispatch_pkt[0].is_branch}),
        .dispatch_SPEC_PC({rob_dispatch_pkt[1].SPEC_PC, rob_dispatch_pkt[0].SPEC_PC}),
        .is_store({rob_dispatch_pkt[1].is_store, rob_dispatch_pkt[0].is_store}),
        .inst({rob_dispatch_pkt[1].inst, rob_dispatch_pkt[0].inst}),
        .NumFreeEntries(NumROBFreeEntries),
        .CDB_in(complete_cdb_reg),
        .store_complete({fromStorePipe_toSQ[1].valid , fromStorePipe_toSQ[0].valid}),
        .store_rob_ptr({fromStorePipe_toSQ[1].rob_ptr , fromStorePipe_toSQ[0].rob_ptr}),
        .performStoreReq(sQueue[SQhead].valid),
        .store_done(store_done),
        .stallStore(stall_SQ_retirement),
        .commit_valid(commit_valid),
        .commit_dest_reg(commit_dest_reg),
        .commit_T(commit_T),
        .commit_Told(commit_Told),
        .commit_PC(commit_PC),
        .RobEntriesToRetire(RobEntriesToRetire),
        .sq_retired_req(sq_retired_req),

       .tail(rob_tail),
        .rob_dbg(rob_dbg)

      );

  
  // ======== Issue ========
  DATA [`N-1:0] issue_T1, issue_T2;

  always_comb begin
    for (int i = 0; i < `N; i++) begin
      issue_T1[i] = read_T1[i];
      issue_T2[i] = read_T2[i];
      for (int c = 0; c < 2; c++) begin
        if (complete_cdb_reg[c].valid && complete_cdb_reg[c].tag == T1_idx[i])
          issue_T1[i] = (T1_idx[i] == '0) ? '0 : complete_cdb_reg[c].data;

        if (complete_cdb_reg[c].valid && complete_cdb_reg[c].tag == T2_idx[i]) 
          issue_T2[i] = (T2_idx[i] == '0) ? '0 : complete_cdb_reg[c].data;

      end
    end
  end

    logic [3:0]  functional_req;


      stage_issue issue_stage (
        .clock(clock), .reset(reset | misprediction),
        .rs_entry(rs_issue_pkt),
        .allowed_to_go(allowed_to_go),
        .mult_done(ex_to_complete_pkt[2].valid),
        .ld_read_en(ld_read_en),
        .read_T1(issue_T1),
        .read_T2(issue_T2),
        .T1_idx(T1_idx),
        .T2_idx(T2_idx),
        .S_out_packet(S_out_packet),
        .store_in(store_in),
        .fifo_full(fifo_full),
        .functional_req(functional_req),
        .stall_SQ_retirement(stall_SQ_retirement)//,
        // .alu_fifo_display(),
        // .mult_fifo_display(),
        // .br_fifo_display(),
        // .ls_fifo_display()
      );

  assign freeList_dbg = freeList_dbg_internal;

  // ===== StorePipeline ======

  COMPLETE_SQ_PACKET [`N-1:0] fromStorePipe_toSQ; // DONT FORGET THIS, tie it to the SQ

  store_pipeline SP (
    .clock(clock),
    .reset(reset | misprediction), //DONT FORGET THE BRANCH TAKEN LOGIC TO FLUSH ALL THE REGS IN HERE
    .IssuedStoreInstructions(store_in),
    .SQ_in_packet(fromStorePipe_toSQ)
  );


  // ======== Store Queue ========
     SQ SQ_inst (
      .clock(clock),
      .reset(reset | misprediction), //DONT FORGET THE BRANCH TAKEN LOGIC TO FLUSH ALL THE REGS IN HERE
      .branch_mispredict('0),
      .complete_sq_packet(fromStorePipe_toSQ),
      .retired_req({1'b0 , sq_retired_req}),
      .store_done(store_done),
      .sQueue_packet_out(sQueue_packet_out),
      .dispatch_req(sq_req),
      .sq_pos(sq_pos),
      .sq_pos_valid(sq_pos_valid),
      .tail_comb(tail_comb),
      .tail_seq(tail_seq),
      .sQueue(sQueue),
      .head(SQhead)
    );


  // ======== Complete ========

    logic [4:0] functional_req_in;

    assign functional_req_in[0] = functional_req[0];
    assign functional_req_in[1] = functional_req[1];
    assign functional_req_in[2] = functional_req[2];
    assign functional_req_in[3] = functional_req[3];
    assign functional_req_in[4] = functional_req_ld;


      stage_complete complete_stage (
        .clock(clock), .reset(reset | misprediction),
        .complete_in(ex_to_complete_pkt),
        .functional_req(functional_req_in),
        .allowed_to_go(allowed_to_go),
        .complete_cdb_out(complete_cdb_out)
      );


    always_ff @(posedge clock) begin
    if (reset) begin
      complete_cdb_reg <= '{default: '0};
    end else if (misprediction) begin
      complete_cdb_reg <= '{default: '0};
    end else begin
      complete_cdb_reg <= complete_cdb_out;
    end
  end

  assign cdb_dbg = complete_cdb_reg;


  // ======== Execute ========
  // TODO DONT FORGET THE CASE WHERE STORE IS STILL STORING TO CACHE AND THERE MAY 
  // BE A LOAD INSTRUCTION THAT MADE IT ALLLLL THE WAY TO LOAD UNIT AND NOW IS TRYNA ACCESS CACHE
  // because loads are self centered and dont even look at cache, they just look at themselves
  // just simple backpressure or gating needed
    

    
    stage_ex ex_stage (
      .reset(reset | misprediction),
      .clock(clock),
      .stall(!allowed_to_go[2] & ex_to_complete_pkt[2].valid),
      .Ex_packet(S_out_packet),
      .C_packet(ex_to_complete_pkt),
      .load2Dcache_addr(load2Dcache_addr),
      .load2Dcache_valid(load2Dcache_valid),
      .dcache2load_data_out(dcache2load_data_out),
      .dcache2load_valid_out(dcache2load_valid_out),
      .ld_read_en(ld_read_en),
      .functional_req_ld(functional_req_ld)
    );

  // ======== Retire ========
  DATA [1:0] testingTDATA;

      stage_retire retire_stage (
        .NumROBFreeEntries(NumROBFreeEntries),
        .total_num_free(total_num_free),
        .RobEntriesToRetire(RobEntriesToRetire),
        .retireOutArchmapIn(retireOutArchmapIn),
        .RetireToFreeList(RetireToFreeList),
        .NumROBFreeEntriesAfterRetire(NumROBFreeEntriesAfterRetire),
        .NumFreeListFreeEntriesAfterRetire(NumFreeListFreeEntriesAfterRetire),
        .testingTDATA(testingTDATA),
        .committed_insts(committed_insts_wire)
      );

  always_ff @(posedge clock) begin
    if (reset) begin
      committed_insts <= '{default: 0};
    end else begin
      committed_insts <= committed_insts_wire;
    end
  end

  always_comb begin
    // misprediction = 1'b0;
  
    if (committed_insts_wire[0].valid && committed_insts_wire[0].is_branch && committed_insts_wire[0].target_pc != committed_insts_wire[0].SPEC_PC) begin
    jalr_resolved = 1'b0;
    misprediction = 1'b1;
    correct_pc = committed_insts_wire[0].target_pc;

    end else if (committed_insts_wire[1].valid && committed_insts_wire[1].is_branch && committed_insts_wire[1].target_pc != committed_insts_wire[1].SPEC_PC) begin
    jalr_resolved = 1'b0;
    misprediction = 1'b1;
    correct_pc = committed_insts_wire[1].target_pc;

    end else if (committed_insts_wire[0].valid && committed_insts_wire[0].inst[6:0] == `RV32_JALR_OP) begin
    misprediction = 1'b0;
    jalr_resolved = 1'b1;
    correct_pc = committed_insts_wire[0].target_pc;

    end else if (committed_insts_wire[1].valid && committed_insts_wire[1].inst[6:0] == `RV32_JALR_OP) begin
    misprediction = 1'b0;
    jalr_resolved = 1'b1;
    correct_pc = committed_insts_wire[1].target_pc;
    end else begin
    misprediction = 1'b0;
    correct_pc = 0;
    jalr_resolved = 1'b0;
    end
  end


  // ======== ArchMap ========
  s_ArchitecturalMap archmap_inst (
    .clock(clock), .reset(reset),
    .commit_valid({retireOutArchmapIn[1].commit_valid, retireOutArchmapIn[0].commit_valid}),
    .commit_arch_reg({retireOutArchmapIn[1].commit_arch_reg, retireOutArchmapIn[0].commit_arch_reg}),
    .commit_phys_reg({retireOutArchmapIn[1].commit_phys_reg, retireOutArchmapIn[0].commit_phys_reg}),
    .arch_map_out(arch_map_dbg),
    .arch_map_out_to_RAT(arch_map_out_to_RAT)
  );
  

  // ======== PRF ========
      s_PhysicalRegisterFile prf_inst (
        .clock(clock), .reset(reset),
        .readIDX_Ainput(T1_idx),
        .readIDX_Binput(T2_idx),
        .CDB_in(complete_cdb_reg),
        .readIDX_AdataOutput(read_T1),
        .readIDX_BdataOutput(read_T2),
        .prf_dbg(prf_dbg),
        .testingTindicies({retireOutArchmapIn[1].commit_phys_reg , retireOutArchmapIn[0].commit_phys_reg}),
        .testingTDATA(testingTDATA)
      );


  // ======== Free List ========
      freeList freeList_inst (
        .clock(clock), .reset(reset),
        .freeList_in(RetireToFreeList),
        .dispatch_req(FreeListRequest),
        .mispredict(misprediction),
        .freeList_out(freeList_out),
        .total_num_free(total_num_free),
        .freeList_dbg(freeList_dbg_internal),
        .freeList_head_dbg(freeList_head_dbg_internal),
        .freeList_tail_dbg(freeList_tail_dbg_internal)

      );



    // TODO HOOK UP THE CACHE WITH LOAD, DO NOT WORRY ABOUT STORES YET, NO NEED FOR ARBITRATION, JUST USE SIGNAL TO TELL LOAD NOT TO GO YET


  // ADDR      load2Dcache_addr; 
  // logic     load2Dcache_valid;

  // MEM_BLOCK dcache2load_data_out; 
  // logic     dcache2load_valid_out;

  // todo remember to remove this after debugging
  logic blahblah;
  assign blahblah = sQueue_packet_out[0].valid ;
  // ======== D Cache ========    

  //     mem2Dcache_transaction_tag  = mem2proc_transaction_tag;
  //     mem2Dcache_data             = mem2proc_data;               
  //     mem2Dcache_data_tag         = mem2proc_data_tag;       

    dcache DC (
      .clock(clock),
      .reset(reset),
      .mispredict(misprediction),
      .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
      .Dmem2proc_data(mem2proc_data),
      .Dmem2proc_data_tag(mem2proc_data_tag),
      .proc2Dmem_command(Dmem_command),
      .proc2Dmem_addr(Dmem_addr),
      .proc2Dmem_data_out(Dmem_store_data),


      // From load 
      .load2Dcache_addr(load2Dcache_addr), // this goes to Dcache_data_in on FU load
      .load2Dcache_valid(load2Dcache_valid),// this goes to Dcache_valid_in on FU load

      // To load unit
      .dcache2load_data_out(dcache2load_data_out), // Data is mem[load2Dcache_addr]
      .dcache2load_valid_out(dcache2load_valid_out), // When valid is high

      // From store 
      .store2Dcache_addr(sQueue_packet_out[0].address),
      .store2Dcache_size(sQueue_packet_out[0].mem_size),
      .store2Dcache_data(sQueue_packet_out[0].value),
      .store2Dcache_valid(blahblah),
      .store_done(store_done),
      .memDataDebug(memDataDebug),
      .dcache_tags_debug(dcache_tags_debug)
    );


// ======== Debug Packets (Internal) ========
FETCH_DBG_PACKET     fetch_dbg_int;
DISPATCH_DBG_PACKET  dispatch_dbg_int;
ISSUE_DBG_PACKET     issue_dbg_int;
EXECUTE_DBG_PACKET   execute_dbg_int;
COMPLETE_DBG_PACKET  complete_dbg_int;
RETIRE_DBG_PACKET    retire_dbg_int;

// ---- Fetch Stage Debug ----
assign fetch_dbg_int.valid = ib_pckt_out[0].valid;
assign fetch_dbg_int.PC    = ib_pckt_out[0].PC;
assign fetch_dbg_int.NPC   = ib_pckt_out[0].NPC;
assign fetch_dbg_int.inst  = ib_pckt_out[0].inst;

// ---- Dispatch Stage Debug ----
assign dispatch_dbg_int.valid     = rob_dispatch_pkt[0].valid;
assign dispatch_dbg_int.PC        = rob_dispatch_pkt[0].PC;
assign dispatch_dbg_int.inst      = rob_dispatch_pkt[0].instruction;
assign dispatch_dbg_int.arch_dest = rob_dispatch_pkt[0].dest_reg;
assign dispatch_dbg_int.T         = rob_dispatch_pkt[0].TD;
assign dispatch_dbg_int.Told      = rob_dispatch_pkt[0].Told;
assign dispatch_dbg_int.halt      = rob_dispatch_pkt[0].halt;

// ---- Issue Stage Debug ----
assign issue_dbg_int.valid         = rs_issue_pkt[0].valid;
assign issue_dbg_int.PC            = rs_issue_pkt[0].PC;
assign issue_dbg_int.NPC           = rs_issue_pkt[0].NPC;
assign issue_dbg_int.inst          = rs_issue_pkt[0].inst;
assign issue_dbg_int.T1            = rs_issue_pkt[0].T1;
assign issue_dbg_int.T2            = rs_issue_pkt[0].T2;
assign issue_dbg_int.val1          = issue_T1[0];
assign issue_dbg_int.val2          = issue_T2[0];
assign issue_dbg_int.T1_ready      = rs_issue_pkt[0].T1_ready;
assign issue_dbg_int.T2_ready      = rs_issue_pkt[0].T2_ready;
assign issue_dbg_int.dest_reg_idx  = rs_issue_pkt[0].dest_reg_idx;
assign issue_dbg_int.FuncUnitType  = rs_issue_pkt[0].FuncUnitType;

// ---- Execute Stage Debug ----
assign execute_dbg_int.valid         = S_out_packet[0].valid;
assign execute_dbg_int.PC            = S_out_packet[0].PC;
assign execute_dbg_int.NPC           = S_out_packet[0].NPC;
assign execute_dbg_int.inst          = S_out_packet[0].inst;
assign execute_dbg_int.result        = ex_to_complete_pkt[0].result;
assign execute_dbg_int.dest_reg_idx  = ex_to_complete_pkt[0].dest_reg_idx;
assign execute_dbg_int.FuncUnitType  = S_out_packet[0].FuncUnitType;

// ---- Complete Stage Debug ----
assign complete_dbg_int.valid          = complete_cdb_out[0].valid;
assign complete_dbg_int.tag            = complete_cdb_out[0].tag;
assign complete_dbg_int.data           = complete_cdb_out[0].data;
assign complete_dbg_int.if_take_branch = complete_cdb_out[0].if_take_branch;
assign complete_dbg_int.target_pc      = complete_cdb_out[0].target_pc;

// ---- Retire Stage Debug ----
assign retire_dbg_int.valid           = committed_insts[0].valid;
assign retire_dbg_int.NPC             = committed_insts[0].NPC;
assign retire_dbg_int.data            = committed_insts[0].data;
assign retire_dbg_int.reg_idx         = committed_insts[0].reg_idx;
assign retire_dbg_int.halt            = committed_insts[0].halt;
assign retire_dbg_int.illegal         = committed_insts[0].illegal;
assign retire_dbg_int.is_branch       = committed_insts[0].is_branch;
assign retire_dbg_int.if_take_branch  = committed_insts[0].if_take_branch;
assign retire_dbg_int.target_pc       = committed_insts[0].target_pc;

// ======== Connect Outputs ========
assign fetch_dbg     = fetch_dbg_int;
assign dispatch_dbg  = dispatch_dbg_int;
assign issue_dbg     = issue_dbg_int;
assign execute_dbg   = execute_dbg_int;
assign complete_dbg  = complete_dbg_int;
assign retire_dbg    = retire_dbg_int;

endmodule