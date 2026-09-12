# INT8 Quantization — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** TEACH / UNDERSTANDING CHECK

## Current checkpoint

The learner correctly recognized that an INT8 code alone is insufficient to recover the original floating-point numerical meaning.

A precision correction is required: the scale is not merely “how much the original number was decreased.” The scale is the amount of real numerical value represented by one integer step.

For symmetric quantization:

```text
x ≈ S × q
```

where:

- `x` is the real / FP32 value,
- `q` is the quantized integer value,
- `S` is the scale.

Example:

```text
q = 64
S = 0.01
x ≈ 64 × 0.01 = 0.64
```

The same integer code with another scale represents another real value:

```text
q = 64
S = 0.005
x ≈ 64 × 0.005 = 0.32
```

Therefore the numerical meaning is carried by the pair `(q, S)`, not by the INT8 code alone.

## Hard gate

Before proceeding to accumulator-scale derivation, the learner must restate in their own words:

1. what the scale represents, and
2. why the same INT8 code can represent different FP32 values when the scale changes.
