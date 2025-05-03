/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file defines macros and data structures used   //
//                 throughout the processor.                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define N 2
`define CDB_SZ `N // This MUST match your superscalar width

// sizes
`define ROB_SZ 16
`define RS_SZ 8
`define PHYS_REG_SZ_P6 32
`define PHYS_REG_SZ_R10K (32 + `ROB_SZ)
`define SQ_SZ `ROB_SZ // store queue size
`define LQ_SZ 16 // load queue size

// worry about these later
`define BRANCH_PRED_SZ xx
`define LSQ_SZ 4

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU 2
`define NUM_FU_MULT 1
`define NUM_FU_LOAD xx
`define NUM_FU_STORE xx

// number of mult stages (2, 4) (you likely don't need 8)
`define MULT_STAGES 4

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// word and register sizes
typedef logic [31:0] ADDR;
typedef logic [31:0] DATA;
typedef logic [4:0] REG_IDX;

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
// TODO: uncomment this line once you've implemented your cache
`define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
//`define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// memory tags represent a unique id for outstanding mem transactions
// 0 is a sentinel value and is not a valid tag
`define NUM_MEM_TAGS 15
typedef logic [3:0] MEM_TAG;

// icache definitions
`define ICACHE_LINES 32
`define ICACHE_LINE_BITS $clog2(`ICACHE_LINES)

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)

// A memory or cache block
typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
    logic      [63:0] dbbl_level;
} MEM_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    MEM_NONE   = 2'h0,
    MEM_LOAD   = 2'h1,
    MEM_STORE  = 2'h2
} MEM_COMMAND;

// icache tag struct
typedef struct packed {
    logic [12-`ICACHE_LINE_BITS:0] tags;
    logic                          valid;
} ICACHE_TAG;

// dcache tag struct
typedef struct packed {
    logic [12-`ICACHE_LINE_BITS:0] tags;
    logic                          valid;
    logic                          dirty;
} DCACHE_TAG;

///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code
typedef enum logic [3:0] {
    ALU_ADD     = 4'h0,
    ALU_SUB     = 4'h1,
    ALU_SLT     = 4'h2,
    ALU_SLTU    = 4'h3,
    ALU_AND     = 4'h4,
    ALU_OR      = 4'h5,
    ALU_XOR     = 4'h6,
    ALU_SLL     = 4'h7,
    ALU_SRL     = 4'h8,
    ALU_SRA     = 4'h9
} ALU_FUNC;

// MULT funct3 code
// we don't include division or rem options
typedef enum logic [2:0] {
    M_MUL,
    M_MULH,
    M_MULHSU,
    M_MULHU
} MULT_FUNC;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST  inst;
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST inst;
    ADDR PC;
    ADDR NPC; // PC + 4

    DATA rs1_value; // reg A value
    DATA rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    REG_IDX  dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC alu_func;      // ALU function select (ALU_xxx *)
    logic    mult;          // Is inst a multiply instruction?
    logic    rd_mem;        // Does inst read memory?
    logic    wr_mem;        // Does inst write memory?
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
    logic    halt;          // Is this a halt?
    logic    illegal;       // Is this instruction illegal?
    logic    csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic    valid;
} ID_EX_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    DATA alu_result;
    ADDR NPC;

    logic    take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    DATA     rs2_value;
    logic    rd_mem;
    logic    wr_mem;
    REG_IDX  dest_reg_idx;
    logic    halt;
    logic    illegal;
    logic    csr_op;
    logic    rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE mem_size;
    logic    valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    DATA    result;
    ADDR    NPC;
    REG_IDX dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic   take_branch;
    logic   halt;    // not used by wb stage
    logic   illegal; // not used by wb stage
    logic   valid;
} MEM_WB_PACKET;

/**
 * Commit Packet:
 * This is an output of the processor and used in the testbench for counting
 * committed instructions
 *
 * It also acts as a "WB_PACKET", and can be reused in the final project with
 * some slight changes
 */
typedef struct packed {
    ADDR    PC;
    ADDR    NPC;
    DATA    data;
    REG_IDX reg_idx;
    logic   halt;
    logic   illegal;
    logic   valid;
    logic   is_branch;
    logic   if_take_branch;
    ADDR    target_pc;
    ADDR    SPEC_PC;
    INST    inst;
} COMMIT_PACKET;


