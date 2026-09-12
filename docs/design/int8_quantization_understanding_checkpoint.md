# INT8 Quantization — Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** DESIGN / UNDERSTANDING CHECK

## Assumptions

- Symmetric per-tensor activation quantization with scale `S_a`.
- Symmetric per-tensor weight quantization with scale `S_w`.
- Output activation uses scale `S_out`.
- Accumulator scale is `S_acc = S_a × S_w`.
- Four MAC lanes process the 3×3 convolution as 4 + 4 + 1 products.
- The third BRAM word zero-pads its three unused lanes.
- Requantization multiplier is positive because all scales are positive.

## Learner checkpoint

### 1. Why `S_a`, `S_w`, and `S_out` may differ

**Status: PASSED**

The learner correctly recognized that activations, weights, and outputs are separately quantized quantities and can therefore use different scale values. Their numerical dynamic ranges need not be equal.

### 2. Why the requantization multiplier is `S_a S_w / S_out`

**Status: PASSED WITH PRECISION NOTE**

The learner correctly recognized that multiplication combines the activation and weight scales. More precisely:

```text
S_acc = S_a × S_w
```

and converting an accumulator code into output-scale units requires division by `S_out`:

```text
M = S_acc / S_out
  = S_a × S_w / S_out
```

### 3. Why ReLU may be applied before requantization

**Status: NEEDS RESTATEMENT**

The key reason is that the requantization multiplier is positive:

```text
M = S_acc / S_out > 0
```

Multiplying by a positive number does not change the sign of the accumulator. Therefore:

```text
max(0, M × acc) = M × max(0, acc)
```

So a negative accumulator would remain negative after positive scaling and would still be removed by ReLU. Applying the sign check first does not change the mathematical result.

This also reduces unnecessary switching because negative values can bypass the multiplier path.

### 4. Why saturation must occur after requantization

**Status: PASSED**

The learner correctly recognized that direct saturation would clamp the raw accumulator code without first converting it into output-scale units. Requantization preserves the intended numerical meaning under `S_out`; only then should the result be limited to the representable INT8 output range.

### 5. Why the 3×3 data are packed as `4 + 4 + 1`

**Status: PASSED WITH PRECISION NOTE**

The learner correctly connected the schedule to the four available MAC lanes.

The precise reason for zero padding is not that a physically new single MAC would necessarily have to be added. The existing four-MAC datapath could process the ninth product using one lane, but without zero padding it would require a special-case data/control path for the final partial group.

By packing the final word as:

```text
A8, 0, 0, 0
W8, 0, 0, 0
```

only one lane contributes a nonzero product while the same four-lane datapath and reduction tree are reused unchanged. This avoids special-case arithmetic/control hardware and keeps the memory format regular.

## Current hard gate

Before proceeding to `/analyze int8_quantization`, the learner must restate in their own words:

1. why applying ReLU before the requantization multiplier gives the same mathematical result when the multiplier is positive, and
2. why zero padding the last BRAM word avoids special-case control/datapath handling rather than necessarily avoiding the addition of a separate physical MAC unit.
