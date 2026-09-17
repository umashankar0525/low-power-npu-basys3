`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: button_conditioner
// Phase:  Phase 8 — Basys 3 Top-Level Integration
// Purpose:
//   Convert an asynchronous mechanical pushbutton into:
//     1) a synchronized/debounced level, and
//     2) a one-clock rising-edge pulse.
//
// Design contract:
//   - Single 100 MHz system clock domain.
//   - Two flip-flops are used for metastability-risk reduction.
//   - Input must disagree with the accepted level for STABLE_CYCLES
//     consecutive clocks before the debounced level changes.
//   - The counter is activity-driven: it holds at zero while the input and
//     accepted level agree.
//   - clear is synchronous and is used by the start-button instance after a
//     clean board reset has been established.
//
// FPGA note:
//   Xilinx 7-series configuration initializes flip-flops, so the initial block
//   provides a deterministic power-up state for the reset-button conditioner,
//   whose own clean reset level cannot logically reset itself.
// -----------------------------------------------------------------------------
module button_conditioner #(
    parameter integer STABLE_CYCLES = 1000000,
    parameter integer COUNTER_WIDTH = 20
)(
    input  wire clk,
    input  wire clear,
    input  wire async_in,
    output reg  level,
    output wire rise_pulse
);

    // Ask Vivado to treat the two synchronization registers as a CDC chain.
    (* ASYNC_REG = "TRUE" *) reg sync_ff1;
    (* ASYNC_REG = "TRUE" *) reg sync_ff2;

    reg [COUNTER_WIDTH-1:0] stable_count;
    reg                     level_d;

    localparam [COUNTER_WIDTH-1:0] TERMINAL_COUNT = STABLE_CYCLES - 1;

    initial begin
        sync_ff1    = 1'b0;
        sync_ff2    = 1'b0;
        stable_count = {COUNTER_WIDTH{1'b0}};
        level       = 1'b0;
        level_d     = 1'b0;
    end

    always @(posedge clk) begin
        if (clear) begin
            sync_ff1     <= 1'b0;
            sync_ff2     <= 1'b0;
            stable_count <= {COUNTER_WIDTH{1'b0}};
            level        <= 1'b0;
            level_d      <= 1'b0;
        end else begin
            // Two-stage synchronizer.
            sync_ff1 <= async_in;
            sync_ff2 <= sync_ff1;

            // Debounce only while the synchronized sample disagrees with the
            // currently accepted stable level.
            if (sync_ff2 == level) begin
                stable_count <= {COUNTER_WIDTH{1'b0}};
            end else if (stable_count == TERMINAL_COUNT) begin
                level        <= sync_ff2;
                stable_count <= {COUNTER_WIDTH{1'b0}};
            end else begin
                stable_count <= stable_count + {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
            end

            // Previous accepted level for edge detection.
            level_d <= level;
        end
    end

    assign rise_pulse = level & ~level_d;

endmodule
