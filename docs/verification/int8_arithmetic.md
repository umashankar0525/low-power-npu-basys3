# INT8 Arithmetic — Verification Plan and Results

## Role
Verification Engineer artifact for the signed INT8 arithmetic primitive.

## Scope
Verify that the Verilog-2001 arithmetic block correctly:

1. Interprets both operands as signed INT8.
2. Produces the mathematically correct signed INT16 product.
3. Preserves the product value when sign-extending INT16 to INT32.

## Verification Strategy

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

## Testbench

The unit testbench is `tb/unit/tb_int8_arithmetic.v`. It drives every signed INT8 pair, waits `#1`, computes an independently sized reference product, and checks the product, INT32 extension, and sign-extension relationship.

## Exhaustive XSim Result — PASS

### Environment

- Vivado: 2018.2
- Simulator: XSim
- Simulation type: Behavioral / Functional
- DUT: `int8_arithmetic.v`
- Testbench: `tb_int8_arithmetic.v`
- Command: `restart` followed by `run 70 us`
- Time resolution: 1 ps

### Compilation / Elaboration

Compilation completed successfully. The DUT and testbench elaborated successfully. XSim completed the requested simulation.

Vivado emitted one warning that the DUT has no explicit timescale while another module has one. This is a simulation-time-unit warning and did not prevent compilation, elaboration, or functional verification.

### Final Console Evidence

The supplied XSim console reports:

```text
INT8 ARITHMETIC EXHAUSTIVE VERIFICATION
Tests performed : 65536
Errors found    : 0
RESULT          : PASS
```

The simulator also reports:

```text
$finish called at time : 65536 ns
```

This matches the expected execution time because the testbench waits `#1` for each of the 65,536 input combinations:

65536 tests * 1 ns/test = 65536 ns

### Verification Conclusion

All 65,536 signed INT8 activation/weight combinations were exercised. Both the INT16 product and INT32 sign-extension checks completed with zero mismatches.

Therefore the functional arithmetic contract is verified:

`INT8 signed × INT8 signed -> INT16 signed -> INT32 sign-extended`

**Functional verification status: PASS.**

## Important Limitation

This result is a **behavioral functional verification result**. It does not yet establish synthesis resource usage, timing closure, or power. Those require synthesis/implementation and, for power, an appropriate activity-aware power analysis.

## Next Step

Update the performance analysis with measured functional results, then proceed to design review of this primitive before moving to the next architectural module.
