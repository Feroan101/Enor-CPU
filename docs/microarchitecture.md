# ENOR-CPU Microarchitecture Specification

**Version:** 0.1-draft  
**Status:** Design Phase  
**Last Updated:** 2026-08-24

## 1. Overview

This document describes the microarchitectural implementation of the ENOR-CPU architecture. The design targets FPGA implementation with emphasis on simplicity, verifiability, and reasonable performance for AI workloads.

## 2. Pipeline Organization

### 2.1 Scalar Pipeline

The scalar control unit uses a classic 5-stage in-order pipeline:

```
┌─────────┬─────────┬─────────┬─────────┬─────────┐
│   IF    │   ID    │   EX    │   MEM   │   WB    │
│         │         │         │         │         │
│ Fetch   │ Decode  │ Execute │ Memory  │ Write   │
│ instruc │ instruc │ ALU ops │ access  │ back    │
│ tion    │ tion    │         │         │         │
└─────────┴─────────┴─────────┴─────────┴─────────┘
    │         │         │         │         │
    │    ┌────┴────┐    │         │    ┌────┴────┐
    │    │ Register │    │         │    │ Register │
    │    │ File     │    │         │    │ File     │
    │    │ Read     │    │         │    │ Write    │
    │    └─────────┘    │         │    └─────────┘
    │                   │         │
    │              ┌────┴────┐    │
    │              │  Data   │    │
    │              │  Memory │    │
    │              │  SRAM   │    │
    │              └─────────┘    │
    │                             │
    └─────────────────────────────┘
         (Fetch/Load path)
```

**Stage Descriptions:**

| Stage | Name | Function |
|-------|------|----------|
| IF | Instruction Fetch | Fetch 32-bit instruction from code SRAM |
| ID | Instruction Decode | Decode instruction, read register file |
| EX | Execute | ALU operation, address calculation, branch resolution |
| MEM | Memory Access | Data memory read/write |
| WB | Write Back | Write result to register file |

### 2.2 Pipeline Characteristics

- **Depth:** 5 stages
- **Issue width:** 1 instruction per cycle (scalar)
- **Execution:** In-order, no speculation
- **Hazards:** Stalled, not speculated

## 3. Fetch/Decode/Execute Flow

### 3.1 Instruction Fetch

```
┌─────────────────────────────────────────────────────────────┐
│                    Instruction Fetch                         │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │   PC    │────>│  Code   │────>│  Fetch  │              │
│  │  Register│     │  SRAM   │     │  Buffer │              │
│  └─────────┘     └─────────┘     └─────────┘              │
│       │                              │                      │
│       │         ┌─────────┐         │                      │
│       └────────>│  Branch │<────────┘                      │
│                 │  Adder  │                                 │
│                 └─────────┘                                 │
└─────────────────────────────────────────────────────────────┘
```

**Operation:**
1. PC presented to code SRAM
2. Instruction read from SRAM
3. Instruction latched into fetch buffer
4. PC updated (PC+4 or branch target)

**Key Features:**
- Single-cycle fetch (no stall on hit)
- Branch resolved in EX stage (2-cycle penalty)
- No branch prediction in v0.1

### 3.2 Instruction Decode

```
┌─────────────────────────────────────────────────────────────┐
│                   Instruction Decode                         │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │  Fetch  │────>│ Decoder │────>│ Control │              │
│  │  Buffer │     │  Logic  │     │ Signals │              │
│  └─────────┘     └─────────┘     └─────────┘              │
│                       │                                     │
│                  ┌────┴────┐                                │
│                  │ Register │                                │
│                  │ File     │                                │
│                  │ (Read)   │                                │
│                  └─────────┘                                │
└─────────────────────────────────────────────────────────────┘
```

**Operation:**
1. Instruction fields extracted
2. Opcode decoded to determine instruction type
3. Register file read ports activated
4. Control signals generated for EX, MEM, WB stages
5. Immediate values extracted and sign-extended

**Control Signals Generated:**
- ALU operation code
- Register write enable
- Memory read/write
- Branch type
- Immediate select
- Vector/matrix operation codes

### 3.3 Execute

```
┌─────────────────────────────────────────────────────────────┐
│                      Execute                                 │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │  Source │────>│   ALU   │────>│  Branch │              │
│  │  Mux    │     │         │     │  Logic  │              │
│  └─────────┘     └─────────┘     └─────────┘              │
│       │                              │                      │
│  ┌────┴────┐                    ┌────┴────┐                │
│  │  Imm    │                    │  Next   │                │
│  │  Gen    │                    │  PC     │                │
│  └─────────┘                    └─────────┘                │
└─────────────────────────────────────────────────────────────┘
```

