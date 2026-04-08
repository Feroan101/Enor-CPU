# ENOR-CPU Design Decisions

**Version:** 0.1-draft  
**Status:** Design Phase  
**Last Updated:** 2026-08-24

This document records major architectural decisions, the reasoning behind them, and their trade-offs.

---

## Decision 1: RISC-style Fixed-Width Instructions

**Decision:** Use fixed-width 32-bit instructions following RISC design principles.

**Alternatives Considered:**
1. Variable-length instructions (16/32-bit like ARM Thumb-2)
2. Very Long Instruction Word (VLIW) with variable slots
3. Custom encoding optimized for AI operations

**Reasoning:**
- Simplicity in fetch and decode logic
- Aligns with FPGA block RAM widths (32-bit)
- Well-understood design space
- Easier verification and debugging
- Compatible with existing RISC-V ecosystem concepts

**Advantages:**
- Simple, predictable instruction fetch
- Easy to decode (fixed field positions)
- Efficient use of code memory
- Straightforward pipeline design

**Disadvantages:**
- Lower code density than variable-length encodings
- May waste bits for simple instructions
- Less flexible for future extensions

**Consequences:**
- Code size may be 20-30% larger than variable-length alternatives
- Pipeline design is significantly simpler
- Decode logic uses fewer LUTs on FPGA

**Status:** DECIDED

---

## Decision 2: 32-bit Scalar / 256-bit Vector Architecture

**Decision:** Use 32-bit scalar datapath with 256-bit vector datapath (8x INT32 lanes).

**Alternatives Considered:**
1. 64-bit scalar with 512-bit vector
2. 16-bit scalar with 128-bit vector
3. Purely 32-bit (no dedicated vector unit)
4. 32-bit scalar with 128-bit vector (4 lanes)

**Reasoning:**
- 32-bit addresses provide 4 GB address space (sufficient for embedded AI)
- 32-bit integers sufficient for quantized inference (INT8/INT16)
- 256-bit vectors provide 8x INT32 parallelism (good balance)
- 128-bit would limit vector throughput significantly
- 512-bit would increase register file size and area

**Advantages:**
- 4 GB address space
- Good vector parallelism (8 operations/cycle)
- Reasonable register file size (4 KB for 16 vector registers)
- Aligns with common memory bus widths

**Disadvantages:**
- 32-bit may limit address space for large models
- 256-bit vectors require significant routing resources
- Element-wise operations limited to 8 per cycle

**Consequences:**
- Vector register file: 16 x 256-bit = 4096 bits
- Scalar register file: 32 x 32-bit = 1024 bits
- Vector operations process 8 INT32 elements per cycle

**Status:** DECIDED

---

## Decision 3: In-Order Pipeline Without Speculation

**Decision:** Use a simple 5-stage in-order pipeline with no speculation or out-of-order execution.

**Alternatives Considered:**
1. Out-of-order execution (like modern CPUs)
2. Speculative execution with branch prediction
3. VLIW with compiler scheduling
4. Simple multi-cycle implementation (no pipeline)

**Reasoning:**
- Dramatically reduces design complexity
- Easier to verify and debug
- Sufficient for deterministic AI workloads
- Lower power consumption
- FPGA-friendly (fewer control signals)

**Advantages:**
- Simple hazard detection and forwarding
- Predictable timing (important for real-time AI)
- Small area on FPGA
- Easy to reason about correctness

**Disadvantages:**
- Lower Instructions Per Cycle (IPC) than OoO designs
- Branch penalties reduce performance
- Cannot hide memory latency well
- Compiler must handle scheduling

**Consequences:**
- 5-stage pipeline with 2-cycle branch penalty
- No branch prediction (v0.1)
- Compiler responsible for instruction scheduling
- Forwarding unit required for data hazards

**Status:** DECIDED

---

## Decision 4: Dedicated Matrix Unit

**Decision:** Include a dedicated 8x8 INT8 matrix multiply unit as a first-class architectural component.

**Alternatives Considered:**
1. No dedicated matrix unit (use vector unit only)
2. Systolic array (like Google TPU)
3. Smaller 4x4 matrix unit
4. Larger 16x16 matrix unit
5. Configurable matrix dimensions

**Reasoning:**
- Matrix multiply is the dominant operation in neural networks
- 8x8 INT8 provides 64 MACs/cycle (significant speedup)
- 8x8 is small enough for FPGA implementation
- Larger arrays require more DSPs (may not fit)
- Systolic arrays add complexity (control, data flow)

