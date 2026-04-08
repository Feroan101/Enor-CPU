"""ENOR-CPU Register File Implementation"""

class Registers:
    """ENOR-CPU Register File"""
    
    def __init__(self):
        # Scalar registers (x0-x31)
        self.scalar = [0] * 32
        
        # Vector registers (v0-v15), each 256 bits (8 x 32-bit elements)
        self.vector = [[0] * 8 for _ in range(16)]
        
        # Special registers
        self.pc = 0  # Program counter
        self.sr = 0  # Status register (flags)
        self.vl = 8  # Vector length (1-8)
        self.vlx = 8  # Matrix dimension X
        self.vly = 8  # Matrix dimension Y
        self.vlz = 8  # Matrix depth
        
        # CSR registers
        self.csr = {
            0x000: 0,  # SR
            0x001: 8,  # VL
            0x002: 8,  # VLX
            0x003: 8,  # VLY
            0x004: 8,  # VLZ
            0x010: 0,  # EPC
            0x011: 0,  # ECAUSE
            0x020: 0,  # IE
            0x021: 0,  # IPRIO
        }
        
        # Matrix accumulator M0 (8x8 x 32-bit)
        self.matrix = [[0] * 8 for _ in range(8)]
    
    def read_scalar(self, reg):
        """Read scalar register"""
        if reg == 0:
            return 0
        return self.scalar[reg] & 0xFFFFFFFF
    
    def write_scalar(self, reg, value):
        """Write scalar register"""
        if reg == 0:
            return  # x0 is hardwired to 0
        self.scalar[reg] = value & 0xFFFFFFFF
    
    def read_vector(self, reg):
        """Read vector register (returns list of 8 elements)"""
        return self.vector[reg].copy()
    
    def write_vector(self, reg, values):
        """Write vector register"""
        self.vector[reg] = [v & 0xFFFFFFFF for v in values[:8]]
    
    def read_matrix(self, row, col):
        """Read matrix accumulator element"""
        return self.matrix[row][col]
    
    def write_matrix(self, row, col, value):
        """Write matrix accumulator element"""
        self.matrix[row][col] = value & 0xFFFFFFFF
    
    def clear_matrix(self):
        """Clear matrix accumulator"""
        self.matrix = [[0] * 8 for _ in range(8)]
    
    def read_csr(self, addr):
        """Read CSR register"""
        if addr in self.csr:
            return self.csr[addr]
        return 0
    
    def write_csr(self, addr, value):
        """Write CSR register"""
        if addr in self.csr:
            self.csr[addr] = value & 0xFFFFFFFF
            # Update corresponding special registers
            if addr == 0x000:
                self.sr = value
            elif addr == 0x001:
                self.vl = min(max(value, 1), 8)
            elif addr == 0x002:
                self.vlx = min(max(value, 1), 8)
            elif addr == 0x003:
                self.vly = min(max(value, 1), 8)
            elif addr == 0x004:
                self.vlz = min(max(value, 1), 8)
    
    def get_flags(self):
        """Get status flags as a tuple (Z, C, V, N)"""
        z = (self.sr >> 0) & 1
        c = (self.sr >> 1) & 1
        v = (self.sr >> 2) & 1
        n = (self.sr >> 3) & 1
        return (z, c, v, n)
    
    def set_flags(self, z=None, c=None, v=None, n=None):
        """Set status flags"""
        if z is not None:
            self.sr = (self.sr & ~1) | (z & 1)
        if c is not None:
            self.sr = (self.sr & ~2) | ((c & 1) << 1)
        if v is not None:
            self.sr = (self.sr & ~4) | ((v & 1) << 2)
        if n is not None:
            self.sr = (self.sr & ~8) | ((n & 1) << 3)
    
    def dump(self):
        """Dump register state"""
        print("=== Scalar Registers ===")
        for i in range(0, 32, 4):
            print(f"x{i:2d}: {self.scalar[i]:08x}  x{i+1:2d}: {self.scalar[i+1]:08x}  "
                  f"x{i+2:2d}: {self.scalar[i+2]:08x}  x{i+3:2d}: {self.scalar[i+3]:08x}")
        
        print("\n=== Special Registers ===")
        print(f"PC:  {self.pc:08x}")
        print(f"SR:  {self.sr:08x} (Z={self.sr&1} C={(self.sr>>1)&1} V={(self.sr>>2)&1} N={(self.sr>>3)&1})")
        print(f"VL:  {self.vl}")
        print(f"VLX: {self.vlx}")
        print(f"VLY: {self.vly}")
        print(f"VLZ: {self.vlz}")
        
        print("\n=== Vector Registers ===")
        for i in range(0, 16, 2):
            v0 = self.vector[i]
            v1 = self.vector[i+1]
            print(f"v{i:2d}: [{v0[0]:08x} {v0[1]:08x} {v0[2]:08x} {v0[3]:08x} "
                  f"{v0[4]:08x} {v0[5]:08x} {v0[6]:08x} {v0[7]:08x}]")
            print(f"v{i+1:2d}: [{v1[0]:08x} {v1[1]:08x} {v1[2]:08x} {v1[3]:08x} "
                  f"{v1[4]:08x} {v1[5]:08x} {v1[6]:08x} {v1[7]:08x}]")
        
        print("\n=== Matrix Accumulator ===")
        for i in range(8):
            print(f"M0[{i}]: [{self.matrix[i][0]:08x} {self.matrix[i][1]:08x} "
                  f"{self.matrix[i][2]:08x} {self.matrix[i][3]:08x} "
                  f"{self.matrix[i][4]:08x} {self.matrix[i][5]:08x} "
                  f"{self.matrix[i][6]:08x} {self.matrix[i][7]:08x}]")
