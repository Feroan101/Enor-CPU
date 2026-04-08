// ENOR-CPU Instruction Decoder
// Decodes 32-bit instruction and generates control signals

module decoder (
    input  logic [31:0] instruction,

    // Decoded fields
    output logic [ 4:0] rd,
    output logic [ 4:0] rs1,
    output logic [ 4:0] rs2,
    output logic [ 2:0] funct3,
    output logic [ 6:0] funct7,
    output logic [31:0] imm_i,
    output logic [31:0] imm_s,
    output logic [31:0] imm_b,
    output logic [31:0] imm_u,
    output logic [31:0] imm_j,

    // Control signals
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic [ 1:0] mem_size,     // 00=byte, 01=half, 10=word
    output logic        branch,
    output logic [ 2:0] branch_type,  // 000=BEQ, 001=BNE, 010=BLT, 011=BGE, 100=BLTU, 101=BGEU
    output logic        jump,         // JAL
    output logic        jump_reg,     // JALR
    output logic [ 3:0] alu_op,
    output logic        alu_src_b,    // 0=register, 1=immediate
    output logic [ 1:0] wb_sel,       // 00=ALU, 01=MEM, 10=PC+4, 11=upper_imm
    output logic        is_lui,
    output logic        is_auipc,
    output logic        is_system,
    output logic        is_ecall,
    output logic        is_ebreak,
    output logic        is_csr,
    output logic [ 1:0] csr_op,

    // Vector/matrix decode
    output logic        is_vector,
    output logic        is_matrix,
    output logic [ 3:0] vec_op,
    output logic [ 3:0] mat_op,

    // Instruction type
    output logic [ 2:0] instr_type   // 000=R, 001=I, 010=S, 011=B, 100=U, 101=J
);

    logic [6:0] opcode;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // Immediate extraction
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    assign imm_b = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    assign imm_u = {instruction[31:12], 12'b0};
    assign imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    always_comb begin
        // Defaults
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_size   = 2'b10;
        branch     = 1'b0;
        branch_type = 3'b000;
        jump       = 1'b0;
        jump_reg   = 1'b0;
        alu_op     = 4'b0000;
        alu_src_b  = 1'b0;
        wb_sel     = 2'b00;
        is_lui     = 1'b0;
        is_auipc   = 1'b0;
        is_system  = 1'b0;
        is_ecall   = 1'b0;
        is_ebreak  = 1'b0;
        is_csr     = 1'b0;
        csr_op     = 2'b00;
        is_vector  = 1'b0;
        is_matrix  = 1'b0;
        vec_op     = 4'b0000;
        mat_op     = 4'b0000;
        instr_type = 3'b000;

        case (opcode)
            // R-type ALU
            7'b0110011: begin
                instr_type = 3'b000;
                reg_write  = 1'b1;
                alu_src_b  = 1'b0;
                wb_sel     = 2'b00;
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB/ADD
                    3'b001: alu_op = 4'b0101; // SLL
                    3'b010: alu_op = 4'b1000; // SLT
                    3'b011: alu_op = 4'b1001; // SLTU
                    3'b100: alu_op = 4'b0100; // XOR
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA/SRL
                    3'b110: alu_op = 4'b0011; // OR
                    3'b111: alu_op = 4'b0010; // AND
                endcase
            end

            // I-type ALU
            7'b0010011: begin
                instr_type = 3'b001;
                reg_write  = 1'b1;
                alu_src_b  = 1'b1;
                wb_sel     = 2'b00;
                case (funct3)
                    3'b000: alu_op = 4'b0000; // ADDI
                    3'b010: alu_op = 4'b1000; // SLTI
                    3'b011: alu_op = 4'b1001; // SLTIU
                    3'b100: alu_op = 4'b0100; // XORI
                    3'b110: alu_op = 4'b0011; // ORI
                    3'b111: alu_op = 4'b0010; // ANDI
                    3'b001: alu_op = 4'b0101; // SLLI
                    3'b101: alu_op = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI/SRLI
                endcase
            end

            // Load instructions (I-type)
            7'b0000011: begin
                instr_type = 3'b001;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                alu_src_b  = 1'b1;
                alu_op     = 4'b0000; // ADD for address
                wb_sel     = 2'b01;   // MEM
                case (funct3)
                    3'b000: mem_size = 2'b00; // LB
                    3'b001: mem_size = 2'b01; // LH
                    3'b010: mem_size = 2'b10; // LW
                    3'b100: mem_size = 2'b00; // LBU
                    3'b101: mem_size = 2'b01; // LHU
                endcase
            end

            // Store instructions (S-type)
            7'b0100011: begin
                instr_type = 3'b010;
                mem_write  = 1'b1;
                alu_src_b  = 1'b1;
                alu_op     = 4'b0000; // ADD for address
                case (funct3)
                    3'b000: mem_size = 2'b00; // SB
                    3'b001: mem_size = 2'b01; // SH
                    3'b010: mem_size = 2'b10; // SW
                endcase
            end

            // Branch instructions (B-type)
            7'b1100011: begin
                instr_type = 3'b011;
                branch     = 1'b1;
                branch_type = funct3[2:0];
            end

            // JAL (J-type)
            7'b1101111: begin
                instr_type = 3'b101;
                reg_write  = 1'b1;
                jump       = 1'b1;
                wb_sel     = 2'b10; // PC+4
            end

            // JALR (I-type)
            7'b1100111: begin
                instr_type = 3'b001;
                reg_write  = 1'b1;
                jump_reg   = 1'b1;
                wb_sel     = 2'b10; // PC+4
                alu_op     = 4'b0000;
            end

            // LUI (U-type)
            7'b0110111: begin
                instr_type = 3'b100;
                reg_write  = 1'b1;
                is_lui     = 1'b1;
                alu_op     = 4'b1010; // LUI pass-through
                alu_src_b  = 1'b1;
                wb_sel     = 2'b00;
            end

            // AUIPC (U-type)
            7'b0010111: begin
                instr_type = 3'b100;
                reg_write  = 1'b1;
                is_auipc   = 1'b1;
                alu_op     = 4'b1011; // AUIPC = PC + imm
                alu_src_b  = 1'b1;
                wb_sel     = 2'b00;
            end

            // Vector (opcode 0x57)
            7'b0101111: begin
                is_vector = 1'b1;
                vec_op    = funct7[3:0];
                case (funct7)
                    7'h00: begin // VSETVL
                        reg_write = 1'b1;
                        alu_op    = 4'b0000;
                        wb_sel    = 2'b00;
                    end
                    7'h01, 7'h02, 7'h03, 7'h04: begin // VADD, VSUB, VMUL, VDOT
                        // Vector arithmetic - result goes to vector register
                    end
                    7'h10: begin // VDOT
                        reg_write = 1'b1;
                        wb_sel    = 2'b00;
                    end
                    7'h20: begin // VRED_SUM
                        reg_write = 1'b1;
                        wb_sel    = 2'b00;
                    end
                endcase
            end

            // VLW (opcode 0x07)
            7'b0000111: begin
                is_vector = 1'b1;
                vec_op    = 4'h8; // VLW
            end

            // VSW (opcode 0x27)
            7'b0100111: begin
                is_vector = 1'b1;
                vec_op    = 4'h9; // VSW
            end

            // Matrix (opcode 0x77)
            7'b1110111: begin
                is_matrix = 1'b1;
                mat_op    = funct7[3:0];
                case (funct7)
                    7'h00: begin // MMUL
                    end
                    7'h01: begin // MMAC
                    end
                    7'h02: begin // MLOAD
                    end
                    7'h03: begin // MSTORE
                    end
                endcase
            end

            // System (opcode 0x73)
            7'b1110011: begin
                instr_type = 3'b001;
                is_system  = 1'b1;
                is_ecall   = (instruction[31:20] == 12'h000);
                is_ebreak  = (instruction[31:20] == 12'h001);
                is_csr     = (funct3 != 3'b000);
                csr_op     = funct3[1:0];
                if (is_csr) begin
                    reg_write = 1'b1;
                    wb_sel    = 2'b00;
                end
            end

            default: begin
                instr_type = 3'b111; // illegal
            end
        endcase
    end

endmodule
