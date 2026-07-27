module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,
    output logic       reg_write,
    output logic [2:0] imm_sel,
    output logic       alu_src,
    output logic [3:0] alu_ctrl,
    output logic       mem_write,
    output logic [1:0] result_src, // 00=ALU, 01=DataMem, 10=PC+4 (for JAL/JALR), 11=LUI (Imm)
    output logic       branch,
    output logic       bne_flag,
    output logic       jump,
    output logic       jalr
);
    logic [1:0] alu_op;
    
    // Main Decoder
    always_comb begin
        reg_write  = 0;
        imm_sel    = 3'b000;
        alu_src    = 0;
        mem_write  = 0;
        result_src = 2'b00;
        branch     = 0;
        bne_flag   = 0;
        jump       = 0;
        jalr       = 0;
        alu_op     = 2'b00;

        case (opcode)
            7'b0110011: begin // R-type (ADD, SUB, AND, OR, XOR, SLT)
                reg_write = 1;
                alu_op    = 2'b10;
            end
            7'b0010011: begin // I-type (ADDI, etc.)
                reg_write = 1;
                imm_sel   = 3'd0;
                alu_src   = 1;
                alu_op    = 2'b11; // Special I-type ALU op
            end
            7'b0000011: begin // LW
                reg_write  = 1;
                imm_sel    = 3'd0;
                alu_src    = 1;
                result_src = 2'b01; // DataMem
                alu_op     = 2'b00; // ADD
            end
            7'b0100011: begin // SW
                imm_sel   = 3'd1;
                alu_src   = 1;
                mem_write = 1;
                alu_op    = 2'b00; // ADD
            end
            7'b1100011: begin // BEQ / BNE
                imm_sel  = 3'd2;
                branch   = 1;
                alu_op   = 2'b01; // SUB for comparison
                bne_flag = (funct3 == 3'b001); // 1 if BNE, 0 if BEQ
            end
            7'b0110111: begin // LUI
                reg_write  = 1;
                imm_sel    = 3'd4;
                result_src = 2'b11; // Imm
            end
            7'b1101111: begin // JAL
                reg_write  = 1;
                imm_sel    = 3'd3;
                jump       = 1;
                result_src = 2'b10; // PC+4
            end
            7'b1100111: begin // JALR
                reg_write  = 1;
                imm_sel    = 3'd0;
                jump       = 1;
                jalr       = 1;
                result_src = 2'b10; // PC+4
            end
            default: ; // NOP or unsupported
        endcase
    end

    // ALU Decoder
    always_comb begin
        case (alu_op)
            2'b00: alu_ctrl = 4'b0000; // ADD (LW/SW)
            2'b01: alu_ctrl = 4'b1000; // SUB (BEQ/BNE)
            2'b10: begin // R-type
                case (funct3)
                    3'b000: alu_ctrl = (funct7[5]) ? 4'b1000 : 4'b0000; // SUB / ADD
                    3'b010: alu_ctrl = 4'b0010; // SLT
                    3'b100: alu_ctrl = 4'b0100; // XOR
                    3'b110: alu_ctrl = 4'b0110; // OR
                    3'b111: alu_ctrl = 4'b0111; // AND
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            2'b11: begin // I-type
                case (funct3)
                    3'b000: alu_ctrl = 4'b0000; // ADDI
                    default: alu_ctrl = 4'b0000;
                endcase
            end
            default: alu_ctrl = 4'b0000;
        endcase
    end
endmodule
