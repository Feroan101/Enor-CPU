# ENOR-CPU Memory Model

**Version:** 0.1  
**Status:** Specification  
**Last Updated:** 2026-08-24

## 1. Memory Architecture Overview

ENOR-CPU uses a modified Harvard architecture with separate address spaces for code, data, and I/O. All memory is memory-mapped with no virtual memory.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Memory Map                                 │
│                                                                  │
│  0x00000000 ┌──────────────────────────────────┐               │
│             │         Code Space               │               │
│             │         (32 KB SRAM)             │               │
│             │         Read-only from CPU       │               │
│  0x00007FFF ├──────────────────────────────────┤               │
│             │         Reserved                  │               │
│  0x3FFFFFFF ├──────────────────────────────────┤               │
│             │         Data Space               │               │
│             │         (64 KB SRAM)             │               │
│             │         Read/Write               │               │
│  0x4000FFFF ├──────────────────────────────────┤               │
│             │         Matrix Space             │               │
│             │         (32 KB SRAM)             │               │
│             │         Read/Write               │               │
│  0x40007FFF ├──────────────────────────────────┤               │
│             │         Vector Space             │               │
│             │         (16 KB SRAM)             │               │
│             │         Read/Write               │               │
│  0x40003FFF ├──────────────────────────────────┤               │
│             │         Matrix Accumulator       │               │
│             │         (256 bytes)              │               │
│             │         Memory-mapped            │               │
│  0x400000FF ├──────────────────────────────────┤               │
│             │         Reserved                  │               │
│  0x7FFFFFFF ├──────────────────────────────────┤               │
│             │         I/O Space                │               │
│             │         Memory-mapped I/O        │               │
│  0x80000000 ├──────────────────────────────────┤               │
│             │         UART                     │               │
│  0x80000004 ├──────────────────────────────────┤               │
│             │         Timer                    │               │
│  0x80000008 ├──────────────────────────────────┤               │
│             │         GPIO                     │               │
│  0x8000000C ├──────────────────────────────────┤               │
│             │         Interrupt Controller     │               │
│  0x80000010 ├──────────────────────────────────┤               │
│             │         Reserved                  │               │
│  0xBFFFFFFF ├──────────────────────────────────┤               │
│             │         Reserved                  │               │
│  0xFFFFFFFF └──────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────────┘
```

## 2. Address Spaces

### 2.1 Code Space

**Range:** 0x00000000 - 0x3FFFFFFF (1 GB address space, 32 KB physical)

**Characteristics:**
- Read-only from CPU perspective
- 32 KB physical SRAM
- Word-aligned access only (32-bit)
- No write permissions (writes cause exception)

**Purpose:** Stores executable instructions.

**Access:**
- Instruction fetch only
- No load/store access from data memory
- PC must be within 0x00000000 - 0x00007FFF (32 KB)

### 2.2 Data Space

**Range:** 0x40000000 - 0x7FFFFFFF (1 GB address space, 64 KB physical)

**Characteristics:**
- Read/Write from CPU
- 64 KB physical SRAM
- Byte, halfword, and word access
- Word-aligned access preferred

**Purpose:** General-purpose data storage.

**Access:**
- Scalar load/store instructions
- Vector load/store instructions
- Matrix load/store instructions

### 2.3 Matrix Space

**Range:** 0x40000000 - 0x40007FFF (32 KB physical, overlaid in data space)

**Note:** Matrix SRAM is overlaid in the data address space. The actual physical address is decoded separately.

**Characteristics:**
- 32 KB dual-port SRAM
- Optimized for matrix tile access
- 512-bit access width (8 words)
- Banked for parallel access

**Purpose:** Stores matrix operands and results.

### 2.4 Vector Space

**Range:** 0x40000000 - 0x40003FFF (16 KB physical, overlaid in data space)

**Note:** Vector SRAM is overlaid in the data address space. The actual physical address is decoded separately.

**Characteristics:**
- 16 KB banked SRAM (4 banks x 4 KB)
- 256-bit access width (8 words)
- Interleaved addressing

**Purpose:** Stores vector operands and results.

### 2.5 Matrix Accumulator

**Range:** 0x40000000 - 0x400000FF (256 bytes, memory-mapped)

**Note:** This is a special memory-mapped register file for the matrix unit.

**Characteristics:**
- 256 bytes (8x8 x 32-bit = 2048 bits)
- Dual-port access
- Directly accessible via load/store
- Used by MMUL, MMAC, MLOAD, MSTORE

**Purpose:** Accumulator for matrix multiply-accumulate operations.

**Memory Layout:**
```
Address         Element
0x40000000      M0[0][0]
0x40000004      M0[0][1]
0x40000008      M0[0][2]
...
0x400000FC      M0[7][7]
```

### 2.6 I/O Space

**Range:** 0x80000000 - 0xBFFFFFFF (1 GB address space)

**Characteristics:**
- Memory-mapped peripherals
- 32-bit access only
- No caching (always bypasses cache if present)
- Volatile access (no reordering)

**Purpose:** Peripheral communication.

## 3. Memory Map Detail

### 3.1 Code SRAM (32 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Code SRAM                                  │
│                                                              │
│  Physical Size: 32 KB (8192 x 32-bit words)                │
│  Address Range: 0x00000000 - 0x00007FFF                    │
│  Access Width: 32-bit (instruction fetch)                   │
│  Ports: 1 read port                                         │
│  Latency: 1 cycle                                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Address [14:2]  →  32-bit instruction              │   │
│  │  (12-bit word address)                               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Note: Physical SRAM is 32 KB, but address space is 1 GB. │
│        Only lower 15 bits are used for physical addressing. │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Data SRAM (64 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Data SRAM                                  │
│                                                              │
│  Physical Size: 64 KB (16384 x 32-bit words)               │
│  Address Range: 0x40000000 - 0x4000FFFF                    │
│  Access Width: 8, 16, or 32 bits                            │
│  Ports: 2 ports (dual-port)                                 │
│  Latency: 1 cycle                                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Port A: Read/Write (scalar access)                 │   │
│  │  Port B: Read (vector/matrix load)                  │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Byte Enable: 4-bit (supports byte, half, word)            │
│  Alignment: Preferred on 4-byte boundary                    │
└─────────────────────────────────────────────────────────────┘
```

