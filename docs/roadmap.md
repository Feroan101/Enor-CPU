# ENOR-CPU Implementation Roadmap

**Version:** 0.1-draft  
**Status:** Design Phase  
**Last Updated:** 2026-08-24

This document defines the implementation progression for ENOR-CPU from architecture specification through FPGA deployment.

---

## Overview

The roadmap is organized into phases, each building on the previous. Each phase has clear deliverables, verification criteria, and exit conditions.

```
Phase 0: Architecture Specification     ◄── CURRENT
Phase 1: ISA Specification
Phase 2: Minimal Scalar Processor
Phase 3: Simulator
Phase 4: Vector Acceleration
Phase 5: Matrix Acceleration
Phase 6: Memory/Data Movement Improvements
Phase 7: FPGA Implementation
Phase 8: AI Workload Benchmarking
```

---

## Phase 0: Architecture Specification

**Duration:** 2-3 weeks  
**Status:** IN PROGRESS

### Objectives
- Define overall ENOR-CPU architecture
- Document design decisions
- Establish implementation roadmap
- Get architecture reviewed and approved

### Deliverables

| Deliverable | Status | Description |
|-------------|--------|-------------|
| docs/architecture.md | ✅ Complete | Overall architecture specification |
| docs/microarchitecture.md | ✅ Complete | Implementation details |
| docs/design-decisions.md | ✅ Complete | Major decisions and rationale |
| docs/roadmap.md | ✅ Complete | This document |
| Architecture review | ⏳ Pending | Review meeting with stakeholders |

### Exit Criteria
- [ ] All architecture documents complete
- [ ] Architecture review conducted
- [ ] All OPEN questions resolved or deferred
- [ ] Architecture approved for implementation

### Open Questions to Resolve

1. **Branch prediction** - Static or dynamic for v0.2?
2. **Cache** - Add instruction cache in v0.2?
3. **DMA** - Add DMA engine in v0.2?
4. **Interrupt latency** - Maximum acceptable latency?
5. **Power management** - Clock gating needed?

---

## Phase 1: ISA Specification

**Duration:** 2-3 weeks  
**Dependencies:** Phase 0 complete

### Objectives
- Define complete instruction set architecture
- Document instruction encoding
- Create ISA reference manual
- Define assembler syntax

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| isa/instruction-set.md | Complete ISA reference |
| isa/encoding.md | Instruction encoding formats |
| isa/assembler-syntax.md | Assembly language syntax |
| isa/pseudo-instructions.md | Pseudo-instructions and macros |

### Tasks

1. **Scalar Instructions**
   - [ ] Integer arithmetic (ADD, SUB, AND, OR, XOR, shifts)
   - [ ] Memory instructions (LB, LH, LW, SB, SH, SW)
   - [ ] Control flow (BEQ, BNE, BLT, BGE, JAL, JALR)
   - [ ] System instructions (ECALL, EBREAK, CSR)

2. **Vector Instructions**
   - [ ] Vector arithmetic (VADD, VSUB, VMUL)
   - [ ] Vector reductions (VDOT, VRED_SUM, VRED_MAX)
   - [ ] Vector loads/stores (VLW, VSW, VLW_STRIDE)
   - [ ] Vector configuration (VSETVL)

3. **Matrix Instructions**
   - [ ] Matrix multiply (MMUL, MMAC)
   - [ ] Matrix load/store (MLOAD, MSTORE)
   - [ ] Matrix configuration (MSETDIM)

4. **Encoding**
   - [ ] R-type encoding
   - [ ] I-type encoding
   - [ ] S-type encoding
   - [ ] B-type encoding
   - [ ] U-type encoding
   - [ ] V-type encoding (vector)
   - [ ] M-type encoding (matrix)

### Exit Criteria
- [ ] All instructions documented
- [ ] Encoding fully specified
- [ ] Assembler syntax defined
- [ ] ISA reviewed and approved

---

## Phase 2: Minimal Scalar Processor

**Duration:** 4-6 weeks  
**Dependencies:** Phase 1 complete

