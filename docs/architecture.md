# ENOR-CPU Architecture Specification

**Version:** 0.1-draft  
**Status:** Design Phase  
**Last Updated:** 2026-08-24

## 1. Design Goals

ENOR-CPU is designed as a hardware-native execution target for the Enor programming language, optimized for AI/ML workloads while remaining implementable by a single engineer on FPGA.

### Primary Goals

1. **Implementability** - Small enough for one person to implement, verify, and debug
2. **Simplicity** - Minimal complexity, no speculative execution or out-of-order logic
3. **Verifiability** - Straightforward to test and validate correctness
4. **AI Utility** - First-class support for matrix multiply, vector operations, and quantized arithmetic
5. **FPGA Feasibility** - Targets mid-range FPGA (Xilinx Artix-7 or similar)

### Non-Goals (v0.1)

- High-frequency operation (>100 MHz on FPGA)
- Multi-core or multi-threading
- Advanced branch prediction
- Cache coherency
- Virtual memory
- Full IEEE 754 floating-point (deferred to later versions)

## 2. Target Workloads

ENOR-CPU targets inference-phase AI workloads with emphasis on:

| Workload | Priority | Notes |
|----------|----------|-------|
| Matrix multiplication | High | Core of neural network layers |
| Vector element-wise ops | High | Activation functions, normalization |
| Convolution | High | 2D convolution via im2col or direct |
| Reductions | Medium | Sum, mean, max, min operations |
| Quantized inference | High | INT8/INT16 operations |
| Data movement | High | Transpose, reshape, padding |
| Activation functions | Medium | ReLU, sigmoid, tanh (lookup or approx) |

### Workload Characteristics

- **Data parallelism** dominates over task parallelism
- **Memory bound** operations are common (data movement, element-wise ops)
- **Compute bound** operations center on matrix multiply
- **Deterministic execution** preferred for reproducibility

## 3. Design Philosophy

ENOR-CPU adopts a **separation of concerns** approach:

- **Scalar Control Unit** - Handles program flow, control logic, address generation
- **Vector Unit** - Handles element-wise and reduction operations
- **Matrix Unit** - Handles dense matrix multiplication
- **Data Movement Engine** - Handles memory operations, transposes, reshapes

This is not a general-purpose CPU with AI extensions bolted on. It is an AI-oriented processor with general-purpose control capabilities.

## 4. CPU Architecture

### 4.1 Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                          ENOR-CPU                                   │
│                                                                     │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐              │
│  │   Scalar     │   │   Vector    │   │   Matrix    │              │
│  │   Control    │   │   Unit      │   │   Unit      │              │
│  │   Unit       │   │   (VLU)     │   │   (MMU)     │              │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘              │
│         │                  │                  │                     │
│         └──────────────────┼──────────────────┘                     │
│                            │                                        │
│                    ┌───────┴───────┐                                │
│                    │   Scalar      │                                │
│                    │   Register    │                                │
│                    │   File        │                                │
│                    └───────┬───────┘                                │
│                            │                                        │
│                    ┌───────┴───────┐                                │
│                    │   Load/Store  │                                │
│                    │   Unit (LSU)  │                                │
│                    └───────┬───────┘                                │
│                            │                                        │
│                    ┌───────┴───────┐                                │
│                    │   Memory      │                                │
│                    │   Controller  │                                │
│                    └───────┬───────┘                                │
│                            │                                        │
└────────────────────────────┼────────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │   Memory        │
                    │   Subsystem     │
                    └─────────────────┘
