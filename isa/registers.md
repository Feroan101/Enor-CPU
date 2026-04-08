# ENOR-CPU Register Specification

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## 1. Register Overview

ENOR-CPU has three classes of architecturally visible registers:

1. **Scalar Registers** - 32 general-purpose 32-bit registers
2. **Vector Registers** - 16 general-purpose 256-bit registers
3. **Special Registers** - Program counter and status register

Matrix operations use a memory-mapped accumulator (not architecturally visible).

## 2. Scalar Registers

### 2.1 General-Purpose Registers

```
┌─────────────────────────────────────────────────────────────┐
│                   Scalar Register File                       │
│                                                              │
│  ┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐        │
│  │ x0  │ x1  │ x2  │ x3  │ x4  │ x5  │ x6  │ x7  │        │
│  │zero │ ra  │ sp  │ gp  │ tp  │ t0  │ t1  │ t2  │        │
│  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤        │
│  │ x8  │ x9  │ x10 │ x11 │ x12 │ x13 │ x14 │ x15 │        │
│  │ s0  │ s1  │ a0  │ a1  │ a2  │ a3  │ a4  │ a5  │        │
│  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤        │
│  │ x16 │ x17 │ x18 │ x19 │ x20 │ x21 │ x22 │ x23 │        │
│  │ a6  │ a7  │ s2  │ s3  │ s4  │ s5  │ s6  │ s7  │        │
│  ├─────┼─────┼─────┼─────┼─────┼─────┼─────┼─────┤        │
│  │ x24 │ x25 │ x26 │ x27 │ x28 │ x29 │ x30 │ x31 │        │
│  │ s8  │ s9  │ s10 │ s11 │ t3  │ t4  │ t5  │ t6  │        │
│  └─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘        │
│                                                              │
│  Width: 32 bits per register                                │
│  Total: 32 registers = 1024 bits                            │
│  Ports: 2 read, 1 write                                     │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Register Descriptions

| Register | ABI Name | Width | Description |
|----------|----------|-------|-------------|
| x0 | zero | 32 | Hardwired to 0 (reads return 0, writes ignored) |
| x1 | ra | 32 | Return address |
| x2 | sp | 32 | Stack pointer |
| x3 | gp | 32 | Global pointer (optional) |
| x4 | tp | 32 | Thread pointer (reserved) |
| x5-x7 | t0-t2 | 32 | Temporaries (caller-saved) |
| x8-x9 | s0-s1 | 32 | Saved registers (callee-saved) |
| x10-x11 | a0-a1 | 32 | Function arguments / return values |
| x12-x17 | a2-a7 | 32 | Function arguments (caller-saved) |
| x18-x27 | s2-s11 | 32 | Saved registers (callee-saved) |
| x28-x31 | t3-t6 | 32 | Temporaries (caller-saved) |

### 2.3 Calling Convention

**Arguments:**
- a0-a1 (x10-x11): First two arguments and return values
- a2-a7 (x12-x17): Additional arguments

**Return Values:**
- a0 (x10): Primary return value
- a1 (x11): Secondary return value (64-bit returns)

**Saved Registers:**
- s0-s11 (x8-x9, x18-x27): Callee-saved, preserved across calls

**Temporary Registers:**
- t0-t6 (x5-x7, x28-x31): Caller-saved, not preserved

**Special Registers:**
- ra (x1): Return address for function calls
- sp (x2): Stack pointer, decremented on entry, restored on exit

### 2.4 Stack Frame

```
High Address
┌─────────────────┐
│  Previous Frame  │
├─────────────────┤
│  Return Address  │  (if needed)
├─────────────────┤
│  Saved s0-s11   │  (if needed)
├─────────────────┤
│  Local Variables │
├─────────────────┤
│  Temporary Space │
└─────────────────┘
         ▲
         │ sp (x2)
Low Address
```

### 2.5 x0 Behavior

x0 is hardwired to zero:
- **Read:** Always returns 0x00000000
- **Write:** Ignored (no state change)
- **Use cases:** Constant zero, nop (ADD x0, x0, x0)

## 3. Vector Registers

### 3.1 Register File

```
┌─────────────────────────────────────────────────────────────┐
│                   Vector Register File                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  v0  [255:0]  - Vector register 0                   │   │
│  │  v1  [255:0]  - Vector register 1                   │   │
│  │  v2  [255:0]  - Vector register 2                   │   │
│  │  ...                                                 │   │
│  │  v15 [255:0]  - Vector register 15                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Width: 256 bits per register                               │
│  Total: 16 registers = 4096 bits                            │
│  Ports: 2 read, 1 write                                     │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Element Organization

