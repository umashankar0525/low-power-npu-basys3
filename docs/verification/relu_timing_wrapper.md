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

The randomized test performs, for each of 100 values, two rising-edge waits before checking the result. With a 10 ns clock:

`2 edges/test x 10 ns/edge = 20 ns/test`

Therefore:

`100 tests x 20 ns/test = 2000 ns`

This is already twice the available 1000 ns simulation window, before adding reset, directed tests, and back-to-back tests.

Therefore, the message that XSim ran for 1000 ns does **not** mean the DUT failed to finish. It means the simulator was explicitly told to stop after 1000 ns, while the testbench requires more than 2000 ns for the randomized section alone.

A future run must either provide a sufficiently long simulation window or reduce the per-test waiting overhead. For verification, the cleaner solution is to drive inputs away from the active rising edge and then check the expected result exactly one cycle later, while allowing enough total simulation time for all 100 randomized transactions.

## 10. Observed functional failure — back-to-back first sample

The earlier corrected run showed one important failure:

`FAIL: t=186000 input=-25 output=42 expected=0`

The expected result is 0 because -25 is negative. The observed 42 indicates that the testbench sampled the result corresponding to the next sample.

The DUT itself has the intended one-cycle register behavior. The problem was a **testbench race condition** in the back-to-back sequence.

The sequence changed `accumulator_input` immediately after `@(posedge clk)`. The DUT also executes its `always @(posedge clk)` process at that same simulation event. Both processes are scheduled in the same simulation time slot, so the testbench assignment and DUT register capture can occur in an ordering that is not safe to depend on.

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

## 12. Latest simulation result — race condition eliminated

The updated testbench drives the synchronous input on `negedge clk` rather than changing it at the rising capture edge. The back-to-back sequence was also changed so every new sample is established before its intended capture edge.

The latest Vivado 2018.2 XSim run produced **zero failures** for every transaction that completed before the simulator's 1000 ns limit.

Observed result:

- Reset check: **PASS**
- Directed signed/ReLU/saturation checks: **8 PASS**
- Back-to-back pipeline alignment checks: **4 PASS**
- Randomized checks completed within the 1000 ns run: **39 PASS**
- Total completed checks: **52 PASS**
- Total failures: **0 FAIL**
- XSim reported time resolution: **1 ps**
- XSim run limit: **1000 ns**

The console ended at randomized test index `0x27` (decimal 39), which is consistent with 39 completed randomized checks. The final displayed pass count was `0x34` (decimal 52), matching:

`1 reset + 8 directed + 4 back-to-back + 39 randomized = 52 passes`

This is strong evidence that the numerical ReLU/saturation behavior and the one-cycle wrapper alignment are correct for the transactions actually exercised.

However, the verification suite is **not yet complete**, because the simulator stopped at 1000 ns before all 100 randomized tests could execute.

## 13. Timing interpretation after implementation

Once an XDC constraint creates a 100 MHz clock, the important physical path is:

`accumulator_reg Q -> ReLU combinational logic -> output_activation D`

The setup requirement is derived from:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

with `Tclk = 10 ns`.

Positive setup slack means the path meets the 10 ns requirement. Negative setup slack means the path violates the 100 MHz requirement.

## 14. Pass criteria

The module passes verification only if:

- reset checks pass,
- every directed case passes,
- randomized comparisons pass,
- one-cycle latency is demonstrated explicitly,
- back-to-back samples remain correctly aligned,
- no unexpected X/Z values occur after reset,
- and the testbench reports zero mismatches.

A passing simulation is not yet a timing-closure result.

## 15. Current verification status

**Functional status: PASS for all completed transactions.** The latest run eliminated the earlier `-25 -> 42` race and produced 52 passes with zero failures.

**Completion status: INCOMPLETE.** The run stopped at 1000 ns, so only 39 of the intended 100 randomized tests completed.

The next verification action is therefore not to change the DUT. The testbench stimulus timing is now deterministic. The remaining task is to rerun the same testbench with a simulation window long enough to complete all 100 randomized tests.

A conservative run command is:

`run 3000ns`

This provides enough time for the 2000 ns randomized portion plus reset and directed-test overhead. The exact required time can also be derived from the actual number of rising-edge waits in the testbench, but 3000 ns provides margin rather than relying on an exact boundary.

Only after the complete run reports zero mismatches should the project proceed to implementation timing measurement with the 100 MHz XDC constraint.

## 16. User understanding checkpoint

The user correctly identified the key timing relationship: **the accumulator captures an input at edge N, the value propagates through ReLU during cycle N to N+1, and the output register captures the ReLU result at edge N+1.**

The user also correctly identified that changing a synchronous input exactly at the capture edge can create a simulation race. Driving the input on the falling edge removes that ambiguity and provides a deterministic 5 ns stimulus-to-capture interval under the 100 MHz assumption.

## 17. Next step

Run the unchanged updated testbench for at least 3000 ns. Confirm that all 100 randomized transactions complete and that the final summary reports zero failures. Then the project can move from functional verification to implementation timing measurement.
