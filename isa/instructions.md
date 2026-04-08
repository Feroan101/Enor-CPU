# ENOR-CPU Instruction Set

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## 1. Instruction Summary

**Total: 42 instructions**

| Category | Count | Instructions |
|----------|-------|--------------|
| Integer Arithmetic | 18 | ADD, ADDI, SUB, AND, OR, XOR, ANDI, ORI, XORI, SLL, SRL, SRA, SLLI, SRLI, SRAI, SLT, SLTU, LUI, AUIPC |
| Memory | 8 | LB, LH, LW, LBU, LHU, SB, SH, SW |
| Control Flow | 8 | BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR |
| Vector | 8 | VLW, VSW, VADD, VSUB, VMUL, VDOT, VRED_SUM, VSETVL |
| Matrix | 4 | MMUL, MMAC, MLOAD, MSTORE |
| System | 3 | ECALL, EBREAK, CSRRW |

---

## 2. Instruction Format Reference

| Format | Bits | Fields |
|--------|------|--------|
| R-type | [31:0] | funct7[31:25] rs2[24:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0] |
| I-type | [31:0] | imm[11:0][31:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0] |
| S-type | [31:0] | imm[11:5][31:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[4:0][11:7] opcode[6:0] |
| B-type | [31:0] | imm[12][31] imm[10:5][30:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[4:1][11:8] imm[11][7] opcode[6:0] |
| U-type | [31:0] | imm[31:12][31:12] rd[11:7] opcode[6:0] |
| J-type | [31:0] | imm[20][31] imm[10:1][30:21] imm[11][20] imm[19:12][19:12] rd[11:7] opcode[6:0] |
| V-type | [31:0] | funct7[31:25] vs2[24:20] vs1[19:15] funct3[14:12] vd[11:7] opcode[6:0] |

---

## 3. Integer Arithmetic Instructions

### 3.1 ADD

```
ADD

Format:  R-type
Opcode:  0x33
Funct3:  0x00
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] + x[rs2]

Flags:
    Z: Set if result is zero
    C: Set on unsigned carry
    V: Set on signed overflow
    N: Set if result is negative (bit 31)

Latency: 1 cycle

Exception: None

Verification:
    Test: x5 = x6 + x7
    Test overflow: 0x7FFFFFFF + 1 = 0x80000000 (V=1)
    Test carry: 0xFFFFFFFF + 1 = 0x00000000 (C=1)
```

### 3.2 ADDI

```
ADDI

Format:  I-type
Opcode:  0x13
Funct3:  0x00

Operands:
    rd, rs1, imm[11:0]

Operation:
    x[rd] = x[rs1] + sign_extend(imm)

Flags:
    Z: Set if result is zero
    C: Set on unsigned carry
    V: Set on signed overflow
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: imm is 12-bit signed, range -2048 to 2047
```

### 3.3 SUB

```
SUB

Format:  R-type
Opcode:  0x33
Funct3:  0x00
Funct7:  0x20

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] - x[rs2]

Flags:
    Z: Set if result is zero
    C: Set on unsigned borrow (inverted)
    V: Set on signed overflow
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.4 AND

```
AND

Format:  R-type
Opcode:  0x33
Funct3:  0x07
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] & x[rs2]

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.5 OR

```
OR

Format:  R-type
Opcode:  0x33
Funct3:  0x06
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] | x[rs2]

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.6 XOR

```
XOR

Format:  R-type
Opcode:  0x33
Funct3:  0x04
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] ^ x[rs2]

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.7 ANDI

```
ANDI

Format:  I-type
Opcode:  0x13
Funct3:  0x07

Operands:
    rd, rs1, imm[11:0]

Operation:
    x[rd] = x[rs1] & sign_extend(imm)

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.8 ORI

```
ORI

Format:  I-type
Opcode:  0x13
Funct3:  0x06

Operands:
    rd, rs1, imm[11:0]

Operation:
    x[rd] = x[rs1] | sign_extend(imm)

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.9 XORI

```
XORI

Format:  I-type
Opcode:  0x13
Funct3:  0x04

Operands:
    rd, rs1, imm[11:0]

Operation:
    x[rd] = x[rs1] ^ sign_extend(imm)

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None
```