**Operation:**
1. ALU operands selected (register or immediate)
2. ALU operation performed
3. Branch condition evaluated
4. Next PC calculated (PC+4 or target)

**ALU Operations:**
- Arithmetic: ADD, SUB
- Logic: AND, OR, XOR
- Shift: SLL, SRL, SRA
- Compare: SLT, SLTU

### 3.4 Memory Access

```
┌─────────────────────────────────────────────────────────────┐
│                   Memory Access                              │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │  ALU    │────>│ Address │────>│  Data   │              │
│  │  Result │     │  Calc   │     │  SRAM   │              │
│  └─────────┘     └─────────┘     └─────────┘              │
│                       │                                     │
│                  ┌────┴────┐                                │
│                  │  Store  │                                │
│                  │  Data   │                                │
│                  │  Mux    │                                │
│                  └─────────┘                                │
└─────────────────────────────────────────────────────────────┘
```

**Operation:**
1. ALU result used as memory address
2. Store data selected from register file
3. Memory read or write performed
4. Read data latched for WB stage

**Memory Operations:**
- LB: Load byte, sign-extend
- LH: Load halfword, sign-extend
- LW: Load word
- LBU: Load byte unsigned
- LHU: Load halfword unsigned
- SB: Store byte
- SH: Store halfword
- SW: Store word

### 3.5 Write Back

```
┌─────────────────────────────────────────────────────────────┐
│                     Write Back                               │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │ Memory  │────>│  WB     │────>│ Register │              │
│  │  Data   │     │  Mux    │     │  File    │              │
│  └─────────┘     └─────────┘     │  (Write) │              │
│       │                          └─────────┘                │
│  ┌────┴────┐                                                │
│  │  ALU    │                                                │
│  │  Result │                                                │
│  └─────────┘                                                │
└─────────────────────────────────────────────────────────────┘
```

**Operation:**
1. Result selected from ALU or memory
2. Destination register decoded
3. Register file write performed

## 4. Register File

### 4.1 Scalar Register File

```
┌─────────────────────────────────────────────────────────────┐
│                   Scalar Register File                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  32 registers x 32 bits = 1024 bits                 │   │
│  │                                                      │   │
│  │  x0 (zero) - Hardwired to 0                         │   │
│  │  x1-x31    - General purpose                        │   │
│  │                                                      │   │
│  │  Ports:                                              │   │
│  │    Read 1:  rs1 -> data1                             │   │
│  │    Read 2:  rs2 -> data2                             │   │
│  │    Write:   rd <- data_write                         │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Implementation: 2-read, 1-write, write-first semantics    │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- 2 read ports (combinational read)
- 1 write port (synchronous write, rising edge)
- Write-first: if read and write to same register, write takes precedence
- x0 hardwired to 0 (writes ignored)

### 4.2 Vector Register File

```
┌─────────────────────────────────────────────────────────────┐
│                   Vector Register File                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  16 registers x 256 bits = 4096 bits                │   │
│  │                                                      │   │
│  │  v0-v15    - General purpose vector registers       │   │
│  │                                                      │   │
│  │  Each register holds:                                │   │
│  │    - 8 x INT32, or                                   │   │
│  │    - 4 x INT64, or                                   │   │
│  │    - 16 x INT16, or                                  │   │
│  │    - 32 x INT8                                       │   │
│  │                                                      │   │
│  │  Ports:                                              │   │
│  │    Read 1:  vs1 -> vdata1                            │   │
│  │    Read 2:  vs2 -> vdata2                            │   │
│  │    Write:   vd <- vdata_write                        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Implementation: 2-read, 1-write, write-first semantics    │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- 256-bit datapath width
- Configurable vector length via VL register
- Lane-based operation (each lane handles one element)
- Write-first semantics

### 4.3 Matrix Register File

The matrix unit uses a memory-mapped accumulator rather than a traditional register file:

