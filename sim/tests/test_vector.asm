# ENOR-CPU Vector Test Program

# Initialize vector length
ADDI x5, x0, 4     # x5 = 4
VSETVL x5, x5      # VL = 4

# Set up data memory base address
LUI x6, 0x40000    # x6 = 0x40000000

# Load vector data to memory
SW x0, 0x40(x6)    # mem[0x40000040] = 0
ADDI x7, x0, 1
SW x7, 0x44(x6)    # mem[0x40000044] = 1
ADDI x7, x0, 2
SW x7, 0x48(x6)    # mem[0x40000048] = 2
ADDI x7, x0, 3
SW x7, 0x4C(x6)    # mem[0x4000004C] = 3

# Load vector from memory
VLW v0, 0x40(x6)   # v0 = [0, 1, 2, 3]

# Create second vector
ADDI x7, x0, 10
SW x7, 0x50(x6)    # mem[0x40000050] = 10
ADDI x7, x0, 20
SW x7, 0x54(x6)    # mem[0x40000054] = 20
ADDI x7, x0, 30
SW x7, 0x58(x6)    # mem[0x40000058] = 30
ADDI x7, x0, 40
SW x7, 0x5C(x6)    # mem[0x4000005C] = 40

VLW v1, 0x50(x6)   # v1 = [10, 20, 30, 40]

# Vector add
VADD v2, v0, v1    # v2 = [10, 21, 32, 43]

# Store result
VSW v2, 0x60(x6)   # mem[0x40000060] = v2

# Vector multiply
VMUL v3, v0, v1    # v3 = [0, 20, 60, 120]

# Store result
VSW v3, 0x70(x6)   # mem[0x40000070] = v3

# Dot product
VDOT x8, v0, v1    # x8 = 0*10 + 1*20 + 2*30 + 3*40 = 200

# Store dot product
SW x8, 0x80(x6)    # mem[0x40000080] = 200

# Sum reduction
VRED_SUM x9, v2    # x9 = 10 + 21 + 32 + 43 = 106

# Store sum
SW x9, 0x84(x6)    # mem[0x40000084] = 106

EBREAK
