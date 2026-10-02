`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Module: memory_interface_dataflow
// Phase:  Phase 8 — Basys 3 timing-closure refinement
// Purpose:
//   Sequence one 3x3 INT8 convolution over three packed activation/weight words.
//
// Timing-closure refinement:
//   The original datapath allowed the BRAM output, four lane multiplications,
//   reduction tree, sign extension, and INT32 accumulator addition to all lie
//   on one register-to-register path.
//
//   This revision inserts one registered partial-sum pipeline boundary:
//
//       BRAM
//        -> four INT8xINT8 products
//        -> balanced reduction tree
//        -> sign extension
//        -> partial_sum_pipe
//        -> INT32 accumulator add
//        -> accumulator
//
//   Functional arithmetic is unchanged. The engine gains one pipeline-fill
//   cycle so control remains aligned with the registered partial sum.
//
// Assumptions:
//   - activation_data and weight_data are outputs of synchronous memories with
//     one clock of read latency.
//   - Exactly three packed operand words are consumed in fixed order 0,1,2.
//   - Word 2 uses lane 0 for the ninth operand and zero padding in lanes 1..3.
//   - Accumulator precision remains signed INT32.
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

    // Six states still fit in three state bits:
    // ceil(log2(6)) = 3.
    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_WAIT0 = 3'd1;
    localparam [2:0] ST_PIPE0 = 3'd2;
    localparam [2:0] ST_WORD0 = 3'd3;
    localparam [2:0] ST_WORD1 = 3'd4;
    localparam [2:0] ST_WORD2 = 3'd5;

    reg [2:0] state;

    // Running INT32 accumulation.
    reg signed [31:0] accumulator;

    // Timing-closure pipeline register.
    // Stores one fully reduced, sign-extended word contribution before the
    // INT32 accumulator addition.
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

    // Four INT8 x INT8 products. Product precision is INT16.
    wire signed [15:0] p0 = a0 * w0;
    wire signed [15:0] p1 = a1 * w1;
    wire signed [15:0] p2 = a2 * w2;
    wire signed [15:0] p3 = a3 * w3;

    // Balanced reduction tree: 16 -> 17 -> 18 bits.
    wire signed [16:0] sum01 = {p0[15], p0} + {p1[15], p1};
    wire signed [16:0] sum23 = {p2[15], p2} + {p3[15], p3};
    wire signed [17:0] partial_sum = {sum01[16], sum01} +
                                      {sum23[16], sum23};

    // Sign-extend the reduced word contribution to INT32 before registering it.
    wire signed [31:0] partial_sum_ext = {{14{partial_sum[17]}},
                                           partial_sum};

    always @(posedge clk) begin
        if (rst) begin
            state            <= ST_IDLE;
            accumulator      <= 32'sd0;
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
                        partial_sum_pipe <= 32'sd0;

                        // First packed activation/weight word.
                        activation_addr  <= 2'd0;
                        weight_addr      <= 2'd0;
                        activation_rd_en <= 1'b1;
                        weight_rd_en     <= 1'b1;

                        state <= ST_WAIT0;
                    end
                end

                ST_WAIT0: begin
                    // The synchronous BRAMs return word 0 after this edge.
                    // Keep the read stream moving by requesting word 1.
                    activation_addr  <= 2'd1;
                    weight_addr      <= 2'd1;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;

                    state <= ST_PIPE0;
                end

                ST_PIPE0: begin
                    // During this cycle the visible BRAM outputs correspond to
                    // word 0. Capture its fully reduced contribution into the
                    // new timing-closure pipeline register.
                    partial_sum_pipe <= partial_sum_ext;

                    // Request the third and final packed word.
                    activation_addr  <= 2'd2;
                    weight_addr      <= 2'd2;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;

                    state <= ST_WORD0;
                end

                ST_WORD0: begin
                    // Consume registered S0.
                    accumulator <= accumulator + partial_sum_pipe;

                    // The visible BRAM outputs now correspond to word 1.
                    // Pipeline S1 while the BRAM completes the word-2 request.
                    partial_sum_pipe <= partial_sum_ext;

                    // No more memory requests are required after word 2.
                    activation_rd_en <= 1'b0;
                    weight_rd_en     <= 1'b0;

                    state <= ST_WORD1;
                end

                ST_WORD1: begin
                    // Consume registered S1.
                    accumulator <= accumulator + partial_sum_pipe;

                    // The visible BRAM outputs now correspond to word 2.
                    // Pipeline S2 for final consumption on the next edge.
                    partial_sum_pipe <= partial_sum_ext;

                    state <= ST_WORD2;
                end

                ST_WORD2: begin
                    // Consume registered S2 and publish the final convolution
                    // result. Because nonblocking assignments use the previous
                    // accumulator value on this edge:
                    //
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
