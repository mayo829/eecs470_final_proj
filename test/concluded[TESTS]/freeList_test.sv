`include "sys_defs.svh"

// This testbench is made for scalar=2 and ROB=16
// im pretty sure everything works, only thing I didnt test is retiring 2 instructions when there is only space for 1, but I dont think this is possible since in this case, ROB would only have that one PR to retire.

module freelist_test;

    logic clock, reset;
    FREELIST_PACKET_IN freeList_in;
    FREELIST_PACKET_OUT freeList_out;
    
    // debug signals
    logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList;
    logic [`ROB_PTR_WIDTH-1:0] head, tail;

    logic passed;

    freeList dut (
        .clock(clock),
        .reset(reset),
        .freeList_in(freeList_in),
        .freeList_out(freeList_out),
        .freeList_dbg(freeList),
        .head_dbg(head),
        .tail_dbg(tail)
    );

    task show_state;
        begin
            $display(
                "\nTime: %3d | dispatch_req: %b | retired_req: %b | retired_tags[0]: %d | retired_tags[1]: %d | free_tags[0]: %d | free_tags[1]: %d  | put_back: %d | valid: %b | total_num_free: %d\n\n\033[38;5;13mfreeList: head: %2d | tail: %2d\n \033[0m---------------------------------------------------------------------------------\n |\033[38;5;13m  0 \033[0m|\033[38;5;13m  1 \033[0m|\033[38;5;13m  2 \033[0m|\033[38;5;13m  3 \033[0m|\033[38;5;13m  4 \033[0m|\033[38;5;13m  5 \033[0m|\033[38;5;13m  6 \033[0m|\033[38;5;13m  7 \033[0m|\033[38;5;13m  8 \033[0m|\033[38;5;13m  9 \033[0m|\033[38;5;13m 10 \033[0m|\033[38;5;13m 11 \033[0m|\033[38;5;13m 12 \033[0m|\033[38;5;13m 13 \033[0m|\033[38;5;13m 14 \033[0m|\033[38;5;13m 15 \033[0m|\033[38;5;13m\n \033[0m---------------------------------------------------------------------------------\n |\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m %2d \033[0m|\033[38;5;13m\033[0m\n ---------------------------------------------------------------------------------\n",
                $time, 
                freeList_in.dispatch_req, 
                freeList_in.retired_req, 
                freeList_in.retired_tags[0], 
                freeList_in.retired_tags[1], 
                freeList_in.put_back,
                freeList_out.free_tags[0], 
                freeList_out.free_tags[1], 
                freeList_out.valid, 
                freeList_out.total_num_free,
                head,
                tail,
                freeList[0], 
                freeList[1], 
                freeList[2], 
                freeList[3], 
                freeList[4], 
                freeList[5], 
                freeList[6], 
                freeList[7], 
                freeList[8], 
                freeList[9], 
                freeList[10],
                freeList[11], 
                freeList[12], 
                freeList[13], 
                freeList[14], 
                freeList[15]
            );
        end
    endtask

    always begin
        #10 clock = ~clock;
    end

    initial begin
        $display("\n---- Starting FreeList Testbench ----\n");

        // $monitor(
        //     "\nTime: %3d | dispatch_req: %b | retired_req: %b | freeList_in.retired_tags[0]: %d | freeList_in.retired_tags[1]: %d | free_tags[0]: %d | free_tags[1]: %d | valid: %b | total_num_free: %d\n\n\033[38;5;13mfreeList: head: %2d | tail: %2d\n ---------------------------------------------------------------------------------\n |  0 |  1 |  2 |  3 |  4 |  5 |  6 |  7 |  8 |  9 | 10 | 11 | 12 | 13 | 14 | 15 |\n ---------------------------------------------------------------------------------\n | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d | %2d |\033[0m\n ---------------------------------------------------------------------------------",
        //     $time, 
        //     dispatch_req, 
        //     retired_req, 
        //     freeList_in.retired_tags[0], 
        //     freeList_in.retired_tags[1], 
        //     freeList_out.free_tags[0], 
        //     freeList_out.free_tags[1], 
        //     freeList_out.valid, 
        //     freeList_out.total_num_free,
        //     head,
        //     tail,
        //     freeList[0], 
        //     freeList[1], 
        //     freeList[2], 
        //     freeList[3], 
        //     freeList[4], 
        //     freeList[5], 
        //     freeList[6], 
        //     freeList[7], 
        //     freeList[8], 
        //     freeList[9], 
        //     freeList[10],
        //     freeList[11], 
        //     freeList[12], 
        //     freeList[13], 
        //     freeList[14], 
        //     freeList[15]
        // );
        
        $dumpfile("../dump/freeList_test.vcd");
        $dumpvars(0, freelist_test.dut);

        clock = 0;
        reset = 1;
        freeList_in.dispatch_req = 0;
        freeList_in.retired_req = 0;
        freeList_in.retired_tags = 0;
        freeList_in.put_back = 0;
        passed = 1;
        
        // Ensure initial conditions are set properly
        @(negedge clock);
        reset = 0;

        $display("\n\nTest 1: Dispatch 1, 2 instructions");
        @(posedge clock);
        freeList_in.dispatch_req = 2'b01;
        @(negedge clock);
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ) begin
            $display("Test 1.0 \033[31m[FAIL]\033[0m: Expected free_tags[0] to be %d, got %d", `RAT_SZ, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-1) begin
            $display("Test 1.01 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-1, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        @(negedge clock);
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+1) begin
            $display("Test 1.1 \033[31m[FAIL]\033[0m: Expected free_tags[0] to be %d, got %d", `RAT_SZ+1, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+2) begin
            $display("Test 1.11 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ+2, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-3) begin
            $display("Test 1.12 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-3, freeList_out.total_num_free);
            passed = 0;
        end

        // NOTE: not sure if i have to test trying to retire something when freelist is full since this is not possible in normal situations, but might be an edge case if other modules are not working properly should not be possible
        @(posedge clock);
        freeList_in.dispatch_req = 2'b00; // stop dispatching
        $display("\n\nTest 2: Retire 1, 2 instructions");
        @(posedge clock);
        freeList_in.retired_req = 2'b01;
        freeList_in.retired_tags[0] = 0;
        @(negedge clock);
        show_state();
        if (freeList_out.total_num_free != `ROB_SZ-2) begin
            $display("Test 2.0 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-2, freeList_out.total_num_free);
            passed = 0;
        end

        @(posedge clock);
        freeList_in.retired_req = 2'b11;
        freeList_in.retired_tags[0] = 1;
        freeList_in.retired_tags[1] = 2;
        @(negedge clock);
        show_state();
        if (freeList_out.total_num_free != `ROB_SZ) begin
            $display("Test 2.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ, freeList_out.total_num_free);
            passed = 0;
        end

        // @(posedge clock);
        // retired_req = 3'b110;
        // freeList_in.retired_tags[1] = 4;
        // freeList_in.retired_tags[2] = 5;
        // @(negedge clock);
        // if (freeList_out.total_num_free != `ROB_SZ) begin
        //     $display("Test 2.2 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ, freeList_out.total_num_free);
        //     passed = 0;
        // end

        // NOTE: might also need to test for dispatching 2 and retire 3 when freeList is full, which should not be allowed since it would only accept 2 out of the 3 since there is only room for the 2 since we only dispatch 2, but i think this logic is taken care of during dispatch
        @(posedge clock);
        freeList_in.retired_req = 2'b00; // stop retiring
        $display("\n\nTest 3: Dispatch 2 and retire 1 instructions at same time");
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        freeList_in.retired_req = 2'b01;
        freeList_in.retired_tags[0] = 3;
        @(negedge clock);
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+3) begin
            $display("Time: %3d Test 3.0 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", $time,`RAT_SZ+3, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+4) begin
            $display("Time: %3d Test 3.01 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", $time, `RAT_SZ+4, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-1) begin
            $display("Test 3.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-1, freeList_out.total_num_free);
            passed = 0;
        end

        @(posedge clock);
        freeList_in.retired_req = 2'b00;
        $display("\n\nTest 4: Empty FreeList");
        // dispatch all free PRs
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+5) begin
            $display("Test 4.0 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", `RAT_SZ+5, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+6) begin
            $display("Test 4.01 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ+6, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-3) begin
            $display("Test 4.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-3, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+7) begin
            $display("Test 4.03 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags to be %d, got %d", `RAT_SZ+7, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+8) begin
            $display("Test 4.04 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags to be %d, got %d", `RAT_SZ+8, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-5) begin
            $display("Test 4.2 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-5, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+9) begin
            $display("Test 4.06 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", `RAT_SZ+9, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+10) begin
            $display("Test 4.07 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ+10, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-7) begin
            $display("Test 4.3 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-7, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+11) begin
            $display("Test 4.09 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", `RAT_SZ+11, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+12) begin
            $display("Test 4.10 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ+12, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-9) begin
            $display("Test 4.4 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-9, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+13) begin
            $display("Test 4.12 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", `RAT_SZ+13, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ+14) begin
            $display("Test 4.13 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ+14, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-11) begin
            $display("Test 4.5 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-11, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != `RAT_SZ+15) begin
            $display("Test 4.12 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", `RAT_SZ+15, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != `RAT_SZ-`RAT_SZ) begin
            $display("Test 4.13 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", `RAT_SZ-`RAT_SZ, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-13) begin
            $display("Test 4.5 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-13, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        show_state();
        if (freeList_out.free_tags[0] != (`RAT_SZ-`RAT_SZ)+1) begin
            $display("Test 4.12 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", (`RAT_SZ-`RAT_SZ)+1, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != (`RAT_SZ-`RAT_SZ)+2) begin
            $display("Test 4.13 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be %d, got %d", (`RAT_SZ-`RAT_SZ)+2, freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-15) begin
            $display("Test 4.5 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be %d, got %d", `ROB_SZ-15, freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.dispatch_req = 2'b00;
        show_state();
        if (freeList_out.free_tags[0] != (`RAT_SZ-`RAT_SZ)+3) begin
            $display("Time: %3d Test 4.12 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be %d, got %d", $time, (`RAT_SZ-`RAT_SZ)+3, freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.total_num_free != `ROB_SZ-`ROB_SZ) begin
            $display("Test 4.5 \033[31m[FAIL]\033[0m: Expected freeList to be empty and freeList_out.total_num_free to be %d, got %d", `ROB_SZ-16, freeList_out.total_num_free);
            passed = 0;
        end

        @(posedge clock);
        $display("\n\nTest 5: Dispatch 2 and retire 2 instructions at same time after emptying FreeList");
        @(posedge clock);
        freeList_in.retired_req = 2'b11;
        freeList_in.retired_tags[0] = 16;
        freeList_in.retired_tags[1] = 33;
        freeList_in.dispatch_req = 2'b11;
        @(negedge clock);
        show_state();
        if (freeList_out.free_tags[0] != 16) begin
            $display("Test 5.0 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be 16, got %d", freeList_out.free_tags[0]);
            passed = 0;
        end
        if (freeList_out.free_tags[1] != 33) begin
            $display("Test 5.01 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[1] to be 33, got %d", freeList_out.free_tags[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != 0) begin
            $display("Test 5.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 0, got %d", 0, freeList_out.total_num_free);
            passed = 0;
        end

        @(posedge clock);
        freeList_in.retired_req = 2'b00;
        freeList_in.dispatch_req = 2'b00;
        $display("\n\nTest 6: Try to dispatch 2 instructions when FreeList is empty");
        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        @(negedge clock);
        show_state();
        if (freeList_out.valid[0] != 0) begin
            $display("Test 6.0 \033[31m[FAIL]\033[0m: Expected freeList_out.valid[0] to be 0, got %d", freeList_out.valid[0]);
            passed = 0;
        end
        if (freeList_out.valid[1] != 0) begin
            $display("Test 6.01 \033[31m[FAIL]\033[0m: Expected freeList_out.valid[1] to be 0, got %d", freeList_out.valid[1]);
            passed = 0;
        end
        if (freeList_out.total_num_free != 0) begin
            $display("Test 6.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 0, got %d", 0, freeList_out.total_num_free);
            passed = 0;
        end

        @(posedge clock);
        freeList_in.retired_req = 2'b00;
        freeList_in.dispatch_req = 2'b00;
        $display("\n\nTest 7: Putback instructions test");
        @(posedge clock);
        freeList_in.retired_req = 2'b11;
        freeList_in.retired_tags[0] = 12;
        freeList_in.retired_tags[1] = 15;
        @(negedge clock);
        show_state();
        if (freeList_out.total_num_free != 2) begin
            $display("Test 7.0 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 2, got %d", freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.retired_tags[0] = 13;
        freeList_in.retired_tags[1] = 14;
        @(negedge clock);
        show_state();
        if (freeList_out.total_num_free != 4) begin
            $display("Test 7.1 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 4, got %d", freeList_out.total_num_free);
            passed = 0;
        end
        @(posedge clock);
        freeList_in.retired_req = 2'b00;
        freeList_in.dispatch_req = 2'b11;
        @(negedge clock);
        freeList_in.put_back = 1;
        #1;
        show_state();
        if (freeList_out.total_num_free != 3) begin
            $display("Test 7.2 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 3, got %d", freeList_out.total_num_free);
            passed = 0;
        end
        if (freeList_out.free_tags[0] != 12) begin
            $display("Test 7.21 \033[31m[FAIL]\033[0m: Expected freeList_out.free_tags[0] to be 12, got %d", freeList_out.free_tags[0]);
            passed = 0;
        end

        @(posedge clock);
        freeList_in.dispatch_req = 2'b11;
        @(negedge clock);
        freeList_in.put_back = 2;
        #1;
        show_state();
        if (freeList_out.total_num_free != 3) begin
            $display("Test 7.3 \033[31m[FAIL]\033[0m: Expected freeList_out.total_num_free to be 3, got %d", freeList_out.total_num_free);
            passed = 0;
        end
        
        @(posedge clock);
        freeList_in.dispatch_req = 2'b00;
        freeList_in.put_back = 0;

        $display("\n\n----- Test Finished -----\n");
        $display("---- End State ----");
        show_state();
        if (passed) begin
            $display("\033[32m[!PASS!]\033[0m: All tests passed!!!!!!!!!!!!");
        end else begin
            $display("\033[31m[-FAIL-]\033[0m: Some tests failed!");
        end
        $finish;
    end
endmodule