`include "sys_defs.svh"
`include "ISA.svh"

module store_pipeline (
    input   clock,
    input   reset,

    input   ISSUE_PACKET [`N-1:0] IssuedStoreInstructions,

    output  COMPLETE_SQ_PACKET [`N-1:0] SQ_in_packet
);
    


ISSUE_PACKET        [`N-1:0] IssuedStoreInstructions_issueExecute_REG;


// place a register here to hold the 2 issue packets

always_ff @(posedge clock) begin
    if(reset) begin 
        IssuedStoreInstructions_issueExecute_REG <= '{default: '0};
    end else begin
        IssuedStoreInstructions_issueExecute_REG <= IssuedStoreInstructions;
    end 
end


COMPLETE_SQ_PACKET  [`N-1:0] SQ_in_packet_ExecuteComplete;


store_ALU SALU (
    .IssuedStoreInstructions_issueExecute_REG(IssuedStoreInstructions_issueExecute_REG),
	.SQ_in_packet_ExecuteComplete(SQ_in_packet_ExecuteComplete)
);

COMPLETE_SQ_PACKET [`N-1:0] SQ_in_packet_ExecuteComplete_REG;

always_ff @(posedge clock) begin
    if(reset) begin 
        SQ_in_packet_ExecuteComplete_REG <= '{default: '0};
    end else begin
        SQ_in_packet_ExecuteComplete_REG <= SQ_in_packet_ExecuteComplete;
    end 
end

assign SQ_in_packet = SQ_in_packet_ExecuteComplete_REG;







// send the two issue packets through the two store units


// after they come out of the store units, send them to the store queue, just note that the store queue is what handles writing to the cache

// you only can write one thing from the store queue (retire) to the actual Dcache

// So make sure you do read only at the top of the SQ and use it to arbitrate, if it wins the arbitration, then the 





endmodule

module store_ALU (
    input  ISSUE_PACKET         [`N-1:0] IssuedStoreInstructions_issueExecute_REG,
	output COMPLETE_SQ_PACKET   [`N-1:0] SQ_in_packet_ExecuteComplete
);


    always_comb begin 
        for(int i = 0; i < `N; i++) begin 
            SQ_in_packet_ExecuteComplete[i].address  = IssuedStoreInstructions_issueExecute_REG[i].r1_value + `RV32_signext_Simm(IssuedStoreInstructions_issueExecute_REG[i].inst);
            SQ_in_packet_ExecuteComplete[i].sq_pos   = IssuedStoreInstructions_issueExecute_REG[i].sq_pos;
            SQ_in_packet_ExecuteComplete[i].valid    = IssuedStoreInstructions_issueExecute_REG[i].valid;
            SQ_in_packet_ExecuteComplete[i].mem_size = IssuedStoreInstructions_issueExecute_REG[i].mem_size;
            SQ_in_packet_ExecuteComplete[i].value    = IssuedStoreInstructions_issueExecute_REG[i].r2_value;
            SQ_in_packet_ExecuteComplete[i].rob_ptr  = IssuedStoreInstructions_issueExecute_REG[i].rob_ptr;
        end 
    end 
	


endmodule


