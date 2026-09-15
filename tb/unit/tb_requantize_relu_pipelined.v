`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Testbench: tb_requantize_relu_pipelined
// Purpose:
//   Directed unit verification for rtl/activation/requantize_relu_pipelined.v.
//
// Verification partitions:
//   A. Synchronous reset
//   B. Identity scaling / ReLU / saturation
//   C. Positive round-to-nearest
//   D. Non-power-of-two fixed-point multiplication
//   E. Maximum-width arithmetic
//   F. Back-to-back pipeline sequencing
//
// Pipeline timing contract:
//   before edge N : acc_in is stable
//   at edge N     : product_reg captures acc_mag * M_INT
//   after edge N  : q_out becomes valid combinationally from product_reg
//
// IMPORTANT:
//   The old combinational #1-only strategy is not valid for this DUT because
//   the product stage is clocked. Every newly applied input is checked only
//   after a rising edge has captured its product.
// -----------------------------------------------------------------------------
module tb_requantize_relu_pipelined;

    reg clk;
    reg rst;
    integer failures;

    // 100 MHz clock => 10 ns period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Configuration A: M = 1, F = 0
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_identity;
    wire signed [7:0]  q_identity;

    requantize_relu_pipelined #(
        .M_INT(24'd1),
        .FRAC_BITS(0)
    ) dut_identity (
        .clk   (clk),
        .rst   (rst),
        .acc_in(acc_identity),
        .q_out (q_identity)
    );

    // -------------------------------------------------------------------------
    // Configuration B: M = 1/2
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_half;
    wire signed [7:0]  q_half;

    requantize_relu_pipelined #(
        .M_INT(24'd1),
        .FRAC_BITS(1)
    ) dut_half (
        .clk   (clk),
        .rst   (rst),
        .acc_in(acc_half),
        .q_out (q_half)
    );

    // -------------------------------------------------------------------------
    // Configuration C: M = 3/4
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_three_quarters;
    wire signed [7:0]  q_three_quarters;

    requantize_relu_pipelined #(
        .M_INT(24'd3),
        .FRAC_BITS(2)
    ) dut_three_quarters (
        .clk   (clk),
        .rst   (rst),
        .acc_in(acc_three_quarters),
        .q_out (q_three_quarters)
    );

    // -------------------------------------------------------------------------
    // Configuration D: maximum-width stress
    // -------------------------------------------------------------------------
    reg  signed [31:0] acc_max;
    wire signed [7:0]  q_max;

    requantize_relu_pipelined #(
        .M_INT(24'hFFFFFF),
        .FRAC_BITS(42)
    ) dut_max (
        .clk   (clk),
        .rst   (rst),
        .acc_in(acc_max),
        .q_out (q_max)
    );

    // -------------------------------------------------------------------------
    // Helper tasks. Inputs are driven on the falling edge so they are stable
    // before the next rising edge. Checks occur #1 after the rising edge so
    // nonblocking register updates and Stage-2 combinational logic can settle.
    // -------------------------------------------------------------------------
    task check_identity;
        input [31:0] acc_value;
        input [41:0] expected_product;
        input [7:0]  expected_q;
        begin
            @(negedge clk);
            acc_identity = acc_value;
            @(posedge clk);
            #1;

            if (dut_identity.product_reg !== expected_product) begin
                $display("FAIL identity product: acc=%0d expected_product=%0d observed=%0d",
                         $signed(acc_value), expected_product,
                         dut_identity.product_reg);
                failures = failures + 1;
            end

            if (q_identity !== expected_q) begin
                $display("FAIL identity q: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected_q),
                         $signed(q_identity));
                failures = failures + 1;
            end else begin
                $display("PASS identity: acc=%0d product=%0d q=%0d",
                         $signed(acc_value), dut_identity.product_reg,
                         $signed(q_identity));
            end
        end
    endtask

    task check_half;
        input [31:0] acc_value;
        input [41:0] expected_product;
        input [7:0]  expected_q;
        begin
            @(negedge clk);
            acc_half = acc_value;
            @(posedge clk);
            #1;

            if (dut_half.product_reg !== expected_product) begin
                $display("FAIL half product: acc=%0d expected_product=%0d observed=%0d",
                         $signed(acc_value), expected_product,
                         dut_half.product_reg);
                failures = failures + 1;
            end

            if (q_half !== expected_q) begin
                $display("FAIL half q: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected_q),
                         $signed(q_half));
                failures = failures + 1;
            end else begin
                $display("PASS half: acc=%0d product=%0d q=%0d",
                         $signed(acc_value), dut_half.product_reg,
                         $signed(q_half));
            end
        end
    endtask

    task check_three_quarters;
        input [31:0] acc_value;
        input [41:0] expected_product;
        input [7:0]  expected_q;
        begin
            @(negedge clk);
            acc_three_quarters = acc_value;
            @(posedge clk);
            #1;

            if (dut_three_quarters.product_reg !== expected_product) begin
                $display("FAIL 3/4 product: acc=%0d expected_product=%0d observed=%0d",
                         $signed(acc_value), expected_product,
                         dut_three_quarters.product_reg);
                failures = failures + 1;
            end

            if (q_three_quarters !== expected_q) begin
                $display("FAIL 3/4 q: acc=%0d expected=%0d observed=%0d",
                         $signed(acc_value), $signed(expected_q),
                         $signed(q_three_quarters));
                failures = failures + 1;
            end else begin
                $display("PASS 3/4: acc=%0d product=%0d q=%0d",
                         $signed(acc_value), dut_three_quarters.product_reg,
                         $signed(q_three_quarters));
            end
        end
    endtask

    initial begin
        failures = 0;
        rst = 1'b1;

        acc_identity       = 32'sd0;
        acc_half           = 32'sd0;
        acc_three_quarters = 32'sd0;
        acc_max            = 32'sd0;

        // ---------------------------------------------------------------------
        // A. Synchronous reset
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("A. Synchronous reset");
        $display("------------------------------------------------------------");

        @(posedge clk);
        #1;

        if (dut_identity.product_reg !== 42'd0 || q_identity !== 8'sd0 ||
            dut_half.product_reg !== 42'd0 || q_half !== 8'sd0 ||
            dut_three_quarters.product_reg !== 42'd0 ||
            q_three_quarters !== 8'sd0 ||
            dut_max.product_reg !== 42'd0 || q_max !== 8'sd0) begin
            $display("FAIL reset: one or more pipeline states are non-zero");
            failures = failures + 1;
        end else begin
            $display("PASS reset: all product registers and outputs are zero");
        end

        @(negedge clk);
        rst = 1'b0;

        // ---------------------------------------------------------------------
        // B. Identity / ReLU / saturation
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("B. Identity scaling / ReLU / saturation");
        $display("------------------------------------------------------------");

        check_identity(-32'sd1,      42'd0,      8'sd0);
        check_identity( 32'sd0,      42'd0,      8'sd0);
        check_identity( 32'sd1,      42'd1,      8'sd1);
        check_identity( 32'sd126,    42'd126,    8'sd126);
        check_identity( 32'sd127,    42'd127,    8'sd127);
        check_identity( 32'sd128,    42'd128,    8'sd127);
        check_identity( 32'sd145161, 42'd145161, 8'sd127);

        // Explicit Stage-2 saturation checkpoint.
        if (dut_identity.q_pre_wide !== 43'd145161 ||
            q_identity !== 8'sd127) begin
            $display("FAIL identity internal saturation check");
            failures = failures + 1;
        end else begin
            $display("PASS identity internal saturation check");
        end

        // ---------------------------------------------------------------------
        // C. Positive round-to-nearest
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("C. Positive round-to-nearest, M = 1/2");
        $display("------------------------------------------------------------");

        check_half(32'sd1, 42'd1, 8'sd1);
        check_half(32'sd2, 42'd2, 8'sd1);
        check_half(32'sd3, 42'd3, 8'sd2);
        check_half(32'sd4, 42'd4, 8'sd2);

        // 3 * 1 = 3; +1 rounding bias => 4; >>1 => 2.
        @(negedge clk);
        acc_half = 32'sd3;
        @(posedge clk);
        #1;
        if (dut_half.product_reg !== 42'd3 ||
            dut_half.rounded_num !== 43'd4 ||
            dut_half.q_pre_wide  !== 43'd2 ||
            q_half               !== 8'sd2) begin
            $display("FAIL half internal rounding-path check");
            failures = failures + 1;
        end else begin
            $display("PASS half internal rounding-path check");
        end

        // ---------------------------------------------------------------------
        // D. Non-power-of-two coefficient / saturation threshold
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("D. Non-power-of-two multiplier, M = 3/4");
        $display("------------------------------------------------------------");

        check_three_quarters(32'sd1,   42'd3,   8'sd1);
        check_three_quarters(32'sd2,   42'd6,   8'sd2);
        check_three_quarters(32'sd3,   42'd9,   8'sd2);
        check_three_quarters(32'sd5,   42'd15,  8'sd4);
        check_three_quarters(32'sd169, 42'd507, 8'sd127);

        // Natural 127 case.
        if (dut_three_quarters.rounded_num !== 43'd509 ||
            dut_three_quarters.q_pre_wide  !== 43'd127 ||
            q_three_quarters               !== 8'sd127) begin
            $display("FAIL 3/4 natural-127 internal check");
            failures = failures + 1;
        end else begin
            $display("PASS 3/4 natural-127 internal check");
        end

        check_three_quarters(32'sd170, 42'd510, 8'sd127);

        // Saturation-to-127 case.
        if (dut_three_quarters.rounded_num !== 43'd512 ||
            dut_three_quarters.q_pre_wide  !== 43'd128 ||
            q_three_quarters               !== 8'sd127) begin
            $display("FAIL 3/4 saturation-threshold internal check");
            failures = failures + 1;
        end else begin
            $display("PASS 3/4 saturation-threshold internal check");
        end

        // ---------------------------------------------------------------------
        // E. Maximum-width arithmetic
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("E. Maximum-width arithmetic");
        $display("------------------------------------------------------------");

        @(negedge clk);
        acc_max = 32'sd145161;
        @(posedge clk);
        #1;

        if (dut_max.product_reg !== 42'd2435397306615) begin
            $display("FAIL max: product expected 2435397306615 observed %0d",
                     dut_max.product_reg);
            failures = failures + 1;
        end else begin
            $display("PASS max: product_reg = 2435397306615");
        end

        if (dut_max.rounded_num !== 43'd4634420562167) begin
            $display("FAIL max: rounded_num expected 4634420562167 observed %0d",
                     dut_max.rounded_num);
            failures = failures + 1;
        end else begin
            $display("PASS max: rounded_num = 4634420562167");
        end

        if (dut_max.q_pre_wide !== 43'd1 || q_max !== 8'sd1) begin
            $display("FAIL max: expected q_pre=1 q_out=1 observed q_pre=%0d q_out=%0d",
                     dut_max.q_pre_wide, $signed(q_max));
            failures = failures + 1;
        end else begin
            $display("PASS max: q_pre = 1 and q_out = 1");
        end

        // ---------------------------------------------------------------------
        // F. Back-to-back sequencing
        // No empty rising edges are inserted between these samples.
        // ---------------------------------------------------------------------
        $display("------------------------------------------------------------");
        $display("F. Back-to-back pipeline sequencing");
        $display("------------------------------------------------------------");

        @(negedge clk);
        acc_three_quarters = 32'sd1;
        @(posedge clk);
        #1;
        if (q_three_quarters !== 8'sd1 ||
            dut_three_quarters.product_reg !== 42'd3) begin
            $display("FAIL back-to-back sample 1");
            failures = failures + 1;
        end else begin
            $display("PASS back-to-back: acc=1 -> q=1");
        end

        @(negedge clk);
        acc_three_quarters = 32'sd3;
        @(posedge clk);
        #1;
        if (q_three_quarters !== 8'sd2 ||
            dut_three_quarters.product_reg !== 42'd9) begin
            $display("FAIL back-to-back sample 2");
            failures = failures + 1;
        end else begin
            $display("PASS back-to-back: acc=3 -> q=2");
        end

        @(negedge clk);
        acc_three_quarters = 32'sd5;
        @(posedge clk);
        #1;
        if (q_three_quarters !== 8'sd4 ||
            dut_three_quarters.product_reg !== 42'd15) begin
            $display("FAIL back-to-back sample 3");
            failures = failures + 1;
        end else begin
            $display("PASS back-to-back: acc=5 -> q=4");
        end

        $display("------------------------------------------------------------");
        if (failures == 0)
            $display("TB_REQUANTIZE_RELU_PIPELINED_PASS: all directed checks passed");
        else
            $display("TB_REQUANTIZE_RELU_PIPELINED_FAIL: %0d checks failed", failures);
        $display("------------------------------------------------------------");

        $finish;
    end

endmodule
