module imem #(
    parameter INIT_FILE = "../tb/imem.hex"
)(
    input  logic [31:0] pc,
    output logic [31:0] instr
);
    logic [31:0] mem [0:255];    // 1KB memory (256 words)

    initial begin
        $readmemh(INIT_FILE, mem);
    end

        // Read asynchronously (single-cycle architecture)
    assign instr = mem[pc[31:2]];
endmodule