**Advantages:**
- 64x speedup for matrix multiply vs scalar
- 8x8 fits in reasonable FPGA resources (16-32 DSPs)
- Simple control (no systolic data flow)
- Clear architectural purpose

**Disadvantages:**
- Limited to 8x8 tiles (must loop for larger matrices)
- Only INT8 multiplication (no INT16/FP16 in v0.1)
- Requires dedicated matrix SRAM (32 KB)
- Increases design complexity

**Consequences:**
- Matrix SRAM: 32 KB dual-port
- Accumulator: 8x8 x 32-bit = 2048 bits
- Matrix instructions: MMUL, MMAC, MLOAD, MSTORE
- Compiler must handle tiling for matrices > 8x8

**Status:** DECIDED

---

## Decision 5: Harvard Memory Architecture

**Decision:** Use a modified Harvard architecture with separate code and data SRAMs.

**Alternatives Considered:**
1. Von Neumann (unified memory)
2. Pure Harvard (completely separate)
3. Modified Harvard (separate L1, unified L2)
4. Split-code/data with shared cache

**Reasoning:**
- Simpler memory interface (no arbitration needed)
- Code SRAM can be read every cycle (no stalls)
- Data SRAM can be accessed simultaneously
- No need for complex cache coherence
- FPGA block RAMs are inherently dual-port

**Advantages:**
- Simpler memory controller
- Higher memory bandwidth (parallel access)
- No structural hazards on memory
- Deterministic timing

**Disadvantages:**
- Fixed allocation between code and data memory
- Less flexible than unified memory
- May waste memory if one space is underutilized

**Consequences:**
- Code SRAM: 32 KB (instruction fetch only)
- Data SRAM: 64 KB (data access only)
- Matrix SRAM: 32 KB (matrix operations)
- Vector SRAM: 16 KB (vector operations)
- Total on-chip SRAM: 144 KB

**Status:** DECIDED

---

## Decision 6: 32 Scalar Registers

**Decision:** Include 32 general-purpose scalar registers (x0-x31).

**Alternatives Considered:**
1. 16 registers (like MIPS)
2. 32 registers (like RISC-V, ARM)
3. 64 registers (like SPARC)
4. 8 registers (minimal)

**Reasoning:**
- 32 registers is the RISC standard (good balance)
- Provides sufficient registers for most functions
- Compatible with RISC-V calling conventions (easy porting)
- 16 registers may require excessive spilling
- 64 registers increase context switch cost and area

**Advantages:**
- Industry standard (RISC-V compatibility)
- Good register utilization for most code
- Reasonable context save size (128 bytes)
- Fits in standard encoding (5-bit register fields)

**Disadvantages:**
- 160 bytes of register file area (32 x 32-bit x 5 read ports)
- May still require spilling for complex functions
- Context save on interrupt: 128 bytes

**Consequences:**
- Register file: 32 x 32-bit, 2-read, 1-write
- Calling convention: x1 (RA), x2 (SP), x10-x11 (args/rets)
- Context save: 32 x 4 bytes = 128 bytes

**Status:** DECIDED

---

## Decision 7: 16 Vector Registers

**Decision:** Include 16 vector registers (v0-v15), each 256 bits wide.

**Alternatives Considered:**
1. 8 vector registers
2. 16 vector registers
3. 32 vector registers
4. Memory-mapped vector registers (no register file)

**Reasoning:**
- 16 registers provide good register reuse
- 256-bit width enables 8x INT32 operations
- Reasonable register file size (4 KB)
- 32 registers would double area and routing

**Advantages:**
- Sufficient for most vector loops
- Good balance between parallelism and area
- Clear vector register encoding

**Disadvantages:**
- 4 KB register file is significant on small FPGAs
- Limited registers may require spilling for large vectors
- No support for vector chaining in v0.1

**Consequences:**
- Vector register file: 16 x 256-bit = 4096 bits
- Vector length register (VL) controls active lanes
- No vector masking in v0.1 (all lanes active)

**Status:** DECIDED

---

## Decision 8: Fixed-Point Only (No FP Hardware)

**Decision:** v0.1 uses integer arithmetic only (INT8, INT16, INT32). No floating-point hardware.

**Alternatives Considered:**
1. FP16 hardware support
2. FP32 hardware support
3. Software floating-point emulation
4. Fixed-point arithmetic only

