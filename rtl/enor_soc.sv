// ENOR-CPU Top Level SoC
// Connects core with memories and basic peripherals

module enor_soc (
    input  logic        clk,
    input  logic        rst_n,

    // UART interface
    output logic        uart_tx,
    input  logic        uart_rx,

    // GPIO
    output logic [7:0]  gpio_out,
    input  logic [7:0]  gpio_in,

    // LEDs
    output logic [3:0]  led
);

    // Memory parameters
    localparam CODE_ADDR_WIDTH = 13; // 8KB
    localparam DATA_ADDR_WIDTH = 14; // 16KB

    // Code memory signals
    logic [31:0] code_addr;
    logic [31:0] code_data;
    logic        code_req;

    // Data memory signals
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;
    logic        data_req;
    logic        data_we;
    logic [ 1:0] data_size;

    // Data memory select
    logic        sel_data_ram;
    logic        sel_uart;
    logic        sel_gpio;

    // UART signals
    logic [7:0]  uart_rdata;
    logic        uart_ready;
    logic        uart_valid;

    // GPIO signals
    logic [7:0]  gpio_reg;

    // ==================== Core ====================
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

    // ==================== Code Memory ====================
    sram #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (CODE_ADDR_WIDTH)
    ) u_code_mem (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr_a  (code_addr[CODE_ADDR_WIDTH+1:2]),
        .wdata_a (32'b0),
        .rdata_a (code_data),
        .req_a   (code_req),
        .we_a    (1'b0),
        .be_a    (4'b1111)
    );

    // ==================== Data Memory Decode ====================
    always_comb begin
        sel_data_ram = 1'b0;
        sel_uart     = 1'b0;
        sel_gpio     = 1'b0;

        if (data_req) begin
            casez (data_addr[31:28])
                4'h4: sel_data_ram = 1'b1; // 0x40000000 - Data SRAM
                4'h8: begin
                    casez (data_addr[27:0])
                        28'h0000000: sel_uart = 1'b1; // UART data
                        28'h0000004: sel_uart = 1'b1; // UART status
                        28'h0000010: sel_gpio = 1'b1; // GPIO
                        default: sel_data_ram = 1'b1;
                    endcase
                end
                default: sel_data_ram = 1'b1;
            endcase
        end
    end

    // ==================== Data Memory ====================
    sram #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (DATA_ADDR_WIDTH)
    ) u_data_mem (
        .clk     (clk),
        .rst_n   (rst_n),
        .addr_a  (data_addr[DATA_ADDR_WIDTH+1:2]),
        .wdata_a (data_wdata),
        .rdata_a (data_rdata),
        .req_a   (sel_data_ram & data_req),
        .we_a    (data_we),
        .be_a    (4'b1111)
    );

    // ==================== UART ====================
    // Simplified UART for v0.1
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            uart_tx   <= 1'b1;
            gpio_reg  <= 8'b0;
        end else if (sel_uart & data_we) begin
            if (data_addr[2:0] == 3'h0) begin
                // UART data register - transmit byte
                uart_tx <= 1'b0; // Start bit placeholder
            end
        end
    end

    // UART receive placeholder
    assign uart_ready = 1'b1;
    assign uart_valid = 1'b0;

    // ==================== GPIO ====================
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_reg <= 8'b0;
        end else if (sel_gpio & data_we) begin
            gpio_reg <= data_wdata[7:0];
        end
    end

    assign gpio_out = gpio_reg;
    assign led = gpio_reg[3:0];

    // ==================== Data Mux ====================
    always_comb begin
        if (sel_uart) begin
            if (data_addr[2:0] == 3'h0) begin
                data_rdata = {24'b0, 8'h00}; // UART TX data
            end else begin
                data_rdata = {31'b0, uart_ready}; // UART status
            end
        end else if (sel_gpio) begin
            data_rdata = {24'b0, gpio_in};
        end else begin
            data_rdata = data_rdata; // From SRAM
        end
    end

endmodule
