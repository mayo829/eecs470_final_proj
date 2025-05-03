`include "sys_defs.svh"

module stage_issue(
    input   logic                                         clock,
    input   logic                                         reset,
	input 	RS_ISSUE_PACKET 	  [`N-1:0]                rs_entry,
	input 	DATA         		  [`N-1:0]                read_T1,  //from PRF
    input   DATA                  [`N-1:0]                read_T2,  //from PRF
    input   [4:0]               			              allowed_to_go, // from complete stage psel
    input   logic                                         mult_done,
    input   logic                                         ld_read_en,
	output  logic [`N-1:0] [`PR_WIDTH-1:0]                T1_idx,   //to PRF
    output  logic [`N-1:0] [`PR_WIDTH-1:0]                T2_idx,   //to PRF
	output 	ISSUE_PACKET       [`NUM_FU-1:0]              S_out_packet,
    output  ISSUE_PACKET       [`N-1:0]                   store_in,
    output  FIFO_STALL_PACKET                             fifo_full,
    output  logic              [3:0]                      functional_req,

    output  logic                                         stall_SQ_retirement//,

    // // debug signals
    // output  ISSUE_PACKET       [`FIFO_SZ-1:0]             alu_fifo_display, 
    // output  ISSUE_PACKET       [`FIFO_SZ-1:0]             mult_fifo_display, 
    // output  ISSUE_PACKET       [`FIFO_SZ-1:0]             br_fifo_display, 
    // output  ISSUE_PACKET       [`FIFO_SZ-1:0]             ls_fifo_display   
);

ISSUE_PACKET [`N-1:0] issue;
ISSUE_PACKET [`NUM_FU:0] trash;

logic                  [$clog2(`FIFO_SZ)-1:0]   headALU;
logic                  [$clog2(`FIFO_SZ)-1:0]   headMULT;
logic                  [$clog2(`FIFO_SZ)-1:0]   headLD;
logic                  [$clog2(`FIFO_SZ)-1:0]   headBR;


ISSUE_PACKET [`FIFO_SZ-1:0]    fifoALU;
ISSUE_PACKET [`FIFO_SZ-1:0]    fifoMULT;
ISSUE_PACKET [`FIFO_SZ-1:0]    fifoLD;
ISSUE_PACKET [`FIFO_SZ-1:0]    fifoBR;

// THIS GETS VALUE FROM PRF
always_comb begin
    for(int i=0; i<`N; i++) begin
        T1_idx[i] = rs_entry[i].T1;
        T2_idx[i] = rs_entry[i].T2;
    end
end

always_comb begin
    for(int i=0; i<`N; i++) begin
        issue[i].valid           = rs_entry[i].valid;
        issue[i].alu_func        = rs_entry[i].alu_func;
        issue[i].mult_func       = rs_entry[i].mult_func;
        issue[i].FuncUnitType    = rs_entry[i].FuncUnitType;
        issue[i].NPC             = rs_entry[i].NPC;
        issue[i].PC              = rs_entry[i].PC;
        issue[i].opa_select      = rs_entry[i].opa_select;
        issue[i].opb_select      = rs_entry[i].opb_select;
        issue[i].inst            = rs_entry[i].inst;
        issue[i].dest_reg_idx    = rs_entry[i].dest_reg_idx;
        issue[i].mem_size        = rs_entry[i].mem_size;
        issue[i].sq_pos          = rs_entry[i].sq_pos;
        issue[i].rob_ptr         = rs_entry[i].rob_ptr;
        issue[i].r1_value        = read_T1[i];
        issue[i].r2_value        = read_T2[i];

    end
end

/////////////////////////////////////////////////////
//                   FU FIFO                       //
/////////////////////////////////////////////////////

//FIFO ENTRIES
ISSUE_PACKET [`N-1:0] alu_fifo_in  ;
ISSUE_PACKET [`N-1:0] mult_fifo_in ;
ISSUE_PACKET [`N-1:0] ls_fifo_in   ;
ISSUE_PACKET [`N-1:0] br_fifo_in   ;
logic        [1:0]    alu_av;
logic        [1:0]    mult_av;
logic        [1:0]    branch_av;


