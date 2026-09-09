`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: relu_timing_wrapper
// Purpose: Create a synchronous register-to-register timing path around the
//          combinational INT32 ReLU + INT8 saturation block.
//
// Timing structure:
//   accumulator_input -> accumulator register -> ReLU -> output register
//
// Assumptions:
//   - Clock frequency: 100 MHz
//   - Clock period: 10 ns
//   - Reset is synchronous and active high.
//   - accumulator_input represents the completed INT32 accumulator value.
//   - relu_activation remains purely combinational.
//
// The wrapper is a measurement structure. It does not add a pipeline register
// inside relu_activation itself.
// -----------------------------------------------------------------------------
module relu_timing_wrapper (
    input  wire               clk,
    input  wire               rst,
    input  wire signed [31:0] accumulator_input,
    output reg  signed [7:0]  output_activation
);

    // Launch register: represents the completed convolution accumulator.
    reg signed [31:0] accumulator_reg;

    // Combinational output of the existing ReLU + saturation module.
    wire signed [7:0] relu_output;

    relu_activation u_relu (
        .input_acc  (accumulator_reg),
        .output_act (relu_output)
    );

    // Register-to-register timing endpoint.
    always @(posedge clk) begin
        if (rst) begin
            accumulator_reg  <= 32'sd0;
            output_activation <= 8'sd0;
        end else begin
            accumulator_reg  <= accumulator_input;
            output_activation <= relu_output;
        end
    end

endmodule
