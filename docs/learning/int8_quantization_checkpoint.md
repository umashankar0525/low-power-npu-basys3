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

The INT32 accumulator and the next INT8 activation do not necessarily use the same scale.

The accumulator represents a real value according to:

```text
y ≈ S_acc × acc
```

with:

```text
S_acc = S_a × S_w
```

Suppose the next layer stores its activation using scale `S_out`. Its integer output `q_out` must satisfy:

```text
y ≈ S_out × q_out
```

Equating the two real-value interpretations:

```text
S_out × q_out ≈ S_acc × acc
```

so:

```text
q_out ≈ (S_acc / S_out) × acc
```

and therefore:

```text
q_out ≈ (S_a × S_w / S_out) × acc
```

The result must then be rounded and clipped into the required INT8 range. For a ReLU output in the current symmetric baseline, negative values become zero and positive values are limited to the representable positive INT8 range.

### Why raw saturation can be wrong

Assume:

```text
S_acc = 0.001
acc   = 1000
```

Then the accumulator represents:

```text
y ≈ 0.001 × 1000 = 1.0
```

If the output activation scale is:

```text
S_out = 0.01
```

then the correct output integer is approximately:

```text
q_out = round(1.0 / 0.01)
      = 100
```

But directly saturating the raw accumulator integer `1000` to signed INT8 would produce `127`.

Those are different because `1000` is expressed in accumulator units, while the output INT8 must be expressed in output-activation units.

Requantization performs this conversion of units before the final INT8 representation is produced.

## Current hard gate

Before proceeding to `/design int8_quantization`, the learner must explain in their own words:

1. why directly clipping or saturating the raw INT32 accumulator can produce the wrong INT8 output, and
2. what requantization changes using the ratio `S_acc / S_out`.
