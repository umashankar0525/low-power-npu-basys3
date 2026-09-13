# INT8 Quantization — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** VERIFY  
**Status:** Verification plan only — testbench and simulation not yet generated or run

## 1. Verification Objective

Verify that the Phase 6 software and RTL implementation obey the numerical contract already derived in teaching, design, and prediction.

The implementation contains two independently important pieces:

1. `python/quantization/int8_quantizer.py` — software-side quantization, integer reference arithmetic, requantization, and BRAM packing.
2. `rtl/activation/requantize_relu.v` — hardware-side ReLU, fixed-point requantization, rounding, and INT8 saturation.

The verification strategy must not use the RTL itself to generate expected values. Expected results must be calculated independently from the documented equations and/or the Python reference model.

## 2. Assumptions

- Generated activations and weights use symmetric signed INT8 codes in `[-127, +127]`.
- One convolution contains nine products.
- Maximum quantizer-generated positive accumulator magnitude is:

```text
9 × 127 × 127 = 145161
```

- ReLU is applied before positive requantization.
- `M_INT` is a 24-bit unsigned compile-time constant.
- `FRAC_BITS` is a compile-time constant in `0..42`.
- For positive accumulator values:

```text
product = acc × M_INT
```

and, for `FRAC_BITS > 0`:

```text
q_pre = (product + 2^(FRAC_BITS-1)) >> FRAC_BITS
```

while for `FRAC_BITS = 0`:

```text
q_pre = product
```

- Final output is:

```text
q_out = 0                    when acc <= 0
q_out = q_pre                when 0 < q_pre <= 127
q_out = 127                  when q_pre > 127
```

- Physical timing closure, DSP count, LUT count, and power are not verified by behavioral simulation. Those remain later synthesis/implementation measurements.

## 3. Verification Layers

The verification is split into three layers so failures can be localized.

### Layer A — Python numerical contract

Check scale derivation, input rounding, clipping, convolution arithmetic, fixed-point parameter generation, requantization, and BRAM packing independently.

### Layer B — RTL unit verification

Verify `requantize_relu.v` directly with controlled accumulator inputs and known `M_INT` / `FRAC_BITS` parameters.

### Layer C — Cross-check

For selected legal cases, calculate the expected result with the Python reference and confirm that the RTL unit produces the same INT8 code.

The later integration test will additionally connect convolution output to this stage, but that is outside this unit-verification step.

## 4. Python Verification Cases

### 4.1 Symmetric scale derivation

For a tensor whose largest magnitude is `0.5`:

```text
S = 0.5 / 127
```

The test must confirm the implementation produces this value within normal floating-point tolerance.

For an all-zero tensor:

```text
[0, 0, 0, ...]
```

the selected design rule requires:

```text
S = 1.0
```

This avoids division by zero while preserving zero exactly.

### 4.2 Ties-away-from-zero rounding

Choose an explicit scale:

```text
S = 0.5
```

Then:

```text
+0.25 / 0.5 = +0.5 -> +1
-0.25 / 0.5 = -0.5 -> -1
+0.75 / 0.5 = +1.5 -> +2
-0.75 / 0.5 = -1.5 -> -2
```

This directly proves that positive and negative half-way cases are rounded away from zero rather than using banker's rounding.

### 4.3 Input clipping

With `S = 0.5`:

```text
+64 / 0.5 = +128 -> clip to +127
-64 / 0.5 = -128 -> clip to -127
```

This distinguishes quantizer clipping from normal rounding.

### 4.4 Integer 3×3 convolution

Use nine known activation/weight pairs and calculate:

```text
acc_ref = Σ(q_ai × q_wi)
```

independently by hand or by a separate test expression.

Boundary case:

```text
q_ai = 127 for all i
q_wi = 127 for all i
```

Then:

```text
acc_ref = 9 × 127 × 127
        = 145161
```

The Python reference must return exactly `145161`.

### 4.5 Requantization parameter generation

Representative case:

```text
M = 0.1
```

With a 24-bit coefficient and the largest fitting fractional precision:

```text
F = 27
M_INT = round(0.1 × 2^27)
      = 13421773
```

and `F = 28` must be rejected because the corresponding coefficient exceeds 24 bits.

### 4.6 BRAM packing

Use:

```text
[1, -1, 2, -2, 3, -3, 4, -4, 5]
```

The packed words must be:

```text
word 0 = 0xFE02FF01
word 1 = 0xFC04FD03
word 2 = 0x00000005
```

Derivation for word 0:

```text
lane 0 = +1  -> 0x01 -> bits [7:0]
lane 1 = -1  -> 0xFF -> bits [15:8]
lane 2 = +2  -> 0x02 -> bits [23:16]
lane 3 = -2  -> 0xFE -> bits [31:24]
```

This proves both lane order and two's-complement storage.

## 5. RTL Unit Verification Partitions

A single parameter set cannot exercise every useful fixed-point behavior cleanly, so the unit testbench should instantiate separate DUT configurations or run separate elaborations with known constants.

### Configuration A — Identity scaling

```text
M_INT = 1
FRAC_BITS = 0
```

Then, before saturation:

```text
q_pre = acc
```

This configuration isolates ReLU and saturation.

Required cases:

```text
acc = -1       -> q_out = 0
acc = 0        -> q_out = 0
acc = 1        -> q_out = 1
acc = 126      -> q_out = 126
acc = 127      -> q_out = 127
acc = 128      -> q_out = 127
acc = 145161   -> q_out = 127
```

#### Why each case matters