### 3.10 SLL

```
SLL

Format:  R-type
Opcode:  0x33
Funct3:  0x01
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] << x[rs2][4:0]

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: Only lower 5 bits of rs2 used as shift amount
```

### 3.11 SRL

```
SRL

Format:  R-type
Opcode:  0x33
Funct3:  0x05
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] >> x[rs2][4:0] (logical, zero-extend)

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: Only lower 5 bits of rs2 used as shift amount
```

### 3.12 SRA

```
SRA

Format:  R-type
Opcode:  0x33
Funct3:  0x05
Funct7:  0x20

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = x[rs1] >> x[rs2][4:0] (arithmetic, sign-extend)

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: Only lower 5 bits of rs2 used as shift amount
```

### 3.13 SLLI

```
SLLI

Format:  I-type
Opcode:  0x13
Funct3:  0x01
Funct7:  0x00

Operands:
    rd, rs1, imm[4:0]

Operation:
    x[rd] = x[rs1] << imm[4:0]

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: imm[11:5] must be 0x00, otherwise reserved
```

### 3.14 SRLI

```
SRLI

Format:  I-type
Opcode:  0x13
Funct3:  0x05
Funct7:  0x00

Operands:
    rd, rs1, imm[4:0]

Operation:
    x[rd] = x[rs1] >> imm[4:0] (logical)

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: imm[11:5] must be 0x00, otherwise reserved
```

### 3.15 SRAI

```
SRAI

Format:  I-type
Opcode:  0x13
Funct3:  0x05
Funct7:  0x20

Operands:
    rd, rs1, imm[4:0]

Operation:
    x[rd] = x[rs1] >> imm[4:0] (arithmetic)

Flags:
    Z: Set if result is zero
    C: Last bit shifted out (if shift > 0)
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: imm[11:5] must be 0x20, otherwise reserved
```

### 3.16 SLT

```
SLT

Format:  R-type
Opcode:  0x33
Funct3:  0x02
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = (x[rs1] < x[rs2]) ? 1 : 0

Flags:
    Z: Set if result is zero (rd == 0)
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: Signed comparison
```

### 3.17 SLTU

```
SLTU

Format:  R-type
Opcode:  0x33
Funct3:  0x03
Funct7:  0x00

Operands:
    rd, rs1, rs2

Operation:
    x[rd] = (x[rs1] < x[rs2]) unsigned ? 1 : 0

Flags:
    Z: Set if result is zero
    C: 0
    V: 0
    N: Set if result is negative

Latency: 1 cycle

Exception: None

Note: Unsigned comparison
```

### 3.18 LUI

```
LUI

Format:  U-type
Opcode:  0x37

Operands:
    rd, imm[31:12]

Operation:
    x[rd] = imm << 12

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Load Upper Immediate. Places 20-bit immediate in upper 20 bits of rd.
      Lower 12 bits are zero.
```

### 3.19 AUIPC

```
AUIPC

Format:  U-type
Opcode:  0x17

Operands:
    rd, imm[31:12]

Operation:
    x[rd] = PC + (imm << 12)

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Add Upper Immediate to PC. Used for PC-relative addressing.
```

---

## 4. Memory Instructions

### 4.1 LB

```
LB

Format:  I-type
Opcode:  0x03
Funct3:  0x00

Operands:
    rd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    x[rd] = sign_extend(mem[addr][7:0])

Flags: None modified

Latency: 2 cycles (1 for address, 1 for memory)

Exception: Alignment error if addr[1:0] != 0

Note: Load Byte, sign-extended to 32 bits
```

### 4.2 LH

```
LH

Format:  I-type
Opcode:  0x03
Funct3:  0x01

Operands:
    rd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    x[rd] = sign_extend(mem[addr][15:0])

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[0] != 0

Note: Load Halfword, sign-extended to 32 bits
```

### 4.3 LW

```
LW

Format:  I-type
Opcode:  0x03
Funct3:  0x02

Operands:
    rd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    x[rd] = mem[addr][31:0]

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[1:0] != 0

Note: Load Word (32 bits)
```

### 4.4 LBU

