`include "sys_defs.svh"
`timescale 1ns/1ps

module stage_issue_tb;
  // Define constants here
  localparam int CLOCK_PERIOD = 10;
  // Clock and reset
  logic                                 clock;
  logic                                 reset;
  RS_ISSUE_PACKET       [`N-1:0]        rs_entry;
  logic                 [3:0]           complete_stall;
  DATA                  [`N-1:0]        read_T1; // read prf output
  DATA                  [`N-1:0]        read_T2; // read prf output
  DATA                  [`N-1:0]        PRF_read_T1; // read prf output
  DATA                  [`N-1:0]        PRF_read_T2; // read prf output
  logic [`N-1:0] [`PR_WIDTH-1:0]        T1_idx;  // request prf valid
  logic [`N-1:0] [`PR_WIDTH-1:0]        T2_idx;  // request prf valid
  ISSUE_PACKET       [`NUM_FU-1:0]      S_out_packet;
  FIFO_STALL_PACKET                     fifo_full;
  ISSUE_PACKET       [`FIFO_SZ-1:0]     alu_fifo_display;
  ISSUE_PACKET       [`FIFO_SZ-1:0]     mult_fifo_display;
  ISSUE_PACKET       [`FIFO_SZ-1:0]     br_fifo_display;
  ISSUE_PACKET       [`FIFO_SZ-1:0]     ls_fifo_display;
  CDB_ENTRY_PACKET [`N-1:0] CDB_in;
  DATA [`PHYS_REG_SZ_R10K-1:0] PRF;
  RS_ISSUE_PACKET [`RS_SZ-1:0]      rs;
  logic [$clog2(`RS_SZ):0]      NumFreeEntriesAfterIssue;
  COMPLETE_PACKET [`NUM_FU-1:0] C_packet;
  CDB_ENTRY_PACKET [`NUM_FU-1:0] CDB_REG;
  logic [1:0]      NumberToDispatch;
  DISPATCH_RS_PACKET     [`N-1:0] RS_in;
  logic test;
  CDB_ENTRY_PACKET [`N-1:0] fake_CDB;

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  rs Rut (
      .clock(clock),
      .reset(reset),
      .RS_in(RS_in),
      .fifo_full(fifo_full),
      .issue_out(rs_entry),
      .NumberToDispatch(NumberToDispatch),
      .NumFreeEntriesAfterIssue(NumFreeEntriesAfterIssue),
      .cdb(CDB_in)
  );
  stage_issue Dut (
    .clock(clock),
    .reset(reset),
    .rs_entry(rs_entry),
    .complete_stall(complete_stall),
    .read_T1(read_T1),
    .read_T2(read_T2),
    .T1_idx(T1_idx),
    .T2_idx(T2_idx),
    .S_out_packet(S_out_packet),
    .fifo_full(fifo_full),
    .alu_fifo_display(alu_fifo_display),
    .mult_fifo_display(mult_fifo_display),
    .br_fifo_display(br_fifo_display),
    .ls_fifo_display(ls_fifo_display)
  );

  s_PhysicalRegisterFile dut (
    .clock(clock),
    .reset(reset),
    .readIDX_Ainput(T1_idx),
    .readIDX_Binput(T2_idx),
    .CDB_in(test ? fake_CDB : CDB_in),
    .readIDX_AdataOutput(PRF_read_T1),
    .readIDX_BdataOutput(PRF_read_T2),
    .PRF_dbg(PRF)
  );

  // Instantiate the stage_ex
  stage_ex uut (
      .Ex_packet(S_out_packet),
      .C_packet(C_packet)
  );

  stage_complete Fut (
      .clock(clock),
      .reset(reset),
      .complete_in(C_packet),
      .complete_stall(complete_stall),
      .complete_cdb_out(CDB_in)
  );

  always_ff @(negedge clock) begin
    if (reset) begin
        CDB_REG = '{default: '0};
    end else begin
        CDB_REG <= CDB_in;
    end
  end

  always_comb begin
    read_T1 = '0;
    read_T2 = '0;
    for (int i = 0; i < `N; i++) begin
      if (C_packet[i].dest_reg_idx == T1_idx) begin
        read_T1[i] = CDB_REG[i].data;
      end else begin
        read_T1[i] = PRF_read_T1;
      end
      if (C_packet[i].dest_reg_idx == T2_idx) begin
        read_T2[i] = CDB_REG[i].data;
      end else begin
        read_T2[i] = PRF_read_T2;
      end
    end 
  end


  // Apply reset initially
  initial begin
    reset = 1;
    #50;
    reset = 0;
  end

  task init_RS_in(input idx, logic valid, logic busy, ALU_FUNC alu_func, 
    MULT_FUNC mult_func, ADDR PC, ADDR NPC, FUNC_UNIT FuncUnitType, ALU_OPA_SELECT opa_select, 
    ALU_OPB_SELECT opb_select, INST inst, logic [`PR_WIDTH-1:0] TD, logic [`PR_WIDTH-1:0] T1, logic T1p,  logic [`PR_WIDTH-1:0] T2, logic T2p);
      RS_in[idx].valid        = valid;         // Set the initial state to invalid
      RS_in[idx].busy         = busy;          // Set busy to false
      RS_in[idx].alu_func     = alu_func;      // Default values for alu_func, adjust as needed
      RS_in[idx].mult_func    = mult_func;     // Default values for mult_func, adjust to your use-case
      RS_in[idx].PC           = PC;            // Default to some initial PC value, if '0' is invalid, adjust accordingly
      RS_in[idx].NPC          = NPC;           // Default to some initial NPC value
      RS_in[idx].FuncUnitType = FuncUnitType;  // Default functional unit type
      RS_in[idx].opa_select   = opa_select;    // Default operand A select
      RS_in[idx].opb_select   = opb_select;    // Default operand B select
      RS_in[idx].inst         = inst;          // Default instruction code
      RS_in[idx].TD           = TD;            // Default physical destination register
      RS_in[idx].T1           = T1;            // Default first operand register
      RS_in[idx].T1p          = T1p;           // Default predicate for T1
      RS_in[idx].T2           = T2;            // Default second operand register
      RS_in[idx].T2p          = T2p;           // Default predicate for T2
  endtask

  task init_one_cdb_fake_packet(input i, logic [`PR_WIDTH-1:0] tag, DATA data);
      test = 1;
      fake_CDB[i].valid = 1'b1;
      fake_CDB[i].tag = tag;
      fake_CDB[i].data = data;
      test = 0;
  endtask

  task init_dual_cdb_fake_packet( logic [`PR_WIDTH-1:0] tag1, DATA data1, logic [`PR_WIDTH-1:0] tag2, DATA data2);
      test = 1;
      fake_CDB[0].valid = 1'b1;
      fake_CDB[0].tag = tag1;
      fake_CDB[0].data = data1;
      fake_CDB[1].valid = 1'b1;
      fake_CDB[1].tag = tag2;
      fake_CDB[1].data = data2;
      test = 0;
  endtask

  task display_dispatch_RS_packets;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | RS_in[%0d] | valid: %b | busy: %b | FuncUnitType: %0d | PC: %0x | NPC: %0x | opa_select: %0d | opb_select: %0d | inst: %0x | TD %h | T1_idx %h | T1p %b | T2_idx %h | T2p %b ",
              $time, i,
              RS_in[i].valid,         
              RS_in[i].busy,
              RS_in[i].FuncUnitType,        
              RS_in[i].PC,          
              RS_in[i].NPC,         
              RS_in[i].opa_select,   
              RS_in[i].opb_select,    
              RS_in[i].inst,        
              RS_in[i].TD,          
              RS_in[i].T1,           
              RS_in[i].T1p,           
              RS_in[i].T2,          
              RS_in[i].T2p);           
    end
  endtask

  task display_RS_packets;
    for (int i = 0; i < `RS_SZ; i++) begin
      $display("%0t ps | RS[%0d] | valid: %b | busy: %b | FuncUnitType: %0d | PC: %0x | NPC: %0x | opa_select: %0d | opb_select: %0d | inst: %0x | TD %h | T1_idx %h | T1p %b | T2_idx %h | T2p %b ",
              $time, i,
              RS_in[i].valid,         
              RS_in[i].busy,
              RS_in[i].FuncUnitType,        
              RS_in[i].PC,          
              RS_in[i].NPC,         
              RS_in[i].opa_select,   
              RS_in[i].opb_select,    
              RS_in[i].inst,        
              RS_in[i].TD,          
              RS_in[i].T1,           
              RS_in[i].T1p,           
              RS_in[i].T2,          
              RS_in[i].T2p);           
    end
  endtask

  task display_RS_Issue;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | rs_entry[%0d] | valid: %b | FuncUnitType: %0d | PC: %0x | NPC: %0x | opa_select: %0d | opb_select: %0d | inst: %0x | T1_idx %h | T1p %b | T2_idx %h | T2p %b ",
              $time, i,
              rs_entry[i].valid,         
              rs_entry[i].FuncUnitType,        
              rs_entry[i].PC,          
              rs_entry[i].NPC,         
              rs_entry[i].opa_select,   
              rs_entry[i].opb_select,    
              rs_entry[i].inst,        
              rs_entry[i].dest_reg_idx,          
              rs_entry[i].T1,           
              rs_entry[i].T1_ready,           
              rs_entry[i].T2,          
              rs_entry[i].T2_ready);           
    end
  endtask

  // Task to initialize RS_ISSUE_PACKET
  task init_rs_entry(
    input int idx, logic valid, ALU_FUNC alu_func, MULT_FUNC mult_func, FUNC_UNIT FuncUnitType, ADDR NPC, ADDR PC, 
    ALU_OPA_SELECT opa_sel, ALU_OPB_SELECT opb_sel, INST inst, 
    int dest_reg_idx, logic  [`PR_WIDTH-1:0] T1, logic T1_ready, logic  [`PR_WIDTH-1:0] T2, logic T2_ready);
    rs_entry[idx].valid = valid;
    rs_entry[idx].alu_func = alu_func;
    rs_entry[idx].mult_func = mult_func;
    rs_entry[idx].FuncUnitType = FuncUnitType;
    rs_entry[idx].NPC = NPC;
    rs_entry[idx].PC = PC;
    rs_entry[idx].opa_select = opa_sel;
    rs_entry[idx].opb_select = opb_sel;
    rs_entry[idx].inst = inst;
    rs_entry[idx].dest_reg_idx = dest_reg_idx;
    rs_entry[idx].T1 = T1;
    rs_entry[idx].T1_ready = T1_ready;
    rs_entry[idx].T2 = T2;
    rs_entry[idx].T2_ready = T2_ready;
  endtask

  task display_cdb_entry_packet;
    for (int i = 0; i < `N; i++) begin
      $display("%0t ps | CDB_ENTRY_PACKET[%0d] | valid: %b | tag: %h | data: %h",
              $time, i,
              CDB_in[i].valid,
              CDB_in[i].tag,
              CDB_in[i].data);
    end
  endtask

  // Test procedure
  initial begin
    // Test case 1: Initialize and drive the inputs
    init_dual_cdb_fake_packet(1, 32'hdead0000, 2, 32'h0000beef);
    @(negedge clock); // populate prf
    init_dual_cdb_fake_packet(3, 32'h000beef, 5, 32'hbeef0000);
    @(negedge clock); // populate prf

    
  $display("\n");
    init_RS_in(0, 1, 1, ALU_ADD, M_MUL, 32'h00, 32'h04, ALU0, OPA_IS_RS1, OPB_IS_RS2, 32'h00000000, 0, 32'h0001, 1,  32'h0002, 1);
    init_RS_in(1, 1, 1, ALU_ADD, M_MUL, 32'h04, 32'h08, ALU1, OPA_IS_RS1, OPB_IS_RS2, 32'h00000000, 0, 32'h0003, 1,  32'h0005, 1);
    #1;
    display_dispatch_RS_packets(); 

    $display("\nDisplay Rs_pack");
    display_RS_packets();
    @(negedge clock); // move onto issue
    #1;


    $display("\nDisplay rs_issue_pack");
    //display_RS_Issue();
    @(negedge clock); // move onto Execute & Complete
    #1;


   $display("\nComplete Stall= %b", complete_stall);
    $display("\nDisplay issue_ex+pack");
    // display_Issue_Ex_packets();
    @(negedge clock); // move onto Execute & Complete
    #1;

   // @(negedge clock);
    // @(negedge clock);
    // @(negedge clock);
    // @(negedge clock);



    $display("\nDisplay Ex_pack");

    $display("\nComplete Stall= %b", complete_stall);
    // display_Ex_Complete_packet();

     $display("\nDisplay CDB");
    display_cdb_entry_packet();


    $finish;
  end

endmodule