**Reasoning:**
- Floating-point hardware significantly increases area and complexity
- Quantized inference (INT8) is sufficient for many AI workloads
- Software emulation available for FP16/FP32 if needed
- Reduces FPGA resource usage by 30-50%

**Advantages:**
- Much simpler ALU design
- Smaller area (no FP units)
- Faster development time
- Sufficient for quantized neural networks

**Disadvantages:**
- Some AI workloads require FP16/FP32
- Software emulation is slower
- May limit accuracy for some models
- Not compatible with all AI frameworks

**Consequences:**
- Integer ALU only (no FP units)
- Software library needed for FP16/FP32 operations
- Quantization-aware training required for best results
- Later versions (v0.2) may add FP16 hardware

**Status:** DECIDED

---

## Decision 9: No Branch Prediction

**Decision:** v0.1 does not include branch prediction hardware.

**Alternatives Considered:**
1. Static prediction (always taken/not taken)
2. 1-bit predictor
3. 2-bit saturating counter
4. BTB (Branch Target Buffer)
5. No prediction (always flush on branch)

**Reasoning:**
- Branch prediction adds complexity and area
- 2-cycle penalty is acceptable for control code
- AI workloads are dominated by loops (predictable)
- Compiler can schedule around branches
- Simplifies verification significantly

**Advantages:**
- Minimal control logic
- No predictor state to manage
- Deterministic behavior
- Easier to verify

**Disadvantages:**
- 2-cycle penalty on every taken branch
- May reduce performance for branch-heavy code
- Not suitable for general-purpose computing

**Consequences:**
- Branch penalty: 2 cycles (always)
- Compiler should minimize branches
- Loop unrolling recommended
- Later versions may add simple prediction

**Status:** DECIDED

---

## Decision 10: Memory-Mapped I/O

**Decision:** Use memory-mapped I/O for all peripheral access.

**Alternatives Considered:**
1. Port-mapped I/O (separate address space)
2. Memory-mapped I/O (unified address space)
3. Special I/O instructions
4. DMA-based I/O

**Reasoning:**
- Memory-mapped I/O is simpler and more flexible
- No special instructions needed
- Same load/store instructions work for I/O
- Well-understood and widely used

**Advantages:**
- Simple implementation
- Uses existing load/store instructions
- Flexible (any address can be I/O)
- No special decoding logic

**Disadvantages:**
- I/O addresses consume address space
- May be slower than port-mapped I/O
- No protection against accidental I/O access

**Consequences:**
- I/O address space: 0x80000000 - 0xBFFFFFFF
- Peripherals accessed via standard load/store
- No memory protection (v0.1)

**Status:** DECIDED

---

## Decision 11: Single Clock Domain

**Decision:** Use a single clock domain for all v0.1 components.

**Alternatives Considered:**
1. Multiple clock domains (async crossings)
2. Single clock domain (synchronous)
3. Clock gating for power management

**Reasoning:**
- Single clock domain is simplest to design and verify
- No clock domain crossing issues
- Easier timing closure on FPGA
- Power management can be added later

**Advantages:**
- Simple timing analysis
- No clock domain crossing logic
- Easier to debug
- Faster development

**Disadvantages:**
- Higher power consumption (no clock gating)
- Less flexibility for future additions
- May limit maximum frequency

**Consequences:**
- Single 50 MHz clock (target)
- No clock gating in v0.1
- All registers update on same edge
- Power management added in v0.2

**Status:** DECIDED

---

## Decision 12: Vector Length Register (VLR)

**Decision:** Use a configurable vector length register (VL) to control active vector lanes.

**Alternatives Considered:**
1. Fixed vector length (always 8 lanes)
2. Configurable vector length (VL register)
3. Per-instruction vector length encoding
4. Mask registers for lane control

**Reasoning:**
- VL register allows flexible vector lengths (1-8)
- No wasted cycles for sub-word operations
- Simple implementation (just gate lane outputs)
- More efficient than masking

**Advantages:**
- Efficient for different data types (INT8, INT16, INT32)
- No wasted compute cycles
- Simple control logic
- Compatible with RISC-V V-extension concepts

**Disadvantages:**
- Adds state to manage
- Must save/restore on context switch
- Slightly more complex decode logic

**Consequences:**
- VL register: 32-bit, values 1-8 valid
- Default: 8 (all lanes active)
- Must be set before vector operations
- Context save: 4 bytes for VL

**Status:** DECIDED

---

## Decision 13: No Cache

**Decision:** v0.1 uses SRAM only, no cache hierarchy.

