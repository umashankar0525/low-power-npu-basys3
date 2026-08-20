`timescale 1ns / 1ps

module four_mac_datapath (
    input  wire               clk,
    input  wire               rst,
    input  wire               start,
    input  wire signed [7:0]  activation0,
    input  wire signed [7:0]  activation1,
    input  wire signed [7:0]  activation2,
    input  wire signed [7:0]  activation3,
    input  wire signed [7:0]  weight0,
    input  wire signed [7:0]  weight1,
    input  wire signed [7:0]  weight2,
    input  wire signed [7:0]  weight3,
    input  wire signed [7:0]  activation4,
    input  wire signed [7:0]  activation5,
    input  wire signed [7:0]  activation6,
    input  wire signed [7:0]  activation7,
    input  wire signed [7:0]  weight4,
    input  wire signed [7:0]  weight5,
    input  wire signed [7:0]  weight6,
    input  wire signed [7:0]  weight7,
    input  wire signed [7:0]  activation8,
    input  wire signed [7:0]  weight8,
    output reg               done,
    output reg signed [31:0] result
);

    reg [2:0] cycle;
    reg signed [17:0] s0;
    reg signed [17:0] s1;
    reg signed [18:0] t;
    reg signed [15:0] p8;

    wire signed [15:0] a0 = {{8{activation0[7]}}, activation0};
    wire signed [15:0] a1 = {{8{activation1[7]}}, activation1};
    wire signed [15:0] a2 = {{8{activation2[7]}}, activation2};
    wire signed [15:0] a3 = {{8{activation3[7]}}, activation3};
    wire signed [15:0] a4 = {{8{activation4[7]}}, activation4};
    wire signed [15:0] a5 = {{8{activation5[7]}}, activation5};
    wire signed [15:0] a6 = {{8{activation6[7]}}, activation6};
    wire signed [15:0] a7 = {{8{activation7[7]}}, activation7};
    wire signed [15:0] a8 = {{8{activation8[7]}}, activation8};

    wire signed [15:0] w0 = {{8{weight0[7]}}, weight0};
    wire signed [15:0] w1 = {{8{weight1[7]}}, weight1};
    wire signed [15:0] w2 = {{8{weight2[7]}}, weight2};
    wire signed [15:0] w3 = {{8{weight3[7]}}, weight3};
    wire signed [15:0] w4 = {{8{weight4[7]}}, weight4};
    wire signed [15:0] w5 = {{8{weight5[7]}}, weight5};
    wire signed [15:0] w6 = {{8{weight6[7]}}, weight6};
    wire signed [15:0] w7 = {{8{weight7[7]}}, weight7};
    wire signed [15:0] w8 = {{8{weight8[7]}}, weight8};

    wire signed [15:0] p0 = a0 * w0;
    wire signed [15:0] p1 = a1 * w1;
    wire signed [15:0] p2 = a2 * w2;
    wire signed [15:0] p3 = a3 * w3;
    wire signed [15:0] p4 = a4 * w4;
    wire signed [15:0] p5 = a5 * w5;
    wire signed [15:0] p6 = a6 * w6;
    wire signed [15:0] p7 = a7 * w7;
    wire signed [15:0] p8_next = a8 * w8;

    wire signed [16:0] sum01 = {p0[15], p0} + {p1[15], p1};
    wire signed [16:0] sum23 = {p2[15], p2} + {p3[15], p3};
    wire signed [16:0] sum45 = {p4[15], p4} + {p5[15], p5};
    wire signed [16:0] sum67 = {p6[15], p6} + {p7[15], p7};

    wire signed [17:0] partial0 = {sum01[16], sum01} + {sum23[16], sum23};
    wire signed [17:0] partial1 = {sum45[16], sum45} + {sum67[16], sum67};

    always @(posedge clk) begin
        if (rst) begin
            cycle  <= 3'd0;
            s0     <= 18'sd0;
            s1     <= 18'sd0;
            t      <= 19'sd0;
            p8     <= 16'sd0;
            result <= 32'sd0;
            done   <= 1'b0;
        end else begin
            done <= 1'b0;

            if (start && (cycle == 3'd0)) begin
                s0    <= partial0;
                cycle <= 3'd1;
            end else if (cycle == 3'd1) begin
                s1    <= partial1;
                cycle <= 3'd2;
            end else if (cycle == 3'd2) begin
                p8    <= p8_next;
                t     <= {s0[17], s0} + {s1[17], s1};
                cycle <= 3'd3;
            end else if (cycle == 3'd3) begin
                result <= {{13{t[18]}}, t} + {{16{p8[15]}}, p8};
                done   <= 1'b1;
                cycle  <= 3'd0;
            end
        end
    end

endmodule
