`timescale 1ns / 1ps

module tb_4mac_datapath;

    reg clk;
    reg rst;
    reg start;

    reg signed [7:0] activation0, activation1, activation2, activation3;
    reg signed [7:0] weight0, weight1, weight2, weight3;
    reg signed [7:0] activation4, activation5, activation6, activation7;
    reg signed [7:0] weight4, weight5, weight6, weight7;
    reg signed [7:0] activation8, weight8;

    wire done;
    wire signed [31:0] result;

    integer expected;
    integer failures;

    four_mac_datapath dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .activation0(activation0), .activation1(activation1),
        .activation2(activation2), .activation3(activation3),
        .weight0(weight0), .weight1(weight1), .weight2(weight2), .weight3(weight3),
        .activation4(activation4), .activation5(activation5),
        .activation6(activation6), .activation7(activation7),
        .weight4(weight4), .weight5(weight5), .weight6(weight6), .weight7(weight7),
        .activation8(activation8), .weight8(weight8),
        .done(done), .result(result)
    );

    always #5 clk = ~clk;

    task run_case;
        input integer case_id;
        input integer a0, a1, a2, a3, a4, a5, a6, a7, a8;
        input integer w0, w1, w2, w3, w4, w5, w6, w7, w8;
        integer ref;
        begin
            activation0 = a0; activation1 = a1; activation2 = a2; activation3 = a3;
            weight0 = w0; weight1 = w1; weight2 = w2; weight3 = w3;
            activation4 = a4; activation5 = a5; activation6 = a6; activation7 = a7;
            weight4 = w4; weight5 = w5; weight6 = w6; weight7 = w7;
            activation8 = a8; weight8 = w8;

            ref = a0*w0 + a1*w1 + a2*w2 + a3*w3 +
                  a4*w4 + a5*w5 + a6*w6 + a7*w7 + a8*w8;
            expected = ref;

            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            repeat (3) begin
                @(negedge clk);
                if (done !== 1'b0) begin
                    $display("FAIL case %0d: done asserted too early at %0t", case_id, $time);
                    failures = failures + 1;
                end
            end

            @(negedge clk);
            if (done !== 1'b1) begin
                $display("FAIL case %0d: done not asserted at expected cycle", case_id);
                failures = failures + 1;
            end
            if ($signed(result) !== expected) begin
                $display("FAIL case %0d: expected %0d, got %0d", case_id, expected, $signed(result));
                failures = failures + 1;
            end else begin
                $display("PASS case %0d: result=%0d at %0t", case_id, $signed(result), $time);
            end

            @(negedge clk);
            if (done !== 1'b0) begin
                $display("FAIL case %0d: done did not return low", case_id);
                failures = failures + 1;
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        failures = 0;
        expected = 0;

        activation0=0; activation1=0; activation2=0; activation3=0;
        activation4=0; activation5=0; activation6=0; activation7=0; activation8=0;
        weight0=0; weight1=0; weight2=0; weight3=0;
        weight4=0; weight5=0; weight6=0; weight7=0; weight8=0;

        repeat (2) @(negedge clk);
        rst = 1'b0;

        run_case(1, 0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0);
        run_case(2, 2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,3);
        run_case(3, -2,-2,-2,-2,-2,-2,-2,-2,-2, 3,3,3,3,3,3,3,3,3);
        run_case(4, -2,-2,-2,-2,-2,-2,-2,-2,-2, -3,-3,-3,-3,-3,-3,-3,-3,-3);
        run_case(5, -128,-128,-128,-128,-128,-128,-128,-128,-128,
                    -128,-128,-128,-128,-128,-128,-128,-128,-128);
        run_case(6, 127,127,127,127,127,127,127,127,127,
                    -128,-128,-128,-128,-128,-128,-128,-128,-128);
        run_case(7, 1,-2,3,-4,5,-6,7,-8,9, -9,8,-7,6,-5,4,-3,2,-1);

        if (failures == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TESTS FAILED: %0d failures", failures);

        $finish;
    end

endmodule
