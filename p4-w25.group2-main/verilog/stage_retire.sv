//SOME RETIRE LOGIC IS IN THE ROB, YOU MAY MODIFY IT AND THIS HERE NEEDS TO BE REPLACED
//ACTUALLY PROB CAN LEAVE IT THERE, JUST NEED TO CLEAN UP ROB
//DOESN'T HANDLE BRANCH RECOVERY OR PRECISE STATE, also will require rob modification
`include "sys_defs.svh"


module stage_retire (


    //FROM ROB, This will help calculate how many instructions to dispatch
    input   logic                   [`ROB_PTR_WIDTH:0]      NumROBFreeEntries,
    input   logic                   [`ROB_PTR_WIDTH:0]      total_num_free,
    input   ROB_RETIRE_PACKET       [1:0]                   RobEntriesToRetire,
    


    output  RETIRE_ARCHMAP_PACKET   [1:0]                   retireOutArchmapIn,
    output  RETIRE_TO_FREELIST_PACKET                       RetireToFreeList,
    output  logic                   [`ROB_PTR_WIDTH:0]      NumROBFreeEntriesAfterRetire,
    output  logic                   [`ROB_PTR_WIDTH:0]      NumFreeListFreeEntriesAfterRetire,
    // output  logic                                        halt
    output  COMMIT_PACKET [`N-1:0]                          committed_insts,

    output  ADDR                                            correct_pc,
    input   DATA          [1:0]                             testingTDATA
);


