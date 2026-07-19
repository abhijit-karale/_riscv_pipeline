// -----------------------------------------------------------------------------
// Testbench   : tb_riscv_pipeline
// Description : Self-checking testbench for the 5-stage pipelined RISC-V
//               processor. Loads imem.hex (assembled by assemble.py), runs
//               the program to completion, then checks final register file
//               and data memory contents against expected values computed
//               by hand for the test program. Also exercises a load-use
//               hazard (stall) and a taken branch (pipeline flush).
// Author      : Abhijit Karale
// -----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_riscv_pipeline;

    logic clk, rst_n;
    int pass_count = 0;
    int fail_count = 0;

    riscv_pipeline_top dut (.clk(clk), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $readmemh("imem.hex", dut.imem);
    end

    task automatic check_reg(input int idx, input [31:0] expected);
        logic [31:0] actual;
        actual = dut.regfile[idx];
        if (actual === expected) begin
            $display("[PASS] x%0d = 0x%08h (expected 0x%08h)", idx, actual, expected);
            pass_count++;
        end else begin
            $error("[FAIL] x%0d = 0x%08h, expected 0x%08h", idx, actual, expected);
            fail_count++;
        end
    endtask

    task automatic check_mem(input int idx, input [31:0] expected);
        logic [31:0] actual;
        actual = dut.dmem[idx];
        if (actual === expected) begin
            $display("[PASS] mem[%0d] = 0x%08h (expected 0x%08h)", idx, actual, expected);
            pass_count++;
        end else begin
            $error("[FAIL] mem[%0d] = 0x%08h, expected 0x%08h", idx, actual, expected);
            fail_count++;
        end
    endtask

    initial begin
        $dumpfile("waveform/riscv_pipeline.vcd");
        $dumpvars(0, tb_riscv_pipeline);

        $display("=========================================================");
        $display(" 5-Stage Pipelined RISC-V (RV32I subset) Testbench");
        $display("=========================================================");

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;

        // Run enough cycles for the 19-instruction program (including the
        // 1-cycle load-use stall and the branch flush) to fully drain
        // through all 5 pipeline stages.
        repeat (60) @(posedge clk);

        $display("[TEST] Architectural register file check");
        check_reg(1, 32'd5);              // addi x1,x0,5
        check_reg(2, 32'd10);             // addi x2,x0,10
        check_reg(3, 32'd15);             // add  x3,x1,x2
        check_reg(4, 32'd5);              // sub  x4,x2,x1
        check_reg(5, 32'd15);             // lw   x5,0(x0)   <- from sw earlier
        check_reg(6, 32'd20);             // add  x6,x5,x1   <- load-use hazard path
        check_reg(7, 32'd0);              // MUST be 0: flushed by taken branch
        check_reg(8, 32'd42);             // addi x8,x0,42  <- branch target
        check_reg(9, 32'd10);             // and  x9,x3,x2  = 15 & 10
        check_reg(10, 32'd15);            // or   x10,x3,x2 = 15 | 10
        check_reg(11, 32'd5);             // xor  x11,x3,x2 = 15 ^ 10
        check_reg(12, 32'd1);             // slt  x12,x1,x2 = (5<10)

        $display("[TEST] Data memory check");
        check_mem(0, 32'd15);             // sw x3,0(x0) -> mem[0] = 15

        $display("=========================================================");
        $display(" REGRESSION SUMMARY: PASS=%0d  FAIL=%0d", pass_count, fail_count);
        if (fail_count == 0) begin
            $display(" RESULT: ALL TESTS PASSED - pipeline hazards, forwarding,");
            $display("         load-use stall, and branch flush all verified correct");
        end else
            $display(" RESULT: %0d TEST(S) FAILED", fail_count);
        $display("=========================================================");

        $finish;
    end

endmodule
