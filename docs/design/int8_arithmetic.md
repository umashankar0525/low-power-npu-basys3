# INT8 Arithmetic Datapath — Design

## Role
Design Engineer artifact produced after the INT8 arithmetic learning gate.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Objective
Define the conceptual datapath that accepts two signed INT8 operands, produces a signed INT16 product, and provides a sign-extended INT32 value suitable for accumulation.

## Assumptions

- Operands use two's-complement signed representation.
- Activation input is INT8: -128 to +127.
- Weight input is INT8: -128 to +127.
- Product is represented as signed INT16.
- Product is sign-extended to signed INT32 before accumulation.
- The current convolution is 3x3, so nine products contribute to one output.
- No saturation is applied at this arithmetic stage; overflow behavior is handled by the chosen width and later design decisions.
- Clocking/control is intentionally excluded from this arithmetic foundation; the first design is treated as a pure combinational datapath unless a later timing decision requires otherwise.

## Datapath

```text
activation_i [7:0] signed
          |
          v
      +---------+
weight | signed  |
_i [7:0] -> multiply | --> product [15:0] signed
      +---------+
                    |
                    | sign extension
                    v
             product_ext [31:0] signed
                    |
                    v
               accumulator
```

## Interface Concept

| Signal | Width | Signed | Direction | Meaning |
|---|---:|---|---|---|
| activation_i | 8 | yes | input | INT8 activation |
| weight_i | 8 | yes | input | INT8 weight |
| product_o | 16 | yes | output | INT16 multiplication result |
| product_ext_o | 32 | yes | output | Sign-extended INT32 product |

The exact RTL module interface will be finalized only after the prediction/analysis stage.

## Arithmetic Derivation

For signed INT8 operands:

- Minimum = -128
- Maximum = +127

The extreme products are:

(-128) * (-128) = +16384
(-128) * (+127) = -16256
(+127) * (+127) = +16129

Therefore the product range is:

-16256 <= product <= +16384

Signed INT16 has range:

-32768 <= value <= +32767

Therefore INT16 is sufficient for every possible INT8-by-INT8 product.

For the current 3x3 convolution, the largest positive accumulation bound is:

9 * 16384 = 147456

INT18 maximum is 131071, so INT18 is insufficient. INT19 maximum is 262143, so INT19 is mathematically sufficient. The project nevertheless selects INT32 as the architectural accumulator width to provide headroom for scaling and future changes.

## Signed Extension Rule

When converting the INT16 product to INT32, copy the INT16 sign bit into all newly added upper bits.

Example:

INT16 +16384:
0100_0000_0000_0000

INT32:
0000_0000_0000_0000_0100_0000_0000_0000

The numerical value remains +16384.

For a negative product, the upper 16 bits must be all ones. Zero extension is not acceptable because it changes the numerical value.

## Design Boundaries

This module is intentionally small. It does not perform accumulation, ReLU, memory access, FSM control, or convolution scheduling. Those functions will be separate design stages so each architectural assumption can be verified independently.

## Power Consideration

The arithmetic foundation should not introduce unnecessary state or switching. Any clocked implementation will require a later justification. The initial conceptual design therefore separates arithmetic function from control and storage.

## Next Gate

Next step is `/analyze int8_arithmetic`: derive test vectors, expected ranges, timing/resource predictions, and verification expectations before any RTL is generated.
