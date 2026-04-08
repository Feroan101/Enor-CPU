# ENOR-CPU Binary Encoding

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## 1. Encoding Overview

ENOR-CPU uses fixed 32-bit instruction encoding. All instructions are exactly 32 bits (4 bytes) wide.

### 1.1 Design Principles

1. **Fixed width:** Always 32 bits
2. **Regular fields:** Opcode always in bits [6:0]
3. **Register fields:** 5 bits (up to 32 registers)
4. **Immediate fields:** Sign-extended as needed
5. **RISC-V compatible:** Where possible, use RISC-V encoding

### 1.2 Byte Ordering

Little-endian: Least significant byte at lowest address.

## 2. Instruction Formats

### 2.1 R-type (Register)

Used for register-register operations.

```
 31       25 24    20 19    15 14   12 11     7 6      0
┌──────────┬────────┬────────┬──────┬────────┬────────┐
│  funct7  │  rs2   │  rs1   │funct3│   rd   │ opcode │
│  (7 bits)│(5 bits)│(5 bits)│(3b)  │(5 bits)│(7 bits)│
└──────────┴────────┴────────┴──────┴────────┴────────┘
```

**Fields:**
- `funct7[31:25]` - Function code (extended operation)
- `rs2[24:20]` - Source register 2
- `rs1[19:15]` - Source register 1
- `funct3[14:12]` - Function code (operation type)
- `rd[11:7]` - Destination register
- `opcode[6:0]` - Opcode

### 2.2 I-type (Immediate)

Used for immediate operations and loads.

```
 31           20 19    15 14   12 11     7 6      0
┌──────────────┬────────┬──────┬────────┬────────┐
│   imm[11:0]  │  rs1   │funct3│   rd   │ opcode │
│   (12 bits)  │(5 bits)│(3b)  │(5 bits)│(7 bits)│
└──────────────┴────────┴──────┴────────┴────────┘
```

**Fields:**
- `imm[31:20]` - 12-bit signed immediate
- `rs1[19:15]` - Source register 1
- `funct3[14:12]` - Function code
- `rd[11:7]` - Destination register
- `opcode[6:0]` - Opcode

**Immediate:** Sign-extended from 12 bits to 32 bits.

### 2.3 S-type (Store)

Used for store instructions.

```
 31       25 24    20 19    15 14   12 11     7 6      0
┌──────────┬────────┬────────┬──────┬────────┬────────┐
│imm[11:5] │  rs2   │  rs1   │funct3│imm[4:0]│ opcode │
│ (7 bits) │(5 bits)│(5 bits)│(3b)  │(5 bits)│(7 bits)│
└──────────┴────────┴────────┴──────┴────────┴────────┘
```

**Fields:**
- `imm[31:25]` - Immediate bits [11:5]
- `rs2[24:20]` - Source register 2 (data to store)
- `rs1[19:15]` - Source register 1 (base address)
- `funct3[14:12]` - Function code
- `imm[11:7]` - Immediate bits [4:0]
- `opcode[6:0]` - Opcode

**Immediate:** Reconstructed as `imm = {imm[11:5], imm[4:0]}`, sign-extended.

### 2.4 B-type (Branch)

Used for conditional branches.

```
 31 30       25 24    20 19    15 14   12 11    8  7  6      0
┌──┬──────────┬────────┬────────┬──────┬───────┬──┬────────┐
│12│imm[10:5] │  rs2   │  rs1   │funct3│imm[4:1]│11│ opcode │
│  │ (6 bits) │(5 bits)│(5 bits)│(3b)  │(4 bits)│  │(7 bits)│
└──┴──────────┴────────┴────────┴──────┴───────┴──┴────────┘
```

**Fields:**
- `imm[31]` - Immediate bit 12
- `imm[30:25]` - Immediate bits [10:5]
- `rs2[24:20]` - Source register 2
- `rs1[19:15]` - Source register 1
- `funct3[14:12]` - Function code
- `imm[11:8]` - Immediate bits [4:1]
- `imm[7]` - Immediate bit 11
- `opcode[6:0]` - Opcode

