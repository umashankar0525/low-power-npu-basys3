# INT8 Quantization — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** TEACH / UNDERSTANDING CHECK

## Assumptions

- Activations use one symmetric per-tensor scale `S_a`.
- Weights use one symmetric per-tensor scale `S_w`.
- The 3x3 convolution sums nine INT8×INT8 products into an INT32 accumulator.
- The next INT8 activation may use a different scale `S_out`.

## Checkpoint 1 — Scale meaning

**Status: PASSED**

The learner correctly restated that the scale tells us how much real numerical value an INT8 code represents, and that the same INT8 code can represent different FP32 values when the scale changes.

For symmetric quantization:

```text
x ≈ S × q
```

Therefore the numerical meaning is carried by the pair `(q, S)`, not by the INT8 code alone.

## Checkpoint 2 — Product and accumulator scale

**Status: PASSED**

The learner correctly restated that both the activation and weight already carry scale factors, so their multiplication also multiplies the scale factors.

Starting from:

```text
x ≈ S_a × q_a
w ≈ S_w × q_w
```

we obtain:

```text
xw ≈ (S_a × S_w)(q_a × q_w)
```

so:

```text
S_product = S_a × S_w
```

For the 3x3 convolution:

```text
acc = Σ(q_ai × q_wi)
```

and, under the stated per-tensor-scale assumption:

```text
y ≈ (S_a × S_w) acc
```

therefore:

```text
S_acc = S_a × S_w
```

## Checkpoint 3 — Why requantization is needed

**Status: PARTIAL — FINAL DISTINCTION STILL REQUIRED**

The learner now correctly understands why requantization cannot recover the exact original FP32 value: quantization has already introduced rounding and may also have introduced clipping, so information can be lost.

The remaining distinction is between saturation and requantization.

The accumulator represents a real value as:

```text
y ≈ S_acc × acc
```

while the output INT8 value must satisfy:

```text
y ≈ S_out × q_out
```

Therefore:

```text
q_out ≈ round((S_acc / S_out) × acc)
```

with:

```text
S_acc = S_a × S_w
```

### Saturation

Saturation only constrains an integer to the representable INT8 range. For the current post-ReLU signed-INT8 output contract:

```text
value < 0    -> 0
0..127       -> unchanged
value > 127  -> 127
```

It does not convert between two different numerical scales.

### Requantization

Requantization first converts the accumulator from `S_acc` units into `S_out` units using the ratio:

```text
S_acc / S_out
```

and then rounds and clips the resulting integer. Its goal is to make the output INT8 code represent approximately the same real quantity under the output scale.

### Example

Assume:

```text
S_acc = 0.001
acc   = 1000
S_out = 0.01
```

Then:

```text
y ≈ 0.001 × 1000 = 1.0
```

Requantization gives:

```text
q_out = round((0.001 / 0.01) × 1000)
      = 100
```

and `100 × 0.01 = 1.0` approximately preserves the real numerical meaning.

Direct saturation would instead turn raw integer `1000` into `127`, which would represent `1.27` under `S_out = 0.01` and therefore would not preserve the intended numerical value.

## Current hard gate

Before proceeding to `/design int8_quantization`, the learner must restate in their own words:

- saturation only limits a value to the allowed INT8 range;
- requantization changes the integer representation from accumulator scale `S_acc` to output scale `S_out` using `S_acc / S_out` before rounding/clipping;
- requantization is approximate because earlier quantization may already have lost information.
