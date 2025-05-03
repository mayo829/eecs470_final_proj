

`include "sys_defs.svh"

module BHT #(
    parameter BHT_INDEX = $clog2(`BHT_SZ)
)(
    input  clock, reset, 
    // sinput squash_en,
    input  [`SCALAR-1:0] wr_en,
    input  ADDR [`SCALAR-1:0]  ex_pc_in,  // pc from ex stage 
    input  [`SCALAR-1:0] take_branch,    // taken or no taken from ex stage  
    input  ADDR [`SCALAR-1:0] if_pc_in,    // pc from if stage    
    output [`SCALAR-1:0] [`BHT_WIDTH-1:0] bht_if_out,    // output the value stored in BHT to PHT
    output [`SCALAR-1:0] [`BHT_WIDTH-1:0] bht_ex_out    // output the value stored in BHT to PHT
);
    logic [`SCALAR-1:0] bht [`BHT_SZ-1:0];

    logic [BHT_INDEX-1:0] wptr [`SCALAR-1:0];    // write pointer for refreshing the state  
    logic [BHT_INDEX-1:0] rptr [`SCALAR-1:0];    // read pointer for finding the state 
    // calculate the address
    always_comb begin
        for (int i = 0; i < `SCALAR; i++) begin
            wptr[i] = ex_pc_in[i][2 +: BHT_INDEX];
            rptr[i] = if_pc_in[i][2 +: BHT_INDEX];
        end
    end

    logic wr_en_flag1;
    assign wr_en_flag1 = |wr_en;
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < `SCALAR; i++) begin
                bht[i] <= 0;
            end
        end 
        // else if (squash_en) begin
        //     for (int i=0;i<`BHT_SZ;i++) begin
        //         bht[i] <=  0;
        //     end
        // end
        else if (wr_en_flag1) begin
            // Flag to track if any collision has been handled
            logic collision_handled = 0;

            // Check for collisions between write enable signals
            for (int i = 0; i < `SCALAR; i++) begin
                if (wr_en[i] && !collision_handled) begin
                    for (int j = i + 1; j < `SCALAR; j++) begin
                        if (wr_en[j] && (wptr[i] == wptr[j])) begin
                            // Handle the collision: prioritize entry from way i
                            bht[wptr[i]] <= {bht[wptr[i]][`BHT_WIDTH-2:0], take_branch[i]};
                            collision_handled = 1; // Mark collision as handled
                            break; // Exit the inner loop once a collision is handled
                        end
                    end
                end
            end

            // If no collision was handled, process all writes independently
            if (!collision_handled) begin
                for (int i = 0; i < `SCALAR; i++) begin
                    if (wr_en[i]) begin
                        // Update the BHT entry based on the scalar way
                        bht[wptr[i]] <= {bht[wptr[i]][`BHT_WIDTH-2:0], take_branch[i]};
                    end
                end
            end
        end
    end 

    genvar j;
    for (j=0;j<`SCALAR;j++) begin
        assign bht_if_out[j] = bht[rptr[j]];
        assign bht_ex_out[j] = bht[wptr[j]];
    end

endmodule