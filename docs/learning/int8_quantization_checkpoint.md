# INT8 Quantization — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** TEACH / UNDERSTANDING CHECK

## Checkpoint 1 — Scale meaning

**Status: PASSED**

The learner correctly restated that the scale tells us how much real numerical value an INT8 code represents, and that the same INT8 code can represent different FP32 values when the scale changes.

For symmetric quantization:

```text
x ≈ S × q
```

where `x` is the real / FP32 value, `q` is the quantized integer value, and `S` is the scale.

Example:

```text
q = 64, S = 0.01  ->  x ≈ 0.64
q = 64, S = 0.005 ->  x ≈ 0.32
```

Therefore the numerical meaning is carried by the pair `(q, S)`, not by the INT8 code alone.

## Checkpoint 2 — Product and accumulator scale

Consider a quantized activation and weight:

```text
x ≈ S_a × q_a
w ≈ S_w × q_w
```

Multiplying them gives:

```text
xw ≈ (S_a × q_a)(S_w × q_w)
   ≈ (S_a × S_w)(q_a × q_w)
```

Therefore the integer product `q_a × q_w` represents a real quantity with scale:

```text
S_product = S_a × S_w
```

For the 3x3 convolution:

```text
acc = Σ(q_ai × q_wi),  i = 0...8
```

If the same activation scale `S_a` and weight scale `S_w` apply to all nine terms, then:

```text
y ≈ Σ[(S_a × q_ai)(S_w × q_wi)]
  ≈ (S_a × S_w) Σ(q_ai × q_wi)
  ≈ (S_a × S_w) acc
```

Hence:

```text
S_acc = S_a × S_w
```

### Numerical example

Assume:

```text
S_a = 0.02
S_w = 0.05
q_a = 10
q_w = 4
```

Then the represented real activation and weight are:

```text
x ≈ 0.02 × 10 = 0.20
w ≈ 0.05 × 4  = 0.20
```

Their real product is:

```text
xw ≈ 0.20 × 0.20 = 0.04
```

The hardware integer product is:

```text
q_a × q_w = 10 × 4 = 40
```

and its scale is:

```text
S_a × S_w = 0.02 × 0.05 = 0.001
```

so:

```text
40 × 0.001 = 0.04
```

The integer multiplier therefore produces the integer `40`; the scale product `0.001` tells us what that integer means in the real-value domain.

## Current hard gate

Before proceeding to requantization, the learner must explain in their own words why multiplying an activation with scale `S_a` by a weight with scale `S_w` causes the product and INT32 accumulator to have scale `S_a × S_w`.
