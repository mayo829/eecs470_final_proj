// AS THE COMPLETE
// I NEED TO BROADCAST TO CDB, WHAT IS ALL THAT NONSENSE IM SEEING ABOUT STALLING A CDB? 
// I ALSO NEED TO BE ABLE TO TELL EXECUTE THAT IF THEY ARE ATTEMPTING TO COMPLETE MORE THAN 2 INSTRUCTIONS THEN I GOTTA HELP THEM
// PICK 2 OF THE FUNCTIONAL UNITS AND ESSENTIALLY JUST COMMUNICATE TO THE ONE (OR MORE) FUNC UNITS THAT NEED TO STALL AND TELL THEM
// TO STALL

// I NEED TO WRITE TO PRF SO I WILL NEED T AND DATA (AND VALID AND ALL THAT OTHER NONSENSE)

// I WILL ALSO NEED TO SEND THE CDB TO THE RS AND THE RS WILL HAVE TO DEAL WITH CAMMING ITSELF

// THE SAME THING IS THE CASE FOR ROB BUT I JUST NEED TO HANDLE CAMMING THE ROB BUT ONLY TO FIND OUT WHICH
// ROB ENTRY IS ACTUALLY GETTING COMPLETED AND MAKE SURE IT'S MARKED AS COMPLETE,
`include "sys_defs.svh"

module stage_complete (
    input  logic                    clock,
    input  logic                    reset,
    input  COMPLETE_PACKET  [4:0]   complete_in,
    input  logic            [4:0]   functional_req,
    output logic            [4:0]   allowed_to_go,
    output CDB_ENTRY_PACKET [1:0]   complete_cdb_out
);


logic [1:0] grant_idx_0, grant_idx_1;
logic [3:0] grant_mask;

rotating_priority_selector_4to2 u_selector (
    .request       ({functional_req[3], functional_req[2],
                     functional_req[1], functional_req[0]}),
    .clock           (clock),
    .reset         (reset),
    .grant0_idx    (grant_idx_0),
    .grant1_idx    (grant_idx_1),
    .grant_mask    (grant_mask)
);

logic [1:0] total_grants;
logic [1:0] out_idx;

always_comb begin
    allowed_to_go = 5'b00000;
    total_grants = 2'b00;

    if (functional_req[4]) begin
        allowed_to_go[4] = 1'b1;
        total_grants = total_grants + 1'b1;
    end

    for (int i = 0; i < 4; i++) begin
        if (functional_req[i] && grant_mask[i] && (total_grants < 2)) begin
            allowed_to_go[i] = 1'b1;
            total_grants = total_grants + 1'b1;
        end else begin
            allowed_to_go[i] = 1'b0;
        end
    end
end


always_comb begin
    complete_cdb_out = '{default: '0};
    out_idx = 2'b00;

    if (allowed_to_go[4]) begin
        complete_cdb_out[out_idx].valid     = complete_in[4].valid;
        complete_cdb_out[out_idx].tag       = complete_in[4].dest_reg_idx;
        complete_cdb_out[out_idx].data      = complete_in[4].result;
        complete_cdb_out[out_idx].rob_ptr   = complete_in[4].rob_ptr;

        if (complete_in[4].is_branch || (!complete_in[4].is_branch && complete_in[4].if_take_branch)) begin
            complete_cdb_out[out_idx].if_take_branch = complete_in[4].if_take_branch;
            complete_cdb_out[out_idx].target_pc      = complete_in[4].target_pc;
        end else begin
            complete_cdb_out[out_idx].if_take_branch = 1'b0;
            complete_cdb_out[out_idx].target_pc      = '0;
        end

        out_idx = out_idx + 1;
    end

    if (grant_mask[grant_idx_0] && allowed_to_go[grant_idx_0] && out_idx < 2) begin
        complete_cdb_out[out_idx].valid     = complete_in[grant_idx_0].valid;
        complete_cdb_out[out_idx].tag       = complete_in[grant_idx_0].dest_reg_idx;
        complete_cdb_out[out_idx].data      = complete_in[grant_idx_0].result;
        complete_cdb_out[out_idx].rob_ptr   = complete_in[grant_idx_0].rob_ptr;

        if (complete_in[grant_idx_0].is_branch || (!complete_in[grant_idx_0].is_branch && complete_in[grant_idx_0].if_take_branch)) begin
            complete_cdb_out[out_idx].if_take_branch = complete_in[grant_idx_0].if_take_branch;
            complete_cdb_out[out_idx].target_pc      = complete_in[grant_idx_0].target_pc;
        end else begin
            complete_cdb_out[out_idx].if_take_branch = 1'b0;
            complete_cdb_out[out_idx].target_pc      = '0;
        end

        out_idx = out_idx + 1;
    end

    if (grant_mask[grant_idx_1] && grant_idx_1 != grant_idx_0 && allowed_to_go[grant_idx_1] && out_idx < 2) begin
        complete_cdb_out[out_idx].valid     = complete_in[grant_idx_1].valid;
        complete_cdb_out[out_idx].tag       = complete_in[grant_idx_1].dest_reg_idx;
        complete_cdb_out[out_idx].data      = complete_in[grant_idx_1].result;
        complete_cdb_out[out_idx].rob_ptr   = complete_in[grant_idx_1].rob_ptr;

        if (complete_in[grant_idx_1].is_branch || (!complete_in[grant_idx_1].is_branch && complete_in[grant_idx_1].if_take_branch)) begin
            complete_cdb_out[out_idx].if_take_branch = complete_in[grant_idx_1].if_take_branch;
            complete_cdb_out[out_idx].target_pc      = complete_in[grant_idx_1].target_pc;
        end else begin
            complete_cdb_out[out_idx].if_take_branch = 1'b0;
            complete_cdb_out[out_idx].target_pc      = '0;
        end
    end
end



endmodule


module rotating_priority_selector_4to2 (
    input  logic [3:0] request,       // valid bits from complete_in
    input  logic       clock,
    input  logic       reset,
    output logic [1:0] grant0_idx,   // index of 1st chosen instruction
    output logic [1:0] grant1_idx,   // index of 2nd chosen instruction
    output logic [3:0] grant_mask    // 1-hot: who got selected
);

    logic [1:0] count;

    // Round-robin base position counter
    always_ff @(posedge clock) begin
        if (reset)
            count <= 2'b00;
        else
            count <= count + 2'b01;
    end

    always_comb begin
        grant_mask = 4'b0000;
        grant0_idx = 2'd0;
        grant1_idx = 2'd0;

        case (count)  
            2'd0: begin
                if (request[0]) begin
                    grant_mask[0] = 1;
                    grant0_idx = 2'd0;
                    if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end
                end else if (request[1]) begin
                    grant_mask[1] = 1;
                    grant0_idx = 2'd1;
                    if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end
                end else if (request[2]) begin
                    grant_mask[2] = 1;
                    grant0_idx = 2'd2;
                    if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end
                end else if (request[3]) begin
                    grant_mask[3] = 1;
                    grant0_idx = 2'd3;
                    if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end
                end
            end

            2'd1: begin
                if (request[1]) begin
                    grant_mask[1] = 1;
                    grant0_idx = 2'd1;
                    if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end
                end else if (request[2]) begin
                    grant_mask[2] = 1;
                    grant0_idx = 2'd2;
                    if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end
                end else if (request[3]) begin
                    grant_mask[3] = 1;
                    grant0_idx = 2'd3;
                    if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end
                end else if (request[0]) begin
                    grant_mask[0] = 1;
                    grant0_idx = 2'd0;
                    if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end
                end
            end

            2'd2: begin
                if (request[2]) begin
                    grant_mask[2] = 1;
                    grant0_idx = 2'd2;
                    if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end
                end else if (request[3]) begin
                    grant_mask[3] = 1;
                    grant0_idx = 2'd3;
                    if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end
                end else if (request[0]) begin
                    grant_mask[0] = 1;
                    grant0_idx = 2'd0;
                    if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end
                end else if (request[1]) begin
                    grant_mask[1] = 1;
                    grant0_idx = 2'd1;
                    if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end
                end
            end

            2'd3: begin
                if (request[3]) begin
                    grant_mask[3] = 1;
                    grant0_idx = 2'd3;
                    if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end
                end else if (request[0]) begin
                    grant_mask[0] = 1;
                    grant0_idx = 2'd0;
                    if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end else if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end
                end else if (request[1]) begin
                    grant_mask[1] = 1;
                    grant0_idx = 2'd1;
                    if (request[2]) begin
                        grant_mask[2] = 1;
                        grant1_idx = 2'd2;
                    end else if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end
                end else if (request[2]) begin
                    grant_mask[2] = 1;
                    grant0_idx = 2'd2;
                    if (request[3]) begin
                        grant_mask[3] = 1;
                        grant1_idx = 2'd3;
                    end else if (request[0]) begin
                        grant_mask[0] = 1;
                        grant1_idx = 2'd0;
                    end else if (request[1]) begin
                        grant_mask[1] = 1;
                        grant1_idx = 2'd1;
                    end
                end
            end
        endcase
    end
endmodule



// `include "sys_defs.svh"