**Immediate:** Reconstructed as `imm = {imm[31], imm[7], imm[30:25], imm[11:8], 1'b0}`, sign-extended.
The immediate is always a multiple of 2 (bit 0 is always 0).

### 2.5 U-type (Upper Immediate)

Used for LUI and AUIPC.

```
 31                                 12 11     7 6      0
┌────────────────────────────────────┬────────┬────────┐
│         imm[31:12]                 │   rd   │ opcode │
│           (20 bits)                │(5 bits)│(7 bits)│
└────────────────────────────────────┴────────┴────────┘
```

**Fields:**
- `imm[31:12]` - 20-bit upper immediate
- `rd[11:7]` - Destination register
- `opcode[6:0]` - Opcode

**Immediate:** `imm << 12` (shifted left by 12 bits).

### 2.6 J-type (Jump)

Used for JAL.

```
 31 30       21 20 19        12 11     7 6      0
┌──┬──────────┬──┬────────────┬────────┬────────┐
│20│imm[10:1] │11│ imm[19:12] │   rd   │ opcode │
│  │ (10 bits)│  │  (8 bits)  │(5 bits)│(7 bits)│
└──┴──────────┴──┴────────────┴────────┴────────┘
```

**Fields:**
- `imm[31]` - Immediate bit 20
- `imm[30:21]` - Immediate bits [10:1]
- `imm[20]` - Immediate bit 11
- `imm[19:12]` - Immediate bits [19:12]
- `rd[11:7]` - Destination register
- `opcode[6:0]` - Opcode

**Immediate:** Reconstructed as `imm = {imm[31], imm[19:12], imm[20], imm[30:21], 1'b0}`, sign-extended.
The immediate is always a multiple of 2 (bit 0 is always 0).

### 2.7 V-type (Vector)

Used for vector operations.

```
 31       25 24    20 19    15 14   12 11     7 6      0
┌──────────┬────────┬────────┬──────┬────────┬────────┐
│  funct7  │  vs2   │  vs1   │funct3│   vd   │ opcode │
│  (7 bits)│(5 bits)│(5 bits)│(3b)  │(5 bits)│(7 bits)│
└──────────┴────────┴────────┴──────┴────────┴────────┘
```

**Fields:**
- `funct7[31:25]` - Function code (vector operation)
- `vs2[24:20]` - Vector source register 2
- `vs1[19:15]` - Vector source register 1
- `funct3[14:12]` - Function code
- `vd[11:7]` - Vector destination register
- `opcode[6:0]` - Opcode

**Note:** Same format as R-type, but with vector register fields.

## 3. Opcode Map

### 3.1 Opcode Assignment

| Opcode | Binary | Format | Category |
|--------|--------|--------|----------|
| 0x00 | 0000000 | - | Reserved |
| 0x03 | 0000011 | I-type | Load |
| 0x0F | 0001111 | I-type | Fence (reserved) |
| 0x13 | 0010011 | I-type | Arithmetic/Logic (imm) |
| 0x17 | 0010111 | U-type | AUIPC |
| 0x23 | 0100011 | S-type | Store |
| 0x33 | 0110011 | R-type | Arithmetic/Logic (reg) |
| 0x37 | 0110111 | U-type | LUI |
| 0x57 | 1010111 | V-type | Vector |
| 0x63 | 1100011 | B-type | Branch |
| 0x67 | 1100111 | I-type | JALR |
| 0x6F | 1101111 | J-type | JAL |
| 0x73 | 1110011 | I-type | System |
| 0x77 | 1110111 | R/I/S | Matrix |

### 3.2 Opcode Ranges

```
0x00-0x0F: Loads and reserved
0x10-0x1F: Arithmetic/Logic (immediate)
0x20-0x2F: Stores
0x30-0x3F: Arithmetic/Logic (register)
0x40-0x4F: Reserved
0x50-0x5F: Vector
0x60-0x6F: Branches and jumps
0x70-0x7F: System and Matrix
```

