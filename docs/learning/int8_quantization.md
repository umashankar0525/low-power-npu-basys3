# INT8 Quantization — Teaching Notes

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** TEACH

## Assumptions

- Target accelerator arithmetic remains signed INT8 activations and signed INT8 weights.
- Products are signed INT16 and accumulation is signed INT32.
- The baseline convolution is one 3x3 kernel, one input channel, and one output channel.
- The current hardware datapath does not include a bias term unless one is added in a later design step.
- The current `relu_activation` block applies ReLU to an INT32 accumulator and then directly saturates the integer result into signed INT8 range 0 to 127.
- For the first quantization implementation, symmetric signed INT8 quantization is the preferred baseline because it keeps zero represented exactly by integer zero and matches the signed arithmetic already used in the RTL.
- We will derive the numerical representation before writing Python or changing RTL.

## 1. Why quantization exists

A trained neural network commonly represents activations and weights with floating-point numbers such as:

```text
activation = 0.73
weight     = -0.42
```

The FPGA datapath in this project instead operates on signed 8-bit integers:

```text
-128 ... +127
```

Therefore we need a numerical mapping between the real-valued model domain and the integer hardware domain.

Quantization is that mapping.

It should answer two separate questions:

1. How do we convert a real value into an integer that the accelerator can process?
2. How do we interpret the integer result back in terms of the original real-value scale?

If we only convert numbers to integers without remembering the scale, the hardware result has no well-defined real numerical meaning.

## 2. Scale is the size of one integer step

Consider a real quantity `x` and an integer quantity `q`.

For symmetric quantization, we approximate:

```text
x ≈ scale × q
```

Let the scale be `S`.

Then:

```text
x ≈ S q
```

Solving for the integer representation gives:

```text
q ≈ x / S
```

Because the hardware stores integers, the result must be rounded:

```text
q = round(x / S)
```

and then clipped to the allowed integer range.

For the symmetric signed INT8 baseline used here, we deliberately use:

```text
q ∈ [-127, +127]
```

rather than using `-128` for normal symmetric mapping. This gives equal positive and negative magnitude around zero and makes zero map exactly to zero.

The physical INT8 hardware can still represent `-128`; we simply do not normally generate it from the symmetric quantizer.

## 3. Deriving the symmetric INT8 scale

Suppose the largest absolute value in a tensor is:

```text
A = max(|x|)
```

We want that largest magnitude to map to integer magnitude 127.

Therefore:

```text
A = S × 127
```

so:

```text
S = A / 127
```

This is not an arbitrary formula. It follows directly from asking one INT8 code, `127`, to represent the maximum real magnitude `A`.

### Example

Suppose a weight tensor has maximum absolute value:

```text
A = 0.50
```

Then:

```text
S_w = 0.50 / 127
    ≈ 0.003937
```

A real weight:

```text
w = 0.25
```

becomes:

```text
q_w = round(0.25 / 0.003937)
    ≈ round(63.5)
```

which will map to approximately 64 depending on the chosen rounding rule.

The reconstructed value is then approximately:

```text
w_hat = S_w × q_w
```

The difference between `w` and `w_hat` is quantization error.

## 4. Quantization and dequantization equations

For symmetric signed INT8 quantization:

```text
S = max(|x|) / 127
q = clip(round(x / S), -127, 127)
```

The approximate real value represented by the integer is:

```text
x_hat = S q
```

This `x_hat` is generally not exactly equal to the original `x` because quantization has finite resolution.

The error is:

```text
error = x - x_hat
```

A smaller scale gives finer resolution, but the scale must still be large enough to cover the required dynamic range without excessive clipping.

## 5. Why activation and weight scales can be different

Activations and weights are different numerical tensors.

Suppose:

```text
activation range ≈ [-2.0, +2.0]
weight range     ≈ [-0.5, +0.5]
```

Then their scales should not be forced to be equal.

For symmetric INT8:

```text
S_a = 2.0 / 127
S_w = 0.5 / 127
```

The integer activation and integer weight may both be INT8, but each integer code represents a different real step size.

This distinction becomes essential when we multiply them.

## 6. Deriving the scale of an INT8 product

Let a real activation be represented by:

```text
x ≈ S_a q_a
```

and a real weight by:

```text
w ≈ S_w q_w
```

The real product is:

```text
xw
```

Substituting the quantized approximations:

```text
xw ≈ (S_a q_a)(S_w q_w)
```

Rearranging:

```text
xw ≈ (S_a S_w)(q_a q_w)
```

Therefore the integer multiplication:

```text
q_a × q_w
```

has an associated real scale:

```text
S_product = S_a × S_w
```

The scale does not disappear just because the multiplier itself contains only integer hardware.

## 7. Deriving the scale of the accumulator

A 3x3 convolution computes nine products and sums them:

```text
y = Σ(x_i w_i), i = 0...8
```

Using the quantized representation:

```text
x_i ≈ S_a q_ai
w_i ≈ S_w q_wi
```

Therefore:

```text
y ≈ Σ[(S_a q_ai)(S_w q_wi)]
```

The scales are common across the terms for this simple per-tensor baseline, so:

```text
y ≈ S_a S_w Σ(q_ai q_wi)
```

The hardware computes:

```text
acc = Σ(q_ai q_wi)
```

Therefore the real interpretation of the INT32 accumulator is:

```text
y ≈ S_acc × acc
```

where:

```text
S_acc = S_a × S_w
```

This is one of the most important relationships in INT8 inference.

## 8. Why the accumulator is INT32

The integer inputs are 8-bit, but the accumulation must be wider.

A signed INT8 operand can reach magnitude 128 in the hardware representation.

The largest positive product magnitude occurs for:

```text
(-128) × (-128) = 16384
```

For nine terms, an intentionally conservative magnitude bound is:

```text
9 × 16384 = 147456
```

That is far larger than signed INT16 maximum 32767, so keeping the full convolution sum in INT16 would be unsafe.

INT32 provides a very large safety margin for this 3x3 single-channel baseline and also matches the architecture already built.

## 9. Quantization error versus clipping error

Two different errors can occur.

### Quantization error

A real value falls between two representable integer levels and must be rounded.

For example, if one integer step represents 0.01, then 0.234 cannot be represented exactly. It may become 0.23 or 0.24 after quantization and dequantization.

### Clipping error

A value lies outside the range represented by the chosen scale.

For example, if the selected INT8 range represents only up to real magnitude 1.0 but an activation becomes 1.4, it must be clipped to the largest representable value.

Clipping can cause much larger error than normal rounding.

Therefore choosing a scale is a tradeoff:

```text
large scale  -> wider range, coarser resolution
small scale  -> finer resolution, greater clipping risk
```

## 10. Symmetric versus asymmetric quantization

A general affine quantizer can be written as:

```text
x ≈ S(q - Z)
```

where:

- `S` is the scale,
- `Z` is the zero-point.

The integer conversion is approximately:

```text
q = round(x / S) + Z
```

For symmetric quantization:

```text
Z = 0
```

so:

```text
x ≈ S q
```

Symmetric quantization is attractive for our first accelerator because integer zero means real zero and multiplication does not require subtracting zero-points from every operand.

Asymmetric quantization can use the available integer codes more efficiently when a tensor is strongly offset from zero, but it adds extra arithmetic terms or preprocessing requirements.

For architectural learning, symmetric INT8 is therefore the cleaner baseline.

## 11. The crucial requantization problem

The convolution accumulator is INT32 and has scale:

```text
S_acc = S_a × S_w
```

But the next layer's activation is normally stored as another INT8 tensor with its own activation scale:

```text
S_out
```

Therefore we generally cannot simply copy or saturate the raw INT32 accumulator into INT8.

We need to transform from accumulator scale to output scale.

The real output before activation is approximately:

```text
y ≈ S_acc × acc
```

We want an INT8 output `q_out` satisfying:

```text
y ≈ S_out × q_out
```

Equating the two expressions:

```text
S_out q_out ≈ S_acc acc
```

Solving for `q_out`:

```text
q_out ≈ (S_acc / S_out) × acc
```

Since:

```text
S_acc = S_a S_w
```

we get:

```text
q_out ≈ (S_a S_w / S_out) × acc
```

Then the result is rounded and clipped to the output INT8 range.

This operation is called **requantization**.

## 12. Relationship to the current ReLU RTL

The current project ReLU performs the following integer behavior:

```text
acc < 0       -> 0
0 <= acc <=127 -> acc
acc > 127     -> 127
```

That block is correct as a combinational ReLU plus integer saturation block for its stated contract.