//POTENTIALLY NEW PACKETS, EVERYTHING ABOVE IS THE ORIGINAL AND UNCHANGED
//ONLY COMMENT OUT A PACKET ABOVE AND PLACE THE MODIFICATION BELOW IN CASE WE NEED TO ROLL BACK.
//AND SO WE HAVE SOMETHING TO COMPARE TO

//SO FAR WE ARE USING THIS - BUREIR 

`define PR_WIDTH        $clog2(`PHYS_REG_SZ_R10K)
`define ROB_PTR_WIDTH   $clog2(`ROB_SZ)
`define RAT_SZ          32
`define NUM_FU          5
`define FIFO_SZ_IB         16
`define FIFO_SZ            4


// typedef enum logic [1:0] {
// 	ALU         = 2'h0,
// 	MULT        = 2'h1,
// 	LOAD        = 2'h2,
//  BRANCH      = 2'h3
// // may need more
// } FUNC_UNIT;

// typedef enum logic [3:0] {
//     ALU0         = 3'h0,
//     ALU1         = 3'h1,
//     MULT0        = 3'h2,
//     MULT1        = 3'h3,
//     LOAD0        = 3'h4,
//     LOAD1        = 3'h5,
//     BRANCH       = 3'h6
// } FUNC_UNIT;

typedef enum logic [2:0] {
    ALU0         = 3'h0,
    ALU1         = 3'h1,
    MULT         = 3'h2,
    BRANCH       = 3'h3,
    LS           = 3'h4,
    ST           = 3'h5
// may need more
} FUNC_UNIT;

typedef enum logic [1:0] {
	OFF         = 2'h0
// NEEDS MODIFICATION
} FU_STATE;

typedef struct packed{
	logic alu;
	logic ls;
	logic mult;
	logic branch;
} FIFO_STALL_PACKET;


// INTERNAL ENTRIES - BEGIN




//RAT entry
// Each AR entry: { pr_tag, ready }
// We’ll do an array of structures or parallel arrays.
typedef struct packed {
    logic [`PR_WIDTH-1:0] tag;
    logic                ready;
} RAT_ENTRY_PACKET;

typedef struct packed {
    logic [`PR_WIDTH-1:0] tag;
    // logic                ready;
} ARCHMAP_ENTRY_PACKET;

// INTERNAL ENTRIES - END


// THESE PACKETS GO INTO DISPATCH - BEGIN

typedef struct packed {

    INST  inst;

    ADDR  PC;

    ADDR  NPC; // PC + 4

    logic valid;

    ADDR SPEC_PC;

} FETCH_DISPATCH_PACKET;


// THESE PACKETS GO INTO DISPATCH - END

// THESE PACKETS COME OUT OF DISPATCH - BEGIN

typedef struct packed {
        logic valid;
        logic busy;
        logic T1p;
        logic T2p;
        logic [`PR_WIDTH-1:0] T1;
        logic [`PR_WIDTH-1:0] T2;
        logic [`PR_WIDTH-1:0] TD;
        FUNC_UNIT           FuncUnitType;
        ALU_FUNC            alu_func;
        MULT_FUNC           mult_func;
        ALU_OPA_SELECT      opa_select; // ALU opa mux select (ALU_OPA_xxx *)
        ALU_OPB_SELECT      opb_select; // ALU opb mux select (ALU_OPB_xxx *)
        ADDR  PC;
        ADDR  NPC;
        DATA  inst;
        REG_IDX arch_dest;
        logic               dispatched;
        logic [$clog2(`SQ_SZ)-1:0] sq_pos; // store queue position
        //logic [$clog2(`LQ_SZ)-1:0] lq_pos; // load queue position
        MEM_SIZE mem_size;
        logic UncStatus; // is he an unc?
        logic [`ROB_PTR_WIDTH-1:0] rob_ptr;
} DISPATCH_RS_PACKET;

//WORK ON THIS FOR ROB
//SO FAR WE ARE USING THIS - BUREIR 
//ALSO GOING TO HAVE TO *SLIGHTLY* MODIFY ROB
typedef struct packed {
        logic                           valid; 
        logic                           complete;
        REG_IDX                         dest_reg;
        logic       [`PR_WIDTH-1:0]     TD;
        logic       [`PR_WIDTH-1:0]     Told;
        ADDR                            PC;
        ADDR                            NPC;
        INST                            instruction;
        logic                           halt;
        logic                           is_branch;
        logic                           is_store;
        ADDR                            SPEC_PC;  
        INST                            inst;     
} DISPATCH_ROB_PACKET;

// THESE PACKETS COME OUT OF DISPATCH - END


// ROB PACKETS [BEGIN]

typedef struct packed {
    logic                           valid; 
    logic                           complete;
    REG_IDX                         dest_reg;
    INST                            inst;
    logic       [`PR_WIDTH-1:0]     T;
    logic       [`PR_WIDTH-1:0]     Told;
    ADDR                            PC;
    ADDR                            NPC;
    logic                           halt;

    logic                           is_store;
    logic                           is_branch;
    logic                           if_take_branch;
    ADDR                            target_pc;
    ADDR                            SPEC_PC;
} ROB_RETIRE_PACKET;


// ROB PACKETS [END]


// THESE PACKETS GO INTO RS - BEGIN

//IGNORE THIS FOR NOW
// typedef struct packed {
//     logic                   valid;
//     logic                   busy;
//     FUNC_UNIT               FuncUnitType;
//     ALU_FUNC                alu_func;
//     MULT_FUNC               mult_func;
//     ALU_OPA_SELECT          opa_select;
//     ALU_OPB_SELECT          opb_select;
//     ADDR                    PC;
//     ADDR                    NPC;
//     INST                    inst;
//     logic [`PR_WIDTH-1:0]   TD;   // TD
//     logic [`PR_WIDTH-1:0]   T1;
//     logic                   T1p;
//     logic [`PR_WIDTH-1:0]   T2;
//     logic                   T2p;
//     REG_IDX                 arch_dest;
// } DISPATCH_RS_PACKET;