## 4. Funct3 Encoding

### 4.1 Load (opcode 0x03)

| Funct3 | Instruction | Size | Signed |
|--------|-------------|------|--------|
| 0x00 | LB | Byte | Yes |
| 0x01 | LH | Half | Yes |
| 0x02 | LW | Word | - |
| 0x04 | LBU | Byte | No |
| 0x05 | LHU | Half | No |

### 4.2 Store (opcode 0x23)

| Funct3 | Instruction | Size |
|--------|-------------|------|
| 0x00 | SB | Byte |
| 0x01 | SH | Half |
| 0x02 | SW | Word |

### 4.3 Arithmetic/Logic (opcode 0x13, 0x33)

| Funct3 | R-type (0x33) | I-type (0x13) |
|--------|---------------|---------------|
| 0x00 | ADD/SUB | ADDI |
| 0x01 | SLL | SLLI |
| 0x02 | SLT | SLTI |
| 0x03 | SLTU | SLTIU |
| 0x04 | XOR | XORI |
| 0x05 | SRL/SRA | SRLI/SRAI |
| 0x06 | OR | ORI |
| 0x07 | AND | ANDI |

### 4.4 Branch (opcode 0x63)

| Funct3 | Instruction | Condition |
|--------|-------------|-----------|
| 0x00 | BEQ | rs1 == rs2 |
| 0x01 | BNE | rs1 != rs2 |
| 0x04 | BLT | rs1 < rs2 (signed) |
| 0x05 | BGE | rs1 >= rs2 (signed) |
| 0x06 | BLTU | rs1 < rs2 (unsigned) |
| 0x07 | BGEU | rs1 >= rs2 (unsigned) |

### 4.5 Vector (opcode 0x57)

| Funct3 | Description |
|--------|-------------|
| 0x00 | Vector arithmetic |

### 4.6 System (opcode 0x73)

| Funct3 | Instruction |
|--------|-------------|
| 0x00 | ECALL/EBREAK |
| 0x01 | CSRRW |

### 4.7 Matrix (opcode 0x77)

| Funct3 | Description |
|--------|-------------|
| 0x00 | Matrix multiply |
| 0x01 | Matrix store |

## 5. Funct7 Encoding

### 5.1 R-type (opcode 0x33)

| Funct7 | Funct3 | Instruction |
|--------|--------|-------------|
| 0x00 | 0x00 | ADD |
| 0x20 | 0x00 | SUB |
| 0x00 | 0x01 | SLL |
| 0x00 | 0x02 | SLT |
| 0x00 | 0x03 | SLTU |
| 0x00 | 0x04 | XOR |
| 0x00 | 0x05 | SRL |
| 0x20 | 0x05 | SRA |
| 0x00 | 0x06 | OR |
| 0x00 | 0x07 | AND |

### 5.2 I-type Shifts (opcode 0x13)

| Funct7 | Funct3 | Instruction |
|--------|--------|-------------|
| 0x00 | 0x01 | SLLI |
| 0x00 | 0x05 | SRLI |
| 0x20 | 0x05 | SRAI |

**Note:** For SLLI, SRLI, SRAI, the immediate field contains the shift amount, and bits [11:5] must be 0x00 or 0x20.

### 5.3 Vector (opcode 0x57)

| Funct7 | Instruction |
|--------|-------------|
| 0x00 | VADD |
| 0x02 | VSUB |
| 0x04 | VMUL |
| 0x10 | VDOT |
| 0x11 | VRED_SUM |
| 0x20 | VSETVL |

### 5.4 Matrix (opcode 0x77)

| Funct7 | Instruction |
|--------|-------------|
| 0x00 | MMUL |
| 0x01 | MMAC |
| 0x02 | MLOAD |
| 0x03 | MSTORE |

## 6. Immediate Encoding

### 6.1 I-type Immediate

12-bit signed immediate, range: -2048 to 2047.

