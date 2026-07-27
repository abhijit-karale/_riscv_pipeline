module regfile (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        we,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);
    logic [31:0] registers [0:31];

    always_comb begin
        rd1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
        rd2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];
    end

    always_ff @(posedge clk) begin
        if (we && rd != 5'b0) begin
            registers[rd] <= wd;
        end
    end
endmodule
