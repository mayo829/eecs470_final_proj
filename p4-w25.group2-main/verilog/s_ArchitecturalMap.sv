// MISSING, REQUIRED FOR PRECISE STATE AND ROLLING BACK ON BRANCH MIDPREDICT AND EXCEPTIONS

`include "sys_defs.svh"

// CODE IS MY OWN, GPT ONLY COMMENTED ON FUNCTIONALITY AND FLOW

module s_ArchitecturalMap (
  input  logic             clock,
  input  logic             reset,

  // Inputs from the ROB (committed dest registers)
  input  logic [1:0]       commit_valid,     // One bit per instruction (left/right)
  input  REG_IDX [1:0]     commit_arch_reg,  // Architectural register to commit
  input  logic [1:0][`PR_WIDTH-1:0]  commit_phys_reg,  // Physical register to assign

  // Output: the current architectural mapping (for rollback restore)
  output logic [31:0][`PR_WIDTH-1:0] arch_map_out,

  output logic [31:0][`PR_WIDTH-1:0] arch_map_out_to_RAT
);

  // Internal architectural map
  logic [31:0][`PR_WIDTH-1:0] arch_map;

  logic [31:0][`PR_WIDTH-1:0] arch_map_next;

    always_comb begin
      arch_map_next = arch_map;
      for (int i = 0; i < 2; i++) begin
        if (commit_valid[i]) begin
          arch_map_next[commit_arch_reg[i]] = commit_phys_reg[i];
        end
      end
    end

  // Commit logic
  always_ff @(posedge clock) begin
    if (reset) begin
      for (int i = 0; i < 32; i++) begin
        arch_map[i] <= i;  // Identity map: ARx → PRx
      end
    end else begin
        arch_map <= arch_map_next;
    end
  end

  assign arch_map_out = arch_map;

  assign arch_map_out_to_RAT = arch_map_next;

endmodule
