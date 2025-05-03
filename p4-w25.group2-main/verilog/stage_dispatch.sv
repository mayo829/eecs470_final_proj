`include "sys_defs.svh"
`include "ISA.svh"

//THIS IS PERFECT, NEEDS TO BE CHECKED AND MODIFIED IF NEEDED


/**
 * decoder
 *
 * Decodes the incoming RISC‑V instruction into:
 *   - source architectural registers (reg1, reg2)
 *   - destination architectural register (dest_reg)
 *   - ALU0 and multi-cycle function unit controls (alu_func, mult_func, etc.)
 *   - halts or special cases
 *
 * Uses REG_IDX (typedef logic [4:0]) for architectural registers.
 */
module decoder(
    input  FETCH_DISPATCH_PACKET fetched,

    // Use REG_IDX instead of logic [4:0] for architectural registers
    output REG_IDX               reg1,
    output REG_IDX               reg2,
    output REG_IDX               dest_reg,

    output ALU_OPA_SELECT        opa_select,
    output ALU_OPB_SELECT        opb_select,
    output FUNC_UNIT             FuncUnitType,
    output ALU_FUNC              alu_func,
    output MULT_FUNC             mult_func,
    output MEM_SIZE              mem_size,
    output logic                 halt,
    output logic                 valid
);

    // Extract the instruction and its 'valid' bit
    INST  inst;
    logic inst_valid;
    assign inst       = fetched.inst;
    assign inst_valid = fetched.valid;
    assign valid      = inst_valid;

    always_comb begin
        // Default control values:
        // - These are effectively "no-op" unless overridden by a recognized instruction
        reg1         = `ZERO_REG;
        reg2         = `ZERO_REG;
        dest_reg     = `ZERO_REG;
        opa_select   = OPA_IS_RS1;
        opb_select   = OPB_IS_RS2;
        FuncUnitType = ALU0;
        alu_func     = ALU_ADD;
        mult_func    = M_MUL;
        mem_size     = BYTE;
        halt         = `FALSE;

        if (inst_valid) begin
            casez (inst)
                // ---- Immediate instructions ----
                `RV32_ADDI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_ADD;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_SLLI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLL;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select 	 = OPB_IS_I_IMM;
                end

                `RV32_SRLI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SRL;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_SLTI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLT;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end
                
                `RV32_SLTIU: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLTU;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_ANDI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_AND;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_ORI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_OR;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_XORI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_XOR;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                `RV32_SRAI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SRA;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end        
                                
                // ---- Upper Immediate Instructions ----
                `RV32_LUI: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_ADD;
                    dest_reg     = inst.u.rd;
                    reg1         = `ZERO_REG;
                    opa_select   = OPA_IS_ZERO;
                    opb_select   = OPB_IS_U_IMM;
                end

                `RV32_AUIPC: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_ADD;
                    dest_reg     = inst.u.rd;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_U_IMM;
                end

                // ---- Register-Register instructions ----
                `RV32_OR: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_OR;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_ADD: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_ADD;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_MUL: begin
                    FuncUnitType = MULT;
                    mult_func    = M_MUL;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SUB: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SUB;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SLT: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLT;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SLTU: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLTU;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_AND: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_AND;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_XOR: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_XOR;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SLL: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SLL;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SRL: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SRL;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_SRA: begin
                    FuncUnitType = ALU0;
                    alu_func     = ALU_SRA;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_MULH: begin
                    FuncUnitType = MULT;
                    mult_func    = M_MULH;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_MULHSU: begin
                    FuncUnitType = MULT;
                    mult_func    = M_MULHSU;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                `RV32_MULHU: begin
                    FuncUnitType = MULT;
                    mult_func    = M_MULHU;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_RS2;
                end

                // ---- Branch instructions ----
                `RV32_BNE: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                `RV32_BEQ: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                `RV32_BLT: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                `RV32_BGE: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                `RV32_BLTU: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                `RV32_BGEU: begin
                    FuncUnitType = BRANCH;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_B_IMM;
                end

                // ==== Jump  ====
                `RV32_JAL: begin
                    FuncUnitType = BRANCH;
                    dest_reg     = inst.r.rd;
                    opa_select   = OPA_IS_PC;
                    opb_select   = OPB_IS_J_IMM;
                end

                `RV32_JALR: begin
                    FuncUnitType = BRANCH;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

                // ==== Load instructions ====
                `RV32_LB, `RV32_LH, `RV32_LW, `RV32_LBU, `RV32_LHU: begin
                    FuncUnitType = LS;
                    dest_reg     = inst.r.rd;
                    reg1         = inst.r.rs1;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_I_IMM;
                end

        
                // ==== Store instructions ====
                `RV32_SB: begin
                    FuncUnitType = ST;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_S_IMM;
                    mem_size     = BYTE;
                end

                `RV32_SH: begin
                    FuncUnitType = ST;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_S_IMM;
                    mem_size     = HALF;
                end

                `RV32_SW: begin
                    FuncUnitType = ST;
                    reg1         = inst.r.rs1;
                    reg2         = inst.r.rs2;
                    opa_select   = OPA_IS_RS1;
                    opb_select   = OPB_IS_S_IMM;
                    mem_size     = WORD;
                end

                // ---- Halt (WFI) ----
                `WFI: begin
                    halt = `TRUE;
                end

                // ---- Default / unhandled case ----
                default: begin
                    // do nothing
                end
            endcase
        end
    end

endmodule // decoder


/**
 * dispatch_stage
 *
 * Takes up to 2 fetched instructions, decodes them, and allocates
 * resources: a new physical register from the free list, a ROB entry,
 * etc. Passes information on to the Reservation Station (RS) and the ROB.
 */
`include "sys_defs.svh"
`include "ISA.svh"

module stage_dispatch (
    input  logic clock,
    input  logic reset,

    input  FETCH_DISPATCH_PACKET [1:0] fetched_in,

    input  logic [$clog2(`RS_SZ):0] NumFreeEntriesAfterIssue,
    input  logic [`ROB_PTR_WIDTH:0] NumROBFreeEntriesAfterRetire,

    input  logic [1:0] dispatch_stall_i,
    input  logic [1:0] free_valid_i,

    output DISPATCH_ROB_PACKET  [1:0] rob_out,

    input  logic [1:0][`PR_WIDTH-1:0] maptable_old_pr_i,
    input  logic [1:0][`PR_WIDTH-1:0] maptable_new_pr_i,
    output logic [1:0][`PR_WIDTH-1:0] maptable_new_pr_o,
    output REG_IDX [1:0] maptable_arch_o,

    output REG_IDX [1:0] reg1_ar_o,
    output REG_IDX [1:0] reg2_ar_o,

    input  logic [1:0][`PR_WIDTH-1:0] reg1_pr_i,
    input  logic [1:0][`PR_WIDTH-1:0] reg2_pr_i,
    input  logic [1:0] reg1_ready_i,
    input  logic [1:0] reg2_ready_i,

    output DISPATCH_RS_PACKET [1:0] rs_in,

    input  logic [`N-1:0][$clog2(`ROB_SZ)-1:0] sq_pos,
    input  logic [`N-1:0]                      sq_pos_valid, 
    input  logic [$clog2(`ROB_SZ)-1:0]         tail_comb,
    input  logic [$clog2(`ROB_SZ)-1:0]         tail_seq,

    output logic [1:0]                         sq_req,
    input  logic [`ROB_PTR_WIDTH-1:0]          rob_tail,

    output logic [1:0]                         kys
    
);

  logic [1:0] dec_valid;
  REG_IDX dec_reg1 [1:0], dec_reg2 [1:0], dec_dest [1:0];
  ALU_OPA_SELECT dec_opa_select [1:0];
  ALU_OPB_SELECT dec_opb_select [1:0];
  FUNC_UNIT dec_func_unit [1:0];
  ALU_FUNC dec_alu_func [1:0];
  MULT_FUNC dec_mult_func [1:0];
  logic [1:0] dec_halt;
  MEM_SIZE [1:0] dec_mem_size;

  generate
    for (genvar i = 0; i < 2; i++) begin : GEN_DECODER
      decoder dec_u (
        .fetched      (fetched_in[i]),
        .reg1         (dec_reg1[i]),
        .reg2         (dec_reg2[i]),
        .dest_reg     (dec_dest[i]),
        .opa_select   (dec_opa_select[i]),
        .opb_select   (dec_opb_select[i]),
        .FuncUnitType (dec_func_unit[i]),
        .alu_func     (dec_alu_func[i]),
        .mult_func    (dec_mult_func[i]),
        .mem_size     (dec_mem_size[i]),
        .halt         (dec_halt[i]),
        .valid        (dec_valid[i])
      );
    end
  endgenerate

  always_comb begin
    sq_req = '0;
    for (int i = 0; i < 2; i++) begin
      // Default zero to avoid latch
      maptable_arch_o[i]   = '0;
      maptable_new_pr_o[i] = '0;
      reg1_ar_o[i]         = '0;
      reg2_ar_o[i]         = '0;
      kys[i]               = '0;

      rob_out[i] = '{default: '0};
      rs_in[i]   = '{default: '0};

      kys[i] = ((dec_func_unit[i] == BRANCH && fetched_in[i].inst[6:0] != `RV32_JALR_OP && fetched_in[i].inst[6:0] != `RV32_JAL_OP) 
      || dec_func_unit[i] == ST || dec_halt[i] || dec_dest[i] == '0)? 1'b0 : 1'b1;

      if (dispatch_stall_i[i]) begin
        // RAT -> mapping outputs
        maptable_arch_o[i]   = dec_dest[i];
        maptable_new_pr_o[i] = maptable_new_pr_i[i];
        reg1_ar_o[i]         = dec_reg1[i];
        reg2_ar_o[i]         = dec_reg2[i];

        // ROB entry
        rob_out[i].valid       = dec_valid[i];
        rob_out[i].complete    = 1'b0;
        rob_out[i].dest_reg    = dec_dest[i];
        rob_out[i].inst        = fetched_in[i].inst;
        rob_out[i].TD          = maptable_new_pr_i[i];
        rob_out[i].Told        = maptable_old_pr_i[i];
        rob_out[i].PC          = fetched_in[i].PC;
        rob_out[i].SPEC_PC     = fetched_in[i].SPEC_PC; // spec_pc for commit
        rob_out[i].NPC         = fetched_in[i].NPC;
        rob_out[i].instruction = fetched_in[i].inst;
        rob_out[i].halt        = dec_halt[i];
        rob_out[i].is_branch   = (dec_func_unit[i] == BRANCH && fetched_in[i].inst[6:0] != `RV32_JAL_OP && fetched_in[i].inst[6:0] != `RV32_JALR_OP)? 1'b1 : 1'b0;
        rob_out[i].is_store    = (dec_func_unit[i] == ST)? 1'b1 : 1'b0;

        // RS entry (if not halt)
        if (!dec_halt[i]) begin
            sq_req[i]             = (dec_valid[i] && (dec_func_unit[i] == ST))? 1'b1 : 1'b0;
            rs_in[i].valid        = dec_valid[i];
            rs_in[i].FuncUnitType = dec_func_unit[i];
            rs_in[i].alu_func     = dec_alu_func[i];
            rs_in[i].mult_func    = dec_mult_func[i];
            rs_in[i].opa_select   = dec_opa_select[i];
            rs_in[i].opb_select   = dec_opb_select[i];
            rs_in[i].PC           = fetched_in[i].PC;
            rs_in[i].NPC          = fetched_in[i].NPC;
            rs_in[i].inst         = fetched_in[i].inst;
            rs_in[i].TD           = maptable_new_pr_i[i];
            rs_in[i].T1           = reg1_pr_i[i];
            rs_in[i].T1p          = reg1_ready_i[i];
            rs_in[i].T2           = reg2_pr_i[i];
            rs_in[i].T2p          = reg2_ready_i[i];
            rs_in[i].mem_size     = dec_mem_size[i];
            rs_in[i].rob_ptr      = ((rob_tail + i) % `ROB_SZ);
            if (dec_func_unit[i] == ST && sq_pos_valid[i]) begin
                rs_in[i].sq_pos = sq_pos[i];
            end else if (dec_func_unit[i] == LS) begin
                // Conflict case handled for i == 0
                if (i == 0 && dec_func_unit[1] == ST) begin
                    rs_in[i].sq_pos = tail_seq; // ← only override in conflict scenario
                end else begin
                    rs_in[i].sq_pos = tail_comb;
                end
            end
        end
      end
    end
  end


endmodule
