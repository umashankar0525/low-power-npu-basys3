`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: requantize_timing_wrapper
// Purpose: Characterize the timing-refined requantization datapath using a
//          synchronous launch register, one internal product pipeline register,
//          and a synchronous activation capture register.
//
// Timing structure:
//   accumulator_input
//       -> launch register
//       -> Stage 1: ReLU/sign gate + DSP multiply
//       -> 42-bit product pipeline register
//       -> Stage 2: rounding + shift + saturation
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
//   - Valid architectural accumulator values obey the Phase 6 bounded-data
//     contract.
//
// IMPORTANT RESOURCE NOTE:
//   accumulator_reg and output_activation are measurement-wrapper registers.
//   product_reg is the intentional timing-refinement register inside
//   requantize_relu_pipelined and must be accounted for separately.
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

    // Launch register: models the completed convolution result register.
    reg signed [31:0] accumulator_reg;

    // Stage-2 combinational output of the timing-refined requantizer.
    wire signed [7:0] requantized_output;

    requantize_relu_pipelined #(
        .M_INT(M_INT),
        .FRAC_BITS(FRAC_BITS)
    ) u_requantize (
        .clk   (clk),
        .rst   (rst),
        .acc_in(accumulator_reg),
        .q_out (requantized_output)
    );

    // The launch register represents S5 in the architectural schedule.
    // The internal product register captures the corresponding product at S6.
    // This output register then captures the rounded/saturated activation at S7.
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
