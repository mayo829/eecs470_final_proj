module bp2b(
  input logic clock, reset,
  
  // 0: Not Taken, 1: Taken
  input COMMIT_PACKET [`N-1:0] committed_inst,

  // 0: Not Taken, 1: Taken
  output logic predicted_branch
);


  // Standard sequential state encoding
  typedef enum logic [1:0] {
    STRONGLY_NT = 2'b00,
    WEAKLY_NT   = 2'b01,
    WEAKLY_T    = 2'b10,
    STRONGLY_T  = 2'b11
  } state_t;

  state_t predicted_state, next_state;

  // Output logic - predict taken for states 2 and 3
  assign predicted_branch = predicted_state[1];

  // State registers
  always_ff @(posedge clock) begin
    if (reset) begin
      // Initialize in a weakly biased state
      predicted_state <= WEAKLY_NT;
    end
    else begin
      predicted_state <= next_state;
    end
  end



    assign take = committed_inst[0].if_take_branch || committed_inst[1].if_take_branch; // If we take the "if_take_branch" from Cpacket, do we have to consider which one of the two, or just one, becuase we have one branch functional unit? 

  // Next state logic - standard 2-bit saturating counter
  always_comb begin
    // Default to staying in current state
    next_state = predicted_state;

    if (committed_inst[0].is_branch && committed_inst[0].valid || committed_inst[1].is_branch && committed_inst[1].valid
      // Only update if the branch is committing, then we can use the information from misprediction (execute) to update the BP.
    ) begin
      
      if (take) begin // i think this is the raw input of if the branch was taken or not.

        // Branch was taken
        next_state = (predicted_state == STRONGLY_T) ? STRONGLY_T : state_t'(predicted_state + 1'b1);
      end
      
      else begin
        // Branch was not taken
        next_state = (predicted_state == STRONGLY_NT) ? STRONGLY_NT : state_t'(predicted_state - 1'b1);
      end
    end
  end

endmodule