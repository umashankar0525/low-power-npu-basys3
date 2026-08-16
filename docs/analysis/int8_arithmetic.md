# INT8 Arithmetic — Analysis, Predictions, and Measured Results

## Role
Performance Analyst artifact.

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

There are 256 possible activation values and 256 possible weight values.

Therefore:

256 x 256 = 65,536

input combinations.

Prediction: exhaustive functional verification is practical.

## 5. Cycle Prediction

Because the proposed arithmetic block is combinational:

- Functional latency in clock cycles: 0 registered cycles.
- If surrounded by registers, the datapath can be treated as a single combinational stage between those registers.

At 100 MHz:

T_clock = 1 / 100 MHz = 10 ns

Prediction: the multiplier plus sign-extension logic must meet the timing budget assigned to its surrounding register-to-register path. Exact delay requires implementation measurement.

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

No numerical power value is predicted at this stage.

## 8. Measured Functional Result

### User-supplied Vivado/XSim run

- Vivado: 2018.2
- Simulation: Behavioral / Functional
- Time resolution: 1 ps
- Command: `restart` followed by `run 70 us`
- DUT and testbench compiled and elaborated successfully.
- Simulation completed successfully.

The final XSim console reported:

```text
INT8 ARITHMETIC EXHAUSTIVE VERIFICATION
Tests performed : 65536
Errors found    : 0
RESULT          : PASS
```

The simulator reported:

```text
$finish called at time : 65536 ns
```

The measured execution time agrees exactly with the testbench structure:

65,536 tests x 1 ns/test = 65,536 ns

### Measured vs predicted

| Metric | Prediction | Measurement | Status |
|---|---|---|---|
| Compilation | Successful | Successful | Confirmed |
| Elaboration | Successful | Successful | Confirmed |
| Exhaustive combinations | 65,536 | 65,536 | Confirmed |
| Errors | 0 | 0 | Confirmed |
| Functional result | PASS | PASS | Confirmed |
| Product range | -16256 to +16384 | All combinations passed reference comparison | Confirmed functionally |
| Sign extension | Value preserved | All combinations passed extension check | Confirmed functionally |
| Registered latency | 0 cycles | DUT is combinational | Confirmed architecturally |
| LUT usage | Unknown until synthesis | Not measured | Pending |
| FF usage | 0 expected in DUT | Not measured by synthesis | Pending |
| DSP usage | Unknown until synthesis | Not measured | Pending |
| Timing | Implementation-dependent | Not measured | Pending |
| Power | Implementation/activity-dependent | Not measured | Pending |

## 9. Interpretation

The functional prediction was correct: the RTL arithmetic block handled every possible signed INT8 input pair with zero mismatches.

This does **not** prove the block's FPGA resource mapping, timing, or power characteristics. Those remain implementation-level measurements.

## 10. Warning

Vivado reported that `int8_arithmetic.v` has no explicit timescale while another module has one. This is a simulation-unit consistency warning, not a functional failure. A future cleanup may add `` `timescale 1ns/1ps `` to the DUT.

## Status

**Functional verification: PASS — 65,536 / 65,536 combinations, 0 errors.**

**Implementation analysis: Pending synthesis/implementation measurements.**

## Next Step

Proceed to design review of `int8_arithmetic` before starting the next module. The review should check signedness, width choices, module boundaries, verification evidence, and remaining implementation assumptions.