```
 31                          20
┌──────────────────────────────┐
│      imm[11:0]               │
│    (12-bit signed)           │
└──────────────────────────────┘

Sign-extended to 32 bits:
  imm_32 = {{20{imm[11]}}, imm[11:0]}
```

### 6.2 S-type Immediate

12-bit signed immediate, split across two fields.

```
 31       25                 11      7
┌──────────┐                 ┌────────┐
│ imm[11:5]│                 │imm[4:0]│
│ (7 bits) │                 │(5 bits)│
└──────────┘                 └────────┘

Reconstructed:
  imm = {imm[11:5], imm[4:0]}
  imm_32 = {{20{imm[11]}}, imm[11:0]}
```

### 6.3 B-type Immediate

13-bit signed immediate (multiple of 2), split across four fields.

```
 31 30       25            11    8  7
┌──┬──────────┐            ┌───────┐──┐
│12│ imm[10:5]│            │imm[4:1]│11│
└──┴──────────┘            └───────┘──┘

Reconstructed:
  imm = {imm[31], imm[7], imm[30:25], imm[11:8], 1'b0}
  imm_32 = {{19{imm[31]}}, imm[31], imm[7], imm[30:25], imm[11:8], 1'b0}
```

### 6.4 U-type Immediate

20-bit upper immediate, shifted left by 12.

```
 31                                12
┌────────────────────────────────────┐
│         imm[31:12]                 │
│           (20 bits)                │
└────────────────────────────────────┘

Result:
  imm_32 = {imm[31:12], 12'b0}
```

### 6.5 J-type Immediate

21-bit signed immediate (multiple of 2), split across four fields.

```
 31 30       21 20 19        12
┌──┬──────────┬──┬────────────┐
│20│ imm[10:1]│11│ imm[19:12] │
└──┴──────────┴──┴────────────┘

Reconstructed:
  imm = {imm[31], imm[19:12], imm[20], imm[30:21], 1'b0}
  imm_32 = {{11{imm[31]}}, imm[31], imm[19:12], imm[20], imm[30:21], 1'b0}
```

## 7. Register Field Encoding

### 7.1 Scalar Registers

5-bit register specifier, 0-31.

| Encoding | Register | ABI Name |
|----------|----------|----------|
| 00000 | x0 | zero |
| 00001 | x1 | ra |
| 00010 | x2 | sp |
| 00011 | x3 | gp |
| 00100 | x4 | tp |
| 00101 | x5 | t0 |
| 00110 | x6 | t1 |
| 00111 | x7 | t2 |
| 01000 | x8 | s0 |
| 01001 | x9 | s1 |
| 01010 | x10 | a0 |
| 01011 | x11 | a1 |
| 01100 | x12 | a2 |
| 01101 | x13 | a3 |
| 01110 | x14 | a4 |
| 01111 | x15 | a5 |
| 10000 | x16 | a6 |
| 10001 | x17 | a7 |
| 10010 | x18 | s2 |
| 10011 | x19 | s3 |
| 10100 | x20 | s4 |
| 10101 | x21 | s5 |
| 10110 | x22 | s6 |
| 10111 | x23 | s7 |
| 11000 | x24 | s8 |
| 11001 | x25 | s9 |
| 11010 | x26 | s10 |
| 11011 | x27 | s11 |
| 11100 | x28 | t3 |
| 11101 | x29 | t4 |
| 11110 | x30 | t5 |
| 11111 | x31 | t6 |

### 7.2 Vector Registers

5-bit vector register specifier, 0-15.

| Encoding | Register |
|----------|----------|
| 00000 | v0 |
| 00001 | v1 |
| 00010 | v2 |
| 00011 | v3 |
| 00100 | v4 |
| 00101 | v5 |
| 00110 | v6 |
| 00111 | v7 |
| 01000 | v8 |
| 01001 | v9 |
| 01010 | v10 |
| 01011 | v11 |
| 01100 | v12 |
| 01101 | v13 |
| 01110 | v14 |
| 01111 | v15 |

