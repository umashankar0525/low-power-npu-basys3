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

**Status: NEEDS ONE PRECISION CORRECTION**

The learner correctly recognized that direct saturation of the raw accumulator is insufficient, but described requantization as a way to "get the original number." That is not exact.

The INT32 accumulator and the next INT8 activation can use different scales. The accumulator represents a real value as:

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

Requantization does **not** recover the original FP32 value exactly. Quantization has already introduced rounding and possibly clipping error. Requantization instead converts the accumulator integer from accumulator-scale units into output-scale units so that the new INT8 code represents approximately the same real quantity.

### Example

Assume:

```text
S_acc = 0.001
acc   = 1000
S_out = 0.01
```

The accumulator represents:

```text
y ≈ 0.001 × 1000 = 1.0
```

The correct output code is:

```text
q_out = round((0.001 / 0.01) × 1000)
      = 100
```

Directly saturating raw integer `1000` would instead produce `127`, which changes the represented real value.

## Current hard gate

Before proceeding to `/design int8_quantization`, the learner must restate this final distinction:

- saturation only limits an integer to the representable range;
- requantization first converts from accumulator scale `S_acc` to output scale `S_out` using `S_acc / S_out`;
- requantization preserves the real numerical meaning approximately, but does not reconstruct the exact original FP32 value.