typedef struct packed {
    logic                          valid; // if low, the data in this struct is garbage
    ALU_FUNC                       alu_func;
    MULT_FUNC                      mult_func;
    FUNC_UNIT                      FuncUnitType;
    MEM_SIZE                       mem_size;
    ADDR                           NPC;   // PC + 4
    ADDR                           PC;    // PC
    ALU_OPA_SELECT                 opa_select; // ALU opa mux select (ALU_OPA_xxx )
    ALU_OPB_SELECT                 opb_select; // ALU opb mux select (ALU_OPB_xxx)
    INST                           inst;
    logic [`PR_WIDTH-1:0]          dest_reg_idx;
    logic [`PR_WIDTH-1:0]          T1;
    logic [`PR_WIDTH-1:0]          T2;
    logic                          T1_ready;
    logic                          T2_ready;
    logic                          busy;
    logic [$clog2(`SQ_SZ)-1:0]     sq_pos;
    logic [`ROB_PTR_WIDTH-1:0]     rob_ptr;
} RS_ISSUE_PACKET;

typedef struct packed{
    logic 				            valid;
    ALU_FUNC                        alu_func;
    MULT_FUNC                       mult_func; // Is inst a multiply instruction?
    FUNC_UNIT			            FuncUnitType;
    ADDR                            NPC;        // PC + 4
    ADDR                            PC;         // PC
    ALU_OPA_SELECT                  opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT                  opb_select; // ALU opb mux select (ALU_OPB_xxx *)
    INST          		            inst;
    logic [`PR_WIDTH-1:0] 	        dest_reg_idx;
    DATA	                        r1_value;
    DATA 	                        r2_value;
    MEM_SIZE                        mem_size;
    logic [$clog2(`SQ_SZ)-1:0]      sq_pos;
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
} ISSUE_PACKET;



// THESE PACKETS GO INTO A FUNCTIONAL UNIT - END


typedef struct packed {
    logic                           if_take_branch;
    logic                           is_branch;
    logic                           valid;
    ADDR                            NPC;   // PC + 4
    ADDR                            PC;    // PC
    ADDR                            target_pc;
    logic [`PR_WIDTH-1:0]           dest_reg_idx; // T to broadcast back
    DATA                            result; // Data value
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
} COMPLETE_PACKET;

//CDB entry
typedef struct packed {
    logic                           valid;
    logic [`PR_WIDTH-1:0]           tag;
    DATA                            data;
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
    logic                           if_take_branch;
    ADDR                            target_pc;
} CDB_ENTRY_PACKET;

// LSQ packets
typedef struct packed {
    logic                           valid;
    ADDR                            address; // address storing to
    DATA                            value;
    MEM_SIZE                        mem_size;
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
} SQ_PACKET; 

// freeList packets
typedef struct packed {
    logic [1:0]                retired_req;      // one-hot retired instruction lines
    logic [1:0][`PR_WIDTH-1:0] retired_tags;     // retired instruction tags
} RETIRE_TO_FREELIST_PACKET;

