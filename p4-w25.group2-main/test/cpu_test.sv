
/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cpu_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the VeriSimpleV processor.     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

// P4 TODO: Add your own debugging framework. Basic printing of data structures
//          is an absolute necessity for the project. You can use C functions 
//          like in test/pipeline_print.c or just do everything in verilog.
//          Be careful about running out of space on CAEN printing lots of state
//          for longer programs (alexnet, outer_product, etc.)

// These link to the pipeline_print.c file in this directory, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
import "DPI-C" function string decode_inst(int inst);
import "DPI-C" function void open_pipeline_output_file(string file_name);
import "DPI-C" function void print_header();
// import "DPI-C" function void print_cycles(int clock_count);
import "DPI-C" function void print_stage(int inst, int npc, int valid_inst);
import "DPI-C" function void print_reg(int wb_data, int wb_idx, int wb_en);
// import "DPI-C" function void print_membus(int proc2mem_command, int proc2mem_addr,
//                                          int proc2mem_data_hi, int proc2mem_data_lo);
import "DPI-C" function void close_pipeline_output_file();


`define TB_MAX_CYCLES 50000000


module testbench;
    // string inputs for loading memory and output files
    // run like: cd build && ./simv +MEMORY=../programs/mem/<my_program>.mem +OUTPUT=../output/<my_program>
    // this testbench will generate 4 output files based on the output
    // named OUTPUT.{out cpi, wb, ppln} for the memory, cpi, writeback, and pipeline outputs.
    string program_memory_file, output_name;
    string out_outfile, cpi_outfile, writeback_outfile, pipeline_outfile;
    int out_fileno, cpi_fileno, wb_fileno; // verilog uses integer file handles with $fopen and $fclose

    // variables used in the testbench
    logic        clock;
    logic        reset;
    logic [31:0] clock_count; // also used for terminating infinite loops
    logic [31:0] instr_count;

    MEM_COMMAND proc2mem_command;
    ADDR        proc2mem_addr;
    MEM_BLOCK   proc2mem_data;
    MEM_TAG     mem2proc_transaction_tag;
    MEM_BLOCK   mem2proc_data;
    MEM_TAG     mem2proc_data_tag;
    MEM_SIZE    proc2mem_size;

    COMMIT_PACKET [`N-1:0] committed_insts;
    EXCEPTION_CODE error_status = NO_ERROR;

    ADDR  if_id_NPC_dbg;    
    DATA  if_id_inst_dbg;   
    logic if_id_valid_dbg;  
    ADDR  id_ROB_NPC_dbg;   
    DATA  id_ROB_inst_dbg;  
    logic id_ROB_valid_dbg; 
    ADDR  id_RS_NPC_dbg;   
    DATA  id_RS_inst_dbg;   
    logic id_RS_valid_dbg;  
    ADDR  RS_IS_NPC_dbg;    
    DATA  RS_IS_inst_dbg;   
    logic RS_IS_valid_dbg;  
    ADDR  Ex_C_NPC_dbg;     
    DATA  Ex_C_inst_dbg;    
    logic Ex_C_valid_dbg;   
    ADDR  ROB_RE_NPC_dbg;   
    DATA  ROB_RE_inst_dbg;  
    logic ROB_RE_valid_dbg; 

FETCH_DBG_PACKET     fetch_dbg;
DISPATCH_DBG_PACKET  dispatch_dbg;
ISSUE_DBG_PACKET     issue_dbg;
EXECUTE_DBG_PACKET   execute_dbg;
COMPLETE_DBG_PACKET  complete_dbg;
RETIRE_DBG_PACKET    retire_dbg;


RAT_ENTRY_PACKET [0:31] RAT_dbg;
DISPATCH_RS_PACKET [`RS_SZ-1:0] rs_dbg;
logic [31:0][`PR_WIDTH-1:0] arch_map_dbg;
CDB_ENTRY_PACKET [1:0] cdb_dbg;
DATA [`PHYS_REG_SZ_R10K-1:0] prf_dbg;
ROB_RETIRE_PACKET [`ROB_SZ-1:0] rob_dbg;
logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg;
logic [`ROB_PTR_WIDTH-1:0] freeList_head_dbg;
logic [`ROB_PTR_WIDTH-1:0] freeList_tail_dbg;

logic [`ICACHE_LINES-1:0][$bits(MEM_BLOCK)-1:0]  memDataDebug;
DCACHE_TAG [`ICACHE_LINES-1:0] dcache_tags_debug;

