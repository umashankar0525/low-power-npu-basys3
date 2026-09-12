`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: control_fsm
// Purpose: Supervisory controller for the convolution engine and activation
//          capture stage.
//
// Architectural role:
//   - Accept one external start request while idle.
//   - Generate one-cycle engine_start pulse.
//   - Wait for the existing memory_interface_dataflow engine to finish.
//   - Request one-cycle capture of the combinational ReLU result.
//   - Generate one-cycle done pulse.
//   - Keep busy high until the controller returns to IDLE.
//
// Assumptions:
//   - Clock: 100 MHz.
//   - Reset: synchronous, active high.
//   - start is a one-cycle pulse and is legal only when busy == 0.
//   - engine_done is a one-cycle pulse from the existing convolution engine.
//   - Arithmetic data does not pass through this module.
// -----------------------------------------------------------------------------
module control_fsm (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire engine_done,

    output reg  engine_start,
    output reg  capture_activation,
    output reg  busy,
    output reg  done
);

    // Five states require at least three binary state bits:
    // ceil(log2(5)) = 3.
    localparam [2:0] ST_IDLE               = 3'd0;
    localparam [2:0] ST_LAUNCH             = 3'd1;
    localparam [2:0] ST_WAIT_ENGINE        = 3'd2;
    localparam [2:0] ST_CAPTURE_ACTIVATION = 3'd3;
    localparam [2:0] ST_DONE               = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // State register.
    always @(posedge clk) begin
        if (rst)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    // Next-state logic.
    always @(*) begin
        next_state = state;

        case (state)
            ST_IDLE: begin
                if (start)
                    next_state = ST_LAUNCH;
            end

            ST_LAUNCH: begin
                next_state = ST_WAIT_ENGINE;
            end

            ST_WAIT_ENGINE: begin
                if (engine_done)
                    next_state = ST_CAPTURE_ACTIVATION;
            end

            ST_CAPTURE_ACTIVATION: begin
                next_state = ST_DONE;
            end

            ST_DONE: begin
                next_state = ST_IDLE;
            end

            default: begin
                next_state = ST_IDLE;
            end
        endcase
    end

    // Moore-style output decode.
    // Outputs depend only on the current state.
    always @(*) begin
        engine_start       = 1'b0;
        capture_activation = 1'b0;
        busy               = 1'b0;
        done               = 1'b0;

        case (state)
            ST_IDLE: begin
                // Ready for a new transaction.
            end

            ST_LAUNCH: begin
                engine_start = 1'b1;
                busy         = 1'b1;
            end

            ST_WAIT_ENGINE: begin
                busy = 1'b1;
            end

            ST_CAPTURE_ACTIVATION: begin
                capture_activation = 1'b1;
                busy               = 1'b1;
            end

            ST_DONE: begin
                // done is a one-cycle pulse, but busy remains high so that
                // external logic cannot issue a new start until IDLE.
                busy = 1'b1;
                done = 1'b1;
            end

            default: begin
                // Safe output defaults are already assigned above.
            end
        endcase
    end

endmodule
