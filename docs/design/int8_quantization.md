# INT8 Quantization — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** DESIGN

## 1. Objective

Define the numerical contract that connects floating-point neural-network data to the existing signed-INT8 FPGA convolution datapath and converts the INT32 convolution result into a correctly scaled signed-INT8 ReLU activation.

The design has two connected parts:

1. **Host-side quantization and memory-image generation** in Python.
2. **Hardware-side requantization + ReLU + saturation** after the INT32 convolution accumulator.

The design must preserve a clear numerical interpretation from FP32 values to INT8 BRAM contents, through INT8×INT8 multiplication and INT32 accumulation, and finally back to an INT8 activation.

## 2. Assumptions

- FPGA: XC7A35T-1CPG236C on Basys 3.
- Clock: 100 MHz, so `Tclk = 10 ns`.
- Convolution: 3×3.
- Input channels: 1.
- Output channels: 1.
- Activations: signed INT8.
- Weights: signed INT8.
- Products: signed INT16.
- Accumulator: signed INT32.
- Activation function: ReLU.
- The current convolution engine produces one completed INT32 accumulator result per transaction.
- The current memory datapath packs four INT8 lanes into one 32-bit word, with lane 0 in bits `[7:0]` and lane 3 in bits `[31:24]`.
- The current design has no bias term. Bias quantization is outside this module.
- Baseline quantization is **symmetric, per-tensor, zero-point = 0**.
- Normal quantizer-generated INT8 values use `[-127, +127]` rather than using `-128` as a normal symmetric code.
- Output after ReLU is therefore in signed-INT8 range `[0, 127]`.
- The scale parameters are determined offline in Python and are constant for a given generated test/model configuration.
- No floating-point arithmetic is implemented in FPGA logic.

## 3. Selected Quantization Scheme

Use symmetric per-tensor quantization:

```text
x ≈ S × q
```

where:

- `x` is the real / FP32 value,
- `q` is the signed integer representation,
- `S` is a positive scale.

For a nonzero tensor:

```text
S = max(|x|) / 127
```

The integer code is:

```text
q = clip(round_away_from_zero(x / S), -127, 127)
```

### All-zero tensor case

If:

```text
max(|x|) = 0
```

then division by zero must be avoided.

The selected rule is:

```text
S = 1.0
q = 0 for every element
```

The exact scale is irrelevant for an all-zero tensor because every represented real value is zero, but a defined nonzero scale keeps later equations valid.

## 4. Rounding Rule

The Python generator and hardware/reference model must not silently use different tie-breaking rules.

The selected input-quantization rule is **round to nearest, ties away from zero**:

For `r >= 0`:

```text
round_away_from_zero(r) = floor(r + 0.5)
```

For `r < 0`:

```text
round_away_from_zero(r) = ceil(r - 0.5)
```

This is chosen because it is explicit and easy to reproduce independently.

Python's built-in `round()` must not be relied on as the specification because its tie behavior can differ from this contract.

For the post-ReLU requantization path, the value is nonnegative, so round-to-nearest becomes:

```text
round_positive(r) = floor(r + 0.5)
```

## 5. Activation Quantization

Let FP32 activations be `a_i`.

Find:

```text
A_a = max(|a_i|)
```

For a nonzero activation tensor:

```text
S_a = A_a / 127
```

Then:

```text
q_ai = clip(round_away_from_zero(a_i / S_a), -127, 127)
```

The represented value is:

```text
a_i_hat = S_a × q_ai
```

The difference:

```text
a_i - a_i_hat
```

is the activation quantization error.

## 6. Weight Quantization

Let FP32 weights be `w_i`.

Find:

```text
A_w = max(|w_i|)
```

For a nonzero weight tensor:

```text
S_w = A_w / 127
```

Then:

```text
q_wi = clip(round_away_from_zero(w_i / S_w), -127, 127)
```

The represented value is:

```text
w_i_hat = S_w × q_wi
```

Activations and weights have independent scales because their real dynamic ranges need not match.

## 7. Product and Accumulator Scale Derivation

For one activation and one weight:

```text
a ≈ S_a q_a
w ≈ S_w q_w
```

Multiplication gives:

```text
a w ≈ (S_a q_a)(S_w q_w)
    ≈ (S_a S_w)(q_a q_w)
```

Therefore:

```text
S_product = S_a × S_w
```

For the 3×3 convolution:

```text
acc = Σ(q_ai q_wi), i = 0...8
```

and because all nine terms use the same per-tensor scales:

```text
y ≈ (S_a S_w) acc
```

Hence:

```text
S_acc = S_a × S_w
```

This scale belongs to the INT32 accumulator result even though the FPGA itself stores only the integer `acc`.

## 8. Integer Range Derivation

The symmetric quantizer normally generates:

```text
q ∈ [-127, 127]
```

The largest product magnitude is therefore:

```text
127 × 127 = 16129
```

A conservative bound for nine equal-sign products is:

```text
9 × 16129 = 145161
```

Check signed widths:

```text
18-bit signed range = -131072 ... +131071
```

which is insufficient because:

```text
145161 > 131071
```

while:

```text
19-bit signed range = -262144 ... +262143
```