```
┌─────────────────────────────────────────────────────────────┐
│                  Matrix Accumulator                          │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  M0: 8x8 accumulator                                │   │
│  │                                                      │   │
│  │  Total size: 8 x 8 x 32 bits = 2048 bits           │   │
│  │                                                      │   │
│  │  Memory-mapped to: 0x4000_0000 - 0x4000_07FF       │   │
│  │                                                      │   │
│  │  Organization:                                       │   │
│  │    Row 0: M0[0][0..7]                               │   │
│  │    Row 1: M0[1][0..7]                               │   │
│  │    ...                                               │   │
│  │    Row 7: M0[7][0..7]                               │   │
│  │                                                      │   │
│  │  Dual-port access for matrix operations             │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 4.4 Special Registers

```
┌─────────────────────────────────────────────────────────────┐
│                   Special Registers                          │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  PC (32-bit): Program Counter                       │   │
│  │    - Updated every cycle (unless stalled)           │   │
│  │    - Aligned to 4-byte boundary                     │   │
│  │                                                      │   │
│  │  SR (32-bit): Status Register                       │   │
│  │    - Bit 0: Zero flag (Z)                           │   │
│  │    - Bit 1: Carry flag (C)                          │   │
│  │    - Bit 2: Overflow flag (V)                       │   │
│  │    - Bit 3: Negative flag (N)                       │   │
│  │    - Bit 8: Interrupt enable (IE)                   │   │
│  │    - Bits 31:16: Reserved                          │   │
│  │                                                      │   │
│  │  VL (32-bit): Vector Length                         │   │
│  │    - Values 1-8 valid                               │   │
│  │    - Default: 8                                     │   │
│  │                                                      │   │
│  │  VLX (32-bit): Matrix Dimension X (columns)        │   │
│  │    - Values 1-8 valid                               │   │
│  │    - Default: 8                                     │   │
│  │                                                      │   │
│  │  VLY (32-bit): Matrix Dimension Y (rows)           │   │
│  │    - Values 1-8 valid                               │   │
│  │    - Default: 8                                     │   │
│  │                                                      │   │
│  │  VLZ (32-bit): Matrix Depth (accumulate dim)       │   │
│  │    - Values 1-8 valid                               │   │
│  │    - Default: 8                                     │   │
│  │                                                      │   │
│  │  STRIDE (32-bit): Memory Stride                    │   │
│  │    - Byte stride for vector load/store              │   │
│  │    - Default: 4 (contiguous words)                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Access: Via CSR instructions (CSRRW, CSRRS, CSRRC)       │
└─────────────────────────────────────────────────────────────┘
```

## 5. ALU

### 5.1 Scalar ALU

```
┌─────────────────────────────────────────────────────────────┐
│                      Scalar ALU                              │
│                                                              │
│  Input A ──────┐                                            │
│                │                                            │
│           ┌────┴────┐                                       │
│           │ Operand │                                       │
│           │  Mux    │                                       │
│           └────┬────┘                                       │
│                │                                            │
│           ┌────┴────┐                                       │
│           │   ALU   │                                       │
│           │  Core   │                                       │
│           └────┬────┘                                       │
│                │                                            │
│           ┌────┴────┐                                       │
│           │  Flags  │──────> Z, C, V, N                    │
│           │  Write  │                                       │
│           └────┬────┘                                       │
│                │                                            │
│  Result ───────┘                                            │
│                                                              │
│  Operations:                                                │
│    - ADD (A + B)                                            │
│    - SUB (A - B)                                            │
│    - AND (A & B)                                            │
│    - OR  (A | B)                                            │
│    - XOR (A ^ B)                                            │
│    - SLL (A << B[4:0])                                     │
│    - SRL (A >> B[4:0])                                     │
│    - SRA (A >>> B[4:0])                                    │
│    - SLT (A < B ? 1 : 0)                                   │
│    - SLTU (A < B unsigned ? 1 : 0)                         │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- 32-bit datapath
- Single-cycle operation
- Generates status flags (Z, C, V, N)
- No multi-cycle operations (no multiplier in v0.1)

### 5.2 Vector ALU

