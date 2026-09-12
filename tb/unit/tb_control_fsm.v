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

            if (done && !busy) begin
                $display("FAIL: done high while busy low at %0t", $time);
                failures = failures + 1;
            end

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

    task finish_engine_after_wait;
        input integer wait_cycles;
        integer i;
        begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 101);

            for (i = 0; i < wait_cycles; i = i + 1) begin
                @(posedge clk);
                #2;
                expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 102);
            end

            @(negedge clk);
            engine_done = 1'b1;

            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 103);

            @(negedge clk);
            engine_done = 1'b0;

            @(posedge clk);
            observed_done_time = $time;
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b1, 104);

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

        repeat (2) @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 1);

        @(negedge clk);
        rst = 1'b0;

        repeat (3) begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 2);
        end

        issue_start();

        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 3);

        repeat (4) begin
            @(posedge clk);
            #2;
            expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 4);
        end

        @(negedge clk);
        engine_done = 1'b1;

        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 5);

        @(negedge clk);
        engine_done = 1'b0;

        @(posedge clk);
        observed_done_time = $time;
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b1, 6);

        if ((observed_done_time - accepted_start_time) !== 70) begin
            $display("FAIL latency: expected 70 ns, measured %0d ns",
                     observed_done_time - accepted_start_time);
            failures = failures + 1;
        end else begin
            $display("PASS latency: external start -> done = %0d ns",
                     observed_done_time - accepted_start_time);
        end

        transaction_count = transaction_count + 1;

        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
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

        issue_start();

        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 8);

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

        issue_start();
        finish_engine_after_wait(1);
        transaction_count = transaction_count + 1;

        issue_start();
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 14);

        @(negedge clk);
        rst = 1'b1;
        @(posedge clk);
        #2;
        expect_outputs(1'b0, 1'b0, 1'b0, 1'b0, 15);

        @(negedge clk);
        rst = 1'b0;

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

    initial begin
        #2000;
        $display("FAIL: simulation timeout");
        $finish;
    end

endmodule
