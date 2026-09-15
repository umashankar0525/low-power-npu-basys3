`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: convolution_integration
// Phase:  Phase 7 — Convolution Integration and End-to-End Dataflow
// Purpose:
//   Integrate the existing supervisory controller, 3x3 memory/dataflow engine,
//   timing-refined requantizer, and one architectural INT8 output register.
//
// Architectural contract:
//   external start
//     -> control_fsm
//     -> memory_interface_dataflow
//     -> signed INT32 result
//     -> requantize_relu_pipelined
//     -> registered INT8 activation_out
//     -> external done
//
// Assumptions:
//   - 100 MHz system clock in the target design.
//   - Synchronous active-high reset.
//   - start is a one-cycle pulse and is legal only when busy == 0.
//   - Activation and weight memories have one clock of read latency.
//   - Memory words pack four signed INT8 lanes in little-lane order:
//       lane0 -> [7:0], lane1 -> [15:8], lane2 -> [23:16], lane3 -> [31:24].
//   - Word 2 contains convolution element 8 in lane 0 and zero padding in
//     lanes 1..3.
//   - M_INT is a 24-bit unsigned compile-time requantization coefficient.
//   - FRAC_BITS is a compile-time value in the verified range 0..42.
//
// Important timing relationship:
//   E5: engine registers final INT32 result and engine_done
//   E6: requantizer product_reg captures product from that final result
//   E7: activation_out captures rounded/shifted/saturated q_out; controller
//       enters DONE, so external done is asserted with activation_out valid.
//
// This module intentionally does NOT instantiate physical BRAM or board I/O.
// Those are left to later platform-level integration.
// -----------------------------------------------------------------------------
module convolution_integration #(
    parameter [23:0] M_INT      = 24'd1,
    parameter integer FRAC_BITS = 0
)(
    input  wire              clk,
    input  wire              rst,
    input  wire              start,

    output wire              busy,
    output wire              done,

    output wire              activation_rd_en,
    output wire [1:0]        activation_addr,
    input  wire [31:0]       activation_data,

    output wire              weight_rd_en,
    output wire [1:0]        weight_addr,
    input  wire [31:0]       weight_data,

    output reg signed [7:0]  activation_out
);

    // -------------------------------------------------------------------------
    // Internal control and datapath signals
    // -------------------------------------------------------------------------
    wire               engine_start;
    wire               engine_done;
    wire               capture_activation;
    wire signed [31:0] engine_result;
    wire signed [7:0]  requantized_q;

    // -------------------------------------------------------------------------
    // Supervisory controller
    // Owns transaction-level launch, wait, output-capture, busy, and done.
    // -------------------------------------------------------------------------
    control_fsm u_control_fsm (
        .clk                (clk),
        .rst                (rst),
        .start              (start),
        .engine_done        (engine_done),
        .engine_start       (engine_start),
        .capture_activation (capture_activation),
        .busy               (busy),
        .done               (done)
    );

    // -------------------------------------------------------------------------
    // Existing 3x3 convolution engine
    // Owns synchronous-memory sequencing, four-lane INT8 arithmetic,
    // reduction, and signed INT32 accumulation.
    // -------------------------------------------------------------------------
    memory_interface_dataflow u_memory_interface_dataflow (
        .clk                (clk),
        .rst                (rst),
        .start              (engine_start),

        .activation_rd_en   (activation_rd_en),
        .activation_addr    (activation_addr),
        .activation_data    (activation_data),

        .weight_rd_en       (weight_rd_en),
        .weight_addr        (weight_addr),
        .weight_data        (weight_data),

        .done               (engine_done),
        .result             (engine_result)
    );

    // -------------------------------------------------------------------------
    // Timing-refined ReLU + fixed-point requantization
    // The internal product register is intentionally left free-running because
    // the architectural output register below determines transaction validity.
    // -------------------------------------------------------------------------
    requantize_relu_pipelined #(
        .M_INT      (M_INT),
        .FRAC_BITS  (FRAC_BITS)
    ) u_requantize_relu_pipelined (
        .clk        (clk),
        .rst        (rst),
        .acc_in     (engine_result),
        .q_out      (requantized_q)
    );

    // -------------------------------------------------------------------------
    // Architectural transaction-result register
    // capture_activation is high during ST_CAPTURE_ACTIVATION. On the edge that
    // ends that state, q_out has had the full E6->E7 interval to settle from the
    // requantizer's registered product. After the same edge the controller is
    // in ST_DONE, so done=1 implies activation_out is already valid.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst)
            activation_out <= 8'sd0;
        else if (capture_activation)
            activation_out <= requantized_q;
    end

endmodule