```
┌─────────────────────────────────────────────────────────────┐
│                      Vector ALU                              │
│                                                              │
│  ┌─────┐  ┌─────┐  ┌─────┐       ┌─────┐                  │
│  │Lane0│  │Lane1│  │Lane2│  ...  │Lane7│                  │
│  │     │  │     │  │     │       │     │                  │
│  │ ALU │  │ ALU │  │ ALU │       │ ALU │                  │
│  └──┬──┘  └──┬──┘  └──┬──┘       └──┬──┘                  │
│     │        │        │              │                      │
│     └────────┴────────┴──────────────┘                      │
│                    │                                        │
│              ┌─────┴─────┐                                  │
│              │  Reduction │                                  │
│              │  Unit      │                                  │
│              └───────────┘                                  │
│                                                              │
│  Each Lane:                                                 │
│    - 32-bit ALU                                             │
│    - Operates on single element                             │
│    - Configurable element width (8/16/32 bits)             │
│                                                              │
│  Reduction Unit:                                            │
│    - Combines lane results for dot product, sum, etc.      │
│    - Multi-cycle operation                                  │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- 8 parallel lanes
- Each lane: 32-bit integer ALU
- Element width configurable via VL and type registers
- Reduction unit combines lane results

### 5.3 Matrix ALU

```
┌─────────────────────────────────────────────────────────────┐
│                      Matrix ALU                              │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              8x8 Multiply Array                      │   │
│  │                                                      │   │
│  │    ┌───┐ ┌───┐ ┌───┐       ┌───┐                  │   │
│  │    │M00│ │M01│ │M02│  ...  │M07│  Row 0           │   │
│  │    └───┘ └───┘ └───┘       └───┘                  │   │
│  │    ┌───┐ ┌───┐ ┌───┐       ┌───┐                  │   │
│  │    │M10│ │M11│ │M12│  ...  │M17│  Row 1           │   │
│  │    └───┘ └───┘ └───┘       └───┘                  │   │
│  │      .     .     .     .     .                      │   │
│  │    ┌───┐ ┌───┐ ┌───┐       ┌───┐                  │   │
│  │    │M70│ │M71│ │M72│  ...  │M77│  Row 7           │   │
│  │    └───┘ └───┘ └───┘       └───┘                  │   │
│  │                                                      │   │
│  │  Each M_ij:                                          │   │
│  │    - 8-bit x 8-bit → 32-bit multiply                │   │
│  │    - 32-bit accumulator                              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Accumulator Buffer                      │   │
│  │    - 8 x 32-bit registers per row                   │   │
│  │    - Total: 2048 bits                                │   │
│  │    - Dual-port for read/write                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- 8x8 INT8 multiply-accumulate array
- 32-bit accumulation per element
- Single-cycle MAC per row
- 8 cycles to complete 8x8 matrix multiply
- Accumulator can be read/written via memory-mapped interface

## 6. Load/Store Unit

### 6.1 LSU Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Load/Store Unit                            │
│                                                              │
│  ┌─────────┐     ┌─────────┐     ┌─────────┐              │
│  │ Address │────>│  Align  │────>│  Data   │              │
│  │  Calc   │     │  Logic  │     │  Path   │              │
│  └─────────┘     └─────────┘     └─────────┘              │
│       │               │               │                     │
│  ┌────┴────┐    ┌────┴────┐    ┌────┴────┐                │
│  │  Base   │    │  Byte   │    │  Scalar │                │
│  │  + Imm  │    │  Enable │    │  /Vec   │                │
│  │         │    │         │    │  Mux    │                │
│  └─────────┘    └─────────┘    └─────────┘                │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │                 Vector Load Path                      │   │
│  │    - Burst read: 256 bits per cycle                  │   │
│  │    - Stride support: configurable byte stride        │   │
│  │    - Alignment: word-aligned for simplicity          │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 Address Calculation

**Address Modes:**
- Base + immediate (I-type): `addr = rs1 + imm`
- Base + offset (S-type): `addr = rs1 + imm`
- Base + register (R-type): `addr = rs1 + rs2` (for indexed access)

**Alignment:**
- Word access: 4-byte aligned
- Halfword access: 2-byte aligned
- Byte access: any alignment
- Unaligned access: causes alignment exception (v0.1)

### 6.3 Memory Interface

