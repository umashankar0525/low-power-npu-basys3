`timescale 1ns/1ps

module tb_int32_accumulator;

    reg clk;
    reg rst;
    reg en;
    reg signed [15:0] product_i;
    wire signed [31:0] accumulator_o;

    integer errors;
    integer checks;
    integer expected;
    integer i;

    int32_accumulator dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .product_i(product_i),
        .accumulator_o(accumulator_o)
    );

    always #5 clk = ~clk;

    task check_accumulator;
        input integer expected_value;
        begin
            checks = checks + 1;
            if (accumulator_o !== expected_value) begin
                $display("ACCUMULATOR ERROR: expected=%0d observed=%0d time=%0t", expected_value, accumulator_o, $time);
                errors = errors + 1;
            end
        end
    endtask

    task apply_product;
        input integer product_value;
        begin
            product_i = product_value;
            en = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        en = 1'b0;
        product_i = 16'sd0;
        errors = 0;
        checks = 0;
        expected = 0;

        // Reset test.
        @(posedge clk);
        #1;
        check_accumulator(0);

        // Positive accumulation: 100 + 200 + 300 = 600.
        rst = 1'b0;
        apply_product(100);
        expected = expected + 100;
        check_accumulator(expected);

        apply_product(200);
        expected = expected + 200;
        check_accumulator(expected);

        apply_product(300);
        expected = expected + 300;
        check_accumulator(expected);

        // Hold test: en=0 must preserve the previous value.
        en = 1'b0;
        product_i = -16'sd999;
        @(posedge clk);
        #1;
        check_accumulator(expected);

        // Mixed signed accumulation: 600 - 200 = 400.
        apply_product(-200);
        expected = expected - 200;
        check_accumulator(expected);

        // Reset during operation.
        rst = 1'b1;
        en = 1'b1;
        product_i = 16'sd1234;
        @(posedge clk);
        #1;
        expected = 0;
        check_accumulator(expected);
        rst = 1'b0;

        // Nine maximum positive products: 9 * 16384 = 147456.
        expected = 0;
        for (i = 0; i < 9; i = i + 1) begin
            apply_product(16384);
            expected = expected + 16384;
            check_accumulator(expected);
        end
        check_accumulator(147456);

        // Reset before negative boundary test.
        rst = 1'b1;
        en = 1'b0;
        @(posedge clk);
        #1;
        expected = 0;
        check_accumulator(expected);
        rst = 1'b0;

        // Nine maximum negative products: 9 * -16256 = -146304.
        expected = 0;
        for (i = 0; i < 9; i = i + 1) begin
            apply_product(-16256);
            expected = expected - 16256;
            check_accumulator(expected);
        end
        check_accumulator(-146304);

        $display("----------------------------------------");
        $display("INT32 ACCUMULATOR VERIFICATION");
        $display("Checks performed : %0d", checks);
        $display("Errors found     : %0d", errors);

        if (errors == 0) begin
            $display("RESULT           : PASS");
        end
        else begin
            $display("RESULT           : FAIL");
        end

        $display("----------------------------------------");
        $finish;
    end

endmodule
