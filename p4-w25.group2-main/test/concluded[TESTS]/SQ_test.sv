`include "sys_defs.svh"
`timescale 1ns/1ps

module SQ_tb;

  // Parameters
  parameter CLOCK_PERIOD = 10; // Adjust for effective simulation timing

  logic clock;
  logic reset;
  logic branch_mispredict;
  logic failed;
  COMPLETE_SQ_PACKET [`N-1:0] complete_sq_packet;
  logic [`N-1:0] retired_req;
  SQ_PACKET [`N-1:0] sQueue_packet_out;
  logic [`N-1:0]  dispatch_req;
  logic [`N-1:0][$clog2(`ROB_SZ)-1:0] sq_pos;
  logic [`N-1:0] sq_pos_valid;
  logic full;
  logic [$clog2(`ROB_SZ)-1:0] usedEntries;
  SQ_ENTRY [`ROB_SZ-1:0] sQueue;
  logic [$clog2(`ROB_SZ)-1:0] head;

  SQ dut (
    .clock(clock),
    .reset(reset),
    .branch_mispredict(branch_mispredict),
    .complete_sq_packet(complete_sq_packet),
    .retired_req(retired_req),
    .sQueue_packet_out(sQueue_packet_out),
    .dispatch_req(dispatch_req),
    .sq_pos(sq_pos),
    .sq_pos_valid(sq_pos_valid),
    .full(full),
    .usedEntries(usedEntries),
    .sQueue(sQueue),
    .head(head)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Assign initial states
  initial begin
    reset = 1;
    dispatch_req = '0;
    retired_req = '0;
  end

  // Apply reset process
  initial begin
    #100;
    reset = 0;
  end

  // Display FIFO packet out contents visually
  task show_sq;
        begin
            $display("\nTime: %0t", $time);
            $display(" ---------------------------------------------------------\n |\033[38;5;13m v \033[0m|\033[38;5;13m allocated \033[0m|\033[38;5;13m address      \033[0m|\033[38;5;13m value        \033[0m|\033[38;5;13m retired \033[0m|");
            for (int i = 0; i < `ROB_SZ; i++) begin
                $display(
                    "\033[0m |--------------------------------------------------------\n |\033[38;5;13m %b \033[0m|\033[38;5;13m %b         \033[0m|\033[38;5;13m 0x%10h \033[0m|\033[38;5;13m 0x%10h \033[0m|\033[38;5;13m %b       \033[0m|",
                    sQueue[i].valid, 
                    sQueue[i].allocated, 
                    sQueue[i].address, 
                    sQueue[i].value,
                    sQueue[i].retired
                );
            end
            $display(" ---------------------------------------------------------\n");
        end
    endtask

  task set_complete_sq_packet(input int idx, logic valid, logic [$clog2(`ROB_SZ)-1:0] sq_pos, ADDR address, DATA value);
    begin
      complete_sq_packet[idx].valid = valid;
      complete_sq_packet[idx].sq_pos = sq_pos;
      complete_sq_packet[idx].address = address;
      complete_sq_packet[idx].value = value;
    end
  endtask

  // Testbench Main Execution
  initial begin
    $vcdplusfile("/home/lbrzozow/Documents/eecs470/proj/p4-w25.group2/dump/SQ_test.vpd"); 
    $vcdpluson();
    reset = 1;
    branch_mispredict = 0;
    complete_sq_packet = '{default: '0};
    dispatch_req = '0;
    retired_req = '0;
    failed = 0;

    // Wait for reset to be released
    @(negedge reset);
    #10;

    show_sq();

    @(posedge clock);
    // Test case 1: Dispatching packets
    dispatch_req = 'b11;
    @(negedge clock);
    if (sq_pos[0] != 0 || sq_pos[1] != 1 || sq_pos_valid[0] != 1 || sq_pos_valid[1] != 1) begin
      $display("Test case 1 failed: Incorrect sq_pos values");
      failed = 1;
    end

    @(posedge clock);
    @(negedge clock);
    if (sq_pos[0] != 2 || sq_pos[1] != 3 || sq_pos_valid[0] != 1 || sq_pos_valid[1] != 1) begin
      $display("Test case 1 failed: Incorrect sq_pos values");
      failed = 1;
    end
    show_sq();

    @(posedge clock);
    @(negedge clock);
    if (sq_pos[0] != 4 || sq_pos[1] != 5 || sq_pos_valid[0] != 1 || sq_pos_valid[1] != 1) begin
      $display("Test case 1 failed: Incorrect sq_pos values");
      failed = 1;
    end
    show_sq();

    @(posedge clock);
    set_complete_sq_packet(0, 1, 1, 32'h00001004, 32'h0000BEEF);
    set_complete_sq_packet(1, 1, 12, 32'h00001001, 32'h0000DEAD);

    @(posedge clock);
    dispatch_req = '0;
    set_complete_sq_packet(0, 0, 0, 32'h0, 32'h0);

    repeat (4) @(posedge clock);
    set_complete_sq_packet(1, 0, 0, 32'h0, 32'h0);
    retired_req = 'b11;
    show_sq();

    @(posedge clock);
    set_complete_sq_packet(0, 1, 3, 32'h10101, 32'hC0FEEE);
    show_sq();

    @(posedge clock);
    set_complete_sq_packet(1, 1, 0, 32'h00001012, 32'hDEADBEEF);

    @(posedge clock);
    retired_req = 'b0;
    set_complete_sq_packet(0, 0, 0, 32'h0, 32'h0);
    @(negedge clock);
    show_sq();

    @(posedge clock);
    branch_mispredict = 1;

    @(posedge clock);
    branch_mispredict = 0;
    @(negedge clock);
    show_sq();

    @(posedge clock);


    // Simulation end
    if (!failed) begin
        $display("\033[32m[!PASS!]\033[0m: All tests passed!!!!!!!!!!!!");
    end else begin
        $display("\033[31m[-FAIL-]\033[0m: Some tests failed!");
    end
    $finish;
  end

endmodule