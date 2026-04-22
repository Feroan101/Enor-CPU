// ENOR-CPU Matrix Accumulator
// M0: 8x8 matrix of INT32 values (memory-mapped at 0x80000000)

module matrix_regfile (
    input  logic        clk,
    input  logic        rst_n,

    // Read port
    input  logic [ 2:0] row_addr,
    input  logic [ 2:0] col_addr,
    output logic [31:0] read_data,

    // Write port
    input  logic [ 2:0] wr_row_addr,
    input  logic [ 2:0] wr_col_addr,
    input  logic [31:0] write_data,
    input  logic        write_en,

    // Clear
    input  logic        clear
);

    logic [31:0] matrix [0:7][0:7];

    // Read logic (combinational)
    assign read_data = matrix[row_addr][col_addr];

    // Write logic (clear and write can happen in same cycle)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    matrix[i][j] <= 32'b0;
                end
            end
        end else begin
            if (clear) begin
                for (int i = 0; i < 8; i++) begin
                    for (int j = 0; j < 8; j++) begin
                        matrix[i][j] <= 32'b0;
                    end
                end
            end
            if (write_en) begin
                matrix[wr_row_addr][wr_col_addr] <= write_data;
            end
        end
    end

endmodule
