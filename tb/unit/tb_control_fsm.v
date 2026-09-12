`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// Testbench: tb_control_fsm
// Purpose: Verify the five-state supervisory control protocol.
//
// Predicted real wrapped-engine timing at 100 MHz:
//   external start accepted -> external done = 7 clock periods = 70 ns
//
// This is a unit test of control_fsm only. The convolution engine is modeled by
// driving engine_done explicitly.
// -----------------------------------------------------------------------------
module tb_control_fsm;

    reg clk;
    reg rst;
    reg start;
    reg engine_done;

    wire engine_start;
    wire capture_activation;
    wire busy;
    wire done;

    integer failures;
    integer engine_start_count;
    integer capture_count;
    integer done_count;
    integer transaction_count;

    reg capture_seen;
    time accepted_start_time;
    time observed_done_time;

    control_fsm dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .engine_done(engine_done),
        .engine_start(engine_start),
        .capture_activation(capture_activation),
        .busy(busy),
        .done(done)
    );

    // 100 MHz clock -> 10 ns period.
    always #5 clk = ~clk;

    // -------------------------------------------------------------------------
    // Continuous scoreboard and protocol invariants.
    // Sample one nanosecond after each rising edge so the state-register NBA
    // update and Moore output decode have settled.
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        #1;

        if (rst) begin
            capture_seen = 1'b0;
        end else begin
            if (engine_start) begin
                engine_start_count = engine_start_count + 1;
                capture_seen = 1'b0;
            end

            if (capture_activation) begin
                capture_count = capture_count + 1;
                capture_seen = 1'b1;
            end

            if (done) begin
                done_count = done_count + 1;
                if (!capture_seen) begin
                    $display("FAIL: done occurred before capture_activation at %0t", $time);
                    failures = failures + 1;
                end
            end

            // No two one-cycle control events should overlap.
            if (engine_start && capture_activation) begin
                $display("FAIL: engine_start and capture_activation overlap at %0t", $time);
                failures = failures + 1;
            end

            if (engine_start && done) begin
                $display("FAIL: engine_start and done overlap at %0t", $time);
                failures = failures + 1;
            end

            if (capture_activation && done) begin
                $display("FAIL: capture_activation and done overlap at %0t", $time);
                failures = failures + 1;
            end

            // Finalized handshake: done does not mean ready; busy stays high.
            if (done && !busy) begin
                $display("FAIL: done high while busy low at %0t", $time);
                failures = failures + 1;
            end

            // busy=0 means IDLE/ready, so no control pulse may be active.
            if (!busy && (engine_start || capture_activation || done)) begin
                $display("FAIL: control pulse active while busy=0 at %0t", $time);
                failures = failures + 1;
            end
        end
    end

    task expect_outputs;
        input exp_engine_start;
        input exp_capture;
        input exp_busy;
        input exp_done;
        input integer check_id;
        begin
            if (engine_start !== exp_engine_start ||
                capture_activation !== exp_capture ||
                busy !== exp_busy ||
                done !== exp_done) begin
                $display("FAIL check %0d at %0t: got es=%b cap=%b busy=%b done=%b; expected %b %b %b %b",
                         check_id, $time,
                         engine_start, capture_activation, busy, done,
                         exp_engine_start, exp_capture, exp_busy, exp_done);
                failures = failures + 1;
            end else begin
                $display("PASS check %0d at %0t: es=%b cap=%b busy=%b done=%b",
                         check_id, $time,
                         engine_start, capture_activation, busy, done);
            end
        end
    endtask

    // Drive one legal one-cycle external start request from IDLE.
    task issue_start;
        begin
            @(negedge clk);
            start = 1'b1;
            @(posedge clk);
            accepted_start_time = $time;
            #2;
            expect_outputs(1'b1, 1'b0, 1'b1, 1'b0, 100);
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    // Complete a transaction after an arbitrary number of WAIT_ENGINE cycles.
    // engine_done is asserted for exactly one clock interval.
    task finish_engine_after_wait;
        input integer wait_cycles;
        integer i;
        begin
            // First rising edge after LAUNCH moves the FSM to WAIT_ENGINE.
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 101);

            // Hold engine_done low and prove the FSM waits indefinitely.
            for (i = 0; i < wait_cycles; i = i + 1) begin
                @(posedge clk);
                #2;
                expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 102);
            end

            @(negedge clk);
            engine_done = 1'b1;

            // The edge sampling engine_done enters CAPTURE_ACTIVATION.
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 103);

            @(negedge clk);
            engine_done = 1'b0;

            // Next edge enters DONE. Output must already have been captured.
            @(posedge clk);
            observed_done_time = $time;
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b1, 104);

            // Next edge returns to IDLE/ready.
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 105);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = 1'b1;
        start = 1'b0;
        engine_done = 1'b0;

        failures = 0;
        engine_start_count = 0;
        capture_count = 0;
        done_count = 0;
        transaction_count = 0;
        capture_seen = 1'b0;
        accepted_start_time = 0;
        observed_done_time = 0;

        // ---------------------------------------------------------------------
        // Test 1: synchronous reset must force safe IDLE behavior.
        // ---------------------------------------------------------------------
        repeat (2) @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1);

        @(negedge clk);
        rst = 1'b0;

        // ---------------------------------------------------------------------
        // Test 2: IDLE must hold indefinitely when start=0.
        // ---------------------------------------------------------------------
        repeat (3) begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 2);
        end

        // ---------------------------------------------------------------------
        // Test 3: real-timing transaction.
        //
        // After engine_start is presented for one cycle, model the existing
        // registered convolution engine. Its own accepted-start -> generated
        // done latency is four periods. Since engine_done is a registered output,
        // drive it after the fourth engine period so this outer FSM observes it
        // on the following edge. Expected external start -> DONE = 70 ns.
        // ---------------------------------------------------------------------
        issue_start();

        // S1: controller enters WAIT_ENGINE and modeled engine accepts start.
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 3);

        // S2, S3, S4, S5: four engine periods while outer FSM waits.
        repeat (4) begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 4);
        end

        // Model registered engine_done becoming high after S5.
        @(negedge clk);
        engine_done = 1'b1;

        // S6: outer FSM observes engine_done and enters capture.
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 5);

        @(negedge clk);
        engine_done = 1'b0;

        // S7: enter DONE; measured start-to-DONE must be 70 ns.
        @(posedge clk);
        observed_done_time = $time;
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b1, 6);

        if ((observed_done_time - accepted_start_time) !== 70) begin
            $display("FAIL latency: expected 70 ns, measured %0t ns",
                     observed_done_time - accepted_start_time);
            failures = failures + 1;
        end else begin
            $display("PASS latency: external start -> done = %0t ns",
                     observed_done_time - accepted_start_time);
        end

        transaction_count = transaction_count + 1;

        // ---------------------------------------------------------------------
        // Test 4: start during DONE must be ignored.
        // busy is still high in DONE, so this request is illegal by contract.
        // ---------------------------------------------------------------------
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);   // DONE -> IDLE; request must not launch engine.
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 7);
        @(negedge clk);
        start = 1'b0;

        @(posedge clk);
        #2;
        if (engine_start_count !== 1) begin
            $display("FAIL: start during DONE produced extra engine launch");
            failures = failures + 1;
        end else begin
            $display("PASS: start during DONE was ignored");
        end

        // ---------------------------------------------------------------------
        // Test 5: start while WAIT_ENGINE is busy must be ignored.
        // Then complete the same transaction normally.
        // ---------------------------------------------------------------------
        issue_start();

        @(posedge clk);   // Enter WAIT_ENGINE.
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 8);

        // Illegal start pulse while busy.
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 9);
        @(negedge clk);
        start = 1'b0;

        if (engine_start_count !== 2) begin
            $display("FAIL: busy-time start created unexpected launch count=%0d",
                     engine_start_count);
            failures = failures + 1;
        end else begin
            $display("PASS: start while busy was ignored");
        end

        // Keep waiting for two more cycles to prove latency is not hard-coded.
        repeat (2) begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 10);
        end

        @(negedge clk);
        engine_done = 1'b1;
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 11);
        @(negedge clk);
        engine_done = 1'b0;

        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b1, 12);
        transaction_count = transaction_count + 1;

        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 13);

        // ---------------------------------------------------------------------
        // Test 6: legal new transaction after returning to IDLE.
        // No reset is required between transactions.
        // ---------------------------------------------------------------------
        issue_start();
        finish_engine_after_wait(1);
        transaction_count = transaction_count + 1;

        // ---------------------------------------------------------------------
        // Test 7: synchronous reset during WAIT_ENGINE must abandon transaction
        // and return directly to safe IDLE behavior.
        // ---------------------------------------------------------------------
        issue_start();
        @(posedge clk);   // Enter WAIT_ENGINE.
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 14);

        @(negedge clk);
        rst = 1'b1;
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 15);

        @(negedge clk);
        rst = 1'b0;

        // ---------------------------------------------------------------------
        // Final pulse-count checks.
        // Three transactions were completed. The fourth launch was reset before
        // completion, so it contributes one engine_start but no capture/done.
        // ---------------------------------------------------------------------
        if (engine_start_count !== 4) begin
            $display("FAIL pulse count: engine_start expected 4, got %0d",
                     engine_start_count);
            failures = failures + 1;
        end

        if (capture_count !== 3) begin
            $display("FAIL pulse count: capture_activation expected 3, got %0d",
                     capture_count);
            failures = failures + 1;
        end

        if (done_count !== 3) begin
            $display("FAIL pulse count: done expected 3, got %0d", done_count);
            failures = failures + 1;
        end

        if (transaction_count !== 3) begin
            $display("FAIL scoreboard: completed transactions expected 3, got %0d",
                     transaction_count);
            failures = failures + 1;
        end

        if (failures == 0)
            $display("PASS: control FSM sequencing, handshake, reset, pulse counts, and 70 ns timing verified.");
        else
            $display("FAIL: control FSM testbench detected %0d error(s).", failures);

        $finish;
    end

    // Simulation safety timeout.
    initial begin
        #2000;
        $display("FAIL: simulation timeout");
        $finish;
    end

endmodule
