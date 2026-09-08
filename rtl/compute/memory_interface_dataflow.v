`timescale 1ns / 1ps

// Memory/dataflow controller for one 3x3 INT8 convolution.
// Assumption: activation_data and weight_data are outputs of synchronous
// memories with one clock of read latency.
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

    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_WAIT0 = 3'd1;
    localparam [2:0] ST_WORD0 = 3'd2;
    localparam [2:0] ST_WORD1 = 3'd3;
    localparam [2:0] ST_WORD2 = 3'd4;

    reg [2:0] state;
    reg signed [31:0] accumulator;

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

    // Sign-extend the partial sum before INT32 accumulation.
    wire signed [31:0] partial_sum_ext = {{14{partial_sum[17]}},
                                           partial_sum};

    always @(posedge clk) begin
        if (rst) begin
            state            <= ST_IDLE;
            accumulator      <= 32'sd0;
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
                        activation_addr  <= 2'd0;
                        weight_addr      <= 2'd0;
                        activation_rd_en <= 1'b1;
                        weight_rd_en     <= 1'b1;
                        state            <= ST_WAIT0;
                    end
                end

                ST_WAIT0: begin
                    // The memories return word 0 after this edge.
                    // Simultaneously request word 1 for the next cycle.
                    activation_addr  <= 2'd1;
                    weight_addr      <= 2'd1;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;
                    state            <= ST_WORD0;
                end

                ST_WORD0: begin
                    // Word 0 is valid during this cycle.
                    // Capture S0 at the end of the cycle and request word 2.
                    accumulator      <= accumulator + partial_sum_ext;
                    activation_addr  <= 2'd2;
                    weight_addr      <= 2'd2;
                    activation_rd_en <= 1'b1;
                    weight_rd_en     <= 1'b1;
                    state            <= ST_WORD1;
                end

                ST_WORD1: begin
                    // Word 1 is valid during this cycle.
                    accumulator      <= accumulator + partial_sum_ext;
                    activation_rd_en <= 1'b0;
                    weight_rd_en     <= 1'b0;
                    state            <= ST_WORD2;
                end

                ST_WORD2: begin
                    // Word 2 contains P8 in lane 0 and zero-padded lanes 1..3.
                    // The new accumulator value is the final convolution result.
                    result <= accumulator + partial_sum_ext;
                    done   <= 1'b1;
                    state  <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