logic [4:0] caster;

    // Instantiate the Pipeline
    cpu verisimpleV (
        // Inputs
        .clock (clock),
        .reset (reset),
        .mem2proc_transaction_tag (mem2proc_transaction_tag),
        .mem2proc_data            (mem2proc_data),
        .mem2proc_data_tag        (mem2proc_data_tag),

        // Outputs
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif
        .committed_insts  (committed_insts),
        .fetch_dbg(fetch_dbg),
        .dispatch_dbg(dispatch_dbg),
        .issue_dbg(issue_dbg),
        .execute_dbg(execute_dbg),
        .complete_dbg(complete_dbg),
        .retire_dbg(retire_dbg),
        
        .RAT_dbg(RAT_dbg),
        .rs_dbg(rs_dbg),
        .arch_map_dbg(arch_map_dbg),
        .cdb_dbg(cdb_dbg),
        .prf_dbg(prf_dbg),
        .rob_dbg(rob_dbg),
        .freeList_dbg(freeList_dbg),
        .freeList_head_dbg(freeList_head_dbg),
        .freeList_tail_dbg(freeList_tail_dbg),

        .memDataDebug(memDataDebug),
        .dcache_tags_debug(dcache_tags_debug)
//        .ROB_RE_NPC_dbg   (ROB_RE_NPC_dbg),
//        .ROB_RE_inst_dbg  (ROB_RE_inst_dbg),
//        .ROB_RE_valid_dbg (ROB_RE_valid_dbg)
    );


    // Instantiate the Data Memory
    mem memory (
        // Inputs
        .clock            (clock),
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif
        // Outputs
        .mem2proc_transaction_tag (mem2proc_transaction_tag),
        .mem2proc_data            (mem2proc_data),
        .mem2proc_data_tag        (mem2proc_data_tag)
    );


    // Generate System Clock
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    initial begin
        caster = 0;
        $display("\n---- Starting CPU Testbench ----\n");

        //$vcdplusfile("/home/mahdichy/.ssh/eecs470/working_branch/p4-w25.group2/dump/cpu_test.vpd"); 
        
        //$vcdpluson();
        // $dumpfile("/home/balaboud/eecs470/p4-w25.group2/dump/cpu_test.vcd");
        // $dumpvars(0,testbench.verisimpleV);

        // set paramterized strings, see comment at start of module
        if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
            $display("Using memory file  : %s", program_memory_file);
        end else begin
            $display("Did not receive '+MEMORY=' argument. Exiting.\n");
            $finish;
        end
        if ($value$plusargs("OUTPUT=%s", output_name)) begin
            $display("Using output files : %s.{out, cpi, wb, ppln}", output_name);
            out_outfile       = {output_name,".out"}; // this is how you concatenate strings in verilog
            cpi_outfile       = {output_name,".cpi"};
            writeback_outfile = {output_name,".wb"};
            pipeline_outfile  = {output_name,".ppln"};
        end else begin
            $display("\nDid not receive '+OUTPUT=' argument. Exiting.\n");
            $finish;
        end

        clock = 1'b0;
        reset = 1'b0;

        $display("\n  %16t : Asserting Reset", $realtime);
        reset = 1'b1;

        @(posedge clock);
        @(posedge clock);

        $display("  %16t : Loading Unified Memory", $realtime);
        // load the compiled program's hex data into the memory module
        $readmemh(program_memory_file, memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        #1; // This reset is at an odd time to avoid the pos & neg clock edges
        $display("  %16t : Deasserting Reset", $realtime);
        reset = 1'b0;

        wb_fileno = $fopen(writeback_outfile);
        $fdisplay(wb_fileno, "Register writeback output (hexadecimal)");

        // Open pipeline output file AFTER throwing the reset otherwise the reset state is displayed
        open_pipeline_output_file(pipeline_outfile);
        // print_header();

        out_fileno = $fopen(out_outfile);

        $display("  %16t : Running Processor", $realtime);
    end


    always @(negedge clock) begin
        if (reset) begin
            // Count the number of cycles and number of instructions committed
            clock_count = 0;
            instr_count = 0;
        end else begin
            #2; // wait a short time to avoid a clock edge

            clock_count = clock_count + 1;

            if (clock_count % 10000 == 0) begin
                $display("  %16t : %d cycles", $realtime, clock_count);
            end

            // print the pipeline debug outputs via c code to the pipeline output file
            //print_cycles(clock_count - 1);

            print_stage(if_id_inst_dbg,  if_id_NPC_dbg,   {31'b0, if_id_valid_dbg});
            // print_stage(id_ROB_inst_dbg, id_ROB_NPC_dbg,  {31'b0, id_ROB_valid_dbg});
            // print_stage(id_RS_inst_dbg,  id_RS_NPC_dbg,   {31'b0, id_RS_valid_dbg});
            // print_stage(RS_IS_inst_dbg,  RS_IS_NPC_dbg,   {31'b0, RS_IS_valid_dbg});
            // print_stage(Ex_C_inst_dbg,   Ex_C_NPC_dbg,    {31'b0, Ex_C_valid_dbg});
            // print_stage(ROB_RE_inst_dbg, ROB_RE_NPC_dbg,  {31'b0, ROB_RE_valid_dbg});

            print_reg(committed_insts[0].data, {27'b0,committed_insts[0].reg_idx}, {31'b0,committed_insts[0].valid});
            // print_membus({30'b0,proc2mem_command}, proc2mem_addr[31:0],
            //               proc2mem_data[63:32], proc2mem_data[31:0]);

            print_custom_data();

            output_reg_writeback_and_maybe_halt();

            // stop the processor
            if (error_status != NO_ERROR || clock_count > `TB_MAX_CYCLES) begin

                $display("  %16t : Processor Finished", $realtime);

                // close the writeback and pipeline output files
                close_pipeline_output_file();
                $fclose(wb_fileno);

                // display the final memory and status
                show_final_mem_and_status(error_status);
                // output the final CPI
                output_cpi_file();

                $display("\n---- Finished CPU Testbench ----\n");

                #100 $finish;
            end
        end // if(reset)
    end


    // Task to output register writeback data and potentially halt the processor.
    task output_reg_writeback_and_maybe_halt;
        ADDR pc;
        DATA inst;
        MEM_BLOCK block;
        for (int n = 0; n < `N; ++n) begin
            if (committed_insts[n].valid) begin
                // update the count for every committed instruction
                instr_count = instr_count + 1;

                pc = committed_insts[n].PC;
                block = memory.unified_memory[pc[31:3]];
                inst = block.word_level[pc[2]];
                // print the committed instructions to the writeback output file
                if (committed_insts[n].reg_idx == `ZERO_REG) begin
                    $fdisplay(wb_fileno, "PC %4x:%-8s| ---", pc, decode_inst(inst));
                end else begin
                    $fdisplay(wb_fileno, "PC %4x:%-8s| r%02d=%-8x",
                              pc,
                              decode_inst(inst),
                              committed_insts[n].reg_idx,
                              committed_insts[n].data);
                end

                // exit if we have an illegal instruction or a halt
                if (committed_insts[n].illegal) begin
                    error_status = ILLEGAL_INST;
                    break;
                end else if(committed_insts[n].halt) begin
                    error_status = HALTED_ON_WFI;
                    break;
                end
            end
        end
    endtask // task output_reg_writeback_and_maybe_halt


    // Task to output the final CPI and # of elapsed clock edges
    task output_cpi_file;
        real cpi;
        begin
            cpi = $itor(clock_count) / instr_count; // must convert int to real
            cpi_fileno = $fopen(cpi_outfile);
            $fdisplay(cpi_fileno, "@@@  %0d cycles / %0d instrs = %f CPI",
                      clock_count, instr_count, cpi);
            $fdisplay(cpi_fileno, "@@@  %4.2f ns total time to execute",
                      clock_count * `CLOCK_PERIOD);
            $fclose(cpi_fileno);
        end
    endtask // task output_cpi_file


    // Show contents of Unified Memory in both hex and decimal
    // Also output the final processor status
task show_final_mem_and_status;
        input EXCEPTION_CODE final_status;
        int showing_data;
        int printed = 0;
        int lastaddrprinted = 0;
        begin
            $fdisplay(out_fileno, "\nFinal memory state and exit status:\n");
            $fdisplay(out_fileno, "@@@ Unified Memory contents hex on left, decimal on right: ");
            $fdisplay(out_fileno, "@@@");
            //showing_data = 0;
            for (int k = 0; k < `MEM_64BIT_LINES; k = k+1) begin
                printed = 0;
                for (int i = 0; i < `ICACHE_LINES; i++) begin
                    caster = i;
                    if (dcache_tags_debug[i].valid && dcache_tags_debug[i].dirty &&
                        ({dcache_tags_debug[i].tags, caster, 3'b000} == k * 8)) begin
                        if(memDataDebug[i] !== 64'b0) begin
                        $fdisplay(out_fileno, "@@@ mem[%5d] = %016x : %0d", 
                                k * 8, memDataDebug[i], memDataDebug[i]);
                        //showing_data = 1;
                        lastaddrprinted = k * 8;
                        end 
                        printed = 1;
                        break;
                    end
                end
                if (!printed && memory.unified_memory[k] != 0) begin
                    $fdisplay(out_fileno, "@@@ mem[%5d] = %016x : %0d", 
                            k * 8, memory.unified_memory[k], memory.unified_memory[k]);
                    //showing_data = 1;
                    lastaddrprinted = k * 8;
                end
                if (lastaddrprinted == ( k - 1 ) * 8) begin
                    $fdisplay(out_fileno, "@@@");
                    //showing_data = 0;
                end
            end

            $fdisplay(out_fileno, "@@@");

            case (final_status)
                LOAD_ACCESS_FAULT: $fdisplay(out_fileno, "@@@ System halted on memory error");
                HALTED_ON_WFI:     $fdisplay(out_fileno, "@@@ System halted on WFI instruction");
                ILLEGAL_INST:      $fdisplay(out_fileno, "@@@ System halted on illegal instruction");
                default:           $fdisplay(out_fileno, "@@@ System halted on unknown error code %x", final_status);
            endcase
            $fdisplay(out_fileno, "@@@");
            $fclose(out_fileno);
        end
    endtask // task show_final_mem_and_status



    // OPTIONAL: Print our your data here
    // It will go to the $program.log file
    task print_custom_data;
        //$display("%3d: YOUR DATA HERE", 
        //    clock_count-1
        //);

        // if (1) begin
        //     $display("-------------------------------- fetch --------------------------------");
        //     $display("if_packet[%d], PC %d, NPC %d, valid %b", 0, verisimpleV.if_packet_fetch[0].PC, verisimpleV.if_packet_fetch[0].NPC, verisimpleV.if_packet_fetch[0].valid);
        //     $display("if_packet[%d], PC %d, NPC %d, valid %b", 1, verisimpleV.if_packet_fetch[1].PC, verisimpleV.if_packet_fetch[1].NPC, verisimpleV.if_packet_fetch[1].valid);
        // end

        // if (1) begin
        //     $display("-------------------------------- ib-out --------------------------------");
        //     $display("head %d, tail %d, full %b, start_valid_on_reset %b, usedEntries %d, NumFreeEntries %d", verisimpleV.instb.next_head, verisimpleV.instb.next_tail, verisimpleV.instb.full, verisimpleV.start_valid_on_reset, verisimpleV.instb.usedEntries, verisimpleV.instb.NumFreeEntries);
        //     $display("ib_pckt_out[%d], PC %d, NPC %d, valid %b", 0, verisimpleV.ib_pckt_out[0].PC, verisimpleV.ib_pckt_out[0].NPC, verisimpleV.ib_pckt_out[0].valid);
        //     $display("ib_pckt_out[%d], PC %d, NPC %d, valid %b", 1, verisimpleV.ib_pckt_out[1].PC, verisimpleV.ib_pckt_out[1].NPC, verisimpleV.ib_pckt_out[1].valid);
        // end
        // // Display final FIFO state
        // $display("Time %0t ps | FIFO State:", $time);
        // for (int j = 0; j < `FIFO_SZ; j++) begin
        //     $display("fifo[%0d] | valid: %b | inst: %0x | PC: %0d | NPC: %0d",
        //             j,
        //             verisimpleV.instb.next_fifo[j].valid,
        //             verisimpleV.instb.next_fifo[j].inst,
        //             verisimpleV.instb.next_fifo[j].PC,
        //             verisimpleV.instb.next_fifo[j].NPC);
        // end

    //--------------------------------------------------
    // Debug Packet Printout
    //--------------------------------------------------
    // $display("\n==================== DEBUG PACKETS ====================");

    // // ---- FETCH ----
    // $display("FETCH    | valid: %b | PC: 0x%08x | NPC: 0x%08x | inst: 0x%08x",
    //         fetch_dbg.valid,
    //         fetch_dbg.PC,
    //         fetch_dbg.NPC,
    //         fetch_dbg.inst);

    // // ---- DISPATCH ----
    // $display("DISPATCH | valid: %b | PC: 0x%08x | inst: 0x%08x | arch_dest: x%-2d | T: %0d | Told: %0d | halt: %b",
    //         dispatch_dbg.valid,
    //         dispatch_dbg.PC,
    //         dispatch_dbg.inst,
    //         dispatch_dbg.arch_dest,
    //         dispatch_dbg.T,
    //         dispatch_dbg.Told,
    //         dispatch_dbg.halt);

    // // ---- ISSUE ----
    // $display("ISSUE    | valid: %b | PC: 0x%08x | inst: 0x%08x | T1: %0d | T2: %0d | val1: 0x%08x | val2: 0x%08x | ready: (%b, %b)",
    //         issue_dbg.valid,
    //         issue_dbg.PC,
    //         issue_dbg.inst,
    //         issue_dbg.T1,
    //         issue_dbg.T2,
    //         issue_dbg.val1,
    //         issue_dbg.val2,
    //         issue_dbg.T1_ready,
    //         issue_dbg.T2_ready);

    // // ---- EXECUTE ----
    // $display("EXECUTE  | valid: %b | PC: 0x%08x | inst: 0x%08x | result: 0x%08x | dest_pr: %0d",
    //         execute_dbg.valid,
    //         execute_dbg.PC,
    //         execute_dbg.inst,
    //         execute_dbg.result,
    //         execute_dbg.dest_reg_idx);

    // // ---- COMPLETE ----
    // $display("COMPLETE | valid: %b | tag: %0d | data: 0x%08x | branch?: %b | target: 0x%08x",
    //         complete_dbg.valid,
    //         complete_dbg.tag,
    //         complete_dbg.data,
    //         complete_dbg.if_take_branch,
    //         complete_dbg.target_pc);

    // // ---- RETIRE ----
    // $display("RETIRE   | valid: %b | NPC: 0x%08x | reg: x%0d | data: 0x%08x | branch?: %b | target: 0x%08x | halt: %b | illegal: %b",
    //         retire_dbg.valid,
    //         retire_dbg.NPC,
    //         retire_dbg.reg_idx,
    //         retire_dbg.data,
    //         retire_dbg.if_take_branch,
    //         retire_dbg.target_pc,
    //         retire_dbg.halt,
    //         retire_dbg.illegal);

    // $display("=======================================================\n");

    // $display("\n==================== DEBUG PACKETS ====================");
    // // ---------------------------------------------
    // //              DUMP: INTERNAL STATE
    // // ---------------------------------------------
    // $display("--------- ARCHITECTURAL MAP ---------");
    // for (int i = 0; i < 32; i++) begin
    // $display("AR[%0d] → PR[%0d]", i, arch_map_dbg[i]);
    // end

    // $display("--------- RAT ---------");
    // for (int i = 0; i < 32; i++) begin
    // $display("RAT[%0d] → PR[%0d] (ready: %b)", i, RAT_dbg[i].tag, RAT_dbg[i].ready);
    // end

    // $display("--------- PRF ---------");
    // for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
    // $display("PR[%0d] = 0x%08x", i, prf_dbg[i]);
    // end

    // $display("--------- RS ---------");
    // for (int i = 0; i < `RS_SZ; i++) begin
    // if (rs_dbg[i].valid) begin
    //     $display("RS[%0d] | PC: 0x%08x | TD: %0d | T1: %0d (%b) | T2: %0d (%b)",
    //             i, rs_dbg[i].PC, rs_dbg[i].TD,
    //             rs_dbg[i].T1, rs_dbg[i].T1p,
    //             rs_dbg[i].T2, rs_dbg[i].T2p);
    // end
    // end

    // $display("--------- CDB ---------");
    // for (int i = 0; i < 2; i++) begin
    // if (cdb_dbg[i].valid)
    //     $display("CDB[%0d] | Tag: %0d | Data: 0x%08x", i, cdb_dbg[i].tag, cdb_dbg[i].data);
    // else
    //     $display("CDB[%0d] | ---", i);
    // end

    // $display("--------- FREE LIST ---------");
    // $display("Head: %0d | Tail: %0d", freeList_head_dbg, freeList_tail_dbg);
    // for (int i = 0; i < `ROB_SZ; i++) begin
    // $display("Free[%0d] = PR[%0d]", i, freeList_dbg[i]);
    // end

    // $display("--------- ROB ---------");
    // for (int i = 0; i < `ROB_SZ; i++) begin
    // if (rob_dbg[i].valid) begin
    //     $display("ROB[%0d] | PC: 0x%08x | T: %0d | Told: %0d | AR: x%-2d | Complete: %b",
    //     i, rob_dbg[i].PC, rob_dbg[i].T, rob_dbg[i].Told, rob_dbg[i].dest_reg, rob_dbg[i].complete);
    // end
    // end
    
    // $display("=======================================================\n");


$display("\n==================== DEBUG PACKETS ====================");
$display("Idx | %-20s | %-10s | %-12s | %-12s", "RAT", "ArchMap", "PRF", "FreeList(i)");
$display("----+----------------------+------------+--------------+--------------");

for (int idx = 0; idx < `PHYS_REG_SZ_R10K; idx++) begin
  string rat_str = "";
  string arch_str = "";
  string prf_str = "";
  string free_str = "";

  // Only print RAT entry if in bounds (0–31)
  if (idx < 32)
    $sformat(rat_str, "PR(%2d)(r=%1d)", RAT_dbg[idx].tag, RAT_dbg[idx].ready);
  else
    rat_str = "";

  // Only print ArchMap entry if in bounds (0–31)
  if (idx < 32)
    $sformat(arch_str, "PR(%2d)", arch_map_dbg[idx]);
  else
    arch_str = "";

  // PRF entry (always valid)
  $sformat(prf_str, "0x%08x", prf_dbg[idx]);

  // FreeList entry (only for 0–ROB_SZ-1)
  if (idx < `ROB_SZ) begin
    string head_tag = "";
    string tail_tag = "";

    if (freeList_head_dbg == idx) begin 
        head_tag = "H>";
    end else begin
        head_tag = "  ";
    end
    if (freeList_tail_dbg == idx) begin 
        tail_tag = "<T";
    end else begin
        tail_tag = "  ";
    end

    if (freeList_dbg[idx] !== 'x)
      $sformat(free_str, "%sPR(%2d)%s", head_tag, freeList_dbg[idx], tail_tag);
    else
      $sformat(free_str, "%sPR(??)%s", head_tag, tail_tag);
  end else begin
    free_str = "";
  end

  $display("%2d  | %-20s | %-10s | %-12s | %-12s", idx, rat_str, arch_str, prf_str, free_str);

end

$display("=======================================================\n");



// ROB and RS side-by-side
$display("\nROB  |     PC     |  T  | Told | AR  | Br? | Taken | Target     |  Halt || RS");
$display("------------------------------------------------------------------------------------------------------------------------------------------------");
for (int k = 0; k < `ROB_SZ; k++) begin
  string rob_line = "";
  string rs_line = "";

  if (rob_dbg[k].valid) begin
    $sformat(rob_line,
      "%2d   | 0x%08x | %2d  | %3d  | x%-2d |  %1b  |   %1b   | 0x%08x |   %1b   ||",
      k, rob_dbg[k].PC, rob_dbg[k].T, rob_dbg[k].Told, rob_dbg[k].dest_reg,
      rob_dbg[k].is_branch, rob_dbg[k].if_take_branch, rob_dbg[k].target_pc, rob_dbg[k].halt);
  end else begin
    rob_line = "                                                      ||";
  end

  if (rs_dbg[k].valid) begin
    $sformat(rs_line,
      " RS(%2d) | PC=0x%08x | TD=%2d | T1=%2d (%1b) | T2=%2d (%1b) | FU=%0d | ALU=%0d",
      k, rs_dbg[k].PC, rs_dbg[k].TD,
      rs_dbg[k].T1, rs_dbg[k].T1p,
      rs_dbg[k].T2, rs_dbg[k].T2p,
      rs_dbg[k].FuncUnitType, rs_dbg[k].alu_func);
  end

  if (rob_dbg[k].valid || rs_dbg[k].valid)
    $display("%s%s", rob_line, rs_line);
end

// CDB info
$display("\n--------- CDB ---------");
for (int i = 0; i < 2; i++) begin
  if (cdb_dbg[i].valid)
    $display("CDB(%0d) | Tag: %2d | Data: 0x%08x | Branch?: %b | Target: 0x%08x",
             i, cdb_dbg[i].tag, cdb_dbg[i].data, cdb_dbg[i].if_take_branch, cdb_dbg[i].target_pc);
  else
    $display("CDB(%0d) | ---", i);
end

$display("=======================================================\n");







    endtask


endmodule // module testbench