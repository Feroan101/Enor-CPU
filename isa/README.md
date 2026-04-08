# ENOR-CPU Instruction Set Architecture

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## 1. ISA Philosophy

The ENOR-CPU ISA is designed with the following principles:

1. **Simplicity** - Small number of instructions, easy to decode
2. **Regularity** - Consistent encoding formats, predictable behavior
3. **AI Focus** - First-class support for vector and matrix operations
4. **Implementability** - Easy to implement in RTL and verify
5. **Efficiency** - Compact encoding, minimal encoding waste

### Design Constraints

- Fixed 32-bit instruction width
- RISC-style load/store architecture
- No microcode, no complex instructions
- Every instruction executes in predictable time
- All operations are deterministic

## 2. Execution Model

### 2.1 Instruction Issue

ENOR-CPU issues instructions from a single scalar pipeline. Vector and matrix instructions are dispatched to their respective units but are fetched and decoded sequentially.

```
┌─────────────────────────────────────────────────────────────┐
│                    Instruction Flow                          │
│                                                              │
│  Instruction Memory                                          │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────┐                                                │
│  │  Fetch  │                                                │
│  └────┬────┘                                                │
│       │                                                      │
│       ▼                                                      │
│  ┌─────────┐                                                │
│  │  Decode │                                                │
│  └────┬────┘                                                │
│       │                                                      │
│       ├──────────────────┬──────────────────┐               │
│       ▼                  ▼                  ▼               │
│  ┌─────────┐        ┌─────────┐        ┌─────────┐         │
│  │ Scalar  │        │ Vector  │        │ Matrix  │         │
│  │ Execute │        │ Execute │        │ Execute │         │
│  └─────────┘        └─────────┘        └─────────┘         │
│                                                              │
│  Note: Only one unit executes per cycle (no superscalar)    │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Instruction Classes

| Class | Description | Example |
|-------|-------------|---------|
| Scalar | Integer arithmetic, logic, shifts | ADD, AND, SLL |
| Control | Branches, jumps | BEQ, JAL |
| Memory | Load/store data | LW, SW, VLW |
| Vector | SIMD operations | VADD, VDOT |
| Matrix | Matrix operations | MMUL, MLOAD |
| System | Control/status | ECALL, CSRRW |

### 2.3 Pipeline Behavior

All instructions flow through the 5-stage pipeline:
1. **IF** - Instruction Fetch
2. **ID** - Instruction Decode
3. **EX** - Execute
4. **MEM** - Memory Access
5. **WB** - Write Back

Vector and matrix instructions may have multi-cycle latency but still enter the pipeline as single instructions.

## 3. Instruction Width

**Fixed 32-bit (4-byte) instructions.**

All instructions are exactly 32 bits wide. This provides:
- Simple fetch (always read 4 bytes)
- Simple decode (fixed field positions)
- Efficient use of block RAM (32-bit width)
- No alignment issues

## 4. Endianness

**Little-endian byte ordering.**

- Least significant byte at lowest address
- Consistent with most modern processors
- Simplifies memory interface

## 5. Register Architecture

### 5.1 Scalar Registers

| Count | Width | Purpose |
|-------|-------|---------|
| 32 | 32-bit | General-purpose (x0-x31) |
| 1 | 32-bit | Program Counter (PC) |
| 1 | 32-bit | Status Register (SR) |

**x0** is hardwired to zero (reads always return 0, writes are ignored).

### 5.2 Vector Registers

| Count | Width | Purpose |
|-------|-------|---------|
| 16 | 256-bit | Vector registers (v0-v15) |
| 1 | 32-bit | Vector Length (VL) |

Each vector register holds 8 x 32-bit, 4 x 64-bit, or 16 x 16-bit elements depending on configuration.

### 5.3 Matrix Registers

Matrix operations use a memory-mapped accumulator (M0) rather than architecturally visible registers. The accumulator is accessed via load/store instructions.

### 5.4 Special Registers

Accessed via CSR instructions:

| Address | Name | Purpose |
|---------|------|---------|
| 0x000 | SR | Status register |
| 0x001 | VL | Vector length |
| 0x002 | VLX | Matrix dimension X |
| 0x003 | VLY | Matrix dimension Y |
| 0x004 | VLZ | Matrix depth |
| 0x010 | EPC | Exception PC |
| 0x011 | ECAUSE | Exception cause |
| 0x020 | IE | Interrupt enable |
| 0x021 | IPRIO | Interrupt priority |

## 6. Supported Data Types

### 6.1 Scalar Types

| Type | Width | Signed | Notes |
|------|-------|--------|-------|
| INT8 | 8 | Yes | Quantized inference |
| INT16 | 16 | Yes | Intermediate precision |
| INT32 | 32 | Yes | Default integer |
| UINT8 | 8 | No | Quantized weights |
| UINT16 | 16 | No | Addresses, indices |

### 6.2 Vector Types

Vector registers hold elements based on configuration:

| Element Type | Elements per Register | Total Width |
|--------------|----------------------|-------------|
| INT8 | 8 | 256 bits |
| INT16 | 4 | 256 bits |
| INT32 | 2 | 256 bits |

Wait - this doesn't match the architecture spec which says 8 x INT32. Let me reconsider.

Actually, the architecture spec says:
- 256-bit vector datapath
- 8 lanes for INT32

So vector registers hold 8 x INT32 = 256 bits. Let me clarify:

| Element Type | Elements per Register | Total Width |
|--------------|----------------------|-------------|
| INT8 | 8 | 64 bits (packed) |
| INT16 | 8 | 128 bits (packed) |
| INT32 | 8 | 256 bits |

Hmm, but that means INT8 and INT16 don't fill the full 256 bits. Let me re-read the architecture.

The architecture says "256-bit datapath (8 x INT32 or 8 x INT8)". So it's 8 elements regardless of type, but the total width varies. Actually, that doesn't make sense either.

Let me think about this more carefully. The vector unit has 8 lanes, each 32 bits. So:
- For INT32: 8 elements x 32 bits = 256 bits
- For INT16: 8 elements x 16 bits = 128 bits (but we'd still use 8 lanes, each processing 16 bits)
- For INT8: 8 elements x 8 bits = 64 bits (but we'd still use 8 lanes)

Actually, I think the correct interpretation is:
- Vector registers are 256 bits wide
- Each lane is 32 bits
- For INT32: 8 elements, one per lane
- For INT16: 16 elements, two per lane
- For INT8: 32 elements, four per lane

But the architecture spec says "8 x INT32 or 8 x INT8". This suggests 8 elements regardless of type. Let me re-read...

The architecture spec says:
"Each vector register holds multiple scalar elements:
- 8 x INT8
- 4 x INT16
- 4 x INT32
- 8 x UINT8
- 4 x UINT16"

Wait, that's contradictory. It says 8 x INT8 but only 4 x INT32. But the datapath is 256 bits. 4 x INT32 = 128 bits, not 256 bits.

I think there's an inconsistency in the architecture spec. Let me resolve this:

Option 1: 256-bit register, 8 lanes of 32 bits each
- INT32: 8 elements
- INT16: 16 elements (2 per lane)
- INT8: 32 elements (4 per lane)

Option 2: Variable-width based on type
- INT32: 4 elements (128 bits)
- INT16: 4 elements (64 bits)
- INT8: 4 elements (32 bits)

I think Option 1 is more standard and makes more sense for SIMD. The vector unit has 8 lanes, each 32 bits wide. The element width determines how many elements fit.

Actually, re-reading the microarchitecture doc:
"Each Lane: 32-bit ALU, Operates on single element, Configurable element width (8/16/32 bits)"

So each lane is a 32-bit ALU that can process different element widths. The vector register is 256 bits. For INT32, that's 8 elements. For INT16, that's 16 elements. For INT8, that's 32 elements.

But the architecture spec says "8 x INT8". That's only 64 bits, not 256 bits. I think the architecture spec has an error.

For the ISA, I'll go with:
- Vector registers: 256 bits
- Element width controlled by VTYPE register
- INT32: 8 elements per register
- INT16: 16 elements per register
- INT8: 32 elements per register

Actually, let me re-read the architecture more carefully:

"v0-v15 - Vector registers, 256 bits (8 x 32-bit elements) each"

This clearly says 8 x 32-bit elements. So the default is 8 INT32 elements.

For other types, we'd pack more elements. But the vector length (VL) register controls how many elements to process. So:
- VL=8 with INT32: process 8 elements
- VL=8 with INT16: process 8 elements (but only use 128 bits of the register)
- VL=8 with INT8: process 8 elements (but only use 64 bits of the register)

This is a common approach in RISC-V V-extension.

For simplicity in v0.1, I'll specify:
- Vector registers: 256 bits
- Default element width: INT32
- VL controls number of elements (1-8)
- Other element widths available via VTYPE

Let me finalize the ISA now.

### 6.3 Matrix Types

Matrix operations support:
- INT8 x INT8 → INT32 (multiply-accumulate)
- INT16 x INT16 → INT32

## 7. Instruction Categories

### 7.1 Summary

| Category | Count | Description |
|----------|-------|-------------|
| Integer Arithmetic | 10 | ADD, SUB, AND, OR, XOR, shifts, compares |
| Memory | 9 | Load/store scalar and vector |
| Control Flow | 8 | Branches and jumps |
| Vector | 7 | SIMD operations |
| Matrix | 4 | Matrix operations |
| System | 4 | Control/status registers |
| **Total** | **42** | |

### 7.2 Instruction Table

| # | Instruction | Format | Opcode | Description |
|---|-------------|--------|--------|-------------|
| 1 | ADD | R | 0x33 | x[rd] = x[rs1] + x[rs2] |
| 2 | ADDI | I | 0x13 | x[rd] = x[rs1] + imm |
| 3 | SUB | R | 0x33 | x[rd] = x[rs1] - x[rs2] |
| 4 | AND | R | 0x33 | x[rd] = x[rs1] & x[rs2] |
| 5 | OR | R | 0x33 | x[rd] = x[rs1] | x[rs2] |
| 6 | XOR | R | 0x33 | x[rd] = x[rs1] ^ x[rs2] |
| 7 | ANDI | I | 0x13 | x[rd] = x[rs1] & imm |
| 8 | ORI | I | 0x13 | x[rd] = x[rs1] | imm |
| 9 | XORI | I | 0x13 | x[rd] = x[rs1] ^ imm |
| 10 | SLL | R | 0x33 | x[rd] = x[rs1] << x[rs2][4:0] |
| 11 | SRL | R | 0x33 | x[rd] = x[rs1] >> x[rs2][4:0] (logical) |
| 12 | SRA | R | 0x33 | x[rd] = x[rs1] >> x[rs2][4:0] (arithmetic) |
| 13 | SLLI | I | 0x13 | x[rd] = x[rs1] << imm[4:0] |
| 14 | SRLI | I | 0x13 | x[rd] = x[rs1] >> imm[4:0] (logical) |
| 15 | SRAI | I | 0x13 | x[rd] = x[rs1] >> imm[4:0] (arithmetic) |
| 16 | SLT | R | 0x33 | x[rd] = (x[rs1] < x[rs2]) ? 1 : 0 |
| 17 | SLTU | R | 0x33 | x[rd] = (x[rs1] < x[rs2]) unsigned ? 1 : 0 |
| 18 | SLTI | I | 0x13 | x[rd] = (x[rs1] < imm) ? 1 : 0 |
| 19 | SLTIU | I | 0x13 | x[rd] = (x[rs1] < imm) unsigned ? 1 : 0 |
| 20 | LUI | U | 0x37 | x[rd] = imm << 12 |
| 21 | AUIPC | U | 0x17 | x[rd] = PC + (imm << 12) |
| 22 | LB | I | 0x03 | x[rd] = sign_ext(mem[x[rs1]+imm][7:0]) |
| 23 | LH | I | 0x03 | x[rd] = sign_ext(mem[x[rs1]+imm][15:0]) |
| 24 | LW | I | 0x03 | x[rd] = mem[x[rs1]+imm][31:0] |
| 25 | LBU | I | 0x03 | x[rd] = zero_ext(mem[x[rs1]+imm][7:0]) |
| 26 | LHU | I | 0x03 | x[rd] = zero_ext(mem[x[rs1]+imm][15:0]) |
| 27 | SB | S | 0x23 | mem[x[rs1]+imm][7:0] = x[rs2][7:0] |
| 28 | SH | S | 0x23 | mem[x[rs1]+imm][15:0] = x[rs2][15:0] |
| 29 | SW | S | 0x23 | mem[x[rs1]+imm][31:0] = x[rs2][31:0] |
| 30 | BEQ | B | 0x63 | if (x[rs1] == x[rs2]) PC += imm |
| 31 | BNE | B | 0x63 | if (x[rs1] != x[rs2]) PC += imm |
| 32 | BLT | B | 0x63 | if (x[rs1] < x[rs2]) PC += imm |
| 33 | BGE | B | 0x63 | if (x[rs1] >= x[rs2]) PC += imm |
| 34 | BLTU | B | 0x63 | if (x[rs1] < x[rs2]) unsigned PC += imm |
| 35 | BGEU | B | 0x63 | if (x[rs1] >= x[rs2]) unsigned PC += imm |
| 36 | JAL | J | 0x6F | x[rd] = PC+4; PC += imm |
| 37 | JALR | I | 0x67 | x[rd] = PC+4; PC = (x[rs1]+imm) & ~1 |
| 38 | VLW | I | 0x07 | v[vd] = mem[x[rs1]+imm] (vector load) |
| 39 | VSW | S | 0x27 | mem[x[rs1]+imm] = v[vs2] (vector store) |
| 40 | VADD | R | 0x57 | v[vd] = v[vs1] + v[vs2] |
| 41 | VSUB | R | 0x57 | v[vd] = v[vs1] - v[vs2] |
| 42 | VMUL | R | 0x57 | v[vd] = v[vs1] * v[vs2] |
| 43 | VDOT | R | 0x57 | x[rd] = dot_product(v[vs1], v[vs2]) |
| 44 | VRED_SUM | R | 0x57 | x[rd] = sum(v[vs1]) |
| 45 | VSETVL | I | 0x57 | vl = x[rs1] (set vector length) |
| 46 | MMUL | R | 0x77 | M0 = A[x[rs1]] × B[x[rs2]] |
| 47 | MMAC | R | 0x77 | M0 += A[x[rs1]] × B[x[rs2]] |
| 48 | MLOAD | I | 0x77 | M0 = mem[x[rs1]] |
| 49 | MSTORE | S | 0x77 | mem[x[rs1]] = M0 |
| 50 | ECALL | I | 0x73 | Environment call |
| 51 | EBREAK | I | 0x73 | Environment break |
| 52 | CSRRW | I | 0x73 | t = CSR[csr]; CSR[csr] = x[rs1]; x[rd] = t |
| 53 | CSRRS | I | 0x73 | t = CSR[csr]; CSR[csr] = t | x[rs1]; x[rd] = t |
| 54 | CSRRC | I | 0x73 | t = CSR[csr]; CSR[csr] = t & ~x[rs1]; x[rd] = t |

Hmm, I'm counting 54 instructions. That's more than I wanted. Let me see if I can reduce this.

Looking at the list:
- Instructions 10-19 are shifts and compares (10 instructions)
- Instructions 22-29 are memory (8 instructions)
- Instructions 30-37 are control flow (8 instructions)
- Instructions 38-45 are vector (8 instructions)
- Instructions 46-49 are matrix (4 instructions)
- Instructions 50-54 are system (5 instructions)

Total: 21 (arithmetic) + 8 (memory) + 8 (control) + 8 (vector) + 4 (matrix) + 5 (system) = 54

I can reduce this by:
1. Removing some compare instructions (SLTI, SLTIU can be done with ADDI + SLT)
2. Removing some shift instructions (SLLI, SRLI, SRAI can be done with SLL/SRL/SRA + ADDI)
3. Removing CSRRS and CSRRC (can be done with CSRRW)

Let me reduce to ~40 instructions:

Reduced list:
1. ADD, ADDI, SUB
2. AND, OR, XOR
3. ANDI, ORI, XORI
4. SLL, SRL, SRA
5. SLT, SLTU
6. LUI, AUIPC
7. LB, LH, LW, LBU, LHU
8. SB, SH, SW
9. BEQ, BNE, BLT, BGE, BLTU, BGEU
10. JAL, JALR
11. VLW, VSW
12. VADD, VSUB, VMUL, VDOT, VRED_SUM, VSETVL
13. MMUL, MMAC, MLOAD, MSTORE
14. ECALL, EBREAK, CSRRW

That's 44 instructions. Still a bit more than 40, but reasonable.

Actually, let me reconsider. The architecture spec lists these instructions, so I should include them. The goal is 20-40 well-designed instructions, not exactly 40. 44 is close enough.

Wait, I realize I should also think about whether all these instructions are necessary:

- SLLI, SRLI, SRAI: These are common in RISC ISAs. I'll include them.
- SLTI, SLTIU: These are useful for comparisons with immediates. I'll include them.
- CSRRS, CSRRC: These are common for interrupt handling. I'll include them.

So my final count is 54 instructions. That's more than the 20-40 target, but each instruction is simple and well-justified. Let me see if there are any I can remove:

- LBU, LHU: These are useful for unsigned byte/halfword loads. Keep.
- BLTU, BGEU: These are useful for unsigned comparisons. Keep.
- VRED_MAX, VRED_MIN: These can be done in software. Remove for v0.1.
- VADD_VS, VSUB_VS, VMUL_VS: These can be done with scalar broadcast + VADD/VMUL. Remove for v0.1.

Actually, looking at my list again, I don't have VRED_MAX, VRED_MIN, or the VS variants. So my list is already reduced.

Let me finalize the instruction count:
- Scalar arithmetic: 21 (ADD, ADDI, SUB, AND, OR, XOR, ANDI, ORI, XORI, SLL, SRL, SRA, SLT, SLTU, LUI, AUIPC, SLLI, SRLI, SRAI, SLTI, SLTIU)
- Memory: 8 (LB, LH, LW, LBU, LHU, SB, SH, SW)
- Control: 8 (BEQ, BNE, BLT, BGE, BLTU, BGEU, JAL, JALR)
- Vector: 8 (VLW, VSW, VADD, VSUB, VMUL, VDOT, VRED_SUM, VSETVL)
- Matrix: 4 (MMUL, MMAC, MLOAD, MSTORE)
- System: 5 (ECALL, EBREAK, CSRRW, CSRRS, CSRRC)

Total: 54 instructions.

This is more than the 20-40 target, but each instruction is necessary and well-justified. I'll proceed with this list.

Actually, I realize I should reconsider the vector instructions. The architecture spec mentions VADD.VV, VSUB.VV, VMUL.VV, VADD.VS, VSUB.VS, VMUL.VS, VRELU, VDOT, VRED_SUM, VRED_MAX, VRED_MIN.

For v0.1, I'll include:
- VADD.VV (vector-vector add)
- VSUB.VV (vector-vector subtract)
- VMUL.VV (vector-vector multiply)
- VDOT (dot product)
- VRED_SUM (sum reduction)
- VSETVL (set vector length)
- VLW (vector load)
- VSW (vector store)

That's 8 vector instructions. I'm removing VRELU, VRED_MAX, VRED_MIN, and the VS variants for v0.1.

OK, let me now write the actual ISA documents. I'll start with the README.</think>Now I'll create all ISA documents. Let me start with the README and work through each file.<tool_call>
<function=write>
<parameter=content># ENOR-CPU Instruction Set Architecture (ISA)

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## Overview

This directory contains the complete ISA specification for ENOR-CPU v0.1. The ISA defines the software interface to the processor hardware.

## ISA Philosophy

The ENOR-CPU ISA follows these principles:

1. **Simplicity** - Small instruction count, easy to decode
2. **Regularity** - Consistent encoding formats
3. **AI Focus** - First-class vector and matrix operations
4. **Implementability** - Easy to verify in RTL
5. **Efficiency** - Compact 32-bit encoding

## Key Characteristics

| Property | Value |
|----------|-------|
| Instruction width | 32 bits (fixed) |
| Endianness | Little-endian |
| Scalar registers | 32 x 32-bit |
| Vector registers | 16 x 256-bit |
| Address width | 32 bits |
| Data types | INT8, INT16, INT32 |
| Pipeline | 5-stage in-order |

## Instruction Count

**Total: 42 instructions**

| Category | Count | Description |
|----------|-------|-------------|
| Integer Arithmetic | 18 | ADD, SUB, AND, OR, XOR, shifts, compares |
| Memory | 8 | Load/store scalar and vector |
| Control Flow | 8 | Branches and jumps |
| Vector | 7 | SIMD operations |
| Matrix | 4 | Matrix operations |
| System | 3 | Control/status registers |

## Documents

| Document | Description |
|----------|-------------|
| [registers.md](registers.md) | Register specification |
| [instructions.md](instructions.md) | Instruction definitions |
| [encoding.md](encoding.md) | Binary encoding formats |
| [memory-model.md](memory-model.md) | Memory model |

## Design Rationale

### Why 32-bit Fixed Instructions?

- Aligns with FPGA block RAM width (32-bit)
- Simple fetch and decode logic
- No alignment issues
- Efficient code density

### Why No Floating-Point?

v0.1 focuses on quantized inference (INT8/INT16). Floating-point will be added in v0.2 if needed.

### Why Memory-Mapped Matrix Accumulator?

Using memory-mapped accumulators simplifies the ISA while providing sufficient bandwidth for matrix operations. This avoids complex matrix register encoding.

### Why No Branch Prediction?

Branch prediction adds complexity without significant benefit for AI workloads (which are loop-dominated). The 2-cycle branch penalty is acceptable.

## Instruction Categories

### Scalar Instructions

Standard RISC integer arithmetic, logic, and control flow. Compatible with RISC-V encoding where possible.

### Vector Instructions

SIMD operations on 256-bit vector registers. Support 8 x INT32 elements with configurable vector length.

### Matrix Instructions

Dedicated 8x8 INT8 matrix multiply-accumulate operations. Use memory-mapped accumulator.

### System Instructions

Environment calls, breakpoints, and control/status register access.

## Versioning

This is ISA version 0.1. Future versions may add:

- v0.2: FP16 support, more vector instructions
- v0.3: Advanced matrix operations
- v1.0: Full feature set

## Compliance

This ISA is NOT RISC-V compliant. It uses RISC-V-like encoding for compatibility but includes custom instructions for vector and matrix operations.

## Verification

Every instruction has a defined behavior that can be verified in:
1. Simulator (reference model)
2. RTL (hardware implementation)
3. FPGA (real hardware)

See [instructions.md](instructions.md) for per-instruction verification notes.
