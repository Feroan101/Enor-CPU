// ENOR-CPU Register File
// 32 scalar registers (x0-x31), x0 hardwired to 0
// 2 read ports, 1 write port
// Includes bypass network for write-through forwarding

module register_file (
    input  logic        clk,
    input  logic        rst_n,

    // Read port 1
    input  logic [ 4:0] rs1_addr,
    output logic [31:0] rs1_data,

    // Read port 2
    input  logic [ 4:0] rs2_addr,
    output logic [31:0] rs2_data,

    // Write port
    input  logic [ 4:0] rd_addr,
    input  logic [31:0] rd_data,
    input  logic        rd_we
);

    logic [31:0] registers [0:31];

    // Write logic (x0 hardwired to 0)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 32; i++) begin
                registers[i] <= 32'b0;
            end
        end else if (rd_we && rd_addr != 5'b0) begin
            registers[rd_addr] <= rd_data;
        end
    end

    // Read logic with bypass (write-through forwarding)
    // If reading same register being written, forward the write data
    assign rs1_data = (rs1_addr == 5'b0) ? 32'b0 :
                      (rd_we && rs1_addr == rd_addr) ? rd_data :
                      registers[rs1_addr];

    assign rs2_data = (rs2_addr == 5'b0) ? 32'b0 :
                      (rd_we && rs2_addr == rd_addr) ? rd_data :
                      registers[rs2_addr];

endmodule
