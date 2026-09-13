`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: requantize_relu
// Purpose: Convert one completed signed INT32 convolution accumulator into the
//          next signed-INT8 activation using ReLU, fixed-point requantization,
//          round-to-nearest, and saturation.
//
// Numerical contract:
//   S_acc = S_a * S_w
//   M     = S_acc / S_out
//   M ~= M_INT / 2^FRAC_BITS
//
// For acc_in > 0:
//   product = acc_in * M_INT
//   q_pre   = round(product / 2^FRAC_BITS)
//   q_out   = min(q_pre, 127)
//
// For acc_in <= 0:
//   q_out = 0
//
// Assumptions established in Phase 6 analysis:
//   - Normal generated INT8 operands are in [-127, +127].
//   - A 3x3 single-channel convolution therefore has positive magnitude
//     bounded by 145161 after ReLU.
//   - The valid positive accumulator magnitude therefore fits in 18 unsigned
//     bits. Inputs outside that numerical contract are not supported by this
//     baseline implementation.
//   - M_INT is a 24-bit unsigned layer constant.
//   - FRAC_BITS is a compile-time constant in the range 0..42.
//   - This module is combinational. Timing closure at 100 MHz must be measured
//     later; no physical timing claim is made here.
// -----------------------------------------------------------------------------
module requantize_relu #(
    parameter [23:0] M_INT     = 24'd1,
    parameter integer FRAC_BITS = 0
)(
    input  wire signed [31:0] acc_in,
    output reg  signed [7:0]  q_out
);

    // ReLU/sign gate. Multiplication by the positive requantization constant
    // cannot change sign, so non-positive accumulators can be forced to zero
    // before the multiplier.
    wire acc_positive = (~acc_in[31]) && (|acc_in);

    // Under the Phase 6 bounded-data contract, every valid positive result is
    // <= 145161 and therefore fits exactly in 18 unsigned bits.
    wire [17:0] acc_mag = acc_positive ? acc_in[17:0] : 18'd0;

    // 18-bit unsigned magnitude x 24-bit unsigned coefficient = 42-bit result.
    wire [41:0] product = acc_mag * M_INT;

    // One extra bit is reserved for a possible carry from the rounding bias.
    wire [42:0] product_ext = {1'b0, product};
    wire [42:0] rounded_num;
    wire [42:0] q_pre_wide;

    generate
        if (FRAC_BITS == 0) begin : gen_no_fractional_shift
            assign rounded_num = product_ext;
            assign q_pre_wide  = rounded_num;
        end else begin : gen_fractional_shift
            // Positive-only round-to-nearest:
            // floor((product + 2^(F-1)) / 2^F)
            wire [42:0] rounding_bias;
            assign rounding_bias = (43'd1 << (FRAC_BITS - 1));
            assign rounded_num   = product_ext + rounding_bias;
            assign q_pre_wide    = rounded_num >> FRAC_BITS;
        end
    endgenerate

    // Final output contract after ReLU is signed INT8 [0, 127].
    // Any bit at position 7 or above means the non-negative requantized value
    // exceeds 127 and must saturate.
    always @(*) begin
        if (!acc_positive)
            q_out = 8'sd0;
        else if (|q_pre_wide[42:7])
            q_out = 8'sd127;
        else
            q_out = $signed(q_pre_wide[7:0]);
    end

endmodule
