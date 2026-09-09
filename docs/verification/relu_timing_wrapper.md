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

AMD Vivado documentation confirms that a rising-edge `always @(posedge CLK)` block with non-blocking assignments is a supported sequential coding form, and synchronous reset can be modeled inside the clocked block. citeturn1view0

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

## 8. Expected timing interpretation after implementation

Once an XDC constraint creates a 100 MHz clock, the important physical path is:

`accumulator_reg Q -> ReLU combinational logic -> output_activation D`

The setup requirement is derived from:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

with `Tclk = 10 ns`.

Positive setup slack means the path meets the 10 ns requirement. Negative setup slack means the path violates the 100 MHz requirement.

## 9. Pass criteria

The module passes verification only if:

- reset checks pass,
- every directed case passes,
- randomized comparisons pass,
- one-cycle latency is demonstrated explicitly,
- back-to-back samples remain correctly aligned,
- no unexpected X/Z values occur after reset,
- and the testbench reports zero mismatches.

A passing simulation is not yet a timing-closure result.

## 10. Next step

After this verification plan is understood, generate `tb/unit/tb_relu_timing_wrapper.v`, run it in Vivado XSim, and inspect the waveform edge-by-edge. Only after functional verification passes should the project proceed to an XDC constraint and implementation timing measurement.