**Note:** Bits [31:28] of vs1, vs2, vd must be 0 for v0.1.

## 8. Reserved Encodings

### 8.1 Reserved Opcodes

| Opcode | Status |
|--------|--------|
| 0x00 | Reserved |
| 0x01-0x02 | Reserved |
| 0x04-0x0E | Reserved |
| 0x10-0x12 | Reserved |
| 0x14-0x16 | Reserved |
| 0x18-0x22 | Reserved |
| 0x24-0x32 | Reserved |
| 0x34-0x36 | Reserved |
| 0x38-0x56 | Reserved |
| 0x58-0x62 | Reserved |
| 0x64-0x66 | Reserved |
| 0x68-0x6E | Reserved |
| 0x70-0x72 | Reserved |
| 0x74-0x76 | Reserved |
| 0x78-0x7F | Reserved |

### 8.2 Reserved Funct3/Funct7

Reserved funct3 or funct7 combinations within an opcode will cause an illegal instruction exception.

### 8.3 Reserved Registers

- Scalar register encoding 0-31: All valid
- Vector register encoding 0-15: Valid
- Vector register encoding 16-31: Reserved (bits [31:28] of vs1/vs2/vd must be 0)

## 9. Encoding Verification

### 9.1 Decoder Truth Table

The decoder can be implemented as a simple truth table:

```
case (opcode)
    7'b0000011: // Load
        case (funct3)
            3'b000: LB
            3'b001: LH
            3'b010: LW
            3'b100: LBU
            3'b101: LHU
            default: ILLEGAL
        endcase
    7'b0010011: // I-type ALU
        case (funct3)
            3'b000: ADDI
            3'b001: SLLI
            3'b010: SLTI
            3'b011: SLTIU
            3'b100: XORI
            3'b101: case (funct7)
                7'b0000000: SRLI
                7'b0010000: SRAI
                default: ILLEGAL
            endcase
            3'b110: ORI
            3'b111: ANDI
        endcase
    7'b0100011: // Store
        case (funct3)
            3'b000: SB
            3'b001: SH
            3'b010: SW
            default: ILLEGAL
        endcase
    7'b0110011: // R-type ALU
        case ({funct7, funct3})
            10'b0000000_000: ADD
            10'b0100000_000: SUB
            10'b0000000_001: SLL
            10'b0000000_010: SLT
            10'b0000000_011: SLTU
            10'b0000000_100: XOR
            10'b0000000_101: SRL
            10'b0100000_101: SRA
            10'b0000000_110: OR
            10'b0000000_111: AND
            default: ILLEGAL
        endcase
    7'b0110111: LUI
    7'b0010111: AUIPC
    7'b1100011: // Branch
        case (funct3)
            3'b000: BEQ
            3'b001: BNE
            3'b100: BLT
            3'b101: BGE
            3'b110: BLTU
            3'b111: BGEU
            default: ILLEGAL
        endcase
    7'b1100111: JALR
    7'b1101111: JAL
    7'b1110011: // System
        case (funct3)
            3'b000: case (imm[11:0])
                12'b000000000000: ECALL
                12'b000000000001: EBREAK
                default: ILLEGAL
            endcase
            3'b001: CSRRW
            default: ILLEGAL
        endcase
    7'b1010111: // Vector
        case (funct7)
            7'b0000000: VADD
            7'b0000010: VSUB
            7'b0000100: VMUL
            7'b0010000: VDOT
            7'b0010001: VRED_SUM
            7'b0100000: VSETVL
            default: ILLEGAL
        endcase
    7'b1110111: // Matrix
        case ({funct7, funct3})
            {7'b0000000, 3'b000}: MMUL
            {7'b0000001, 3'b000}: MMAC
            {7'b0000010, 3'b000}: MLOAD
            {7'b0000011, 3'b001}: MSTORE
            default: ILLEGAL
        endcase
    default: ILLEGAL
endcase
```

### 9.2 Encoding Anomalies

