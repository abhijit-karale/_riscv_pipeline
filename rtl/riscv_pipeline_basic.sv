module riscv_pipeline_basic (
    input logic clk,
    input logic rst_n
);
    // =========================================================================
    // Pipeline Registers
    // =========================================================================
    // IF/ID
    logic [31:0] if_id_pc, if_id_pc_plus_4, if_id_instr;

    // ID/EX
    logic [31:0] id_ex_pc, id_ex_pc_plus_4;
    logic [31:0] id_ex_rd1, id_ex_rd2, id_ex_imm;
    logic [4:0]  id_ex_rs1, id_ex_rs2, id_ex_rd;
    logic        id_ex_reg_write, id_ex_mem_write, id_ex_alu_src, id_ex_branch, id_ex_jump, id_ex_jalr, id_ex_bne_flag;
    logic [1:0]  id_ex_result_src;
    logic [3:0]  id_ex_alu_ctrl;

    // EX/MEM
    logic [31:0] ex_mem_alu_result, ex_mem_rd2, ex_mem_pc_target, ex_mem_pc_plus_4, ex_mem_imm;
    logic [4:0]  ex_mem_rd;
    logic        ex_mem_reg_write, ex_mem_mem_write, ex_mem_take_branch, ex_mem_jump;
    logic [1:0]  ex_mem_result_src;

    // MEM/WB
    logic [31:0] mem_wb_alu_result, mem_wb_dmem_rd, mem_wb_pc_plus_4, mem_wb_imm;
    logic [4:0]  mem_wb_rd;
    logic        mem_wb_reg_write;
    logic [1:0]  mem_wb_result_src;

    // =========================================================================
    // IF Stage
    // =========================================================================
    logic [31:0] if_pc, if_next_pc, if_pc_plus_4, if_instr;
    logic        pc_src;
    logic [31:0] pc_target;

    pc_reg u_pc_reg (
        .clk(clk), .rst_n(rst_n), .next_pc(if_next_pc), .pc(if_pc)
    );
    
    assign if_pc_plus_4 = if_pc + 4;
    assign if_next_pc = pc_src ? pc_target : if_pc_plus_4;

    imem #(
        .INIT_FILE("../tb/nop_program.hex")
    ) u_imem (
        .pc(if_pc), .instr(if_instr)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc        <= 0;
            if_id_pc_plus_4 <= 0;
            if_id_instr     <= 0;
        end else begin
            if_id_pc        <= if_pc;
            if_id_pc_plus_4 <= if_pc_plus_4;
            if_id_instr     <= if_instr;
        end
    end

    // =========================================================================
    // ID Stage
    // =========================================================================
    logic       id_reg_write, id_alu_src, id_mem_write, id_branch, id_jump, id_jalr, id_bne_flag;
    logic [2:0] id_imm_sel;
    logic [3:0] id_alu_ctrl;
    logic [1:0] id_result_src;
    logic [31:0] id_rd1, id_rd2, id_imm;
    logic [31:0] wb_wd3; // From WB stage

    control_unit u_control (
        .opcode(if_id_instr[6:0]), .funct3(if_id_instr[14:12]), .funct7(if_id_instr[31:25]),
        .reg_write(id_reg_write), .imm_sel(id_imm_sel), .alu_src(id_alu_src),
        .alu_ctrl(id_alu_ctrl), .mem_write(id_mem_write), .result_src(id_result_src),
        .branch(id_branch), .bne_flag(id_bne_flag), .jump(id_jump), .jalr(id_jalr)
    );

    regfile u_regfile (
        .clk(clk), .rst_n(rst_n), .we(mem_wb_reg_write), // Write from WB stage
        .rs1(if_id_instr[19:15]), .rs2(if_id_instr[24:20]), .rd(mem_wb_rd),
        .wd(wb_wd3), .rd1(id_rd1), .rd2(id_rd2)
    );

    imm_gen u_imm_gen (
        .instr(if_id_instr), .imm_sel(id_imm_sel), .imm(id_imm)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc         <= 0;
            id_ex_pc_plus_4  <= 0;
            id_ex_rd1        <= 0;
            id_ex_rd2        <= 0;
            id_ex_imm        <= 0;
            id_ex_rs1        <= 0;
            id_ex_rs2        <= 0;
            id_ex_rd         <= 0;
            id_ex_reg_write  <= 0;
            id_ex_mem_write  <= 0;
            id_ex_alu_src    <= 0;
            id_ex_branch     <= 0;
            id_ex_jump       <= 0;
            id_ex_jalr       <= 0;
            id_ex_bne_flag   <= 0;
            id_ex_result_src <= 0;
            id_ex_alu_ctrl   <= 0;
        end else begin
            id_ex_pc         <= if_id_pc;
            id_ex_pc_plus_4  <= if_id_pc_plus_4;
            id_ex_rd1        <= id_rd1;
            id_ex_rd2        <= id_rd2;
            id_ex_imm        <= id_imm;
            id_ex_rs1        <= if_id_instr[19:15];
            id_ex_rs2        <= if_id_instr[24:20];
            id_ex_rd         <= if_id_instr[11:7];
            id_ex_reg_write  <= id_reg_write;
            id_ex_mem_write  <= id_mem_write;
            id_ex_alu_src    <= id_alu_src;
            id_ex_branch     <= id_branch;
            id_ex_jump       <= id_jump;
            id_ex_jalr       <= id_jalr;
            id_ex_bne_flag   <= id_bne_flag;
            id_ex_result_src <= id_result_src;
            id_ex_alu_ctrl   <= id_alu_ctrl;
        end
    end

    // =========================================================================
    // EX Stage
    // =========================================================================
    logic [31:0] ex_alu_b, ex_alu_result, ex_pc_target;
    logic        ex_zero, ex_take_branch;

    assign ex_alu_b = id_ex_alu_src ? id_ex_imm : id_ex_rd2;

    alu u_alu (
        .a(id_ex_rd1), .b(ex_alu_b), .alu_ctrl(id_ex_alu_ctrl),
        .result(ex_alu_result), .zero(ex_zero)
    );

    assign ex_take_branch = id_ex_branch & (id_ex_bne_flag ? ~ex_zero : ex_zero);
    assign ex_pc_target = (id_ex_jalr ? id_ex_rd1 : id_ex_pc) + id_ex_imm;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result  <= 0;
            ex_mem_rd2         <= 0;
            ex_mem_pc_target   <= 0;
            ex_mem_pc_plus_4   <= 0;
            ex_mem_imm         <= 0;
            ex_mem_rd          <= 0;
            ex_mem_reg_write   <= 0;
            ex_mem_mem_write   <= 0;
            ex_mem_take_branch <= 0;
            ex_mem_jump        <= 0;
            ex_mem_result_src  <= 0;
        end else begin
            ex_mem_alu_result  <= ex_alu_result;
            ex_mem_rd2         <= id_ex_rd2;
            ex_mem_pc_target   <= ex_pc_target;
            ex_mem_pc_plus_4   <= id_ex_pc_plus_4;
            ex_mem_imm         <= id_ex_imm;
            ex_mem_rd          <= id_ex_rd;
            ex_mem_reg_write   <= id_ex_reg_write;
            ex_mem_mem_write   <= id_ex_mem_write;
            ex_mem_take_branch <= ex_take_branch;
            ex_mem_jump        <= id_ex_jump;
            ex_mem_result_src  <= id_ex_result_src;
        end
    end

    // =========================================================================
    // MEM Stage
    // =========================================================================
    logic [31:0] mem_dmem_rd;

    dmem u_dmem (
        .clk(clk), .we(ex_mem_mem_write), .addr(ex_mem_alu_result),
        .wd(ex_mem_rd2), .rd(mem_dmem_rd)
    );

    // Hazard resolution for jump/branch (resolved in MEM without hazard logic for now, 
    // we route pc_src to IF)
    assign pc_src = ex_mem_take_branch | ex_mem_jump;
    assign pc_target = ex_mem_pc_target;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_alu_result <= 0;
            mem_wb_dmem_rd    <= 0;
            mem_wb_pc_plus_4  <= 0;
            mem_wb_imm        <= 0;
            mem_wb_rd         <= 0;
            mem_wb_reg_write  <= 0;
            mem_wb_result_src <= 0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_dmem_rd    <= mem_dmem_rd;
            mem_wb_pc_plus_4  <= ex_mem_pc_plus_4;
            mem_wb_imm        <= ex_mem_imm;
            mem_wb_rd         <= ex_mem_rd;
            mem_wb_reg_write  <= ex_mem_reg_write;
            mem_wb_result_src <= ex_mem_result_src;
        end
    end

    // =========================================================================
    // WB Stage
    // =========================================================================
    always_comb begin
        case (mem_wb_result_src)
            2'b00: wb_wd3 = mem_wb_alu_result;
            2'b01: wb_wd3 = mem_wb_dmem_rd;
            2'b10: wb_wd3 = mem_wb_pc_plus_4;
            2'b11: wb_wd3 = mem_wb_imm;
            default: wb_wd3 = 32'b0;
        endcase
    end

endmodule
