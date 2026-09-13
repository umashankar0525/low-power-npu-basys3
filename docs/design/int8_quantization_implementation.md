# INT8 Quantization — Step 5 Implementation Note

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** STEP 5 — IMPLEMENTATION  
**Status:** RTL and host-side reference helpers generated; verification has not started

## 1. Implemented files

This implementation step adds two code paths that follow the previously approved numerical contract:

```text
rtl/activation/requantize_relu.v
python/quantization/int8_quantizer.py
```

No simulation result, synthesis result, timing result, or resource measurement is claimed in this step.

## 2. Hardware module boundary

The new hardware block is a separate combinational module:

```text
requantize_relu
```

It accepts one completed signed INT32 convolution accumulator and produces one signed INT8 activation.

The existing convolution engine and Control FSM are not modified in this step.

The existing standalone `relu_activation.v` is also left unchanged because it remains valid for its original integer-only ReLU/saturation contract. The new module is the Phase 6 quantized-output path.

## 3. Hardware arithmetic implemented

The layer constants are parameters:

```text
M_INT     : 24-bit unsigned coefficient
FRAC_BITS : compile-time fractional shift, 0..42
```

They represent:

```text
M = S_acc / S_out
  = S_a S_w / S_out

M ~= M_INT / 2^FRAC_BITS
```

For a non-positive accumulator:

```text
q_out = 0
```

For a positive accumulator:

```text
product = acc_mag * M_INT
```

with widths:

```text
acc_mag    = 18 bits unsigned
M_INT      = 24 bits unsigned
product    = 42 bits unsigned
rounded    = 43 bits unsigned
```

If `FRAC_BITS > 0`, round-to-nearest is implemented as:

```text
rounded = product + 2^(FRAC_BITS - 1)
q_pre   = rounded >> FRAC_BITS
```

If `FRAC_BITS = 0`:

```text
q_pre = product
```

Final saturation is:

```text
q_out = min(q_pre, 127)
```

Because ReLU has already eliminated negative values, the output range is:

```text
0..127
```

## 4. Why the multiplier input is 18 bits

The approved Phase 6 generated-data contract restricts normal activation and weight codes to:

```text
[-127, +127]
```

Therefore one product magnitude is bounded by:

```text
127 x 127 = 16129
```

and the 3x3 positive convolution bound is:

```text
9 x 16129 = 145161
```

Since:

```text
2^17 < 145161 < 2^18
```

the post-ReLU positive magnitude fits in 18 unsigned bits.

The RTL therefore deliberately uses `acc_in[17:0]` only after confirming that the accumulator is positive.

**Contract limitation:** a positive accumulator above 145161 is outside the baseline Phase 6 generated-data contract. The module is not specified to preserve arbitrary out-of-contract positive INT32 values.

## 5. ReLU before requantization

The sign check is performed before multiplication.

This is mathematically valid because:

```text
M > 0
```

so multiplication by the requantization factor cannot change sign:

```text
max(0, M acc) = M max(0, acc)
```

The multiplier input is therefore forced to zero for non-positive accumulators. This preserves the numerical result and can reduce unnecessary switching activity.

## 6. Constant shift implementation

`FRAC_BITS` is a parameter, not a runtime input.

Therefore the right shift is a compile-time constant shift. This avoids introducing a general variable barrel-shifter requirement.

The module has two elaboration branches:

```text
FRAC_BITS = 0  -> no rounding bias and no shift
FRAC_BITS > 0  -> add 2^(F-1), then right shift by F
```

This also avoids an invalid negative shift expression when `FRAC_BITS = 0`.

## 7. Saturation test

After the rounded right shift, the output is non-negative.

A result is larger than 127 exactly when any bit at position 7 or above is set:

```text
|q_pre_wide[42:7] = 1
```

Therefore:

```text
upper bits set -> 127
otherwise      -> q_pre_wide[7:0]
```

## 8. Why the module remains combinational

The approved baseline design keeps the requantization path combinational so it can initially fit between the completed engine result and the existing activation-capture point without changing the Control FSM protocol.

The performance analysis identified a possible S6 pipeline opportunity, but that pipeline register is **not inserted yet**. Its need must be decided from measured timing, not guessed.

Therefore this implementation does not claim that the path meets the 10 ns period. Timing remains an unverified prediction.

## 9. Host-side quantization helpers

The Python implementation adds explicit functions for:

```text
round-to-nearest, ties away from zero
symmetric scale derivation
INT8 quantization
approximate dequantization
post-ReLU output scale derivation
fixed-point requantization parameter derivation
independent 3x3 integer convolution
software reference requantization + ReLU
4-lane INT8 packing
3x3 packing as 4 + 4 + 1
hexadecimal memory-word formatting
```

The Python code uses standard-library arithmetic rather than relying on Python's built-in `round()` as the specification.

## 10. Python rounding contract

Input quantization uses:

```text
value >= 0 : floor(value + 0.5)
value < 0  : ceil(value - 0.5)
```

This implements round-to-nearest with exact ties away from zero.

The positive post-ReLU requantization path uses the equivalent integer rule:

```text
(product + 2^(F-1)) >> F
```

for `F > 0`.

## 11. Scale handling

For a nonzero tensor:

```text
S = max(abs(x)) / 127
```

For an all-zero tensor:

```text
S = 1.0
all q = 0
```

The all-zero rule avoids division by zero while preserving the only meaningful represented value: zero.

## 12. Requantization parameter generation

Python computes:

```text
M = S_a S_w / S_out
```

and searches for the largest fractional shift up to the approved bound:

```text
F <= 42
```

such that:

```text
M_INT = round(M 2^F)
```

fits in the selected unsigned coefficient width.

For the baseline:

```text
coefficient width = 24 bits
M_INT <= 2^24 - 1
```

The returned metadata is:

```text
M, M_INT, F
```

so the same numerical parameters can later be used by the RTL instance and the independent reference model.

## 13. BRAM packing implementation

Four signed INT8 values are packed as:

```text
lane 0 -> bits [7:0]
lane 1 -> bits [15:8]
lane 2 -> bits [23:16]
lane 3 -> bits [31:24]
```

For nine values:

```text
word 0 -> values 0,1,2,3
word 1 -> values 4,5,6,7
word 2 -> value 8,0,0,0
```

Signed negative values are converted to their normal 8-bit two's-complement byte using the low eight bits before packing.

## 14. Independent-reference principle

The Python helper computes the integer convolution independently:

```text
acc_ref = sum(q_a[i] * q_w[i])
```

and computes the expected quantized output independently:

```text
if acc_ref <= 0:
    q_out_ref = 0
else:
    product = acc_ref * M_INT
    q_pre = rounded_right_shift(product, F)
    q_out_ref = min(q_pre, 127)
```

This is intentionally separate from RTL so later verification does not use the design under test to generate its own expected result.

## 15. What has not been done yet

The following are deliberately deferred to the next workflow stages:

```text
/verify int8_quantization
unit-test/testbench generation
XSim execution
Python reference tests
Vivado synthesis
DSP/LUT/FF measurement
setup/hold timing measurement
comparison against prediction
integration into a top-level accelerator
```

The next mandatory workflow step is `/verify int8_quantization` before any testbench or simulation is generated.
