module imm_gen (
    input  logic [31:0] instr,
    input  logic [2:0]  imm_sel, // Determines format: 0=I, 1=S, 2=B, 3=J, 4=U
    output logic [31:0] imm
);
    always_comb begin
        case (imm_sel)
            3'd0: imm = {{20{instr[31]}}, instr[31:20]}; // I-type
            3'd1: imm = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S-type
            3'd2: imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; // B-type
            3'd3: imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; // J-type
            3'd4: imm = {instr[31:12], 12'b0}; // U-type
            default: imm = 32'b0;
        endcase
    end
endmodule