**Alternatives Considered:**
1. Direct-mapped cache
2. Set-associative cache
3. Fully associative cache
4. No cache (SRAM only)

**Reasoning:**
- SRAM provides deterministic timing (important for AI)
- Cache adds complexity and unpredictability
- SRAM sufficient for embedded AI workloads
- No need for cache coherence (single core)

**Advantages:**
- Deterministic memory access timing
- Simple memory controller
- No cache misses to handle
- Easier to verify

**Disadvantages:**
- Limited memory capacity (144 KB total)
- No automatic data reuse
- Must manually manage data movement

**Consequences:**
- All data must fit in SRAM (144 KB)
- Compiler/runtime must manage data tiling
- No automatic caching of frequently accessed data
- Later versions may add cache for larger models

**Status:** DECIDED

---

## Decision 14: 8x8 Matrix Tile Size

**Decision:** Use 8x8 as the native matrix tile size.

**Alternatives Considered:**
1. 4x4 matrix tile
2. 8x8 matrix tile
3. 16x16 matrix tile
4. Configurable tile size

**Reasoning:**
- 8x8 provides 64 MACs/cycle (good throughput)
- 16x16 requires 256 multipliers (too many for FPGA)
- 4x4 only provides 16 MACs/cycle (too low)
- 8x8 fits in reasonable FPGA resources (16-32 DSPs)

**Advantages:**
- 64 MACs/cycle is significant speedup
- Fits in mid-range FPGA (16-32 DSPs)
- Simple control logic
- Good balance of throughput and area

**Disadvantages:**
- Limited to 8x8 tiles (must loop for larger matrices)
- May not be optimal for all matrix sizes
- Fixed tile size limits flexibility

**Consequences:**
- Matrix operations: 8x8 tiles
- Accumulator: 8x8 x 32-bit = 2048 bits
- Matrix SRAM: 32 KB (stores multiple 8x8 tiles)
- Compiler must handle tiling for larger matrices

**Status:** DECIDED

---

## Decision 15: Synchronous Reset

**Decision:** Use asynchronous active-low reset (standard for FPGA).

**Alternatives Considered:**
1. Synchronous reset
2. Asynchronous reset
3. No reset (power-on defaults)

**Reasoning:**
- Asynchronous reset is standard for FPGA
- Easier to meet timing constraints
- Well-supported by FPGA tools
- Can be synchronized internally if needed

**Advantages:**
- Standard practice for FPGA design
- Easy to implement
- Reliable initialization
- Tool support

**Disadvantages:**
- Must handle reset removal carefully
- May cause metastability if not synchronized
- Adds complexity to timing analysis

**Consequences:**
- Reset pin: active-low
- Hold time: 16 clock cycles minimum
- All registers reset to known state
- PC starts at 0x00000000

**Status:** DECIDED

---

## Decision 16: No DMA Engine

**Decision:** v0.1 does not include a DMA engine.

**Alternatives Considered:**
1. Simple DMA engine
2. Complex DMA with scatter-gather
3. No DMA (CPU handles all transfers)
4. Lightweight DMA (memory-to-memory only)

**Reasoning:**
- DMA adds complexity and area
- CPU can handle data movement with vector loads/stores
- Vector load/store provides 256 bits/cycle bandwidth
- DMA can be added in v0.2 if needed

**Advantages:**
- Simpler design
- Less area
- Easier to verify
- Vector unit provides good bandwidth

**Disadvantages:**
- CPU must handle all data movement
- May limit throughput for large data transfers
- Cannot overlap compute and data movement

**Consequences:**
- All data movement via CPU instructions
- Vector load/store: 256 bits/cycle
- No background data transfers
- Later versions may add DMA

**Status:** DECIDED

---

## Decision 17: No Virtual Memory

**Decision:** v0.1 does not include virtual memory or MMU.

**Alternatives Considered:**
1. Simple MMU with page tables
2. TLB-based virtual memory
3. No virtual memory (physical addresses only)
4. Memory protection unit (MPU)

**Reasoning:**
- Virtual memory adds significant complexity
- Physical addressing sufficient for embedded AI
- No need for memory protection in single-task system
- Simplifies memory controller

**Advantages:**
- Simple memory access (no address translation)
- Deterministic timing (no TLB misses)
- Less area (no page table walker)
- Easier verification

**Disadvantages:**
- No memory protection
- No memory overcommitment
- Limited to physical memory size
- Not suitable for multi-tasking OS

**Consequences:**
- Physical addressing only
- No memory protection
- Single address space
- Later versions may add MPU for security

