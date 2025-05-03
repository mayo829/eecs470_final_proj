module PHT #(
    parameter PHT_INDEX = $clog2(`PHT_SZ)
) (
    input  clock, reset,
    input  [`SCALAR-1:0] wr_en,
    ADDR   [`SCALAR-1:0]  ex_pc_in,  // pc from ex stage 
    input  [`SCALAR-1:0] take_branch,    // taken or no taken from ex stage  
    ADDR   [`SCALAR-1:0]  if_pc_in,    // pc from if stage 
    input  [`SCALAR-1:0] [`BHT_WIDTH-1:0] bht_if_in,  
    input  [`SCALAR-1:0] [`BHT_WIDTH-1:0] bht_ex_in,  
    output logic [`SCALAR-1:0] predict_taken    // predict pc taken or no taken
);
    PHT_STATE  state [`PHT_SZ-1:0] [`H_SZ-1:0];
    PHT_STATE  n_state [`PHT_SZ-1:0] [`H_SZ-1:0];

    logic [PHT_INDEX-1:0] wptr [`SCALAR-1:0];    // write pointer for refreshing the state  
    logic [PHT_INDEX-1:0] rptr [`SCALAR-1:0];    // read pointer for finding the state 
    
    always_comb begin
        for (int i=0;i<`SCALAR;i++) begin
            wptr[i] = ex_pc_in[i][2 +: PHT_INDEX];
            rptr[i] = if_pc_in[i][2 +: PHT_INDEX];
        end
    end
    
    always_comb begin
        for (int j=0;j<`PHT_SZ;j++) begin
            for (int m=0;m<`H_SZ;m++) begin
                n_state[j][m] = state[j][m];
            end
        end
        for (int i = `SCALAR-1; i >= 0 ; i--) begin
            case (state[wptr[i]][bht_ex_in[i]])
                NT_STRONG: n_state[wptr[i]][bht_ex_in[i]] = take_branch[i] ? NT_WEAK : NT_STRONG;
                NT_WEAK:   n_state[wptr[i]][bht_ex_in[i]] = take_branch[i] ? T_STRONG  : NT_STRONG;
                T_WEAK:    n_state[wptr[i]][bht_ex_in[i]] = take_branch[i] ? T_STRONG : NT_STRONG;
                T_STRONG:  n_state[wptr[i]][bht_ex_in[i]] = take_branch[i] ? T_STRONG : T_WEAK;
            endcase
        end
    end

    logic wr_en_flag1;
    assign wr_en_flag1 =| wr_en;
    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int k=0;k<`PHT_SZ;k++) begin
                for (int n=0;n<`H_SZ;n++) begin
                    state[k][n] <=  NT_WEAK;
                end
            end
        end else if (wr_en_flag1) begin
            // Flag to track if any collision has been handled
            logic collision_handled = 0;
            
            // Check for collisions between write enable signals
            for (int i = 0; i < `SCALAR; i++) begin
                if (wr_en[i] && !collision_handled) begin
                    for (int j = i + 1; j < `SCALAR; j++) begin
                        if (wr_en[j] && (wptr[i] == wptr[j])) begin
                            // Handle the collision
                            state[wptr[i]][bht_ex_in[i]] <= n_state[wptr[i]][bht_ex_in[i]];
                            collision_handled = 1;
                            break; // Exit the inner loop once a collision is handled
                        end
                    end
                end
            end

            // If no collision was handled, process all writes independently
            if (!collision_handled) begin
                for (int i = 0; i <`SCALAR; i++) begin
                    if (wr_en[i]) begin
                        state[wptr[i]][bht_ex_in[i]] <= n_state[wptr[i]][bht_ex_in[i]];
                    end
                end
            end
        end
    end

    
    always_comb begin
        for (int n=0;n<`SCALAR;n++) begin
            predict_taken[n] = ((state[rptr[n]][bht_if_in[n]]== T_WEAK) | (state[rptr[n]][bht_if_in[n]]== T_STRONG)) ? 1 : 0;
        end 
    end

endmodule