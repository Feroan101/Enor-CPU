// ENOR-CPU Core Testbench

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

    // Simple instruction memory
    logic [31:0] instr_mem [0:255];

    assign code_data = instr_mem[code_addr[9:2]];

    // Simple data memory
    logic [31:0] data_mem [0:1023];

    assign data_rdata = data_mem[data_addr[11:2]];

    always_ff @(posedge clk) begin
        if (data_req && data_we) begin
            data_mem[data_addr[11:2]] <= data_wdata;
        end
    end

    // Test sequence
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;

        // Load test program
        // ADDI x5, x0, 10
        instr_mem[0] = 32'h00a00293;
        // ADDI x6, x0, 20
        instr_mem[1] = 32'h01400313;
        // ADD x7, x5, x6
        instr_mem[2] = 32'h006283b3;
        // SW x7, 0(x0)
        instr_mem[3] = 32'h00702023;
        // LW x8, 0(x0)
        instr_mem[4] = 32'h00002403;
        // EBREAK
        instr_mem[5] = 32'h00100073;

        // Run for enough cycles
        #200;

        // Check results
        $display("Test complete");
        $finish;
    end

    // Monitor
    initial begin
        $monitor("Time=%0t PC=%h Instr=%h", $time, code_addr, code_data);
    end

endmodule