always_comb begin
    NumROBFreeEntriesAfterRetire    = 'b0;
    NumFreeListFreeEntriesAfterRetire   = total_num_free;
    RetireToFreeList                = '{default: '0};
    retireOutArchmapIn[0]           = '{default: '0};
    retireOutArchmapIn[1]           = '{default: '0};
    committed_insts                 = '{default: '0};
    // halt                            = 'b0;
    case ({RobEntriesToRetire[1].valid,RobEntriesToRetire[0].valid})
        2'b00: begin 
            RetireToFreeList.retired_req        = 2'b00;
            NumROBFreeEntriesAfterRetire        = NumROBFreeEntries + 2'd0;
            NumFreeListFreeEntriesAfterRetire   = total_num_free + 2'd0;
            // halt                         = 1'b0;     
        end

        2'b01: begin
            if(RobEntriesToRetire[0].Told == '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free;
            RetireToFreeList.retired_req            = 2'b00;
            end else begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free + 2'd1;
            RetireToFreeList.retired_req            = 2'b01;
            end
            NumROBFreeEntriesAfterRetire            = NumROBFreeEntries + 2'd1;
            RetireToFreeList.retired_tags[0]        = RobEntriesToRetire[0].Told;
            retireOutArchmapIn[0].commit_valid      = RobEntriesToRetire[0].valid;
            retireOutArchmapIn[0].commit_arch_reg   = RobEntriesToRetire[0].dest_reg;
            retireOutArchmapIn[0].commit_phys_reg   = RobEntriesToRetire[0].T;
            committed_insts[0].PC                   = RobEntriesToRetire[0].PC;
            committed_insts[0].NPC                  = RobEntriesToRetire[0].NPC;
            committed_insts[0].reg_idx              = RobEntriesToRetire[0].dest_reg;
            committed_insts[0].data                 = testingTDATA[0];
            committed_insts[0].halt                 = RobEntriesToRetire[0].halt;
            committed_insts[0].illegal              = 1'b0;
            committed_insts[0].valid                = RobEntriesToRetire[0].valid;
            committed_insts[0].if_take_branch       = RobEntriesToRetire[0].if_take_branch;
            committed_insts[0].target_pc            = RobEntriesToRetire[0].target_pc;
            committed_insts[0].is_branch            = RobEntriesToRetire[0].is_branch;
            committed_insts[0].SPEC_PC              = RobEntriesToRetire[0].SPEC_PC; 
            committed_insts[0].inst                 = RobEntriesToRetire[0].inst; 
            //halt                                    = 1'b0;      
        end

        2'b10: begin
            if(RobEntriesToRetire[1].Told == '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free;
            RetireToFreeList.retired_req            = 2'b00;
            end else begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free + 2'd1;
            RetireToFreeList.retired_req            = 2'b10;
            end
            NumROBFreeEntriesAfterRetire            = NumROBFreeEntries + 2'd1;
            RetireToFreeList.retired_tags[1]        = RobEntriesToRetire[1].Told;
            retireOutArchmapIn[1].commit_valid      = RobEntriesToRetire[1].valid;
            retireOutArchmapIn[1].commit_arch_reg   = RobEntriesToRetire[1].dest_reg;
            retireOutArchmapIn[1].commit_phys_reg   = RobEntriesToRetire[1].T;
            committed_insts[1].PC                   = RobEntriesToRetire[1].PC;
            committed_insts[1].NPC                  = RobEntriesToRetire[1].NPC;
            committed_insts[1].reg_idx              = RobEntriesToRetire[1].dest_reg;
            committed_insts[1].data                 = testingTDATA[1];
            committed_insts[1].halt                 = RobEntriesToRetire[1].halt;
            committed_insts[1].illegal              = 1'b0;
            committed_insts[1].valid                = RobEntriesToRetire[1].valid;
            committed_insts[1].if_take_branch       = RobEntriesToRetire[1].if_take_branch;
            committed_insts[1].target_pc            = RobEntriesToRetire[1].target_pc;
            committed_insts[1].is_branch            = RobEntriesToRetire[1].is_branch;
            committed_insts[1].SPEC_PC              = RobEntriesToRetire[1].SPEC_PC;
            committed_insts[1].inst                 = RobEntriesToRetire[1].inst; 
            //halt                                    = 1'b0;      
        end

        2'b11: begin
            if(RobEntriesToRetire[0].Told != '0 && RobEntriesToRetire[1].Told != '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free + 2'd2;
            RetireToFreeList.retired_req            = 2'b11;
            end else if (RobEntriesToRetire[0].Told != '0 && RobEntriesToRetire[1].Told == '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free + 2'd1;
            RetireToFreeList.retired_req            = 2'b01;
            end else if (RobEntriesToRetire[0].Told == '0 && RobEntriesToRetire[1].Told != '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free + 2'd1;
            RetireToFreeList.retired_req            = 2'b10;
            end else if (RobEntriesToRetire[0].Told == '0 && RobEntriesToRetire[1].Told == '0) begin
            NumFreeListFreeEntriesAfterRetire       = total_num_free;
            RetireToFreeList.retired_req            = 2'b00;
            end


            NumROBFreeEntriesAfterRetire            = NumROBFreeEntries + 2'd2;
            RetireToFreeList.retired_tags[0]        = RobEntriesToRetire[0].Told; 
            RetireToFreeList.retired_tags[1]        = RobEntriesToRetire[1].Told;
            retireOutArchmapIn[0].commit_valid      = RobEntriesToRetire[0].valid;
            retireOutArchmapIn[0].commit_arch_reg   = RobEntriesToRetire[0].dest_reg;
            retireOutArchmapIn[0].commit_phys_reg   = RobEntriesToRetire[0].T;
            retireOutArchmapIn[1].commit_valid      = RobEntriesToRetire[1].valid;
            retireOutArchmapIn[1].commit_arch_reg   = RobEntriesToRetire[1].dest_reg;
            retireOutArchmapIn[1].commit_phys_reg   = RobEntriesToRetire[1].T;
            committed_insts[0].PC                   = RobEntriesToRetire[0].PC;
            committed_insts[0].NPC                  = RobEntriesToRetire[0].NPC;
            committed_insts[0].reg_idx              = RobEntriesToRetire[0].dest_reg;
            committed_insts[0].data                 = testingTDATA[0];
            committed_insts[0].halt                 = RobEntriesToRetire[0].halt;
            committed_insts[0].illegal              = 1'b0;
            committed_insts[0].valid                = RobEntriesToRetire[0].valid;
            committed_insts[0].is_branch            = RobEntriesToRetire[0].is_branch;
            committed_insts[1].PC                   = RobEntriesToRetire[1].PC;
            committed_insts[1].NPC                  = RobEntriesToRetire[1].NPC;
            committed_insts[1].reg_idx              = RobEntriesToRetire[1].dest_reg;
            committed_insts[1].data                 = testingTDATA[1];
            committed_insts[1].halt                 = RobEntriesToRetire[1].halt;
            committed_insts[1].illegal              = 1'b0;
            committed_insts[1].valid                = RobEntriesToRetire[1].valid;
            committed_insts[0].if_take_branch       = RobEntriesToRetire[0].if_take_branch;
            committed_insts[0].target_pc            = RobEntriesToRetire[0].target_pc;
            committed_insts[1].if_take_branch       = RobEntriesToRetire[1].if_take_branch;
            committed_insts[1].target_pc            = RobEntriesToRetire[1].target_pc;
            committed_insts[1].is_branch            = RobEntriesToRetire[1].is_branch;
            committed_insts[0].SPEC_PC              = RobEntriesToRetire[0].SPEC_PC;
            committed_insts[1].SPEC_PC             = RobEntriesToRetire[1].SPEC_PC;
            committed_insts[0].inst                 = RobEntriesToRetire[0].inst; 
            committed_insts[1].inst                 = RobEntriesToRetire[1].inst; 
            //halt                                    = 1'b0;      
        end
    endcase
end



endmodule