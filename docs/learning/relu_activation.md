# Learning Note: ReLU Activation

**Role:** Teaching Assistant  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `relu_activation`

## 1. Why ReLU exists

The convolution/MAC datapath produces a signed INT32 accumulator result. A neural-network activation function is applied after the accumulated dot product. For this project, the activation function is ReLU (Rectified Linear Unit).

ReLU is defined as:

\[
ReLU(x)=\begin{cases}
x,&x>0\\
0,&x\le0
\end{cases}
\]

In words: positive values pass through unchanged; zero and negative values become zero.

## 2. Why ReLU is hardware-friendly

ReLU does not require multiplication, division, or a lookup table. For a signed two's-complement value, the sign is represented by the most-significant bit (MSB). Therefore, the hardware only needs to determine whether the signed input is negative.

For a signed 32-bit value `x[31:0]`:

- `x[31] = 0` → non-negative → output is `x`.
- `x[31] = 1` → negative → output is `0`.

This makes ReLU primarily a comparison/sign-bit decision followed by selection.

## 3. Important precision decision

The accumulator in this project is INT32, but the activation precision is specified as INT8. Therefore, there are actually two conceptual operations:

1. Apply ReLU to the INT32 accumulator.
2. Convert the resulting non-negative value to the required INT8 representation.

These must not be confused. ReLU itself does not perform the INT32-to-INT8 conversion.

A future design decision must define how the INT32 value is reduced to INT8. Possible approaches include saturation, truncation, or a quantization scale. For this project, that policy must be explicitly chosen before RTL is written.

## 4. Why simple truncation can be dangerous

Suppose the post-ReLU value is larger than the positive INT8 range of 127. Directly taking the low 8 bits does not preserve the mathematical value. It can wrap around in two's-complement representation.

For example, a positive INT32 value of 130 has binary low 8 bits corresponding to `0x82`. Interpreting `0x82` as signed INT8 gives -126, which would turn a positive activation into a negative number.

Therefore, if the output must remain a valid signed INT8 activation, the conversion policy needs to prevent unintended wraparound. Saturation is one common hardware-friendly policy:

\[
Q(x)=\begin{cases}
0,&x\le0\\
127,&x>127\\
x,&0<x\le127
\end{cases}
\]

This is only a candidate policy for the project; it is not yet the final design decision.

## 5. Signed boundary cases

For ReLU, important functional boundaries are:

- `x = -1` → `0`
- `x = -128` → `0` (if considering an INT8 input)
- `x = 0` → `0`
- `x = 1` → `1`
- `x = 127` → `127`
- INT32 values larger than 127 require an explicit INT32-to-INT8 policy.

The INT32 range is:

\[
-2^{31}\le x\le2^{31}-1
\]

ReLU maps the entire negative half of that range to zero.

## 6. Hardware/dataflow location

The intended high-level dataflow is:

`BRAM → INT8 products → partial sums → INT32 accumulator → ReLU → INT8 output`

ReLU therefore belongs after the complete convolution accumulation, not between individual products. Applying ReLU to each product would implement a different mathematical operation:

\[
ReLU(a_0w_0)+ReLU(a_1w_1)+...\neq ReLU(\sum_i a_iw_i)
\]

in general.

## 7. Timing assumption

**Assumptions:**

- Clock = 100 MHz.
- ReLU is implemented as combinational logic.
- The INT32 accumulator result is already available before ReLU evaluates.
- No additional registered ReLU stage is assumed yet.

Under these assumptions, ReLU does not inherently require a separate clock cycle. However, if timing analysis shows the accumulator-to-output path is too long, a registered activation stage could be considered. That is a design decision to be evaluated later, not assumed now.

## 8. Interview-level takeaway

A strong hardware explanation is:

> ReLU is a sign-based clamp. For a signed two's-complement accumulator, the MSB identifies a negative value. Negative values are replaced with zero, while non-negative values pass through. Since ReLU is only a comparison and multiplexing operation, it is much cheaper than arithmetic-heavy activation functions. The subsequent INT32-to-INT8 conversion is a separate quantization problem and must have an explicitly defined policy.

## 9. Checkpoint

Before proceeding to `/design relu_activation`, the learner must be able to explain:

1. The mathematical definition of ReLU.
2. How the sign bit identifies negative two's-complement values.
3. Why ReLU should operate after the complete accumulation.
4. Why ReLU and INT32-to-INT8 conversion are separate operations.
5. Why blindly truncating a positive INT32 value to 8 bits can produce an incorrect signed result.

**Status:** Teaching complete; learner checkpoint required before design.
