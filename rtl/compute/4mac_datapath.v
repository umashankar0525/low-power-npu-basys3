`timescale 1ns / 1ps

module four_mac_datapath (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
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
    output reg         done,
    output reg signed [31:0] result
);

    reg [2:0] cycle;
    reg signed [17:0] s0;
    reg signed [17:0] s1;
    reg signed [18:0] t;
    reg signed [15:0] p8;

    reg signed [15:0] p0;
    reg signed [15:0] p1;
    reg signed [15:0] p2;
    reg signed [15:0] p3;
    reg signed [15:0] p4;
    reg signed [15:0] p5;
    reg signed [15:0] p6;
    reg signed [15:0] p7;

    reg signed [16:0] sum01;
    reg signed [16:0] sum23;
    reg signed [16:0] sum45;
    reg signed [16:0] sum67;

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
                p0    <= activation0 * weight0;
                p1    <= activation1 * weight1;
                p2    <= activation2 * weight2;
                p3    <= activation3 * weight3;
                sum01 <= (activation0 * weight0) + (activation1 * weight1);
                sum23 <= (activation2 * weight2) + (activation3 * weight3);
                s0    <= ((activation0 * weight0) + (activation1 * weight1)) +
                         ((activation2 * weight2) + (activation3 * weight3));
                cycle <= 3'd1;
            end else if (cycle == 3'd1) begin
                p4    <= activation4 * weight4;
                p5    <= activation5 * weight5;
                p6    <= activation6 * weight6;
                p7    <= activation7 * weight7;
                sum45 <= (activation4 * weight4) + (activation5 * weight5);
                sum67 <= (activation6 * weight6) + (activation7 * weight7);
                s1    <= ((activation4 * weight4) + (activation5 * weight5)) +
                         ((activation6 * weight6) + (activation7 * weight7));
                cycle <= 3'd2;
            end else if (cycle == 3'd2) begin
                p8    <= activation8 * weight8;
                t     <= $signed(s0) + $signed(s1);
                cycle <= 3'd3;
            end else if (cycle == 3'd3) begin
                result <= $signed(t) + $signed(p8);
                done   <= 1'b1;
                cycle  <= 3'd0;
            end
        end
    end

endmodule
