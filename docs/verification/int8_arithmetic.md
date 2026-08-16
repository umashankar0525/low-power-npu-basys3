# INT8 Arithmetic — Verification Plan

## Role
Verification Engineer artifact for the signed INT8 arithmetic primitive.

## Scope
Verify that the Verilog-2001 arithmetic block correctly:

1. Interprets both operands as signed INT8.
2. Produces the mathematically correct signed INT16 product.
3. Preserves the product value when sign-extending INT16 to INT32.

## Verification Strategy

### Exhaustive verification

There are 256 possible values for each signed INT8 operand:

2^8 = 256

Therefore the complete Cartesian product contains:

256 * 256 = 65,536 input combinations.

Because the arithmetic block has only two 8-bit inputs, exhaustive verification is practical and preferred over relying only on a small collection of random vectors.

## Required Checks

For every pair `(activation_i, weight_i)`:

- Reference product = signed activation * signed weight.
- `product_o` must equal the reference product.
- `product_ext_o` must equal the same numerical reference value.
- No valid INT8 input combination may produce an INT16 overflow.
- The upper 16 bits of `product_ext_o` must be a sign extension of `product_o[15]`.

## Boundary Vectors

| Activation | Weight | Expected product |
|---:|---:|---:|
| 127 | 127 | 16129 |
| -128 | 127 | -16256 |
| 127 | -128 | -16256 |
| -128 | -128 | 16384 |
| 0 | 0 | 0 |
| 1 | -1 | -1 |
| -1 | -1 | 1 |
| -1 | 127 | -127 |

## Signal-Level Reasoning

For a positive product, the product MSB must be 0 and the upper 16 bits of the INT32 output must therefore be all zero.

For a negative product, the product MSB must be 1 and the upper 16 bits of the INT32 output must therefore be all one.

Example:

`-5` as INT16 = `1111_1111_1111_1011`

Sign-extended INT32 = `1111_1111_1111_1111_1111_1111_1111_1011`

The numerical value remains -5.

## Testbench Expectations

The eventual unit testbench should:

- drive exhaustive signed INT8 combinations,
- allow combinational outputs to settle,
- compare both outputs against an independently calculated reference,
- stop and report the first mismatch with operands and observed/expected values,
- report the total number of successful combinations.

The testbench must not simply print `PASS` without proving all checks were performed.

## Pass Criteria

A verification run passes only if all 65,536 combinations satisfy the product and sign-extension checks with zero mismatches.

## Assumptions

- Simulation uses Verilog-2001/SystemVerilog-compatible XSim compilation as required by the Vivado project, but the DUT itself remains Verilog-2001.
- The DUT is combinational, so no clock is required for functional verification.
- Reference arithmetic in the testbench must be sized and treated as signed so the comparison does not accidentally hide signedness errors.

## Next Step

Generate `tb/unit/tb_int8_arithmetic.v`, run exhaustive XSim verification, then explain why the observed waveforms and pass/fail result prove the DUT behavior.
