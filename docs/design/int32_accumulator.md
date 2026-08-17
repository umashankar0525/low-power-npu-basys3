# INT32 Accumulator — Design

## Role
Design Engineer artifact for the second arithmetic-stage module.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Objective
Design a clocked INT32 accumulator that accepts one signed INT16 product per cycle, sign-extends that product to INT32, and adds it to stored state when enabled.

## Assumptions

- RTL will be Verilog-2001, not SystemVerilog.
- Input product is signed INT16.
- Accumulator state is signed INT32.
- The accumulator is synchronous to the project clock, assumed to be 100 MHz (10 ns period).
- Reset is synchronous and active high for the first design.
- `en` controls whether an input product is accumulated on the active clock edge.
- Reset has priority over accumulation.
- One INT16 product is supplied per cycle by this primitive. Combining four MAC outputs into a partial sum is a separate scheduling/design decision.
- No saturation is implemented at this stage; the chosen INT32 width provides ample range for the current 3x3 convolution.

## Mathematical Contract

For a valid accumulation cycle:

`acc_next = acc_current + sign_extend(product_i)`

For reset:

`acc_next = 0`

For a disabled cycle:

`acc_next = acc_current`

## Datapath

```text
product_i [15:0] signed
        |
        | sign extension
        v
product_ext [31:0] signed
        |
        v
   +-----------+
   | 32-bit    |
   | adder     |<--------- accumulator_q
   +-----+-----+
         |
         v
   accumulator_d
         |
         v
   +-----------+
   | 32-bit    |
   | register  |
   +-----+-----+
         |
         +-------> accumulator_q
```

## Interface Concept

| Signal | Width | Direction | Meaning |
|---|---:|---|---|
| `clk` | 1 | input | Accumulator clock |
| `rst` | 1 | input | Synchronous active-high reset |
| `en` | 1 | input | Accumulate enable |
| `product_i` | 16 | input | Signed INT16 product |
| `accumulator_o` | 32 | output | Signed INT32 stored accumulation |

The exact RTL coding style will be implemented only in the RTL generation stage.

## Why a Register Is Required

The accumulator must preserve the previous partial sum between clock edges. A combinational adder alone cannot represent the required stateful behavior. The register creates the cycle-to-cycle state:

`acc[n+1] = acc[n] + product[n]`

when `en=1`.

## Width Derivation

Maximum positive INT8 product:

`(-128) * (-128) = 16384`

For nine products:

`9 * 16384 = 147456`

Maximum negative product:

`(-128) * 127 = -16256`

For nine products:

`9 * (-16256) = -146304`

Thus the current 3x3 convolution sum is bounded by:

`-146304 <= sum <= 147456`

INT19 is mathematically sufficient for these bounds, but INT32 is retained as the architectural accumulator width for headroom and future scaling.

## Four-MAC Relationship

The four-MAC architecture does not require this primitive to accept four independent products. The mathematical result remains:

`sum = p0 + p1 + ... + p8`

The four-MAC scheduler may later produce four products in parallel and combine them into a partial sum before presenting data to the accumulator. That scheduling decision belongs to the MAC/control design stage and is intentionally separated from this primitive.

## Cycle Semantics

Assuming reset is asserted on a rising edge:

- At reset edge: accumulator becomes 0.
- On a later rising edge with `en=1`: the current signed INT16 product is sign-extended and added to the previous accumulator value.
- With `en=0`: accumulator holds its previous value.

Therefore a sequence of nine enabled products requires nine active accumulation edges after reset when using one-product-per-cycle input to this primitive.

## Verification Intent

The verification stage must test reset, enable/hold behavior, positive and negative products, sign extension, repeated accumulation, zero products, and boundary accumulation values. It must independently calculate expected state transitions rather than merely checking that the output changes.

## Design Boundary

This module does not include the INT8 multiplier, ReLU, BRAM, FSM, or four-MAC scheduler. Those remain separate modules so each behavior can be verified independently.

## Next Step

Run `/analyze int32_accumulator` to predict cycle behavior, boundary vectors, resource usage, and timing before any accumulator RTL is generated.
