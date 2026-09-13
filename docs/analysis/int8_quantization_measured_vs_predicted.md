# INT8 Quantization — Measured vs Predicted Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED  
**Status:** Functional behavioral measurements recorded; physical resource and timing measurements still pending

## 1. Objective

Compare the pre-implementation predictions in `docs/analysis/int8_quantization.md` against the measurements now available from the Step 8 Vivado XSim behavioral run.

This document intentionally separates two measurement classes:

1. **Functional numerical measurements**, which XSim can verify now.
2. **Physical implementation measurements**, such as DSP usage, LUT usage, critical-path delay, WNS, and TNS, which behavioral simulation cannot provide.

The Step 9 analysis is therefore only partially complete until the physical measurements are collected.

## 2. Assumptions

- Target FPGA remains XC7A35T-1CPG236C on Basys 3.
- Target clock remains 100 MHz, so the intended clock period is:

```text
Tclk = 1 / 100 MHz = 10 ns
```

- Generated INT8 activations and weights use `[-127, +127]`.
- One convolution contains nine INT8×INT8 products.
- ReLU is applied before fixed-point requantization.
- `M_INT` is a 24-bit unsigned compile-time parameter.
- `FRAC_BITS` is a compile-time parameter in `0..42`.
- The current `requantize_relu.v` block is combinational and contains no internal clocked register.
- The Step 8 evidence is behavioral XSim, not post-synthesis or post-route timing simulation.

## 3. Behavioral Measurement Summary

The XSim testbench completed at:

```text
23 ns
```

with:

```text
failures = 0
TB_REQUANTIZE_RELU_PASS: all directed checks passed
```

The directed checks exercised four parameter configurations:

```text
A: M_INT = 1,        FRAC_BITS = 0
B: M_INT = 1,        FRAC_BITS = 1
C: M_INT = 3,        FRAC_BITS = 2
D: M_INT = 0xFFFFFF, FRAC_BITS = 42
```

Across those configurations, the testbench produced 27 directed PASS checks and zero failures.

## 4. Prediction: Post-ReLU Magnitude Requires 18 Unsigned Bits

### Predicted

The maximum quantizer-generated positive convolution accumulator is:

```text
9 × 127 × 127 = 145161
```

Compare powers of two:

```text
2^17 = 131072
2^18 = 262144
```

Therefore:

```text
131072 < 145161 < 262144
```

so 17 unsigned bits are insufficient and 18 unsigned bits are sufficient.

### Measured

The maximum-width XSim case drove:

```text
acc_in = 145161
```

and observed:

```text
acc_positive = 1
acc_mag      = 145161
```

with the internal magnitude path passing exactly.

### Comparison

```text
Prediction: 145161 fits the selected 18-bit unsigned magnitude path.
Measured:   145161 propagated through acc_mag without truncation.
Result:     CONFIRMED functionally.
```

This does not prove that 145161 is the largest value a future generalized accelerator could produce; it confirms the present 3×3, one-channel contract.

## 5. Prediction: Raw Requantization Product Requires 42 Bits

### Predicted

Maximum legal positive accumulator:

```text
acc_max = 145161
```

Maximum 24-bit coefficient:

```text
M_INT_max = 2^24 - 1
          = 16777215
```

Exact maximum product:

```text
145161 × 16777215
= 2435397306615
```

Compare powers of two:

```text
2^41 = 2199023255552
2^42 = 4398046511104
```

Therefore:

```text
2^41 < 2435397306615 < 2^42
```

so the exact product requires 42 bits.

### Measured

The maximum-width XSim test observed exactly:

```text
product = 2435397306615
```

and the testbench explicitly checked that internal value rather than only checking the final INT8 output.

### Comparison

```text
Prediction: 42-bit product required.
Measured:   Exact maximum product preserved and matched.
Result:     CONFIRMED functionally.
```

## 6. Prediction: Rounding Intermediate Requires 43 Bits Conservatively

### Predicted

