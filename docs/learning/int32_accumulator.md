# INT32 Accumulator — Learning

## Role
Teaching Assistant

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design

## Learning Objective
Understand how the INT16 products from the verified INT8 arithmetic primitive are accumulated into an INT32 convolution sum over a 3x3 kernel.

## 1. What the accumulator does

A convolution output for a 3x3, single-channel kernel is:

S = p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8

where each product pi is the signed INT16 result of one INT8 activation multiplied by one INT8 weight.

The accumulator stores a running sum instead of requiring all nine products to be added in one operation.

Conceptually:

cycle 0: acc = 0 + p0
cycle 1: acc = acc + p1
cycle 2: acc = acc + p2
...
cycle 8: acc = acc + p8

The final accumulator value is the convolution sum before an activation such as ReLU.

## 2. Why the accumulator is INT32

Each INT8 x INT8 product fits in signed INT16.

The largest positive product is:

(-128) x (-128) = 16384

For nine products, the largest possible positive sum is:

9 x 16384 = 147456

Signed INT18 has maximum value:

2^17 - 1 = 131071

so INT18 is not sufficient.

Signed INT19 has maximum value:

2^18 - 1 = 262143

so INT19 is mathematically sufficient for the current 3x3 case.

The project uses INT32 to provide architectural headroom for scaling and future changes.

## 3. Negative accumulation bound

The most negative single product is:

(-128) x 127 = -16256

Therefore the most negative sum of nine valid products is:

9 x (-16256) = -146304

The current convolution accumulation range is therefore:

-146304 <= S <= 147456

This fits inside signed INT32:

-2147483648 <= S <= 2147483647

## 4. Sign extension before addition

A product is generated as signed INT16 and must be sign-extended to INT32 before it is added to the INT32 accumulator.

Example with -5:

INT16:
1111_1111_1111_1011

INT32:
1111_1111_1111_1111_1111_1111_1111_1011

The numerical value remains -5.

Zero extension would interpret the negative product incorrectly and corrupt the convolution sum.

## 5. Sequential versus combinational accumulation

The project specifies four MAC units. The accumulator must support repeated updates as products are processed.

A clocked accumulator conceptually behaves as:

acc_next = acc_current + product_ext

On a clock edge, the new value becomes the stored accumulator value.

This differs from the previous arithmetic primitive, which was purely combinational.

The accumulator is stateful because it must remember the partial sum between cycles.

## 6. Reset behavior

Before starting a new convolution output, the accumulator must be initialized to zero.

Conceptually:

reset/clear -> acc = 0

The exact reset style, enable signal, and cycle schedule belong to the Design stage and must not be assumed here.

## 7. Product width versus accumulator width

Product width answers: can one INT8 x INT8 multiplication be represented without overflow? Answer: INT16.

Accumulator width answers: can the required sum of products be represented without overflow? Answer for this architecture: INT32.

These are separate numerical requirements.

## 8. Four MAC units

Four MAC units do not change the mathematical convolution result. They change how many products can be processed in parallel per cycle.

For the learning stage, first understand one accumulator receiving one INT16 product per update. Parallel scheduling across four MAC units will be designed afterward.

## 9. Next Design Stage

The Design stage will define accumulator input/output widths, signedness, clear/reset behavior, enable/valid behavior, update timing, whether the accumulator accepts one product or a sum of multiple MAC results, and how four MAC units map onto accumulation cycles.

No RTL should be generated until those decisions are derived and understood.

## Understanding Gate

Explain in your own words:

1. Why is INT16 enough for one product but not enough for the sum of nine products?
2. Why is INT32 stateful while the previous multiplier block was combinational?
3. What must happen to a negative INT16 product before adding it to an INT32 accumulator?
4. Why do four MAC units affect scheduling rather than the mathematical convolution equation?