### 3.3 Matrix SRAM (32 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Matrix SRAM                                │
│                                                              │
│  Physical Size: 32 KB (8192 x 32-bit words)                │
│  Address Range: 0x40000000 - 0x40007FFF                    │
│  Access Width: 512-bit (8 words)                            │
│  Ports: 2 ports (dual-port)                                 │
│  Latency: 1 cycle                                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Tile Organization:                                 │   │
│  │    - Each tile: 8x8 x 32-bit = 256 bytes           │   │
│  │    - Up to 128 tiles (32 KB / 256 B)               │   │
│  │    - Tile addressing: addr[13:8]                    │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Used by: MMUL, MMAC, MLOAD, MSTORE                        │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 Vector SRAM (16 KB)

```
┌─────────────────────────────────────────────────────────────┐
│                    Vector SRAM                                │
│                                                              │
│  Physical Size: 16 KB (4096 x 32-bit words)                │
│  Address Range: 0x40000000 - 0x40003FFF                    │
│  Access Width: 256-bit (8 words)                            │
│  Ports: 4 banks (independent access)                        │
│  Latency: 1 cycle                                           │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Bank Organization:                                 │   │
│  │    Bank 0: 0x40000000 - 0x40000FFF (4 KB)         │   │
│  │    Bank 1: 0x40001000 - 0x40001FFF (4 KB)         │   │
│  │    Bank 2: 0x40002000 - 0x40002FFF (4 KB)         │   │
│  │    Bank 3: 0x40003000 - 0x40003FFF (4 KB)         │   │
│  │                                                      │   │
│  │  Interleaved by address bits [13:12]               │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Used by: VLW, VSW                                         │
└─────────────────────────────────────────────────────────────┘
```

## 4. Memory Access Rules

### 4.1 Alignment Requirements

| Access Type | Alignment | Exception on Violation |
|-------------|-----------|------------------------|
| Instruction fetch | 4-byte | Yes (instruction misalign) |
| LB, LBU | Any | No |
| LH, LHU | 2-byte | Yes (load half misalign) |
| LW | 4-byte | Yes (load word misalign) |
| SB | Any | No |
| SH | 2-byte | Yes (store half misalign) |
| SW | 4-byte | Yes (store word misalign) |
| VLW | 32-byte | Yes (vector load misalign) |
| VSW | 32-byte | Yes (vector store misalign) |

### 4.2 Access Width

| Instruction | Width | Description |
|-------------|-------|-------------|
| LB, LBU | 8 bits | Byte access |
| LH, LHU | 16 bits | Halfword access |
| LW | 32 bits | Word access |
| VLW | 256 bits | Vector access (8 words) |
| VSW | 256 bits | Vector access (8 words) |
| MLOAD | 512 bits | Matrix access (16 words) |
| MSTORE | 512 bits | Matrix access (16 words) |

### 4.3 Byte Ordering

Little-endian: Least significant byte at lowest address.

