# ENOR-CPU Test Program
# Simple arithmetic test

# Initialize registers
ADDI x5, x0, 10    # x5 = 10
ADDI x6, x0, 20    # x6 = 20
ADDI x7, x0, 30    # x7 = 30

# Arithmetic operations
ADD x8, x5, x6     # x8 = x5 + x6 = 30
SUB x9, x7, x5     # x9 = x7 - x5 = 20
AND x10, x8, x9    # x10 = x8 & x9
OR x11, x8, x9     # x11 = x8 | x9
XOR x12, x8, x9    # x12 = x8 ^ x9

# Store results to data memory (0x40000000+)
# Use LUI to set upper bits
LUI x20, 0x40000    # x20 = 0x40000000
SW x8, 0x40(x20)    # mem[0x40000040] = 30
SW x9, 0x44(x20)    # mem[0x40000044] = 20
SW x10, 0x48(x20)   # mem[0x40000048] = x10
SW x11, 0x4C(x20)   # mem[0x4000004C] = x11
SW x12, 0x50(x20)   # mem[0x40000050] = x12

# Load and verify
LW x13, 0x40(x20)   # x13 = mem[0x40000040] = 30
LW x14, 0x44(x20)   # x14 = mem[0x40000044] = 20

# Branch test
BEQ x13, x7, skip   # if x13 == x7 (30 == 30), jump to skip
ADDI x15, x0, 1     # x15 = 1 (should not execute)
skip:
ADDI x15, x0, 99    # x15 = 99

# End
EBREAK
