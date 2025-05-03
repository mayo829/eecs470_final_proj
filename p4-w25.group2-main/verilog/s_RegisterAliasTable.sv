//THIS SHOULD BE GOOD, DOES NOT HANDLE REWIND

`include "sys_defs.svh"


// CODE IS MY OWN, GPT ONLY COMMENTED ON FUNCTIONALITY AND FLOW

module s_RegisterAliasTable (
  input  logic                    clock,
  input  logic                    reset,
  input  logic                    misprediction,

  // 2 instructions' architectural src regs and dest regs
  input  REG_IDX [1:0] arc_src1_regs,
  input  REG_IDX [1:0] arc_src2_regs,
  input  REG_IDX [1:0] arc_dest_regs,

  // 2 allocated free PRs, each 6 bits
  input  FREELIST_PACKET_OUT      free_physical_register_indicies,
  // input  logic [1:0][5:0]         free_physical_register_indicies,
  // TRUNCATED SIGNAL, NEEDS TO BE UPDATED IN TESTBENCH

  // Up to 2 writes on CDB (not yet used)
  input  logic [1:0]              cdb_valid,
  input  logic [1:0][5:0]         cdb_tag,
  input  logic [31:0][`PR_WIDTH-1:0]  arch_map_out_to_RAT,

  // RAT outputs: T, Told, T1, T2 are each 6 bits per instruction
  output logic [1:0][5:0]         Told,
  output logic [1:0][5:0]         T,
  output logic [1:0][5:0]         T1,
  output logic [1:0]              T1p,
  output logic [1:0][5:0]         T2,
  output logic [1:0]              T2p,

  output RAT_ENTRY_PACKET [0:31] RAT_dbg
);

  // Current RAT state
  RAT_ENTRY_PACKET [0:31] rat_array;

  // Temporary next-state RAT (updated in the same cycle)
  RAT_ENTRY_PACKET [0:31] rat_array_next;


//truncated combinational logic commented out
// always_comb begin
//   logic inst1_fwd_T1;
//   logic inst1_fwd_T2;
//   logic inst1_same_dest_as_0;

//   rat_array_next = rat_array;

//   // --- CDB Updates ---
//   for (int i = 1; i < 32; i++) begin
//     for (int j = 0; j < 2; j++) begin
//       if (cdb_valid[j] && (rat_array[i].tag == cdb_tag[j])) begin
//         rat_array_next[i].ready = 1'b1;
//       end
//     end
//   end

//   // -------------------------
//   // INSTRUCTION 0
//   // -------------------------
//   T[0]    = (arc_dest_regs[0] != `ZERO_REG) ? free_physical_register_indicies[0] : 6'd0;
//   Told[0] = (arc_dest_regs[0] != `ZERO_REG) ? rat_array[arc_dest_regs[0]].tag    : 6'd0;

//   T1[0]  = (arc_src1_regs[0] != `ZERO_REG) ? rat_array[arc_src1_regs[0]].tag       : 6'd0;
//   T1p[0] = (arc_src1_regs[0] != `ZERO_REG) ? rat_array_next[arc_src1_regs[0]].ready : 1'b1;

//   T2[0]  = (arc_src2_regs[0] != `ZERO_REG) ? rat_array[arc_src2_regs[0]].tag       : 6'd0;
//   T2p[0] = (arc_src2_regs[0] != `ZERO_REG) ? rat_array_next[arc_src2_regs[0]].ready : 1'b1;

//   if (arc_dest_regs[0] != `ZERO_REG) begin
//     rat_array_next[arc_dest_regs[0]].tag   = T[0];
//     rat_array_next[arc_dest_regs[0]].ready = 1'b0;
//   end

//   // -------------------------
//   // INSTRUCTION 1
//   // -------------------------
//   inst1_fwd_T1 = (arc_src1_regs[1] == arc_dest_regs[0]) && (arc_src1_regs[1] != `ZERO_REG);
//   inst1_fwd_T2 = (arc_src2_regs[1] == arc_dest_regs[0]) && (arc_src2_regs[1] != `ZERO_REG);
//   inst1_same_dest_as_0 = (arc_dest_regs[1] == arc_dest_regs[0]) && (arc_dest_regs[1] != `ZERO_REG);

//   T[1]    = (arc_dest_regs[1] != `ZERO_REG) ? free_physical_register_indicies[1] : 6'd0;
//   Told[1] = (arc_dest_regs[1] != `ZERO_REG) ? 
//             (inst1_same_dest_as_0 ? T[0] : rat_array[arc_dest_regs[1]].tag)
//           : 6'd0;


//   T1[1] = inst1_fwd_T1 ? T[0] : (arc_src1_regs[1] != `ZERO_REG) ? rat_array[arc_src1_regs[1]].tag : 6'd0;
// T1p[1] = inst1_fwd_T1 ? 1'b0 : (arc_src1_regs[1] != `ZERO_REG) ? rat_array_next[arc_src1_regs[1]].ready : 1'b1;