For `FRAC_BITS = 42`, round-to-nearest adds:

```text
2^(42-1) = 2^41
          = 2199023255552
```

The maximum-width test therefore expects:

```text
rounded_num
= 2435397306615 + 2199023255552
= 4634420562167
```

Because the 42-bit product can generate a carry when the rounding bias is added, the selected implementation uses a 43-bit rounding intermediate.

### Measured

XSim observed exactly:

```text
rounded_num = 4634420562167
```

followed by:

```text
q_pre = 1
q_out = 1
```

### Comparison

```text
Prediction: 43-bit intermediate safely preserves product + bias.
Measured:   Exact 43-bit expected value observed.
Result:     CONFIRMED functionally.
```

This is stronger evidence than checking only `q_out = 1`, because a large right shift can hide an internal truncation mistake.

## 7. Prediction: ReLU and Saturation Ordering

### Predicted

The selected order is:

```text
signed accumulator
 -> ReLU/sign test
 -> positive requantization
 -> rounding
 -> saturation to 127
```

### Measured

Identity configuration `M_INT=1`, `FRAC_BITS=0` produced:

```text
acc = -1      -> q_out = 0
acc = 0       -> q_out = 0
acc = 1       -> q_out = 1
acc = 126     -> q_out = 126
acc = 127     -> q_out = 127
acc = 128     -> q_out = 127
acc = 145161  -> q_out = 127
```

### Comparison

The negative path, zero path, normal positive range, exact 127 boundary, and first saturation value all matched the specification.

```text
Result: CONFIRMED functionally.
```

## 8. Prediction: Positive Round-to-Nearest Behavior

### Predicted

For:

```text
M_INT = 1
FRAC_BITS = 1
```

positive requantization is:

```text
q_pre = (acc + 1) >> 1
```

so:

```text
1 -> 1
2 -> 1
3 -> 2
4 -> 2
```

### Measured

XSim produced exactly those four results.

```text
Result: CONFIRMED functionally.
```

## 9. Prediction: Non-Power-of-Two Multiplication Is Required

### Predicted

For:

```text
M_INT = 3
FRAC_BITS = 2
```

we represent:

```text
M_hat = 3 / 4
      = 0.75
```

This configuration proves the datapath performs multiplication followed by shifting rather than behaving only as a power-of-two shifter.

### Measured

XSim reported:

```text
acc = 1   -> q_out = 1
acc = 2   -> q_out = 2
acc = 3   -> q_out = 2
acc = 5   -> q_out = 4
acc = 169 -> q_out = 127
acc = 170 -> q_out = 127
```

The two final cases exercise different internal paths:

```text
169 × 3 = 507
(507 + 2) >> 2 = 127
```

so 127 is reached naturally, while:

```text
170 × 3 = 510
(510 + 2) >> 2 = 128
```

so the final output reaches 127 only because saturation is activated.

```text
Result: CONFIRMED functionally.
```

## 10. Functional Prediction-versus-Measurement Table

| Item | Prediction | Behavioral measurement | Status |
|---|---|---|---|
| Maximum legal positive accumulator exercised | `145161` | `acc_mag = 145161` | Confirmed |
| Post-ReLU magnitude width | 18 unsigned bits | Maximum legal magnitude preserved | Confirmed functionally |
| Requantization multiply operands | 18-bit magnitude × 24-bit coefficient | Maximum legal operands exercised | Confirmed functionally |
| Raw product width | 42 bits | `2435397306615` matched exactly | Confirmed |
| Rounding intermediate | 43 bits conservative | `4634420562167` matched exactly | Confirmed |
| Maximum useful test shift | `F = 42` | `F=42` case produced exact expected result | Confirmed for tested boundary |
| ReLU negative handling | Negative accumulator -> 0 | `-1 -> 0` | Confirmed |
| Positive rounding | Round-to-nearest on positive path | Half-step tests all matched | Confirmed |
| Saturation boundary | `q_pre > 127 -> 127` | 169 natural 127, 170 internal 128 then saturation | Confirmed |
| Behavioral failures | 0 expected | `failures = 0` | Confirmed |

