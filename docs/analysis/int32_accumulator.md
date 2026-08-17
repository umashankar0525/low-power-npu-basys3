# INT32 Accumulator — Pre-RTL Analysis

## Role
Performance Analyst.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Scope
Predict numerical behavior, cycle behavior, resource usage, timing implications, and power behavior for a clocked one-product-per-cycle signed INT32 accumulator.

## Assumptions

- Target clock is 100 MHz, so the clock period is 10 ns.
- The accumulator uses a 32-bit signed register.
- Reset is synchronous and active high.
- Enable is active high.
- One signed INT16 product is accepted per enabled cycle.
- The INT16 product is sign-extended to INT32 before addition.
- No saturation logic is included in this primitive.
- The DUT is written in Verilog-2001.

## Numerical Predictions

Each INT8 multiplication produces an INT16 value in:

-16256 <= product <= 16384

For nine products, the current 3x3 convolution sum is bounded by:

9 * (-16256) = -146304
9 * 16384 = 147456

Therefore the current convolution sum fits comfortably in signed INT32.

## State Predictions

On reset:

accumulator_next = 0

On enabled operation:

accumulator_next = accumulator_current + sign_extend(product_i)

On disabled operation:

accumulator_next = accumulator_current

The output therefore has one registered-cycle state update per enabled clock edge.

## Cycle Prediction

With one product accepted per cycle, accumulating nine products requires nine enabled clock edges after the accumulator is initialized/reset.

At 100 MHz:

Tclk = 1 / 100 MHz = 10 ns

Therefore the nine enabled accumulation updates occupy:

9 * 10 ns = 90 ns

This is a prediction for this primitive's one-product-per-cycle interface. It is NOT the predicted total latency of the eventual four-MAC convolution engine.

## Boundary Predictions

Starting from zero and applying nine maximum positive products:

0 + 9*16384 = 147456

Starting from zero and applying nine maximum negative products:

0 + 9*(-16256) = -146304

Both must be represented exactly in INT32.

## Resource Predictions

Expected state resources:

- 32 flip-flops for the accumulator register.
- No BRAM.
- No additional registers for this conceptual primitive.
- Adder logic required for the 32-bit addition.

Exact LUT count is implementation-dependent and must be measured after synthesis.

No DSP resource is required by the accumulator mathematically, although implementation mapping must be checked rather than assumed.

## Timing Prediction

The critical combinational path is expected to include:

sign extension -> 32-bit addition -> accumulator register setup

The exact delay and timing slack cannot be predicted numerically without synthesis/place-and-route data.

At 100 MHz, the available clock period is 10 ns. The implementation must satisfy the required setup timing within that period.

## Power Prediction

The accumulator register toggles only when enabled or reset according to the chosen control behavior. When `en=0` and reset is inactive, the register should hold its state, reducing unnecessary sequential switching.

The exact power consumption is implementation- and activity-dependent and must be measured later.

## Verification Predictions

The eventual testbench should verify:

1. Reset forces the accumulator to zero.
2. Enable adds one signed product each active edge.
3. Disable holds the previous value.
4. Positive and negative products accumulate correctly.
5. Sign extension is correct for negative products.
6. Maximum positive and negative nine-product sums are represented correctly.
7. Multiple reset/enable sequences behave deterministically.

## Next Gate

Before RTL generation, the designer must confirm these predictions and explain the difference between the nine-cycle prediction for this one-product interface and the eventual four-MAC convolution schedule.
