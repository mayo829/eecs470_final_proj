`include "sys_defs.svh"
`timescale 1ns/1ps

module dcache_tb;

  // Parameters
  parameter CLOCK_PERIOD = 10;

  // Clock and reset
  logic clock;
  logic reset;

  // Inputs to the dcache
  MEM_TAG Dmem2proc_transaction_tag;
  MEM_BLOCK Dmem2proc_data;
  MEM_TAG Dmem2proc_data_tag;
  ADDR load2Dcache_addr;
  logic load2Dcache_valid;
  ADDR store2Dcache_addr;
  MEM_SIZE store2Dcache_size;
  DATA store2Dcache_data;
  logic store2Dcache_valid;

  // Outputs from the dcache
  MEM_COMMAND proc2Dmem_command;
  ADDR proc2Dmem_addr;
  MEM_BLOCK dcache2load_data_out;
  logic dcache2load_valid_out;
  MEM_BLOCK   proc2Dmem_data_out;
  logic dcache2store_valid_out;

  // Instantiate the dcache
  dcache uut (
    .clock(clock),
    .reset(reset),

    // From Memory
    .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
    .Dmem2proc_data(Dmem2proc_data),
    .Dmem2proc_data_tag(Dmem2proc_data_tag),

    // To Memory
    .proc2Dmem_command(proc2Dmem_command),
    .proc2Dmem_addr(proc2Dmem_addr),
    .proc2Dmem_data_out(proc2Dmem_data_out),

    // From Load
    .load2Dcache_addr(load2Dcache_addr),
    .load2Dcache_valid(load2Dcache_valid),

    // To Load Unit
    .dcache2load_data_out(dcache2load_data_out),
    .dcache2load_valid_out(dcache2load_valid_out),

    // From Store
    .store2Dcache_addr(store2Dcache_addr),
    .store2Dcache_size(store2Dcache_size),
    .store2Dcache_data(store2Dcache_data),
    .store2Dcache_valid(store2Dcache_valid),

    // to Sq
    .dcache2store_valid_out(dcache2store_valid_out)
  );

  // Clock generation
  initial begin
    clock = 0;
    forever #(CLOCK_PERIOD / 2.0) clock = ~clock;
  end

  // Test tasks
  task reset_test();
    begin
      @(posedge clock);
      reset = 1;
      @(posedge clock);
      reset = 0;
      @(posedge clock);

      $display("--- Performing Reset Test ---");
      if (proc2Dmem_command == MEM_NONE) begin
        $display("Reset works: proc2Dmem_command is MEM_NONE");
      end else begin
        $display("Error: Reset failed, proc2Dmem_command is %b", proc2Dmem_command);
      end
    end
  endtask

  task load_test(input ADDR addr);
    begin
      $display("--- Performing Load Test ---");
      @(posedge clock);
      load2Dcache_valid = 1;
      load2Dcache_addr = addr;
      
      // Simulate memory response after some delay
      repeat (10) @(posedge clock);
      Dmem2proc_transaction_tag = 4'd1; // Example tag
      Dmem2proc_data = 32'hDEADBEEF; // Example data
      Dmem2proc_data_tag = 4'd1;

      // Observe the dcache outputs
      repeat (5) @(posedge clock);
      if (dcache2load_valid_out) begin
        $display("Data valid: %h", dcache2load_data_out);
      end else begin
        $display("Error: Data not valid");
      end
      //disp_cache(); // uncomment to display cache contents

      // if (uut.dcache_tags[3].valid && dcache2load_data_out == 32'hdeadbeef) begin
      //   // Green color for pass using ANSI escape codes
      //   $display("\033[32m[PASS]\033[0m load test");
      // end else begin
      //   // Red color for fail
      //   $display("\033[31m[FAIL]\033[0m load test");
      // end
      //disp_cache();

      Dmem2proc_transaction_tag = 4'd0; // Example tag
      Dmem2proc_data_tag = 4'd0;
    end
  endtask

  task store_test(input ADDR addr, input DATA data);
    begin
      $display("--- Performing Store Test ---");
      @(posedge clock);
      load2Dcache_valid  = 0;
      store2Dcache_valid = 1;
      store2Dcache_size  = WORD;
      store2Dcache_addr  = addr;
      store2Dcache_data  = data;
      // doing store
      repeat (5) @(posedge clock); // one clock cycle delay for cache miss do a load
      Dmem2proc_data = '0; // Example data

      @(posedge clock); // one clock cycle delay for cache hit doa store
      @(negedge clock);

      // if (uut.dcache_tags[5].dirty && uut.dcache_tags[5].valid && uut.dcache_mem.memData[5] == 64'hbaadfade00000000) begin
      //   // Green color for pass using ANSI escape codes
      //   $display("\033[32m[PASS]\033[0m store test 1");
      // end else begin
      //   // Red color for fail
      //   $display("\033[31m[FAIL]\033[0m store test 1");
      // end
      //disp_cache();
      store2Dcache_valid = 0; // Deactivate store

      @(posedge clock);
      load2Dcache_valid = 1;
      load2Dcache_addr = addr;
      repeat (5) @(posedge clock);

      //store2Dcache_valid = 0;
      @(negedge clock);
      // $display("got_mem_data: %b", uut.got_mem_data);
      // disp_cache();

      if (dcache2load_valid_out) begin
        $display("Data valid: %h", dcache2load_valid_out);
        $display("\033[32m[PASS]\033[0m store test 2");

      end else begin
        $display("Error: Data not valid");
        $display("\033[31m[FAIL]\033[0m store test 2");

      end
      load2Dcache_valid = 0;
    end
  endtask

  task wb_test(input ADDR addr, input DATA store_data, input DATA load_data);
    begin
      $display("--- Performing Writeback Test ---");
      @(posedge clock);
      load2Dcache_valid = 0;
      store2Dcache_valid = 1;
      store2Dcache_addr = addr;
      store2Dcache_data = store_data;
      @(posedge clock); // should be a cache hit store
      @(negedge clock);
      //disp_cache();

      // if (uut.dcache_tags[3].dirty && uut.dcache_tags[3].valid && uut.dcache_mem.memData[3] == 64'hBEC0FFEEDEADBEEF) begin
      //   // Green color for pass using ANSI escape codes 
      //   $display("\033[32m[PASS]\033[0m Writeback test1");
      // end else begin
      //   // Red color for fail
      //   $display("\033[31m[FAIL]\033[0m Writeback test1");
      // end
      store2Dcache_valid = 0; // Deactivate store      // Observe writeback and command outputs

      @(posedge clock); 
      load2Dcache_valid = 1;
      load2Dcache_addr = addr;
      @(posedge clock);
      @(negedge clock);