- `-1`: proves the sign/ReLU path forces negative values to zero.
- `0`: proves zero is also mapped to zero.
- `1`: proves a small positive value passes through.
- `126`: proves a legal unsaturated value is unchanged.
- `127`: proves the exact positive INT8 boundary remains representable.
- `128`: proves saturation begins immediately above the boundary.
- `145161`: proves the maximum legal positive accumulator reaches the saturation path without sign or magnitude corruption.

### Configuration B — Explicit rounding

```text
M_INT = 1
FRAC_BITS = 1
```

The equation becomes:

```text
q_pre = (acc + 1) >> 1
```

for positive `acc`.

Required cases:

```text
acc = 1 -> (1 + 1) >> 1 = 1
acc = 2 -> (2 + 1) >> 1 = 1
acc = 3 -> (3 + 1) >> 1 = 2
acc = 4 -> (4 + 1) >> 1 = 2
```

This verifies round-to-nearest for a positive half-step:

```text
1 / 2 = 0.5 -> 1
3 / 2 = 1.5 -> 2
```

and also verifies ordinary non-half values.

### Configuration C — Non-power-of-two multiplier

```text
M_INT = 3
FRAC_BITS = 2
```

This represents:

```text
M_hat = 3 / 4 = 0.75
```

Required hand-derived cases:

```text
acc = 1:
product = 3
q_pre = (3 + 2) >> 2 = 1

acc = 2:
product = 6
q_pre = (6 + 2) >> 2 = 2

acc = 3:
product = 9
q_pre = (9 + 2) >> 2 = 2
```

This proves the design is not accidentally behaving as only a power-of-two shifter.

### Configuration D — Maximum-width arithmetic

Use the maximum legal values from the Phase 6 contract:

```text
acc       = 145161
M_INT     = 16777215
FRAC_BITS = 42
```

Raw product:

```text
145161 × 16777215
= 2435397306615
```

The rounding bias is:

```text
2^41 = 2199023255552
```

Therefore:

```text
rounded_num
= 2435397306615 + 2199023255552
= 4634420562167
```

and:

```text
q_pre = 4634420562167 >> 42
      = 1
```

Expected output:

```text
q_out = 1
```

This case is especially important because it exercises:

- the full 18-bit legal accumulator magnitude,
- the full 24-bit coefficient,
- a 42-bit raw product,
- the high rounding-bias bit,
- the 43-bit rounding intermediate,
- and the largest allowed fractional shift.

A pass here gives strong evidence that no upper product or rounding bit was accidentally truncated.

## 6. Combinational Signal-by-Signal Expectations

`requantize_relu` is currently combinational, so behavioral verification must check the following logical sequence for every directed vector:

```text
acc_in
  |
  +--> acc_positive
  |
  +--> acc_mag (zero for non-positive values, lower 18 legal magnitude bits for positive values)
  |
  +--> product = acc_mag × M_INT
  |
  +--> product_ext
  |
  +--> rounding bias addition when FRAC_BITS > 0
  |
  +--> q_pre_wide after constant shift
  |
  +--> saturation test on bits [42:7]
  |
  +--> q_out
```

A final testbench pass is not enough by itself. During result review we must explain why each relevant internal transformation implies the observed `q_out` for every boundary class.

## 7. Contract-Violation Cases

The RTL baseline intentionally supports only positive accumulators up to `145161` after ReLU under the generated-data contract.

Therefore arbitrary positive INT32 inputs above that value are not valid functional test vectors for this version. Such values would be contract violations rather than required supported behavior.

Verification must not mistake an out-of-contract result for a valid architecture requirement.

Later, if the accelerator is generalized to more input channels or larger accumulation depth, the magnitude width and this verification plan must be re-derived.

## 8. Python-to-RTL Cross-Check

For selected legal parameter sets, the test flow should produce the expected output using the Python function:

```text
requantize_relu(accumulator, m_int, frac_bits)
```

and compare that value with XSim's RTL result.

The important independence rule is:

- Python and RTL may implement the same documented equation.
- Python must not read an RTL-produced expected value.
- The testbench must not simply copy the RTL expression verbatim and call it an independent reference.

For the strongest check, expected vectors can be generated by Python into a simple data file and consumed by the Verilog testbench.

## 9. Pass/Fail Criteria

The module passes functional unit verification only if:

- every directed Python numerical-contract test matches its hand-derived result;
- every RTL directed vector matches an independently derived expected INT8 result;
- negative and zero accumulators always produce zero;
- rounding half-step cases match the specified positive round-to-nearest rule;
- 127 is preserved and values above the output range saturate to 127;
- the maximum-width case produces the exact expected value without truncation;
- BRAM packing order and signed-byte representation match the memory-interface contract;
- no `X` or `Z` appears on `q_out` for valid known inputs and legal parameters.

A simple message such as `PASS` is not sufficient evidence by itself. The simulation report must record each input, expected output, observed output, and the reason the case exercises a specific boundary or arithmetic rule.

## 10. What Behavioral Simulation Cannot Prove

Even if every XSim case passes, behavioral simulation does not prove:

```text
DSP48E1 count
LUT count
FF count
10 ns setup closure
hold timing
maximum clock frequency
power
```

Those measurements must be performed later and compared with the `/analyze int8_quantization` predictions.

## 11. Testbench Gate

No testbench is generated in this verification-planning step.

Before proceeding to Step 7 testbench generation, the learner must be able to explain:

1. why we need separate tests for ReLU/saturation, rounding, and maximum-width arithmetic instead of only one normal positive value;
2. why the case `acc=145161`, `M_INT=16777215`, `FRAC_BITS=42` is valuable even though its final output is only `1`;
3. why comparing RTL against an independently calculated Python result is stronger than calculating the expected value by duplicating the RTL expression inside the Verilog testbench.