However, a general quantized neural-network layer needs the scale conversion derived above before or as part of producing the next INT8 activation.

Directly saturating the raw INT32 accumulator is mathematically equivalent to a special case in which the effective accumulator-to-output scale ratio is treated as 1:

```text
S_acc / S_out = 1
```

A real quantized model will not generally satisfy that automatically.

This is an important architectural boundary to address in Phase 6. We must decide during DESIGN whether:

1. the Python data-generation flow deliberately chooses compatible scales for a simplified demonstrator, or
2. the hardware path gains an explicit requantization stage.

We will not make that choice silently. It must be derived and documented before implementation.

## 13. ReLU in the quantized domain

For the symmetric baseline, zero-point is zero.

Therefore real zero maps to integer zero.

ReLU is:

```text
ReLU(x) = max(0, x)
```

and with symmetric quantization this maps naturally to:

```text
q_relu = max(0, q)
```

This is why symmetric quantization works neatly with the current integer ReLU concept.

The remaining issue is not where zero lies; the remaining issue is the scale conversion from INT32 accumulator units into the next INT8 activation units.

## 14. Why we need a Python reference path

The FPGA should not be trusted as its own reference model.

A Python quantization/reference flow will eventually need to calculate, independently of the RTL:

```text
FP32 inputs and weights
        ↓
quantization parameters
        ↓
INT8 activations + INT8 weights
        ↓
integer 3x3 convolution
        ↓
INT32 accumulator
        ↓
requantization decision
        ↓
ReLU / INT8 output
```

Then XSim results can be compared against independently calculated expected values.

This is much stronger verification than copying a value from the RTL into the testbench and checking it against itself.

## 15. Example end-to-end scale derivation

Assume, for illustration only:

```text
max activation magnitude = 2.0
max weight magnitude     = 0.5
```

Then:

```text
S_a = 2.0 / 127
S_w = 0.5 / 127
```

Therefore:

```text
S_acc = S_a × S_w
```

Numerically:

```text
S_a ≈ 0.015748
S_w ≈ 0.003937
S_acc ≈ 0.0000620
```

If the integer accumulator is:

```text
acc = 10000
```

then the real value represented by that accumulator is approximately:

```text
y ≈ 10000 × 0.0000620
  ≈ 0.620
```

Notice why directly saturating integer `10000` to INT8 value `127` would lose the numerical interpretation.

If the desired output activation scale were, for example:

```text
S_out = 0.01
```

then the required integer output would be approximately:

```text
q_out = round(0.620 / 0.01)
      = 62
```

Equivalently:

```text
q_out = round((S_acc / S_out) × 10000)
```

This is the purpose of requantization.

## 16. What Phase 6 must establish before implementation

Before generating Python quantization code or changing the hardware, we need to understand and later design:

- whether the baseline uses symmetric quantization for both activations and weights,
- how scales are derived,
- what rounding rule is used,
- what clipping range is used,
- whether scaling is per-tensor or per-channel,
- how the INT32 accumulator is interpreted,
- how the output is requantized to INT8,
- where ReLU is applied relative to requantization,
- how quantized values are packed into BRAM words,
- how the Python reference model will independently reproduce the integer convolution.

For the current one-input-channel, one-output-channel accelerator, **per-tensor symmetric quantization** is the simplest baseline to understand first. More advanced per-channel weight quantization can be considered after the baseline is working.

## 17. Key equations

Symmetric quantization scale:

```text
S = max(|x|) / 127
```

Quantization:

```text
q = clip(round(x / S), -127, 127)
```

Dequantization:

```text
x_hat = S q
```

Product interpretation:

```text
xw ≈ (S_a S_w)(q_a q_w)
```

Accumulator interpretation:

```text
y ≈ (S_a S_w) acc
```

Requantization into an output scale:

```text
q_out = round((S_a S_w / S_out) acc)
```

followed by the appropriate activation and clipping rule.

## 18. Teaching hard gate

Before moving to `/design int8_quantization`, the learner must explain in their own words:

1. Why an INT8 value by itself is not enough to represent the original FP32 value, and what the scale means.
2. Why the INT32 accumulator has scale `S_a × S_w`.
3. Why directly saturating the raw INT32 accumulator to INT8 is not generally equivalent to a complete quantized neural-network output, and why requantization may be required.

No Python implementation or RTL modification should be generated until these concepts are understood.