```

### 4.2 Execution Model

ENOR-CPU uses a **VLIW-like static scheduling** model where the compiler explicitly assigns operations to execution units. This avoids the complexity of dynamic scheduling while still enabling parallelism.

**Execution slots per cycle:**
- 1 scalar instruction (control flow, address computation)
- 1 vector instruction (element-wise, reduction)
- 1 matrix instruction (multiply, MAC)
- 1 memory instruction (load/store)

**Note:** Not all slots must be filled. Unused slots execute NOP.

## 5. Word Size

### 5.1 Architecture Width

- **Address width:** 32 bits
- **Data width:** 32 bits (scalar), 256 bits (vector), variable (matrix)
- **Instruction width:** 32 bits (fixed)

### 5.2 Rationale

32-bit addresses provide 4 GB address space, sufficient for embedded AI applications. Fixed-width 32-bit instructions simplify decode and align with FPGA block RAM widths.

## 6. Register Model

### 6.1 Scalar Registers

```
x0  - Hardwired zero (read-only)
x1  - Return address (RA)
x2  - Stack pointer (SP)
x3  - Global pointer (GP) - optional
x4  - Thread pointer (TP) - reserved
x5-x7   - Temporary (caller-saved)
x8-x9   - Saved (callee-saved)
x10-x11 - Function arguments / return values
x12-x17 - Temporary (caller-saved)
x18-x27 - Saved (callee-saved)
x28-x31 - Temporary (caller-saved)
```

**Total:** 32 scalar registers, 32-bit each

### 6.2 Vector Registers

```
v0-v15 - Vector registers, 256 bits (8 x 32-bit elements) each
```

**Total:** 16 vector registers, 256-bit each

Vector length is configurable via a special register (`vl`), allowing 1-8 element operations.

### 6.3 Matrix Registers

Matrix computation uses a **memory-mapped accumulator register file** rather than architecturally visible registers. This simplifies the ISA while providing sufficient bandwidth.

```
M0 - 8x8 accumulator (2048 bits total, memory-mapped)
```

### 6.4 Special Registers

| Register | Width | Purpose |
|----------|-------|---------|
| PC | 32 | Program counter |
| SR | 32 | Status register (flags) |
| VL | 32 | Vector length (1-8) |
| VLX | 32 | Matrix dimension X |
| VLY | 32 | Matrix dimension Y |
| VLZ | 32 | Matrix dimension Z (depth) |
| STRIDE | 32 | Memory stride for vector ops |

## 7. Data Types

### 7.1 Scalar Types

| Type | Width | Notes |
|------|-------|-------|
| INT8 | 8 | Quantized inference |
| INT16 | 16 | Intermediate precision |
| INT32 | 32 | Default integer |
| UINT8 | 8 | Quantized weights |
| UINT16 | 16 | Addresses, indices |
| FP16 | 16 | Half precision (software) |
| BF16 | 16 | Brain float (software) |
| FP32 | 32 | Single precision (software) |

### 7.2 Vector Types

Each vector register holds multiple scalar elements:
- 8 x INT8
- 4 x INT16
- 4 x INT32
- 8 x UINT8
- 4 x UINT16

### 7.3 Matrix Types

Matrix operations support:
- INT8 x INT8 → INT32 (multiply-accumulate)
- INT16 x INT16 → INT32
- INT8 x INT8 → INT8 (saturating)

### 7.4 Floating-Point Strategy

v0.1 does not include hardware floating-point. Floating-point operations are implemented via:
1. Software emulation library
2. Fixed-point approximation where acceptable
3. Later versions may add FP16 hardware support

## 8. Memory Model

### 8.1 Address Space

```
0x00000000 - 0x3FFFFFFF  Code (1 GB)
0x40000000 - 0x7FFFFFFF  Data (1 GB)
0x80000000 - 0xBFFFFFFF  I/O (1 GB)
0xC0000000 - 0xFFFFFFFF  Reserved
```

### 8.2 Memory Organization

```
┌─────────────────────────────────────────────────┐
│                  Memory Subsystem                │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐      │
│  │  Code    │  │  Data    │  │  I/O     │      │
│  │  SRAM    │  │  SRAM    │  │  Bridge  │      │
│  │  (32KB)  │  │  (64KB)  │  │          │      │
│  └──────────┘  └──────────┘  └──────────┘      │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         Matrix SRAM (32KB)               │   │
│  │         (Dual-port for MMU)              │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │         Vector SRAM (16KB)               │   │
│  │         (Banked for VLU)                 │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 8.3 Memory Access Patterns

- **Scalar:** Byte, halfword, word access
- **Vector:** Burst access, 256 bits per cycle
- **Matrix:** Block access, configurable tile size

### 8.4 Consistency Model

**Sequential consistency** within each address space. No explicit memory ordering instructions in v0.1 (single-core).

## 9. Instruction Set Architecture

### 9.1 Instruction Encoding

Fixed 32-bit instruction width with the following formats:

**R-type (Register):**
```
[31:25] funct7 | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:7] rd | [6:0] opcode
```

**I-type (Immediate):**
```
[31:20] imm[11:0] | [19:15] rs1 | [14:12] funct3 | [11:7] rd | [6:0] opcode
```