```
LBU

Format:  I-type
Opcode:  0x03
Funct3:  0x04

Operands:
    rd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    x[rd] = zero_extend(mem[addr][7:0])

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[1:0] != 0

Note: Load Byte Unsigned, zero-extended to 32 bits
```

### 4.5 LHU

```
LHU

Format:  I-type
Opcode:  0x03
Funct3:  0x05

Operands:
    rd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    x[rd] = zero_extend(mem[addr][15:0])

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[0] != 0

Note: Load Halfword Unsigned, zero-extended to 32 bits
```

### 4.6 SB

```
SB

Format:  S-type
Opcode:  0x23
Funct3:  0x00

Operands:
    rs1, rs2, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    mem[addr][7:0] = x[rs2][7:0]

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[1:0] != 0

Note: Store Byte
```

### 4.7 SH

```
SH

Format:  S-type
Opcode:  0x23
Funct3:  0x01

Operands:
    rs1, rs2, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    mem[addr][15:0] = x[rs2][15:0]

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[0] != 0

Note: Store Halfword
```

### 4.8 SW

```
SW

Format:  S-type
Opcode:  0x23
Funct3:  0x02

Operands:
    rs1, rs2, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    mem[addr][31:0] = x[rs2][31:0]

Flags: None modified

Latency: 2 cycles

Exception: Alignment error if addr[1:0] != 0

Note: Store Word
```

---

## 5. Control Flow Instructions

### 5.1 BEQ

```
BEQ

Format:  B-type
Opcode:  0x63
Funct3:  0x00

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] == x[rs2])
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Equal
```

### 5.2 BNE

```
BNE

Format:  B-type
Opcode:  0x63
Funct3:  0x01

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] != x[rs2])
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Not Equal
```

### 5.3 BLT

```
BLT

Format:  B-type
Opcode:  0x63
Funct3:  0x04

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] < x[rs2])
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Less Than (signed)
```

### 5.4 BGE

```
BGE

Format:  B-type
Opcode:  0x63
Funct3:  0x05

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] >= x[rs2])
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Greater Than or Equal (signed)
```

### 5.5 BLTU

```
BLTU

Format:  B-type
Opcode:  0x63
Funct3:  0x06

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] < x[rs2]) unsigned
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Less Than (unsigned)
```

### 5.6 BGEU

```
BGEU

Format:  B-type
Opcode:  0x63
Funct3:  0x07

Operands:
    rs1, rs2, offset[12:1]

Operation:
    if (x[rs1] >= x[rs2]) unsigned
        PC = PC + sign_extend(offset << 1)
    else
        PC = PC + 4

Flags: None modified

Latency: 1 cycle (not taken), 2 cycles (taken)

Exception: None

Note: Branch if Greater Than or Equal (unsigned)
```

### 5.7 JAL

```
JAL

Format:  J-type
Opcode:  0x6F

Operands:
    rd, offset[20:1]

Operation:
    x[rd] = PC + 4
    PC = PC + sign_extend(offset << 1)

Flags: None modified

Latency: 2 cycles

Exception: None

Note: Jump And Link. Stores return address in rd.
      Offset is 20-bit signed, shifted left 1.
```

### 5.8 JALR

```
JALR

Format:  I-type
Opcode:  0x67
Funct3:  0x00

Operands:
    rd, rs1, imm[11:0]

Operation:
    x[rd] = PC + 4
    PC = (x[rs1] + sign_extend(imm)) & ~1

Flags: None modified

Latency: 2 cycles

Exception: None

Note: Jump And Link Register. PC = (rs1 + imm) & ~1 (bit 0 cleared).
```

---

## 6. Vector Instructions

### 6.1 VLW

```
VLW

Format:  I-type
Opcode:  0x07
Funct3:  0x02

Operands:
    vd, rs1, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    v[vd][255:0] = mem[addr][255:0]

Flags: None modified

Latency: 1 cycle (burst load)

Exception: Alignment error if addr[4:0] != 0

Note: Vector Load Word. Loads 256 bits (8 words) from memory.
      Address must be 32-byte aligned.
```

### 6.2 VSW

