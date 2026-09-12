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

## Checkpoint 3 — Saturation versus requantization

**Status: PASSED**

The learner correctly restated the final distinction:

- **Saturation** only limits an integer to the allowed INT8 range.
- **Requantization** converts the accumulator from `S_acc` units to `S_out` units using the scale ratio before rounding and clipping.

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

Requantization does not reconstruct the exact original FP32 value because earlier quantization may already have introduced rounding or clipping error. Its purpose is to preserve the represented real quantity approximately while changing from accumulator-scale units to output-scale units.

## Teaching gate result

**TEACHING GATE: PASSED**

The learner has demonstrated understanding of:

1. why the pair `(q, S)` is required to interpret an INT8 value;
2. why the product and INT32 accumulator scale are `S_a × S_w` under the baseline per-tensor model;
3. why raw saturation alone is not a complete accumulator-to-output conversion;
4. how requantization uses `S_acc / S_out` before rounding and clipping;
5. why requantization is approximate rather than an exact reconstruction of the original FP32 value.

The module is now ready to move to the next mandatory workflow step:

```text
/design int8_quantization
```

No Python implementation or RTL modification should be generated until DESIGN and ANALYZE/PREDICT are completed and the learner confirms understanding.
