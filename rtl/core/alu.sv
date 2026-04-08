// ENOR-CPU ALU
// combinational logic for all ALU operations

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

    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLL  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111;
    localparam ALU_SLT  = 4'b1000;
    localparam ALU_SLTU = 4'b1001;
    localparam ALU_LUI  = 4'b1010;
    localparam ALU_AUIPC = 4'b1011;

    logic [32:0] sum;
    logic [31:0] diff;
    logic        slt_result;
    logic        sltu_result;

    assign sum = {1'b0, op_a} + {1'b0, op_b};
    assign diff = op_a - op_b;
    assign slt_result = ($signed(op_a) < $signed(op_b)) ? 1'b1 : 1'b0;
    assign sltu_result = (op_a < op_b) ? 1'b1 : 1'b0;

    always_comb begin
        case (alu_op)
            ALU_ADD:  result = sum[31:0];
            ALU_SUB:  result = diff;
            ALU_AND:  result = op_a & op_b;
            ALU_OR:   result = op_a | op_b;
            ALU_XOR:  result = op_a ^ op_b;
            ALU_SLL:  result = op_a << op_b[4:0];
            ALU_SRL:  result = op_a >> op_b[4:0];
            ALU_SRA:  result = $unsigned($signed(op_a) >>> op_b[4:0]);
            ALU_SLT:  result = {31'b0, slt_result};
            ALU_SLTU: result = {31'b0, sltu_result};
            ALU_LUI:  result = op_b;
            ALU_AUIPC: result = sum[31:0];
            default:  result = 32'b0;
        endcase
    end

    assign zero     = (result == 32'b0);
    assign negative = result[31];
    assign carry    = sum[32];
    assign overflow = (op_a[31] == op_b[31]) && (result[31] != op_a[31]) && (alu_op == ALU_ADD || alu_op == ALU_SUB);

endmodule