**S-type (Store):**
```
[31:25] imm[11:5] | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:7] imm[4:0] | [6:0] opcode
```

**B-type (Branch):**
```
[31] imm[12] | [30:25] imm[10:5] | [24:20] rs2 | [19:15] rs1 | [14:12] funct3 | [11:8] imm[4:1] | [7] imm[11] | [6:0] opcode
```

**U-type (Upper Immediate):**
```
[31:12] imm[31:12] | [11:7] rd | [6:0] opcode
```

**V-type (Vector):**
```
[31:25] funct7 | [24:20] vs2 | [19:15] vs1 | [14:12] funct3 | [11:7] vd | [6:0] opcode
```

**M-type (Matrix):**
```
[31:28] funct4 | [27:24] mtype | [23:20] md | [19:16] ms2 | [15:12] ms1 | [11:8] mdst | [7:4] tile | [3:0] opcode
```

### 9.2 Instruction Categories

**Integer Arithmetic:**
- ADD, ADDI, SUB
- AND, OR, XOR
- SLL, SRL, SRA
- SLT, SLTU
- LUI, AUIPC

**Memory:**
- LB, LH, LW, LBU, LHU
- SB, SH, SW
- VLW (vector load word)
- VSW (vector store word)
- VLW_STRIDE (vector load with stride)
- VSW_STRIDE (vector store with stride)

**Control Flow:**
- BEQ, BNE, BLT, BGE, BLTU, BGEU
- JAL, JALR
- ECALL, EBREAK

**Vector Operations:**
- VADD.VV (vector-vector add)
- VSUB.VV (vector-vector subtract)
- VMUL.VV (vector-vector multiply)
- VADD.VS (vector-scalar add)
- VSUB.VS (vector-scalar subtract)
- VMUL.VS (vector-scalar multiply)
- VRELU (vector ReLU activation)
- VDOT (vector dot product)
- VRED_SUM (vector sum reduction)
- VRED_MAX (vector max reduction)
- VRED_MIN (vector min reduction)

**Matrix Operations:**
- MMUL (matrix multiply)
- MMAC (matrix multiply-accumulate)
- MLOAD (load matrix tile)
- MSTORE (store matrix tile)
- MSET_ZERO (zero matrix accumulator)
- MTRANS (matrix transpose - v0.2)

**Control/Status:**
- CSRRW (read/write control register)
- CSRRS (read/set control register)
- CSRRC (read/clear control register)

## 10. Compute Units

### 10.1 Scalar Control Unit

**Responsibilities:**
- Program flow control
- Address computation
- Branch/jump handling
- System calls
- Interrupt handling

**Characteristics:**
- 5-stage in-order pipeline (IF, ID, EX, MEM, WB)
- Single-issue
- No speculation

### 10.2 Vector Unit (VLU)

**Responsibilities:**
- Element-wise arithmetic on vectors
- Reduction operations
- Activation functions
- Scalar-vector operations

**Characteristics:**
- 256-bit datapath (8 x INT32 or 8 x INT8)
- Configurable vector length (1-8)
- Single-cycle latency for simple ops
- Multi-cycle for reductions

### 10.3 Matrix Unit (MMU)

**Responsibilities:**
- Dense matrix multiplication
- Matrix multiply-accumulate
- Block matrix operations

**Characteristics:**
- 8x8 INT8 multiply-accumulate per cycle
- Supports tile-based decomposition
- Accumulates into dedicated SRAM
- Latency: 8 cycles for 8x8 matmul

### 10.4 Load/Store Unit (LSU)

**Responsibilities:**
- Scalar memory access
- Vector memory access (burst)
- Memory address generation
- Stride pattern support

**Characteristics:**
- Unified address calculation
- Separate scalar and vector data paths
-支持 unaligned access (hardware assist)

## 11. AI Acceleration Strategy

### 11.1 Matrix Multiply Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                    Matrix Multiply Unit                          │
│                                                                  │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                  │
│  │  Input   │    │  MAC     │    │  Output  │                  │
│  │  Buffer  │───>│  Array   │───>│  Buffer  │                  │
│  │  (A,B)   │    │  8x8     │    │  (C)     │                  │
│  └──────────┘    └──────────┘    └──────────┘                  │
│       │               │               │                         │
│       │          ┌────┴────┐          │                         │
│       │          │  Accum  │          │                         │
│       │          │  Regs   │          │                         │
│       │          └─────────┘          │                         │
│       │                               │                         │
│  ┌────┴───────────────────────────────┴────┐                   │
│  │           Tile Controller               │                   │
│  │   (handles loop unrolling, tiling)      │                   │
│  └─────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 Data Movement Patterns

