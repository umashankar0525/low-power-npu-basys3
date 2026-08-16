# INT8 Arithmetic — Pre-RTL Analysis, Predictions, and Measured Update

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

There are:

2^8 = 256

possible activation values and 256 possible weight values.

Therefore an exhaustive product test contains:

256 x 256 = 65,536

input combinations.

Prediction: a software reference model can evaluate all 65,536 combinations and compare them against the RTL output.

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

## 8. First Simulation Measurement

### Vivado/XSim run supplied by user

- Vivado 2018.2
- Behavioral/functional simulation
- Time resolution: 1 ps
- Simulation command ran for 1000 ns
- Compile completed successfully.
- Elaboration completed successfully.
- Simulation completed successfully for the requested 1000 ns window.

### Measured waveform evidence

The supplied waveform shows:

- `activation_i = 0x80`, interpreted as signed -128.
- `weight_i = 0x68`, interpreted as +104.
- `product_o = 0xCD38`, interpreted as -13000.
- `product_ext_o = 0xFFFFCD38`, interpreted as -13000.
- `errors = 0` over the observed interval.

Independent arithmetic check:

(-128) x 104 = -13312.

Therefore the displayed example must be interpreted carefully: the screenshot's displayed `weight_i` and product values do not appear to correspond to the same instant at the cursor because the waveform spans multiple transitions and the value panel is at the current cursor position. We should not use that screenshot alone to claim a specific operand/product pair is a verified simultaneous sample.

The stronger evidence is the testbench counters and final console summary.

### Coverage calculation

The testbench waits `#1` for each pair. The full exhaustive run requires:

65,536 x 1 ns = 65,536 ns = 65.536 us

The supplied run was only 1000 ns = 1 us.

Approximate maximum completed iterations during that window:

1000 ns / 1 ns per iteration = 1000 iterations

Therefore the run is partial, not exhaustive.

## 9. Measured vs Predicted Status

| Metric | Prediction | First measurement | Status |
|---|---|---|---|
| Compilation | Successful | Successful | Confirmed |
| Elaboration | Successful | Successful | Confirmed |
| Product range | -16256 to +16384 | Not exhaustively measured | Pending |
| Exhaustive combinations | 65,536 | ~1000-window coverage | Pending |
| Errors | 0 expected | No errors observed in shown interval | Partial confirmation |
| Registered latency | 0 cycles | Consistent with combinational DUT | Confirmed architecturally |
| LUT usage | Unknown until synthesis | Not measured | Pending |
| DSP usage | Unknown until synthesis | Not measured | Pending |
| Timing | Implementation-dependent | Not measured | Pending |
| Power | Implementation/activity-dependent | Not measured | Pending |

## 10. Warning

Vivado reported that `int8_arithmetic.v` has no explicit timescale while another module has one. This is a simulation-unit consistency warning, not a functional failure. A future cleanup may add `` `timescale 1ns/1ps `` to the DUT.

## 11. Required Next Measurement

Run the testbench for at least 70 us / 70,000 ns and capture the final console summary.

Expected final evidence:

- Tests performed: 65536
- Errors found: 0
- RESULT: PASS

Only after that result will exhaustive functional verification be marked complete.

## Status

**Functional verification status: PARTIAL — exhaustive run not yet completed.**