//      $display("got_mem_data: %b", uut.got_mem_data);
      //disp_cache();
      if (dcache2load_valid_out) begin
        $display("Data valid: %h", dcache2load_data_out);
      end else begin
        $display("Error: Data not valid");
      end
      load2Dcache_valid = 0;
      @(posedge clock);
      load2Dcache_valid = 1;
      load2Dcache_addr  = 32'h501c;

      // Simulate memory response after some delay
      repeat (10) @(posedge clock);

      Dmem2proc_transaction_tag = 4'd1; // Example tag
      Dmem2proc_data = load_data; // Example data
      Dmem2proc_data_tag = 4'd1;
      $display("proc2Dmem_addr: %h", proc2Dmem_addr);
      $display("proc2Dmem_data_out: %h", proc2Dmem_data_out);
      
      if (dcache2load_data_out == 64'hBEC0FFEEDEADBEEF) begin
        // Green color for pass using ANSI escape codes 
        $display("\033[32m[PASS]\033[0m Writeback test2");
      end else begin
        // Red color for fail
        $display("\033[31m[FAIL]\033[0m Writeback test2");
      end

      if (proc2Dmem_data_out == 64'hBEC0FFEEDEADBEEF) begin
        // Green color for pass using ANSI escape codes 
        $display("\033[32m[PASS]\033[0m Writeback test3");
      end else begin
        // Red color for fail
        $display("\033[31m[FAIL]\033[0m Writeback test3");
      end
      //load2Dcache_valid = 1;


      @(posedge clock)
      @(negedge clock);

      //disp_cache();
      // if (!uut.dcache_tags[3].dirty && uut.dcache_tags[3].valid && dcache2load_data_out == 64'h00000000b00fCAFE) begin
      //   // Green color for pass using ANSI escape codes 
      //   $display("\033[32m[PASS]\033[0m Writeback test4");
      // end else begin
      //   // Red color for fail
      //   $display("\033[31m[FAIL]\033[0m Writeback test4");
      // end
    end
  endtask


  task disp_cache();
    begin
      // $display("Cache contents:");
      // for (int i = 0; i < `ICACHE_LINES; i++) begin
      //   $display("Line %0d: Tag: %h, Valid: %b, Dirty: %h, Data: %h", i, uut.dcache_tags[i].tags, uut.dcache_tags[i].valid, uut.dcache_tags[i].dirty, uut.dcache_mem.memData[i]);
      // end
    end
  endtask

  initial begin
    // Initialize inputs
    reset = 1;
    Dmem2proc_transaction_tag = 0;
    Dmem2proc_data = 0;
    Dmem2proc_data_tag = 0;
    load2Dcache_addr = 0;
    load2Dcache_valid = 0;
    store2Dcache_addr = 0;
    store2Dcache_size = 0;
    store2Dcache_data = 0;
    store2Dcache_valid = 0;
    // $monitor("Time: %0t, current_index: %d, current_tag: %d, got_mem_data: %d, read_en: %b, write_en %b, storedata: %h, negate: %h, align: %h, store2dcache:%h, case: %b, hit: %b, load2Dcache_valid: %b, dcache2load_valid_out: %b, dcache2store_data_out: %h", 
    //           $time, uut.current_index, uut.current_tag, uut.got_mem_data, uut.read_en, uut.write_en, uut.store_data, uut.aligned_store_data_negate, uut.aligned_store_data, store2Dcache_data, uut.store2Dcache_addr[2:0], uut.cache_hit, load2Dcache_valid, dcache2load_valid_out, dcache2store_valid_out);

    // Release reset and perform tests
    reset_test();
    // load a whole word from memory
    load_test(32'h001c);
    // store a whole word to memory
    store_test(32'h202c, 32'hBAADFADE);
    // test writing back to memory
    wb_test(32'h001c, 32'hBEC0FFEE, 32'hb00fCAFE);

    //load_and_store(32'h001c, 32'hFEEDBEEF, 32'h202c, 32'hb00fb00f);

    $finish;
  end
endmodule
