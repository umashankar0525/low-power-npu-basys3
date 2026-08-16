# L1 — INT8 Signed Arithmetic

## Role
Teaching Assistant

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design

## Objective
Understand exactly how signed INT8 values are represented and why this representation determines the datapath widths of the NPU.

## Assumptions
- INT8 means an 8-bit two's-complement signed integer.
- No saturation is applied at the arithmetic primitive in this lesson.
- The FPGA datapath will use ordinary fixed-width binary arithmetic unless a later design explicitly adds saturation.

## 1. Why two's complement?

A signed binary representation must encode both positive and negative numbers. Two's complement uses the most significant bit as the sign indicator while allowing ordinary binary addition hardware to perform signed addition.

For an N-bit two's-complement integer, the representable range is:

`-2^(N-1) <= x <= 2^(N-1)-1`

For N = 8:

`-2^7 <= x <= 2^7 - 1`

Therefore:

`-128 <= x <= +127`

There are exactly 256 possible 8-bit bit patterns, matching the 256 integer values from -128 through +127.

## 2. Reading an INT8 value

If the most significant bit is 0, the value is non-negative and is interpreted as an ordinary binary number.

Example:

`0000_0101 = +5`

If the most significant bit is 1, the value is negative. To find its magnitude, invert all bits and add one.

Example:

`1111_1011`

Invert:

`0000_0100`

Add one:

`0000_0101 = 5`

Therefore the original value is `-5`.

## 3. Why the negative limit is -128 but the positive limit is +127

The sign bit divides the 256 patterns into two groups. Zero belongs to the non-negative group, leaving one fewer positive value than negative values.

Positive/zero: 0 through 127 = 128 values.
Negative: -128 through -1 = 128 values.

This asymmetry is fundamental when calculating worst-case arithmetic bounds.

## 4. Sign extension

When an INT8 value is moved into a wider signed datapath, the sign must be preserved. This is done by copying the sign bit into the newly added upper bits.

Example:

`+5` as INT8:

`0000_0101`

Sign-extended to INT16:

`0000_0000_0000_0101`

`-5` as INT8:

`1111_1011`

Sign-extended to INT16:

`1111_1111_1111_1011`

Zero-extension of a negative signed number would change its value, so signed hardware must distinguish sign extension from zero extension.

## 5. INT8 multiplication

The NPU multiplies two signed INT8 operands. Each operand lies in [-128, 127]. The mathematical product therefore has a larger range than INT8.

The extreme magnitudes are obtained from the endpoints:

`(-128) * 127 = -16256`

`(-128) * (-128) = 16384`

`127 * 127 = 16129`

Therefore the complete mathematical product range is:

`-16384 <= product <= 16384`

An INT16 signed number has range:

`-2^15 <= x <= 2^15 - 1`

or:

`-32768 <= x <= 32767`

Therefore INT16 is sufficient to represent every mathematical INT8-by-INT8 product.

## 6. Why this matters for the NPU

A convolution performs many products and then adds them. We cannot safely keep the product in INT8 because the product range is much larger than the INT8 range.

The intended datapath is therefore:

`INT8 activation × INT8 weight -> INT16 product -> INT32 accumulator`

This width progression is an architectural decision, not an arbitrary convention.

## 7. Accumulator motivation

A 3x3 convolution with one input channel contains nine products per output value:

`sum = p0 + p1 + ... + p8`

Even though each product fits in INT16, the sum of nine products needs more range.

A conservative worst-case positive sum is:

`9 * 16384 = 147456`

A conservative worst-case negative sum is:

`9 * (-16384) = -147456`

INT18 already has range:

`-131072 <= x <= 131071`

so INT18 is not sufficient for the full worst-case signed sum.

INT19 has range:

`-262144 <= x <= 262143`

so INT19 is mathematically sufficient for nine worst-case products. The project nevertheless specifies an INT32 accumulator, giving substantial headroom and making the accumulation datapath simple and robust for future extensions.

This is an important distinction: **minimum mathematically sufficient width is not always the same as the chosen architectural width.**

## 8. Key datapath lesson

For this project:

`8-bit signed activation`

`×`

`8-bit signed weight`

`↓`

`16-bit signed product`

`↓`

`32-bit signed accumulator`

The next lesson will examine the multiplier itself and derive the product width from first principles.

## Understanding Check

Before moving to `/design int8_arithmetic`, explain in your own words:

1. Why is the INT8 signed range -128 to +127?
2. Why does an INT8 × INT8 operation require an INT16 result?
3. Why can nine INT16 products not simply be accumulated in INT16?
4. Why does this project choose INT32 even though INT19 is mathematically sufficient for a 3x3, one-channel sum?
5. What is the difference between sign extension and zero extension?