### Objectives
- Implement scalar control unit in SystemVerilog
- Create testbench for unit verification
- Run simple test programs
- Synthesize for FPGA

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| rtl/scalar/ | Scalar processor RTL |
| rtl/common/ | Shared modules (ALU, regfile, etc.) |
| tests/scalar/ | Scalar processor tests |
| sim/scalar/ | Simulation scripts |

### Module Hierarchy

```
enor_cpu_top
├── scalar_core
│   ├── if_stage
│   │   ├── pc_register
│   │   ├── instruction_fetch
│   │   └── branch_adder
│   ├── id_stage
│   │   ├── instruction_decode
│   │   ├── register_file
│   │   └── immediate_gen
│   ├── ex_stage
│   │   ├── alu
│   │   ├── branch_logic
│   │   └── forwarding_mux
│   ├── mem_stage
│   │   ├── data_memory
│   │   └── store_buffer
│   └── wb_stage
│       └── writeback_mux
├── control
│   ├── hazard_detection
│   ├── forwarding_unit
│   └── stall_logic
├── memory_interface
│   ├── code_sram
│   └── data_sram
└── io_peripheral
    ├── uart
    └── timer
```

### Tasks

1. **Pipeline Stages** (2 weeks)
   - [ ] IF stage (PC, instruction fetch)
   - [ ] ID stage (decode, register file)
   - [ ] EX stage (ALU, branch logic)
   - [ ] MEM stage (memory access)
   - [ ] WB stage (writeback)

2. **Control Logic** (1 week)
   - [ ] Hazard detection unit
   - [ ] Forwarding unit
   - [ ] Stall logic

3. **Memory Interface** (1 week)
   - [ ] Code SRAM interface
   - [ ] Data SRAM interface
   - [ ] Memory controller

4. **Peripherals** (1 week)
   - [ ] UART module
   - [ ] Timer module
   - [ ] GPIO module

5. **Verification** (1 week)
   - [ ] Unit testbenches
   - [ ] Integration tests
   - [ ] Simple program test

### Verification Strategy

**Unit Tests:**
- ALU: all operations, edge cases
- Register file: read/write, write-first
- Hazard detection: RAW, load-use
- Forwarding: EX, MEM, WB paths

**Integration Tests:**
- Pipeline stall on load-use
- Branch flush and redirect
- Forwarding correctness
- Memory access patterns

**Program Tests:**
- Fibonacci sequence
- Matrix multiply (scalar)
- Simple loop with branch
- Function call/return

### Exit Criteria
- [ ] All scalar instructions implemented
- [ ] Hazard detection working
- [ ] Forwarding working
- [ ] UART output working
- [ ] Simple programs execute correctly
- [ ] Synthesizes on FPGA (Xilinx Artix-7)

---

## Phase 3: Simulator

**Duration:** 3-4 weeks  
**Dependencies:** Phase 2 complete

### Objectives
- Create cycle-accurate simulator
- Support all scalar instructions
- Generate execution traces
- Enable software development without FPGA

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| sim/enor_sim.cpp | Main simulator |
| sim/decoder.cpp | Instruction decoder |
| sim/executor.cpp | Instruction executor |
| sim/memory.cpp | Memory model |
| sim/trace.cpp | Execution trace generator |
| sim/cli.cpp | Command-line interface |

### Features

1. **Functional Simulation**
   - [ ] Instruction fetch
   - [ ] Instruction decode
   - [ ] Instruction execution
   - [ ] Memory access
   - [ ] Register updates

2. **Trace Generation**
   - [ ] Instruction trace
   - [ ] Memory access trace
   - [ ] Pipeline stall trace
   - [ ] Branch taken/not taken

3. **Debug Interface**
   - [ ] Single-step execution
   - [ ] Breakpoints
   - [ ] Register dump
   - [ ] Memory dump

4. **Performance Counters**
   - [ ] Instruction count
   - [ ] Cycle count
   - [ ] Stall count
   - [ ] Branch count

