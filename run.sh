#!/bin/bash
set -e
# Regenerate the assembled test program machine code
cd tb && python3 assemble.py && cp imem.hex ../imem.hex && cd ..
iverilog -g2012 -o sim.out rtl/riscv_pipeline_top.sv tb/tb_riscv_pipeline.sv
vvp sim.out
python3 vcd_plot.py waveform/riscv_pipeline.vcd waveform/riscv_pipeline_waveform.png \
    clk rst_n pc if_instr stall branch_taken ex_alu_result wb_data wb_rd wb_reg_write --window 0 350
echo "Done. Open waveform/riscv_pipeline.vcd in GTKWave for full interactive waveform."
