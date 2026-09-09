// -----------------------------------------------------------------------------
// Testbench: tb_relu_activation
// Purpose: Unit verification of INT32 ReLU + saturating INT8 conversion.
//
// DUT is purely combinational, so this testbench intentionally has NO clock.
// A #1 delay is used only to allow combinational signals to settle in simulation;
// it is not a clock period and does not imply architectural latency.
//
// Verification method:
//   1. Apply an INT32 input.
//   2. Compute the expected result with an independent behavioral oracle.
//   3. Wait for combinational settling.
//   4. Compare DUT output with the oracle using case equality.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

module tb_relu_activation;

    reg signed [31:0] input_acc;
    wire signed [7:0] output_act;

    integer pass_count;
    integer fail_count;
    integer i;

    // Independent reference model.
    // This uses signed arithmetic comparisons rather than the DUT's bit tests.
    function signed [7:0] reference_relu_sat;
        input signed [31:0] x;
        begin
            if (x < 0)
                reference_relu_sat = 8'sd0;
            else if (x > 127)
                reference_relu_sat = 8'sd127;
            else
                reference_relu_sat = x[7:0];
        end
    endfunction

    task check_value;
        input signed [31:0] test_input;
        reg signed [7:0] expected;
        begin
            input_acc = test_input;
            expected = reference_relu_sat(test_input);

            // Simulation settling delay only; no clock is required.
            #1;

            if (output_act !== expected) begin
                $display("FAIL: input=%0d (0x%08h), expected=%0d (0x%02h), got=%0d (0x%02h)",
                         test_input, test_input, expected, expected,
                         output_act, output_act);
                fail_count = fail_count + 1;
            end
            else begin
                $display("PASS: input=%0d (0x%08h) -> output=%0d (0x%02h)",
                         test_input, test_input, output_act, output_act);
                pass_count = pass_count + 1;
            end
        end
    endtask

    relu_activation dut (
        .input_acc  (input_acc),
        .output_act (output_act)
    );

    initial begin
        pass_count = 0;
        fail_count = 0;
        input_acc  = 32'sd0;

        $display("------------------------------------------------------------");
        $display("ReLU activation unit test started");
        $display("No clock is used because the DUT is combinational.");
        $display("------------------------------------------------------------");

        // Negative values -> 0.
        check_value(-32'sd1);
        check_value(-32'sd128);
        check_value(-32'sd32768);
        check_value(32'sh80000000); // INT32 minimum

        // Exactly representable non-negative INT8 values.
        check_value(32'sd0);
        check_value(32'sd1);
        check_value(32'sd126);
        check_value(32'sd127);

        // Values above INT8 maximum -> saturation at +127.
        check_value(32'sd128);
        check_value(32'sd129);
        check_value(32'sd130);
        check_value(32'sd255);
        check_value(32'sh7fffffff); // INT32 maximum

        // Additional mixed/boundary values.
        check_value(-32'sd127);
        check_value(-32'sd129);
        check_value(32'sd64);
        check_value(32'sd100);

        // Deterministic random coverage across the full INT32 input space.
        for (i = 0; i < 100; i = i + 1) begin
            check_value($random);
        end

        $display("------------------------------------------------------------");
        $display("ReLU activation unit test complete");
        $display("PASS count = %0d", pass_count);
        $display("FAIL count = %0d", fail_count);
        $display("------------------------------------------------------------");

        if (fail_count == 0)
            $display("RESULT: ALL TESTS PASSED");
        else
            $display("RESULT: TESTS FAILED");

        $finish;
    end

endmodule
