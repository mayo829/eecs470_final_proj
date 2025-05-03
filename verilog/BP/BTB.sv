/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  BTB.sv                                              //
//                                                                     //
//  Description :  Whenever a branch instruction enters it will        //
//                 be judge by this module first to see if a           //
//                 prediction needs to be done first                   //
//                                                                     //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

module BTB #(
    parameter BTB_INDEX = $clog2(`BTB_SZ)
) (
    input  clock, reset,
    input [`SCALAR-1:0] wr_en,    // write target value in buffer
    ADDR  [`SCALAR-1:0]  ex_pc_in,  // pc from ex stage 
    ADDR  [`SCALAR-1:0]  ex_tg_pc_in,    // target pc from ex stage in 
    ADDR  [`SCALAR-1:0]  if_pc_in,    // pc from if stage    
    output [`SCALAR-1:0] hit,    // 1 if pc hit buffer 
    output  ADDR [`SCALAR-1:0] predict_pc_out
);
    logic [`TAG_SZ+`VAL_SZ-1:0] mem [`BTB_SZ-1:0];
    logic [`BTB_SZ-1:0] valid;    // 1 if address store valid target PC
   

    // synopsys sync_set_reset "reset"
    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < `BTB_SZ; i++) begin
                mem [i] <=  0;
            end
            valid <=  0;
        end
        else begin
           // Flag to track if any collision has been handled
            logic collision_handled = 0;
            // Check for any collisions between streams
            for (int i = 0; i < `SCALAR; i++) begin
                if (wr_en[i] && !collision_handled) begin
                    for (int j = i + 1; j < `SCALAR; j++) begin
                        if (wr_en[j] && (ex_pc_in[i][2 +: BTB_INDEX] == ex_pc_in[j][2 +: BTB_INDEX])) begin
                            // Handle the collision
                            mem[ex_pc_in[i][2 +: BTB_INDEX]] <= {ex_pc_in[i][BTB_INDEX+2 +: `TAG_SZ], ex_tg_pc_in[i][2 +: `VAL_SZ]};
                            valid[ex_pc_in[i][2 +: BTB_INDEX]] <= 1'b1;
                            collision_handled = 1;
                            break; // Exit the inner loop once a collision is handled
                        end
                    end
                end
            end

            // If no collision was handled, process all writes independently
            if (!collision_handled) begin
                for (int i = 0; i < `SCALAR; i++) begin
                    if (wr_en[i]) begin
                        mem[ex_pc_in[i][2 +: BTB_INDEX]] <= 
                            {ex_pc_in[i][BTB_INDEX+2 +: `TAG_SZ], ex_tg_pc_in[i][2 +: `VAL_SZ]};
                        valid[ex_pc_in[i][2 +: BTB_INDEX]] <= 1'b1;
                    end
                end
            end
        end
    end

    genvar j,k;
    for (j = 0; j < `SCALAR; j++) begin
    assign   predict_pc_out[j] = 
            {if_pc_in[j][32-1:`VAL_SZ+2],
            mem[if_pc_in[j][BTB_INDEX+1-:BTB_INDEX]][`VAL_SZ-1:0],
            {2{1'b0}}};    
    end



    for (k = 0; k < `SCALAR; k++) begin
    assign  hit[k] = 
            (if_pc_in[k][BTB_INDEX+2 +: `TAG_SZ] == 
            mem[if_pc_in[k][BTB_INDEX+1-:BTB_INDEX]][`VAL_SZ +: `TAG_SZ])&
            valid[if_pc_in[k][BTB_INDEX+1-:BTB_INDEX]];
    end

endmodule