```
Word at address 0x1000:
┌─────────┬─────────┬─────────┬─────────┐
│ Byte 3  │ Byte 2  │ Byte 1  │ Byte 0  │
│ 0x1003  │ 0x1002  │ 0x1001  │ 0x1000  │
└─────────┴─────────┴─────────┴─────────┘

Byte 0 = bits [7:0]
Byte 1 = bits [15:8]
Byte 2 = bits [23:16]
Byte 3 = bits [31:24]
```

## 5. Memory Operations

### 5.1 Scalar Load Operations

```
Load Byte (LB):
  addr = x[rs1] + sign_extend(imm[11:0])
  x[rd] = sign_extend(mem[addr][7:0])

Load Halfword (LH):
  addr = x[rs1] + sign_extend(imm[11:0])
  x[rd] = sign_extend(mem[addr][15:0])

Load Word (LW):
  addr = x[rs1] + sign_extend(imm[11:0])
  x[rd] = mem[addr][31:0]

Load Byte Unsigned (LBU):
  addr = x[rs1] + sign_extend(imm[11:0])
  x[rd] = zero_extend(mem[addr][7:0])

Load Halfword Unsigned (LHU):
  addr = x[rs1] + sign_extend(imm[11:0])
  x[rd] = zero_extend(mem[addr][15:0])
```

### 5.2 Scalar Store Operations

```
Store Byte (SB):
  addr = x[rs1] + sign_extend(imm[11:0])
  mem[addr][7:0] = x[rs2][7:0]

Store Halfword (SH):
  addr = x[rs1] + sign_extend(imm[11:0])
  mem[addr][15:0] = x[rs2][15:0]

Store Word (SW):
  addr = x[rs1] + sign_extend(imm[11:0])
  mem[addr][31:0] = x[rs2][31:0]
```

### 5.3 Vector Load/Store Operations

```
Vector Load Word (VLW):
  addr = x[rs1] + sign_extend(imm[11:0])
  v[vd][255:0] = mem[addr+0][31:0] : mem[addr+4][31:0] : ... : mem[addr+28][31:0]

Vector Store Word (VSW):
  addr = x[rs1] + sign_extend(imm[11:0])
  mem[addr+0][31:0] = v[vs2][31:0]
  mem[addr+4][31:0] = v[vs2][63:32]
  ...
  mem[addr+28][31:0] = v[vs2][255:224]
```

### 5.4 Matrix Load/Store Operations

```
Matrix Load (MLOAD):
  addr = x[rs1]
  for i = 0 to VLY-1:
    for j = 0 to VLX-1:
      M0[i][j] = mem[addr + (i * VLX + j) * 4]

Matrix Store (MSTORE):
  addr = x[rs1]
  for i = 0 to VLY-1:
    for j = 0 to VLX-1:
      mem[addr + (i * VLX + j) * 4] = M0[i][j]
```

## 6. Memory Consistency

### 6.1 Consistency Model

ENOR-CPU uses **sequential consistency** for all memory operations.

**Rules:**
1. All memory operations appear to execute in program order
2. All memory operations are visible to all observers in the same order
3. No reordering of memory operations

### 6.2 Implications

- No need for memory barriers in v0.1 (single-core)
- Load/store operations complete before next instruction executes
- Vector/matrix operations complete before next instruction executes

### 6.3 Future Considerations

In multi-core versions, explicit memory ordering instructions will be required:
- FENCE: Order all memory operations
- FENCE.I: Order instruction and data memory operations

## 7. Memory Exceptions

### 7.1 Exception Types

| Exception | Cause | Handler |
|-----------|-------|---------|
| Instruction address misalign | PC[1:0] != 0 | Exception handler |
| Instruction access fault | Code SRAM access error | Exception handler |
| Load address misalign | LH/LHU addr[0] != 0, LW addr[1:0] != 0 | Exception handler |
| Store address misalign | SH addr[0] != 0, SW addr[1:0] != 0 | Exception handler |
| Load access fault | Data SRAM access error | Exception handler |
| Store access fault | Data SRAM access error | Exception handler |
| Vector load misalign | VLW addr[4:0] != 0 | Exception handler |
| Vector store misalign | VSW addr[4:0] != 0 | Exception handler |

### 7.2 Exception Handling

When a memory exception occurs:
1. Save PC to EPC CSR
2. Set ECAUSE CSR to exception code
3. Disable interrupts (IE = 0)
4. Jump to exception handler (0x00001000)

## 8. Memory Performance

### 8.1 Access Latency

| Access Type | Latency | Throughput |
|-------------|---------|------------|
| Instruction fetch | 1 cycle | 1 instruction/cycle |
| Scalar load | 2 cycles | 1 load/2 cycles |
| Scalar store | 2 cycles | 1 store/2 cycles |
| Vector load | 1 cycle | 256 bits/cycle |
| Vector store | 1 cycle | 256 bits/cycle |
| Matrix load | 4 cycles | 512 bits/4 cycles |
| Matrix store | 4 cycles | 512 bits/4 cycles |

