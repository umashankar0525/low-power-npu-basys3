`timescale 1ns / 1ps

// Verification testbench for memory_interface_dataflow.
// The behavioral memories intentionally model one-cycle synchronous read latency.
module tb_memory_interface_dataflow;

    reg clk;
    reg rst;
    reg start;

    wire        activation_rd_en;
    wire [1:0]  activation_addr;
    reg  [31:0] activation_data;

    wire        weight_rd_en;
    wire [1:0]  weight_addr;
    reg  [31:0] weight_data;

    wire        done;
    wire signed [31:0] result;

    reg [31:0] activation_mem [0:2];
    reg [31:0] weight_mem     [0:2];

    integer cycle_count;
    integer request_count;
    integer error_count;

    memory_interface_dataflow dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .activation_rd_en(activation_rd_en),
        .activation_addr(activation_addr),
        .activation_data(activation_data),
        .weight_rd_en(weight_rd_en),
        .weight_addr(weight_addr),
        .weight_data(weight_data),
        .done(done),
        .result(result)
    );

    // 100 MHz clock: 10 ns period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // One-cycle synchronous activation memory model.
    // At a rising edge, the requested address is captured and its data is
    // placed on activation_data using a nonblocking assignment. The DUT's
    // sequential logic therefore cannot consume the newly returned value
    // until the following clock edge.
    always @(posedge clk) begin
        if (activation_rd_en)
            activation_data <= activation_mem[activation_addr];
    end

    // One-cycle synchronous weight memory model.
    always @(posedge clk) begin
        if (weight_rd_en)
            weight_data <= weight_mem[weight_addr];
    end

    // Cycle counter and request checks.
    always @(posedge clk) begin
        cycle_count <= cycle_count + 1;

        if (activation_rd_en || weight_rd_en) begin
            request_count <= request_count + 1;

            if (activation_addr !== weight_addr) begin
                $display("ERROR: activation/weight address mismatch at cycle %0d", cycle_count);
                error_count <= error_count + 1;
            end
        end
    end

    task check;
        input condition;
        input [255:0] message;
        begin
            if (!condition) begin
                $display("ERROR: %0s at cycle %0d", message, cycle_count);
                error_count = error_count + 1;
            end
        end
    endtask

    initial begin
        cycle_count  = 0;
        request_count = 0;
        error_count  = 0;
        start = 1'b0;
        rst = 1'b1;
        activation_data = 32'd0;
        weight_data = 32'd0;

        // Word 0: 10 * 1 = 10, remaining lanes zero.
        activation_mem[0] = {8'd0, 8'd0, 8'd0, 8'd10};
        weight_mem[0]     = {8'd0, 8'd0, 8'd0, 8'd1};

        // Word 1: 20 * 1 = 20, remaining lanes zero.
        activation_mem[1] = {8'd0, 8'd0, 8'd0, 8'd20};
        weight_mem[1]     = {8'd0, 8'd0, 8'd0, 8'd1};

        // Word 2: 30 * 1 = 30, remaining lanes zero.
        activation_mem[2] = {8'd0, 8'd0, 8'd0, 8'd30};
        weight_mem[2]     = {8'd0, 8'd0, 8'd0, 8'd1};

        // Hold reset for two rising edges.
        @(posedge clk);
        @(posedge clk);
        #1;
        check(done === 1'b0, "done asserted during reset");
        check(result === 32'sd0, "result changed during reset");

        rst = 1'b0;

        // Start transaction. start is sampled at the next rising edge.
        start = 1'b1;
        @(posedge clk); // Edge 1: request word 0.
        #1;
        start = 1'b0;

        check(activation_rd_en === 1'b1, "word 0 read was not requested");
        check(activation_addr === 2'd0, "first address was not 0");
        check(weight_addr === 2'd0, "first weight address was not 0");
        check(dut.accumulator === 32'sd0, "accumulator was not cleared at start");

        @(posedge clk); // Edge 2: request word 1; word 0 becomes valid after edge.
        #1;
        check(activation_rd_en === 1'b1, "word 1 read was not requested");
        check(activation_addr === 2'd1, "second address was not 1");
        check(activation_data === activation_mem[0], "word 0 did not return after one cycle");
        check(weight_data === weight_mem[0], "weight word 0 did not return after one cycle");
        check(dut.accumulator === 32'sd0, "word 0 was consumed too early");

        @(posedge clk); // Edge 3: consume word 0; request word 2; word 1 returns after edge.
        #1;
        check(activation_rd_en === 1'b1, "word 2 read was not requested");
        check(activation_addr === 2'd2, "third address was not 2");
        check(dut.accumulator === 32'sd10, "word 0 partial sum was not captured as 10");
        check(activation_data === activation_mem[1], "word 1 did not return after one cycle");
        check(weight_data === weight_mem[1], "weight word 1 did not return after one cycle");

        // Attempt a new start while the DUT is busy. It must not corrupt the active transaction.
        start = 1'b1;
        @(posedge clk); // Edge 4: consume word 1; word 2 returns after edge.
        #1;
        start = 1'b0;
        check(dut.accumulator === 32'sd30, "word 1 partial sum was not accumulated correctly");
        check(activation_data === activation_mem[2], "word 2 did not return after one cycle");
        check(weight_data === weight_mem[2], "weight word 2 did not return after one cycle");
        check(done === 1'b0, "done asserted before final word");

        @(posedge clk); // Edge 5: consume word 2, register result, assert done.
        #1;
        check(done === 1'b1, "done was not asserted after final word");
        check(result === 32'sd60, "final result was not 60");
        check(request_count === 3, "unexpected number of memory request cycles");
        check(activation_addr === 2'd2, "final address changed unexpectedly");

        @(posedge clk);
        #1;
        check(done === 1'b0, "done was not a one-cycle pulse");
        check(result === 32'sd60, "result was not retained after completion");

        if (error_count == 0)
            $display("PASS: memory latency, address sequencing, accumulation, and completion timing verified.");
        else
            $display("FAIL: %0d verification error(s).", error_count);

        $finish;
    end

endmodule
