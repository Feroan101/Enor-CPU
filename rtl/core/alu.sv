// ENOR-CPU ALU
// combinational logic for all ALU operations
// Uses if-else instead of case to work around Icarus Verilog 12.0
// "sorry: constant selects in always_* processes" bug

module alu (
    input  logic [31:0] op_a,
    input  logic [31:0] op_b,
    input  logic [ 3:0] alu_op,
    output logic [31:0] result,
    output logic        zero,
    output logic        negative,
    output logic        carry,
    output logic        overflow
);

    logic [32:0] sum;
    logic [31:0] diff;
    logic        slt_result;
    logic        sltu_result;

    assign sum = {1'b0, op_a} + {1'b0, op_b};
    assign diff = op_a - op_b;
    assign slt_result = ($signed(op_a) < $signed(op_b)) ? 1'b1 : 1'b0;
    assign sltu_result = (op_a < op_b) ? 1'b1 : 1'b0;

    always_comb begin
        if (alu_op == 4'b0000)
            result = sum[31:0];
        else if (alu_op == 4'b0001)
            result = diff;
        else if (alu_op == 4'b0010)
            result = op_a & op_b;
        else if (alu_op == 4'b0011)
            result = op_a | op_b;
        else if (alu_op == 4'b0100)
            result = op_a ^ op_b;
        else if (alu_op == 4'b0101)
            result = op_a << op_b[4:0];
        else if (alu_op == 4'b0110)
            result = op_a >> op_b[4:0];
        else if (alu_op == 4'b0111)
            result = $unsigned($signed(op_a) >>> op_b[4:0]);
        else if (alu_op == 4'b1000)
            result = {31'b0, slt_result};
        else if (alu_op == 4'b1001)
            result = {31'b0, sltu_result};
        else if (alu_op == 4'b1010)
            result = op_b;
        else if (alu_op == 4'b1011)
            result = sum[31:0];
        else
            result = 32'b0;
    end

    assign zero     = (result == 32'b0);
    assign negative = result[31];
    assign carry    = sum[32];
    assign overflow = (op_a[31] == op_b[31]) && (result[31] != op_a[31]) && (alu_op == 4'b0000 || alu_op == 4'b0001);

endmodule
