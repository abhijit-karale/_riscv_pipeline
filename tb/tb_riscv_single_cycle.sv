module tb_riscv_single_cycle();
    logic clk;
    logic rst_n;

    // Instantiate DUT
    riscv_single_cycle dut (
        .clk(clk),
        .rst_n(rst_n)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        $dumpfile("../sim/single_cycle.vcd");
        $dumpvars(0, tb_riscv_single_cycle);

        // Initialize
        clk = 0;
        rst_n = 0;
        
        // Reset
        #15 rst_n = 1;

        // Wait for program execution (26 instructions = 26 cycles)
        #300;
        
        // Check Registers
        $display("--- Final Register Values ---");
        for (int i = 0; i < 32; i++) begin
            if (dut.u_regfile.registers[i] !== 0) begin
                $display("x%0d\t= %0d\t(0x%h)", i, dut.u_regfile.registers[i], dut.u_regfile.registers[i]);
            end
        end
        $display("-----------------------------");

        // Verify key values
        if (dut.u_regfile.registers[3] === 32'd15) $display("PASS: ADD test (x3)");
        else $display("FAIL: ADD test (x3) expected 15, got %d", dut.u_regfile.registers[3]);

        if (dut.u_regfile.registers[5] === 32'd15) $display("PASS: LW/SW test (x5)");
        else $display("FAIL: LW/SW test (x5) expected 15, got %d", dut.u_regfile.registers[5]);

        if (dut.u_regfile.registers[8] === 32'd42) $display("PASS: BEQ test (x8)");
        else $display("FAIL: BEQ test (x8) expected 42, got %d", dut.u_regfile.registers[8]);

        if (dut.u_regfile.registers[7] === 32'd0) $display("PASS: BEQ jump/skip test (x7)");
        else $display("FAIL: BEQ jump/skip test (x7) expected 0, got %d", dut.u_regfile.registers[7]);

        if (dut.u_regfile.registers[12] === 32'd1) $display("PASS: SLT test (x12)");
        else $display("FAIL: SLT test (x12) expected 1, got %d", dut.u_regfile.registers[12]);

        if (dut.u_regfile.registers[13] === 32'h12345000) $display("PASS: LUI test (x13)");
        else $display("FAIL: LUI test (x13) expected 12345000, got %h", dut.u_regfile.registers[13]);

        if (dut.u_regfile.registers[14] === 32'd64) $display("PASS: JAL test (x14)");
        else $display("FAIL: JAL test (x14) expected 64, got %d", dut.u_regfile.registers[14]);

        if (dut.u_regfile.registers[15] === 32'd0) $display("PASS: JAL jump/skip test (x15)");
        else $display("FAIL: JAL jump/skip test (x15) expected 0, got %d", dut.u_regfile.registers[15]);

        if (dut.u_regfile.registers[16] === 32'd72) $display("PASS: JALR test (x16)");
        else $display("FAIL: JALR test (x16) expected 72, got %d", dut.u_regfile.registers[16]);

        if (dut.u_regfile.registers[17] === 32'd0) $display("PASS: BNE jump/skip test (x17)");
        else $display("FAIL: BNE jump/skip test (x17) expected 0, got %d", dut.u_regfile.registers[17]);

        $finish;
    end
endmodule