### Exit Criteria
- [ ] Simulator runs all scalar programs
- [ ] Trace matches RTL simulation
- [ ] Debug interface working
- [ ] Performance counters accurate

---

## Phase 4: Vector Acceleration

**Duration:** 4-6 weeks  
**Dependencies:** Phase 2 complete (parallel with Phase 3)

### Objectives
- Implement vector unit
- Add vector register file
- Implement vector instructions
- Verify vector operations

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| rtl/vector/ | Vector unit RTL |
| rtl/vector/regfile.sv | Vector register file |
| rtl/vector/alu.sv | Vector ALU (8 lanes) |
| rtl/vector/load_store.sv | Vector load/store unit |
| tests/vector/ | Vector unit tests |

### Module Hierarchy

```
vector_unit
├── vector_regfile
│   ├── lane0_reg
│   ├── lane1_reg
│   └── ...
│   └── lane7_reg
├── vector_alu
│   ├── lane0_alu
│   ├── lane1_alu
│   └── ...
│   └── lane7_alu
├── reduction_unit
│   └── adder_tree
├── vector_load_store
│   ├── address_gen
│   └── burst_controller
└── vector_control
    ├── decoder
    └── sequencer
```

### Tasks

1. **Vector Register File** (1 week)
   - [ ] 16 x 256-bit registers
   - [ ] 2 read ports, 1 write port
   - [ ] Write-first semantics

2. **Vector ALU** (2 weeks)
   - [ ] 8 parallel lanes
   - [ ] Each lane: 32-bit integer ALU
   - [ ] Element width configuration

3. **Vector Load/Store** (1 week)
   - [ ] Burst read/write (256 bits/cycle)
   - [ ] Stride support
   - [ ] Alignment logic

4. **Vector Control** (1 week)
   - [ ] Instruction decoder
   - [ ] Sequencer for multi-cycle ops
   - [ ] VL register management

5. **Verification** (1 week)
   - [ ] Unit tests for each module
   - [ ] Integration tests
   - [ ] Vector program tests

### Test Programs

- Vector add (8 elements)
- Vector multiply (8 elements)
- Dot product (8 elements)
- Vector sum reduction
- Vector load/store with stride

### Exit Criteria
- [ ] All vector instructions implemented
- [ ] 8-lane operation verified
- [ ] Reduction operations working
- [ ] Vector load/store working
- [ ] Synthesizes on FPGA

---

## Phase 5: Matrix Acceleration

**Duration:** 4-6 weeks  
**Dependencies:** Phase 2 complete (parallel with Phase 3-4)

### Objectives
- Implement matrix multiply unit
- Add matrix SRAM
- Implement matrix instructions
- Verify matrix operations

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| rtl/matrix/ | Matrix unit RTL |
| rtl/matrix/multiply_array.sv | 8x8 multiply array |
| rtl/matrix/accumulator.sv | Accumulator buffer |
| rtl/matrix/controller.sv | Matrix controller |
| rtl/matrix/sram.sv | Matrix SRAM |
| tests/matrix/ | Matrix unit tests |

### Module Hierarchy

```
matrix_unit
├── multiply_array
│   ├── mac_unit (64 instances)
│   └── weight_buffer
├── accumulator
│   ├── row0_acc (8 x 32-bit)
│   ├── row1_acc (8 x 32-bit)
│   └── ...
│   └── row7_acc (8 x 32-bit)
├── matrix_sram
│   ├── sram_core
│   └── port_mux
└── controller
    ├── decoder
    ├── sequencer
    └── tile_counter
```

### Tasks

1. **Multiply Array** (2 weeks)
   - [ ] 8x8 INT8 multiplier array
   - [ ] Weight buffer (8x8)
   - [ ] Input buffer (8-element)
   - [ ] 32-bit accumulator per MAC

2. **Accumulator Buffer** (1 week)
   - [ ] 8 rows x 8 columns x 32-bit
   - [ ] Dual-port access
   - [ ] Clear/set operations

