# INT8 Quantization — Testbench Generation Note

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 7 — TESTBENCH GENERATION  
**Status:** Testbench created; simulation not yet run

## 1. Objective

Create a directed Verilog unit testbench for `rtl/activation/requantize_relu.v` that exercises the arithmetic partitions defined in `docs/verification/int8_quantization.md` without claiming any simulation result yet.

The generated testbench is:

```text
tb/unit/tb_requantize_relu.v
```

## 2. Assumptions

- `requantize_relu.v` is combinational.
- Generated-data accumulator range remains bounded by the Phase 6 contract.
- Maximum legal positive accumulator is `145161`.
- `M_INT` is 24-bit unsigned.
- `FRAC_BITS` is a compile-time constant in `0..42`.
- XSim/Vivado 2018.2 compatibility is preferred, so the testbench uses straightforward Verilog constructs rather than relying on newer SystemVerilog-only features.
- No timing, DSP, LUT, or power conclusion can be drawn from this behavioral unit testbench.

## 3. Why Multiple DUT Instances Are Used

`M_INT` and `FRAC_BITS` are module parameters, so they are fixed at elaboration time for each instantiated DUT.

A single instance therefore cannot switch at runtime between all parameter combinations needed to isolate the arithmetic rules.

The testbench instantiates four versions of the same module:

```text
A: M_INT = 1,        FRAC_BITS = 0
B: M_INT = 1,        FRAC_BITS = 1
C: M_INT = 3,        FRAC_BITS = 2
D: M_INT = 0xFFFFFF, FRAC_BITS = 42
```

These represent:

```text
A: M = 1
B: M = 1/2
C: M = 3/4
D: maximum-width coefficient and shift stress
```

## 4. Configuration A — ReLU and Saturation

Configuration A removes fractional scaling:

```text
M_INT = 1
FRAC_BITS = 0
```

Therefore, for positive legal inputs:

```text
q_pre = acc
```

Directed checks are:

```text
-1      -> 0
0       -> 0
1       -> 1
126     -> 126
127     -> 127
128     -> 127
145161  -> 127
```

This isolates:

- negative ReLU behavior,
- zero handling,
- unsaturated pass-through,
- exact INT8 positive boundary,
- first value above the boundary,
- maximum legal positive accumulator.

The testbench also inspects internal DUT signals for selected cases, including `acc_positive`, `acc_mag`, `product`, and `q_pre_wide`.

## 5. Configuration B — Rounding

Configuration B uses:

```text
M_INT = 1
FRAC_BITS = 1
```

For positive inputs:

```text
q_pre = (acc + 1) >> 1
```

Directed cases:

```text
acc = 1 -> 1
acc = 2 -> 1
acc = 3 -> 2
acc = 4 -> 2
```

The important half-way cases are:

```text
0.5 -> 1
1.5 -> 2
```

For `acc = 3`, the testbench explicitly expects the internal sequence:

```text
product     = 3
rounded_num = 4
q_pre_wide  = 2
q_out       = 2
```

This directly checks the specified positive round-to-nearest behavior.

## 6. Configuration C — Non-Power-of-Two Scaling

Configuration C uses:

```text
M_INT = 3
FRAC_BITS = 2
```

so:

```text
M_hat = 3 / 4 = 0.75
```

Directed cases include:

```text
1   -> 1
2   -> 2
3   -> 2
5   -> 4
169 -> 127
170 -> 127
```

The pair `169` and `170` is particularly useful:

For `169`:

```text
product = 169 × 3 = 507
rounded = 507 + 2 = 509
q_pre   = 509 >> 2 = 127
```

For `170`:

```text
product = 170 × 3 = 510
rounded = 510 + 2 = 512
q_pre   = 512 >> 2 = 128
q_out   = 127 after saturation
```

This verifies both genuine multiply-plus-shift behavior and the saturation boundary after requantization.

## 7. Configuration D — Maximum-Width Arithmetic

The stress case is:

```text
acc       = 145161
M_INT     = 16777215
FRAC_BITS = 42
```

The expected internal values are fixed hand-derived constants:

```text
acc_mag = 145161

product
= 145161 × 16777215
= 2435397306615

rounding bias
= 2^41
= 2199023255552

rounded_num
= 2435397306615 + 2199023255552
= 4634420562167

q_pre
= 4634420562167 >> 42
= 1

q_out = 1
```

The testbench checks all of these values individually rather than only checking the final output.

This is important because a final `q_out = 1` alone would not reveal where a possible truncation occurred. Checking the 42-bit product and 43-bit rounded intermediate gives direct evidence about the intended width path.

## 8. X/Z Detection

The testbench uses case inequality (`!==`) for expected-output checks.

Therefore an unknown or high-impedance output does not accidentally compare equal to a known expected result.

Any `X` or `Z` on a checked signal causes that directed check to fail.

## 9. What Has Not Been Done Yet

No XSim run has been performed in this step.

Therefore this document does **not** claim:

- that the testbench compiles,
- that every case passes,
- that the DUT matches the expected values,
- that timing closes at 100 MHz,
- or that the predicted resource mapping is correct.

Those are Step 8 measurement tasks.

## 10. Step 8 Entry Condition

Before running simulation, the learner should understand why:

1. separate parameterized DUT instances are required when `M_INT` and `FRAC_BITS` are compile-time parameters, and
2. the maximum-width test checks the internal 42-bit product and 43-bit rounded value rather than only checking the final `q_out = 1`.
