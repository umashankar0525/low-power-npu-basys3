# Verification Plan — `relu_timing_wrapper`

**Role:** Verification Engineer  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Clock assumption:** 100 MHz (10 ns period)

## 1. Verification objective

Verify that the timing wrapper correctly creates the intended synchronous boundary around the existing combinational `relu_activation` block:

`accumulator_input -> accumulator_reg -> ReLU + saturation -> output_activation`

The verification must establish both numerical correctness and cycle alignment. It must not claim physical timing closure; that requires implementation timing analysis with an XDC clock constraint.

## 2. Assumptions

- `clk` is the only clock.
- `rst` is synchronous and active high.
- `accumulator_input` represents a completed signed INT32 accumulator value.
- `relu_activation` is the previously verified combinational module.
- The wrapper uses non-blocking assignments in its clocked process.
- The intended data latency is **one clock cycle** from an input sample captured by `accumulator_reg` to the corresponding sample captured by `output_activation`.
- A 100 MHz clock has a 10 ns period.
- Behavioral simulation does not measure post-place-and-route propagation delay or setup slack.

## 3. Verification properties

### Property A — synchronous reset

When `rst=1` at a rising edge:
- `accumulator_reg` becomes 0.
- `output_activation` becomes 0.

### Property B — input capture

When `rst=0` at rising edge N:
- `accumulator_reg` captures `accumulator_input`.
- `output_activation` does **not** capture the new input's ReLU result at the same edge.

This distinction is important because both assignments are non-blocking.

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

The testbench must include at least:

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

The testbench should calculate the expected result independently rather than copying the RTL implementation structure.

Reference function:

1. Interpret the 32-bit value as signed.
2. If negative, expected = 0.
3. Else if greater than 127, expected = 127.
4. Else expected = input value.

The checker must compare the expected value for the **previously captured input sample**, not the current `accumulator_input` value.

## 5. Directed test sequence

1. Assert reset for at least one rising edge.
2. Verify both registered outputs are zero after the reset edge.
3. Release reset.
4. Apply one negative value and verify zero one cycle later.
5. Apply 0 and 127 to verify pass-through boundaries.
6. Apply 128 and a large positive value to verify saturation.
7. Apply consecutive different values to verify one-cycle pipeline alignment.
8. Apply minimum and maximum INT32 values.

## 6. Randomized verification

After directed tests, run a randomized set of signed INT32 accumulator values. Maintain a one-entry expected-value queue because the wrapper has one cycle of architectural data latency.

For every rising edge after the pipeline is primed:

`observed_output == reference(previous_cycle_input)`

A failing comparison must report:
- simulation time
- input sample used for the expected result
- expected output
- observed output
- reset state
- test index

## 7. What this simulation can prove

The simulation can prove:

- reset behavior
- correct signed interpretation
- ReLU behavior through the wrapper
- INT8 saturation behavior
- one-cycle pipeline alignment
- back-to-back transaction handling

The simulation **cannot** prove:

- actual ReLU propagation delay
- routing delay
- setup slack
- hold slack
- 100 MHz timing closure

Those require synthesis/implementation and a clock constraint.

## 8. Timing-wrapper latency derivation

The wrapper contains two registers in the same clocked process:

- `accumulator_reg <= accumulator_input`
- `output_activation <= relu_output`

Because these are non-blocking assignments, the right-hand sides are evaluated using the values that existed **before** the active clock edge.

Therefore, at edge N:

- `accumulator_reg` captures input X.
- `output_activation` captures the ReLU result of the **previous** `accumulator_reg` value.

During cycle N -> N+1, the new `accumulator_reg` value propagates combinationally through ReLU.

At edge N+1, `output_activation` captures `ReLU_saturate(X)`.

Thus the architectural latency is exactly **one clock cycle** from the input capture edge to the output capture edge.

The statement "the accumulator captures it at N-1" is therefore not the precise rule. The correct rule is: **the accumulator captures X at edge N, and the output register captures ReLU(X) at edge N+1.**

## 9. Observed simulation issue — testbench stopped at 1000 ns

The XSim run command uses:

`run 1000ns`

The current randomized test performs, for each of 100 values, two rising-edge waits before checking the result. With a 10 ns clock:

`2 edges/test x 10 ns/edge = 20 ns/test`

