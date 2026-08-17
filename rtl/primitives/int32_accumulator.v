module int32_accumulator (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [15:0] product_i,
    output reg  signed [31:0] accumulator_o
);

    always @(posedge clk) begin
        if (rst) begin
            accumulator_o <= 32'sd0;
        end
        else if (en) begin
            accumulator_o <= accumulator_o + {{16{product_i[15]}}, product_i};
        end
    end

endmodule