// module stage_complete (
//     input  logic                  clock,
//     input  logic                  reset,
//     input  COMPLETE_PACKET [4:0] complete_in,
//     input  logic        [4:0]    functional_req,
//     output logic        [4:0]    allowed_to_go,
//     output logic        [4:0]    stall_fus,
//     output CDB_ENTRY_PACKET [1:0] complete_cdb_out
// );

// logic [2:0] grant_idx_0, grant_idx_1;
// logic [4:0] grant_mask;

// rotating_priority_selector_5to2 u_selector (
//     .request       (functional_req),
//     .clock         (clock),
//     .reset         (reset),
//     .grant0_idx    (grant_idx_0),
//     .grant1_idx    (grant_idx_1),
//     .grant_mask    (grant_mask)
// );

// always_comb begin
//     allowed_to_go = 5'b00000;
//     for (int i = 0; i < 5; i++) begin
//         allowed_to_go[i] = functional_req[i] && grant_mask[i];
//     end

//     stall_fus = functional_req & ~allowed_to_go;
// end

// always_comb begin
//     complete_cdb_out = '{default: '0};

//     if (grant_mask[grant_idx_0]) begin
//         complete_cdb_out[0].valid = 1;
//         complete_cdb_out[0].tag   = complete_in[grant_idx_0].dest_reg_idx;
//         complete_cdb_out[0].data  = complete_in[grant_idx_0].result;

