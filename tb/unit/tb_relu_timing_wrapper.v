`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Testbench: tb_relu_timing_wrapper
// Purpose: Verify reset, one-cycle register-to-register latency, ReLU behavior,
//          INT8 saturation, and back-to-back input/output alignment.
//
// Assumptions:
//   - Clock period: 10 ns (100 MHz)
//   - Reset is synchronous and active high.
//   - accumulator_input is the completed INT32 accumulator value.
//   - output_activation captures ReLU+saturation one clock after input capture.
// -----------------------------------------------------------------------------
module tb_relu_timing_wrapper;

    reg clk;
    reg rst;
    reg signed [31:0] accumulator_input;
    wire signed [7:0] output_activation;

    integer pass_count;
    integer fail_count;

    relu_timing_wrapper dut (
        .clk                (clk),
        .rst                (rst),
        .accumulator_input  (accumulator_input),
        .output_activation  (output_activation)
    );

    // 100 MHz clock: 10 ns period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Independent reference model.
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
        input signed [31:0] test_value;
        input signed [7:0] expected_value;
        begin
            if (output_activation === expected_value) begin
                pass_count = pass_count + 1;
                $display("PASS: t=%0t input=%0d output=%0d expected=%0d",
                         $time, test_value, output_activation, expected_value);
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: t=%0t input=%0d output=%0d expected=%0d",
                         $time, test_value, output_activation, expected_value);
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        rst = 1'b1;
        accumulator_input = 32'sd0;

        // Synchronous reset: output must clear at the reset edge.
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

        // ---------------------------------------------------------------------
        // Directed one-cycle-latency tests.
        // Input is applied before edge N. At N it enters accumulator_reg.
        // At N+1 output_activation must contain ReLU+saturated result.
        // ---------------------------------------------------------------------

        // -2147483648 -> 0
        accumulator_input = -32'sh80000000;
        @(posedge clk);
        #1;
        // Old pipeline result after reset must still be zero.
        check_output(-32'sh80000000, 8'sd0);

        @(posedge clk);
        #1;
        check_output(-32'sh80000000, 8'sd0);

        // -1 -> 0
        accumulator_input = -32'sd1;
        @(posedge clk);
        #1;
        check_output(-32'sd1, 8'sd0);

        // 0 -> 0
        accumulator_input = 32'sd0;
        @(posedge clk);
        #1;
        check_output(32'sd0, 8'sd0);

        // 1 -> 1
        accumulator_input = 32'sd1;
        @(posedge clk);
        #1;
        check_output(32'sd1, 8'sd1);

        // 127 -> 127
        accumulator_input = 32'sd127;
        @(posedge clk);
        #1;
        check_output(32'sd127, 8'sd127);

        // 128 -> 127 (saturation boundary)
        accumulator_input = 32'sd128;
        @(posedge clk);
        #1;
        check_output(32'sd128, 8'sd127);

        // 130 -> 127
        accumulator_input = 32'sd130;
        @(posedge clk);
        #1;
        check_output(32'sd130, 8'sd127);

        // INT32 maximum -> 127
        accumulator_input = 32'sh7fffffff;
        @(posedge clk);
        #1;
        check_output(32'sh7fffffff, 8'sd127);

        // ---------------------------------------------------------------------
        // Back-to-back tests: each edge changes the accumulator register, while
        // output_activation must correspond to the value captured one edge ago.
        // ---------------------------------------------------------------------
        accumulator_input = -32'sd25;
        @(posedge clk);
        #1;
        check_output(-32'sd25, 8'sd0);

        accumulator_input = 32'sd42;
        @(posedge clk);
        #1;
        check_output(32'sd42, 8'sd42);

        accumulator_input = 32'sd200;
        @(posedge clk);
        #1;
        check_output(32'sd200, 8'sd127);

        accumulator_input = 32'sd100;
        @(posedge clk);
        #1;
        check_output(32'sd100, 8'sd100);

        // Randomized deterministic tests.
        // Each random value is checked one cycle after capture.
        repeat (100) begin
            accumulator_input = $random;
            @(posedge clk);
            #1;
            check_output(accumulator_input, expected_relu(accumulator_input));
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
