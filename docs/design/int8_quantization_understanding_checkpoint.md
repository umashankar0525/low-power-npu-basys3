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

**Status: PASSED**

The learner correctly recognized that multiplication combines the activation and weight scales:

```text
S_acc = S_a × S_w
```

and converting an accumulator code into output-scale units requires division by `S_out`:

```text
M = S_acc / S_out
  = S_a × S_w / S_out
```

### 3. Why ReLU may be applied before requantization

**Status: PASSED**

The learner correctly restated that a positive requantization multiplier does not change the sign of the accumulator.

Because:

```text
M = S_acc / S_out > 0
```

we have:

```text
max(0, M × acc) = M × max(0, acc)
```

Therefore the ReLU sign check may be applied before the multiplier without changing the mathematical result. Negative accumulators can also bypass the multiplier path, reducing unnecessary switching.

### 4. Why saturation must occur after requantization

**Status: PASSED**

The learner correctly recognized that direct saturation would clamp the raw accumulator code without first converting it into output-scale units. Requantization preserves the intended numerical meaning under `S_out`; only then should the result be limited to the representable INT8 output range.

### 5. Why the 3×3 data are packed as `4 + 4 + 1`

**Status: PASSED**

The learner correctly restated that the ninth product can reuse one lane of the existing four-MAC datapath.

By packing the final word as:

```text
A8, 0, 0, 0
W8, 0, 0, 0
```

only one lane contributes a nonzero product while the other three lanes produce zero. This allows the same four-lane multiply/reduction datapath and the same regular memory/control structure to be reused, avoiding special-case handling for the last single product.

## Design understanding gate

**STATUS: PASSED**

The learner has successfully restated the required architectural decisions. `/design int8_quantization` is complete.

The next mandatory workflow stage is:

```text
/analyze int8_quantization
```

That stage must predict, before implementation:

- fixed-point requantization multiplier precision and approximation error,
- product and intermediate widths,
- possible DSP/LUT implementation cost,
- combinational timing risk relative to the 10 ns clock period,
- whether the current zero-extra-cycle capture structure is a reasonable prediction or a pipeline stage is likely to be required.
