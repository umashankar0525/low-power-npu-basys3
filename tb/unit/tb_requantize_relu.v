`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Testbench: tb_requantize_relu
// Purpose:
//   Directed unit verification for rtl/activation/requantize_relu.v.
//
// Verification partitions:
//   A. Identity scaling       : ReLU + saturation
//   B. Half scaling           : positive round-to-nearest
//   C. Three-quarter scaling  : non-power-of-two fixed-point multiplication
//   D. Maximum-width case     : 18x24-bit multiply, 43-bit rounding path
//
// This DUT is combinational, so no clock is required. Each input change is
// followed by #1 to allow combinational signals to settle before checking.
//
// IMPORTANT:
//   Expected values are hand-derived from the documented numerical contract.
//   The testbench does not calculate expected values by duplicating the DUT
//   implementation expression.
// -----------------------------------------------------------------------------
module tb_requantize_relu;

    integer failures;

    // -------------------------------------------------------------------------
    // Configuration A: M = 1, F = 0
    // Isolates ReLU and saturation.
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_identity;
    wire signed [7:0]  q_identity;

    requantize_relu #(
        .M_INT(24'd1),
        .FRAC_BITS(0)
    ) dut_identity (
        .acc_in(acc_identity),
        .q_out(q_identity)
    );

    // -------------------------------------------------------------------------
    // Configuration B: M = 1/2
    // q_pre = (acc + 1) >> 1 for positive acc.
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_half;
    wire signed [7:0]  q_half;

    requantize_relu #(
        .M_INT(24'd1),
        .FRAC_BITS(1)
    ) dut_half (
        .acc_in(acc_half),
        .q_out(q_half)
    );

    // -------------------------------------------------------------------------
    // Configuration C: M = 3/4
    // Proves the datapath is doing multiply + shift, not only a power-of-two
    // shift approximation.
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_three_quarters;
    wire signed [7:0]  q_three_quarters;

    requantize_relu #(
        .M_INT(24'd3),
        .FRAC_BITS(2)
    ) dut_three_quarters (
        .acc_in(acc_three_quarters),
        .q_out(q_three_quarters)
    );

    // -------------------------------------------------------------------------
    // Configuration D: maximum legal Phase-6 width stress.
    // M_INT = 2^24 - 1, F = 42.
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_max;
    wire signed [7:0]  q_max;

    requantize_relu #(
        .M_INT(24'hFFFFFF),
        .FRAC_BITS(42)
    ) dut_max (
        .acc_in(acc_max),
        .q_out(q_max)
    );

    // -------------------------------------------------------------------------
    // Small helper tasks. Each task checks one fixed parameterization only.
    // Case equality is used so X/Z values fail the test.
    // -------------------------------------------------------------------------
    task check_identity;
        input [31:0] acc_value;
        input [7:0]  expected;
        begin
            acc_identity = acc_value;
            #1;
            if (q_identity !== expected) begin
                $display("FAIL identity: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected), $signed(q_identity));
                failures = failures + 1;
            end else begin
                $display("PASS identity: acc=%0d -> q=%0d",
                         $signed(acc_value), $signed(q_identity));
            end
        end
    endtask

    task check_half;
        input [31:0] acc_value;
        input [7:0]  expected;
        begin
            acc_half = acc_value;
            #1;
            if (q_half !== expected) begin
                $display("FAIL half: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected), $signed(q_half));
                failures = failures + 1;
            end else begin
                $display("PASS half: acc=%0d -> q=%0d",
                         $signed(acc_value), $signed(q_half));
            end
        end
    endtask

    task check_three_quarters;
        input [31:0] acc_value;
        input [7:0]  expected;
        begin
            acc_three_quarters = acc_value;
            #1;
            if (q_three_quarters !== expected) begin
                $display("FAIL 3/4: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected), $signed(q_three_quarters));
                failures = failures + 1;
            end else begin
                $display("PASS 3/4: acc=%0d -> q=%0d",
                         $signed(acc_value), $signed(q_three_quarters));
            end
        end
    endtask

    initial begin
        failures = 0;

        acc_identity       = 32'sd0;
        acc_half           = 32'sd0;
        acc_three_quarters = 32'sd0;
        acc_max            = 32'sd0;
        #1;

        $display("------------------------------------------------------------");
        $display("Configuration A: identity scaling / ReLU / saturation");
        $display("------------------------------------------------------------");

        check_identity(-32'sd1,      8'sd0);
        check_identity( 32'sd0,      8'sd0);
        check_identity( 32'sd1,      8'sd1);
        check_identity( 32'sd126,    8'sd126);
        check_identity( 32'sd127,    8'sd127);
        check_identity( 32'sd128,    8'sd127);
        check_identity( 32'sd145161, 8'sd127);

        // Signal-path checkpoint for a negative value.
        acc_identity = -32'sd1;
        #1;
        if (dut_identity.acc_positive !== 1'b0 ||
            dut_identity.acc_mag      !== 18'd0 ||
            q_identity                !== 8'sd0) begin
            $display("FAIL identity internal negative-path check");
            failures = failures + 1;
        end else begin
            $display("PASS identity internal negative-path check");
        end

        // Signal-path checkpoint immediately above the saturation boundary.
        acc_identity = 32'sd128;
        #1;
        if (dut_identity.acc_positive !== 1'b1 ||
            dut_identity.acc_mag      !== 18'd128 ||
            dut_identity.product      !== 42'd128 ||
            dut_identity.q_pre_wide   !== 43'd128 ||
            q_identity                !== 8'sd127) begin
            $display("FAIL identity internal saturation-path check");
            failures = failures + 1;
        end else begin
            $display("PASS identity internal saturation-path check");
        end

        $display("------------------------------------------------------------");
        $display("Configuration B: positive round-to-nearest, M = 1/2");
        $display("------------------------------------------------------------");

        check_half(32'sd1, 8'sd1); // 0.5 -> 1
        check_half(32'sd2, 8'sd1); // 1.0 -> 1
        check_half(32'sd3, 8'sd2); // 1.5 -> 2
        check_half(32'sd4, 8'sd2); // 2.0 -> 2

        // Explicit internal check for the 1.5 -> 2 half-step case.
        acc_half = 32'sd3;
        #1;
        if (dut_half.product     !== 42'd3 ||
            dut_half.rounded_num !== 43'd4 ||
            dut_half.q_pre_wide  !== 43'd2 ||
            q_half               !== 8'sd2) begin
            $display("FAIL half internal rounding-path check");
            failures = failures + 1;
        end else begin
            $display("PASS half internal rounding-path check");
        end

        $display("------------------------------------------------------------");
        $display("Configuration C: non-power-of-two multiplier, M = 3/4");
        $display("------------------------------------------------------------");

        check_three_quarters(32'sd1,   8'sd1);
        check_three_quarters(32'sd2,   8'sd2);
        check_three_quarters(32'sd3,   8'sd2);
        check_three_quarters(32'sd5,   8'sd4);
        check_three_quarters(32'sd169, 8'sd127);
        check_three_quarters(32'sd170, 8'sd127); // q_pre=128, then saturate

        // Internal checkpoint at the output saturation threshold.
        acc_three_quarters = 32'sd170;
        #1;
        if (dut_three_quarters.product     !== 42'd510 ||
            dut_three_quarters.rounded_num !== 43'd512 ||
            dut_three_quarters.q_pre_wide  !== 43'd128 ||
            q_three_quarters               !== 8'sd127) begin
            $display("FAIL 3/4 internal saturation-threshold check");
            failures = failures + 1;
        end else begin
            $display("PASS 3/4 internal saturation-threshold check");
        end

        $display("------------------------------------------------------------");
        $display("Configuration D: maximum-width arithmetic");
        $display("------------------------------------------------------------");

        acc_max = 32'sd145161;
        #1;

        if (dut_max.acc_positive !== 1'b1) begin
            $display("FAIL max: acc_positive expected 1 observed %b",
                     dut_max.acc_positive);
            failures = failures + 1;
        end else begin
            $display("PASS max: acc_positive = 1");
        end

        if (dut_max.acc_mag !== 18'd145161) begin
            $display("FAIL max: acc_mag expected 145161 observed %0d",
                     dut_max.acc_mag);
            failures = failures + 1;
        end else begin
            $display("PASS max: acc_mag = 145161");
        end

        if (dut_max.product !== 42'd2435397306615) begin
            $display("FAIL max: product expected 2435397306615 observed %0d",
                     dut_max.product);
            failures = failures + 1;
        end else begin
            $display("PASS max: 42-bit product = 2435397306615");
        end

        if (dut_max.rounded_num !== 43'd4634420562167) begin
            $display("FAIL max: rounded_num expected 4634420562167 observed %0d",
                     dut_max.rounded_num);
            failures = failures + 1;
        end else begin
            $display("PASS max: 43-bit rounded_num = 4634420562167");
        end

        if (dut_max.q_pre_wide !== 43'd1) begin
            $display("FAIL max: q_pre expected 1 observed %0d",
                     dut_max.q_pre_wide);
            failures = failures + 1;
        end else begin
            $display("PASS max: q_pre = 1 after >> 42");
        end

        if (q_max !== 8'sd1) begin
            $display("FAIL max: q_out expected 1 observed %0d", $signed(q_max));
            failures = failures + 1;
        end else begin
            $display("PASS max: q_out = 1");
        end

        $display("------------------------------------------------------------");
        if (failures == 0)
            $display("TB_REQUANTIZE_RELU_PASS: all directed checks passed");
        else
            $display("TB_REQUANTIZE_RELU_FAIL: %0d checks failed", failures);
        $display("------------------------------------------------------------");

        $finish;
    end

endmodule
