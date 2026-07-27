# 5-Stage Pipelined RISC-V Processor (RV32I)

## Project Goal
Build a 5-stage pipelined RISC-V (RV32I base integer ISA) processor in SystemVerilog, verify it with a layered UVM testbench, and reach 95%+ functional coverage.

## Supported Instruction Subset
This project implements the following core subset of the RV32I ISA, which is sufficient to demonstrate full datapath completeness, hazard handling, and branching, making it an excellent and defensible subset for a resume project:

- **R-type**: `ADD`, `SUB`, `AND`, `OR`, `XOR`, `SLT`
- **I-type**: `ADDI`, `LW`, `JALR`
- **S-type**: `SW`
- **B-type**: `BEQ`, `BNE`
- **U-type**: `LUI`
- **J-type**: `JAL`

## Repository Structure
- `rtl/` - SystemVerilog RTL design files
- `tb/` - UVM testbench files
- `sim/` - Simulation and regression outputs
- `docs/` - Project documentation
