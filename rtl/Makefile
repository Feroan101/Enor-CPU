# ENOR-CPU RTL Makefile

# Simulator (Icarus Verilog)
SIM = iverilog
SIM_FLAGS = -g2012 -Wall
VVP = vvp

# Source directories
CORE_DIR = core
MEM_DIR = mem
TB_DIR = tb

# Source files
CORE_SRCS = $(CORE_DIR)/alu.sv \
            $(CORE_DIR)/register_file.sv \
            $(CORE_DIR)/decoder.sv \
            $(CORE_DIR)/vector_regfile.sv \
            $(CORE_DIR)/matrix_regfile.sv \
            $(CORE_DIR)/enor_core.sv

MEM_SRCS = $(MEM_DIR)/sram.sv

TB_SRCS = $(TB_DIR)/tb_enor_core.sv

# Top module
TOP = tb_enor_core

# Output
OUTPUT = sim_out.vvp

.PHONY: all sim wave clean

all: sim

sim: $(OUTPUT)
	$(VVP) $(OUTPUT)

$(OUTPUT): $(CORE_SRCS) $(MEM_SRCS) $(TB_SRCS)
	$(SIM) $(SIM_FLAGS) -o $(OUTPUT) $(CORE_SRCS) $(MEM_SRCS) $(TB_SRCS)

wave: sim
	gtkwave $(OUTPUT).vcd &

clean:
	rm -f $(OUTPUT) *.vcd
