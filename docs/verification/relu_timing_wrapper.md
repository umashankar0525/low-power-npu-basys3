# Verification Plan — `relu_timing_wrapper`

**Role:** Verification Engineer  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Clock assumption:** 100 MHz (10 ns period)

## 1. Verification objective

Verify that the timing wrapper correctly creates the intended synchronous boundary around the existing combinational `relu_activation` block:

`accumulator_input -> accumulator_reg -> ReLU + saturation -> output_activation`

The verification establishes numerical correctness and cycle alignment. It does not claim physical timing closure; that requires implementation timing analysis with an XDC clock constraint.

## 2. Assumptions

- `clk` is the only clock.
- `rst` is synchronous and active high.
- `accumulator_input` represents a completed signed INT32 accumulator value.
- `relu_activation` is the previously verified combinational module.
- The wrapper uses non-blocking assignments in its clocked process.
- The intended data latency is one clock cycle from an input sample captured by `accumulator_reg` to the corresponding sample captured by `output_activation`.
- A 100 MHz clock has a 10 ns period.
- Behavioral simulation does not measure post-place-and-route propagation delay or setup slack.
- The corrected testbench drives synchronous inputs on the falling edge to avoid same-edge simulation races.

## 3. Verification properties

### Property A — synchronous reset

When `rst=1` at a rising edge:
- `accumulator_reg` becomes 0.
- `output_activation` becomes 0.

### Property B — input capture

When `rst=0` at rising edge N:
- `accumulator_reg` captures `accumulator_input`.
- `output_activation` does not capture the new input's ReLU result at the same edge.

### Property C — one-cycle ReLU latency

If `accumulator_input = X` is captured at edge N, then at edge N+1:

`output_activation = ReLU_saturate(X)`

where:
- X < 0 -> 0
- 0 <= X <= 127 -> X
- X >= 128 -> 127

### Property D — back-to-back samples

For inputs X0, X1, X2 presented on consecutive cycles, outputs must correspond to X0, X1, X2 on consecutive following cycles. This verifies that the wrapper behaves as a pipeline boundary rather than losing or duplicating samples.

### Property E — signed boundary correctness

The testbench includes:
- -2147483648 -> 0
- -1 -> 0
- 0 -> 0
- 1 -> 1
- 127 -> 127
- 128 -> 127
- 2147483647 -> 127

### Property F — no unknown outputs

After reset has been applied and released, the expected output must not contain X/Z for the tested transactions.

## 4. Independent reference model

The testbench calculates the expected result independently:

1. Interpret the 32-bit value as signed.
2. If negative, expected = 0.
3. Else if greater than 127, expected = 127.
4. Else expected = input value.

The checker compares the expected value for the previously captured input sample, not the current `accumulator_input` value.

## 5. Timing-wrapper latency derivation

The wrapper contains two registers:

- `accumulator_reg <= accumulator_input`
- `output_activation <= relu_output`

Because these are non-blocking assignments, at edge N:

- `accumulator_reg` captures input X.
- `output_activation` captures the ReLU result of the previous `accumulator_reg` value.

During cycle N -> N+1, the new `accumulator_reg` value propagates through the combinational ReLU logic.

At edge N+1, `output_activation` captures `ReLU_saturate(X)`.

Therefore the architectural latency is exactly one clock cycle.

## 6. Earlier simulation issue — same-edge stimulus race

The earlier run showed:

`FAIL: t=186000 input=-25 output=42 expected=0`

The observed 42 belonged to the previous sample. The root cause was changing `accumulator_input` immediately after `@(posedge clk)`, at the same simulation time as the DUT's clocked process.

This created an active-region simulation race: the testbench stimulus and DUT capture were both scheduled at the same edge, so the capture order was unsafe to depend on.

The testbench was corrected to establish synchronous input data on `negedge clk`, providing deterministic setup margin before the next rising capture edge.

At 100 MHz:

`Tclk = 10 ns`

and the falling-edge-to-rising-edge interval is:

`10 ns / 2 = 5 ns`

This is a simulation stimulus margin, not a claim about the FPGA's actual setup time.

## 7. Final simulation measurement

Vivado 2018.2 XSim successfully compiled and elaborated:

- `relu_activation`
- `relu_timing_wrapper`
- `tb_relu_timing_wrapper`

The corrected testbench was first run to 1000 ns and then continued with:

`run 3000ns`

The final run completed naturally with:

`PASS: relu_timing_wrapper verification completed with 113 passes and 0 failures.`

The testbench then called `$finish` at:

`2216 ns`

Therefore the complete test suite finished before the 3000 ns run limit.

## 8. Final functional results

| Verification item | Result |
|---|---:|
| Synchronous reset | PASS |
| Directed signed/ReLU/saturation cases | PASS |
| Back-to-back pipeline alignment | PASS |
| Randomized signed INT32 cases | PASS |
| Total checks | **113 PASS** |
| Failures | **0 FAIL** |
| Final `$finish` time | **2216 ns** |

Representative final checks include:

- -2147483648 -> 0
- -25 -> 0
- 42 -> 42
- 100 -> 100
- 200 -> 127
- large positive INT32 values -> 127
- large negative INT32 values -> 0

The previous `-25 -> 42` mismatch did not recur.

## 9. Why the 3000 ns run was required

The earlier `run 1000ns` command stopped before all randomized cases completed.

The randomized section uses approximately two rising-edge intervals per test:

`2 edges/test x 10 ns/edge = 20 ns/test`

For 100 randomized tests:

`100 x 20 ns = 2000 ns`

Adding reset and directed tests requires additional time, so `3000 ns` provides adequate margin.

The final `$finish` at 2216 ns confirms that the complete testbench actually executed.

## 10. What this simulation proves

The final simulation proves:

- synchronous reset behavior,
- signed INT32 interpretation,
- ReLU behavior,
- INT8 saturation behavior,
- one-cycle pipeline alignment,
- deterministic back-to-back operation,
- randomized functional behavior,
- zero mismatches across the completed suite.

The simulation does not prove:

- FPGA propagation delay,
- routing delay,
- setup slack,
- hold slack,
- 100 MHz implementation timing closure.

Those require synthesis/implementation with a real 100 MHz clock constraint.

## 11. Pass criteria

The functional verification pass criteria are satisfied:

- reset checks pass,
- all directed checks pass,
- back-to-back samples remain aligned,
- all 100 randomized transactions complete,
- zero failures are reported.

Therefore the **functional verification stage is PASS**.

Timing closure remains a separate task.

## 12. Current verification status

**Functional verification: COMPLETE — PASS.**

Measured result: **113 passes, 0 failures**.

The testbench race has been eliminated and all intended randomized transactions completed. No RTL change is required as a result of the earlier race.

The next project step is implementation timing measurement for the path:

`accumulator_reg Q -> relu_activation -> output_activation D`

using the actual 100 MHz XDC clock constraint.

## 13. Next step

Proceed to the implementation timing stage. Record worst-case setup slack, hold slack, and critical-path delay. Do not infer these values from the behavioral simulation.
