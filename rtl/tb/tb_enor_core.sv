// ENOR-CPU Core Testbench
// Verifies basic instruction execution against expected values

`timescale 1ns / 1ps

module tb_enor_core;

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

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 100MHz

    // DUT instantiation
    enor_core u_core (
        .clk         (clk),
        .rst_n       (rst_n),
        .code_addr   (code_addr),
        .code_data   (code_data),
        .code_req    (code_req),
        .data_addr   (data_addr),
        .data_wdata  (data_wdata),
        .data_rdata  (data_rdata),
        .data_req    (data_req),
        .data_we     (data_we),
        .data_size   (data_size),
        .irq_timer   (1'b0),
        .irq_ext     (1'b0)
    );

    // Instruction memory
    logic [31:0] instr_mem [0:255];
    assign code_data = instr_mem[code_addr[9:2]];

    // Data memory
    logic [31:0] data_mem [0:1023];
    assign data_rdata = data_mem[data_addr[13:2]];

    always_ff @(posedge clk) begin
        if (data_req && data_we) begin
            data_mem[data_addr[13:2]] <= data_wdata;
        end
    end

    initial begin
        // Load test program
        instr_mem[0]  = 32'h00a00293; // ADDI x5, x0, 10
        instr_mem[1]  = 32'h01400313; // ADDI x6, x0, 20
        instr_mem[2]  = 32'h006283b3; // ADD  x7, x5, x6
        instr_mem[3]  = 32'h40538433; // SUB  x8, x7, x5
        instr_mem[4]  = 32'h009474b3; // AND  x9, x8, x7
        instr_mem[5]  = 32'h00946533; // OR   x10, x8, x7
        instr_mem[6]  = 32'h009445b3; // XOR  x11, x8, x7
        instr_mem[7]  = 32'h00702023; // SW   x7, 0(x0)
        instr_mem[8]  = 32'h00002603; // LW   x12, 0(x0)
        instr_mem[9]  = 32'h007426b3; // SLT  x13, x8, x7
        instr_mem[10] = 32'h0083b733; // SLTU x14, x7, x8
        instr_mem[11] = 32'h00100073; // EBREAK

        // Initialize
        rst_n = 0;
        cycle_count = 0;
        errors = 0;
        test_done = 0;

        // Reset
        #25;
        rst_n = 1;

        // Run until EBREAK or timeout
        while (!test_done && cycle_count < 100) begin
            @(posedge clk);
            cycle_count++;

            // Check for EBREAK at current PC
            if (code_data == 32'h00100073 && code_req) begin
                @(posedge clk);
                @(posedge clk);
                test_done = 1;
            end
        end

        // ==================== Verify Results ====================
        $display("\n=== ENOR-CPU RTL Verification ===");
        $display("Cycles executed: %0d", cycle_count);

        check_reg("x5",  32'd10);
        check_reg("x6",  32'd20);
        check_reg("x7",  32'd30);
        check_reg("x8",  32'd20);
        check_reg("x9",  32'd20);
        check_reg("x10", 32'd30);
        check_reg("x11", 32'd10);
        check_reg("x12", 32'd30);
        check_reg("x13", 32'd1);
        check_reg("x14", 32'd0);

        check_mem("mem[0]", 0, 32'd30);

        $display("\n=== Test Summary ===");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILURES: %0d", errors);
        $display("====================\n");

        $finish;
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
                default: actual = 32'hDEADBEEF;
            endcase

            if (actual === expected) begin
                $display("  PASS: %0s = %0d (0x%08h)", name, actual, actual);
            end else begin
                $display("  FAIL: %0s = %0d (0x%08h), expected %0d (0x%08h)",
                         name, actual, actual, expected, expected);
                errors++;
            end
        end
    endtask

    task check_mem;
        input [8*16-1:0] name;
        input [31:0] addr;
        input [31:0] expected;
        logic [31:0] actual;
        begin
            actual = data_mem[addr[13:2]];
            if (actual === expected) begin
                $display("  PASS: %0s = %0d (0x%08h)", name, actual, actual);
            end else begin
                $display("  FAIL: %0s = %0d (0x%08h), expected %0d (0x%08h)",
                         name, actual, actual, expected, expected);
                errors++;
            end
        end
    endtask

    initial begin
        #1000000;
        if (!test_done) begin
            $display("TIMEOUT");
            $finish;
        end
    end

endmodule
