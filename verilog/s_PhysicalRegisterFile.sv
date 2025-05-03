`include "sys_defs.svh"

module s_PhysicalRegisterFile (
    input   logic clock,
    input   logic reset,

    input  logic [1:0][`PR_WIDTH-1:0] readIDX_Ainput,
    input  logic [1:0][`PR_WIDTH-1:0] readIDX_Binput,

    input  CDB_ENTRY_PACKET [1:0] CDB_in,  // CDB Input for writeback

    output DATA [1:0] readIDX_AdataOutput,
    output DATA [1:0] readIDX_BdataOutput,

    output DATA [`PHYS_REG_SZ_R10K-1:0] prf_dbg,  // Debugging output for PRF

    //for making sure commit is correct
    input  logic [1:0][`PR_WIDTH-1:0]   testingTindicies, 
    output DATA  [1:0]                  testingTDATA
);

  // ✅ Storage for PRF (Array of DATA elements)
  DATA [`PHYS_REG_SZ_R10K-1:0] PRF;
  DATA [`PHYS_REG_SZ_R10K-1:0] PRF_next;

  always_comb begin
    for(int i = 0; i < 2; i++) begin
        testingTDATA[i] = PRF[testingTindicies[i]];
    end
  end

  // ✅ Writing to PRF from CDB (Common Data Bus)
  always_comb begin
      PRF_next = PRF;  // ✅ Default: Carry over previous state

      for(int i = 0; i < 2; i++) begin
          if (CDB_in[i].valid && (CDB_in[i].tag != `ZERO_REG)) begin
              PRF_next[CDB_in[i].tag] = CDB_in[i].data;
          end
      end
  end

  // ✅ Reading PRF values for Execute/Issue Stage
  always_comb begin
      for (int i = 0; i < 2; i++) begin
          readIDX_AdataOutput[i] = PRF[readIDX_Ainput[i]];
          readIDX_BdataOutput[i] = PRF[readIDX_Binput[i]];
      end
  end

// always_comb begin
//     for (int i = 0; i < 48; i++) begin
//         $display("[PRF STATE] PR[%0d] = %0d", i, PRF[i]);
//     end
// end
  // ✅ Sequential Register Update
  always_ff @(posedge clock) begin
      if (reset) begin
          for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
              PRF[i] <= '0;  // ✅ Reset all registers
          end
      end else begin
          PRF <= PRF_next;  // ✅ Commit new values
      end
  end

assign prf_dbg = PRF; // ✅ Debugging Output

endmodule         