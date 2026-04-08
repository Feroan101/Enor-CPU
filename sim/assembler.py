#!/usr/bin/env python3
"""ENOR-CPU Assembler"""

import sys
import re
import argparse

# Register names
REG_NAMES = {
    'x0': 0, 'x1': 1, 'x2': 2, 'x3': 3, 'x4': 4, 'x5': 5, 'x6': 6, 'x7': 7,
    'x8': 8, 'x9': 9, 'x10': 10, 'x11': 11, 'x12': 12, 'x13': 13, 'x14': 14, 'x15': 15,
    'x16': 16, 'x17': 17, 'x18': 18, 'x19': 19, 'x20': 20, 'x21': 21, 'x22': 22, 'x23': 23,
    'x24': 24, 'x25': 25, 'x26': 26, 'x27': 27, 'x28': 28, 'x29': 29, 'x30': 30, 'x31': 31,
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
    'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31,
}

# Vector register names
VREG_NAMES = {
    'v0': 0, 'v1': 1, 'v2': 2, 'v3': 3, 'v4': 4, 'v5': 5, 'v6': 6, 'v7': 7,
    'v8': 8, 'v9': 9, 'v10': 10, 'v11': 11, 'v12': 12, 'v13': 13, 'v14': 14, 'v15': 15,
}