The architecture supports efficient data movement for common AI patterns:

**Weight Stationary:**
- Weights loaded once, broadcast to PEs
- Activations streamed in
- Results accumulated

**Output Stationary:**
- Partial results held in accumulators
- Weights and activations streamed
- Final result written out

### 11.3 Quantization Support

Native support for quantized inference:

- INT8 matrix multiply with INT32 accumulation
- Per-channel scale factors
- Asymmetric quantization support
- Requantization hardware (v0.2)

## 12. Interrupt Strategy

### 12.1 Exception Model

- Synchronous exceptions (ECALL, EBREAK)
- Asynchronous interrupts (timer, external)
- Priority: exception > interrupt
- Vectored interrupt table at 0x00001000

### 12.2 Interrupt Sources

| Source | Priority | Notes |
|--------|----------|-------|
| Timer | 1 | System tick |
| External | 2 | GPIO, UART |
| Matrix done | 3 | MMU completion |
| Error | 0 (highest) | Memory error, overflow |

### 12.3 Context Save

Context is saved to a dedicated stack by hardware on interrupt entry. Software saves additional state as needed.

## 13. I/O Model

### 13.1 Memory-Mapped I/O

All I/O is memory-mapped starting at 0x80000000:

```
0x80000000 - UART data register
0x80000004 - UART status register
0x80000008 - Timer value
0x8000000C - Timer compare
0x80000010 - GPIO output
0x80000014 - GPIO input
0x80000018 - Interrupt enable
0x8000001C - Interrupt status
```

### 13.2 Peripherals (v0.1)

- UART (8N1, 115200 baud default)
- 32-bit timer with interrupt
- 8-bit GPIO
- Interrupt controller

## 14. Hardware/Software Boundary

### 14.1 Hardware Responsibilities

- Instruction fetch and decode
- Integer arithmetic
- Vector arithmetic
- Matrix multiplication
- Memory access
- Interrupt handling
- Basic I/O

### 14.2 Software Responsibilities

- Floating-point operations (emulation library)
- Activation functions beyond ReLU (software)
- Complex data movement (transpose, reshape)
- Scheduling and synchronization
- Memory management
- Dynamic allocation

### 14.3 Compiler Responsibilities

- Instruction scheduling across execution units
- Register allocation
- Vectorization of loops
- Matrix tiling and blocking
- Memory layout optimization
- Intrinsic mapping to hardware operations

### 14.4 Runtime Responsibilities

- System initialization
- Interrupt service routines
- Timer management
- I/O drivers
- Dynamic memory allocation (optional)

## 15. Initial Hardware Scope (v0.1)

### 15.1 Included

- 32-bit scalar processor
- 5-stage pipeline
- 32 scalar registers
- 16 vector registers (256-bit)
- 8x8 matrix multiply unit
- 32KB instruction SRAM
- 64KB data SRAM
- 32KB matrix SRAM
- 16KB vector SRAM
- UART peripheral
- Timer peripheral
- 8-bit GPIO
- Basic interrupt controller

### 15.2 Excluded (v0.1)

- Floating-point hardware
- Branch prediction
- Speculative execution
- Out-of-order execution
- Cache hierarchy
- Virtual memory
- Multi-core
- DMA engine
- Systolic array
- Hardware activation functions beyond ReLU

## 16. Planned for Later Versions

### v0.2

- FP16 hardware support
- Hardware ReLU, sigmoid, tanh
- DMA engine
- Matrix transpose hardware
- Expanded vector length (16/32 elements)
- Performance counters

### v0.3

- Systolic array option
- On-chip SRAM expansion (128KB+)
- Advanced quantization support
- Batch normalization hardware
- Softmax hardware

### v1.0

- Multi-core support (2-4 cores)
- Cache hierarchy
- Advanced branch prediction
- Debug interface (JTAG)
- Trace interface

## 17. Experimental Ideas

- **Hardware scatter/gather** - For sparse operations
- **Bit-serial processing** - For variable precision
- **In-memory compute** - For element-wise operations
- **Custom instruction extensions** - User-definable operations

These are not planned for implementation but are noted for future consideration.
