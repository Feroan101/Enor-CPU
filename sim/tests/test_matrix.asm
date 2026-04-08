# ENOR-CPU Matrix Test Program

# Set matrix dimensions
ADDI x5, x0, 2     # x5 = 2
CSRRW x0, 0x002, x5  # VLX = 2
CSRRW x0, 0x003, x5  # VLY = 2
CSRRW x0, 0x004, x5  # VLZ = 2

# Set up data memory base address
LUI x16, 0x40000   # x16 = 0x40000000

# Initialize matrix A (2x2)
# A = [[1, 2], [3, 4]]
ADDI x6, x16, 0x100  # x6 = 0x40000100 (matrix A address)
ADDI x7, x0, 1
SW x7, 0(x6)         # A[0][0] = 1
ADDI x7, x0, 2
SW x7, 4(x6)         # A[0][1] = 2
ADDI x7, x0, 3
SW x7, 8(x6)         # A[1][0] = 3
ADDI x7, x0, 4
SW x7, 12(x6)        # A[1][1] = 4

# Initialize matrix B (2x2)
# B = [[5, 6], [7, 8]]
ADDI x8, x16, 0x140  # x8 = 0x40000140 (matrix B address)
ADDI x7, x0, 5
SW x7, 0(x8)         # B[0][0] = 5
ADDI x7, x0, 6
SW x7, 4(x8)         # B[0][1] = 6
ADDI x7, x0, 7
SW x7, 8(x8)         # B[1][0] = 7
ADDI x7, x0, 8
SW x7, 12(x8)        # B[1][1] = 8

# Matrix multiply: M0 = A * B
# Expected: M0 = [[19, 22], [43, 50]]
MMUL x6, x8

# Store result
ADDI x9, x16, 0x180  # x9 = 0x40000180 (result address)
MSTORE x9

# Verify result
LW x10, 0(x9)        # x10 = M0[0][0] = 19
LW x11, 4(x9)        # x11 = M0[0][1] = 22
LW x12, 8(x9)        # x12 = M0[1][0] = 43
LW x13, 12(x9)       # x13 = M0[1][1] = 50

# Matrix multiply-accumulate: M0 += A * B
# Expected: M0 = [[38, 44], [86, 100]]
MMAC x6, x8

# Store accumulated result
ADDI x14, x16, 0x1C0  # x14 = 0x400001C0 (accumulated result address)
MSTORE x14

EBREAK