### 8.2 Bandwidth

| Interface | Width | Bandwidth |
|-----------|-------|-----------|
| Instruction fetch | 32 bits | 32 bits/cycle |
| Scalar data | 32 bits | 32 bits/cycle |
| Vector data | 256 bits | 256 bits/cycle |
| Matrix data | 512 bits | 128 bits/cycle (4-cycle latency) |

### 8.3 Bottlenecks

1. **Scalar data bandwidth:** 32 bits/cycle may limit control-heavy code
2. **Matrix bandwidth:** 512 bits per 4 cycles = 128 bits/cycle effective
3. **No caching:** All accesses go to SRAM (no cache hits)

## 9. Memory Initialization

### 9.1 Reset State

On hardware reset:
- Code SRAM: Unchanged (holds programmed instructions)
- Data SRAM: Undefined
- Matrix SRAM: Undefined
- Vector SRAM: Undefined
- Matrix Accumulator: Undefined

### 9.2 Firmware Loading

Firmware is loaded via UART or other boot mechanism:
1. Receive firmware bytes via UART
2. Write to code SRAM starting at 0x00000000
3. Verify checksum
4. Start execution at 0x00000000

## 10. Memory Protection

### 10.1 v0.1 Protection

No memory protection in v0.1:
- No privilege levels
- No memory access control
- No address space isolation

### 10.2 Future Protection

v0.2 may add:
- Supervisor/user mode
- Memory access permissions
- Address space IDs
- Physical memory protection (PMP)

## 11. Example Memory Operations

### 11.1 Scalar Load Example

```
# Load word from address in x5 + 8
LW x6, 8(x5)

# Execution:
# addr = x[5] + 8
# x[6] = mem[addr][31:0]
```

### 11.2 Vector Load Example

```
# Load vector from address in x5
VSETVL x6, 8      # Set VL = 8
VLW v0, 0(x5)     # Load 8 words into v0

# Execution:
# addr = x[5]
# v[0][31:0] = mem[addr][31:0]
# v[0][63:32] = mem[addr+4][31:0]
# ...
# v[0][255:224] = mem[addr+28][31:0]
```

### 11.3 Matrix Load Example

```
# Load 8x8 matrix from address in x5
CSRRW x0, 0x002, x6   # Set VLX = 8
CSRRW x0, 0x003, x6   # Set VLY = 8
MLOAD x5              # Load matrix to M0

# Execution:
# addr = x[5]
# for i = 0 to 7:
#   for j = 0 to 7:
#     M0[i][j] = mem[addr + (i*8 + j)*4]
```

### 11.4 Store Example

```
# Store word to address in x5 + 12
SW x6, 12(x5)

# Execution:
# addr = x[5] + 12
# mem[addr][31:0] = x[6][31:0]
```

## 12. Memory Map Summary

| Range | Size | Type | Description |
|-------|------|------|-------------|
| 0x00000000-0x00007FFF | 32 KB | Code SRAM | Instruction storage |
| 0x00008000-0x3FFFFFFF | ~1 GB | Reserved | Unused |
| 0x40000000-0x4000FFFF | 64 KB | Data SRAM | General data |
| 0x40000000-0x40007FFF | 32 KB | Matrix SRAM | Matrix tiles |
| 0x40000000-0x40003FFF | 16 KB | Vector SRAM | Vector data |
| 0x40000000-0x400000FF | 256 B | Matrix Acc | M0 accumulator |
| 0x40010000-0x7FFFFFFF | ~1 GB | Reserved | Unused |
| 0x80000000 | 4 B | UART | Serial data |
| 0x80000004 | 4 B | UART | Serial status |
| 0x80000008 | 4 B | Timer | Timer value |
| 0x8000000C | 4 B | Timer | Timer compare |
| 0x80000010 | 4 B | GPIO | GPIO output |
| 0x80000014 | 4 B | GPIO | GPIO input |
| 0x80000018 | 4 B | Int | Interrupt enable |
| 0x8000001C | 4 B | Int | Interrupt status |
| 0x80000020-0xBFFFFFFF | ~1 GB | I/O | Future peripherals |

## 13. Open Questions

1. **Memory Remapping:** Should we allow remapping of SRAM to different address ranges, or keep fixed?

2. **Cache:** Should we add a small instruction cache (1-2 KB) to improve code density?

3. **Write Buffer:** Should we add a write buffer to hide store latency?

4. **Atomic Operations:** Should we add atomic operations (LR/SC) for future multi-core?

5. **Memory Encryption:** Should we add memory encryption for security?