```
┌─────────────────────────────────────────────────────────────┐
│                 Memory Interface                             │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Scalar Port (32-bit)                               │   │
│  │    - Single word access                             │   │
│  │    - 1 cycle latency                                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Vector Port (256-bit)                              │   │
│  │    - Burst access                                   │   │
│  │    - 256 bits per cycle                             │   │
│  │    - 1 cycle latency                                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Matrix Port (512-bit)                              │   │
│  │    - 8 words per cycle                              │   │
│  │    - For matrix tile loads                          │   │
│  │    - 1 cycle latency                                │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 7. Memory Subsystem

### 7.1 Memory Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                    Memory Hierarchy                           │
│                                                              │
│  Level 0: Register Files                                    │
│    - Scalar: 32 x 32-bit = 1 KB                           │
│    - Vector: 16 x 256-bit = 4 KB                          │
│    - Matrix: 8x8 x 32-bit = 2 KB                          │
│    - Latency: 0 cycles (combinational read)                │
│                                                              │
│  Level 1: SRAM (On-chip)                                    │
│    - Code SRAM: 32 KB (1-way)                              │
│    - Data SRAM: 64 KB (1-way)                              │
│    - Matrix SRAM: 32 KB (dual-port)                        │
│    - Vector SRAM: 16 KB (4-bank)                           │
│    - Latency: 1 cycle                                      │
│                                                              │
│  Level 2: External Memory (optional)                        │
│    - Connected via memory controller                       │
│    - Latency: Variable (10-100 cycles)                     │
│    - Not implemented in v0.1                               │
└─────────────────────────────────────────────────────────────┘
```

### 7.2 SRAM Organization