```
VSW

Format:  S-type
Opcode:  0x27
Funct3:  0x02

Operands:
    rs1, vs2, imm[11:0]

Operation:
    addr = x[rs1] + sign_extend(imm)
    mem[addr][255:0] = v[vs2][255:0]

Flags: None modified

Latency: 1 cycle (burst store)

Exception: Alignment error if addr[4:0] != 0

Note: Vector Store Word. Stores 256 bits (8 words) to memory.
      Address must be 32-byte aligned.
```

### 6.3 VADD

```
VADD

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x00

Operands:
    vd, vs1, vs2

Operation:
    for i = 0 to VL-1:
        v[vd][i] = v[vs1][i] + v[vs2][i]

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Vector Add. Element-wise addition of VL elements.
      Uses current VL setting.
```

### 6.4 VSUB

```
VSUB

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x02

Operands:
    vd, vs1, vs2

Operation:
    for i = 0 to VL-1:
        v[vd][i] = v[vs1][i] - v[vs2][i]

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Vector Subtract. Element-wise subtraction of VL elements.
```

### 6.5 VMUL

```
VMUL

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x04

Operands:
    vd, vs1, vs2

Operation:
    for i = 0 to VL-1:
        v[vd][i] = v[vs1][i] * v[vs2][i]

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Vector Multiply. Element-wise multiplication of VL elements.
```

### 6.6 VDOT

```
VDOT

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x10

Operands:
    rd, vs1, vs2

Operation:
    temp = 0
    for i = 0 to VL-1:
        temp = temp + v[vs1][i] * v[vs2][i]
    x[rd] = temp

Flags:
    Z: Set if result is zero
    N: Set if result is negative

Latency: VL cycles (serial accumulation)

Exception: None

Note: Vector Dot Product. Computes sum of element-wise products.
      Result stored in scalar register rd.
```

### 6.7 VRED_SUM

```
VRED_SUM

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x11

Operands:
    rd, vs1

Operation:
    temp = 0
    for i = 0 to VL-1:
        temp = temp + v[vs1][i]
    x[rd] = temp

Flags:
    Z: Set if result is zero
    N: Set if result is negative

Latency: VL cycles (serial accumulation)

Exception: None

Note: Vector Reduce Sum. Computes sum of all elements.
      Result stored in scalar register rd.
```

### 6.8 VSETVL

```
VSETVL

Format:  V-type
Opcode:  0x57
Funct3:  0x00
Funct7:  0x20

Operands:
    vd, vs1

Operation:
    vl = min(x[vs1], 8)
    x[vd] = vl

Flags: None modified

Latency: 1 cycle

Exception: None

Note: Set Vector Length. Sets VL to min(x[vs1], 8).
      Actual VL written to x[vd].
```

---

## 7. Matrix Instructions

### 7.1 MMUL

```
MMUL

Format:  R-type
Opcode:  0x77
Funct3:  0x00
Funct7:  0x00

Operands:
    rs1, rs2

Operation:
    // Load matrices A and B from memory
    A = load_matrix(x[rs1])
    B = load_matrix(x[rs2])
    
    // Compute matrix multiply
    for i = 0 to VLX-1:
        for j = 0 to VLY-1:
            M0[i][j] = 0
            for k = 0 to VLZ-1:
                M0[i][j] += A[i][k] * B[k][j]

Flags: None modified

Latency: max(VLX, VLY, VLZ) cycles (8 cycles for full 8x8, pipelined)

Exception: None

Note: Matrix Multiply. Computes M0 = A × B.
      Matrices loaded from data SRAM at addresses in rs1, rs2.
      Result stored in memory-mapped accumulator M0.
      Dimensions controlled by VLX, VLY, VLZ CSRs.
```

### 7.2 MMAC

```
MMAC

Format:  R-type
Opcode:  0x77
Funct3:  0x00
Funct7:  0x01

Operands:
    rs1, rs2

Operation:
    // Load matrices A and B from memory
    A = load_matrix(x[rs1])
    B = load_matrix(x[rs2])
    
    // Compute matrix multiply-accumulate
    for i = 0 to VLX-1:
        for j = 0 to VLY-1:
            for k = 0 to VLZ-1:
                M0[i][j] += A[i][k] * B[k][j]

Flags: None modified

Latency: max(VLX, VLY, VLZ) cycles (pipelined)

Exception: None

Note: Matrix Multiply-Accumulate. Computes M0 += A × B.
      Accumulates into existing M0 values.
```

