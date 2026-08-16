# INT8 Arithmetic — Pre-RTL Analysis and Predictions

## Role
Performance Analyst artifact. This document contains predictions only; no simulation measurements have been performed yet.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Assumptions

- Target FPGA: XC7A35T-1CPG236C (Artix-7)
- Target clock: 100 MHz
- Arithmetic block is combinational for this first design.
- Operands are signed two's-complement INT8.
- Product is signed INT16.
- Product is sign-extended to signed INT32.
- Vivado synthesis and implementation settings can affect exact mapped resources and timing.
- Exact FPGA resource/timing numbers are therefore predictions, not measurements.

## 1. Numerical Predictions

INT8 range:

-128 <= x <= +127

Extreme products:

(-128)(-128) = +16384
(-128)(+127) = -16256
(+127)(+127) = +16129

Therefore predicted product range:

-16256 <= p <= +16384

INT16 range:

-32768 <= p <= +32767

Prediction: every possible INT8 x INT8 product fits in INT16 without overflow.

For the current 3x3 convolution:

9 x 16384 = 147456

INT18 maximum = 131071, so INT18 is insufficient.
INT19 maximum = 262143, so INT19 is sufficient for the current worst-case positive sum.

The architectural accumulator remains INT32 for headroom.

## 2. Boundary Test Vectors

These are predicted expected results and should become unit-test cases later.

| activation | weight | expected INT16 product | expected sign |
|---:|---:|---:|---|
| 0 | 0 | 0 | positive/zero |
| 1 | 1 | 1 | positive |
| -1 | 1 | -1 | negative |
| 1 | -1 | -1 | negative |
| -1 | -1 | 1 | positive |
| 127 | 127 | 16129 | positive |
| -128 | 127 | -16256 | negative |
| 127 | -128 | -16256 | negative |
| -128 | -128 | 16384 | positive |
| 0 | -128 | 0 | zero |

Prediction: all vectors above produce exact mathematical results with no product overflow.

## 3. Sign-Extension Predictions

Positive example:

INT16 16384 = `0100_0000_0000_0000`

Expected INT32 extension:

`0000_0000_0000_0000_0100_0000_0000_0000`

Negative example:

INT16 -16256 = `1100_0000_1000_0000`

Expected INT32 extension copies the sign bit into the upper 16 bits:

`1111_1111_1111_1111_1100_0000_1000_0000`

Prediction: sign extension preserves the numerical value exactly.

## 4. Exhaustive Verification Prediction

There are:

2^8 = 256

possible activation values and 256 possible weight values.

Therefore an exhaustive product test contains:

256 x 256 = 65,536

input combinations.

Prediction: a software reference model can evaluate all 65,536 combinations and compare them against the RTL output. This is small enough to be practical and provides stronger confidence than a handful of directed vectors.

## 5. Cycle Prediction

Because the proposed arithmetic block is combinational:

- Functional latency in clock cycles: 0 registered cycles.
- If surrounded by registers, the datapath can be treated as a single combinational stage between those registers.

At 100 MHz:

T_clock = 1 / 100 MHz = 10 ns

Prediction: the multiplier plus sign-extension logic must meet the timing budget assigned to its surrounding register-to-register path. The exact delay cannot be honestly predicted from arithmetic alone because FPGA mapping and synthesis determine the implementation.

## 6. Resource Prediction

The block requires one signed 8x8 multiplication operation and simple wiring for sign extension.

Prediction before synthesis:

- No flip-flops are required by the pure combinational arithmetic itself.
- No BRAM is required.
- No DSP count is guaranteed from RTL alone; Vivado may infer a DSP48-based multiplier or implement multiplication using LUT-based logic depending on synthesis settings and constraints.
- Sign extension should require essentially routing/wiring rather than a large arithmetic resource.

Exact LUT, FF, DSP, timing, and power values must be measured after synthesis/implementation.

## 7. Power Prediction

Dynamic power is strongly related to switching activity and capacitance. A combinational multiplier can have substantial internal switching when its operands change.

Prediction:

- Holding operands stable should reduce switching after transient propagation.
- Unnecessary toggling at the multiplier inputs will propagate through the datapath.
- Clock gating is not applicable to the pure combinational block itself; later architecture should consider operand isolation or clock enables around registered stages if measurements justify them.

No numerical power value is predicted at this stage because FPGA power depends on activity, implementation, clocking, and device conditions.

## 8. Expected Failure Modes

The most likely arithmetic failures are:

1. Treating operands as unsigned.
2. Incorrect two's-complement interpretation.
3. Truncating the product to 8 bits.
4. Incorrect sign extension from 16 to 32 bits.
5. Confusing bit patterns with signed numerical values.
6. Testing only positive values and missing negative boundary cases.

## 9. Measurement Plan

After RTL and verification are permitted, collect:

- Functional correctness over all 65,536 input combinations.
- Post-synthesis LUT usage.
- Flip-flop usage.
- DSP usage.
- Worst negative slack / timing result.
- Maximum combinational delay of the relevant path.
- Power estimate if a suitable Vivado power flow is available.

Then update this document with a measured-vs-predicted table. Predictions must remain unchanged in the prediction section so that deviations can be analyzed rather than hidden.

## Prediction Gate

No RTL or simulation should begin until the learner confirms the expected numerical, cycle, resource, and verification behavior described here.
