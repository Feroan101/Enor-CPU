# ENOR-CPU

A custom processor architecture designed as the native hardware target for the Enor programming language, optimized for AI/ML workloads.

## Overview

ENOR-CPU is a RISC-style processor with dedicated vector and matrix acceleration units, designed for efficient execution of AI inference workloads. The architecture prioritizes implementability, simplicity, and verifiability while providing meaningful acceleration for neural network computations.

### Key Features

- **32-bit scalar processor** with 5-stage in-order pipeline
- **256-bit vector unit** (8 lanes for INT32 operations)
- **8x8 matrix multiply unit** (64 INT8 MACs/cycle)
- **Fixed-point arithmetic** (INT8, INT16, INT32)
- **Memory-mapped I/O** with UART, timer, and GPIO
- **FPGA-implementable** on Xilinx Artix-7 or similar

### Design Philosophy

ENOR-CPU is not a general-purpose CPU with AI extensions bolted on. It is an AI-oriented processor with general-purpose control capabilities. The architecture separates concerns:

- **Scalar Control Unit** - Program flow and address computation
- **Vector Unit** - Element-wise and reduction operations
- **Matrix Unit** - Dense matrix multiplication
- **Data Movement Engine** - Memory operations and data transformation

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Overall architecture specification |
| [Microarchitecture](docs/microarchitecture.md) | Implementation details |
| [Design Decisions](docs/design-decisions.md) | Major decisions and rationale |
| [Roadmap](docs/roadmap.md) | Implementation progression |

## Project Structure

```
enor-cpu/
├── docs/                    # Architecture documentation
├── isa/                     # ISA specification (Phase 1)
├── rtl/                     # SystemVerilog RTL (Phase 2+)
├── sim/                     # Simulator (Phase 3)
├── fpga/                    # FPGA implementation (Phase 7)
├── tests/                   # Test programs
├── benchmarks/              # AI workload benchmarks (Phase 8)
└── README.md
```

## Current Status

**Phase 0: Architecture Specification** - IN PROGRESS

- [x] Architecture document
- [x] Microarchitecture document
- [x] Design decisions document
- [x] Roadmap document
- [ ] Architecture review
- [ ] OPEN questions resolved

## Quick Start

### Prerequisites

- FPGA board with Xilinx Artix-7 or equivalent
- Vivado or open-source Yosys/nextpnr toolchain
- SystemVerilog simulator (Verilator, Icarus, or commercial)

### Building

```bash
# Phase 2: Synthesize scalar processor
cd fpga
make synth

# Generate bitstream
make bitstream

# Program FPGA
make program
```

### Running Tests

```bash
# Run scalar unit tests
cd tests/scalar
make run

# Run vector unit tests
cd tests/vector
make run

# Run matrix unit tests
cd tests/matrix
make run
```

## Targets

| Metric | v0.1 Target |
|--------|-------------|
| Clock frequency | 50 MHz |
| INT8 MACs/cycle | 64 |
| Vector ops/cycle | 8 |
| Memory bandwidth | 256 bits/cycle |
| FPGA utilization | < 15% LUTs |
| Power consumption | < 1W |

## Roadmap

- **Phase 0:** Architecture specification (current)
- **Phase 1:** ISA specification
- **Phase 2:** Minimal scalar processor
- **Phase 3:** Simulator
- **Phase 4:** Vector acceleration
- **Phase 5:** Matrix acceleration
- **Phase 6:** Memory improvements
- **Phase 7:** FPGA implementation
- **Phase 8:** AI workload benchmarking

See [Roadmap](docs/roadmap.md) for detailed timeline.

## Open Questions

1. Should v0.2 add branch prediction?
2. Should v0.2 add instruction cache?
3. Should v0.2 add DMA engine?
4. What is the maximum acceptable interrupt latency?
5. Should v0.1 include clock gating?

See [Design Decisions](docs/design-decisions.md) for full discussion.

## Contributing

This is currently a solo design project. Contribution guidelines will be added after architecture review.

## License

TBD after architecture review.

## Contact

Project owner: TBD
