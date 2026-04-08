// ENOR-CPU Vector Register File
// 16 vector registers (v0-v15), each 256 bits (8 x 32-bit words)

module vector_regfile (
    input  logic        clk,
    input  logic        rst_n,

    // Read port 1
    input  logic [ 3:0] vs1_addr,
    output logic [255:0] vs1_data,

    // Read port 2
    input  logic [ 3:0] vs2_addr,
    output logic [255:0] vs2_data,

    // Write port
    input  logic [ 3:0] vd_addr,
    input  logic [255:0] vd_data,
    input  logic        vd_we,

    // Vector length
    input  logic [ 2:0] vl_in,
    output logic [ 2:0] vl_out
);

    logic [255:0] vregs [0:15];
    logic [ 2:0]  vl;

    assign vl_out = vl;

    // Vector length control
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vl <= 3'd7; // default VL = 8
        end else if (vd_we && vd_addr == 4'hF) begin
            // VSETVL writes to special register
            vl <= vl_in;
        end
    end

    // Write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                vregs[i] <= 256'b0;
            end
        end else if (vd_we) begin
            vregs[vd_addr] <= vd_data;
        end
    end

    // Read logic
    assign vs1_data = vregs[vs1_addr];
    assign vs2_data = vregs[vs2_addr];

endmodule