### 7.3 MLOAD

```
MLOAD

Format:  I-type
Opcode:  0x77
Funct3:  0x00

Operands:
    rs1

Operation:
    addr = x[rs1]
    for i = 0 to VLY-1:
        for j = 0 to VLX-1:
            M0[i][j] = mem[addr + (i * VLX + j) * 4]

Flags: None modified

Latency: VLX cycles (burst load)

Exception: None

Note: Matrix Load. Loads matrix from memory to M0 accumulator.
      Dimensions controlled by VLX and VLY CSRs.
```

### 7.4 MSTORE

```
MSTORE

Format:  S-type
Opcode:  0x77
Funct3:  0x01

Operands:
    rs1

Operation:
    addr = x[rs1]
    for i = 0 to VLY-1:
        for j = 0 to VLX-1:
            mem[addr + (i * VLX + j) * 4] = M0[i][j]

Flags: None modified

Latency: VLX cycles (burst store)

Exception: None

Note: Matrix Store. Stores matrix from M0 accumulator to memory.
      Dimensions controlled by VLX and VLY CSRs.
```

---

## 8. System Instructions

### 8.1 ECALL

```
ECALL

Format:  I-type
Opcode:  0x73
Funct3:  0x00

Operands:
    None

Operation:
    // Environment call
    // Save PC+4 to EPC
    // Jump to exception handler
    EPC = PC + 4
    ECAUSE = 0x0000000B  // Environment call
    PC = 0x00001000      // Exception vector

Flags: IE cleared (interrupts disabled)

Latency: 3 cycles

Exception: Exception trap

Note: Environment call. Used for system calls and traps.
```

### 8.2 EBREAK

```
EBREAK

Format:  I-type
Opcode:  0x73
Funct3:  0x00

Operands:
    None

Operation:
    // Environment break
    // Save PC to EPC
    // Jump to exception handler
    EPC = PC
    ECAUSE = 0x00000003  // Breakpoint
    PC = 0x00001000      // Exception vector

Flags: IE cleared (interrupts disabled)

Latency: 3 cycles

Exception: Exception trap

Note: Environment break. Used for breakpoints and debugger entry.
```

### 8.3 CSRRW

```
CSRRW

Format:  I-type
Opcode:  0x73
Funct3:  0x01

Operands:
    rd, csr, rs1

Operation:
    temp = CSR[csr]
    CSR[csr] = x[rs1]
    x[rd] = temp

Flags: Modified if SR written

Latency: 1 cycle

Exception: None

Note: CSR Read/Write. Atomic read and write of CSR.
      If rd = x0, CSR is written but not read.
```

---

## 9. Instruction Encoding Summary

### 9.1 Opcode Map

| Opcode | Format | Instructions |
|--------|--------|--------------|
| 0x03 | I-type | LB, LH, LW, LBU, LHU |
| 0x0F | I-type | FENCE (reserved) |
| 0x13 | I-type | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI |
| 0x17 | U-type | AUIPC |
| 0x23 | S-type | SB, SH, SW |
| 0x33 | R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| 0x37 | U-type | LUI |
| 0x57 | V-type | VADD, VSUB, VMUL, VDOT, VRED_SUM, VSETVL |
| 0x63 | B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| 0x67 | I-type | JALR |
| 0x6F | J-type | JAL |
| 0x73 | I-type | ECALL, EBREAK, CSRRW |
| 0x77 | R/I/S | MMUL, MMAC, MLOAD, MSTORE |

### 9.2 Funct3 Encoding

**R-type (opcode 0x33):**
| Funct3 | Funct7 | Instruction |
|--------|--------|-------------|
| 0x00 | 0x00 | ADD |
| 0x00 | 0x20 | SUB |
| 0x01 | 0x00 | SLL |
| 0x02 | 0x00 | SLT |
| 0x03 | 0x00 | SLTU |
| 0x04 | 0x00 | XOR |
| 0x05 | 0x00 | SRL |
| 0x05 | 0x20 | SRA |
| 0x06 | 0x00 | OR |
| 0x07 | 0x00 | AND |

