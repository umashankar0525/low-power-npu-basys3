`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: operand_bram_dual_read
// Phase:  Phase 8 — Basys 3 Top-Level Integration
// Purpose:
//   Provide the activation and weight operands required by convolution_integration
//   from one logically shared, dual-read, synchronous memory structure.
//
// Architectural contract:
//   - 32-bit read words.
//   - One-clock synchronous read behavior.
//   - Activation and weight reads may occur in the same cycle.
//   - Activation logical addresses 0..2 map to physical addresses 0..2.
//   - Weight logical addresses 0..2 map to physical addresses 256..258.
//   - Initial board demonstration vector is fixed at configuration time.
//
// Packing order:
//   lane0 -> [7:0]
//   lane1 -> [15:8]
//   lane2 -> [23:16]
//   lane3 -> [31:24]
//
// BRAM note:
//   ram_style requests block-memory implementation, but actual BRAM inference
//   must still be confirmed from Vivado synthesis/utilization evidence.
// -----------------------------------------------------------------------------
module operand_bram_dual_read (
    input  wire        clk,

    input  wire        activation_rd_en,
    input  wire [1:0]  activation_addr,
    output reg  [31:0] activation_data,

    input  wire        weight_rd_en,
    input  wire [1:0]  weight_addr,
    output reg  [31:0] weight_data
);

    localparam integer MEM_DEPTH   = 512;
    localparam integer WEIGHT_BASE = 256;

    // 512 x 32 = 16384 bits, intentionally sized in the block-RAM range.
    // The two registered read ports model a true dual-read synchronous memory.
    (* ram_style = "block" *) reg [31:0] mem [0:MEM_DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1)
            mem[i] = 32'h00000000;

        // Activations [1,2,3,4,5,6,7,8,9].
        mem[0] = 32'h04030201;
        mem[1] = 32'h08070605;
        mem[2] = 32'h00000009;

        // Weights [1,1,1,1,1,1,1,1,1].
        mem[WEIGHT_BASE + 0] = 32'h01010101;
        mem[WEIGHT_BASE + 1] = 32'h01010101;
        mem[WEIGHT_BASE + 2] = 32'h00000001;

        activation_data = 32'h00000000;
        weight_data     = 32'h00000000;
    end

    // Synchronous activation read port.
    always @(posedge clk) begin
        if (activation_rd_en)
            activation_data <= mem[{7'b0000000, activation_addr}];
    end

    // Synchronous weight read port.
    always @(posedge clk) begin
        if (weight_rd_en)
            weight_data <= mem[WEIGHT_BASE + weight_addr];
    end

endmodule