always_comb begin
    alu_fifo_in  = '{default: '0};
    mult_fifo_in = '{default: '0};
    ls_fifo_in   = '{default: '0};
    br_fifo_in   = '{default: '0};
    store_in     = '{default: '0};
    for(int i=0; i<`N; i++) begin
        alu_fifo_in[i]    = (rs_entry[i].FuncUnitType   == ALU0) || (rs_entry[i].FuncUnitType == ALU1) ? issue[i] : 0;
        alu_av[0]         = (rs_entry[i].FuncUnitType   == ALU0) ? 1 : 0;
        alu_av[1]         = (rs_entry[i].FuncUnitType   == ALU1) ? 1 : 0;
        mult_fifo_in[i]   = rs_entry[i].FuncUnitType   == MULT    ? issue[i] : 0;
        mult_av[i]        = rs_entry[i].FuncUnitType   == MULT    ? 1 : 0;
        br_fifo_in[i]     = rs_entry[i].FuncUnitType   == BRANCH  ? issue[i] : 0;
        branch_av[i]      = rs_entry[i].FuncUnitType   == BRANCH  ? 1 : 0;
        ls_fifo_in[i]     = rs_entry[i].FuncUnitType   == LS  ? issue[i] : 0;
        store_in[i]       = rs_entry[i].FuncUnitType   == ST  ? issue[i] : 0;
    end
end

// make logic to change rd_en 

FIFO alu_fifo(
    .clock(clock),
    .reset(reset),
    .rd_EN({allowed_to_go[int'(ALU1)], allowed_to_go[int'(ALU0)]}),
    .wr_EN({alu_fifo_in[1].valid, alu_fifo_in[0].valid}),
    .fifo_pckt_in({alu_fifo_in[1], alu_fifo_in[0]}),
    .full(fifo_full.alu),
    .fifo_pckt_out({S_out_packet[int'(ALU1)], S_out_packet[int'(ALU0)]}), 
    .fifo(fifoALU),
    .head(headALU)
);

FIFO ls_fifo(
    .clock(clock),
    .reset(reset),
    .rd_EN({1'b0, ld_read_en}),
    .wr_EN({ls_fifo_in[1].valid, ls_fifo_in[0].valid}),
    .fifo_pckt_in(ls_fifo_in),
    .full(fifo_full.ls),
    .fifo_pckt_out({trash[int'(LS)], S_out_packet[int'(LS)]}), 
    .fifo(fifoLD),
    .head(headLD)
);

FIFO mult_fifo(
    .clock(clock),
    .reset(reset),
    .rd_EN({1'b0, allowed_to_go[int'(MULT)] || !mult_done}),
    .wr_EN({mult_fifo_in[1].valid, mult_fifo_in[0].valid}),
    .fifo_pckt_in(mult_fifo_in),
    .full(fifo_full.mult),
    .fifo_pckt_out({trash[int'(MULT)], S_out_packet[int'(MULT)]}), 
    .fifo(fifoMULT),
    .head(headMULT)
);

FIFO br_fifo(
    .clock(clock),
    .reset(reset),
    .rd_EN({1'b0, allowed_to_go[int'(BRANCH)]}),
    .wr_EN({br_fifo_in[1].valid, br_fifo_in[0].valid}),
    .fifo_pckt_in(br_fifo_in),
    .full(fifo_full.branch),
    .fifo_pckt_out({trash[int'(BRANCH)], S_out_packet[int'(BRANCH)]}), 
    .fifo(fifoBR),
    .head(headBR)
);



assign functional_req[0] = fifoALU[headALU].valid;
assign functional_req[1] = fifoALU[(headALU + 1) % `FIFO_SZ].valid;
//assign functional_req[2] = fifoMULT[headMULT].valid;
// assign functional_req[3] = fifoLD[headLD].valid;
assign functional_req[2] = mult_done;
assign functional_req[3] = fifoBR[headBR].valid;


assign stall_SQ_retirement = fifoLD[headLD].valid;

endmodule