which is sufficient.

The existing INT32 accumulator therefore has substantial headroom for this 3×3, one-channel design.

The RTL can still physically receive the INT8 code `-128`. If arbitrary external INT8 values are allowed instead of only quantizer-generated values, the previously derived conservative bound using magnitude 128 remains applicable. The Phase 6 generated data itself will use `[-127, 127]`.

## 9. Why the Existing ReLU/Saturation Block Is Not the Final Quantized Output Stage

The current ReLU block performs:

```text
acc < 0         -> 0
0 <= acc <= 127 -> acc
acc > 127       -> 127
```

That behavior is correct for its original integer contract, but it implicitly assumes that the accumulator and output activation use the same numerical scale.

A general quantized output instead needs:

```text
S_acc = S_a × S_w
```

and a potentially different output activation scale:

```text
S_out
```

The final output code must represent approximately the same real quantity:

```text
y ≈ S_acc × acc
```

and also:

```text
y ≈ S_out × q_out
```

Therefore:

```text
q_out ≈ (S_acc / S_out) × acc
```

followed by rounding and clipping.

The ratio:

```text
M = S_acc / S_out
```

is the requantization multiplier.

## 10. Output Scale Selection

The output scale is selected offline from representative post-ReLU FP32 output data.

Let:

```text
y_relu = max(0, y_fp32)
```

and let:

```text
A_out = max(y_relu)
```

across the chosen calibration / test set.

For a nonzero output range:

```text
S_out = A_out / 127
```

If every calibrated output is zero:

```text
S_out = 1.0
```

The important point is that `S_out` is a layer/output-tensor property, not a value recomputed independently for every single output sample. Recomputing the scale for each result would make output codes incomparable across samples and would not model a fixed quantized layer.

For unit tests, an explicit known `S_out` may be supplied so expected results can be hand-derived.

## 11. Selected Requantization Architecture

No FPGA floating-point unit will be used.

The offline Python flow converts the real multiplier:

```text
M = S_acc / S_out
```

into a fixed-point integer multiplier and shift:

```text
M ≈ M_int / 2^F
```

where:

```text
M_int = round(M × 2^F)
```

The FPGA computes, for a positive accumulator:

```text
scaled_num = acc × M_int
```

then performs round-to-nearest before the right shift:

```text
q_pre = (scaled_num + 2^(F-1)) >> F
```

for `F > 0`.

Finally:

```text
q_out = min(q_pre, 127)
```

Because ReLU removes negative values, the lower output bound is zero.

### Parameter generation

`M_int` and `F` are generated offline and treated as layer constants.

The baseline generator will choose the largest practical fractional shift `F` that keeps `M_int` inside the selected hardware coefficient width. A 24-bit unsigned coefficient is the initial design target; exact resource/timing consequences must be predicted in `/analyze` before RTL is generated.

This keeps the FPGA datapath integer-only while retaining substantially more precision than directly truncating or using only a power-of-two scale.

## 12. ReLU Placement Relative to Requantization

The requantization multiplier is positive because all scales are positive:

```text
M > 0
```

Therefore:

```text
max(0, M × acc) = M × max(0, acc)
```

So ReLU may mathematically be applied before the positive scaling operation.

The selected hardware ordering is:

```text
INT32 accumulator
       |
       v
   sign / ReLU check
       |
       +---- negative or zero ----> 0
       |
     positive
       |
       v
 fixed-point multiply by M_int
       |
       v
 rounding right shift by F
       |
       v
 saturate above 127
       |
       v
 signed INT8 output
```

This ordering has two advantages:

1. Negative accumulators do not need to toggle the multiplier datapath.
2. Rounding logic only needs to handle nonnegative values.

Both are useful for a low-power architecture.

## 13. Interaction With the Existing Control FSM

The current outer FSM has a `CAPTURE_ACTIVATION` state that captures a combinational activation result into an output register before entering `DONE`.

The selected baseline keeps requantization + ReLU combinational so that the existing supervisory state sequence does not need to change:

```text
engine result stable
      -> combinational ReLU/requantization
      -> CAPTURE_ACTIVATION register
      -> DONE
```

This preserves the current control protocol **only if** the new combinational path can meet the 100 MHz timing requirement.

At 100 MHz:

```text
Tclk = 1 / 100 MHz = 10 ns
```

No claim is made yet that the multiplier/rounding/saturation path meets 10 ns. That is an analysis and later synthesis/implementation measurement task.

If prediction or implementation shows that the path cannot meet timing, a pipeline register would be required and the Control FSM latency would have to be re-derived. That change is not made silently.

## 14. BRAM Packing Contract

The existing memory engine interprets a 32-bit word as:

```text
lane 0 = bits [7:0]
lane 1 = bits [15:8]
lane 2 = bits [23:16]
lane 3 = bits [31:24]
```

Therefore the Python generator must pack a 3×3 activation window as:

```text
Address 0:
[31:24] q_a3
[23:16] q_a2
[15:8]  q_a1
[7:0]   q_a0

Address 1:
[31:24] q_a7
[23:16] q_a6
[15:8]  q_a5
[7:0]   q_a4

Address 2:
[31:24] 0
[23:16] 0
[15:8]  0
[7:0]   q_a8
```

