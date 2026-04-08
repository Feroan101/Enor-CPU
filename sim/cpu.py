#!/usr/bin/env python3
"""ENOR-CPU Reference Simulator"""

import sys
import argparse
from registers import Registers
from memory import Memory
from instructions import Instructions

class CPU:
    """ENOR-CPU Simulator"""
    
    def __init__(self):
        self.regs = Registers()
        self.mem = Memory()
        self.instr = Instructions(self.regs, self.mem)
        self.halted = False
        self.debug = False
    
    def load_binary(self, filename):
        """Load binary file into code memory"""
        with open(filename, 'rb') as f:
            data = f.read()
        self.mem.load_code(data)
        print(f"Loaded {len(data)} bytes into code memory")
    
    def step(self):
        """Execute one instruction"""
        if self.halted:
            return False
        
        # Fetch instruction
        instruction = self.mem.read_word(self.regs.pc)
        
        if self.debug:
            print(f"PC={self.regs.pc:08x} INSTR={instruction:08x}")
        
        # Execute
        self.regs.pc = (self.regs.pc + 4) & 0xFFFFFFFF
        success = self.instr.execute(instruction)
        
        if not success:
            print(f"Error at PC={self.regs.pc-4:08x}: Failed to execute instruction {instruction:08x}")
            self.halted = True
            return False
        
        # Check for halt (ECALL/EBREAK)
        if self.regs.pc == 0x00001000:
            self.halted = True
            return False
        
        return True
    
    def run(self, max_cycles=10000):
        """Run CPU until halted or max cycles"""
        cycles = 0
        while cycles < max_cycles and not self.halted:
            if not self.step():
                break
            cycles += 1
        
        return cycles
    
    def dump_state(self):
        """Dump CPU state"""
        self.regs.dump()
        print(f"\nCycles: {self.instr.cycle_count}")
        print(f"Instructions: {self.instr.instr_count}")

def main():
    parser = argparse.ArgumentParser(description='ENOR-CPU Simulator')
    parser.add_argument('binary', help='Binary file to execute')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    parser.add_argument('--cycles', type=int, default=10000, help='Maximum cycles')
    parser.add_argument('--dump', action='store_true', help='Dump state after execution')
    args = parser.parse_args()
    
    cpu = CPU()
    cpu.debug = args.debug
    
    try:
        cpu.load_binary(args.binary)
    except FileNotFoundError:
        print(f"Error: File not found: {args.binary}")
        sys.exit(1)
    
    print("Running ENOR-CPU...")
    cycles = cpu.run(args.cycles)
    print(f"\nExecution complete after {cycles} cycles")
    
    if args.dump:
        cpu.dump_state()
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