1. **VSETVL:** Uses funct7 = 0x20, VDOT uses funct7 = 0x10. No conflict.

2. **MSTORE:** Uses S-type format but opcode 0x77 is shared with R-type matrix ops.
   - **Solution:** Use funct3 to distinguish (0x00 for R-type, 0x01 for S-type).

## 10. Example Encoding Walkthrough

### 10.1 ADD x5, x6, x7

```
Instruction: ADD x5, x6, x7
Format: R-type
Opcode: 0x33 (ADD/SUB)
Funct3: 0x00
Funct7: 0x00

Fields:
  funct7 = 0000000
  rs2    = 00111 (x7)
  rs1    = 00110 (x6)
  funct3 = 000
  rd     = 00101 (x5)
  opcode = 0110011

Binary: 0000000 00111 00110 000 00101 0110011
       |funct7 | rs2  | rs1  |f3  |  rd  |opcode|

Hex: 0000000 00111 00110 000 00101 0110011
    = 0000 0000 0111 0011 0000 0010 1011 0011
    = 0x007302B3
```

### 10.2 ADDI x5, x6, 42

```
Instruction: ADDI x5, x6, 42
Format: I-type
Opcode: 0x13 (I-type ALU)
Funct3: 0x00

Fields:
  imm    = 000000101010 (42)
  rs1    = 00110 (x6)
  funct3 = 000
  rd     = 00101 (x5)
  opcode = 0010011

Binary: 000000101010 00110 000 00101 0010011
       |   imm      | rs1  |f3  |  rd  |opcode|

Hex: 0000 0010 1010 0011 0000 0010 1001 0011
   = 0x02A30293
```

### 10.3 LW x5, 8(x6)

```
Instruction: LW x5, 8(x6)
Format: I-type
Opcode: 0x03 (Load)
Funct3: 0x02 (LW)

Fields:
  imm    = 000000001000 (8)
  rs1    = 00110 (x6)
  funct3 = 010
  rd     = 00101 (x5)
  opcode = 0000011

Binary: 000000001000 00110 010 00101 0000011
       |   imm      | rs1  |f3  |  rd  |opcode|

Hex: 0000 0000 1000 0011 0010 0010 1000 0011
   = 0x00832283
```

### 10.4 BEQ x5, x6, 16

```
Instruction: BEQ x5, x6, 16
Format: B-type
Opcode: 0x63 (Branch)
Funct3: 0x00 (BEQ)

Offset: 16 bytes
imm[12:1] = 16 >> 1 = 8 = 0b1000

Fields:
  imm[12]   = 0
  imm[10:5] = 000000
  rs2       = 00110 (x6)
  rs1       = 00101 (x5)
  funct3    = 000
  imm[4:1]  = 01000 (8 >> 1 = 4, but 16 >> 1 = 8, so 01000)
  imm[11]   = 0
  opcode    = 1100011

Wait, let me recalculate:
Offset = 16
imm[12:1] = 16 / 2 = 8 = 0b000000001000

imm[12] = 0
imm[11] = 0
imm[10:5] = 000000
imm[4:1] = 01000 (8 in binary, but we need 4 bits for [4:1])

Actually: imm[12:1] = 8 = 0b000000001000
So:
  imm[12] = 0
  imm[11] = 0
  imm[10:5] = 000000 (bits 10:5 of 8 = 0)
  imm[4:1] = 01000 (bits 4:1 of 8 = 0b1000, but that's 4 bits)

Wait, 8 = 0b1000, which is 4 bits. So imm[4:1] = 01000? No, that's 5 bits.

Let me think again:
imm[12:1] is a 12-bit field representing the offset divided by 2.
Offset = 16, so imm[12:1] = 8 = 0b000000001000

imm[12] = bit 12 of imm[12:1] = 0
imm[11] = bit 11 of imm[12:1] = 0
imm[10:5] = bits 10:5 of imm[12:1] = 000000
imm[4:1] = bits 4:1 of imm[12:1] = 01000 (which is 8 >> 1 = 4, so 0b0100)

Actually, I'm confusing myself. Let me use the formula:
imm[12:1] = offset / 2 = 16 / 2 = 8 = 0b000000001000

So:
imm[12] = 0
imm[11] = 0
imm[10:5] = 000000 (bits 10:5 of 0b000000001000)
imm[4:1] = 01000 (bits 4:1 of 0b000000001000)

But bits 4:1 of 0b000000001000 are:
bit 4 = 0
bit 3 = 1
bit 2 = 0
bit 1 = 0
So imm[4:1] = 0b0100 = 4

Hmm, I think I'm making this too complicated. Let me just use the formula from the RISC-V spec:

For B-type:
imm[12:1] = offset / 2

offset = 16
imm[12:1] = 8 = 0b000000001000

imm[12] = 0
imm[11] = 0
imm[10:5] = 000000
imm[4:1] = 01000 (which is 8 in 4 bits, but that's wrong)

Actually, imm[4:1] is 4 bits, so it can represent 0-15.
8 in 4 bits is 0b1000, but that's only valid if we're counting from 0.

I think the issue is that imm[4:1] is bits 4:1 of the 12-bit immediate, not the value.
imm[12:1] = 0b000000001000

imm[4:1] = bits 4:1 of this = 0b0100 = 4

So:
imm[12] = 0
imm[11] = 0
imm[10:5] = 000000
imm[4:1] = 0100

Binary: 0 000000 00110 00101 000 0100 0 1100011

Hex: 0 000000 00110 00101 000 0100 0 1100011
   = 0000 0000 0110 0010 1000 0100 0110 0011
   = 0x00628463
```