**I-type (opcode 0x13):**
| Funct3 | Funct7 | Instruction |
|--------|--------|-------------|
| 0x00 | - | ADDI |
| 0x01 | 0x00 | SLLI |
| 0x02 | - | SLTI |
| 0x03 | - | SLTIU |
| 0x04 | - | XORI |
| 0x05 | 0x00 | SRLI |
| 0x05 | 0x20 | SRAI |
| 0x06 | - | ORI |
| 0x07 | - | ANDI |

**V-type (opcode 0x57):**
| Funct7 | Instruction |
|--------|-------------|
| 0x00 | VADD |
| 0x02 | VSUB |
| 0x04 | VMUL |
| 0x10 | VDOT |
| 0x11 | VRED_SUM |
| 0x20 | VSETVL |

**Matrix (opcode 0x77):**
| Funct7 | Instruction |
|--------|-------------|
| 0x00 | MMUL |
| 0x01 | MMAC |
| 0x02 | MLOAD |
| 0x03 | MSTORE |

---

## 10. Pseudo-Instructions

### 10.1 Common Pseudo-Instructions

| Pseudo | Expands To | Description |
|--------|------------|-------------|
| NOP | ADD x0, x0, x0 | No operation |
| LI rd, imm | LUI + ADDI | Load immediate (32-bit) |
| MV rd, rs | ADDI rd, rs, 0 | Copy register |
| NOT rd, rs | XORI rd, rs, -1 | Bitwise NOT |
| NEG rd, rs | SUB rd, x0, rs | Negate |
| BEQZ rs, offset | BEQ rs, x0, offset | Branch if zero |
| BNEZ rs, offset | BNE rs, x0, offset | Branch if not zero |
| BLEZ rs, offset | BGE x0, rs, offset | Branch if <= zero |
| BGEZ rs, offset | BGE rs, x0, offset | Branch if >= zero |
| BLTZ rs, offset | BLT rs, x0, offset | Branch if < zero |
| J offset | JAL x0, offset | Jump |
| JR rs | JALR x0, rs, 0 | Jump register |
| RET | JALR x0, x1, 0 | Return from function |
| CALL offset | AUIPC x1, offset[31:12] + JALR x1, x1, offset[11:0] | Call subroutine |

### 10.2 Vector Pseudo-Instructions

| Pseudo | Expands To | Description |
|--------|------------|-------------|
| VNOP | VADD v0, v0, v0 | Vector no-op |
| VMV vd, vs | VADD vd, vs, v0 | Vector copy (v0 = 0) |

### 10.3 Matrix Pseudo-Instructions

| Pseudo | Expands To | Description |
|--------|------------|-------------|
| MCLR | CSRRW x0, 0x100, x0 | Clear matrix accumulator |

---

## 11. Example Encodings

### 11.1 Scalar Examples

```
ADD x5, x6, x7
  funct7 = 0000000
  rs2    = 00111 (x7)
  rs1    = 00110 (x6)
  funct3 = 000
  rd     = 00101 (x5)
  opcode = 0110011

Binary: 0000000 00111 00110 000 00101 0110011
Hex:    0x007302B3

ADDI x5, x6, 42
  imm    = 000000101010 (42)
  rs1    = 00110 (x6)
  funct3 = 000
  rd     = 00101 (x5)
  opcode = 0010011

Binary: 000000101010 00110 000 00101 0010011
Hex:    0x02A30293

LW x5, 8(x6)
  imm    = 000000001000 (8)
  rs1    = 00110 (x6)
  funct3 = 010
  rd     = 00101 (x5)
  opcode = 0000011

Binary: 000000001000 00110 010 00101 0000011
Hex:    0x00832283

BEQ x5, x6, offset (offset = 16 bytes)
  imm[12]   = 0
  imm[10:5] = 000000
  rs2       = 00110 (x6)
  rs1       = 00101 (x5)
  funct3    = 000
  imm[4:1]  = 1000 (8 >> 1 = 4, but offset is 16, so 16>>1 = 8, bits = 01000)
  imm[11]   = 0
  opcode    = 1100011

Wait, let me recalculate. Offset = 16 bytes.
imm[12:1] = 16 >> 1 = 8 = 0b1000
So imm[12] = 0, imm[11] = 0, imm[10:5] = 000000, imm[4:1] = 01000

Binary: 0 000000 00110 00101 000 01000 0 1100011
Hex:    0x00628463
```

