# ENOR-CPU Reference Simulator

**Version:** 0.1  
**Status:** Implementation

## Overview

This is the golden reference simulator for ENOR-CPU v0.1. It implements the complete ISA and provides deterministic execution for verification.

## Usage

```bash
# Run a binary file
python3 cpu.py program.bin

# Run with debug output
python3 cpu.py program.bin --debug

# Run with cycle limit
python3 cpu.py program.bin --cycles 1000
```

## Files

| File | Description |
|------|-------------|
| cpu.py | Main simulator entry point |
| memory.py | Memory subsystem |
| registers.py | Register files |
| instructions.py | Instruction decoder and executor |
| tests/ | Test programs |

## Architecture

The simulator implements:
- 32 scalar registers (x0-x31)
- 16 vector registers (v0-v15)
- Matrix accumulator (M0)
- Special registers (PC, SR, VL, VLX, VLY, VLZ)
- Memory (code, data, I/O)
- All 42 instructions

## Verification

The simulator output can be compared against RTL simulation to verify correctness.
