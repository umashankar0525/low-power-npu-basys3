# INT32 Accumulator — Verification Plan

## Role
Verification Engineer.

## Scope
Verify the clocked Verilog-2001 INT32 accumulator that accepts one signed INT16 product per enabled cycle.

## Interface Contract

- `rst=1` at a rising edge forces `accumulator_o` to zero.
- `rst=0, en=1` at a rising edge adds the sign-extended INT16 product to the current INT32 accumulator.
- `rst=0, en=0` at a rising edge holds the current accumulator value.

## Reference Equation

For each enabled edge:

`acc_next = acc_current + signed(product_i)`

The product must be sign-extended from 16 bits to 32 bits before addition.

## Verification Strategy

This stateful primitive does not have a useful 256x256 combinational Cartesian-space test like the multiplier. Instead, verification uses directed state-transition sequences designed to exercise each part of the contract and the numerical boundaries.

## Required Tests

1. Reset from an unknown/nonzero starting state and verify zero.
2. Accumulate positive values over multiple clock edges.
3. Accumulate negative values over multiple clock edges.
4. Mix positive and negative values and compare against an independent integer reference.
5. Assert `en=0` and verify the accumulator holds its previous value.
6. Apply nine maximum positive products (`16384`) and verify `147456`.
7. Apply nine maximum negative products (`-16256`) and verify `-146304`.
8. Apply a negative product such as `-200` after a positive accumulator value and verify sign extension preserves the mathematical result.
9. Reset during a sequence and verify the accumulated state returns to zero on the reset edge.

## Signal-Level Proof Expectations

For every enabled edge, the expected value is calculated independently in the testbench before the edge and compared with `accumulator_o` after the edge.

For disabled edges, the expected value remains unchanged.

For reset edges, the expected value becomes zero regardless of the previous accumulator value or product input.

## Boundary Values

Maximum positive product:

`16384`

Maximum negative product:

`-16256`

Nine positive products:

`9 * 16384 = 147456`

Nine negative products:

`9 * -16256 = -146304`

Both values fit within INT32.

## Pass Criteria

All directed sequences must produce zero mismatches. The testbench must report the number of checks performed and the number of errors. A passing result must be supported by the observed state transitions, not only by a final PASS string.

## Assumptions

- Clock frequency is 100 MHz for cycle/timing interpretation; functional simulation itself does not require a physical 100 MHz clock.
- Reset is synchronous active high, as defined by the RTL design.
- No saturation or overflow detection is included in this primitive.

## Next Step

Generate `tb/unit/tb_int32_accumulator.v`, run it in XSim, then compare measured behavior against the pre-RTL predictions.