3. **Matrix SRAM** (1 week)
   - [ ] 32 KB dual-port SRAM
   - [ ] Tile-based organization
   - [ ] Read/write interface

4. **Matrix Controller** (1 week)
   - [ ] Instruction decoder
   - [ ] Sequencer for 8-cycle multiply
   - [ ] Tile counter
   - [ ] Dimension registers

5. **Verification** (1 week)
   - [ ] Unit tests for multiply array
   - [ ] Integration tests
   - [ ] Matrix program tests

### Test Programs

- 8x8 matrix multiply (single tile)
- 8x8 matrix multiply-accumulate
- Matrix load/store
- Larger matrix multiply (tiled)

### Exit Criteria
- [ ] 8x8 matrix multiply working
- [ ] MMAC operation working
- [ ] Matrix SRAM read/write working
- [ ] Tiled matrix multiply working
- [ ] Synthesizes on FPGA

---

## Phase 6: Memory/Data Movement Improvements

**Duration:** 3-4 weeks  
**Dependencies:** Phases 4-5 complete

### Objectives
- Optimize memory subsystem
- Add vector SRAM banked access
- Implement stride patterns
- Optimize data movement

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| rtl/memory/ | Memory subsystem |
| rtl/memory/vector_sram.sv | Banked vector SRAM |
| rtl/memory/stride_gen.sv | Stride address generator |
| rtl/memory/arbitrer.sv | Memory arbiter |
| tests/memory/ | Memory tests |

### Tasks

1. **Vector SRAM Banking** (1 week)
   - [ ] 4-bank organization
   - [ ] Interleaved addressing
   - [ ] Parallel lane access

2. **Stride Patterns** (1 week)
   - [ ] Configurable byte stride
   - [ ] Burst mode for contiguous access
   - [ ] Scatter/gather patterns

3. **Memory Arbiter** (1 week)
   - [ ] Priority-based arbitration
   - [ ] Vector vs scalar access
   - [ ] Matrix vs vector access

4. **Data Movement Optimization** (1 week)
   - [ ] Software transpose routines
   - [ ] Im2col for convolution
   - [ ] Padding utilities

### Exit Criteria
- [ ] Banked vector SRAM working
- [ ] Stride patterns verified
- [ ] Memory arbiter functional
- [ ] Data movement benchmarks pass

---

## Phase 7: FPGA Implementation

**Duration:** 4-6 weeks  
**Dependencies:** Phases 4-6 complete

### Objectives
- Synthesize ENOR-CPU for FPGA
- Achieve timing closure
- Implement on real hardware
- Verify on FPGA

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| fpga/constraints/ | Timing constraints |
| fpga/synthesis/ | Synthesis scripts |
| fpga/implementation/ | Implementation scripts |
| fpga/bitstream/ | Bitstream files |
| fpga/test/ | FPGA test programs |

### Target FPGAs

1. **Primary:** Xilinx Artix-7 XC7A100T
   - 101,440 Logic Cells
   - 4,860 KB Block RAM
   - 240 DSP slices
   - Price: ~$50

2. **Alternative:** Lattice ECP5-5G
   - 41,200 LUTs
   - 3.7 Mb Block RAM
   - 192 DSPs
   - Price: ~$30

### Tasks

1. **Synthesis** (2 weeks)
   - [ ] Write synthesis constraints
   - [ ] Run synthesis
   - [ ] Analyze timing reports
   - [ ] Optimize critical paths

2. **Implementation** (2 weeks)
   - [ ] Place and route
   - [ ] Timing closure
   - [ ] Power analysis
   - [ ] Generate bitstream

3. **FPGA Testing** (2 weeks)
   - [ ] Program loading via UART
   - [ ] Simple test programs
   - [ ] Vector unit tests
   - [ ] Matrix unit tests
   - [ ] Performance measurement

### Resource Estimates

| Resource | Estimated | Available (XC7A100T) | Utilization |
|----------|-----------|----------------------|-------------|
| LUTs | 10,000 | 63,400 | 16% |
| FFs | 5,000 | 126,800 | 4% |
| BRAM | 10 | 135 | 7% |
| DSPs | 32 | 240 | 13% |

