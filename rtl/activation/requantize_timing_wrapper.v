`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: requantize_timing_wrapper
// Purpose: Create a synchronous register-to-register timing path around the
//          combinational fixed-point requantization + ReLU block.
//
// Timing structure:
//   accumulator_input
//       -> launch register
//       -> requantize_relu
//       -> capture register
//       -> output_activation
//
// Representative measurement parameters:
//   M_INT     = 13,421,773
//   FRAC_BITS = 27
//   M_hat     = 13,421,773 / 2^27 ~= 0.10000000149
//
// Assumptions:
//   - Target clock frequency: 100 MHz
//   - Target clock period: 10 ns
//   - Reset is synchronous and active high.
//   - The wrapper is measurement-only; it is not the final integrated NPU top.
//   - requantize_relu remains purely combinational.
//   - Valid architectural accumulator values still obey the Phase 6 bounded
//     generated-data contract.
//
// IMPORTANT RESOURCE NOTE:
//   The launch/capture registers belong to this timing-measurement wrapper.
//   They must not be reported as internal pipeline FFs of requantize_relu.
// -----------------------------------------------------------------------------
module requantize_timing_wrapper #(
    parameter [23:0] M_INT      = 24'd13421773,
    parameter integer FRAC_BITS = 27
)(
    input  wire               clk,
    input  wire               rst,
    input  wire signed [31:0] accumulator_input,
    output reg  signed [7:0]  output_activation
);

    // Launch register: models the completed convolution accumulator register.
    reg signed [31:0] accumulator_reg;

    // Combinational requantization result.
    wire signed [7:0] requantized_output;

    requantize_relu #(
        .M_INT(M_INT),
        .FRAC_BITS(FRAC_BITS)
    ) u_requantize (
        .acc_in(accumulator_reg),
        .q_out(requantized_output)
    );

    // Launch and capture registers create the timing path that static timing
    // analysis evaluates against the 10 ns clock constraint.
    always @(posedge clk) begin
        if (rst) begin
            accumulator_reg   <= 32'sd0;
            output_activation <= 8'sd0;
        end else begin
            accumulator_reg   <= accumulator_input;
            output_activation <= requantized_output;
        end
    end

endmodule
