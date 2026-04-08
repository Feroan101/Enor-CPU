"""ENOR-CPU Memory Subsystem Implementation"""

class Memory:
    """ENOR-CPU Memory Subsystem"""
    
    def __init__(self, code_size=32*1024, data_size=64*1024):
        # Code SRAM (32 KB)
        self.code_size = code_size
        self.code = bytearray(code_size)
        
        # Data SRAM (64 KB)
        self.data_size = data_size
        self.data = bytearray(data_size)
        
        # Matrix SRAM (32 KB, overlaid in data space)
        self.matrix_sram = bytearray(32*1024)
        
        # Vector SRAM (16 KB, overlaid in data space)
        self.vector_sram = bytearray(16*1024)
        
        # I/O registers
        self.uart_data = 0
        self.uart_status = 0
        self.timer_value = 0
        self.timer_compare = 0
        self.gpio_output = 0
        self.gpio_input = 0
        self.interrupt_enable = 0
        self.interrupt_status = 0
        
        # Output buffer for UART
        self.uart_output = []
    
    def read_word(self, addr):
        """Read 32-bit word from memory"""
        addr = addr & 0xFFFFFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            return int.from_bytes(self.data[offset:offset+4], 'little')
        
        # Code space (for instruction fetch)
        elif 0x00000000 <= addr < 0x00000000 + self.code_size:
            offset = addr - 0x00000000
            return int.from_bytes(self.code[offset:offset+4], 'little')
        
        # I/O space
        elif 0x80000000 <= addr < 0x80000020:
            return self._read_io(addr)
        
        return 0
    
    def write_word(self, addr, value):
        """Write 32-bit word to memory"""
        addr = addr & 0xFFFFFFFF
        value = value & 0xFFFFFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            self.data[offset:offset+4] = value.to_bytes(4, 'little')
        
        # I/O space
        elif 0x80000000 <= addr < 0x80000020:
            self._write_io(addr, value)
    
    def read_half(self, addr):
        """Read 16-bit halfword from memory"""
        addr = addr & 0xFFFFFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            return int.from_bytes(self.data[offset:offset+2], 'little')
        
        return 0
    
    def write_half(self, addr, value):
        """Write 16-bit halfword to memory"""
        addr = addr & 0xFFFFFFFF
        value = value & 0xFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            self.data[offset:offset+2] = value.to_bytes(2, 'little')
    
    def read_byte(self, addr):
        """Read 8-bit byte from memory"""
        addr = addr & 0xFFFFFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            return self.data[offset]
        
        # I/O space
        elif addr == 0x80000000:
            return self.uart_data & 0xFF
        
        return 0
    
    def write_byte(self, addr, value):
        """Write 8-bit byte to memory"""
        addr = addr & 0xFFFFFFFF
        value = value & 0xFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            self.data[offset] = value
        
        # I/O space
        elif addr == 0x80000000:
            self.uart_data = value
            self.uart_output.append(value)
            # Print ASCII character
            if 32 <= value < 127:
                print(chr(value), end='')
            elif value == 10:  # newline
                print()
    
    def read_vector(self, addr):
        """Read 256-bit vector from memory"""
        addr = addr & 0xFFFFFFFF
        result = []
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            for i in range(8):
                word = int.from_bytes(self.data[offset+i*4:offset+i*4+4], 'little')
                result.append(word)
        
        return result
    
    def write_vector(self, addr, values):
        """Write 256-bit vector to memory"""
        addr = addr & 0xFFFFFFFF
        
        # Data space
        if 0x40000000 <= addr < 0x40000000 + self.data_size:
            offset = addr - 0x40000000
            for i, val in enumerate(values[:8]):
                self.data[offset+i*4:offset+i*4+4] = (val & 0xFFFFFFFF).to_bytes(4, 'little')
    
    def load_code(self, data, offset=0):
        """Load code into code memory"""
        self.code[offset:offset+len(data)] = data
    
    def load_data(self, data, offset=0):
        """Load data into data memory"""
        self.data[offset:offset+len(data)] = data
    
    def _read_io(self, addr):
        """Read from I/O register"""
        if addr == 0x80000000:  # UART data
            return self.uart_data
        elif addr == 0x80000004:  # UART status
            return self.uart_status
        elif addr == 0x80000008:  # Timer value
            return self.timer_value
        elif addr == 0x8000000C:  # Timer compare
            return self.timer_compare
        elif addr == 0x80000010:  # GPIO output
            return self.gpio_output
        elif addr == 0x80000014:  # GPIO input
            return self.gpio_input
        elif addr == 0x80000018:  # Interrupt enable
            return self.interrupt_enable
        elif addr == 0x8000001C:  # Interrupt status
            return self.interrupt_status
        return 0
    
    def _write_io(self, addr, value):
        """Write to I/O register"""
        if addr == 0x80000000:  # UART data
            self.uart_data = value & 0xFF
            self.uart_output.append(value & 0xFF)
        elif addr == 0x80000004:  # UART status
            self.uart_status = value
        elif addr == 0x80000008:  # Timer value
            self.timer_value = value
        elif addr == 0x8000000C:  # Timer compare
            self.timer_compare = value
        elif addr == 0x80000010:  # GPIO output
            self.gpio_output = value
        elif addr == 0x80000014:  # GPIO input
            self.gpio_input = value
        elif addr == 0x80000018:  # Interrupt enable
            self.interrupt_enable = value
        elif addr == 0x8000001C:  # Interrupt status
            self.interrupt_status = value
    
    def dump_data(self, start, length):
        """Dump data memory contents"""
        for i in range(0, length, 16):
            addr = start + i
            hex_str = ' '.join(f'{self.read_byte(addr+j):02x}' for j in range(16))
            print(f'{addr:08x}: {hex_str}')
