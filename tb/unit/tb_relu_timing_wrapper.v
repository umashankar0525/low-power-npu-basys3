`timescale 1ns / 1ps

// Testbench: tb_relu_timing_wrapper
// Purpose: Verify reset, one-cycle latency, ReLU+saturation, and back-to-back alignment.
// Assumptions: 100 MHz clock (10 ns period), synchronous active-high reset.
module tb_relu_timing_wrapper;
    reg clk;
    reg rst;
    reg signed [31:0] accumulator_input;
    wire signed [7:0] output_activation;

    integer pass_count;
    integer fail_count;
    integer i;
    reg signed [31:0] random_value;

    relu_timing_wrapper dut (
        .clk                (clk),
        .rst                (rst),
        .accumulator_input  (accumulator_input),
        .output_activation  (output_activation)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function signed [7:0] expected_relu;
        input signed [31:0] value;
        begin
            if (value < 0)
                expected_relu = 8'sd0;
            else if (value > 127)
                expected_relu = 8'sd127;
            else
                expected_relu = value[7:0];
        end
    endfunction

    task check_output;
        input signed [31:0] expected_input;
        reg signed [7:0] expected_value;
        begin
            expected_value = expected_relu(expected_input);
            if (output_activation === expected_value) begin
                pass_count = pass_count + 1;
                $display("PASS: t=%0t input=%0d output=%0d expected=%0d",
                         $time, expected_input, output_activation, expected_value);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: t=%0t input=%0d output=%0d expected=%0d",
                         $time, expected_input, output_activation, expected_value);
            end
        end
    endtask

    // Apply input before edge N; verify its result after edge N+1.
    task apply_and_check_one_cycle;
        input signed [31:0] test_value;
        begin
            accumulator_input = test_value;
            @(posedge clk);
            @(posedge clk);
            #1;
            check_output(test_value);
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst = 1'b1;
        accumulator_input = 32'sd0;

        @(posedge clk);
        #1;
        if (output_activation === 8'sd0 && dut.accumulator_reg === 32'sd0) begin
            pass_count = pass_count + 1;
            $display("PASS: synchronous reset cleared accumulator and output");
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: synchronous reset did not clear accumulator/output");
        end
        rst = 1'b0;

        // Directed one-cycle-latency tests.
        apply_and_check_one_cycle(-32'sh80000000);
        apply_and_check_one_cycle(-32'sd1);
        apply_and_check_one_cycle(32'sd0);
        apply_and_check_one_cycle(32'sd1);
        apply_and_check_one_cycle(32'sd127);
        apply_and_check_one_cycle(32'sd128);
        apply_and_check_one_cycle(32'sd130);
        apply_and_check_one_cycle(32'sh7fffffff);

        // Back-to-back pipeline alignment.
        accumulator_input = -32'sd25;
        @(posedge clk);
        accumulator_input = 32'sd42;
        @(posedge clk);
        #1;
        check_output(-32'sd25);

        accumulator_input = 32'sd200;
        @(posedge clk);
        #1;
        check_output(32'sd42);

        accumulator_input = 32'sd100;
        @(posedge clk);
        #1;
        check_output(32'sd200);

        @(posedge clk);
        #1;
        check_output(32'sd100);

        // 100 randomized INT32 tests; each is checked one cycle later.
        for (i = 0; i < 100; i = i + 1) begin
            random_value = $random;
            accumulator_input = random_value;
            @(posedge clk);
            @(posedge clk);
            #1;
            check_output(random_value);
        end

        if (fail_count == 0)
            $display("PASS: relu_timing_wrapper verification completed with %0d passes and %0d failures.",
                     pass_count, fail_count);
        else
            $display("FAIL: relu_timing_wrapper verification completed with %0d passes and %0d failures.",
                     pass_count, fail_count);

        $finish;
    end
endmodule