### Exit Criteria
- [ ] Synthesis completes
- [ ] Timing closure achieved (50 MHz)
- [ ] Bitstream generated
- [ ] FPGA boots and runs test program
- [ ] UART output working
- [ ] Vector operations verified on hardware
- [ ] Matrix operations verified on hardware

---

## Phase 8: AI Workload Benchmarking

**Duration:** 3-4 weeks  
**Dependencies:** Phase 7 complete

### Objectives
- Benchmark AI workloads
- Measure performance metrics
- Identify bottlenecks
- Document results

### Deliverables

| Deliverable | Description |
|-------------|-------------|
| benchmarks/ | Benchmark programs |
| benchmarks/matmul/ | Matrix multiply benchmark |
| benchmarks/conv2d/ | Convolution benchmark |
| benchmarks/relu/ | ReLU activation benchmark |
| benchmarks/inference/ | Full inference benchmark |
| results/ | Performance results |

### Benchmarks

1. **Matrix Multiply**
   - [ ] 8x8 INT8 matrix multiply
   - [ ] 64x64 INT8 matrix multiply (tiled)
   - [ ] 256x256 INT8 matrix multiply (tiled)
   - [ ] Measure: cycles, MACs/cycle, throughput

2. **Convolution**
   - [ ] 3x3 convolution on 32x32 input
   - [ ] 3x3 convolution on 224x224 input
   - [ ] Measure: cycles, throughput

3. **Activation Functions**
   - [ ] ReLU on 1024 elements
   - [ ] Sigmoid (software) on 1024 elements
   - [ ] Measure: cycles, throughput

4. **Full Inference**
   - [ ] Simple MLP (2 layers)
   - [ ] Simple CNN (2 layers)
   - [ ] Measure: total cycles, latency

### Performance Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| INT8 MACs/cycle | 64 | Matrix unit throughput |
| Vector ops/cycle | 8 | Vector unit throughput |
| Memory bandwidth | 256 bits/cycle | Vector load/store |
| Clock frequency | 50 MHz | Target FPGA frequency |
| Power | < 1W | Target power consumption |

### Exit Criteria
- [ ] All benchmarks run successfully
- [ ] Performance metrics documented
- [ ] Bottlenecks identified
- [ ] Results published

---

## Summary Timeline

```
Month 1:  Phase 0 (Architecture) + Phase 1 (ISA)
Month 2:  Phase 2 (Scalar Processor)
Month 3:  Phase 3 (Simulator) + Phase 4 (Vector)
Month 4:  Phase 5 (Matrix) + Phase 6 (Memory)
Month 5:  Phase 7 (FPGA)
Month 6:  Phase 8 (Benchmarks)
```

**Total estimated duration:** 6 months (part-time)

---

## Risk Mitigation

| Risk | Phase | Mitigation |
|------|-------|------------|
| Architecture issues | 0 | Thorough review, OPEN questions |
| ISA complexity | 1 | Start minimal, add later |
| Pipeline bugs | 2 | Comprehensive testbench |
| Timing closure | 7 | Simplify critical paths |
| Area overflow | 7 | Reduce matrix size if needed |
| Performance miss | 8 | Optimize hot paths, add cache |

---

## Success Criteria

### v0.1 Minimum Success
- Scalar processor runs simple programs
- Vector unit performs 8-element operations
- Matrix unit performs 8x8 multiply
- FPGA boots and runs test program
- UART output working

### v0.1 Full Success
- All benchmarks run
- 50 MHz timing closure
- < 1W power consumption
- < 10,000 LUTs utilization
- Documentation complete

### Future Success (v0.2+)
- FP16 hardware support
- Cache hierarchy
- DMA engine
- Multi-core support
- Advanced AI workloads

---

## Next Steps

1. **Immediate:** Complete architecture review
2. **Next week:** Start ISA specification
3. **Next month:** Begin RTL implementation

**Owner:** TBD  
**Review date:** TBD  
**Approval:** Pending
