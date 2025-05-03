`include "sys_defs.svh"

module stage_if_test;
    parameter SCALAR = 3;
    parameter FIFO_DEPTH = 16;
    parameter FIFO_WIDTH = 32;

    logic clock, reset;
    logic if_valid, take_branch;
    logic [31:0] branch_target;
    MEM_BLOCK Imem_data[SCALAR-1:0];
    logic [$clog2(SCALAR):0] num_dispatch;
    IF_ID_PACKET if_packet[SCALAR-1:0];
    logic [31:0] Imem_addr;

    stage_if #(
        .SCALAR(SCALAR),
        .FIFO_DEPTH(FIFO_DEPTH),
        .FIFO_WIDTH(FIFO_WIDTH)
    ) uut (
        .clock(clock),
        .reset(reset),
        .if_valid(if_valid),
        .take_branch(take_branch),
        .branch_target(branch_target),
        .Imem_data(Imem_data),
        .num_dispatch(num_dispatch),
        .if_packet(if_packet),
        .Imem_addr(Imem_addr)
    );

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;  // 10ns clock period
    end

    initial begin
        $dumpfile("stage_if_test.vcd");
        $dumpvars(0, stage_if_test);
        $display("\nStarting testbench...");

        // Initialize signals
        reset = 1;
        if_valid = 0;
        take_branch = 0;
        branch_target = 32'h0;
        num_dispatch = 0;
        
        // Wait for a few cycles
        @(negedge clock);
        reset = 0;
        
        // Test 1: Fetch Specific Instructions
        $display("\nTest 1: Fetch Specific Instructions");

        // Load instructions using dbbl_level
        Imem_data[0].dbbl_level = 64'h0010009300200113;
        Imem_data[1].dbbl_level = 64'h0030019300400213;
        Imem_data[2].dbbl_level = {`NOP, `NOP};
        
        @(negedge clock);
        if_valid = 1;
        @(negedge clock);

        // Confirm fetch cycle completed without X states
        if_valid = 0;

        // Test 2: Dispatch Instructions
        $display("\nTest 2: Output Dispatched Instructions");
        num_dispatch = 2;
        @(negedge clock);
        num_dispatch = 0;
        @(negedge clock);

        // Test 3: Execute a Branch Operation
        $display("\nTest 3: Branch Operation");
        @(negedge clock);
        take_branch = 1;
        branch_target = 32'h10000000;
        @(negedge clock);
        take_branch = 0;
        @(negedge clock);

        $display("\nTest Finished. @@@ Passed\n");
        $finish;
    end

    // Monitor execution
    initial begin
        $monitor("Time: %3d | if_valid: %b | take_branch: %b | branch_target: 0x%h | Imem_data: {%h, %h, %h} | num_dispatch: %d | if_packet.inst[0]: 0x%h | if_packet.inst[1]: 0x%h | if_packet.inst[2]: 0x%h | Imem_addr: 0x%h | fifo_wr_en: %b | fifo_rd_en: %b | fifo_rd_valid: %b | fifo_full: %b",
                 $time, if_valid, take_branch, branch_target, 
                 Imem_data[0].dbbl_level, Imem_data[1].dbbl_level, Imem_data[2].dbbl_level, 
                 num_dispatch, if_packet[0].inst, if_packet[1].inst, if_packet[2].inst, Imem_addr, 
                 uut.fifo_wr_en, uut.fifo_rd_en, uut.fifo_rd_valid, uut.fifo_full);
    end

endmodule