typedef struct packed {
    logic [1:0][`PR_WIDTH-1:0] free_tags;        // tags of free PRs
    logic [1:0]                valid;            // one-hot valid granted lines of free_tags
} FREELIST_PACKET_OUT;

//retire packets

typedef struct packed {
    logic                               commit_valid;
    REG_IDX                             commit_arch_reg;
    logic       [`PR_WIDTH-1:0]           commit_phys_reg;
} RETIRE_ARCHMAP_PACKET;






// === Debug Packets ===

typedef struct packed {
  logic        valid;
  ADDR         PC;
  ADDR         NPC;
  DATA         inst;
} FETCH_DBG_PACKET;

typedef struct packed {
  logic        valid;
  ADDR         PC;
  DATA         inst;
  REG_IDX      arch_dest;
  logic [`PR_WIDTH-1:0] T;
  logic [`PR_WIDTH-1:0] Told;
  logic        halt;
} DISPATCH_DBG_PACKET;

typedef struct packed {
  logic        valid;
  ADDR         PC;
  ADDR         NPC;
  DATA         inst;
  logic [`PR_WIDTH-1:0] T1;
  logic [`PR_WIDTH-1:0] T2;
  DATA         val1;
  DATA         val2;
  logic        T1_ready;
  logic        T2_ready;
  logic [`PR_WIDTH-1:0] dest_reg_idx;
  FUNC_UNIT    FuncUnitType;
} ISSUE_DBG_PACKET;

typedef struct packed {
  logic        valid;
  ADDR         PC;
  ADDR         NPC;
  DATA         inst;
  DATA         result;
  logic [`PR_WIDTH-1:0] dest_reg_idx;
  FUNC_UNIT    FuncUnitType;
} EXECUTE_DBG_PACKET;

typedef struct packed {
  logic        valid;
  logic [`PR_WIDTH-1:0] tag;
  DATA         data;
  logic        if_take_branch;
  ADDR         target_pc;
} COMPLETE_DBG_PACKET;

typedef struct packed {
  logic        valid;
  ADDR         NPC;
  DATA         data;
  REG_IDX      reg_idx;
  logic        halt;
  logic        illegal;
  logic        is_branch;
  logic        if_take_branch;
  ADDR         target_pc;
} RETIRE_DBG_PACKET;

typedef enum logic [1:0] {
    INPUT = 2'h0,
    SQ    = 2'h1,
    CACHE = 2'h2,
    OUTPUT = 2'h3
} LOAD_STATUS; // Load stage status

// LSQ packets
typedef struct packed {
    logic       valid;     // valid high when values ready from ex stage (complete packet)
    logic       retired;   // store is requested for retirement
    logic       allocated; // allocated high on dispatch
    ADDR        address;   // address storing to
    DATA        value;
    MEM_SIZE    mem_size;
    logic       pending_retirement;
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
} SQ_ENTRY;

typedef struct packed {
    logic                           valid;
    logic [`ROB_PTR_WIDTH-1:0]      sq_pos;
    ADDR                            address;
    DATA                            value;
    MEM_SIZE                        mem_size;
    logic [$clog2(`ROB_SZ)-1:0]     rob_ptr;
} COMPLETE_SQ_PACKET;

// typedef struct packed {
//     logic                   valid;
//     logic [3:0]             mem_align;
//     ADDR                    addr; // must be aligned with words
//     DATA                    data;
// } SQ_PACKET_ENTRY;

typedef struct packed {
	logic					valid;
	logic [3:0]				mem_align;
	DATA		            data;
} SQ2LOAD_PACKET;

typedef struct packed {
	logic [`LSQ_SZ-1:0]		tail_pos; // the tail position when load is dispatched
	ADDR		            addr; // must align with word! 
} LOAD2SQ_PACKET;


typedef enum logic [2:0] {
    RESTARTED     = 3'h0,
    ITYPE         = 3'h1,
    DTYPE         = 3'h2
} CACHE_TYPE;

typedef struct packed {
    CACHE_TYPE cache_type;
    logic      valid;
} CACHE_BUFFER_PACKET;

typedef enum logic [2:0] {
    IDLE_CACHE   = 3'h0,
    MEM_STAGE    = 3'h1,
    WRITEBACK    = 3'h2,
    DONE       = 3'h3
} CACHE_STATUS;
`endif // __SYS_DEFS_SVH__
