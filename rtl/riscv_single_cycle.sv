module riscv_single_cycle (
    input logic clk,
    input logic rst_n
);
    // PC & Instruction
    logic [31:0] pc, next_pc, instr, pc_plus_4;
    
    // Control Signals
    logic       reg_write, alu_src, mem_write, branch, jump, jalr, zero, bne_flag;
    logic [2:0] imm_sel;
    logic [3:0] alu_ctrl;
    logic [1:0] result_src;
    logic       take_branch;
    
    // Datapath
    logic [31:0] rd1, rd2, imm, alu_b, alu_result, dmem_rd, wd3, pc_target;

    // Instantiate Modules
    pc_reg u_pc_reg (
        .clk(clk), .rst_n(rst_n), .next_pc(next_pc), .pc(pc)
    );
    
    assign pc_plus_4 = pc + 4;

    imem u_imem (
        .pc(pc), .instr(instr)
    );

    control_unit u_control (
        .opcode(instr[6:0]), .funct3(instr[14:12]), .funct7(instr[31:25]),
        .reg_write(reg_write), .imm_sel(imm_sel), .alu_src(alu_src),
        .alu_ctrl(alu_ctrl), .mem_write(mem_write), .result_src(result_src),
        .branch(branch), .bne_flag(bne_flag), .jump(jump), .jalr(jalr)
    );

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n), .we(reg_write),
        .rs1(instr[19:15]), .rs2(instr[24:20]), .rd(instr[11:7]),
        .wd(wd3), .rd1(rd1), .rd2(rd2)
    );

    imm_gen u_imm_gen (
        .instr(instr), .imm_sel(imm_sel), .imm(imm)
    );

    assign alu_b = alu_src ? imm : rd2;

    alu u_alu (
        .a(rd1), .b(alu_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero)
    );

    dmem u_dmem (
        .clk(clk), .we(mem_write), .addr(alu_result),
        .wd(rd2), .rd(dmem_rd)
    );

    // Writeback Mux
    always_comb begin
        case (result_src)
            2'b00: wd3 = alu_result;
            2'b01: wd3 = dmem_rd;
            2'b10: wd3 = pc_plus_4;
            2'b11: wd3 = imm;
            default: wd3 = 32'b0;
        endcase
    end

    // Branch / Jump Logic
    assign take_branch = branch & (bne_flag ? ~zero : zero);
    assign pc_target = (jalr ? rd1 : pc) + imm;
    assign next_pc = (take_branch | jump) ? pc_target : pc_plus_4;

endmodule
