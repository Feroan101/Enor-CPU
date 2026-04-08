"""ENOR-CPU Instruction Decoder and Executor"""

def sign_extend(value, bits):
    """Sign extend a value from bits to 32 bits"""
    if value & (1 << (bits - 1)):
        return value - (1 << bits)
    return value

def to_signed32(value):
    """Convert unsigned 32-bit to signed"""
    value = value & 0xFFFFFFFF
    if value & 0x80000000:
        return value - 0x100000000
    return value

class Instructions:
    """ENOR-CPU Instruction Decoder and Executor"""
    
    def __init__(self, regs, mem):
        self.regs = regs
        self.mem = mem
        self.cycle_count = 0
        self.instr_count = 0
    
    def execute(self, instruction):
        """Execute a single instruction"""
        self.instr_count += 1
        
        # Extract fields
        opcode = instruction & 0x7F
        rd = (instruction >> 7) & 0x1F
        funct3 = (instruction >> 12) & 0x07
        rs1 = (instruction >> 15) & 0x1F
        rs2 = (instruction >> 20) & 0x1F
        funct7 = (instruction >> 25) & 0x7F
        
        # Decode and execute
        if opcode == 0x33:  # R-type ALU
            return self._execute_r_type(rd, funct3, rs1, rs2, funct7)
        elif opcode == 0x13:  # I-type ALU
            return self._execute_i_type_alu(rd, funct3, rs1, instruction)
        elif opcode == 0x03:  # Load
            return self._execute_load(rd, funct3, rs1, instruction)
        elif opcode == 0x23:  # Store
            return self._execute_store(funct3, rs1, rs2, instruction)
        elif opcode == 0x63:  # Branch
            return self._execute_branch(funct3, rs1, rs2, instruction)
        elif opcode == 0x6F:  # JAL
            return self._execute_jal(rd, instruction)
        elif opcode == 0x67:  # JALR
            return self._execute_jalr(rd, rs1, instruction)
        elif opcode == 0x37:  # LUI
            return self._execute_lui(rd, instruction)
        elif opcode == 0x17:  # AUIPC
            return self._execute_auipc(rd, instruction)
        elif opcode == 0x57:  # Vector
            return self._execute_vector(rd, funct3, rs1, rs2, funct7, instruction)
        elif opcode == 0x07:  # Vector load (VLW)
            return self._execute_vload(rd, funct3, rs1, instruction)
        elif opcode == 0x27:  # Vector store (VSW)
            return self._execute_vstore(funct3, rs1, rs2, instruction)
        elif opcode == 0x77:  # Matrix
            return self._execute_matrix(rd, funct3, rs1, rs2, funct7, instruction)
        elif opcode == 0x73:  # System
            return self._execute_system(rd, funct3, rs1, instruction)
        else:
            print(f"Unknown opcode: {opcode:02x}")
            return False
    
    def _execute_r_type(self, rd, funct3, rs1, rs2, funct7):
        """Execute R-type instruction"""
        a = self.regs.read_scalar(rs1)
        b = self.regs.read_scalar(rs2)
        
        if funct3 == 0x00:  # ADD/SUB
            if funct7 == 0x00:  # ADD
                result = (a + b) & 0xFFFFFFFF
                self.regs.write_scalar(rd, result)
                # Set flags
                z = 1 if result == 0 else 0
                c = 1 if (a + b) > 0xFFFFFFFF else 0
                v = 1 if ((a ^ result) & (b ^ result) & 0x80000000) else 0
                n = (result >> 31) & 1
                self.regs.set_flags(z=z, c=c, v=v, n=n)
            elif funct7 == 0x20:  # SUB
                result = (a - b) & 0xFFFFFFFF
                self.regs.write_scalar(rd, result)
                # Set flags
                z = 1 if result == 0 else 0
                c = 1 if a >= b else 0  # Borrow (inverted)
                v = 1 if ((a ^ b) & (a ^ result) & 0x80000000) else 0
                n = (result >> 31) & 1
                self.regs.set_flags(z=z, c=c, v=v, n=n)
            else:
                return False
        elif funct3 == 0x01:  # SLL
            shift = b & 0x1F
            result = (a << shift) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            c = (a >> (32 - shift)) & 1 if shift > 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=c, v=0, n=n)
        elif funct3 == 0x02:  # SLT
            a_signed = to_signed32(a)
            b_signed = to_signed32(b)
            result = 1 if a_signed < b_signed else 0
            self.regs.write_scalar(rd, result)
            self.regs.set_flags(z=1 if result == 0 else 0, c=0, v=0, n=0)
        elif funct3 == 0x03:  # SLTU
            result = 1 if a < b else 0
            self.regs.write_scalar(rd, result)
            self.regs.set_flags(z=1 if result == 0 else 0, c=0, v=0, n=0)
        elif funct3 == 0x04:  # XOR
            result = (a ^ b) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct3 == 0x05:  # SRL/SRA
            shift = b & 0x1F
            if funct7 == 0x00:  # SRL
                result = (a >> shift) & 0xFFFFFFFF
            elif funct7 == 0x20:  # SRA
                a_signed = to_signed32(a)
                result = (a_signed >> shift) & 0xFFFFFFFF
            else:
                return False
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            c = (a >> (shift - 1)) & 1 if shift > 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=c, v=0, n=n)
        elif funct3 == 0x06:  # OR
            result = (a | b) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct3 == 0x07:  # AND
            result = (a & b) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        else:
            return False
        
        return True
    
    def _execute_i_type_alu(self, rd, funct3, rs1, instruction):
        """Execute I-type ALU instruction"""
        imm = sign_extend((instruction >> 20) & 0xFFF, 12)
        a = self.regs.read_scalar(rs1)
        
        if funct3 == 0x00:  # ADDI
            result = (a + imm) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            c = 1 if (a + imm) > 0xFFFFFFFF else 0
            v = 1 if ((a ^ result) & (imm ^ result) & 0x80000000) else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=c, v=v, n=n)
        elif funct3 == 0x01:  # SLLI
            shift = imm & 0x1F
            result = (a << shift) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            c = (a >> (32 - shift)) & 1 if shift > 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=c, v=0, n=n)
        elif funct3 == 0x02:  # SLTI
            a_signed = to_signed32(a)
            result = 1 if a_signed < imm else 0
            self.regs.write_scalar(rd, result)
            self.regs.set_flags(z=1 if result == 0 else 0, c=0, v=0, n=0)
        elif funct3 == 0x03:  # SLTIU
            result = 1 if (a & 0xFFFFFFFF) < (imm & 0xFFFFFFFF) else 0
            self.regs.write_scalar(rd, result)
            self.regs.set_flags(z=1 if result == 0 else 0, c=0, v=0, n=0)
        elif funct3 == 0x04:  # XORI
            result = (a ^ imm) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct3 == 0x05:  # SRLI/SRAI
            shift = imm & 0x1F
            funct7 = (instruction >> 25) & 0x7F
            if funct7 == 0x00:  # SRLI
                result = (a >> shift) & 0xFFFFFFFF
            elif funct7 == 0x20:  # SRAI
                a_signed = to_signed32(a)
                result = (a_signed >> shift) & 0xFFFFFFFF
            else:
                return False
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            c = (a >> (shift - 1)) & 1 if shift > 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=c, v=0, n=n)
        elif funct3 == 0x06:  # ORI
            result = (a | imm) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct3 == 0x07:  # ANDI
            result = (a & imm) & 0xFFFFFFFF
            self.regs.write_scalar(rd, result)
            z = 1 if result == 0 else 0
            n = (result >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        else:
            return False
        
        return True
    
    def _execute_load(self, rd, funct3, rs1, instruction):
        """Execute load instruction"""
        imm = sign_extend((instruction >> 20) & 0xFFF, 12)
        base = self.regs.read_scalar(rs1)
        addr = (base + imm) & 0xFFFFFFFF
        
        if funct3 == 0x00:  # LB
            value = self.mem.read_byte(addr)
            value = sign_extend(value, 8)
            self.regs.write_scalar(rd, value)
        elif funct3 == 0x01:  # LH
            value = self.mem.read_half(addr)
            value = sign_extend(value, 16)
            self.regs.write_scalar(rd, value)
        elif funct3 == 0x02:  # LW
            value = self.mem.read_word(addr)
            self.regs.write_scalar(rd, value)
        elif funct3 == 0x04:  # LBU
            value = self.mem.read_byte(addr)
            self.regs.write_scalar(rd, value)
        elif funct3 == 0x05:  # LHU
            value = self.mem.read_half(addr)
            self.regs.write_scalar(rd, value)
        else:
            return False
        
        return True
    
    def _execute_store(self, funct3, rs1, rs2, instruction):
        """Execute store instruction"""
        imm_11_5 = (instruction >> 25) & 0x7F
        imm_4_0 = (instruction >> 7) & 0x1F
        imm = sign_extend((imm_11_5 << 5) | imm_4_0, 12)
        
        base = self.regs.read_scalar(rs1)
        addr = (base + imm) & 0xFFFFFFFF
        value = self.regs.read_scalar(rs2)
        
        if funct3 == 0x00:  # SB
            self.mem.write_byte(addr, value & 0xFF)
        elif funct3 == 0x01:  # SH
            self.mem.write_half(addr, value & 0xFFFF)
        elif funct3 == 0x02:  # SW
            self.mem.write_word(addr, value)
        else:
            return False
        
        return True
    
    def _execute_branch(self, funct3, rs1, rs2, instruction):
        """Execute branch instruction"""
        a = self.regs.read_scalar(rs1)
        b = self.regs.read_scalar(rs2)
        
        # Calculate offset
        imm_12 = (instruction >> 31) & 1
        imm_10_5 = (instruction >> 25) & 0x3F
        imm_4_1 = (instruction >> 8) & 0xF
        imm_11 = (instruction >> 7) & 1
        imm = sign_extend((imm_12 << 12) | (imm_11 << 11) | (imm_10_5 << 5) | (imm_4_1 << 1), 13)
        
        taken = False
        if funct3 == 0x00:  # BEQ
            taken = (a == b)
        elif funct3 == 0x01:  # BNE
            taken = (a != b)
        elif funct3 == 0x04:  # BLT
            taken = (to_signed32(a) < to_signed32(b))
        elif funct3 == 0x05:  # BGE
            taken = (to_signed32(a) >= to_signed32(b))
        elif funct3 == 0x06:  # BLTU
            taken = (a < b)
        elif funct3 == 0x07:  # BGEU
            taken = (a >= b)
        else:
            return False
        
        if taken:
            self.regs.pc = (self.regs.pc - 4 + imm) & 0xFFFFFFFF
        else:
            pass  # PC is already PC+4
        
        return True
    
    def _execute_jal(self, rd, instruction):
        """Execute JAL instruction"""
        imm_20 = (instruction >> 31) & 1
        imm_10_1 = (instruction >> 21) & 0x3FF
        imm_11 = (instruction >> 20) & 1
        imm_19_12 = (instruction >> 12) & 0xFF
        imm = sign_extend((imm_20 << 20) | (imm_19_12 << 12) | (imm_11 << 11) | (imm_10_1 << 1), 21)
        
        self.regs.write_scalar(rd, (self.regs.pc + 4) & 0xFFFFFFFF)
        self.regs.pc = (self.regs.pc + imm) & 0xFFFFFFFF
        
        return True
    
    def _execute_jalr(self, rd, rs1, instruction):
        """Execute JALR instruction"""
        imm = sign_extend((instruction >> 20) & 0xFFF, 12)
        base = self.regs.read_scalar(rs1)
        target = ((base + imm) & ~1) & 0xFFFFFFFF
        
        self.regs.write_scalar(rd, (self.regs.pc + 4) & 0xFFFFFFFF)
        self.regs.pc = target
        
        return True
    
    def _execute_lui(self, rd, instruction):
        """Execute LUI instruction"""
        imm = (instruction >> 12) & 0xFFFFF
        result = (imm << 12) & 0xFFFFFFFF
        self.regs.write_scalar(rd, result)
        return True
    
    def _execute_auipc(self, rd, instruction):
        """Execute AUIPC instruction"""
        imm = (instruction >> 12) & 0xFFFFF
        result = (self.regs.pc + (imm << 12)) & 0xFFFFFFFF
        self.regs.write_scalar(rd, result)
        return True
    
    def _execute_vload(self, rd, funct3, rs1, instruction):
        """Execute vector load instruction (VLW)"""
        if funct3 == 0x02:  # VLW - Load 256 bits (8 words)
            imm = sign_extend((instruction >> 20) & 0xFFF, 12)
            base = self.regs.read_scalar(rs1)
            addr = (base + imm) & 0xFFFFFFFF
            
            # Load 8 words into vector register
            result = []
            for i in range(8):
                word = self.mem.read_word(addr + i * 4)
                result.append(word)
            self.regs.write_vector(rd, result)
        return True
    
    def _execute_vstore(self, funct3, rs1, rs2, instruction):
        """Execute vector store instruction (VSW)"""
        if funct3 == 0x02:  # VSW - Store 256 bits (8 words)
            imm_11_5 = (instruction >> 25) & 0x7F
            imm_4_0 = (instruction >> 7) & 0x1F
            imm = (imm_11_5 << 5) | imm_4_0
            imm = sign_extend(imm, 12)
            
            base = self.regs.read_scalar(rs1)
            addr = (base + imm) & 0xFFFFFFFF
            
            # Store 8 words from vector register
            vals = self.regs.read_vector(rs2)
            for i in range(8):
                self.mem.write_word(addr + i * 4, vals[i])
        return True
    
    def _execute_vector(self, rd, funct3, rs1, rs2, funct7, instruction):
        """Execute vector instruction"""
        if funct7 == 0x00:  # VADD
            vs1_vals = self.regs.read_vector(rs1)
            vs2_vals = self.regs.read_vector(rs2)
            result = [(vs1_vals[i] + vs2_vals[i]) & 0xFFFFFFFF for i in range(self.regs.vl)]
            result.extend([0] * (8 - len(result)))
            self.regs.write_vector(rd, result)
        elif funct7 == 0x02:  # VSUB
            vs1_vals = self.regs.read_vector(rs1)
            vs2_vals = self.regs.read_vector(rs2)
            result = [(vs1_vals[i] - vs2_vals[i]) & 0xFFFFFFFF for i in range(self.regs.vl)]
            result.extend([0] * (8 - len(result)))
            self.regs.write_vector(rd, result)
        elif funct7 == 0x04:  # VMUL
            vs1_vals = self.regs.read_vector(rs1)
            vs2_vals = self.regs.read_vector(rs2)
            result = [(vs1_vals[i] * vs2_vals[i]) & 0xFFFFFFFF for i in range(self.regs.vl)]
            result.extend([0] * (8 - len(result)))
            self.regs.write_vector(rd, result)
        elif funct7 == 0x10:  # VDOT
            vs1_vals = self.regs.read_vector(rs1)
            vs2_vals = self.regs.read_vector(rs2)
            temp = 0
            for i in range(self.regs.vl):
                temp = (temp + vs1_vals[i] * vs2_vals[i]) & 0xFFFFFFFF
            self.regs.write_scalar(rd, temp)
            z = 1 if temp == 0 else 0
            n = (temp >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct7 == 0x11:  # VRED_SUM
            vs1_vals = self.regs.read_vector(rs1)
            temp = 0
            for i in range(self.regs.vl):
                temp = (temp + vs1_vals[i]) & 0xFFFFFFFF
            self.regs.write_scalar(rd, temp)
            z = 1 if temp == 0 else 0
            n = (temp >> 31) & 1
            self.regs.set_flags(z=z, c=0, v=0, n=n)
        elif funct7 == 0x20:  # VSETVL
            new_vl = min(max(self.regs.read_scalar(rs1), 1), 8)
            self.regs.vl = new_vl
            self.regs.write_scalar(rd, new_vl)
        else:
            return False
        
        return True
    
    def _execute_matrix(self, rd, funct3, rs1, rs2, funct7, instruction):
        """Execute matrix instruction"""
        if funct7 == 0x00:  # MMUL
            addr_a = self.regs.read_scalar(rs1)
            addr_b = self.regs.read_scalar(rs2)
            
            # Load matrices from memory
            A = [[0] * 8 for _ in range(8)]
            B = [[0] * 8 for _ in range(8)]
            
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    A[i][j] = self.mem.read_word(addr_a + (i * self.regs.vlx + j) * 4)
            
            for i in range(self.regs.vlz):
                for j in range(self.regs.vly):
                    B[i][j] = self.mem.read_word(addr_b + (i * self.regs.vly + j) * 4)
            
            # Compute matrix multiply
            self.regs.clear_matrix()
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    temp = 0
                    for k in range(self.regs.vlz):
                        temp = (temp + A[i][k] * B[k][j]) & 0xFFFFFFFF
                    self.regs.write_matrix(i, j, temp)
        
        elif funct7 == 0x01:  # MMAC
            addr_a = self.regs.read_scalar(rs1)
            addr_b = self.regs.read_scalar(rs2)
            
            # Load matrices from memory
            A = [[0] * 8 for _ in range(8)]
            B = [[0] * 8 for _ in range(8)]
            
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    A[i][j] = self.mem.read_word(addr_a + (i * self.regs.vlx + j) * 4)
            
            for i in range(self.regs.vlz):
                for j in range(self.regs.vly):
                    B[i][j] = self.mem.read_word(addr_b + (i * self.regs.vly + j) * 4)
            
            # Compute matrix multiply-accumulate
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    temp = self.regs.read_matrix(i, j)
                    for k in range(self.regs.vlz):
                        temp = (temp + A[i][k] * B[k][j]) & 0xFFFFFFFF
                    self.regs.write_matrix(i, j, temp)
        
        elif funct7 == 0x02:  # MLOAD
            addr = self.regs.read_scalar(rs1)
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    value = self.mem.read_word(addr + (i * self.regs.vlx + j) * 4)
                    self.regs.write_matrix(i, j, value)
        
        elif funct7 == 0x03:  # MSTORE
            addr = self.regs.read_scalar(rs1)
            for i in range(self.regs.vly):
                for j in range(self.regs.vlx):
                    value = self.regs.read_matrix(i, j)
                    self.mem.write_word(addr + (i * self.regs.vlx + j) * 4, value)
        
        else:
            return False
        
        return True
    
    def _execute_system(self, rd, funct3, rs1, instruction):
        """Execute system instruction"""
        if funct3 == 0x00:  # ECALL/EBREAK
            imm = (instruction >> 20) & 0xFFF
            if imm == 0x000:  # ECALL
                self.regs.write_csr(0x010, (self.regs.pc + 4) & 0xFFFFFFFF)
                self.regs.write_csr(0x011, 0x0000000B)
                self.regs.pc = 0x00001000
                self.regs.sr &= ~0x80  # Clear IE
            elif imm == 0x001:  # EBREAK
                self.regs.write_csr(0x010, self.regs.pc)
                self.regs.write_csr(0x011, 0x00000003)
                self.regs.pc = 0x00001000
                self.regs.sr &= ~0x80  # Clear IE
            else:
                return False
        elif funct3 == 0x01:  # CSRRW
            csr_addr = (instruction >> 20) & 0xFFF
            temp = self.regs.read_csr(csr_addr)
            self.regs.write_csr(csr_addr, self.regs.read_scalar(rs1))
            self.regs.write_scalar(rd, temp)
        else:
            return False
        
        return True
