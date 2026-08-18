# INT32 Accumulator — Measured vs Predicted Analysis

## Role
Performance Analyst.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Scope
Compare pre-RTL predictions with the XSim behavioral simulation of the clocked one-product-per-cycle signed INT32 accumulator.

## Assumptions

- Target clock is 100 MHz, so the clock period is 10 ns.
- The accumulator uses a 32-bit signed register.
- Reset is synchronous and active high.
- Enable is active high.
- One signed INT16 product is accepted per enabled cycle.
- The INT16 product is sign-extended to INT32 before addition.
- No saturation logic is included in this primitive.
- The DUT is written in Verilog-2001.

## Predicted Numerical Range

Each INT8 multiplication produces an INT16 value in:

-16256 <= product <= 16384

For nine products, the current 3x3 convolution sum is bounded by:

9 * (-16256) = -146304
9 * 16384 = 147456

Therefore the current convolution sum fits comfortably in signed INT32.

## Measured Verification Result

XSim behavioral simulation reported:

- Checks performed: 28
- Errors found: 0
- Result: PASS
- Simulation finish time: 256 ns

The waveform shows the clock, reset, enable, product input, accumulator output, expected value, check count, and error count changing during the directed verification sequence.

The measured result agrees with the functional predictions: reset produced zero, enabled operations accumulated signed products, disabled operation held the accumulator, and the positive and negative nine-product boundary sequences matched the reference values.

## State Prediction vs Measurement

### Reset

Prediction:

accumulator_next = 0

Measurement:

PASS. The reset check completed with zero mismatches.

### Enabled accumulation

Prediction:

accumulator_next = accumulator_current + sign_extend(product_i)

Measurement:

PASS. Positive, negative, and mixed signed accumulation checks produced no errors.

### Disabled operation

Prediction:

accumulator_next = accumulator_current

Measurement:

PASS. The hold check produced no mismatch.

## Boundary Prediction vs Measurement

### Maximum positive sequence

Prediction:

0 + 9*16384 = 147456

Measurement:

PASS. Nine maximum positive products were checked at every accumulation step and the final expected value was 147456.

### Maximum negative sequence

Prediction:

0 + 9*(-16256) = -146304

Measurement:

PASS. Nine maximum negative products were checked at every accumulation step and the final expected value was -146304.

## Cycle Prediction vs Measurement

The design uses a 10 ns clock period, corresponding to the assumed 100 MHz target clock.

The accumulator accepts one product per enabled clock edge. Therefore a sequence of nine products requires nine enabled edges, corresponding to:

9 * 10 ns = 90 ns

The complete testbench finished at 256 ns because it includes reset, positive accumulation, hold, mixed-sign accumulation, a second reset, the positive boundary sequence, another reset, and the negative boundary sequence. Therefore the 256 ns total simulation time must not be interpreted as the latency of one nine-product accumulation.

## Resource Prediction Status

Functional simulation does not measure FPGA resources. The following remain implementation measurements:

- Exact flip-flop count after synthesis.
- Exact LUT count.
- DSP usage/mapping.
- Timing slack.
- Power.

The architectural prediction remains 32 bits of accumulator state, but the exact mapped FPGA resources must be obtained from Vivado synthesis/implementation reports.

## Timing Prediction Status

The available 100 MHz clock period is 10 ns. Behavioral simulation confirms the sequential function but does not provide post-synthesis timing.

Required future measurement:

- Worst negative slack (WNS).
- Total negative slack (TNS).
- Worst path delay.
- Whether the 100 MHz requirement is met.

## Power Prediction Status

Behavioral simulation verifies functional switching but does not provide an FPGA power estimate. Power remains a future implementation measurement using realistic activity information.

## Conclusion

The measured functional behavior matches the pre-RTL predictions for the tested state transitions and numerical boundaries. The INT32 accumulator primitive is therefore functionally verified in behavioral simulation.

The next phase is to perform implementation/resource analysis and then design the next architectural block. The 4-MAC scheduling problem remains separate from this primitive and must be derived before claiming a convolution latency.
