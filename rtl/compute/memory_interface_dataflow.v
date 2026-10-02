`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: memory_interface_dataflow
// Phase:  Phase 8 — Basys 3 timing-closure refinement, Stage 2
// Purpose:
//   Sequence one 3x3 INT8 convolution over three packed activation/weight words.
//
// Stage-1 timing closure inserted partial_sum_pipe between the reduction tree
// and the INT32 accumulator.
//
// Stage-2 timing closure now inserts four registered INT16 products between the
// BRAM outputs and the reduction tree:
//
//   BRAM
//    -> four INT8xINT8 multipliers
//    -> product_pipe0..3
//    -> balanced reduction tree
//    -> partial_sum_pipe
//    -> INT32 accumulator add
//    -> accumulator
//
// This preserves the mathematical result and three-word memory traffic while
// adding one more pipeline-fill cycle.
//
// Assumptions:
//   - activation_data and weight_data are outputs of synchronous memories with
//     one clock of read latency.
//   - Exactly three packed operand words are consumed in fixed order 0,1,2.
//   - Word 2 contains the ninth operand in lane 0 and zero padding in lanes 1..3.
//   - Product precision is signed INT16.
//   - Accumulator precision is signed INT32.
// -----------------------------------------------------------------------------
module memory_interface_dataflow (
    input  wire              clk,
    input  wire              rst,
    input  wire              start,

    output reg               activation_rd_en,
    output reg  [1:0]        activation_addr,
    input  wire [31:0]       activation_data,

    output reg               weight_rd_en,
    output reg  [1:0]        weight_addr,
    input  wire [31:0]       weight_data,

    output reg               done,
    output reg signed [31:0] result
);

    // Seven states still fit in three state bits:
    // ceil(log2(7)) = 3.
    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_WAIT0 = 3'd1;
    localparam [2:0] ST_PROD0 = 3'd2;
    localparam [2:0] ST_PIPE0 = 3'd3;
    localparam [2:0] ST_WORD0 = 3'd4;
    localparam [2:0] ST_WORD1 = 3'd5;
    localparam [2:0] ST_WORD2 = 3'd6;

    reg [2:0] state;

    // Running INT32 accumulation.
    reg signed [31:0] accumulator;

    // Stage-2 product pipeline registers.
    reg signed [15:0] product_pipe0;
    reg signed [15:0] product_pipe1;
    reg signed [15:0] product_pipe2;
    reg signed [15:0] product_pipe3;

    // Stage-1 partial-sum pipeline register.
    reg signed [31:0] partial_sum_pipe;

    // Four packed signed INT8 activation lanes.
    wire signed [7:0] a0 = activation_data[7:0];
    wire signed [7:0] a1 = activation_data[15:8];
    wire signed [7:0] a2 = activation_data[23:16];
    wire signed [7:0] a3 = activation_data[31:24];

    // Four packed signed INT8 weight lanes.
    wire signed [7:0] w0 = weight_data[7:0];
    wire signed [7:0] w1 = weight_data[15:8];
    wire signed [7:0] w2 = weight_data[23:16];
    wire signed [7:0] w3 = weight_data[31:24];

    // Raw combinational INT8 x INT8 products.
    wire signed [15:0] p0 = a0 * w0;
    wire signed [15:0] p1 = a1 * w1;
    wire signed [15:0] p2 = a2 * w2;
    wire signed [15:0] p3 = a3 * w3;

    // Reduction tree now consumes registered products.
    // Balanced reduction: 16 -> 17 -> 18 bits.
    wire signed [16:0] sum01 =
        {product_pipe0[15], product_pipe0} +
        {product_pipe1[15], product_pipe1};

    wire signed [16:0] sum23 =
        {product_pipe2[15], product_pipe2} +
        {product_pipe3[15], product_pipe3};

    wire signed [17:0] partial_sum =
        {sum01[16], sum01} +
        {sum23[16], sum23};

    // Sign-extend the reduced word contribution to INT32 before registering it.
    wire signed [31:0] partial_sum_ext =
        {{14{partial_sum[17]}}, partial_sum};

    always @(posedge clk) begin
        if (rst) begin
            state            <= ST_IDLE;
            accumulator      <= 32'sd0;

            product_pipe0    <= 16'sd0;
            product_pipe1    <= 16'sd0;
            product_pipe2    <= 16'sd0;
            product_pipe3    <= 16'sd0;

            partial_sum_pipe <= 32'sd0;
            result           <= 32'sd0;
            done             <= 1'b0;

            activation_rd_en <= 1'b0;
            activation_addr  <= 2'd0;
            weight_rd_en     <= 1'b0;
            weight_addr      <= 2'd0;
        end else begin
            // done is a one-cycle pulse.
            done <= 1'b0;

            case (state)
                ST_IDLE: begin
                    activation_rd_en <= 1'b0;
                    weight_rd_en     <= 1'b0;

                    if (start) begin
                        accumulator      <= 32'sd0;

                        product_pipe0    <= 16'sd0;
                        product_pipe1    <= 16'sd0;
                        product_pipe2    <= 16'sd0;
                        product_pipe3    <= 16'sd0;

                        partial_sum_pipe <= 32'sd0;

                        // Request packed operand word 0.
                        activation_addr  <= 2'd0;
                        weight_addr      <= 2'd0;
                        activation_rd_en <= 1'b1;
                        weight_rd_en     <= 1'b1;

                        state <= ST_WAIT0;
                    end
                end

                ST_WAIT0: begin
                    // BRAM consumes the previous word-0 request on this edge.
                    // Request word 1 for the following BRAM access.
                    activation_addr  <= 2'd1;
                    weight_addr      <= 2'd1;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;

                    state <= ST_PROD0;
                end

                ST_PROD0: begin
                    // During this cycle the visible BRAM outputs are word 0.
                    // Register the four word-0 products.
                    product_pipe0 <= p0;
                    product_pipe1 <= p1;
                    product_pipe2 <= p2;
                    product_pipe3 <= p3;

                    // Request the final packed operand word.
                    activation_addr  <= 2'd2;
                    weight_addr      <= 2'd2;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;

                    state <= ST_PIPE0;
                end

                ST_PIPE0: begin
                    // Consume registered word-0 products to capture S0.
                    partial_sum_pipe <= partial_sum_ext;

                    // At this point the visible BRAM outputs are word 1.
                    // Refill the product pipeline with word-1 products.
                    product_pipe0 <= p0;
                    product_pipe1 <= p1;
                    product_pipe2 <= p2;
                    product_pipe3 <= p3;

                    // Word 2 has already been requested. No more reads are needed.
                    activation_rd_en <= 1'b0;
                    weight_rd_en     <= 1'b0;

                    state <= ST_WORD0;
                end

                ST_WORD0: begin
                    // Consume registered S0.
                    accumulator <= accumulator + partial_sum_pipe;

                    // Consume registered word-1 products to capture S1.
                    partial_sum_pipe <= partial_sum_ext;

                    // The BRAM outputs now hold word 2. Capture its products.
                    product_pipe0 <= p0;
                    product_pipe1 <= p1;
                    product_pipe2 <= p2;
                    product_pipe3 <= p3;

                    state <= ST_WORD1;
                end

                ST_WORD1: begin
                    // Consume registered S1.
                    accumulator <= accumulator + partial_sum_pipe;

                    // Consume registered word-2 products to capture S2.
                    partial_sum_pipe <= partial_sum_ext;

                    state <= ST_WORD2;
                end

                ST_WORD2: begin
                    // Consume registered S2 and publish the final convolution.
                    // Nonblocking assignment semantics use the prior accumulator:
                    // result = (S0 + S1) + S2.
                    result <= accumulator + partial_sum_pipe;
                    done   <= 1'b1;

                    state <= ST_IDLE;
                end

                default: begin
                    state            <= ST_IDLE;
                    activation_rd_en <= 1'b0;
                    weight_rd_en     <= 1'b0;
                end
            endcase
        end
    end

endmodule