Therefore:

`100 tests x 20 ns/test = 2000 ns`

This is already twice the available 1000 ns simulation window, before adding reset, directed tests, and back-to-back tests.

Therefore, the message that XSim ran for 1000 ns does **not** mean the DUT failed to finish. It means the simulator was explicitly told to stop after 1000 ns, while the testbench requires more than 2000 ns for the randomized section alone.

A future run must either provide a sufficiently long simulation window or reduce the per-test waiting overhead. For verification, the cleaner solution is to drive inputs away from the active rising edge and then check the expected result exactly one cycle later, while allowing enough total simulation time for all 100 randomized transactions.

## 10. Observed functional failure — back-to-back first sample

The corrected run showed one important failure:

`FAIL: t=186000 input=-25 output=42 expected=0`

The expected result is 0 because -25 is negative. The observed 42 indicates that the testbench sampled the result corresponding to the next sample.

The DUT itself has the intended one-cycle register behavior. The problem is a **testbench race condition** in the back-to-back sequence.

The sequence currently changes `accumulator_input` immediately after `@(posedge clk)`. The DUT also executes its `always @(posedge clk)` process at that same simulation event. Both processes are scheduled in the same simulation time slot, so the testbench assignment and DUT register capture can occur in an ordering that is not safe to depend on.

That explains the observed value:

- Intended: edge N captures -25.
- Testbench immediately changes input to 42 at the same simulation time.
- If the testbench assignment is seen before the DUT samples its input, the DUT can capture 42 instead of -25.
- One cycle later, the output becomes 42, producing exactly the observed failure.

This is a verification stimulus problem, not evidence that the ReLU or wrapper datapath is incorrect.

## 11. Correct stimulus timing rule

The testbench must not change a synchronous input at the same active clock edge at which the DUT is expected to capture it.

Two safe approaches are:

1. Drive the input on the **falling edge** and let the next rising edge capture it.
2. Drive the input some nonzero simulation delay before the rising edge.

For this project, falling-edge stimulus is conceptually clean because it guarantees that the input is stable for half a clock period before the capture edge.

At 100 MHz:

`Tclk = 10 ns`

so falling-edge to rising-edge separation is:

`10 ns / 2 = 5 ns`

This gives the DUT a deterministic stimulus relationship in simulation.

## 12. Expected timing interpretation after implementation

Once an XDC constraint creates a 100 MHz clock, the important physical path is:

`accumulator_reg Q -> ReLU combinational logic -> output_activation D`

The setup requirement is derived from:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

with `Tclk = 10 ns`.

Positive setup slack means the path meets the 10 ns requirement. Negative setup slack means the path violates the 100 MHz requirement.

## 13. Pass criteria

The module passes verification only if:

- reset checks pass,
- every directed case passes,
- randomized comparisons pass,
- one-cycle latency is demonstrated explicitly,
- back-to-back samples remain correctly aligned,
- no unexpected X/Z values occur after reset,
- and the testbench reports zero mismatches.

A passing simulation is not yet a timing-closure result.

## 14. Current verification status

The latest observed run demonstrates that the basic wrapper behavior is largely correct: the directed signed/ReLU/saturation cases align correctly after the sampling correction, and the remaining mismatch is isolated to the back-to-back stimulus race.

The verification is therefore **not yet complete**. The next testbench revision should first eliminate the stimulus race, then run long enough to complete all 100 randomized tests. Only after zero mismatches are obtained should the project proceed to implementation timing measurement.

## 15. User understanding checkpoint

The user correctly identified the underlying verification rule: **a synchronous input must be stable before the capture edge; it should not be changed at the same active edge on which the DUT is expected to sample it.**

This is the key distinction between a deterministic synchronous testbench and a same-edge simulation race. The rule is not merely "do not change it exactly at the edge"; the stronger hardware concept is that the input must satisfy the receiving register's setup requirement before the edge. In behavioral simulation, driving on the falling edge provides a simple deterministic margin and avoids process-order races.

## 16. Next step

Revise the testbench stimulus/check timing to remove same-edge races, run the complete directed + back-to-back + 100-randomized suite, and inspect the waveform around the first back-to-back transaction. Only after zero mismatches are obtained should the project proceed to an XDC constraint and implementation timing measurement.
