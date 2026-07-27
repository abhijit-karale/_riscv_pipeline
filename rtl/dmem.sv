module dmem (
    input  logic        clk,
    input  logic        we,
    input  logic [31:0] addr,
    input  logic [31:0] wd,
    output logic [31:0] rd
);
    logic [31:0] mem [0:255]; // 1KB data memory

    // Asynchronous read for single-cycle
    assign rd = mem[addr[31:2]];

    // Synchronous write
    always_ff @(posedge clk) begin
        if (we) begin
            mem[addr[31:2]] <= wd;
        end
    end
endmodule
