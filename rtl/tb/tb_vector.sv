// ENOR-CPU Vector Execution Test
// Verifies vector load, store, arithmetic, dot product, and reduction

`timescale 1ns / 1ps

module tb_vector;

    logic        clk;
    logic        rst_n;
    logic [31:0] code_addr;
    logic [31:0] code_data;
    logic        code_req;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;
    logic        data_req;
    logic        data_we;
    logic [ 1:0] data_size;

    int          cycle_count;
    int          errors;
    logic        test_done;

    initial clk = 0;
    always #5 clk = ~clk;

    enor_core u_core (
        .clk(clk), .rst_n(rst_n),
        .code_addr(code_addr), .code_data(code_data), .code_req(code_req),
        .data_addr(data_addr), .data_wdata(data_wdata), .data_rdata(data_rdata),
        .data_req(data_req), .data_we(data_we), .data_size(data_size),
        .irq_timer(1'b0), .irq_ext(1'b0)
    );

    // Instruction memory (loaded from test_vector.asm)
    logic [31:0] instr_mem [0:255];
    assign code_data = instr_mem[code_addr[9:2]];

    // Data memory
    logic [31:0] data_mem [0:4095];
    assign data_rdata = data_mem[data_addr[15:2]];

    always_ff @(posedge clk) begin
        if (data_req && data_we) begin
            data_mem[data_addr[15:2]] <= data_wdata;
        end
    end

    task check_reg;
        input [8*8-1:0] name;
        input [31:0] expected;
        logic [31:0] actual;
        begin
            case (name)
                "x5":  actual = u_core.u_regfile.registers[5];
                "x6":  actual = u_core.u_regfile.registers[6];
                "x7":  actual = u_core.u_regfile.registers[7];
                "x8":  actual = u_core.u_regfile.registers[8];
                "x9":  actual = u_core.u_regfile.registers[9];
                "x10": actual = u_core.u_regfile.registers[10];
                "x11": actual = u_core.u_regfile.registers[11];
                "x12": actual = u_core.u_regfile.registers[12];
                "x13": actual = u_core.u_regfile.registers[13];
                "x14": actual = u_core.u_regfile.registers[14];
                "x15": actual = u_core.u_regfile.registers[15];
                "x16": actual = u_core.u_regfile.registers[16];
                default: actual = 32'hDEADBEEF;
            endcase

            if (actual === expected)
                $display("  PASS: %0s = %0d (0x%08h)", name, actual, actual);
            else begin
                $display("  FAIL: %0s = %0d (0x%08h), expected %0d (0x%08h)",
                         name, actual, actual, expected, expected);
                errors++;
            end
        end
    endtask

    task check_vec;
        input [8*4-1:0] name;
        input [31:0] e0, e1, e2, e3;
        logic [255:0] vreg;
        logic [31:0] actual_e0, actual_e1, actual_e2, actual_e3;
        begin
            case (name)
                "v2":  vreg = u_core.u_vregfile.vregs[2];
                "v3":  vreg = u_core.u_vregfile.vregs[3];
                default: vreg = 256'b0;
            endcase
            actual_e0 = vreg[31:0];
            actual_e1 = vreg[63:32];
            actual_e2 = vreg[95:64];
            actual_e3 = vreg[127:96];

            if (actual_e0 === e0 && actual_e1 === e1 && actual_e2 === e2 && actual_e3 === e3)
                $display("  PASS: %0s = [%0d, %0d, %0d, %0d]", name, actual_e0, actual_e1, actual_e2, actual_e3);
            else begin
                $display("  FAIL: %0s = [%0d, %0d, %0d, %0d], expected [%0d, %0d, %0d, %0d]",
                         name, actual_e0, actual_e1, actual_e2, actual_e3, e0, e1, e2, e3);
                errors++;
            end
        end
    endtask

    task check_mem;
        input [31:0] addr;
        input [31:0] expected;
        logic [31:0] actual;
        begin
            actual = data_mem[addr[15:2]];
            if (actual === expected)
                $display("  PASS: mem[0x%08h] = %0d (0x%08h)", addr, actual, actual);
            else begin
                $display("  FAIL: mem[0x%08h] = %0d (0x%08h), expected %0d (0x%08h)",
                         addr, actual, actual, expected, expected);
                errors++;
            end
        end
    endtask

    initial begin
        // Load test_vector machine code (from assembler output)
        instr_mem[0]  = 32'h00400293; // ADDI x5, x0, 4
        instr_mem[1]  = 32'h400282d7; // VSETVL x5, x5
        instr_mem[2]  = 32'h40000337; // LUI x6, 0x40000
        instr_mem[3]  = 32'h04032023; // SW x0, 0x40(x6)
        instr_mem[4]  = 32'h00100393; // ADDI x7, x0, 1
        instr_mem[5]  = 32'h04732223; // SW x7, 0x44(x6)
        instr_mem[6]  = 32'h00200393; // ADDI x7, x0, 2
        instr_mem[7]  = 32'h04732423; // SW x7, 0x48(x6)
        instr_mem[8]  = 32'h00300393; // ADDI x7, x0, 3
        instr_mem[9]  = 32'h04732623; // SW x7, 0x4C(x6)
        instr_mem[10] = 32'h04032007; // VLW v0, 0x40(x6)
        instr_mem[11] = 32'h00a00393; // ADDI x7, x0, 10
        instr_mem[12] = 32'h04732823; // SW x7, 0x50(x6)
        instr_mem[13] = 32'h01400393; // ADDI x7, x0, 20
        instr_mem[14] = 32'h04732a23; // SW x7, 0x54(x6)
        instr_mem[15] = 32'h01e00393; // ADDI x7, x0, 30
        instr_mem[16] = 32'h04732c23; // SW x7, 0x58(x6)
        instr_mem[17] = 32'h02800393; // ADDI x7, x0, 40
        instr_mem[18] = 32'h04732e23; // SW x7, 0x5C(x6)
        instr_mem[19] = 32'h05032087; // VLW v1, 0x50(x6)
        instr_mem[20] = 32'h00100157; // VADD v2, v0, v1
        instr_mem[21] = 32'h06232027; // VSW v2, 0x60(x6)
        instr_mem[22] = 32'h081001d7; // VMUL v3, v0, v1
        instr_mem[23] = 32'h06332827; // VSW v3, 0x70(x6)
        instr_mem[24] = 32'h20100457; // VDOT x8, v0, v1
        instr_mem[25] = 32'h08832023; // SW x8, 0x80(x6)
        instr_mem[26] = 32'h220104d7; // VRED_SUM x9, v2
        instr_mem[27] = 32'h08932223; // SW x9, 0x84(x6)
        instr_mem[28] = 32'h00100073; // EBREAK

        rst_n = 0;
        cycle_count = 0;
        errors = 0;
        test_done = 0;

        #25;
        rst_n = 1;

        while (!test_done && cycle_count < 5000) begin
            @(posedge clk);
            cycle_count++;

            if (cycle_count >= 24 && cycle_count <= 36) begin
                $display("  DBG cyc=%0d PC=%h mc_st=%b vlp=%b stall=%b vrf_we=%b vrf_addr=%h",
                    cycle_count, u_core.pc, u_core.mc_stall, u_core.vl_write_pending,
                    u_core.stall, u_core.vrf_vd_we, u_core.vrf_vd_addr);
            end

            if (code_data == 32'h00100073 && code_req) begin
                @(posedge clk);
                @(posedge clk);
                test_done = 1;
            end
        end

        $display("\n=== ENOR-CPU Vector Verification ===");
        $display("Cycles executed: %0d", cycle_count);

        check_reg("x5",  32'd4);     // VSETVL returns 4
        check_reg("x6",  32'h40000000);
        check_reg("x8",  32'd200);    // dot product: 0*10+1*20+2*30+3*40=200
        check_reg("x9",  32'd106);    // sum reduction: 10+21+32+43=106

        check_vec("v2", 32'd10, 32'd21, 32'd32, 32'd43);
        check_vec("v3", 32'd0, 32'd20, 32'd60, 32'd120);

        check_mem(32'h40000060, 32'd10);
        check_mem(32'h40000064, 32'd21);
        check_mem(32'h40000068, 32'd32);
        check_mem(32'h4000006c, 32'd43);
        check_mem(32'h40000070, 32'd0);
        check_mem(32'h40000074, 32'd20);
        check_mem(32'h40000078, 32'd60);
        check_mem(32'h4000007c, 32'd120);
        check_mem(32'h40000080, 32'd200);
        check_mem(32'h40000084, 32'd106);

        $display("\n=== Test Summary ===");
        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("FAILURES: %0d", errors);
        $display("====================\n");

        $finish;
    end

    initial begin
        #5000000;
        if (!test_done) begin
            $display("TIMEOUT after %0d cycles", cycle_count);
            $finish;
        end
    end

endmodule
