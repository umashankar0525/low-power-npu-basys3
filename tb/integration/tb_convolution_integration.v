`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Integration testbench: convolution_integration
// Phase 7 — Convolution Integration and End-to-End Dataflow
//
// IMPORTANT:
//   This file is generated from the approved verification plan. It has not yet
//   been run in XSim. Step 8 must execute it and explain every passing waveform
//   relationship signal by signal.
//
// Primary DUT parameters:
//   M_INT     = 3
//   FRAC_BITS = 2
//   M_hat     = 3/4 = 0.75
//
// The testbench intentionally models activation and weight memories as
// one-clock synchronous-read memories using nonblocking assignments.
// -----------------------------------------------------------------------------
module tb_convolution_integration;

    // -------------------------------------------------------------------------
    // Clock / reset
    // -------------------------------------------------------------------------
    reg clk;
    reg rst;

    // -------------------------------------------------------------------------
    // Primary DUT: M_INT=3, FRAC_BITS=2
    // -------------------------------------------------------------------------
    reg start;
    wire busy;
    wire done;

    wire activation_rd_en;
    wire [1:0] activation_addr;
    reg  [31:0] activation_data;

    wire weight_rd_en;
    wire [1:0] weight_addr;
    reg  [31:0] weight_data;

    wire signed [7:0] activation_out;

    reg [31:0] activation_mem [0:2];
    reg [31:0] weight_mem     [0:2];

    // -------------------------------------------------------------------------
    // Secondary DUT: maximum-width requantization configuration
    // M_INT=2^24-1, FRAC_BITS=42
    // -------------------------------------------------------------------------
    reg start_max;
    wire busy_max;
    wire done_max;

    wire max_activation_rd_en;
    wire [1:0] max_activation_addr;
    reg  [31:0] max_activation_data;

    wire max_weight_rd_en;
    wire [1:0] max_weight_addr;
    reg  [31:0] max_weight_data;

    wire signed [7:0] max_activation_out;

    reg [31:0] max_activation_mem [0:2];
    reg [31:0] max_weight_mem     [0:2];

    // -------------------------------------------------------------------------
    // Scoreboard / measurement state
    // -------------------------------------------------------------------------
    integer error_count;

    reg primary_track;
    integer primary_req_count;
    integer primary_engine_start_count;
    integer primary_engine_done_count;
    integer primary_capture_count;
    integer primary_done_count;
    reg primary_capture_seen;

    time first_start_time;
    time second_start_time;
    time measured_done_time;

    reg [31:0] expected_activation_return;
    reg [31:0] expected_weight_return;

    // -------------------------------------------------------------------------
    // DUT instances
    // -------------------------------------------------------------------------
    convolution_integration #(
        .M_INT     (24'd3),
        .FRAC_BITS (2)
    ) dut (
        .clk               (clk),
        .rst               (rst),
        .start             (start),
        .busy              (busy),
        .done              (done),
        .activation_rd_en  (activation_rd_en),
        .activation_addr   (activation_addr),
        .activation_data   (activation_data),
        .weight_rd_en      (weight_rd_en),
        .weight_addr       (weight_addr),
        .weight_data       (weight_data),
        .activation_out    (activation_out)
    );

    convolution_integration #(
        .M_INT     (24'hFFFFFF),
        .FRAC_BITS (42)
    ) dut_max (
        .clk               (clk),
        .rst               (rst),
        .start             (start_max),
        .busy              (busy_max),
        .done              (done_max),
        .activation_rd_en  (max_activation_rd_en),
        .activation_addr   (max_activation_addr),
        .activation_data   (max_activation_data),
        .weight_rd_en      (max_weight_rd_en),
        .weight_addr       (max_weight_addr),
        .weight_data       (max_weight_data),
        .activation_out    (max_activation_out)
    );

    // -------------------------------------------------------------------------
    // 100 MHz clock => 10 ns period
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // One-clock synchronous memory models — primary DUT
    // The DUT sees the pre-edge memory value during its sequential evaluation.
    // The requested word appears only after the edge due to NBA semantics.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (activation_rd_en)
            activation_data <= activation_mem[activation_addr];

        if (weight_rd_en)
            weight_data <= weight_mem[weight_addr];
    end

    // One-clock synchronous memory models — maximum-width DUT.
    always @(posedge clk) begin
        if (max_activation_rd_en)
            max_activation_data <= max_activation_mem[max_activation_addr];

        if (max_weight_rd_en)
            max_weight_data <= max_weight_mem[max_weight_addr];
    end

    // -------------------------------------------------------------------------
    // Generic check helper
    // -------------------------------------------------------------------------
    task check;
        input condition;
        input [767:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("ERROR @ %0t ns: %0s", $time, message);
                error_count = error_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Primary memory loaders
    // -------------------------------------------------------------------------
    task load_primary_words;
        input [31:0] a0;
        input [31:0] a1;
        input [31:0] a2;
        input [31:0] w0;
        input [31:0] w1;
        input [31:0] w2;
        begin
            activation_mem[0] = a0;
            activation_mem[1] = a1;
            activation_mem[2] = a2;
            weight_mem[0]     = w0;
            weight_mem[1]     = w1;
            weight_mem[2]     = w2;
        end
    endtask

    task load_max_words;
        input [31:0] a0;
        input [31:0] a1;
        input [31:0] a2;
        input [31:0] w0;
        input [31:0] w1;
        input [31:0] w2;
        begin
            max_activation_mem[0] = a0;
            max_activation_mem[1] = a1;
            max_activation_mem[2] = a2;
            max_weight_mem[0]     = w0;
            max_weight_mem[1]     = w1;
            max_weight_mem[2]     = w2;
        end
    endtask

    // -------------------------------------------------------------------------
    // Scoreboard setup
    // -------------------------------------------------------------------------
    task reset_primary_scoreboard;
        begin
            primary_req_count          = 0;
            primary_engine_start_count = 0;
            primary_engine_done_count  = 0;
            primary_capture_count      = 0;
            primary_done_count         = 0;
            primary_capture_seen       = 1'b0;
        end
    endtask

    // Count transaction pulses using their actual rising edges.
    always @(posedge dut.engine_start) begin
        if (primary_track)
            primary_engine_start_count = primary_engine_start_count + 1;
    end

    always @(posedge dut.engine_done) begin
        if (primary_track)
            primary_engine_done_count = primary_engine_done_count + 1;
    end

    always @(posedge dut.capture_activation) begin
        if (primary_track) begin
            primary_capture_count = primary_capture_count + 1;
            primary_capture_seen  = 1'b1;
        end
    end

    always @(posedge done) begin
        if (primary_track) begin
            primary_done_count = primary_done_count + 1;
            check(primary_capture_seen === 1'b1,
                  "done asserted before a capture_activation event");
        end
    end

    // -------------------------------------------------------------------------
    // Request-order and synchronous-memory-response monitor for primary DUT.
    // The request observed at this edge causes the modeled data output to update
    // after this same edge. The engine consumes it only on a later edge.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (primary_track && (activation_rd_en || weight_rd_en)) begin
            check((activation_rd_en === 1'b1) && (weight_rd_en === 1'b1),
                  "activation and weight read enables were not asserted together");
            check(activation_addr === weight_addr,
                  "activation and weight addresses did not match");

            case (primary_req_count)
                0: check(activation_addr === 2'd0,
                         "first memory request address was not 0");
                1: check(activation_addr === 2'd1,
                         "second memory request address was not 1");
                2: check(activation_addr === 2'd2,
                         "third memory request address was not 2");
                default: check(1'b0,
                               "more than three memory request cycles occurred");
            endcase

            expected_activation_return = activation_mem[activation_addr];
            expected_weight_return     = weight_mem[weight_addr];
            primary_req_count = primary_req_count + 1;

            #1;
            check(activation_data === expected_activation_return,
                  "activation memory did not return the requested word after the synchronous edge");
            check(weight_data === expected_weight_return,
                  "weight memory did not return the requested word after the synchronous edge");
        end
    end

    // -------------------------------------------------------------------------
    // Continuous public-interface invariants.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        #1;
        if (!rst) begin
            check(!(done && !busy),
                  "done was high while busy was low");

            if (!busy) begin
                check(done === 1'b0,
                      "done remained high while controller was ready/idle");
            end

            check(activation_rd_en === weight_rd_en,
                  "activation/weight read-enable symmetry was violated");
        end
    end

    // -------------------------------------------------------------------------
    // Legal one-cycle primary start pulse.
    // Returns the accepted-start edge timestamp through global first_start_time
    // when used by normal directed tests.
    // -------------------------------------------------------------------------
    task pulse_primary_start;
        begin
            check(busy === 1'b0,
                  "attempted a legal primary start while busy was high");
            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            first_start_time = $time;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Full primary transaction checker.
    // Proves E5 -> E6 -> E7 data association, request count, pulse count,
    // 70 ns latency, output stability before capture, and final public result.
    // -------------------------------------------------------------------------
    task run_primary_transaction;
        input integer expected_acc;
        input integer expected_product;
        input integer expected_q;
        input [767:0] label;
        reg signed [7:0] old_activation;
        time local_start_time;
        time local_done_time;
        begin
            $display("TEST: %0s", label);

            reset_primary_scoreboard;
            primary_track = 1'b1;
            old_activation = activation_out;

            pulse_primary_start;
            local_start_time = first_start_time;

            // E5: final signed INT32 convolution result is registered.
            @(posedge dut.engine_done);
            #1;
            check(dut.engine_result === expected_acc,
                  "E5 engine_result did not match independent convolution expectation");
            check(activation_out === old_activation,
                  "activation_out changed before the architectural capture edge");

            // E6: product_reg captures the product derived from the E5 result.
            @(posedge clk);
            #1;
            check(dut.capture_activation === 1'b1,
                  "capture_activation was not high during E6->E7 interval");
            check(dut.u_requantize_relu_pipelined.product_reg === expected_product,
                  "E6 product_reg did not correspond to the E5 engine_result");
            check(dut.requantized_q === expected_q,
                  "requantized_q did not match rounding/shift/saturation expectation");
            check(activation_out === old_activation,
                  "activation_out changed one cycle too early");

            // E7: architectural result is captured and DONE becomes visible.
            @(posedge done);
            local_done_time = $time;
            #1;
            check(activation_out === expected_q,
                  "E7 activation_out did not capture the expected q_out");
            check(busy === 1'b1,
                  "busy was not high during DONE interval");
            check((local_done_time - local_start_time) == 70,
                  "accepted-start to done latency was not 70 ns");

            check(primary_req_count == 3,
                  "transaction did not issue exactly three memory request cycles");
            check(primary_engine_start_count == 1,
                  "transaction did not generate exactly one engine_start pulse");
            check(primary_engine_done_count == 1,
                  "transaction did not generate exactly one engine_done pulse");
            check(primary_capture_count == 1,
                  "transaction did not generate exactly one capture_activation pulse");
            check(primary_done_count == 1,
                  "transaction did not generate exactly one external done pulse");

            @(negedge done);
            #1;
            check(busy === 1'b0,
                  "busy did not return low after DONE -> IDLE transition");

            primary_track = 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    initial begin
        error_count = 0;
        primary_track = 1'b0;
        reset_primary_scoreboard;

        start = 1'b0;
        start_max = 1'b0;
        rst = 1'b1;

        activation_data = 32'd0;
        weight_data = 32'd0;
        max_activation_data = 32'd0;
        max_weight_data = 32'd0;

        // Default memory initialization.
        load_primary_words(32'd0, 32'd0, 32'd0,
                           32'd0, 32'd0, 32'd0);
        load_max_words(32'd0, 32'd0, 32'd0,
                       32'd0, 32'd0, 32'd0);

        // ---------------------------------------------------------------------
        // Test 1 — Reset and idle state
        // ---------------------------------------------------------------------
        $display("TEST: reset and idle state");
        @(posedge clk);
        @(posedge clk);
        #1;
        check(busy === 1'b0, "busy was not low during reset");
        check(done === 1'b0, "done was not low during reset");
        check(activation_out === 8'sd0, "activation_out was not cleared by reset");
        check(activation_rd_en === 1'b0, "activation read enable was high during reset");
        check(weight_rd_en === 1'b0, "weight read enable was high during reset");
        check(activation_addr === 2'd0, "activation address did not reset to zero");
        check(weight_addr === 2'd0, "weight address did not reset to zero");
        check(dut.u_requantize_relu_pipelined.product_reg === 42'd0,
              "requantizer product_reg was not cleared by reset");

        @(negedge clk);
        rst = 1'b0;

        // ---------------------------------------------------------------------
        // Test 2 — Positive unsaturated end-to-end case
        // activations = [1,2,3,4,5,6,7,8,9]
        // weights     = [1,1,1,1,1,1,1,1,1]
        // acc=45, product=135, q=(135+2)>>2=34
        // ---------------------------------------------------------------------
        load_primary_words(
            32'h04030201,
            32'h08070605,
            32'h00000009,
            32'h01010101,
            32'h01010101,
            32'h00000001
        );
        run_primary_transaction(45, 135, 34,
            "positive unsaturated convolution: 45 -> product 135 -> q_out 34");

        // ---------------------------------------------------------------------
        // Test 3 — Negative convolution through ReLU
        // acc=-45 -> product_reg=0 -> q_out=0
        // ---------------------------------------------------------------------
        load_primary_words(
            32'hFCFDFEFF,
            32'hF8F9FAFB,
            32'h000000F7,
            32'h01010101,
            32'h01010101,
            32'h00000001
        );
        run_primary_transaction(-45, 0, 0,
            "negative convolution: engine_result -45 then ReLU/requantization to 0");

        // ---------------------------------------------------------------------
        // Test 4 — Maximum legal positive accumulator with saturation
        // 9 * 127 * 127 = 145161
        // product=435483, q_pre=(435483+2)>>2=108871 -> saturate to 127
        // ---------------------------------------------------------------------
        load_primary_words(
            32'h7F7F7F7F,
            32'h7F7F7F7F,
            32'h0000007F,
            32'h7F7F7F7F,
            32'h7F7F7F7F,
            32'h0000007F
        );
        run_primary_transaction(145161, 435483, 127,
            "maximum legal accumulator: 145161 -> saturation to 127");

        // ---------------------------------------------------------------------
        // Test 5 — Small value exposing fixed-point rounding
        // acc=5, product=15, (15+2)>>2=4
        // ---------------------------------------------------------------------
        load_primary_words(
            32'h00000005,
            32'h00000000,
            32'h00000000,
            32'h00000001,
            32'h00000000,
            32'h00000000
        );
        run_primary_transaction(5, 15, 4,
            "rounding visibility: 5 -> product 15 -> q_out 4");

        // ---------------------------------------------------------------------
        // Test 6 — Start while busy must be ignored
        // Use nominal 45 -> 34 vector and inject a second start in WAIT_ENGINE.
        // ---------------------------------------------------------------------
        $display("TEST: start while busy is ignored");
        load_primary_words(
            32'h04030201,
            32'h08070605,
            32'h00000009,
            32'h01010101,
            32'h01010101,
            32'h00000001
        );
        reset_primary_scoreboard;
        primary_track = 1'b1;
        pulse_primary_start;

        // Wait until the transaction is active, then inject an illegal request.
        @(posedge clk);
        @(negedge clk);
        check(busy === 1'b1, "busy was not high before illegal start injection");
        start = 1'b1;
        @(posedge clk);
        @(negedge clk);
        start = 1'b0;

        @(posedge done);
        #1;
        check(activation_out === 8'sd34,
              "busy-start test produced the wrong final output");
        check(primary_engine_start_count == 1,
              "start while busy generated an extra engine_start pulse");
        check(primary_req_count == 3,
              "start while busy changed the three-request memory sequence");
        check(primary_capture_count == 1,
              "start while busy generated an extra capture pulse");
        check(primary_done_count == 1,
              "start while busy generated an extra done pulse");
        @(negedge done);
        #1;
        primary_track = 1'b0;

        // ---------------------------------------------------------------------
        // Test 7 — Earliest legal back-to-back transactions
        // Transaction 1 expected 34; transaction 2 expected 4.
        // Accepted starts must be 90 ns apart.
        // ---------------------------------------------------------------------
        $display("TEST: earliest legal restart and stale-data rejection");
        load_primary_words(
            32'h04030201,
            32'h08070605,
            32'h00000009,
            32'h01010101,
            32'h01010101,
            32'h00000001
        );

        check(busy === 1'b0, "controller was not idle before back-to-back test");
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        first_start_time = $time;
        @(negedge clk);
        start = 1'b0;

        @(posedge done);
        #1;
        check(activation_out === 8'sd34,
              "first back-to-back transaction did not produce 34");

        // Wait for E8 return to IDLE, change data, and present the next start
        // immediately so it is accepted at E9.
        @(negedge busy);
        load_primary_words(
            32'h00000005,
            32'h00000000,
            32'h00000000,
            32'h00000001,
            32'h00000000,
            32'h00000000
        );
        start = 1'b1;
        @(posedge clk);
        second_start_time = $time;
        check((second_start_time - first_start_time) == 90,
              "earliest legal accepted-start spacing was not 90 ns");
        @(negedge clk);
        start = 1'b0;

        @(posedge done);
        #1;
        check(activation_out === 8'sd4,
              "second transaction did not replace the first result with fresh output 4");
        @(negedge done);
        #1;

        // ---------------------------------------------------------------------
        // Test 8 — Reset during active transaction, then recovery
        // ---------------------------------------------------------------------
        $display("TEST: synchronous reset during active transaction and recovery");
        load_primary_words(
            32'h04030201,
            32'h08070605,
            32'h00000009,
            32'h01010101,
            32'h01010101,
            32'h00000001
        );

        pulse_primary_start;
        @(posedge clk); // Engine accepts engine_start and launches word 0 request.
        @(negedge clk);
        check(busy === 1'b1, "transaction was not active before reset injection");
        rst = 1'b1;
        @(posedge clk);
        #1;
        check(busy === 1'b0, "busy did not clear on synchronous reset edge");
        check(done === 1'b0, "done remained asserted after synchronous reset");
        check(activation_out === 8'sd0, "activation_out did not clear on reset");
        check(activation_rd_en === 1'b0, "activation read enable did not clear on reset");
        check(weight_rd_en === 1'b0, "weight read enable did not clear on reset");
        check(dut.engine_done === 1'b0, "engine_done did not clear on reset");
        check(dut.engine_result === 32'sd0, "engine_result did not clear on reset");
        check(dut.u_requantize_relu_pipelined.product_reg === 42'd0,
              "product_reg did not clear on reset");

        @(negedge clk);
        rst = 1'b0;

        // Prove recovery with a fresh 5 -> 4 transaction.
        load_primary_words(
            32'h00000005,
            32'h00000000,
            32'h00000000,
            32'h00000001,
            32'h00000000,
            32'h00000000
        );
        run_primary_transaction(5, 15, 4,
            "post-reset recovery transaction: 5 -> product 15 -> q_out 4");

        // ---------------------------------------------------------------------
        // Test 9 — Maximum-width requantization integration check
        // M_INT=16777215, FRAC_BITS=42
        // acc=145161
        // product=2435397306615
        // rounded_num=product+2^41=4634420562167
        // q_pre=1, activation_out=1
        // ---------------------------------------------------------------------
        $display("TEST: maximum-width requantization integration");
        load_max_words(
            32'h7F7F7F7F,
            32'h7F7F7F7F,
            32'h0000007F,
            32'h7F7F7F7F,
            32'h7F7F7F7F,
            32'h0000007F
        );

        check(busy_max === 1'b0, "maximum-width DUT was not idle before start");
        @(negedge clk);
        start_max = 1'b1;
        @(posedge clk);
        first_start_time = $time;
        @(negedge clk);
        start_max = 1'b0;

        @(posedge dut_max.engine_done);
        #1;
        check(dut_max.engine_result === 32'sd145161,
              "maximum-width DUT engine_result was not 145161 at E5");

        @(posedge clk);
        #1;
        check(dut_max.capture_activation === 1'b1,
              "maximum-width DUT did not enter capture interval at E6");
        check(dut_max.u_requantize_relu_pipelined.product_reg === 42'd2435397306615,
              "maximum-width product_reg lost or corrupted upper product bits");
        check(dut_max.requantized_q === 8'sd1,
              "maximum-width rounding/shift result was not 1");

        @(posedge done_max);
        measured_done_time = $time;
        #1;
        check(max_activation_out === 8'sd1,
              "maximum-width architectural output was not 1 at E7");
        check((measured_done_time - first_start_time) == 70,
              "maximum-width DUT latency was not 70 ns");

        @(negedge done_max);
        #1;
        check(busy_max === 1'b0,
              "maximum-width DUT did not return to idle after DONE");

        // ---------------------------------------------------------------------
        // Final report
        // ---------------------------------------------------------------------
        if (error_count == 0)
            $display("PASS: convolution integration testbench completed with 0 detected errors.");
        else
            $display("FAIL: convolution integration testbench detected %0d error(s).", error_count);

        $finish;
    end

endmodule
