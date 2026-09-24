 // -----------------------------------------------------------------------------
 // Module      : riscv_pipeline_top
// Description : 5-stage pipelined RV32I processor subset (IF-ID-EX-MEM-WB).
//                Supports: ADD, SUB, AND, OR, XOR, SLT, ADDI, LW, SW, BEQ.
//                Includes:
//                  - EX-stage operand forwarding (from EX/MEM and MEM/WB)
//                  - Load-use hazard detection with 1-cycle stall
//                  - Branch resolution in EX with pipeline flush on taken branch
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module riscv_pipeline_top #(
    parameter IMEM_WORDS = 64,
    parameter DMEM_WORDS = 64
) (
    input  logic clk, 
    input  logic rst_n
);

    // ================= Instruction memory =================
    logic [31:0] imem [0:IMEM_WORDS-1];

    // ================= Register file =================
    logic [31:0] regfile [0:31];
    initial begin
        for (int i = 0; i < 32; i++) regfile[i] = 32'd0;
    end

    // ================= Data memory =================
    logic [31:0] dmem [0:DMEM_WORDS-1];
    initial begin
        for (int i = 0; i < DMEM_WORDS; i++) dmem[i] = 32'd0;
    end

    // =====================================================================
    // IF stage
    // =====================================================================
    logic [31:0] pc, pc_next;
    logic        stall;         // load-use hazard stall
    logic        branch_taken;
    logic [31:0] branch_target;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'd0;
        else        pc <= pc_next;
    end

    always_comb begin
        if (branch_taken)      pc_next = branch_target;
        else if (stall)        pc_next = pc;
        else                   pc_next = pc + 32'd4;
    end

    logic [31:0] if_instr;
    assign if_instr = imem[pc[31:2]];

    // IF/ID pipeline register
    logic [31:0] ifid_instr, ifid_pc;
    logic        ifid_bubble;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || branch_taken) begin
            ifid_instr  <= 32'd0; // NOP (addi x0,x0,0)
            ifid_pc     <= 32'd0;
        end else if (stall) begin
            // hold current IF/ID contents (bubble inserted downstream instead)
        end else begin
            ifid_instr <= if_instr;
            ifid_pc    <= pc;
        end
    end

    // =====================================================================
    // ID stage
    // =====================================================================
    logic [6:0]  id_opcode;
    logic [4:0]  id_rd, id_rs1, id_rs2;
    logic [2:0]  id_funct3;
    logic [6:0]  id_funct7;
    logic [31:0] id_imm;
    logic        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src, id_branch;

    assign id_opcode = ifid_instr[6:0];
    assign id_rd     = ifid_instr[11:7];
    assign id_funct3 = ifid_instr[14:12];
    assign id_rs1    = ifid_instr[19:15];
    assign id_rs2    = ifid_instr[24:20];
    assign id_funct7 = ifid_instr[31:25];

    // Immediate generation (I-type, S-type, B-type)
    always_comb begin
        case (id_opcode)
            7'b0010011, 7'b0000011: // I-type: addi, lw
                id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:20]};
            7'b0100011: // S-type: sw
                id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:25], ifid_instr[11:7]};
            7'b1100011: // B-type: beq
                id_imm = {{19{ifid_instr[31]}}, ifid_instr[31], ifid_instr[7],
                          ifid_instr[30:25], ifid_instr[11:8], 1'b0};
            default:
                id_imm = 32'd0;
        endcase
    end

    // Control decode
    always_comb begin
        id_reg_write  = 1'b0;
        id_mem_read   = 1'b0;
        id_mem_write  = 1'b0;
        id_mem_to_reg = 1'b0;
        id_alu_src    = 1'b0;
        id_branch     = 1'b0;
        case (id_opcode)
            7'b0110011: begin id_reg_write = 1'b1; end                       // R-type
            7'b0010011: begin id_reg_write = 1'b1; id_alu_src = 1'b1; end    // addi
            7'b0000011: begin id_reg_write = 1'b1; id_alu_src = 1'b1;
                               id_mem_read = 1'b1; id_mem_to_reg = 1'b1; end // lw
            7'b0100011: begin id_alu_src = 1'b1; id_mem_write = 1'b1; end    // sw
            7'b1100011: begin id_branch = 1'b1; end                          // beq
            default: ;
        endcase
    end

    // Register file read with write-back same-cycle forwarding (internal bypass)
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic [31:0] wb_data;

    logic [31:0] id_rs1_data, id_rs2_data;
    assign id_rs1_data = (wb_reg_write && wb_rd != 0 && wb_rd == id_rs1) ? wb_data : regfile[id_rs1];
    assign id_rs2_data = (wb_reg_write && wb_rd != 0 && wb_rd == id_rs2) ? wb_data : regfile[id_rs2];

    // =====================================================================
    // Hazard detection unit (load-use hazard) - looks at ID/EX stage
    // =====================================================================
    logic idex_mem_read;
    logic [4:0] idex_rd;

    always_comb begin
        if (idex_mem_read && (idex_rd != 0) &&
            ((idex_rd == id_rs1) || (idex_rd == id_rs2)))
            stall = 1'b1;
        else
            stall = 1'b0;
    end

    // ID/EX pipeline register
    logic [31:0] idex_pc, idex_rs1_data, idex_rs2_data, idex_imm;
    logic [4:0]  idex_rs1, idex_rs2;
    logic [2:0]  idex_funct3;
    logic [6:0]  idex_funct7;
    logic [6:0]  idex_opcode;
    logic        idex_reg_write, idex_mem_write, idex_mem_to_reg, idex_alu_src, idex_branch;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || stall || branch_taken) begin
            idex_pc         <= 32'd0;
            idex_rs1_data   <= 32'd0;
            idex_rs2_data   <= 32'd0;
            idex_imm        <= 32'd0;
            idex_rs1        <= 5'd0;
            idex_rs2        <= 5'd0;
            idex_rd         <= 5'd0;
            idex_funct3     <= 3'd0;
            idex_funct7     <= 7'd0;
            idex_opcode     <= 7'd0;
            idex_reg_write  <= 1'b0;
            idex_mem_read   <= 1'b0;
            idex_mem_write  <= 1'b0;
            idex_mem_to_reg <= 1'b0;
            idex_alu_src    <= 1'b0;
            idex_branch     <= 1'b0;
        end else begin
            idex_pc         <= ifid_pc;
            idex_rs1_data   <= id_rs1_data;
            idex_rs2_data   <= id_rs2_data;
            idex_imm        <= id_imm;
            idex_rs1        <= id_rs1;
            idex_rs2        <= id_rs2;
            idex_rd         <= id_rd;
            idex_funct3     <= id_funct3;
            idex_funct7     <= id_funct7;
            idex_opcode     <= id_opcode;
            idex_reg_write  <= id_reg_write;
            idex_mem_read   <= id_mem_read;
            idex_mem_write  <= id_mem_write;
            idex_mem_to_reg <= id_mem_to_reg;
            idex_alu_src    <= id_alu_src;
            idex_branch     <= id_branch;
        end
    end

    // =====================================================================
    // EX stage - forwarding + ALU + branch resolution
    // =====================================================================
    logic [4:0] exmem_rd, memwb_rd;
    logic       exmem_reg_write, memwb_reg_write;
    logic [31:0] exmem_alu_result, memwb_writeback_data;

    logic [1:0] fwd_a_sel, fwd_b_sel; // 00=regfile/idex, 01=EX/MEM, 10=MEM/WB

    always_comb begin
        // Forward A (rs1)
        if (exmem_reg_write && (exmem_rd != 0) && (exmem_rd == idex_rs1))
            fwd_a_sel = 2'b01;
        else if (memwb_reg_write && (memwb_rd != 0) && (memwb_rd == idex_rs1))
            fwd_a_sel = 2'b10;
        else
            fwd_a_sel = 2'b00;

        // Forward B (rs2)
        if (exmem_reg_write && (exmem_rd != 0) && (exmem_rd == idex_rs2))
            fwd_b_sel = 2'b01;
        else if (memwb_reg_write && (memwb_rd != 0) && (memwb_rd == idex_rs2))
            fwd_b_sel = 2'b10;
        else
            fwd_b_sel = 2'b00;
    end

    logic [31:0] ex_operand_a, ex_operand_b_reg, ex_alu_b, ex_alu_result;

    always_comb begin
        case (fwd_a_sel)
            2'b01: ex_operand_a = exmem_alu_result;
            2'b10: ex_operand_a = memwb_writeback_data;
            default: ex_operand_a = idex_rs1_data;
        endcase
        case (fwd_b_sel)
            2'b01: ex_operand_b_reg = exmem_alu_result;
            2'b10: ex_operand_b_reg = memwb_writeback_data;
            default: ex_operand_b_reg = idex_rs2_data;
        endcase
    end

    assign ex_alu_b = idex_alu_src ? idex_imm : ex_operand_b_reg;

    // ALU control: derive operation from opcode/funct3/funct7
    logic [3:0] alu_ctrl;
    always_comb begin
        case (idex_opcode)
            7'b0110011: begin // R-type
                case ({idex_funct7[5], idex_funct3})
                    4'b0_000: alu_ctrl = 4'b0000; // add
                    4'b1_000: alu_ctrl = 4'b0001; // sub
                    4'b0_111: alu_ctrl = 4'b0010; // and
                    4'b0_110: alu_ctrl = 4'b0011; // or
                    4'b0_100: alu_ctrl = 4'b0100; // xor
                    4'b0_010: alu_ctrl = 4'b0101; // slt
                    default:  alu_ctrl = 4'b0000;
                endcase
            end
            7'b0010011: alu_ctrl = 4'b0000; // addi -> add
            7'b0000011: alu_ctrl = 4'b0000; // lw   -> add (base+offset)
            7'b0100011: alu_ctrl = 4'b0000; // sw   -> add (base+offset)
            7'b1100011: alu_ctrl = 4'b0001; // beq  -> sub (for zero compare)
            default:    alu_ctrl = 4'b0000;
        endcase
    end

    always_comb begin
        case (alu_ctrl)
            4'b0000: ex_alu_result = ex_operand_a + ex_alu_b;
            4'b0001: ex_alu_result = ex_operand_a - ex_alu_b;
            4'b0010: ex_alu_result = ex_operand_a & ex_alu_b;
            4'b0011: ex_alu_result = ex_operand_a | ex_alu_b;
            4'b0100: ex_alu_result = ex_operand_a ^ ex_alu_b;
            4'b0101: ex_alu_result = ($signed(ex_operand_a) < $signed(ex_alu_b)) ? 32'd1 : 32'd0;
            default: ex_alu_result = 32'd0;
        endcase
    end

    logic ex_zero;
    assign ex_zero = (ex_operand_a == ex_alu_b);
    assign branch_taken  = idex_branch && ex_zero;
    assign branch_target = idex_pc + idex_imm;

    // EX/MEM pipeline register
    logic [31:0] exmem_store_data, exmem_pc;
    logic        exmem_mem_write, exmem_mem_to_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exmem_alu_result <= 32'd0;
            exmem_store_data <= 32'd0;
            exmem_rd         <= 5'd0;
            exmem_reg_write  <= 1'b0;
            exmem_mem_write  <= 1'b0;
            exmem_mem_to_reg <= 1'b0;
        end else begin
            exmem_alu_result <= ex_alu_result;
            exmem_store_data <= ex_operand_b_reg;
            exmem_rd         <= idex_rd;
            exmem_reg_write  <= idex_reg_write;
            exmem_mem_write  <= idex_mem_write;
            exmem_mem_to_reg <= idex_mem_to_reg;
        end
    end

    // =====================================================================
    // MEM stage
    // =====================================================================
    logic [31:0] mem_read_data;

    always_ff @(posedge clk) begin
        if (exmem_mem_write)
            dmem[exmem_alu_result[31:2]] <= exmem_store_data;
    end
    assign mem_read_data = dmem[exmem_alu_result[31:2]];

    // MEM/WB pipeline register
    logic [31:0] memwb_alu_result, memwb_mem_data;
    logic        memwb_mem_to_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            memwb_alu_result <= 32'd0;
            memwb_mem_data   <= 32'd0;
            memwb_rd         <= 5'd0;
            memwb_reg_write  <= 1'b0;
            memwb_mem_to_reg <= 1'b0;
        end else begin
            memwb_alu_result <= exmem_alu_result;
            memwb_mem_data   <= mem_read_data;
            memwb_rd         <= exmem_rd;
            memwb_reg_write  <= exmem_reg_write;
            memwb_mem_to_reg <= exmem_mem_to_reg;
        end
    end

    // =====================================================================
    // WB stage
    // =====================================================================
    assign memwb_writeback_data = memwb_mem_to_reg ? memwb_mem_data : memwb_alu_result;
    assign wb_rd        = memwb_rd;
    assign wb_reg_write = memwb_reg_write;
    assign wb_data       = memwb_writeback_data;

    always_ff @(posedge clk) begin
        if (memwb_reg_write && memwb_rd != 0)
            regfile[memwb_rd] <= memwb_writeback_data;
    end

endmodule
