# INT8 Quantization — Implementation Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** RTL IMPLEMENTATION / UNDERSTANDING CHECK

## Assumptions

- Generated INT8 activations and weights are restricted to `[-127, +127]`.
- One 3×3 convolution therefore has maximum positive accumulator magnitude `145161`.
- ReLU is applied before fixed-point requantization.
- Requantization coefficient `M_INT` is 24-bit unsigned.
- Python must act as an independent reference rather than reuse RTL-generated expected values.

## Learner checkpoint

### 1. Why the raw requantization product needs 42 bits

**Status: PASSED**

The learner correctly used the worst-case product:

```text
145161 × 16777215 = 2435397306615
```

and observed:

```text
2^41 < 2435397306615 < 2^42
```

Therefore the exact raw unsigned multiplication result requires 42 bits.

### 2. Why Python must calculate the expected value independently

**Status: PASSED**

The learner correctly identified Python as the independent software-side reference. This prevents the verification environment from deriving its expected result from the same RTL behavior being checked. The Python model must independently implement the specified quantization, integer convolution, requantization, rounding, clipping, and BRAM packing contracts.

### 3. Why the post-ReLU accumulator magnitude uses 18 unsigned bits

**Status: PASSED**

Under the Phase 6 generated-data contract:

```text
acc_max = 9 × 127 × 127
        = 145161
```

After ReLU, the hardware only needs a non-negative magnitude. Compare the magnitude against powers of two:

```text
2^17 = 131072
2^18 = 262144
```

Since:

```text
131072 < 145161 < 262144
```

17 unsigned bits are insufficient, while 18 unsigned bits are sufficient. The learner correctly restated this relationship.

This 18-bit magnitude assumption is valid only for the bounded 3×3, one-channel, `[-127,+127]` generated-data contract. Arbitrary larger positive INT32 values are outside this baseline module's supported numerical range.

## Gate result

**IMPLEMENTATION UNDERSTANDING GATE: PASSED**

The learner has now demonstrated understanding of:

- the 18-bit post-ReLU accumulator magnitude;
- the 42-bit requantization product width;
- the need for an independent Python golden/reference model.

The mandatory workflow may now proceed to:

```text
/verify int8_quantization
```

No simulation result is claimed at this point.