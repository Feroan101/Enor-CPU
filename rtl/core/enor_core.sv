// ENOR-CPU Core Top Module
// Single-cycle implementation for v0.1 with multi-cycle vector/matrix support
// All 256-bit wide signals avoid LHS bit-slices in always_* blocks (Icarus workaround)

module enor_core (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] code_addr,
    input  logic [31:0] code_data,
    output logic        code_req,
    output logic [31:0] data_addr,
    output logic [31:0] data_wdata,
    input  logic [31:0] data_rdata,
    output logic        data_req,
    output logic        data_we,
    output logic [ 1:0] data_size,
    input  logic        irq_timer,
    input  logic        irq_ext
);

    logic [31:0] pc, pc_next;
    logic [31:0] instruction;
    logic        stall;

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

    logic [31:0] rs1_data, rs2_data;
    logic [31:0] alu_result;
    logic        alu_zero, alu_negative, alu_carry, alu_overflow;
    logic [31:0] alu_op_b;
    logic [31:0] wb_data;
    logic        branch_taken;
    logic [31:0] branch_target;

    logic [31:0] csr_status, csr_epc, csr_cause;
    logic [31:0] csr_vlx, csr_vly, csr_vlz;
    localparam CSR_STATUS = 12'h010;
    localparam CSR_EPC    = 12'h011;
    localparam CSR_CAUSE  = 12'h012;
    localparam CSR_VLX    = 12'h002;
    localparam CSR_VLY    = 12'h003;
    localparam CSR_VLZ    = 12'h004;

    // ==================== Vector Register File ====================
    logic [ 3:0] vrf_vs1_addr, vrf_vs2_addr, vrf_vd_addr;
    logic [255:0] vrf_vs1_data, vrf_vs2_data, vrf_vd_data;
    logic        vrf_vd_we;
    logic [ 2:0] vrf_vl_in, vrf_vl_out;

    vector_regfile u_vregfile (
        .clk(clk), .rst_n(rst_n),
        .vs1_addr(vrf_vs1_addr), .vs1_data(vrf_vs1_data),
        .vs2_addr(vrf_vs2_addr), .vs2_data(vrf_vs2_data),
        .vd_addr(vrf_vd_addr), .vd_data(vrf_vd_data), .vd_we(vrf_vd_we),
        .vl_in(vrf_vl_in), .vl_out(vrf_vl_out)
    );

    assign vrf_vs1_addr = dec_rs1[3:0];
    assign vrf_vs2_addr = dec_rs2[3:0];
    assign vrf_vl_in    = rs1_data[2:0];

    // ==================== Matrix Accumulator ====================
    logic [ 2:0] mat_row_addr, mat_col_addr;
    logic [31:0] mat_read_data;
    logic [ 2:0] mat_wr_row_addr, mat_wr_col_addr;
    logic [31:0] mat_write_data;
    logic        mat_write_en, mat_clear;

    matrix_regfile u_matregfile (
        .clk(clk), .rst_n(rst_n),
        .row_addr(mat_row_addr), .col_addr(mat_col_addr), .read_data(mat_read_data),
        .wr_row_addr(mat_wr_row_addr), .wr_col_addr(mat_wr_col_addr),
        .write_data(mat_write_data), .write_en(mat_write_en), .clear(mat_clear)
    );

    // ==================== Multi-Cycle Controller ====================
    localparam MC_IDLE   = 3'd0;
    localparam MC_VLW    = 3'd1;
    localparam MC_VSW    = 3'd2;
    localparam MC_MMUL_A = 3'd3;
    localparam MC_MMUL_B = 3'd4;
    localparam MC_MMUL_W = 3'd5;
    localparam MC_MSTORE = 3'd6;
    localparam MC_MLOAD  = 3'd7;

    logic [2:0]  mc_state;
    logic [5:0]  mc_cnt;
    logic [31:0] mc_addr_a, mc_addr_b;
    logic        mc_stall;
    logic        mc_is_mac;

    logic [2:0]  mc_state_nxt;
    logic [5:0]  mc_cnt_nxt;
    logic        mc_stall_nxt;

    logic [31:0] mat_a [0:7][0:7];
    logic [31:0] mat_b [0:7][0:7];

    // VLW buffer: use 8 separate 32-bit words to avoid bit-select in always_ff
    logic [31:0] vlw_buf [0:7];
    logic        vl_write_pending;
    logic [ 3:0] vlw_rd;  // Latch VLW destination register

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mc_state <= MC_IDLE;
            mc_cnt   <= 6'd0;
            mc_addr_a <= 32'b0;
            mc_addr_b <= 32'b0;
            mc_is_mac <= 1'b0;
            vl_write_pending <= 1'b0;
            vlw_rd <= 4'b0;
            for (int i = 0; i < 8; i++)
                vlw_buf[i] <= 32'b0;
            for (int i = 0; i < 8; i++)
                for (int j = 0; j < 8; j++) begin
                    mat_a[i][j] <= 32'b0;
                    mat_b[i][j] <= 32'b0;
                end
        end else begin
            mc_state   <= mc_state_nxt;
            mc_cnt     <= mc_cnt_nxt;
            mc_stall   <= mc_stall_nxt;

            // VLW: capture each loaded word into array element (no bit-select on wide LHS)
            if (mc_state == MC_VLW) begin
                vlw_buf[mc_cnt[2:0]] <= data_rdata;
            end

            // VLW write pending: set when VLW completes, cleared next cycle
            if (mc_state == MC_VLW && mc_state_nxt == MC_IDLE)
                vl_write_pending <= 1'b1;
            else
                vl_write_pending <= 1'b0;

            // MMUL_A: capture matrix A elements
            if (mc_state == MC_MMUL_A) begin
                mat_a[mc_cnt[5:3]][mc_cnt[2:0]] <= data_rdata;
            end

            // MMUL_B: capture matrix B elements
            if (mc_state == MC_MMUL_B) begin
                mat_b[mc_cnt[5:3]][mc_cnt[2:0]] <= data_rdata;
            end

            // Start of multi-cycle: latch addresses, MAC flag, and rd
            if (mc_state == MC_IDLE && mc_state_nxt != MC_IDLE) begin
                mc_addr_a <= rs1_data + (dec_is_matrix ? 32'd0 : dec_imm_i);
                mc_addr_b <= rs2_data;
                mc_is_mac <= (dec_is_matrix && dec_mat_op == 4'h1);
                vlw_rd    <= dec_rd[3:0];
                for (int i = 0; i < 8; i++)
                    vlw_buf[i] <= 32'b0;
            end
        end
    end

    // Multi-cycle controller next-state (combinational)
    logic [2:0] mc_vl_limit;
    assign mc_vl_limit = vrf_vl_out;

    logic [31:0] mc_cur_addr;

    always_comb begin
        mc_state_nxt = mc_state;
        mc_cnt_nxt   = mc_cnt;
        mc_stall_nxt = 1'b0;

        case (mc_state)
            MC_IDLE: begin
                if (!vl_write_pending) begin
                    if (dec_is_vector && dec_vec_op == 4'h8) begin
                        mc_state_nxt = MC_VLW;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end else if (dec_is_vector && dec_vec_op == 4'h9) begin
                        mc_state_nxt = MC_VSW;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end else if (dec_is_matrix && dec_mat_op == 4'h0) begin
                        mc_state_nxt = MC_MMUL_A;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end else if (dec_is_matrix && dec_mat_op == 4'h1) begin
                        mc_state_nxt = MC_MMUL_A;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end else if (dec_is_matrix && dec_mat_op == 4'h3) begin
                        mc_state_nxt = MC_MSTORE;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end else if (dec_is_matrix && dec_mat_op == 4'h2) begin
                        mc_state_nxt = MC_MLOAD;
                        mc_cnt_nxt = 6'd0;
                        mc_stall_nxt = 1'b1;
                    end
                end
            end

            MC_VLW: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt[2:0] >= mc_vl_limit - 3'd1) begin
                    mc_state_nxt = MC_IDLE;
                    mc_stall_nxt = 1'b0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_VSW: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt[2:0] >= mc_vl_limit - 3'd1) begin
                    mc_state_nxt = MC_IDLE;
                    mc_stall_nxt = 1'b0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_MMUL_A: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt == 6'd63) begin
                    mc_state_nxt = MC_MMUL_B;
                    mc_cnt_nxt = 6'd0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_MMUL_B: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt == 6'd63) begin
                    mc_state_nxt = MC_MMUL_W;
                    mc_cnt_nxt = 6'd0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_MMUL_W: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt == 6'd63) begin
                    mc_state_nxt = MC_IDLE;
                    mc_stall_nxt = 1'b0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_MSTORE: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt == 6'd63) begin
                    mc_state_nxt = MC_IDLE;
                    mc_stall_nxt = 1'b0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            MC_MLOAD: begin
                mc_stall_nxt = 1'b1;
                if (mc_cnt == 6'd63) begin
                    mc_state_nxt = MC_IDLE;
                    mc_stall_nxt = 1'b0;
                end else begin
                    mc_cnt_nxt = mc_cnt + 6'd1;
                end
            end

            default: begin
                mc_state_nxt = MC_IDLE;
            end
        endcase
    end

    // Compute address for multi-cycle memory access
    always_comb begin
        case (mc_state)
            MC_VLW:    mc_cur_addr = mc_addr_a + {26'b0, mc_cnt[2:0], 2'b00};
            MC_VSW:    mc_cur_addr = mc_addr_a + {26'b0, mc_cnt[2:0], 2'b00};
            MC_MMUL_A: mc_cur_addr = mc_addr_a + {26'b0, mc_cnt, 2'b00};
            MC_MMUL_B: mc_cur_addr = mc_addr_b + {26'b0, mc_cnt, 2'b00};
            MC_MSTORE: mc_cur_addr = mc_addr_a + {26'b0, mc_cnt, 2'b00};
            MC_MLOAD:  mc_cur_addr = mc_addr_a + {26'b0, mc_cnt, 2'b00};
            default:   mc_cur_addr = 32'b0;
        endcase
    end

    // VSW data: read from vector regfile using part-select (continuous assign, safe)
    logic [31:0] vsw_data;
    assign vsw_data = vrf_vs2_data[mc_cnt[2:0]*32 +: 32];

    // MSTORE read port
    assign mat_row_addr = mc_cnt[5:3];
    assign mat_col_addr = mc_cnt[2:0];

    // Matrix multiply write-back logic
    logic [31:0] mmul_result;
    logic [31:0] mmul_accum;
    logic [2:0]  mmul_i, mmul_j;

    assign mmul_i = mc_cnt[5:3];
    assign mmul_j = mc_cnt[2:0];

    // MLOAD: write data to matrix
    assign mat_wr_row_addr = mc_cnt[5:3];
    assign mat_wr_col_addr = mc_cnt[2:0];
    assign mat_write_data  = data_rdata;
    assign mat_write_en    = (mc_state == MC_MLOAD) || (mc_state == MC_MMUL_W);
    assign mat_clear       = (mc_state == MC_MMUL_W && mc_cnt == 6'd0 && !mc_is_mac);

    // MMUL_W: compute each element (unrolled to avoid bit-selects)
    logic [31:0] mmul_k0, mmul_k1, mmul_k2, mmul_k3;
    logic [31:0] mmul_k4, mmul_k5, mmul_k6, mmul_k7;

    always_comb begin
        mmul_k0 = (0 < csr_vlz[2:0]) ? mat_a[mmul_i][0] * mat_b[0][mmul_j] : 32'b0;
        mmul_k1 = (1 < csr_vlz[2:0]) ? mat_a[mmul_i][1] * mat_b[1][mmul_j] : 32'b0;
        mmul_k2 = (2 < csr_vlz[2:0]) ? mat_a[mmul_i][2] * mat_b[2][mmul_j] : 32'b0;
        mmul_k3 = (3 < csr_vlz[2:0]) ? mat_a[mmul_i][3] * mat_b[3][mmul_j] : 32'b0;
        mmul_k4 = (4 < csr_vlz[2:0]) ? mat_a[mmul_i][4] * mat_b[4][mmul_j] : 32'b0;
        mmul_k5 = (5 < csr_vlz[2:0]) ? mat_a[mmul_i][5] * mat_b[5][mmul_j] : 32'b0;
        mmul_k6 = (6 < csr_vlz[2:0]) ? mat_a[mmul_i][6] * mat_b[6][mmul_j] : 32'b0;
        mmul_k7 = (7 < csr_vlz[2:0]) ? mat_a[mmul_i][7] * mat_b[7][mmul_j] : 32'b0;
        mmul_result = mmul_k0 + mmul_k1 + mmul_k2 + mmul_k3
                    + mmul_k4 + mmul_k5 + mmul_k6 + mmul_k7;
        if (mc_is_mac)
            mmul_accum = mat_read_data + mmul_result;
        else
            mmul_accum = mmul_result;
    end

    // ==================== PC Logic ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h00000000;
        else if (!stall)
            pc <= pc_next;
    end

    always_comb begin
        if (branch_taken)
            pc_next = branch_target;
        else if (dec_jump)
            pc_next = alu_result;
        else if (dec_jump_reg)
            pc_next = alu_result & ~32'h1;
        else if (dec_is_system && (dec_is_ecall || dec_is_ebreak))
            pc_next = 32'h00001000;
        else
            pc_next = pc + 32'h4;
    end

    assign code_addr = pc;
    assign code_req  = !stall;
    assign instruction = code_data;

    // ==================== Decoder ====================
    decoder u_decoder (
        .instruction(instruction), .rd(dec_rd), .rs1(dec_rs1), .rs2(dec_rs2),
        .funct3(dec_funct3), .funct7(dec_funct7),
        .imm_i(dec_imm_i), .imm_s(dec_imm_s), .imm_b(dec_imm_b),
        .imm_u(dec_imm_u), .imm_j(dec_imm_j),
        .reg_write(dec_reg_write), .mem_read(dec_mem_read), .mem_write(dec_mem_write),
        .mem_size(dec_mem_size), .branch(dec_branch), .branch_type(dec_branch_type),
        .jump(dec_jump), .jump_reg(dec_jump_reg),
        .alu_op(dec_alu_op), .alu_src_b(dec_alu_src_b), .wb_sel(dec_wb_sel),
        .is_lui(dec_is_lui), .is_auipc(dec_is_auipc),
        .is_system(dec_is_system), .is_ecall(dec_is_ecall),
        .is_ebreak(dec_is_ebreak), .is_csr(dec_is_csr), .csr_op(dec_csr_op),
        .is_vector(dec_is_vector), .is_matrix(dec_is_matrix),
        .vec_op(dec_vec_op), .mat_op(dec_mat_op), .instr_type(dec_instr_type)
    );

    // ==================== Register File ====================
    register_file u_regfile (
        .clk(clk), .rst_n(rst_n),
        .rs1_addr(dec_rs1), .rs1_data(rs1_data),
        .rs2_addr(dec_rs2), .rs2_data(rs2_data),
        .rd_addr(dec_rd), .rd_data(wb_data), .rd_we(dec_reg_write)
    );

    // ==================== ALU Source Mux ====================
    logic [31:0] imm_selected;
    assign imm_selected = (dec_instr_type == 3'b010) ? dec_imm_s :
                          (dec_instr_type == 3'b011) ? dec_imm_b :
                          (dec_instr_type == 3'b100) ? dec_imm_u :
                          (dec_instr_type == 3'b101) ? dec_imm_j :
                          dec_imm_i;
    assign alu_op_b = dec_alu_src_b ? imm_selected : rs2_data;

    // ==================== ALU ====================
    alu u_alu (
        .op_a(rs1_data), .op_b(alu_op_b), .alu_op(dec_alu_op),
        .result(alu_result), .zero(alu_zero), .negative(alu_negative),
        .carry(alu_carry), .overflow(alu_overflow)
    );

    // ==================== Branch Logic ====================
    always_comb begin
        branch_taken = 1'b0;
        branch_target = 32'b0;
        if (dec_branch) begin
            case (dec_branch_type)
                3'b000: branch_taken = alu_zero;
                3'b001: branch_taken = ~alu_zero;
                3'b100: branch_taken = alu_negative;
                3'b101: branch_taken = ~alu_negative;
                3'b110: branch_taken = ~alu_carry;
                3'b111: branch_taken = alu_carry;
                default: branch_taken = 1'b0;
            endcase
            branch_target = pc + dec_imm_b;
        end
    end

    // ==================== Vector ALU ====================
    // Compute each lane into separate 32-bit variables, then concatenate.
    // This avoids constant bit-selects on 256-bit LHS in always_comb.
    logic [31:0] va0, va1, va2, va3, va4, va5, va6, va7;
    logic [31:0] vb0, vb1, vb2, vb3, vb4, vb5, vb6, vb7;
    logic [31:0] vec_scalar_result;
    logic [255:0] vec_alu_result;
    logic        vec_wr_en;

    assign va0 = vrf_vs1_data[31:0];
    assign va1 = vrf_vs1_data[63:32];
    assign va2 = vrf_vs1_data[95:64];
    assign va3 = vrf_vs1_data[127:96];
    assign va4 = vrf_vs1_data[159:128];
    assign va5 = vrf_vs1_data[191:160];
    assign va6 = vrf_vs1_data[223:192];
    assign va7 = vrf_vs1_data[255:224];

    assign vb0 = vrf_vs2_data[31:0];
    assign vb1 = vrf_vs2_data[63:32];
    assign vb2 = vrf_vs2_data[95:64];
    assign vb3 = vrf_vs2_data[127:96];
    assign vb4 = vrf_vs2_data[159:128];
    assign vb5 = vrf_vs2_data[191:160];
    assign vb6 = vrf_vs2_data[223:192];
    assign vb7 = vrf_vs2_data[255:224];

    logic [31:0] vs0, vs1, vs2, vs3, vs4, vs5, vs6, vs7;

    always_comb begin
        vec_scalar_result = 32'b0;
        vec_wr_en = 1'b0;
        vs0 = 32'b0; vs1 = 32'b0; vs2 = 32'b0; vs3 = 32'b0;
        vs4 = 32'b0; vs5 = 32'b0; vs6 = 32'b0; vs7 = 32'b0;

        if (dec_is_vector) begin
            case (dec_vec_op)
                4'h0: begin // VADD
                    vec_wr_en = 1'b1;
                    vs0 = va0 + vb0;
                    vs1 = va1 + vb1;
                    vs2 = va2 + vb2;
                    vs3 = va3 + vb3;
                    vs4 = va4 + vb4;
                    vs5 = va5 + vb5;
                    vs6 = va6 + vb6;
                    vs7 = va7 + vb7;
                end
                4'h2: begin // VSUB
                    vec_wr_en = 1'b1;
                    vs0 = va0 - vb0;
                    vs1 = va1 - vb1;
                    vs2 = va2 - vb2;
                    vs3 = va3 - vb3;
                    vs4 = va4 - vb4;
                    vs5 = va5 - vb5;
                    vs6 = va6 - vb6;
                    vs7 = va7 - vb7;
                end
                4'h4: begin // VMUL
                    vec_wr_en = 1'b1;
                    vs0 = va0 * vb0;
                    vs1 = va1 * vb1;
                    vs2 = va2 * vb2;
                    vs3 = va3 * vb3;
                    vs4 = va4 * vb4;
                    vs5 = va5 * vb5;
                    vs6 = va6 * vb6;
                    vs7 = va7 * vb7;
                end
                4'h1: begin // VDOT
                    vec_scalar_result = va0 * vb0 + va1 * vb1 + va2 * vb2 + va3 * vb3
                                      + va4 * vb4 + va5 * vb5 + va6 * vb6 + va7 * vb7;
                end
                4'h3: begin // VRED_SUM
                    vec_scalar_result = va0 + va1 + va2 + va3 + va4 + va5 + va6 + va7;
                end
                default: ;
            endcase
        end
    end

    assign vec_alu_result = {vs7, vs6, vs5, vs4, vs3, vs2, vs1, vs0};

    // ==================== VSETVL + Vector regfile write ====================
    // VSETVL: write VL to vector regfile special addr (0xF) and write VL value to scalar rd
    logic vsetvl_we;
    assign vsetvl_we = dec_is_vector && dec_vec_op == 4'h5;

    assign vrf_vd_addr = vsetvl_we ? 4'hF : (vl_write_pending ? vlw_rd : dec_rd[3:0]);
    assign vrf_vd_we   = vec_wr_en | vl_write_pending | vsetvl_we;
    assign vrf_vd_data = vl_write_pending ? {vlw_buf[7], vlw_buf[6], vlw_buf[5], vlw_buf[4],
                                             vlw_buf[3], vlw_buf[2], vlw_buf[1], vlw_buf[0]}
                       : vec_alu_result;

    // ==================== Data Memory Interface ====================
    always_comb begin
        if (mc_state != MC_IDLE) begin
            data_addr  = mc_cur_addr;
            data_wdata = (mc_state == MC_VSW) ? vsw_data :
                         (mc_state == MC_MSTORE) ? mat_read_data :
                         (mc_state == MC_MMUL_W) ? mmul_accum : 32'b0;
            data_req   = (mc_state != MC_MMUL_W);
            data_we    = (mc_state == MC_VSW) || (mc_state == MC_MSTORE);
            data_size  = 2'b10;
        end else begin
            data_addr  = alu_result;
            data_wdata = rs2_data;
            data_req   = dec_mem_read | dec_mem_write;
            data_we    = dec_mem_write;
            data_size  = dec_mem_size;
        end
    end

    // ==================== Write Back Mux ====================
    always_comb begin
        case (dec_wb_sel)
            2'b00: wb_data = alu_result;
            2'b01: wb_data = data_rdata;
            2'b10: wb_data = pc + 32'h4;
            2'b11: wb_data = dec_imm_u;
            default: wb_data = alu_result;
        endcase

        if (dec_is_vector && (dec_vec_op == 4'h1 || dec_vec_op == 4'h3))
            wb_data = vec_scalar_result;
        if (vsetvl_we)
            wb_data = {29'b0, rs1_data[2:0]};
    end

    // ==================== CSR Registers ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            csr_status <= 32'b0; csr_epc <= 32'b0; csr_cause <= 32'b0;
            csr_vlx <= 32'd8; csr_vly <= 32'd8; csr_vlz <= 32'd8;
        end else if (dec_is_system && dec_is_ecall) begin
            csr_epc <= pc; csr_cause <= 32'h0000000B; csr_status[7] <= 1'b0;
        end else if (dec_is_system && dec_is_ebreak) begin
            csr_epc <= pc; csr_cause <= 32'h00000003; csr_status[7] <= 1'b0;
        end else if (dec_is_csr) begin
            case (dec_imm_i[11:0])
                CSR_VLX:    csr_vlx    <= (dec_csr_op == 2'b01) ? rs1_data : csr_vlx;
                CSR_VLY:    csr_vly    <= (dec_csr_op == 2'b01) ? rs1_data : csr_vly;
                CSR_VLZ:    csr_vlz    <= (dec_csr_op == 2'b01) ? rs1_data : csr_vlz;
                CSR_STATUS: csr_status <= (dec_csr_op == 2'b01) ? rs1_data : csr_status;
                CSR_EPC:    csr_epc    <= (dec_csr_op == 2'b01) ? rs1_data : csr_epc;
                CSR_CAUSE:  csr_cause  <= (dec_csr_op == 2'b01) ? rs1_data : csr_cause;
            endcase
        end
    end

    // Stall on: multi-cycle active, vl write-back pending, or just entering multi-cycle
    logic mc_entering_mc;
    assign mc_entering_mc = (mc_state == MC_IDLE) && (mc_state_nxt != MC_IDLE);
    assign stall = mc_stall_nxt | vl_write_pending | mc_entering_mc;

endmodule
