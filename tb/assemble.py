#!/usr/bin/env python3
"""Minimal RV32I encoder for the pipeline test program (no labels/parser -
just direct encode calls, values shown alongside for review)."""

def r_type(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def i_type(imm, rs1, funct3, rd, opcode):
    imm &= 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1, funct3, opcode):
    imm &= 0xFFF
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def b_type(imm, rs2, rs1, funct3, opcode):
    # imm is byte offset, must be even
    imm12   = (imm >> 12) & 0x1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1  = (imm >> 1) & 0xF
    imm11   = (imm >> 11) & 0x1
    return (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_1 << 8) | (imm11 << 7) | opcode

def addi(rd, rs1, imm): return i_type(imm, rs1, 0b000, rd, 0b0010011)
def add(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b000, rd, 0b0110011)
def sub(rd, rs1, rs2):  return r_type(0b0100000, rs2, rs1, 0b000, rd, 0b0110011)
def and_(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b111, rd, 0b0110011)
def or_(rd, rs1, rs2):   return r_type(0b0000000, rs2, rs1, 0b110, rd, 0b0110011)
def xor_(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b100, rd, 0b0110011)
def slt(rd, rs1, rs2):  return r_type(0b0000000, rs2, rs1, 0b010, rd, 0b0110011)
def lw(rd, rs1, imm):   return i_type(imm, rs1, 0b010, rd, 0b0000011)
def sw(rs2, rs1, imm):  return s_type(imm, rs2, rs1, 0b010, 0b0100011)
def beq(rs1, rs2, imm): return b_type(imm, rs2, rs1, 0b000, 0b1100011)
def nop():               return addi(0, 0, 0)

program = [
    addi(1, 0, 5),       # 0:  x1 = 5
    addi(2, 0, 10),      # 1:  x2 = 10
    add(3, 1, 2),        # 2:  x3 = x1+x2 = 15
    sub(4, 2, 1),        # 3:  x4 = x2-x1 = 5
    sw(3, 0, 0),         # 4:  mem[0] = x3 = 15
    lw(5, 0, 0),         # 5:  x5 = mem[0] = 15   (load)
    add(6, 5, 1),        # 6:  x6 = x5+x1 = 20    (load-use hazard: needs x5 immediately)
    beq(1, 1, 8),        # 7:  branch always taken (x1==x1), target = pc(7*4=28)+8 = 36 -> instr index 9
    addi(7, 0, 99),      # 8:  SHOULD BE FLUSHED (branch delay slot squashed) -> x7 stays 0
    addi(8, 0, 42),      # 9:  branch target: x8 = 42
    and_(9, 3, 2),       # 10: x9  = x3 & x2 = 15 & 10 = 10
    or_(10, 3, 2),       # 11: x10 = x3 | x2 = 15
    xor_(11, 3, 2),      # 12: x11 = x3 ^ x2 = 5
    slt(12, 1, 2),       # 13: x12 = (x1<x2) = 1
    nop(), nop(), nop(), nop(), nop(),  # drain pipeline
]

with open("imem.hex", "w") as f:
    for instr in program:
        f.write(f"{instr:08x}\n")

print(f"Wrote {len(program)} instructions to imem.hex")
for i, instr in enumerate(program):
    print(f"  [{i:2d}] 0x{instr:08x}")