### 11.2 Vector Examples

```
VSETVL x5, 4 (set VL = 4)
  imm    = 000000000100 (4)
  rs1    = x0 (if using x0 as source)
  funct3 = 000
  rd     = 00101 (x5)
  opcode = 1010111

Actually, VSETVL uses rs1 as the source of the new VL value.
VSETVL x5 means: set VL from x5, store actual VL to x5

  funct7 = 0000000 (VSETVL opcode)
  vs2    = 00000 (unused)
  vs1    = 00101 (x5)
  funct3 = 000
  vd     = 00101 (x5)
  opcode = 1010111

Binary: 0000000 00000 00101 000 00101 1010111
Hex:    0x000282D7

VADD v0, v1, v2
  funct7 = 0000000
  vs2    = 00010 (v2)
  vs1    = 00001 (v1)
  funct3 = 000
  vd     = 00000 (v0)
  opcode = 1010111

Binary: 0000000 00010 00001 000 00000 1010111
Hex:    0x00208057

VLW v0, 0(x5)
  imm    = 000000000000 (0)
  rs1    = 00101 (x5)
  funct3 = 010
  vd     = 00000 (v0)
  opcode = 0000111

Binary: 000000000000 00101 010 00000 0000111
Hex:    0x0002A007
```

### 11.3 Matrix Examples

```
MMUL (rs1 = x5, rs2 = x6)
  funct7 = 0000000
  rs2    = 00110 (x6)
  rs1    = 00101 (x5)
  funct3 = 000
  rd     = 00000 (unused, set to 0)
  opcode = 1110111

Binary: 0000000 00110 00101 000 00000 1110111
Hex:    0x00628077

MLOAD (rs1 = x5)
  imm    = 000000000000 (0)
  rs1    = 00101 (x5)
  funct3 = 000
  rd     = 00000 (unused)
  opcode = 1110111

Binary: 000000000000 00101 000 00000 1110111
Hex:    0x00028077

MSTORE (rs1 = x5)
  imm    = 000000000000 (0)
  rs1    = 00101 (x5)
  funct3 = 001
  rs2    = 00000 (unused)
  opcode = 1110111

Binary: 0000000 00000 00101 001 00000 1110111
Hex:    0x00029077
```

---

## 12. Verification Plan

### 12.1 Unit Tests

Each instruction should have a dedicated test:

1. **Arithmetic:** Test ADD, ADDI, SUB with edge cases (overflow, carry)
2. **Logic:** Test AND, OR, XOR with all bit patterns
3. **Shifts:** Test SLL, SRL, SRA with shift amounts 0-31
4. **Compare:** Test SLT, SLTU with signed/unsigned boundaries
5. **Memory:** Test LB, LH, LW with aligned/unaligned addresses
6. **Branch:** Test all branch conditions with taken/not-taken
7. **Jump:** Test JAL, JALR with various targets
8. **Vector:** Test VADD, VSUB, VMUL with VL=1,4,8
9. **Matrix:** Test MMUL, MMAC with 1x1, 4x4, 8x8
10. **System:** Test ECALL, EBREAK, CSRRW

### 12.2 Integration Tests

1. Function call/return sequence
2. Loop with branch
3. Vector loop with VL changes
4. Matrix multiply with tiling
5. Interrupt handling

### 12.3 Program Tests

1. Fibonacci (scalar only)
2. Dot product (vector)
3. Matrix multiply (matrix)
4. Simple neural network layer

---

## 13. Open Questions

1. **VTYPE Register:** Should we add a separate VTYPE register for element width, or keep it simple with INT32 only in v0.1?

2. **Vector Masking:** Should we add vector masking (VM) for predicated operations, or defer to v0.2?

3. **Matrix Transpose:** Should MTRANS be included in v0.1, or is software transpose sufficient?

4. **Stride Support:** Should vector load/store support configurable stride, or only contiguous access?

5. **Atomic Operations:** Should we add atomic operations (LR/SC) for future multi-core, or defer entirely?