## 11. Encoding Tools

### 11.1 Bit Field Calculator

For quick reference, here are the bit positions:

```
31 30 29 28 27 26 25 24 23 22 21 20 19 18 17 16 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
│  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │  │
└──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
 7  6  5  4  3  2  1  0                                                                          
                                                                                                  
R-type: funct7[31:25] rs2[24:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]                 
I-type: imm[11:0][31:20] rs1[19:15] funct3[14:12] rd[11:7] opcode[6:0]                         
S-type: imm[11:5][31:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[4:0][11:7] opcode[6:0]       
B-type: imm[12][31] imm[10:5][30:25] rs2[24:20] rs1[19:15] funct3[14:12] imm[4:1][11:8] imm[11][7] opcode[6:0]
U-type: imm[31:12][31:12] rd[11:7] opcode[6:0]                                                
J-type: imm[20][31] imm[10:1][30:21] imm[11][20] imm[19:12][19:12] rd[11:7] opcode[6:0]       
```

### 11.2 Mask Table

| Field | Bits | Mask |
|-------|------|------|
| opcode | [6:0] | 0x7F |
| rd | [11:7] | 0xF80 |
| funct3 | [14:12] | 0x7000 |
| rs1 | [19:15] | 0xF8000 |
| rs2 | [24:20] | 0x1F00000 |
| funct7 | [31:25] | 0xFE000000 |

## 12. Encoding Validation

### 12.1 Valid Encoding Check

```python
def is_valid_encoding(instruction):
    opcode = instruction & 0x7F
    funct3 = (instruction >> 12) & 0x7
    funct7 = (instruction >> 25) & 0x7F
    
    # Check opcode
    if opcode not in VALID_OPCODES:
        return False
    
    # Check funct3
    if funct3 not in VALID_FUNCT3[opcode]:
        return False
    
    # Check funct7
    if opcode in VALID_FUNCT7 and funct7 not in VALID_FUNCT7[opcode]:
        return False
    
    return True
```

### 12.2 Common Encoding Errors

1. **Wrong opcode:** Most common error
2. **Wrong funct3/funct7:** Causes wrong instruction
3. **Unaligned immediate:** B-type and J-type must be even
4. **Register out of range:** Vector registers > 15
5. **Reserved encoding:** Will cause illegal instruction exception