class Assembler:
    """ENOR-CPU Assembler"""
    
    def __init__(self):
        self.labels = {}
        self.code = []
        self.data = []
        self.current_addr = 0
        self.errors = []
    
    def parse_register(self, name):
        """Parse register name to number"""
        name = name.strip().lower()
        if name in REG_NAMES:
            return REG_NAMES[name]
        if name in VREG_NAMES:
            return VREG_NAMES[name]
        # Try numeric
        if name.startswith('x'):
            try:
                return int(name[1:])
            except ValueError:
                pass
        if name.startswith('v'):
            try:
                return int(name[1:])
            except ValueError:
                pass
        return None
    
    def parse_immediate(self, value):
        """Parse immediate value"""
        value = value.strip()
        # Check if it's a label
        if value in self.labels:
            return self.labels[value]
        if value.startswith('0x') or value.startswith('0X'):
            return int(value, 16)
        if value.startswith('0b') or value.startswith('0B'):
            return int(value, 2)
        if value.startswith('-'):
            return -int(value[1:])
        return int(value)
    
    def parse_offset(self, value):
        """Parse offset like '8(x5)' or 'label'"""
        value = value.strip()
        match = re.match(r'(-?\w+)\((\w+)\)', value)
        if match:
            imm = self.parse_immediate(match.group(1))
            reg = self.parse_register(match.group(2))
            return imm, reg
        # Try as label or immediate
        return self.parse_immediate(value), None
    
    def encode_r_type(self, opcode, funct3, funct7, rd, rs1, rs2):
        """Encode R-type instruction"""
        return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
               ((funct3 & 0x07) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    
    def encode_i_type(self, opcode, funct3, rd, rs1, imm):
        """Encode I-type instruction"""
        imm = imm & 0xFFF
        return ((imm & 0xFFF) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x07) << 12) | \
               ((rd & 0x1F) << 7) | (opcode & 0x7F)
    
    def encode_s_type(self, opcode, funct3, rs1, rs2, imm):
        """Encode S-type instruction"""
        imm = imm & 0xFFF
        imm_11_5 = (imm >> 5) & 0x7F
        imm_4_0 = imm & 0x1F
        return ((imm_11_5 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
               ((funct3 & 0x07) << 12) | ((imm_4_0 & 0x1F) << 7) | (opcode & 0x7F)
    
    def encode_b_type(self, opcode, funct3, rs1, rs2, imm):
        """Encode B-type instruction"""
        imm = imm & 0x1FFE  # Ensure even
        imm_12 = (imm >> 12) & 1
        imm_11 = (imm >> 11) & 1
        imm_10_5 = (imm >> 5) & 0x3F
        imm_4_1 = (imm >> 1) & 0xF
        return ((imm_12 & 1) << 31) | ((imm_10_5 & 0x3F) << 25) | ((rs2 & 0x1F) << 20) | \
               ((rs1 & 0x1F) << 15) | ((funct3 & 0x07) << 12) | ((imm_4_1 & 0xF) << 8) | \
               ((imm_11 & 1) << 7) | (opcode & 0x7F)
    
    def encode_u_type(self, opcode, rd, imm):
        """Encode U-type instruction (imm is the 20-bit value for bits [31:12])"""
        imm = imm & 0xFFFFF
        return (imm << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    
    def encode_j_type(self, opcode, rd, imm):
        """Encode J-type instruction"""
        imm = imm & 0x1FFFFE  # Ensure even
        imm_20 = (imm >> 20) & 1
        imm_19_12 = (imm >> 12) & 0xFF
        imm_11 = (imm >> 11) & 1
        imm_10_1 = (imm >> 1) & 0x3FF
        return ((imm_20 & 1) << 31) | ((imm_10_1 & 0x3FF) << 21) | ((imm_11 & 1) << 20) | \
               ((imm_19_12 & 0xFF) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)
    
    def encode_v_type(self, opcode, funct3, funct7, vd, vs1, vs2):
        """Encode V-type instruction"""
        return ((funct7 & 0x7F) << 25) | ((vs2 & 0x1F) << 20) | ((vs1 & 0x1F) << 15) | \
               ((funct3 & 0x07) << 12) | ((vd & 0x1F) << 7) | (opcode & 0x7F)
    
    def assemble_instruction(self, mnemonic, operands):
        """Assemble a single instruction"""
        mnemonic = mnemonic.upper()
        
        # R-type instructions
        if mnemonic == 'ADD':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x00, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SUB':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x00, 0x20, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'AND':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x07, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'OR':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x06, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'XOR':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x04, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SLL':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x01, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SRL':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x05, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SRA':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x05, 0x20, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SLT':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x02, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'SLTU':
            rd, rs1, rs2 = operands
            return self.encode_r_type(0x33, 0x03, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        
        # I-type ALU instructions
        elif mnemonic == 'ADDI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'ANDI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x07, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'ORI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x06, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'XORI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x04, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'SLLI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x01, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'SRLI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x05, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'SRAI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x05, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm) | 0x20)
        elif mnemonic == 'SLTI':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x02, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'SLTIU':
            rd, rs1, imm = operands
            return self.encode_i_type(0x13, 0x03, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        
        # Load instructions
        elif mnemonic == 'LB':
            rd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x03, 0x00, 
                                       self.parse_register(rd), 
                                       rs1, imm)
        elif mnemonic == 'LH':
            rd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x03, 0x01, 
                                       self.parse_register(rd), 
                                       rs1, imm)
        elif mnemonic == 'LW':
            rd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x03, 0x02, 
                                       self.parse_register(rd), 
                                       rs1, imm)
        elif mnemonic == 'LBU':
            rd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x03, 0x04, 
                                       self.parse_register(rd), 
                                       rs1, imm)
        elif mnemonic == 'LHU':
            rd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x03, 0x05, 
                                       self.parse_register(rd), 
                                       rs1, imm)
        
        # Vector load
        elif mnemonic == 'VLW':
            vd, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_i_type(0x07, 0x02, 
                                       self.parse_register(vd), 
                                       rs1, imm)
        
        # Store instructions
        elif mnemonic == 'SB':
            rs2, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_s_type(0x23, 0x00, 
                                       rs1, 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'SH':
            rs2, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_s_type(0x23, 0x01, 
                                       rs1, 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'SW':
            rs2, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_s_type(0x23, 0x02, 
                                       rs1, 
                                       self.parse_register(rs2), 
                                       imm)
        
        # Vector store
        elif mnemonic == 'VSW':
            vs2, offset = operands
            imm, rs1 = self.parse_offset(offset)
            return self.encode_s_type(0x27, 0x02, 
                                       rs1, 
                                       self.parse_register(vs2), 
                                       imm)
        
        # Branch instructions
        elif mnemonic == 'BEQ':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x00, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'BNE':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x01, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'BLT':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x04, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'BGE':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x05, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'BLTU':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x06, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        elif mnemonic == 'BGEU':
            rs1, rs2, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_b_type(0x63, 0x07, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2), 
                                       imm)
        
        # Jump instructions
        elif mnemonic == 'JAL':
            rd, offset = operands
            imm = self.parse_immediate(offset) - self.current_addr
            return self.encode_j_type(0x6F, 
                                       self.parse_register(rd), 
                                       imm)
        elif mnemonic == 'JALR':
            rd, rs1, imm = operands
            return self.encode_i_type(0x67, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(imm))
        
        # Upper immediate instructions
        elif mnemonic == 'LUI':
            rd, imm = operands
            return self.encode_u_type(0x37, 
                                       self.parse_register(rd), 
                                       self.parse_immediate(imm))
        elif mnemonic == 'AUIPC':
            rd, imm = operands
            return self.encode_u_type(0x17, 
                                       self.parse_register(rd), 
                                       self.parse_immediate(imm))
        
        # Vector instructions
        elif mnemonic == 'VADD':
            vd, vs1, vs2 = operands
            return self.encode_v_type(0x57, 0x00, 0x00, 
                                       VREG_NAMES.get(vd.lower(), 0), 
                                       VREG_NAMES.get(vs1.lower(), 0), 
                                       VREG_NAMES.get(vs2.lower(), 0))
        elif mnemonic == 'VSUB':
            vd, vs1, vs2 = operands
            return self.encode_v_type(0x57, 0x00, 0x02, 
                                       VREG_NAMES.get(vd.lower(), 0), 
                                       VREG_NAMES.get(vs1.lower(), 0), 
                                       VREG_NAMES.get(vs2.lower(), 0))
        elif mnemonic == 'VMUL':
            vd, vs1, vs2 = operands
            return self.encode_v_type(0x57, 0x00, 0x04, 
                                       VREG_NAMES.get(vd.lower(), 0), 
                                       VREG_NAMES.get(vs1.lower(), 0), 
                                       VREG_NAMES.get(vs2.lower(), 0))
        elif mnemonic == 'VDOT':
            rd, vs1, vs2 = operands
            return self.encode_v_type(0x57, 0x00, 0x10, 
                                       self.parse_register(rd), 
                                       VREG_NAMES.get(vs1.lower(), 0), 
                                       VREG_NAMES.get(vs2.lower(), 0))
        elif mnemonic == 'VRED_SUM':
            rd, vs1 = operands
            return self.encode_v_type(0x57, 0x00, 0x11, 
                                       self.parse_register(rd), 
                                       VREG_NAMES.get(vs1.lower(), 0), 
                                       0)
        elif mnemonic == 'VSETVL':
            rd, rs1 = operands
            return self.encode_v_type(0x57, 0x00, 0x20, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       0)
        
        # Matrix instructions
        elif mnemonic == 'MMUL':
            rs1, rs2 = operands
            return self.encode_r_type(0x77, 0x00, 0x00, 
                                       0, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'MMAC':
            rs1, rs2 = operands
            return self.encode_r_type(0x77, 0x00, 0x01, 
                                       0, 
                                       self.parse_register(rs1), 
                                       self.parse_register(rs2))
        elif mnemonic == 'MLOAD':
            rs1 = operands[0]
            return self.encode_r_type(0x77, 0x00, 0x02, 
                                       0, 
                                       self.parse_register(rs1), 
                                       0)
        elif mnemonic == 'MSTORE':
            rs1 = operands[0]
            return self.encode_r_type(0x77, 0x01, 0x03, 
                                       0, 
                                       self.parse_register(rs1), 
                                       0)
        
        # System instructions
        elif mnemonic == 'ECALL':
            return self.encode_i_type(0x73, 0x00, 0, 0, 0x000)
        elif mnemonic == 'EBREAK':
            return self.encode_i_type(0x73, 0x00, 0, 0, 0x001)
        elif mnemonic == 'CSRRW':
            rd, csr, rs1 = operands
            return self.encode_i_type(0x73, 0x01, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs1), 
                                       self.parse_immediate(csr))
        
        # Pseudo-instructions
        elif mnemonic == 'NOP':
            return self.encode_r_type(0x33, 0x00, 0x00, 0, 0, 0)
        elif mnemonic == 'MV':
            rd, rs = operands
            return self.encode_i_type(0x13, 0x00, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs), 
                                       0)
        elif mnemonic == 'NOT':
            rd, rs = operands
            return self.encode_i_type(0x13, 0x04, 
                                       self.parse_register(rd), 
                                       self.parse_register(rs), 
                                       -1)
        elif mnemonic == 'NEG':
            rd, rs = operands
            return self.encode_r_type(0x33, 0x00, 0x20, 
                                       self.parse_register(rd), 
                                       0, 
                                       self.parse_register(rs))
        elif mnemonic == 'LI':
            rd, imm = operands
            imm_val = self.parse_immediate(imm)
            # For small immediates, use ADDI
            if -2048 <= imm_val <= 2047:
                return self.encode_i_type(0x13, 0x00, 
                                           self.parse_register(rd), 
                                           0, imm_val)
            # For larger immediates, use LUI + ADDI
            upper = (imm_val + 0x800) >> 12
            lower = imm_val - (upper << 12)
            # Return LUI (we'd need to handle multi-instruction, but for now just LUI)
            return self.encode_u_type(0x37, self.parse_register(rd), upper << 12)
        elif mnemonic == 'J':
            offset = operands[0]
            imm = self.parse_immediate(offset)
            return self.encode_j_type(0x6F, 0, imm)
        elif mnemonic == 'JR':
            rs = operands[0]
            return self.encode_i_type(0x67, 0x00, 0, self.parse_register(rs), 0)
        elif mnemonic == 'RET':
            return self.encode_i_type(0x67, 0x00, 0, 1, 0)  # JALR x0, x1, 0
        
        else:
            return None
    
    def assemble_line(self, line):
        """Assemble a single line of assembly"""
        # Remove comments
        line = re.sub(r'#.*$', '', line)
        line = re.sub(r'//.*$', '', line)
        
        # Skip empty lines
        if not line.strip():
            return None
        
        # Check for label
        label_match = re.match(r'^(\w+):\s*(.*)', line)
        if label_match:
            label = label_match.group(1)
            self.labels[label] = self.current_addr
            line = label_match.group(2)
        
        if not line.strip():
            return None
        
        # Parse instruction
        parts = line.split()
        if not parts:
            return None
        
        mnemonic = parts[0]
        operands = []
        if len(parts) > 1:
            # Split by comma, but handle memory operands like '8(x5)'
            operand_str = ' '.join(parts[1:])
            operands = [op.strip() for op in re.split(r',\s*(?![^(]*\))', operand_str)]
        
        # Assemble instruction
        instruction = self.assemble_instruction(mnemonic, operands)
        if instruction is None:
            self.errors.append(f"Unknown instruction: {mnemonic}")
            return None
        
        self.current_addr += 4
        return instruction
    
    def assemble(self, source):
        """Assemble source code"""
        lines = source.split('\n')
        
        # First pass: collect labels
        temp_addr = 0
        for line in lines:
            line = re.sub(r'#.*$', '', line)
            line = re.sub(r'//.*$', '', line)
            label_match = re.match(r'^(\w+):\s*(.*)', line)
            if label_match:
                self.labels[label_match.group(1)] = temp_addr
                line = label_match.group(2)
            if line.strip():
                temp_addr += 4
        
        # Second pass: assemble
        self.current_addr = 0
        for line in lines:
            instruction = self.assemble_line(line)
            if instruction is not None:
                self.code.append(instruction)
        
        return self.code
    
    def get_binary(self):
        """Get assembled binary as bytes"""
        binary = bytearray()
        for instr in self.code:
            binary.extend(instr.to_bytes(4, 'little'))
        return binary
    
    def write_binary(self, filename):
        """Write assembled binary to file"""
        binary = self.get_binary()
        with open(filename, 'wb') as f:
            f.write(binary)
        print(f"Written {len(binary)} bytes to {filename}")
    
    def print_listing(self):
        """Print assembly listing"""
        for i, instr in enumerate(self.code):
            addr = i * 4
            print(f"{addr:08x}: {instr:08x}")

def main():
    parser = argparse.ArgumentParser(description='ENOR-CPU Assembler')
    parser.add_argument('input', help='Input assembly file')
    parser.add_argument('-o', '--output', help='Output binary file')
    parser.add_argument('-l', '--listing', action='store_true', help='Print listing')
    args = parser.parse_args()
    
    with open(args.input, 'r') as f:
        source = f.read()
    
    asm = Assembler()
    code = asm.assemble(source)
    
    if asm.errors:
        print("Errors:")
        for error in asm.errors:
            print(f"  {error}")
        return 1
    
    if args.listing:
        asm.print_listing()
    
    if args.output:
        asm.write_binary(args.output)
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
