// ENOR-CPU SRAM Module
// Generic single-port or dual-port SRAM

module sram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 14,  // 16KB default
    parameter DEPTH      = 1 << ADDR_WIDTH
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Port A (read/write)
    input  logic [ADDR_WIDTH-1:0]  addr_a,
    input  logic [DATA_WIDTH-1:0]  wdata_a,
    output logic [DATA_WIDTH-1:0]  rdata_a,
    input  logic                    req_a,
    input  logic                    we_a,
    input  logic [DATA_WIDTH/8-1:0] be_a  // byte enable
);

    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Read/write logic
    always_ff @(posedge clk) begin
        if (req_a) begin
            if (we_a) begin
                for (int i = 0; i < DATA_WIDTH/8; i++) begin
                    if (be_a[i]) begin
                        mem[addr_a][i*8 +: 8] <= wdata_a[i*8 +: 8];
                    end
                end
            end
            rdata_a <= mem[addr_a];
        end
    end

    // Initialization
    initial begin
        for (int i = 0; i < DEPTH; i++) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end

endmodule