Vector registers hold multiple elements based on element width:

| Element Type | Elements | Bits per Element | Total Bits |
|--------------|----------|------------------|------------|
| INT8 | 8 | 8 | 64 (packed into 256-bit reg) |
| INT16 | 4 | 16 | 64 (packed into 256-bit reg) |
| INT32 | 2 | 32 | 64 (packed into 256-bit reg) |

**Note:** Vector registers are always 256 bits wide. Element width determines how many elements are processed per operation.

### 3.3 Element Indexing

Elements are indexed from LSB (element 0) to MSB:

```
Vector Register (256 bits):
┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│ [7] │ [6] │ [5] │ [4] │ [3] │ [2] │ [1] │ [0] │  INT32 (8 elements)
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
 255   223   191   159   127    95    63    31     0

┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│     │     │     │     │[3]  │[2]  │[1]  │[0]  │  INT16 (4 elements, lower 64 bits)
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
 255   223   191   159   127    95    63    31     0

┌─────┬─────┬─────┬─────┬─────┬─────┬─────┬─────┐
│     │     │     │     │     │     │[1]  │[0]  │  INT8 (2 elements, lower 64 bits)
└─────┴─────┴─────┴─────┴─────┴─────┴─────┴─────┘
 255   223   191   159   127    95    63    31     0
```

### 3.4 Vector Length Register (VL)

The vector length register controls how many elements are processed per vector operation.

```
┌─────────────────────────────────────────────────────────────┐
│                   Vector Length Register (VL)                │
│                                                              │
│  Width: 32 bits (only lower 3 bits used)                    │
│  Valid values: 1-8                                          │
│  Default: 8                                                  │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Bits [31:3] │ Bits [2:0]                           │   │
│  │    Reserved  │ Vector Length (1-8)                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Usage:                                                      │
│    VSETVL x5          # Set VL = x[5] (1-8)               │
│    VADD v0, v1, v2    # Process VL elements               │
└─────────────────────────────────────────────────────────────┘
```

### 3.5 Vector Register Usage

**Vector Operations:**
- Two source registers (vs1, vs2)
- One destination register (vd)
- Operates on VL elements

**Example:**
```
VSETVL x5          # Set VL = value in x5 (e.g., 4)
VADD v0, v1, v2    # v0[0..3] = v1[0..3] + v2[0..3]
```

### 3.6 Vector Register ABI

No formal ABI for vector registers in v0.1. Compiler allocates as needed.

## 4. Special Registers

### 4.1 Program Counter (PC)