#### Code SRAM (32 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Code SRAM                                 │
│                                                              │
│  Size: 32 KB = 8192 x 32-bit words                         │
│  Ports: 1 read (instruction fetch)                          │
│  Latency: 1 cycle                                           │
│  Organization: Single-port                                  │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Address [14:2]  →  32-bit instruction              │   │
│  │  (12-bit word address, 4KB pages)                   │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Data SRAM (64 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Data SRAM                                 │
│                                                              │
│  Size: 64 KB = 16384 x 32-bit words                        │
│  Ports: 1 read, 1 write (dual-port)                        │
│  Latency: 1 cycle                                           │
│  Organization: Dual-port                                    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Port A: Read/Write (scalar access)                 │   │
│  │  Port B: Read only (vector load)                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Byte enable: 4-bit (supports byte, half, word access)     │
└─────────────────────────────────────────────────────────────┘
```

#### Matrix SRAM (32 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                   Matrix SRAM                                │
│                                                              │
│  Size: 32 KB = 8192 x 32-bit words                         │
│  Ports: 2 (dual-port for matrix operations)                 │
│  Latency: 1 cycle                                           │
│  Organization: Dual-port, banked                            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Port A: Read (weight loading)                      │   │
│  │  Port B: Write (result storage)                     │   │
│  │                                                      │   │
│  │  Tile organization:                                 │   │
│  │    - 8x8 tile = 256 bytes                          │   │
│  │    - Up to 128 tiles (32KB / 256B)                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

#### Vector SRAM (16 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Vector SRAM                               │
│                                                              │
│  Size: 16 KB = 4096 x 32-bit words                         │
│  Ports: 4 banks (independent access)                        │
│  Latency: 1 cycle                                           │
│  Organization: 4-bank, 4 KB per bank                        │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Bank 0: 4 KB  [0x0000 - 0x0FFF]                  │   │
│  │  Bank 1: 4 KB  [0x1000 - 0x1FFF]                  │   │
│  │  Bank 2: 4 KB  [0x2000 - 0x2FFF]                  │   │
│  │  Bank 3: 4 KB  [0x3000 - 0x3FFF]                  │   │
│  │                                                      │   │
│  │  Interleaved by address bits [13:12]               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Supports parallel access from vector lanes                │
└─────────────────────────────────────────────────────────────┘
```

## 8. Control Logic

### 8.1 Pipeline Control

```
┌─────────────────────────────────────────────────────────────┐
│                   Pipeline Control                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Hazard Detection Unit                               │   │
│  │    - Data hazards (RAW, WAR, WAW)                   │   │
│  │    - Control hazards (branches)                      │   │
│  │    - Memory hazards (load-use)                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Forwarding Unit                                     │   │
│  │    - EX → EX forwarding                             │   │
│  │    - MEM → EX forwarding                            │   │
│  │    - WB → EX forwarding                             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Stall Logic                                        │   │
│  │    - Load-use hazard: 1-cycle stall                 │   │
│  │    - Branch taken: 2-cycle flush                    │   │
│  │    - Memory conflict: stall until free              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 8.2 Hazard Detection Rules

**Data Hazards (RAW):**
```
if (EX_regwrite && EX_rd != 0 && EX_rd == ID_rs1) then
    stall pipeline, forward from EX
if (MEM_regwrite && MEM_rd != 0 && MEM_rd == ID_rs1) then
    forward from MEM
```

**Load-Use Hazard:**
```
if (EX_memread && EX_rd != 0 && (EX_rd == ID_rs1 || EX_rd == ID_rs2)) then
    stall 1 cycle, insert bubble
```

**Control Hazard (Branch):**
```
if (branch_taken) then
    flush IF and ID stages
    load branch target into PC
```

### 8.3 Forwarding Paths

```
┌─────────────────────────────────────────────────────────────┐
│                   Forwarding Network                         │
│                                                              │
│  EX Stage                                                   │
│    ┌─────────┐                                              │
│    │  ALU    │──forward──> EX/MEM pipeline register         │
│    └─────────┘                                              │
│         │                                                   │
│         └──forward──> ID/EX pipeline register (bypass)      │
│                                                              │
│  MEM Stage                                                  │
│    ┌─────────┐                                              │
│    │ Memory  │──forward──> MEM/WB pipeline register         │
│    └─────────┘                                              │
│         │                                                   │
│         └──forward──> ID/EX pipeline register (bypass)      │
│                                                              │
│  WB Stage                                                   │
│    ┌─────────┐                                              │
│    │  Mux    │──forward──> Register File                    │
│    └─────────┘                                              │
└─────────────────────────────────────────────────────────────┘
```

## 9. Data Paths

### 9.1 Scalar Data Path

```
┌─────────────────────────────────────────────────────────────┐
│                   Scalar Data Path                            │
│                                                              │
│                     ┌─────────┐                              │
│                     │   PC    │                              │
│                     └────┬────┘                              │
│                          │                                  │
│                     ┌────┴────┐                              │
│                     │   +4    │                              │
│                     └────┬────┘                              │
│                          │                                  │
│  ┌───────────────────────┴───────────────────────┐         │
│  │                     Mux                        │         │
│  │  (select PC+4 or branch target)               │         │
│  └───────────────────────┬───────────────────────┘         │
│                          │                                  │
│                     ┌────┴────┐                              │
│                     │  Code   │                              │
│                     │  SRAM   │                              │
│                     └────┬────┘                              │
│                          │                                  │
│                     ┌────┴────┐                              │
│                     │ Instr   │                              │
│                     │ Decode  │                              │
│                     └────┬────┘                              │
│                          │                                  │
│              ┌───────────┴───────────┐                      │
│              │                       │                      │
│         ┌────┴────┐            ┌────┴────┐                 │
│         │ Reg File│            │  Imm    │                 │
│         │ (Read)  │            │  Gen    │                 │
│         └────┬────┘            └────┬────┘                 │
│              │                       │                      │
│              └───────────┬───────────┘                      │
│                          │                                  │
│                     ┌────┴────┐                              │
│                     │   ALU   │                              │
│                     └────┬────┘                              │
│                          │                                  │
│              ┌───────────┴───────────┐                      │
│              │                       │                      │
│         ┌────┴────┐            ┌────┴────┐                 │
│         │  Data   │            │ Address │                 │
│         │  SRAM   │            │  Calc   │                 │
│         └────┬────┘            └─────────┘                 │
│              │                                              │
│         ┌────┴────┐                                         │
│         │  WB Mux │                                         │
│         └────┬────┘                                         │
│              │                                              │
│         ┌────┴────┐                                         │
│         │ Reg File│                                         │
│         │ (Write) │                                         │
│         └─────────┘                                         │
└─────────────────────────────────────────────────────────────┘
```

### 9.2 Vector Data Path

```
┌─────────────────────────────────────────────────────────────┐
│                   Vector Data Path                            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Vector Register File                                │   │
│  │    - 2 read ports, 1 write port                     │   │
│  │    - 256-bit datapath                               │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                  │
│         ┌────────────────┴────────────────┐                │
│         │                                  │                │
│    ┌────┴────┐                        ┌────┴────┐          │
│    │ Vector  │                        │ Vector  │          │
│    │ Lane 0  │                        │ Lane 7  │          │
│    │  ┌───┐  │           ...          │  ┌───┐  │          │
│    │  │ALU│  │                        │  │ALU│  │          │
│    │  └───┘  │                        │  └───┘  │          │
│    └────┬────┘                        └────┬────┘          │
│         │                                  │                │
│         └────────────────┬────────────────┘                │
│                          │                                  │
│                    ┌─────┴─────┐                            │
│                    │ Reduction │                            │
│                    │    Unit   │                            │
│                    └─────┬─────┘                            │
│                          │                                  │
│                    ┌─────┴─────┐                            │
│                    │   Result  │                            │
│                    └───────────┘                            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Vector Load Path                                    │   │
│  │    - Burst read from Vector SRAM                     │   │
│  │    - 256 bits per cycle                             │   │
│  │    - Stride support                                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 9.3 Matrix Data Path

```
┌─────────────────────────────────────────────────────────────┐
│                   Matrix Data Path                            │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Matrix SRAM (Weight Storage)                        │   │
│  │    - 32 KB                                          │   │
│  │    - Dual-port                                      │   │
│  └───────────────────────┬─────────────────────────────┘   │
│                          │                                  │
│                     ┌────┴────┐                              │
│                     │  Weight │                              │
│                     │  Buffer │                              │
│                     │ (8x8)   │                              │
│                     └────┬────┘                              │
│                          │                                  │
│  ┌───────────────────────┴───────────────────────┐         │
│  │              8x8 Multiply Array                │         │
│  │  ┌─────┐┌─────┐┌─────┐     ┌─────┐          │         │
│  │  │ M00 ││ M01 ││ M02 │ ... │ M07 │ Row 0    │         │
│  │  └─────┘└─────┘└─────┘     └─────┘          │         │
│  │  ┌─────┐┌─────┐┌─────┐     ┌─────┐          │         │
│  │  │ M10 ││ M11 ││ M12 │ ... │ M17 │ Row 1    │         │
│  │  └─────┘└─────┘└─────┘     └─────┘          │         │
│  │    .       .       .     .     .              │         │
│  │  ┌─────┐┌─────┐┌─────┐     ┌─────┐          │         │
│  │  │ M70 ││ M71 ││ M72 │ ... │ M77 │ Row 7    │         │
│  │  └─────┘└─────┘└─────┘     └─────┘          │         │
│  └───────────────────────┬───────────────────────┘         │
│                          │                                  │
│  ┌───────────────────────┴───────────────────────┐         │
│  │              Accumulator Buffer                 │         │
│  │    - 8 rows x 8 columns x 32-bit              │         │
│  │    - Read/Write via memory-mapped interface     │         │
│  └───────────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 10. Clock and Reset

### 10.1 Clock

```
┌─────────────────────────────────────────────────────────────┐
│                    Clock Domain                              │
│                                                              │
│  Single clock domain for all v0.1 components                │
│                                                              │
│  Target frequency: 50 MHz (FPGA)                            │
│  Minimum period: 20 ns                                       │
│                                                              │
│  Clock sources:                                             │
│    - External oscillator (FPGA board)                       │
│    - PLL-generated (if needed)                              │
│                                                              │
│  Clock enables:                                             │
│    - Global clock gate for low-power mode (v0.2)           │
└─────────────────────────────────────────────────────────────┘
```

### 10.2 Reset

```
┌─────────────────────────────────────────────────────────────┐
│                    Reset Strategy                            │
│                                                              │
│  Asynchronous active-low reset (standard for FPGA)         │
│                                                              │
│  Reset affects:                                             │
│    - PC → 0x00000000                                        │
│    - Pipeline registers → flushed                          │
│    - Status register → interrupts disabled                 │
│    - Vector length → 8 (default)                           │
│    - Matrix dimensions → 8x8 (default)                     │
│    - All other registers → undefined                       │
│                                                              │
│  Reset sequence:                                            │
│    1. Assert reset (low)                                   │
│    2. Hold for 16 clock cycles                            │
│    3. De-assert reset (high)                               │
│    4. PC starts at 0x00000000                             │
│    5. Execution begins                                     │
└─────────────────────────────────────────────────────────────┘
```

## 11. Hazard Handling

### 11.1 Summary of Hazards

| Hazard Type | Detection | Resolution | Penalty |
|-------------|-----------|------------|---------|
| Data (RAW) | EX stage | Forwarding | 0 cycles |
| Load-use | EX stage | Stall + forward | 1 cycle |
| Control (branch) | EX stage | Flush + redirect | 2 cycles |
| Memory conflict | MEM stage | Stall | Variable |

### 11.2 Forwarding Conditions

```
// Forward from EX/MEM
if (ex_mem_regwrite && ex_mem_rd != 0) begin
    if (ex_mem_rd == id_ex_rs1)
        forward_a = 2'b10;  // EX/MEM → ID/EX
    if (ex_mem_rd == id_ex_rs2)
        forward_b = 2'b10;
end

// Forward from MEM/WB
if (mem_wb_regwrite && mem_wb_rd != 0) begin
    if (mem_wb_rd == id_ex_rs1)
        forward_a = 2'b01;  // MEM/WB → ID/EX
    if (mem_wb_rd == id_ex_rs2)
        forward_b = 2'b01;
end
```

### 11.3 Branch Handling

```
// Branch resolution in EX stage
if (branch_taken) begin
    // Flush IF and ID stages
    if_id_flush = 1'b1;
    if_id_insert_bubble = 1'b1;
    
    // Load branch target
    pc_next = branch_target;
    
    // Penalty: 2 cycles (IF and ID flushed)
end
```

## 12. Instruction Latency

### 12.1 Scalar Instructions

| Instruction | Latency | Notes |
|-------------|---------|-------|
| ALU (R/I-type) | 1 cycle | Single-cycle execute |
| Load | 2 cycles | 1 for address, 1 for memory |
| Store | 2 cycles | 1 for address, 1 for write |
| Branch (taken) | 3 cycles | 1 fetch, 1 decode, 1 redirect |
| Branch (not taken) | 1 cycle | Proceeds normally |
| JAL | 2 cycles | 1 fetch, 1 redirect |
| JALR | 3 cycles | 1 fetch, 1 decode, 1 redirect |

### 12.2 Vector Instructions

| Instruction | Latency | Throughput |
|-------------|---------|------------|
| VADD.VV | 1 cycle | 8 ops/cycle |
| VSUB.VV | 1 cycle | 8 ops/cycle |
| VMUL.VV | 1 cycle | 8 ops/cycle |
| VDOT | 8 cycles | 1 result/8 cycles |
| VRED_SUM | 8 cycles | 1 result/8 cycles |

### 12.3 Matrix Instructions

| Instruction | Latency | Throughput |
|-------------|---------|------------|
| MMUL (8x8) | 8 cycles | 1 matrix/8 cycles |
| MMAC | 8 cycles | 1 matrix/8 cycles |
| MLOAD | 4 cycles | 8 words/4 cycles |
| MSTORE | 4 cycles | 8 words/4 cycles |

## 13. Throughput Considerations

### 13.1 Instruction Throughput

**Scalar:** 1 instruction/cycle (ideal)
**Vector:** 8 operations/cycle (8-lane SIMD)
**Matrix:** 64 MACs/cycle (8x8 array)

### 13.2 Bottlenecks

1. **Memory bandwidth** - Most critical for AI workloads
2. **Matrix SRAM bandwidth** - Limited to 512 bits/cycle
3. **Vector SRAM bandwidth** - Limited to 256 bits/cycle
4. **Register file ports** - Limits instruction-level parallelism

### 13.3 Performance Model

For an 8x8 matrix multiply:
- Load weights: 8 cycles (32 KB → matrix SRAM)
- Compute: 8 cycles (8x8 MAC array)
- Store results: 8 cycles (store 8 rows)
- Total: ~24 cycles per 8x8 matrix

**Effective throughput:** ~2.67 matrices/cycle = ~137 INT8 MACs/cycle at 50 MHz

## 14. Implementation Notes

### 14.1 FPGA Resource Estimates

| Resource | Estimated Usage |
|----------|-----------------|
| LUTs | 8,000 - 12,000 |
| FFs | 4,000 - 6,000 |
| BRAM | 8 - 12 (36Kb blocks) |
| DSPs | 16 - 32 (for MAC array) |
| Fmax | 50-100 MHz |

### 14.2 Target FPGA

- **Xilinx Artix-7 (XC7A100T)** or equivalent
- **Lattice ECP5** as alternative
- **Intel Cyclone V** as alternative

### 14.3 Verification Strategy

1. **Unit tests** - Each module independently tested
2. **Integration tests** - Pipeline interaction tests
3. **System tests** - Full program execution tests
4. **Compliance tests** - ISA compliance verification
5. **AI workload tests** - Matrix multiply, convolutions

## 15. Open Questions

1. **Branch prediction** - Add in v0.2? (2-cycle penalty may be acceptable)
2. **Cache** - Add instruction cache? (depends on code size)
3. **DMA** - Add in v0.2? (helps with data movement)
4. **Interrupt latency** - How fast must interrupts be serviced?
5. **Power management** - Clock gating needed?