Weights use the same packing:

```text
Address 0: q_w0..q_w3
Address 1: q_w4..q_w7
Address 2: q_w8 plus three zero bytes
```

Negative INT8 values are stored as their normal 8-bit two's-complement byte representation.

The zero padding preserves the four-lane datapath and makes the third word contribute only product 8.

## 15. Host-Side Data-Generation Flow

The Phase 6 software flow will conceptually perform:

```text
FP32 activation calibration/test data
        |
        +--> derive S_a
        +--> quantize to INT8
        +--> pack into 32-bit BRAM words

FP32 weights
        |
        +--> derive S_w
        +--> quantize to INT8
        +--> pack into 32-bit BRAM words

FP32 reference convolution outputs
        |
        +--> ReLU
        +--> derive S_out from calibration set

S_a, S_w, S_out
        |
        +--> S_acc = S_a × S_w
        +--> M = S_acc / S_out
        +--> derive M_int and F
```

Generated artifacts should contain enough metadata to reproduce the numerical interpretation later. At minimum that means preserving:

```text
S_a
S_w
S_acc
S_out
M
M_int
F
```

alongside the INT8 / BRAM data.

## 16. Independent Integer Reference Model Contract

The Python reference path must calculate the same integer arithmetic independently of the RTL:

```text
acc_ref = Σ(q_ai × q_wi)
```

Then:

```text
if acc_ref <= 0:
    q_out_ref = 0
else:
    scaled_num = acc_ref × M_int
    q_pre = rounded_right_shift(scaled_num, F)
    q_out_ref = min(q_pre, 127)
```

This creates two useful references:

1. `acc_ref` for checking the convolution engine before activation.
2. `q_out_ref` for checking the full quantized activation output.

The FPGA must not be used as its own expected-value generator.

## 17. Error Sources Kept Separate

The design distinguishes three error mechanisms:

### Input quantization error

Produced when FP32 activation/weight values are rounded to INT8 levels.

### Requantization coefficient error

Produced because the real multiplier `M` is approximated by:

```text
M_int / 2^F
```

### Output rounding/clipping error

Produced when the scaled accumulator is rounded to the nearest output INT8 code and possibly saturated to 127.

Keeping these error sources separate is important because an RTL mismatch and an expected quantization approximation are not the same thing.

The `/analyze int8_quantization` step must predict the fixed-point multiplier approximation error before RTL generation.

## 18. Why Per-Tensor Quantization Is Selected First

Per-channel weight quantization can reduce numerical error in larger networks because each output channel can have its own weight scale.

The current architecture has only one output channel, so per-channel and per-tensor weight scaling provide no meaningful channel-selection advantage for this baseline.

Per-tensor quantization is therefore selected because it:

- matches the current one-channel architecture,
- uses one activation scale and one weight scale,
- avoids multiple scale-selection paths,
- keeps the first hardware requantization block understandable,
- still demonstrates the full scale/product/accumulator/requantization problem.

## 19. Design Decisions

The Phase 6 baseline design is therefore:

1. Symmetric signed INT8 quantization with zero-point 0.
2. Normal generated range `[-127, 127]`.
3. Per-tensor activation and weight scales.
4. Explicit round-to-nearest, ties away from zero for FP32-to-INT8 conversion.
5. INT32 accumulator scale `S_acc = S_a × S_w`.
6. Output scale `S_out` derived from representative post-ReLU FP32 output data or explicitly supplied for a test.
7. Fixed-point hardware requantization using `M_int` and right shift `F`.
8. ReLU/sign rejection before the positive fixed-point multiply.
9. Saturation to `[0, 127]` only after requantization.
10. Combinational requantization path initially, preserving the existing `CAPTURE_ACTIVATION` FSM state if timing permits.
11. Python generation of BRAM words matching the existing lane order exactly.
12. Independent Python calculation of both expected INT32 accumulator and expected INT8 final output.

## 20. What Is Intentionally Not Decided Yet

The following are not claimed as measured facts in the DESIGN step:

- exact LUT count,
- exact DSP count,
- exact combinational delay,
- exact timing slack,
- whether Vivado maps the constant multiplier into DSP48E1 resources or LUT logic,
- whether a pipeline register is eventually necessary,
- final fixed coefficient width if analysis shows a better resource/error tradeoff than the initial 24-bit target.

Those belong to `/analyze int8_quantization` and later synthesis/implementation measurement.

## 21. Design Understanding Gate

Before proceeding to `/analyze int8_quantization`, the learner must explain in their own words:

1. Why `S_a`, `S_w`, and `S_out` are separate scales.
2. Why the hardware requantization multiplier is `M = S_a S_w / S_out`.
3. Why the selected architecture applies the ReLU sign check before the fixed-point multiplier.
4. Why saturation must happen after requantization rather than directly on the raw INT32 accumulator.
5. How the nine INT8 values are packed into three 32-bit memory words, including why the final three lanes are zero-padded.

No quantization Python implementation or requantization RTL is generated until this design has been understood and the analysis/prediction step is complete.
