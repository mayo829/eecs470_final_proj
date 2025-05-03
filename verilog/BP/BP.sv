module BP_top (
    input  clock, reset,
    input  ADDR [`SCALAR-1:0]  if_pc_in,    // pc from if stage
    input  INST  [`SCALAR-1:0] inst,    // instruction
    input  EX_BP_PACKET  [`SCALAR-1:0] ex_bp_packet_in,
    input  [`SCALAR-1:0] valid,
    
    output ADDR [`SCALAR-1:0] bp_pc_out,
    output ADDR [`SCALAR-1:0] bp_npc_out,
    output logic bp_taken
);
    logic [`SCALAR-1:0][`BHT_WIDTH-1:0] bht_if_out;    // output the value stored in BHT to PHT
    logic [`SCALAR-1:0][`BHT_WIDTH-1:0] bht_ex_out;    // output the value stored in BHT to PHT
    ADDR link_pc;    // link pc
    logic push;    // 1 if instruction is JAL
    logic pop;     // 1 if instruction is JALR   
    logic [`SCALAR-1:0] predict_taken;
    

    // BTB output
    logic [`SCALAR-1:0] hit;    // 1 if pc hit buffer 
    ADDR [`SCALAR-1:0]  predict_pc_out;

    // RAS output
    ADDR return_addr;    // return pc only when  current insn is JALR

    // pre_decoder output
    logic [`SCALAR-1:0] cond_branch, uncond_branch;
    logic [`SCALAR-1:0] jump,link;
    
    assign bp_taken = link[0] | (jump[0] & hit[0]) | (cond_branch[0] & predict_taken[0] & hit[0]);
    
    

    // control the RAS 
    always_comb begin
        logic jalr_flag;
        assign jalr_flag = 0;
        for (int i = 0 ; i < `SCALAR; i++) begin
            if (jump[i]) begin
                push = valid[i];
                pop  = 0;
                jalr_flag = 1;
                break;
            end
            else if (link[i]) begin
                push = 0;
                pop  = valid[i];
                jalr_flag = 1;
                break;
            end 
        end
        if (!jalr_flag) begin
            push = 0;
            pop  = 0;
        end
    end

    assign link_pc = jump[0] ?  if_pc_in[0] : if_pc_in[1];
    

    // choose next pc
    always_comb begin
        if (link[0]) begin
            bp_npc_out[0] = return_addr;
            bp_npc_out[1] = return_addr + 4;
            bp_pc_out[0] = return_addr;
            bp_pc_out[1] = return_addr + 4;
        end
        else if (jump[0] && hit[0]) begin
            bp_npc_out[0] = predict_pc_out[0];
            bp_npc_out[1] = predict_pc_out[0] + 4;
            bp_pc_out[0] =  predict_pc_out[0];
            bp_pc_out[1] =  predict_pc_out[0] + 4;
        end
        else if (cond_branch[0] && predict_taken[0] && hit[0]) begin
            bp_npc_out[0] = predict_pc_out[0];
            bp_npc_out[1] = predict_pc_out[0] + 4;
            bp_pc_out[0] =  predict_pc_out[0];
            bp_pc_out[1] =  predict_pc_out[0] + 4;
        end
        else if (link[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = return_addr;
            bp_pc_out[0] =  return_addr;
            bp_pc_out[1] =  return_addr+4;
        end
        else if (jump[1] && hit[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = predict_pc_out[1];
            bp_pc_out[0] =  predict_pc_out[1];
            bp_pc_out[1] =  predict_pc_out[1]+4;
        end
        else if (cond_branch[1] &&
            predict_taken[1] && hit[1]) begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = predict_pc_out[1];
            bp_pc_out[0] =  predict_pc_out[1];
            bp_pc_out[1] =  predict_pc_out[1]+4;
        end
        else begin
            bp_npc_out[0] = if_pc_in[0] + 4;
            bp_npc_out[1] = if_pc_in[1] + 4;
            bp_pc_out[0] =  if_pc_in[0] + 8;
            bp_pc_out[1] =  if_pc_in[1] + 8;
        end
    end

    genvar i;
    generate 
    for (i=0;i<`SCALAR;i++) begin
        pre_decode pre_decode_0(
        .inst(inst[i]),
        // output
        .valid(valid[i]),
        .cond_branch(cond_branch[i]), 
        .uncond_branch(uncond_branch[i]),
        .jump(jump[i]),    // JAL is jump insn 
        .link(link[i])     // JALR is link insn
        );
    end
    endgenerate

    BHT bht_0(
        .clock(clock), 
        .reset(reset), 
        // .squash_en(squash_en),
        .wr_en({ex_bp_packet_in[1].con_br_en,ex_bp_packet_in[0].con_br_en}),    // 1 if insn is cond_branch
        .ex_pc_in({ex_bp_packet_in[1].PC, ex_bp_packet_in[0].PC}),  // pc from ex stage 
        .take_branch({ex_bp_packet_in[1].con_br_taken,ex_bp_packet_in[0].con_br_taken}),    // 1 if con_branch taken 
        .if_pc_in(if_pc_in),    // pc from if stage 
        //output    
        .bht_if_out(bht_if_out),    // output the value stored in BHT to PHT
        .bht_ex_out(bht_ex_out)
    );

    PHT pht_0 (
        .clock(clock), 
        .reset(reset),
        .wr_en({ex_bp_packet_in[1].con_br_en,ex_bp_packet_in[0].con_br_en}),    // 1 if insn is cond_branch
        .ex_pc_in({ex_bp_packet_in[1].PC,ex_bp_packet_in[0].PC}),  // pc from ex stage 
        .take_branch({ex_bp_packet_in[1].con_br_taken,ex_bp_packet_in[0].con_br_taken}),    // 1 if con_branch taken 
        .if_pc_in(if_pc_in),    // pc from if stage 
        .bht_if_in(bht_if_out),   
        .bht_ex_in(bht_ex_out),
        //output
        .predict_taken(predict_taken)    // predict pc taken or no taken
    );

    BTB btb_0 (
        .clock(clock), 
        .reset(reset),
        .wr_en({ex_bp_packet_in[1].br_en,ex_bp_packet_in[0].br_en}),    // 1 if insn is branch (con/uncon)
        .ex_pc_in({ex_bp_packet_in[1].PC,ex_bp_packet_in[0].PC}),  // pc from ex stage 
        .ex_tg_pc_in({ex_bp_packet_in[1].tg_pc, ex_bp_packet_in[0].tg_pc}),    // target pc from ex stage in 
        .if_pc_in(if_pc_in),    // pc from if stage 
        //output   
        .hit(hit),    // 1 if pc hit buffer 
        .predict_pc_out(predict_pc_out)
    );

    RAS ras_0(
        .clock(clock),
        .reset(reset),
        .push(push),
        .pop(pop),
        .pc(link_pc),
        .return_addr(return_addr)
    );

    
endmodule
