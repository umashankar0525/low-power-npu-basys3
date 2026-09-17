`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Integration testbench: basys3_top_level
// Phase 8 — Basys 3 Top-Level Integration
//
// Step-8 debug revision:
//   The first XSim run showed that a debounced physical reset cannot be
//   expected to abort a 70 ns transaction before normal completion. The tests
//   therefore separate two contracts:
//
//     1) physical reset button -> synchronizer/debounce -> eventual state clear
//     2) already-clean reset_level while busy -> synchronous transaction abort
//
// Simulation strategy:
//   - Keep the real 100 MHz clock (10 ns period).
//   - Reduce only the debounce threshold from 1,000,000 cycles to 4 cycles.
//   - Measure accelerator latency from the clock edge that samples core_start.
// -----------------------------------------------------------------------------
module tb_basys3_top_level;

    localparam integer SIM_DEBOUNCE_CYCLES = 4;
    localparam integer SIM_DEBOUNCE_WIDTH  = 3;

    reg clk_100mhz;
    reg btn_start;
    reg btn_reset;

    wire [7:0] led_result;
    wire       led_done;

    integer error_count;

    // Transaction / protocol scoreboard.
    integer accepted_start_count;
    integer raw_done_count;
    integer request_count;
    integer busy_mask_checks;

    reg        track_transaction;
    reg        pending_read;
    reg [31:0] pending_activation_word;
    reg [31:0] pending_weight_word;

    time accepted_start_time;
    time raw_done_time;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    basys3_top_level #(
        .DEBOUNCE_CYCLES (SIM_DEBOUNCE_CYCLES),
        .DEBOUNCE_WIDTH  (SIM_DEBOUNCE_WIDTH)
    ) dut (
        .clk_100mhz (clk_100mhz),
        .btn_start  (btn_start),
        .btn_reset  (btn_reset),
        .led_result (led_result),
        .led_done   (led_done)
    );

    // 100 MHz => 10 ns period.
    initial begin
        clk_100mhz = 1'b0;
        forever #5 clk_100mhz = ~clk_100mhz;
    end

    // -------------------------------------------------------------------------
    // Generic check helper
    // -------------------------------------------------------------------------
    task automatic check;
        input condition;
        input [1023:0] message;
        begin
            if (condition !== 1'b1) begin
                $display("ERROR @ %0t: %0s", $time, message);
                error_count = error_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Expected initialized memory contents
    // -------------------------------------------------------------------------
    function [31:0] expected_activation_word;
        input [1:0] addr;
        begin
            case (addr)
                2'd0: expected_activation_word = 32'h04030201;
                2'd1: expected_activation_word = 32'h08070605;
                2'd2: expected_activation_word = 32'h00000009;
                default: expected_activation_word = 32'h00000000;
            endcase
        end
    endfunction

    function [31:0] expected_weight_word;
        input [1:0] addr;
        begin
            case (addr)
                2'd0: expected_weight_word = 32'h01010101;
                2'd1: expected_weight_word = 32'h01010101;
                2'd2: expected_weight_word = 32'h00000001;
                default: expected_weight_word = 32'h00000000;
            endcase
        end
    endfunction

    // -------------------------------------------------------------------------
    // Scoreboard reset
    // -------------------------------------------------------------------------
    task reset_transaction_scoreboard;
        begin
            accepted_start_count    = 0;
            raw_done_count          = 0;
            request_count           = 0;
            busy_mask_checks        = 0;
            pending_read            = 1'b0;
            pending_activation_word = 32'd0;
            pending_weight_word     = 32'd0;
            accepted_start_time     = 0;
            raw_done_time           = 0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Bounded wait helpers
    // -------------------------------------------------------------------------
    task wait_for_start_count;
        input integer target;
        input integer max_cycles;
        input [1023:0] label;
        integer n;
        begin
            n = 0;
            while ((accepted_start_count < target) && (n < max_cycles)) begin
                @(negedge clk_100mhz);
                n = n + 1;
            end
            check(accepted_start_count >= target, label);
        end
    endtask

    task wait_for_done_count;
        input integer target;
        input integer max_cycles;
        input [1023:0] label;
        integer n;
        begin
            n = 0;
            while ((raw_done_count < target) && (n < max_cycles)) begin
                @(negedge clk_100mhz);
                n = n + 1;
            end
            check(raw_done_count >= target, label);
        end
    endtask

    task wait_for_reset_level;
        input expected_level;
        input integer max_cycles;
        input [1023:0] label;
        integer n;
        begin
            n = 0;
            while ((dut.reset_level !== expected_level) && (n < max_cycles)) begin
                @(negedge clk_100mhz);
                n = n + 1;
            end
            check(dut.reset_level === expected_level, label);
        end
    endtask

    task wait_for_start_level;
        input expected_level;
        input integer max_cycles;
        input [1023:0] label;
        integer n;
        begin
            n = 0;
            while ((dut.start_level_unused !== expected_level) && (n < max_cycles)) begin
                @(negedge clk_100mhz);
                n = n + 1;
            end
            check(dut.start_level_unused === expected_level, label);
        end
    endtask

    // -------------------------------------------------------------------------
    // Physical reset helper
    // -------------------------------------------------------------------------
    task apply_physical_reset;
        begin
            @(negedge clk_100mhz);
            btn_reset = 1'b1;

            wait_for_reset_level(1'b1, 20,
                "reset button did not debounce high within timeout");

            // The clean reset level is synchronous to the core. Give the core
            // one edge to sample the already-high reset_level.
            @(posedge clk_100mhz);
            #1;
            check(dut.core_busy === 1'b0,
                  "core_busy was not low after synchronous reset sampling");
            check(dut.core_done === 1'b0,
                  "core_done was not low after synchronous reset sampling");
            check(led_result === 8'd0,
                  "led_result was not cleared by reset");
            check(led_done === 1'b0,
                  "led_done was not cleared by reset");

            @(negedge clk_100mhz);
            btn_reset = 1'b0;
            wait_for_reset_level(1'b0, 20,
                "reset button did not debounce low within timeout");

            @(posedge clk_100mhz);
            #1;
        end
    endtask

    // -------------------------------------------------------------------------
    // Accepted-start and raw-done monitors
    // -------------------------------------------------------------------------
    always @(posedge clk_100mhz) begin
        if (track_transaction && (dut.core_start === 1'b1)) begin
            accepted_start_count = accepted_start_count + 1;
            if (accepted_start_time == 0)
                accepted_start_time = $time;
        end
    end

    always @(posedge dut.core_done) begin
        if (track_transaction) begin
            raw_done_count = raw_done_count + 1;
            if (raw_done_time == 0)
                raw_done_time = $time;
        end
    end

    // -------------------------------------------------------------------------
    // Memory request order + one-clock synchronous-return monitor
    // -------------------------------------------------------------------------
    always @(posedge clk_100mhz) begin
        if (track_transaction) begin
            // A request captured on the previous edge must already have updated
            // the registered memory outputs by this edge.
            if (pending_read) begin
                check(dut.activation_data === pending_activation_word,
                      "activation_data did not match the previous-cycle request");
                check(dut.weight_data === pending_weight_word,
                      "weight_data did not match the previous-cycle request");
            end

            pending_read = 1'b0;

            if ((dut.activation_rd_en === 1'b1) ||
                (dut.weight_rd_en === 1'b1)) begin

                check((dut.activation_rd_en === 1'b1) &&
                      (dut.weight_rd_en === 1'b1),
                      "activation and weight read enables were not asserted together");
                check(dut.activation_addr === dut.weight_addr,
                      "activation and weight logical addresses differed");

                case (request_count)
                    0: check(dut.activation_addr === 2'd0,
                             "first operand request was not address 0");
                    1: check(dut.activation_addr === 2'd1,
                             "second operand request was not address 1");
                    2: check(dut.activation_addr === 2'd2,
                             "third operand request was not address 2");
                    default: check(1'b0,
                                   "more than three operand request cycles occurred");
                endcase

                pending_activation_word = expected_activation_word(dut.activation_addr);
                pending_weight_word     = expected_weight_word(dut.weight_addr);
                pending_read            = 1'b1;
                request_count           = request_count + 1;
            end
        end else begin
            pending_read = 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Main stimulus
    // -------------------------------------------------------------------------
    initial begin
        error_count       = 0;
        track_transaction = 1'b0;
        btn_start         = 1'b0;
        btn_reset         = 1'b0;
        reset_transaction_scoreboard;

        // Allow FPGA-style initialization to settle.
        repeat (3) @(posedge clk_100mhz);
        #1;

        // ---------------------------------------------------------------------
        // TEST 1 — Physical reset path while idle
        // ---------------------------------------------------------------------
        $display("TEST 1: physical reset path");
        apply_physical_reset;

        // ---------------------------------------------------------------------
        // TEST 2 — Button bounce must not create a transaction
        // ---------------------------------------------------------------------
        $display("TEST 2: bounce rejection");
        reset_transaction_scoreboard;
        track_transaction = 1'b1;

        @(negedge clk_100mhz); btn_start = 1'b1;
        @(negedge clk_100mhz); btn_start = 1'b0;
        @(negedge clk_100mhz); btn_start = 1'b1;
        @(negedge clk_100mhz); btn_start = 1'b0;
        @(negedge clk_100mhz); btn_start = 1'b1;
        @(negedge clk_100mhz); btn_start = 1'b0;

        repeat (10) @(posedge clk_100mhz);
        #1;
        check(accepted_start_count == 0,
              "button bounce created an accepted core_start");
        check(dut.start_level_unused === 1'b0,
              "debounced start level changed during bounce-only stimulus");
        check(dut.core_busy === 1'b0,
              "core became busy during bounce-only stimulus");
        track_transaction = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 3 — Full nominal board transaction
        // ---------------------------------------------------------------------
        $display("TEST 3: full board transaction and protocol checks");
        reset_transaction_scoreboard;
        track_transaction = 1'b1;

        @(negedge clk_100mhz);
        btn_start = 1'b1;

        wait_for_start_count(1, 20,
            "stable button press did not produce an accepted core_start");
        check(dut.core_busy === 1'b1,
              "core_busy was not high after accepted core_start");

        // Directly exercise the exact busy-mask property.
        @(negedge clk_100mhz);
        check(dut.core_busy === 1'b1,
              "core was no longer busy before busy-mask test");
        force dut.start_rise = 1'b1;
        #1;
        check(dut.core_start === 1'b0,
              "busy mask failed: core_start asserted while core_busy was high");
        busy_mask_checks = busy_mask_checks + 1;

        @(posedge clk_100mhz);
        #1;
        check(dut.core_busy === 1'b1,
              "core unexpectedly left busy state during busy-mask test");
        check(dut.core_start === 1'b0,
              "busy mask failed at sampling edge");

        @(negedge clk_100mhz);
        release dut.start_rise;

        wait_for_done_count(1, 20,
            "core_done did not occur for the stable button transaction");

        #1;
        check((raw_done_time - accepted_start_time) == 70,
              "accepted core_start to raw core_done latency was not 70 ns");
        check(led_result === 8'd34,
              "board-visible result was not 34 at raw core completion");
        check(request_count == 3,
              "transaction did not issue exactly three paired operand reads");
        check(accepted_start_count == 1,
              "held button created more than one accepted core_start");
        check(raw_done_count == 1,
              "transaction produced more than one raw core_done pulse");
        check(busy_mask_checks == 1,
              "busy-mask condition was not explicitly exercised");

        // done_latched samples raw core_done on the following rising edge.
        check(led_done === 1'b0,
              "led_done asserted in the same cycle as raw core_done");
        @(posedge clk_100mhz);
        #1;
        check(led_done === 1'b1,
              "led_done did not latch completion one clock after raw core_done");

        repeat (5) @(posedge clk_100mhz);
        #1;
        check(accepted_start_count == 1,
              "held button retriggered the accelerator");
        check(led_done === 1'b1,
              "latched completion status did not remain persistent");

        @(negedge clk_100mhz);
        btn_start = 1'b0;
        wait_for_start_level(1'b0, 20,
            "start button did not debounce low after release");
        check(led_done === 1'b1,
              "releasing the start button incorrectly cleared done_latched");
        track_transaction = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 4A — Physical reset pressed while transaction is active
        //
        // This test does NOT require the 70 ns transaction to be aborted. It
        // verifies that the physical button path eventually creates reset_level
        // and that the next synchronous core edge clears architectural state.
        // ---------------------------------------------------------------------
        $display("TEST 4A: physical reset during active transaction - eventual clear");
        reset_transaction_scoreboard;
        track_transaction = 1'b1;

        @(negedge clk_100mhz);
        btn_start = 1'b1;
        wait_for_start_count(1, 20,
            "physical-reset test did not produce accepted core_start");
        check(dut.core_busy === 1'b1,
              "core was not busy before physical-reset timing test");

        @(negedge clk_100mhz);
        btn_start = 1'b0;
        btn_reset = 1'b1;

        wait_for_reset_level(1'b1, 20,
            "physical reset did not debounce high during active transaction");

        // By this time raw_done may legitimately have occurred because the
        // qualified physical reset path is slower than the 70 ns computation.
        check(raw_done_count <= 1,
              "physical-reset test observed more than one raw completion");

        @(posedge clk_100mhz);
        #1;
        check(dut.core_busy === 1'b0,
              "physical reset did not eventually clear core_busy");
        check(dut.core_done === 1'b0,
              "physical reset did not eventually clear core_done");
        check(led_result === 8'd0,
              "physical reset did not eventually clear led_result");
        check(led_done === 1'b0,
              "physical reset did not eventually clear led_done");

        @(negedge clk_100mhz);
        btn_reset = 1'b0;
        wait_for_reset_level(1'b0, 20,
            "physical reset did not debounce low after release");
        wait_for_start_level(1'b0, 20,
            "start conditioner did not return low after physical reset");
        @(posedge clk_100mhz);
        #1;
        track_transaction = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 4B — Clean synchronous reset abort while core is busy
        //
        // This isolates the actual core reset contract from human-interface
        // synchronization/debounce delay. reset_level is forced only as a
        // verification point; the accelerator RTL is not modified.
        // ---------------------------------------------------------------------
        $display("TEST 4B: clean reset_level abort while busy");
        reset_transaction_scoreboard;
        track_transaction = 1'b1;

        @(negedge clk_100mhz);
        btn_start = 1'b1;
        wait_for_start_count(1, 20,
            "clean-reset abort test did not produce accepted core_start");
        check(dut.core_busy === 1'b1,
              "core was not busy before clean-reset abort test");

        // Allow one engine-launch clock so the transaction has genuinely begun.
        @(posedge clk_100mhz);
        #1;
        check(dut.core_busy === 1'b1,
              "core was not busy after engine-launch edge");

        // Assert the already-clean synchronous reset before normal E7 completion.
        @(negedge clk_100mhz);
        btn_start = 1'b0;
        force dut.reset_level = 1'b1;
        #1;
        check(dut.reset_level === 1'b1,
              "forced clean reset_level did not assert");

        @(posedge clk_100mhz);
        #1;
        check(dut.core_busy === 1'b0,
              "clean reset_level did not abort core_busy");
        check(dut.core_done === 1'b0,
              "clean reset_level allowed core_done during abort edge");
        check(led_result === 8'd0,
              "clean reset_level did not clear architectural result");
        check(led_done === 1'b0,
              "clean reset_level did not clear done_latched");
        check(raw_done_count == 0,
              "clean synchronous reset did not abort before raw core_done");

        @(negedge clk_100mhz);
        release dut.reset_level;

        // The abandoned transaction must not reappear after reset is released.
        repeat (10) @(posedge clk_100mhz);
        #1;
        check(raw_done_count == 0,
              "aborted transaction produced a stale raw core_done after reset release");
        check(dut.core_busy === 1'b0,
              "core became busy again after clean-reset abort without a new start");
        wait_for_start_level(1'b0, 20,
            "start conditioner did not return low after clean-reset abort");
        track_transaction = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 5 — Recovery after reset-abort
        // ---------------------------------------------------------------------
        $display("TEST 5: post-reset recovery transaction");
        reset_transaction_scoreboard;
        track_transaction = 1'b1;

        @(negedge clk_100mhz);
        btn_start = 1'b1;

        wait_for_start_count(1, 20,
            "post-reset stable press did not produce accepted core_start");
        wait_for_done_count(1, 20,
            "post-reset transaction did not complete");

        #1;
        check((raw_done_time - accepted_start_time) == 70,
              "post-reset accepted-start to done latency was not 70 ns");
        check(led_result === 8'd34,
              "post-reset board result was not 34");
        check(request_count == 3,
              "post-reset transaction did not issue exactly three operand reads");

        @(posedge clk_100mhz);
        #1;
        check(led_done === 1'b1,
              "post-reset completion was not latched for the LED");

        @(negedge clk_100mhz);
        btn_start = 1'b0;
        wait_for_start_level(1'b0, 20,
            "post-reset start release did not debounce low");

        track_transaction = 1'b0;

        // ---------------------------------------------------------------------
        // Final result
        // ---------------------------------------------------------------------
        if (error_count == 0)
            $display("PASS: tb_basys3_top_level completed with zero errors");
        else
            $display("FAIL: tb_basys3_top_level completed with %0d errors", error_count);

        $finish;
    end

endmodule