```
┌─────────────────────────────────────────────────────────────┐
│                   Program Counter (PC)                       │
│                                                              │
│  Width: 32 bits                                             │
│  Alignment: 4-byte (bits [1:0] always 00)                  │
│  Initial value: 0x00000000                                 │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Bits [31:2] │ Bits [1:0]                           │   │
│  │    PC[31:2]  │   00 (always)                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Updated by:                                                │
│    - Sequential: PC = PC + 4                               │
│    - Branch: PC = PC + imm                                 │
│    - Jump: PC = target                                      │
│    - Exception: PC = handler address                       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Status Register (SR)

```
┌─────────────────────────────────────────────────────────────┐
│                   Status Register (SR)                       │
│                                                              │
│  Width: 32 bits                                             │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Bits [31:8] │ [7] │ [6] │ [5] │ [4] │ [3:0]      │   │
│  │   Reserved   │ IE  │  -  │  -  │  -  │  Flags      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Flags (bits [3:0]):                                        │
│    Bit 0: Z (Zero)       - Last ALU result was zero        │
│    Bit 1: C (Carry)      - Last ALU operation carried      │
│    Bit 2: V (Overflow)   - Last ALU operation overflowed   │
│    Bit 3: N (Negative)   - Last ALU result was negative    │
│                                                              │
│  Interrupt Enable (bit 7):                                  │
│    IE = 1: Interrupts enabled                              │
│    IE = 0: Interrupts disabled                             │
│                                                              │
│  Reserved bits: Read as 0, write ignored                    │
└─────────────────────────────────────────────────────────────┘
```

**Flag Behavior:**

| Operation | Z | C | V | N |
|-----------|---|---|---|---|
| ADD | r==0 | carry | overflow | r[31] |
| SUB | r==0 | borrow | overflow | r[31] |
| AND | r==0 | 0 | 0 | r[31] |
| OR | r==0 | 0 | 0 | r[31] |
| XOR | r==0 | 0 | 0 | r[31] |
| Shift | r==0 | last bit out | 0 | r[31] |

### 4.3 Control/Status Registers (CSR)

CSR registers are accessed via CSRRW, CSRRS, CSRRC instructions.

```
┌─────────────────────────────────────────────────────────────┐
│                   CSR Register Space                         │
│                                                              │
│  Address  │ Name    │ Width │ Description                   │
│  ─────────┼─────────┼───────┼─────────────────────────────  │
│  0x000    │ SR      │ 32    │ Status register               │
│  0x001    │ VL      │ 32    │ Vector length                 │
│  0x002    │ VLX     │ 32    │ Matrix dimension X            │
│  0x003    │ VLY     │ 32    │ Matrix dimension Y            │
│  0x004    │ VLZ     │ 32    │ Matrix depth                  │
│  0x010    │ EPC     │ 32    │ Exception program counter     │
│  0x011    │ ECAUSE  │ 32    │ Exception cause               │
│  0x020    │ IE      │ 32    │ Interrupt enable              │
│  0x021    │ IPRIO   │ 32    │ Interrupt priority            │
│  0x100    │ M0_ADDR │ 32    │ Matrix accumulator address    │
│  0x101    │ M0_DIMX │ 32    │ Matrix dimension X            │
│  0x102    │ M0_DIMY │ 32    │ Matrix dimension Y            │
│  ─────────┴─────────┴───────┴─────────────────────────────  │
│                                                              │
│  CSR addresses are 12-bit (0x000-0xFFF)                    │
│  Only addresses 0x000-0x102 are implemented in v0.1        │
│  All other addresses return 0                               │
└─────────────────────────────────────────────────────────────┘
```

## 5. Matrix Accumulator

### 5.1 Memory-Mapped Accumulator

Matrix operations use a memory-mapped accumulator register file. This is NOT architecturally visible as a register but is accessed via special memory addresses.

```
┌─────────────────────────────────────────────────────────────┐
│                   Matrix Accumulator (M0)                    │
│                                                              │
│  Size: 8 x 8 x 32 bits = 2048 bits                        │
│  Access: Memory-mapped to data SRAM                        │
│                                                              │
│  Memory Map:                                                │
│    0x4000_0000 - M0[0][0] (32 bits)                        │
│    0x4000_0004 - M0[0][1] (32 bits)                        │
│    ...                                                      │
│    0x4000_00FC - M0[7][7] (32 bits)                        │
│                                                              │
│  Organization:                                              │
│    Row-major order                                          │
│    M0[row][col] = base + (row * 8 + col) * 4              │
│                                                              │
│  Total size: 256 bytes                                      │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Matrix Operation Flow

1. Load matrix A from memory to data SRAM
2. Load matrix B from memory to data SRAM
3. Execute MMUL or MMAC instruction
4. Result accumulated in M0
5. Store result from M0 to memory

### 5.3 Matrix Dimension Registers

| CSR | Name | Description |
|-----|------|-------------|
| 0x002 | VLX | Matrix X dimension (columns) |
| 0x003 | VLY | Matrix Y dimension (rows) |
| 0x004 | VLZ | Matrix depth (accumulate dimension) |

These control the size of matrix operations:
- VLX: Number of columns in A and C (1-8)
- VLY: Number of rows in A and C (1-8)
- VLZ: Number of columns in B (1-8), also accumulation depth

## 6. Reset State

On hardware reset, all registers are initialized to:

| Register | Reset Value | Notes |
|----------|-------------|-------|
| x0 | 0x00000000 | Hardwired |
| x1-x31 | Undefined | Must be initialized by software |
| v0-v15 | Undefined | Must be initialized by software |
| PC | 0x00000000 | Start of code space |
| SR | 0x00000000 | Interrupts disabled |
| VL | 0x00000008 | 8 elements |
| VLX | 0x00000008 | 8 columns |
| VLY | 0x00000008 | 8 rows |
| VLZ | 0x00000008 | 8 depth |

## 7. Context Switch

On interrupt, hardware saves:
- PC → EPC (CSR 0x010)
- SR → saved (interrupts disabled)

Software must save:
- x1-x31 (31 registers × 4 bytes = 124 bytes)
- v0-v15 (16 registers × 32 bytes = 512 bytes)
- VL, VLX, VLY, VLZ (16 bytes)

Total context save: ~652 bytes

## 8. Verification Notes

Each register class can be verified independently:

1. **Scalar registers:** Test read/write to all 32 registers, verify x0 is always 0
2. **Vector registers:** Test read/write to all 16 registers, verify element indexing
3. **PC:** Test sequential updates, branches, jumps
4. **SR:** Test flag generation for all ALU operations
5. **CSR:** Test read/write to all implemented CSRs
6. **Matrix accumulator:** Test memory-mapped access
