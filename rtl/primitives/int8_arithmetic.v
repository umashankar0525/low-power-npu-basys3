// -----------------------------------------------------------------------------
// Module: int8_arithmetic
// Purpose: Signed INT8 x INT8 multiplication and INT16 -> INT32 sign extension.
// HDL: Verilog-2001
// -----------------------------------------------------------------------------

module int8_arithmetic (
    input  signed [7:0]  activation_i,
    input  signed [7:0]  weight_i,
    output signed [15:0] product_o,
    output signed [31:0] product_ext_o
);

    // Signed multiplication: INT8 x INT8 -> INT16.
    assign product_o = activation_i * weight_i;

    // Preserve the product's sign when widening from INT16 to INT32.
    assign product_ext_o = {{16{product_o[15]}}, product_o};

endmodule
