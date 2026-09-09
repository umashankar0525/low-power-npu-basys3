// -----------------------------------------------------------------------------
// Module: relu_activation
// Purpose: INT32 ReLU followed by saturating conversion to signed INT8.
//
// Architectural latency: 0 clock cycles (purely combinational).
// Clock: Not used by this module.
//
// Behavior:
//   x < 0       -> 0
//   0 <= x <=127 -> x[7:0]
//   x > 127     -> 127
//
// Assumption: input_acc is the completed signed INT32 accumulator result.
// The output is signed INT8 and is valid combinationally after propagation
// through the comparison/multiplexer logic.
// -----------------------------------------------------------------------------
module relu_activation (
    input  signed [31:0] input_acc,
    output reg signed [7:0] output_act
);

    always @(*) begin
        // ReLU: negative INT32 values become zero.
        if (input_acc[31] == 1'b1) begin
            output_act = 8'sd0;
        end
        // Saturation: after ReLU, any value with a bit above bit 6 set
        // is greater than the maximum signed INT8 value (+127).
        else if (input_acc[31:7] != 25'd0) begin
            output_act = 8'sd127;
        end
        // Remaining non-negative values are exactly representable in INT8.
        else begin
            output_act = input_acc[7:0];
        end
    end

endmodule