**Status:** DECIDED

---

## Decision 18: UART for Serial Communication

**Decision:** Include UART peripheral for serial communication.

**Alternatives Considered:**
1. UART only
2. SPI only
3. I2C only
4. Multiple peripherals (UART + SPI + I2C)
5. No serial communication

**Reasoning:**
- UART is simplest to implement
- Sufficient for debugging and console I/O
- Widely supported by host computers
- Can be extended later

**Advantages:**
- Very simple (few hundred gates)
- Standard protocol
- Easy to connect to PC via USB-UART bridge
- Sufficient for debugging

**Disadvantages:**
- Slow (115200 baud = ~11.5 KB/s)
- Not suitable for high-speed data transfer
- Only one direction at a time (half-duplex in simple impl)

**Consequences:**
- UART: 8N1, 115200 baud default
- Used for: console I/O, debugging, firmware loading
- Later versions may add SPI for SD card access

**Status:** DECIDED

---

## Decision 19: No Multi-Core

**Decision:** v0.1 is single-core only.

**Alternatives Considered:**
1. Single core
2. Dual core
3. Quad core
4. Multi-threaded (SMT)

**Reasoning:**
- Multi-core adds significant complexity (coherence, synchronization)
- Single core sufficient for initial development
- AI workloads can use vector/matrix units for parallelism
- Easier to verify and debug

**Advantages:**
- Simple design
- No cache coherence issues
- Easier to verify
- Lower area

**Disadvantages:**
- Limited to one thread of execution
- Cannot overlap different tasks
- May not fully utilize all hardware units

**Consequences:**
- Single scalar pipeline
- Vector and matrix units are accelerators (not independent cores)
- No hardware multi-threading
- Later versions may add second core

**Status:** DECIDED

---

## Decision 20: Instruction Encoding Compatible with RISC-V

**Decision:** Use RISC-V-like instruction encoding (not RISC-V compliant, but compatible structure).

**Alternatives Considered:**
1. RISC-V compliant (full ISA)
2. RISC-V-like encoding (custom ISA)
3. Completely custom encoding
4. ARM-like encoding

**Reasoning:**
- RISC-V is the modern standard for custom processors
- Compatible encoding allows potential RISC-V toolchain reuse
- Well-documented encoding schemes
- Large community and resources

**Advantages:**
- Potential toolchain compatibility
- Well-documented encoding
- Community support
- Familiar to developers

**Disadvantages:**
- Not fully RISC-V compliant (custom instructions)
- May confuse RISC-V purists
- Custom matrix/vector instructions break compatibility

**Consequences:**
- Scalar instructions: RISC-V compatible encoding
- Vector instructions: RISC-V V-extension-like encoding
- Matrix instructions: Custom encoding
- Toolchain may need custom modifications

**Status:** DECIDED

---

## OPEN Decisions

### OPEN-1: Branch Prediction Strategy

**Question:** Should v0.2 add branch prediction?

**Options:**
1. Static prediction (always taken)
2. 1-bit predictor (last outcome)
3. 2-bit saturating counter
4. BTB (Branch Target Buffer)

**Trade-offs:**
- Static: simplest, no state
- 1-bit: simple, some state
- 2-bit: better accuracy, more state
- BTB: best accuracy, most complex

**Recommendation:** Start with static prediction, add 2-bit counter in v0.2 if needed.

**Status:** OPEN

---

### OPEN-2: Cache Strategy

**Question:** Should v0.2 add instruction cache?

**Options:**
1. Direct-mapped cache (simplest)
2. 2-way set-associative cache
3. No cache (keep SRAM-only)
4. Small cache (1-2 KB) for hot code

**Trade-offs:**
- Cache adds complexity but improves code density
- SRAM-only is simpler but limits code size
- Small cache is a compromise

**Recommendation:** Add 4 KB direct-mapped instruction cache in v0.2.

**Status:** OPEN

---

### OPEN-3: DMA Engine

**Question:** Should v0.2 add DMA for data movement?

**Options:**
1. Simple memory-to-memory DMA
2. Scatter-gather DMA
3. No DMA (keep CPU-based)
4. Lightweight DMA (8 channels)

**Trade-offs:**
- DMA improves throughput but adds complexity
- Scatter-gather is flexible but complex
- CPU-based is simplest but slower

**Recommendation:** Add simple 4-channel DMA in v0.2.

**Status:** OPEN

---

### OPEN-4: Interrupt Latency Requirements

