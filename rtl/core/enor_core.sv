// ENOR-CPU Core Top Module
// Single-cycle implementation for v0.1 (will be pipelined later)

module enor_core (
    input  logic        clk,
    input  logic        rst_n,

    // Code memory interface (Harvard)
    output logic [31:0] code_addr,
    input  logic [31:0] code_data,
    output logic        code_req,

    // Data memory interface
    output logic [31:0] data_addr,
    output logic [31:0] data_wdata,
    input  logic [31:0] data_rdata,
    output logic        data_req,
    output logic        data_we,
    output logic [ 1:0] data_size,

    // Interrupts
    input  logic        irq_timer,
    input  logic        irq_ext
);

    // Internal signals
    logic [31:0] pc, pc_next;
    logic [31:0] instruction;
    logic        stall;

    // Decoder outputs
    logic [ 4:0] dec_rd, dec_rs1, dec_rs2;
    logic [ 2:0] dec_funct3;
    logic [ 6:0] dec_funct7;
    logic [31:0] dec_imm_i, dec_imm_s, dec_imm_b, dec_imm_u, dec_imm_j;
    logic        dec_reg_write, dec_mem_read, dec_mem_write;
    logic [ 1:0] dec_mem_size;
    logic        dec_branch;
    logic [ 2:0] dec_branch_type;
    logic        dec_jump, dec_jump_reg;
    logic [ 3:0] dec_alu_op;
    logic        dec_alu_src_b;
    logic [ 1:0] dec_wb_sel;
    logic        dec_is_lui, dec_is_auipc;
    logic        dec_is_system, dec_is_ecall, dec_is_ebreak, dec_is_csr;
    logic [ 1:0] dec_csr_op;
    logic        dec_is_vector, dec_is_matrix;
    logic [ 3:0] dec_vec_op, dec_mat_op;
    logic [ 2:0] dec_instr_type;

    // Register file outputs
    logic [31:0] rs1_data, rs2_data;

    // ALU outputs
    logic [31:0] alu_result;
    logic        alu_zero, alu_negative, alu_carry, alu_overflow;

    // ALU source B mux
    logic [31:0] alu_op_b;

    // Write back data
    logic [31:0] wb_data;

    // Branch/jump taken
    logic        branch_taken;
    logic [31:0] branch_target;

    // CSR registers
    logic [31:0] csr_status;
    logic [31:0] csr_epc;
    logic [31:0] csr_cause;

    // Vector/matrix signals
    logic [ 2:0] vl;
    logic [31:0] vec_wb_data;

    // CSR addresses
    localparam CSR_STATUS = 12'h010;
    localparam CSR_EPC    = 12'h011;
    localparam CSR_CAUSE  = 12'h012;
    localparam CSR_VLX    = 12'h002;
    localparam CSR_VLY    = 12'h003;
    localparam CSR_VLZ    = 12'h004;

    // CSR registers
    logic [31:0] csr_vlx, csr_vly, csr_vlz;

    // ==================== PC Logic ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end

    // PC next logic
    always_comb begin
        if (branch_taken) begin
            pc_next = branch_target;
        end else if (dec_jump) begin
            pc_next = alu_result;
        end else if (dec_jump_reg) begin
            pc_next = alu_result & ~32'h1; // Force halfword alignment
        end else if (dec_is_system && dec_is_ecall) begin
            pc_next = 32'h00001000; // Exception handler
        end else if (dec_is_system && dec_is_ebreak) begin
            pc_next = 32'h00001000; // Exception handler
        end else begin
            pc_next = pc + 32'h4;
        end
    end

    // Code memory request
    assign code_addr = pc;
    assign code_req  = !stall;
    assign instruction = code_data;

    // ==================== Decoder ====================
    decoder u_decoder (
        .instruction (instruction),
        .rd          (dec_rd),
        .rs1         (dec_rs1),
        .rs2         (dec_rs2),
        .funct3      (dec_funct3),
        .funct7      (dec_funct7),
        .imm_i       (dec_imm_i),
        .imm_s       (dec_imm_s),
        .imm_b       (dec_imm_b),
        .imm_u       (dec_imm_u),
        .imm_j       (dec_imm_j),
        .reg_write   (dec_reg_write),
        .mem_read    (dec_mem_read),
        .mem_write   (dec_mem_write),
        .mem_size    (dec_mem_size),
        .branch      (dec_branch),
        .branch_type (dec_branch_type),
        .jump        (dec_jump),
        .jump_reg    (dec_jump_reg),
        .alu_op      (dec_alu_op),
        .alu_src_b   (dec_alu_src_b),
        .wb_sel      (dec_wb_sel),
        .is_lui      (dec_is_lui),
        .is_auipc    (dec_is_auipc),
        .is_system   (dec_is_system),
        .is_ecall    (dec_is_ecall),
        .is_ebreak   (dec_is_ebreak),
        .is_csr      (dec_is_csr),
        .csr_op      (dec_csr_op),
        .is_vector   (dec_is_vector),
        .is_matrix   (dec_is_matrix),
        .vec_op      (dec_vec_op),
        .mat_op      (dec_mat_op),
        .instr_type  (dec_instr_type)
    );

    // ==================== Register File ====================
    register_file u_regfile (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (dec_rs1),
        .rs1_data (rs1_data),
        .rs2_addr (dec_rs2),
        .rs2_data (rs2_data),
        .rd_addr  (dec_rd),
        .rd_data  (wb_data),
        .rd_we    (dec_reg_write)
    );

    // ==================== ALU Source Mux ====================
    assign alu_op_b = dec_alu_src_b ? dec_imm_i : rs2_data;

    // ==================== ALU ====================
    alu u_alu (
        .op_a      (rs1_data),
        .op_b      (alu_op_b),
        .alu_op    (dec_alu_op),
        .result    (alu_result),
        .zero      (alu_zero),
        .negative  (alu_negative),
        .carry     (alu_carry),
        .overflow  (alu_overflow)
    );

    // ==================== Branch Logic ====================
    always_comb begin
        branch_taken = 1'b0;
        branch_target = 32'b0;

        if (dec_branch) begin
            case (dec_branch_type)
                3'b000: branch_taken = alu_zero;           // BEQ
                3'b001: branch_taken = ~alu_zero;          // BNE
                3'b100: branch_taken = alu_negative;       // BLT
                3'b101: branch_taken = ~alu_negative;      // BGE
                3'b110: branch_taken = ~alu_carry;         // BLTU
                3'b111: branch_taken = alu_carry;          // BGEU
                default: branch_taken = 1'b0;
            endcase
            branch_target = pc + dec_imm_b;
        end
    end

    // ==================== Data Memory Interface ====================
    assign data_addr  = alu_result;
    assign data_wdata = rs2_data;
    assign data_req   = dec_mem_read | dec_mem_write;
    assign data_we    = dec_mem_write;
    assign data_size  = dec_mem_size;

    // ==================== Write Back Mux ====================
    always_comb begin
        case (dec_wb_sel)
            2'b00: wb_data = alu_result;          // ALU result
            2'b01: wb_data = data_rdata;           // Memory read
            2'b10: wb_data = pc + 32'h4;           // PC+4 (JAL/JALR)
            2'b11: wb_data = dec_imm_u;            // Upper immediate (LUI)
            default: wb_data = alu_result;
        endcase
    end

    // ==================== CSR Registers ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_status <= 32'b0;
            csr_epc    <= 32'b0;
            csr_cause  <= 32'b0;
            csr_vlx    <= 32'd8;
            csr_vly    <= 32'd8;
            csr_vlz    <= 32'd8;
        end else if (dec_is_system && dec_is_ecall) begin
            csr_epc   <= pc;
            csr_cause <= 32'h0000000B; // Environment call
            csr_status[7] <= 1'b0;     // Clear IE
        end else if (dec_is_system && dec_is_ebreak) begin
            csr_epc   <= pc;
            csr_cause <= 32'h00000003; // Breakpoint
            csr_status[7] <= 1'b0;     // Clear IE
        end else if (dec_is_csr) begin
            case (dec_imm_i[11:0])
                CSR_VLX: csr_vlx <= (dec_csr_op == 2'b01) ? rs1_data : csr_vlx;
                CSR_VLY: csr_vly <= (dec_csr_op == 2'b01) ? rs1_data : csr_vly;
                CSR_VLZ: csr_vlz <= (dec_csr_op == 2'b01) ? rs1_data : csr_vlz;
                CSR_STATUS: csr_status <= (dec_csr_op == 2'b01) ? rs1_data : csr_status;
                CSR_EPC:    csr_epc    <= (dec_csr_op == 2'b01) ? rs1_data : csr_epc;
                CSR_CAUSE:  csr_cause  <= (dec_csr_op == 2'b01) ? rs1_data : csr_cause;
            endcase
        end
    end

    // ==================== Stall Logic ====================
    // v0.1: Simple stall for multi-cycle operations
    assign stall = 1'b0; // No stalls in single-cycle version

    // ==================== Exception Handling ====================
    // v0.1: ECALL/EBREAK jump to handler, no nested exceptions

endmodule
