`timescale 1ns/1ps

module tb_int8_arithmetic;

    reg signed [7:0]  activation_i;
    reg signed [7:0]  weight_i;
    wire signed [15:0] product_o;
    wire signed [31:0] product_ext_o;

    integer a;
    integer w;
    integer total_tests;
    integer errors;
    integer expected_product;
    reg signed [15:0] expected_product_16;
    reg signed [31:0] expected_product_32;

    int8_arithmetic dut (
        .activation_i(activation_i),
        .weight_i(weight_i),
        .product_o(product_o),
        .product_ext_o(product_ext_o)
    );

    initial begin
        total_tests = 0;
        errors = 0;
        activation_i = 0;
        weight_i = 0;

        for (a = -128; a <= 127; a = a + 1) begin
            for (w = -128; w <= 127; w = w + 1) begin
                activation_i = a;
                weight_i = w;
                #1;

                expected_product = a * w;
                expected_product_16 = expected_product;
                expected_product_32 = expected_product;
                total_tests = total_tests + 1;

                if (product_o !== expected_product_16) begin
                    $display("PRODUCT ERROR: a=%0d w=%0d expected=%0d observed=%0d", a, w, expected_product_16, product_o);
                    errors = errors + 1;
                end

                if (product_ext_o !== expected_product_32) begin
                    $display("EXTENSION ERROR: a=%0d w=%0d expected=%0d observed=%0d", a, w, expected_product_32, product_ext_o);
                    errors = errors + 1;
                end

                if (product_ext_o[31:16] !== {16{product_o[15]}}) begin
                    $display("SIGN EXTENSION ERROR: a=%0d w=%0d product=%0d ext=%0d", a, w, product_o, product_ext_o);
                    errors = errors + 1;
                end
            end
        end

        $display("----------------------------------------");
        $display("INT8 ARITHMETIC EXHAUSTIVE VERIFICATION");
        $display("Tests performed : %0d", total_tests);
        $display("Errors found    : %0d", errors);

        if (errors == 0) begin
            $display("RESULT          : PASS");
        end else begin
            $display("RESULT          : FAIL");
        end

        $display("----------------------------------------");
        $finish;
    end

endmodule