**Question:** What is the maximum acceptable interrupt latency?

**Options:**
1. < 10 cycles (fast)
2. < 20 cycles (moderate)
3. < 50 cycles (relaxed)
4. No requirement

**Trade-offs:**
- Fast latency requires hardware context save
- Moderate latency allows software save
- Relaxed latency simplifies design

**Recommendation:** Target < 20 cycles for v0.1.

**Status:** OPEN

---

### OPEN-5: Power Management

**Question:** Should v0.1 include clock gating?

**Options:**
1. No clock gating (always running)
2. Module-level clock gating
3. Fine-grained clock gating
4. Dynamic voltage/frequency scaling

**Trade-offs:**
- No gating is simplest
- Module-level is easy to add
- Fine-grained saves most power but complex
- DVFS is too complex for v0.1

**Recommendation:** No clock gating in v0.1, add module-level in v0.2.

**Status:** OPEN

---

## Decision Summary

| # | Decision | Status | Version |
|---|----------|--------|---------|
| 1 | Fixed-width instructions | DECIDED | v0.1 |
| 2 | 32-bit scalar / 256-bit vector | DECIDED | v0.1 |
| 3 | In-order pipeline | DECIDED | v0.1 |
| 4 | Dedicated matrix unit | DECIDED | v0.1 |
| 5 | Harvard architecture | DECIDED | v0.1 |
| 6 | 32 scalar registers | DECIDED | v0.1 |
| 7 | 16 vector registers | DECIDED | v0.1 |
| 8 | Fixed-point only | DECIDED | v0.1 |
| 9 | No branch prediction | DECIDED | v0.1 |
| 10 | Memory-mapped I/O | DECIDED | v0.1 |
| 11 | Single clock domain | DECIDED | v0.1 |
| 12 | Configurable vector length | DECIDED | v0.1 |
| 13 | No cache | DECIDED | v0.1 |
| 14 | 8x8 matrix tile | DECIDED | v0.1 |
| 15 | Asynchronous reset | DECIDED | v0.1 |
| 16 | No DMA | DECIDED | v0.1 |
| 17 | No virtual memory | DECIDED | v0.1 |
| 18 | UART only | DECIDED | v0.1 |
| 19 | Single core | DECIDED | v0.1 |
| 20 | RISC-V-like encoding | DECIDED | v0.1 |

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Matrix unit too large for FPGA | High | Medium | Start with 4x4, scale to 8x8 |
| Vector register file routing | Medium | High | Optimize placement, reduce width if needed |
| Memory bandwidth bottleneck | High | Medium | Add DMA in v0.2, optimize data layout |
| Timing closure at 50 MHz | Medium | Low | Simplify critical paths, reduce logic depth |

---

## ISA Audit Fixes (Phase 2)

The following fixes were applied during the Phase 2 ISA self-audit:

### Fix 1: Vector Instruction Count

**Issue:** Vector instruction count listed as 7 but 8 instructions were defined.

**Resolution:** Corrected count to 8.

### Fix 2: VSETVL Encoding Conflict

**Issue:** VSETVL was listed with funct7 = 0x10, which conflicted with VDOT (also 0x10).

**Resolution:** Changed VSETVL funct7 to 0x20 (no conflict with VDOT at 0x10).

### Fix 3: Matrix Latency

**Issue:** Matrix operations listed VLX * VLY * VLZ cycles latency (512 for 8x8), which is unrealistic.

**Resolution:** Changed to max(VLX, VLY, VLZ) cycles (8 for 8x8) with pipelined MAC array.

### Fix 4: SLTI/SLTIU Encoding

**Issue:** SLTI and SLTIU were listed in encoding tables but not in instruction definitions.

**Resolution:** Added SLTI and SLTIU to instruction definitions (I-type, opcode 0x13, funct3 0x02/0x03).

### Decisions on Open Questions

**Q1 (VTYPE Register):** Deferred. INT32 only for v0.1. Element width control via VTYPE register added in v0.2.

**Q2 (Vector Masking):** Deferred. No masking in v0.1. Added in v0.2.

**Q3 (Matrix Transpose):** Deferred. Software transpose sufficient for v0.1.

**Q4 (Stride Support):** Deferred. Contiguous access only in v0.1. Stride support added in v0.2.

**Q5 (Atomic Operations):** Deferred. No atomics in v0.1. Added in v0.3 for multi-core.
| Verification complexity | High | Medium | Modular design, comprehensive testbench |
