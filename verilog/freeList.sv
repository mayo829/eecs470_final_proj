`include "sys_defs.svh"

module freeList (
    input                             clock,
    input                             reset,
    input  RETIRE_TO_FREELIST_PACKET  freeList_in,
    input  logic [1:0]                dispatch_req,
    input  logic                      mispredict,

    output FREELIST_PACKET_OUT        freeList_out,
    output logic [`ROB_PTR_WIDTH:0]   total_num_free,

    output logic [`ROB_SZ-1:0][`PR_WIDTH-1:0] freeList_dbg,
    output logic [`ROB_PTR_WIDTH-1:0]         freeList_head_dbg,
    output logic [`ROB_PTR_WIDTH-1:0]         freeList_tail_dbg
);

logic [`ROB_SZ-1:0][`PR_WIDTH-1:0]  freeList, next_freeList, temp_freeList;
logic [`ROB_PTR_WIDTH:0]            num_free, next_num_free, temp_num_free;
logic [`ROB_PTR_WIDTH-1:0]          head, next_head, tail, next_tail;
logic [1:0]                         num_dispatch_req, dispatch_req_after_retire;

// assign freeList_dbg = next_freeList;
// assign head_dbg = next_head;
// assign tail_dbg = next_tail;





// ----------------------------------- Retire ------------------------------------ //
always_comb begin
    next_tail       = tail;
    temp_freeList   = freeList;
    temp_num_free   = num_free;

    case(freeList_in.retired_req)
        2'b00: begin end
        2'b01: begin
            temp_freeList[tail]     = freeList_in.retired_tags[0];
            temp_num_free           = num_free + 1;
            next_tail               = (tail + 1) % `ROB_SZ;
        end
        2'b10: begin
            temp_freeList[tail]     = freeList_in.retired_tags[1];
            temp_num_free           = num_free + 1;
            next_tail               = (tail + 1) % `ROB_SZ;
        end
        2'b11: begin
            temp_freeList[tail]             = freeList_in.retired_tags[0];
            temp_freeList[(tail + 1) % `ROB_SZ] = freeList_in.retired_tags[1];
            temp_num_free                   = num_free + 2;
            next_tail                       = (tail + 2) % `ROB_SZ;
        end
    endcase
end

// ---------------------------------- Dispatch ----------------------------------- //
always_comb begin
    freeList_out.free_tags = 0;
    freeList_out.valid     = 0;
    next_head              = head;
    next_freeList          = temp_freeList;
    next_num_free          = temp_num_free;

    case(dispatch_req_after_retire)
        2'b00: begin end
        2'b01: begin
            if (temp_num_free >= 1) begin
                freeList_out.valid            = 2'b01;
                freeList_out.free_tags[0]     = temp_freeList[head];
                next_head                     = (head + 1) % `ROB_SZ;
                next_num_free                 = (temp_num_free - 1);
            end
        end
        2'b10: begin
            if (temp_num_free >= 1) begin
                freeList_out.valid            = 2'b10;
                freeList_out.free_tags[1]     = temp_freeList[head];
                next_head                     = (head + 1) % `ROB_SZ;
                next_num_free                 = (temp_num_free - 1);
            end
        end
        2'b11: begin
            if (temp_num_free >= 2) begin
                freeList_out.valid            = 2'b11;
                freeList_out.free_tags[0]     = temp_freeList[head];
                freeList_out.free_tags[1]     = temp_freeList[(head + 1) % `ROB_SZ];
                next_head                     = (head + 2) % `ROB_SZ;
                next_num_free                 = (temp_num_free - 2);
            end
        end
    endcase
end

assign total_num_free = num_free;

// --------------------------- Sequential State Update --------------------------- //
always_ff @(posedge clock) begin
    if (reset) begin
        num_free <= `ROB_SZ;
        head     <= 0;
        tail     <= 0;
        for (int i = 0; i < `ROB_SZ; i = i + 1) begin
            freeList[i] <= i + 6'b100000;
        end
    end else if (mispredict) begin
        head <= head;
        tail <= head;
        freeList <= temp_freeList; // freelist after retirement
        num_free <= `ROB_SZ;
    end else begin
        num_free <= next_num_free;
        freeList <= next_freeList;
        head     <= next_head;
        tail     <= next_tail;
    end
end

// ------------------------ Dynamic Dispatch Calculation ------------------------- //
always_comb begin
    dispatch_req_after_retire = dispatch_req;

    if      (dispatch_req == 2'b00) num_dispatch_req = 0;
    else if (dispatch_req == 2'b01) num_dispatch_req = 1;
    else if (dispatch_req == 2'b10) num_dispatch_req = 1;
    else                            num_dispatch_req = 2;

    if (temp_num_free < num_dispatch_req) begin
        if (temp_num_free >= 1) dispatch_req_after_retire = 2'b01;
        else                    dispatch_req_after_retire = 2'b00;
    end
end

//message to luke if looking here, I changed it to these debugs for the testing so we can see what it is in the start of cycle
assign freeList_head_dbg = head;
assign freeList_tail_dbg = tail;
assign freeList_dbg = freeList;

endmodule