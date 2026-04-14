// ENOR-CPU Deadlock Regression Test
// Regression test for the combinational loop caused by register file bypass
// when an instruction reads and writes the same register (rs == rd).
//
// Root cause: The bypass network forwarded rd_data to rs_data in the same
// cycle, creating: rs_data -> wb_data -> alu_result -> depends on rs_data
//
// This test verifies that self-reading instructions (e.g., ADD x5, x5, x6)
// execute correctly without deadlock.

`timescale 1ns / 1ps

module tb_deadlock_regression;

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

    logic [31:0] instr_mem [0:255];
    assign code_data = instr_mem[code_addr[9:2]];

    logic [31:0] data_mem [0:1023];
    assign data_rdata = data_mem[data_addr[13:2]];

    always_ff @(posedge clk) begin
        if (data_req && data_we) begin
            data_mem[data_addr[13:2]] <= data_wdata;
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

    initial begin
        // Test 1: Self-reading ALU instruction (rs1 == rd)
        // ADD x5, x5, x6 — reads x5 and writes x5
        // x5 starts at 0, x6 = 10
        // x5 = x5 + x6 = 0 + 10 = 10
        // Then ADD x5, x5, x6 again: x5 = 10 + 10 = 20
        instr_mem[0]  = 32'h00a00313; // ADDI x6, x0, 10
        instr_mem[1]  = 32'h006282b3; // ADD x5, x5, x6  (rs1=x5, rd=x5 — deadlock trigger)
        instr_mem[2]  = 32'h006282b3; // ADD x5, x5, x6  (again: x5 = 10+10 = 20)
        // Test 2: Self-reading with rs2 == rd
        // ADD x7, x6, x7 — reads x7 and writes x7
        // x7 starts at 0, x6 = 10
        // x7 = x6 + x7 = 10 + 0 = 10
        instr_mem[3]  = 32'h007303b3; // ADD x7, x6, x7  (rs2=x7, rd=x7 — deadlock trigger)
        // Test 3: Self-reading with rs1 == rs2 == rd
        // ADD x8, x8, x8 — reads x8 twice and writes x8
        // x8 starts at 0, x8 = 0 + 0 = 0
        instr_mem[4]  = 32'h00840433; // ADD x8, x8, x8  (rs1=x8, rs2=x8, rd=x8 — triple trigger)
        // Test 4: SUB self-read
        // SUB x9, x0, x9 — reads x9 and writes x9
        // x9 starts at 0, x9 = 0 - 0 = 0
        instr_mem[5]  = 32'h409004b3; // SUB x9, x0, x9
        // Test 5: AND self-read
        // x10 starts at 0, x10 = 0 & 10 = 0
        instr_mem[6]  = 32'h00a57533; // AND x10, x10, x6  (rs1=x10, rd=x10)
        // Test 6: OR self-read
        // x10 = 0 | 10 = 10
        instr_mem[7]  = 32'h00a56533; // OR x10, x10, x6   (rs1=x10, rd=x10)
        // Test 7: XOR self-read
        // x10 = 10 ^ 10 = 0
        instr_mem[8]  = 32'h00a54533; // XOR x10, x10, x6  (rs1=x10, rd=x10)
        // EBREAK
        instr_mem[9]  = 32'h00100073;

        rst_n = 0;
        cycle_count = 0;
        errors = 0;
        test_done = 0;

        #25;
        rst_n = 1;

        while (!test_done && cycle_count < 100) begin
            @(posedge clk);
            cycle_count++;

            if (code_data == 32'h00100073 && code_req) begin
                @(posedge clk);
                @(posedge clk);
                test_done = 1;
            end
        end

        $display("\n=== Deadlock Regression Test ===");
        $display("Cycles executed: %0d", cycle_count);

        if (!test_done) begin
            $display("  FAIL: Simulation deadlocked (timeout)");
            errors++;
        end else begin
            check_reg("x5",  32'd20);  // 0+10=10, 10+10=20
            check_reg("x6",  32'd10);
            check_reg("x7",  32'd10);  // 10+0=10
            check_reg("x8",  32'd0);   // 0+0=0
            check_reg("x9",  32'd0);   // 0-0=0
            check_reg("x10", 32'd0);   // 0&10=0, 0|10=10, 10^10=0
        end

        $display("\n=== Test Summary ===");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("FAILURES: %0d", errors);
        $display("====================\n");

        $finish;
    end

    initial begin
        #1000000;
        if (!test_done) begin
            $display("TIMEOUT");
            $finish;
        end
    end

endmodule
