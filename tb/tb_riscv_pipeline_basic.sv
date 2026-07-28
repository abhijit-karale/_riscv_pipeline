module tb_riscv_pipeline_basic();
    logic clk;
    logic rst_n;

    // Instantiate DUT
    riscv_pipeline_basic dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("../sim/pipeline_basic.vcd");
        $dumpvars(0, tb_riscv_pipeline_basic);

        // Initialize
        clk = 0;
        rst_n = 0;
        
        // Reset
        #15 rst_n = 1;

        // Wait for program execution
        #500;
        
        // Check Registers
        $display("--- Final Register Values ---");
        for (int i = 0; i < 32; i++) begin
            if (dut.u_regfile.registers[i] !== 0) begin
                $display("x%0d\t= %0d\t(0x%h)", i, dut.u_regfile.registers[i], dut.u_regfile.registers[i]);
            end
        end
        $display("-----------------------------");

        if (dut.u_regfile.registers[1] === 32'd5) $display("PASS: ADDI test (x1)");
        else $display("FAIL: ADDI test (x1) expected 5, got %d", dut.u_regfile.registers[1]);

        if (dut.u_regfile.registers[2] === 32'd10) $display("PASS: ADDI test (x2)");
        else $display("FAIL: ADDI test (x2) expected 10, got %d", dut.u_regfile.registers[2]);

        if (dut.u_regfile.registers[3] === 32'd15) $display("PASS: ADD test (x3)");
        else $display("FAIL: ADD test (x3) expected 15, got %d", dut.u_regfile.registers[3]);

        $finish;
    end
endmodule