// T2[1] = inst1_fwd_T2 ? T[0] : (arc_src2_regs[1] != `ZERO_REG) ? rat_array[arc_src2_regs[1]].tag : 6'd0;
// T2p[1] = inst1_fwd_T2 ? 1'b0 : (arc_src2_regs[1] != `ZERO_REG) ? rat_array_next[arc_src2_regs[1]].ready : 1'b1;

//   if ((arc_dest_regs[1] != `ZERO_REG) && !inst1_same_dest_as_0) begin
//     rat_array_next[arc_dest_regs[1]].tag   = T[1];
//     rat_array_next[arc_dest_regs[1]].ready = 1'b0;
//   end
// end

always_comb begin
  logic inst1_fwd_T1;
  logic inst1_fwd_T2;

  rat_array_next = rat_array;

  // --- CDB Updates ---
  for (int i = 1; i < 32; i++) begin
    for (int j = 0; j < 2; j++) begin
      if (cdb_valid[j] && (rat_array[i].tag == cdb_tag[j])) begin
        rat_array_next[i].ready = 1'b1;
      end
    end
  end

  // -------------------------
  // INSTRUCTION 0
  // -------------------------
  T[0]    = (arc_dest_regs[0] != `ZERO_REG && free_physical_register_indicies.valid[0])
            ? free_physical_register_indicies.free_tags[0]
            : 6'd0;

  Told[0] = (arc_dest_regs[0] != `ZERO_REG && free_physical_register_indicies.valid[0])
            ? rat_array[arc_dest_regs[0]].tag
            : 6'd0;

  T1[0]  = (arc_src1_regs[0] != `ZERO_REG) ? rat_array[arc_src1_regs[0]].tag       : 6'd0;
  T1p[0] = (arc_src1_regs[0] != `ZERO_REG) ? rat_array_next[arc_src1_regs[0]].ready : 1'b1;

  T2[0]  = (arc_src2_regs[0] != `ZERO_REG) ? rat_array[arc_src2_regs[0]].tag       : 6'd0;
  T2p[0] = (arc_src2_regs[0] != `ZERO_REG) ? rat_array_next[arc_src2_regs[0]].ready : 1'b1;

  if (arc_dest_regs[0] != `ZERO_REG && free_physical_register_indicies.valid[0]) begin
    rat_array_next[arc_dest_regs[0]].tag   = T[0];
    rat_array_next[arc_dest_regs[0]].ready = 1'b0;
  end

  // -------------------------
  // INSTRUCTION 1
  // -------------------------
  inst1_fwd_T1 = (arc_src1_regs[1] == arc_dest_regs[0]) && (arc_src1_regs[1] != `ZERO_REG);
  inst1_fwd_T2 = (arc_src2_regs[1] == arc_dest_regs[0]) && (arc_src2_regs[1] != `ZERO_REG);

  T[1] = (arc_dest_regs[1] != `ZERO_REG && free_physical_register_indicies.valid[1])
         ? free_physical_register_indicies.free_tags[1]
         : 6'd0;

  Told[1] = (arc_dest_regs[1] != `ZERO_REG && free_physical_register_indicies.valid[1])
            ? ((arc_dest_regs[1] == arc_dest_regs[0]) ? T[0] : rat_array[arc_dest_regs[1]].tag)
            : 6'd0;

  T1[1] = inst1_fwd_T1 ? T[0] :
          (arc_src1_regs[1] != `ZERO_REG) ? rat_array[arc_src1_regs[1]].tag : 6'd0;

  T1p[1] = inst1_fwd_T1 ? 1'b0 :
           (arc_src1_regs[1] != `ZERO_REG) ? rat_array_next[arc_src1_regs[1]].ready : 1'b1;

  T2[1] = inst1_fwd_T2 ? T[0] :
          (arc_src2_regs[1] != `ZERO_REG) ? rat_array[arc_src2_regs[1]].tag : 6'd0;

  T2p[1] = inst1_fwd_T2 ? 1'b0 :
           (arc_src2_regs[1] != `ZERO_REG) ? rat_array_next[arc_src2_regs[1]].ready : 1'b1;

  if (arc_dest_regs[1] != `ZERO_REG && free_physical_register_indicies.valid[1]) begin
    rat_array_next[arc_dest_regs[1]].tag   = T[1];
    rat_array_next[arc_dest_regs[1]].ready = 1'b0;
  end


  if(misprediction) begin 

    for (int i = 0; i < 32; i++) begin

      rat_array_next[i].tag   = arch_map_out_to_RAT[i];

      rat_array_next[i].ready = 1'b1;

    end

  end


end




  // ✅ Step 3: Update RAT at the end of the cycle
  always_ff @(posedge clock) begin
    if (reset) begin
      for (int i = 0; i < 32; i++) begin
        rat_array[i].tag   <= i;
        rat_array[i].ready <= 1'b1;
      end
    end else begin
      rat_array <= rat_array_next;  // ✅ Commit all updates in the same cycle
    end
  end

  assign RAT_dbg = rat_array;

  

  

endmodule