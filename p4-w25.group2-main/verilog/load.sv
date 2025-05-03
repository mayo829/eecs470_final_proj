`include "ISA.svh"
`include "sys_defs.svh"
module load (
    input                                clock,
    input                                reset,
    input  ISSUE_PACKET                  Ex_packet, 
    output COMPLETE_PACKET               C_packet,

    // // SQ
    // input SQ2LOAD_PACKET                 sq_result, // from the store queue
    // output LOAD2SQ_PACKET                load2SQ_pkt, // to the store queue

    // Cache
    input MEM_BLOCK                      Dcache_data_in,    // Data is mem[proc2Icache_addr]
    input logic                          Dcache_valid_in,    // When valid is high

    output ADDR                          proc2Dcache_addr,   // Address sent to Data memory
    output logic                         load2Dcache_valid,

    
    output logic                         arbitrateOnThis,

    output logic                         ld_read_en,

    output logic                         functional_req_ld
);
   
    // Internal State
    LOAD_STATUS     status;
    DATA            load_data, next_load_data;
    ADDR            address;
    logic [3:0]     mem_align, next_mem_align;

    ISSUE_PACKET Ex_packet_reg;

    // Determine the effective address for loads
    assign address = Ex_packet_reg.r1_value + `RV32_signext_Iimm(Ex_packet_reg.inst);

    //valid output
    assign load2Dcache_valid = status == CACHE;

    assign ld_read_en = status == INPUT;

    // Complete Packet Preparation
    assign C_packet.result          = next_load_data;  // Result will be load_data after processing
    assign C_packet.valid           = status == OUTPUT; 
    assign C_packet.NPC             = Ex_packet_reg.NPC;
    assign C_packet.PC              = Ex_packet_reg.PC;
    assign C_packet.dest_reg_idx    = Ex_packet_reg.dest_reg_idx;
    assign C_packet.target_pc       = '0;
    assign C_packet.if_take_branch  = '0; 
    assign C_packet.is_branch       = '0;
    assign C_packet.rob_ptr         = Ex_packet_reg.rob_ptr;

    assign arbitrateOnThis          = (status == CACHE && Dcache_valid_in); 

    assign functional_req_ld        = status == OUTPUT;

    // LOAD2CACHE Packet Preparation
    assign proc2Dcache_addr     = {address[31:2], 2'b0}; // ignore 1st 2 bits bc those are for alignment
    // bit 2 will be used to choosing the right word.

    // Manage load and sign extending data
    always_comb begin
            next_load_data = '0; // Default to 0
            if (Ex_packet_reg.inst.r.funct3[2]) begin
                // Unsigned data zero-extend
                case (MEM_SIZE'(Ex_packet_reg.inst.r.funct3[1:0]))
                    BYTE: case (address[1:0])
                        2'b00: next_load_data[7:0] = load_data[7:0];
                        2'b01: next_load_data[7:0] = load_data[15:8];
                        2'b10: next_load_data[7:0] = load_data[23:16];
                        2'b11: next_load_data[7:0] = load_data[31:24];
                        default: ; // Handle as necessary
                    endcase
                    HALF: case (address[1:0])
                        2'b00: next_load_data[15:0]  = load_data[15:0];
                        2'b10: next_load_data[15:0]  = load_data[31:16];
                        default: ; // Handle as necessary
                    endcase
                    default: next_load_data[31:0] = load_data[31:0]; // Handle as necessary
                endcase
            end else begin
                // Signed data sign-extend
                case (MEM_SIZE'(Ex_packet_reg.inst.r.funct3[1:0]))
                    BYTE: case (address[1:0])
                        2'b00: begin 
                            next_load_data[7:0]   = load_data[7:0];
                            next_load_data[31:8]  = {(24){load_data[7]}};
                        end
                        2'b01: begin 
                            next_load_data[7:0]  = load_data[15:8];
                            next_load_data[31:8] = {(24){load_data[15]}};
                        end
                        2'b10: begin
                            next_load_data[7:0] = load_data[23:16];
                            next_load_data[31:8] = {(24){load_data[23]}};
                        end
                        2'b11: begin
                            next_load_data[7:0] = load_data[31:24];
                            next_load_data[31:8] = {(24){load_data[31]}};
                        end
                        default: ; // Handle as necessary
                    endcase
                    HALF: case (address[1:0])
                        2'b00: begin
                            next_load_data[15:0]  = load_data[15:0];
                            next_load_data[31:16] = {(16){load_data[15]}};
                        end
                        2'b10: begin
                            next_load_data[15:0]  = load_data[31:16];
                            next_load_data[31:16] = {(16){load_data[31]}};
                        end
                        default: ; // Handle as necessary
                    endcase
                    default: next_load_data[31:0] = load_data[31:0]; // Handle as necessary
                endcase
            end
        end

    // State Machine Logic
    always_ff @(posedge clock) begin
        if (reset) begin
            status <= INPUT;
            load_data <= 0;
            Ex_packet_reg <= '0;
        end else begin
            case (status)
                INPUT: begin
                    // if (sq_result.valid) begin
                    //     status <= SQ; // Proceed to Store Queue handling
                    // end else begin
                    //     status <= CACHE; // Check the cache
                    // end
                    if(Ex_packet.valid) begin 
                        status <= CACHE; // Check the cache
                        Ex_packet_reg <= Ex_packet;
                    end
                    mem_align <= next_mem_align;
                    load_data <= 0; // Default load data
                end
                // SQ: begin
                //     if (sq_result.valid) begin
                //         load_data <= sq_result.data;
                //         status <= OUTPUT;
                //     end 
                //     mem_align <= sq_result.mem_align;
                // end
                CACHE: begin
                    if (Dcache_valid_in) begin // hit
                        load_data <= address[2] ? Dcache_data_in[63:32] : Dcache_data_in[31:0];
                        status <= OUTPUT;
                    end 
                    mem_align <= next_mem_align;
                end
                OUTPUT: begin
                    load_data <= next_load_data;
                    status <= INPUT;
                end
                default: begin
                end
            endcase 
        end 
    end 
endmodule

    // LOAD2SQ Packet Preparation
    // assign load2SQ_pkt.tail_pos = Ex_packet.sq_tail;
    // assign load2SQ_pkt.addr     = {load_data[31:2], 2'b0}; // ignore 1st 2 bits bc those are for alignment

    // always_comb begin
    //     next_mem_align = 0; // dummy value
    //     case(MEM_SIZE'(id_ex_reg.inst.r.funct3[1:0]))
    //         // the least significant 2 bits of mips inst are used to determine the alignment
    //         BYTE: case(address[1:0])  
    //             2'b00: next_mem_align = 4'b0001;
    //             2'b01: next_mem_align = 4'b0010;
    //             2'b10: next_mem_align = 4'b0100;
    //             2'b11: next_mem_align = 4'b1000;
    //         endcase
    //         HALF: case (address[1:0])
    //             2'b00: next_mem_align = 4'b0011;
    //             2'b10: next_mem_align = 4'b1100;
    //         endcase
    //         LW: next_mem_align = 4'b1111;
    //     endcase
    // end