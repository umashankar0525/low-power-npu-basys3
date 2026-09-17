`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: basys3_top_level
// Phase:  Phase 8 — Basys 3 Top-Level Integration
// Purpose:
//   Wrap the verified convolution_integration accelerator core with Basys-3
//   platform services: button conditioning, internal operand memory, and
//   human-visible result/completion outputs.
//
// Approved architectural decisions:
//   - One 100 MHz clock domain.
//   - Start button: synchronize -> debounce -> rising pulse -> busy mask.
//   - Reset button: synchronize -> debounce -> synchronous core reset level.
//   - Operand memory preserves one-clock synchronous read behavior.
//   - Board bring-up uses M_INT=3 and FRAC_BITS=2.
//   - Expected nominal activation_out = 34 = 8'b0010_0010.
//   - Raw core done remains a one-cycle protocol event.
//   - done_latched is board observability only.
// -----------------------------------------------------------------------------
module basys3_top_level #(
    parameter integer DEBOUNCE_CYCLES = 1000000,
    parameter integer DEBOUNCE_WIDTH  = 20
)(
    input  wire       clk_100mhz,
    input  wire       btn_start,
    input  wire       btn_reset,

    output wire [7:0] led_result,
    output wire       led_done
);

    // -------------------------------------------------------------------------
    // Board input conditioning
    // -------------------------------------------------------------------------
    wire reset_level;
    wire reset_rise_unused;
    wire start_level_unused;
    wire start_rise;

    // Reset button conditioner has no external clear source because it creates
    // the clean reset level used by the rest of the board wrapper.
    button_conditioner #(
        .STABLE_CYCLES (DEBOUNCE_CYCLES),
        .COUNTER_WIDTH (DEBOUNCE_WIDTH)
    ) u_reset_conditioner (
        .clk        (clk_100mhz),
        .clear      (1'b0),
        .async_in   (btn_reset),
        .level      (reset_level),
        .rise_pulse (reset_rise_unused)
    );

    // Start conditioning is synchronously cleared while the clean reset level
    // is asserted so no stale press event can survive reset.
    button_conditioner #(
        .STABLE_CYCLES (DEBOUNCE_CYCLES),
        .COUNTER_WIDTH (DEBOUNCE_WIDTH)
    ) u_start_conditioner (
        .clk        (clk_100mhz),
        .clear      (reset_level),
        .async_in   (btn_start),
        .level      (start_level_unused),
        .rise_pulse (start_rise)
    );

    // -------------------------------------------------------------------------
    // Accelerator core / memory interface
    // -------------------------------------------------------------------------
    wire              core_busy;
    wire              core_done;
    wire              core_start;

    wire              activation_rd_en;
    wire [1:0]        activation_addr;
    wire [31:0]       activation_data;

    wire              weight_rd_en;
    wire [1:0]        weight_addr;
    wire [31:0]       weight_data;

    wire signed [7:0] core_activation_out;

    // A button press that arrives while busy is intentionally discarded rather
    // than queued, preserving the Phase-7 legal-start contract.
    assign core_start = start_rise & ~core_busy;

    operand_bram_dual_read u_operand_bram_dual_read (
        .clk              (clk_100mhz),
        .activation_rd_en (activation_rd_en),
        .activation_addr  (activation_addr),
        .activation_data  (activation_data),
        .weight_rd_en     (weight_rd_en),
        .weight_addr      (weight_addr),
        .weight_data      (weight_data)
    );

    convolution_integration #(
        .M_INT      (24'd3),
        .FRAC_BITS  (2)
    ) u_convolution_integration (
        .clk                (clk_100mhz),
        .rst                (reset_level),
        .start              (core_start),
        .busy               (core_busy),
        .done               (core_done),
        .activation_rd_en   (activation_rd_en),
        .activation_addr    (activation_addr),
        .activation_data    (activation_data),
        .weight_rd_en       (weight_rd_en),
        .weight_addr        (weight_addr),
        .weight_data        (weight_data),
        .activation_out     (core_activation_out)
    );

    // -------------------------------------------------------------------------
    // Human-visible completion status
    // -------------------------------------------------------------------------
    reg done_latched;

    initial begin
        done_latched = 1'b0;
    end

    always @(posedge clk_100mhz) begin
        if (reset_level)
            done_latched <= 1'b0;
        else if (core_start)
            done_latched <= 1'b0;
        else if (core_done)
            done_latched <= 1'b1;
    end

    // activation_out is already an architectural holding register in the core,
    // so no second result register is added at board level.
    assign led_result = core_activation_out[7:0];
    assign led_done   = done_latched;

endmodule