## 11. Physical Predictions That Are Still Unmeasured

The following original predictions remain unresolved:

| Physical item | Prediction | Current measurement status |
|---|---|---|
| DSP48E1 usage | 1 to 2 | Pending synthesis |
| LUTs outside multiplier | ~15–35 if DSP absorbs addition; ~60–80 if fabric addition | Pending synthesis |
| Additional BRAM | 0 expected | Pending synthesis confirmation |
| Combinational critical-path delay | Must fit within the relevant 10 ns registered path | Pending registered timing measurement |
| WNS | Must be >= 0 ns for setup closure | Pending implementation timing |
| TNS | Expected 0 if all setup paths pass | Pending implementation timing |
| External start-to-done latency | 70 ns if existing control schedule is preserved | Not measured in this standalone unit test |

## 12. Important Measurement Trap: Do Not Synthesize the Default Parameters and Treat Them as Final

The current module defaults are:

```text
M_INT = 1
FRAC_BITS = 0
```

If `requantize_relu` is synthesized as a standalone top with those defaults, the arithmetic simplifies to approximately:

```text
q_pre = acc_mag
```

The synthesis optimizer can remove or greatly simplify the intended wide constant multiplication and rounding logic.

Therefore a resource report from the default instance would **not** be a valid measurement of the intended nontrivial requantization datapath.

For a meaningful resource comparison, synthesis must use either:

```text
A. the actual final layer constants generated from the quantized data,
```

or, before those constants exist,

```text
B. an explicitly labeled representative nontrivial coefficient configuration.
```

The earlier analysis example used:

```text
M = 0.1
M_INT = 13421773
FRAC_BITS = 27
```

which is a reasonable representative case for exploratory synthesis, but it must not be mislabeled as the final layer-specific measurement.

## 13. Important Timing Trap: Standalone Combinational Synthesis Does Not Prove the 10 ns Path

`requantize_relu.v` is currently combinational. It has no input register, output register, or clock port.

Therefore synthesizing this module alone does not directly measure the intended system timing path:

```text
engine result register
 -> requantization logic
 -> activation capture register
```

The 100 MHz requirement is a **register-to-register timing requirement**.

A valid 10 ns timing measurement requires one of the following:

```text
1. the requantization block integrated between the real source and destination registers,
```

or

```text
2. a dedicated synthesis/timing harness containing representative source and destination registers clocked at 100 MHz.
```

Without one of those registered contexts, a standalone combinational timing report must not be interpreted as proof that the real accelerator closes timing at 100 MHz.

## 14. Step 9 Status

The functional part of measured-vs-predicted analysis is complete:

```text
18-bit positive magnitude prediction : confirmed
42-bit raw product prediction         : confirmed
43-bit rounding intermediate          : confirmed
ReLU behavior                         : confirmed
positive rounding behavior            : confirmed
saturation behavior                   : confirmed
maximum-width arithmetic              : confirmed
```

The physical part is still open:

```text
DSP count            : pending
LUT count            : pending
FF count             : pending
BRAM confirmation    : pending
critical-path delay  : pending
WNS/TNS              : pending
100 MHz closure      : pending
```

Therefore **Step 9 is IN PROGRESS, not complete**. Step 10 design review must not begin until the required physical measurements are collected and compared with the predictions.

## 15. Next Measurement Decision

Before running synthesis for final conclusions, the architecture needs a valid physical measurement context.

The next action should be to choose whether the measurement uses:

```text
actual layer-specific M_INT / FRAC_BITS
```

or a clearly labeled representative nontrivial configuration, and then place the combinational requantizer between source and destination registers for a meaningful 100 MHz timing measurement.

No DSP/LUT/timing conclusion should be recorded from the default `M_INT=1`, `FRAC_BITS=0` standalone top because that configuration can be optimized into a much simpler circuit and would bias the measured-vs-predicted comparison.