//         if (complete_in[grant_idx_0].is_branch) begin
//             complete_cdb_out[0].if_take_branch = complete_in[grant_idx_0].if_take_branch;
//             complete_cdb_out[0].target_pc      = complete_in[grant_idx_0].target_pc;
//         end
//     end

//     if (grant_mask[grant_idx_1] && (grant_idx_1 != grant_idx_0)) begin
//         complete_cdb_out[1].valid = 1;
//         complete_cdb_out[1].tag   = complete_in[grant_idx_1].dest_reg_idx;
//         complete_cdb_out[1].data  = complete_in[grant_idx_1].result;

//         if (complete_in[grant_idx_1].is_branch) begin
//             complete_cdb_out[1].if_take_branch = complete_in[grant_idx_1].if_take_branch;
//             complete_cdb_out[1].target_pc      = complete_in[grant_idx_1].target_pc;
//         end
//     end
// end

// endmodule


// module rotating_priority_selector_5to2 (
//     input  logic [4:0] request,
//     input  logic       clock,
//     input  logic       reset,
//     output logic [2:0] grant0_idx,
//     output logic [2:0] grant1_idx,
//     output logic [4:0] grant_mask
// );

// logic [1:0] rr_ptr;

// always_ff @(posedge clock) begin
//     if (reset)
//         rr_ptr <= 2'b00;
//     else
//         rr_ptr <= rr_ptr + 2'b01;
// end

// function automatic logic [1:0] find_next(input logic [3:0] req, input logic [1:0] start);
//     for (int i = 0; i < 4; i++) begin
//         int idx = (start + i) % 4;
//         if (req[idx]) return idx[1:0];
//     end
//     return 2'b11; // fallback, invalid
// endfunction

// logic [3:0] req_4to0;

// logic [1:0] idx;

// logic [1:0] second;

// always_comb begin
//     grant_mask = 5'b00000;
//     grant0_idx = 3'd0;
//     grant1_idx = 3'd0;

//     req_4to0 = request[3:0];

//     if (request[4]) begin
//         // Priority: index 4 always gets one slot
//         grant_mask[4] = 1;
//         grant0_idx = 3'd4;

//         // find 1 from 0–3
//         idx = find_next(req_4to0, rr_ptr);
//         if (req_4to0[idx]) begin
//             grant_mask[idx] = 1;
//             grant1_idx = idx;
//         end else begin
//             grant1_idx = grant0_idx; // only one valid grant
//         end
//     end else begin
//         // select 2 from 0–3 in round-robin
//         logic [1:0] first = find_next(req_4to0, rr_ptr);
//         logic [3:0] masked_req = req_4to0;
//         masked_req[first] = 0;

//         second = find_next(masked_req, first + 1);

//         if (req_4to0[first]) begin
//             grant_mask[first] = 1;
//             grant0_idx = first;
//         end

//         if (req_4to0[second]) begin
//             grant_mask[second] = 1;
//             grant1_idx = second;
//         end else begin
//             grant1_idx = grant0_idx;
//         end
//     end
// end

// endmodule
