# INT8 Arithmetic — Verification Plan and First Simulation Result

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

## Testbench

The unit testbench is `tb/unit/tb_int8_arithmetic.v`. It drives every signed INT8 pair, waits `#1`, computes an independently sized reference product, and checks the product, INT32 extension, and sign-extension relationship.

## First XSim Run — Measured Result

### Environment

- Vivado: 2018.2
- Simulator: XSim
- Simulation type: Behavioral / Functional
- DUT: `int8_arithmetic.v`
- Testbench: `tb_int8_arithmetic.v`
- Simulation run shown in the supplied Vivado log: 1000 ns
- Time resolution: 1 ps

### Compilation / Elaboration

Compilation completed successfully and the DUT and testbench elaborated successfully. No syntax or elaboration error was reported.

Vivado emitted one warning:

`Module int8_arithmetic doesn't have a timescale but at least one module in design has a timescale.`

This is a simulation-time-unit warning, not a functional failure. The DUT can later be given an explicit `` `timescale 1ns/1ps `` for consistency.

### What the 1000 ns run proves

The supplied waveform shows changing activation values and corresponding signed arithmetic outputs. For example, the displayed hexadecimal values include:

- activation `0x80` = -128 when interpreted as signed INT8
- weight `0x68` = +104
- product `0xCD38` = -13000 as signed INT16
- extended product `0xFFFFCD38` = -13000 as signed INT32

The arithmetic is therefore behaving consistently for the observed negative boundary-side input region.

The waveform also shows `errors = 0` during the observed interval.

### Critical limitation

The run was only `1000 ns`. The testbench waits `#1` per input combination and requires:

65,536 tests * 1 ns/test = 65,536 ns

Therefore the 1000 ns run can cover only approximately the first 1000 input combinations, not all 65,536 combinations.

Consequently:

**This run is NOT an exhaustive PASS.**

It is a successful compilation/elaboration and a partial functional run with zero observed mismatches during the simulated interval.

## Required Next Run

Run the simulation for at least:

`70 us`

or equivalently:

`70000 ns`

This provides enough time for all 65,536 `#1` iterations and the final summary to execute.

The required final evidence is:

- `Tests performed : 65536`
- `Errors found    : 0`
- `RESULT          : PASS`

Only then will exhaustive functional verification be marked PASS.

## Pass Criteria

A verification run passes only if all 65,536 combinations satisfy the product and sign-extension checks with zero mismatches.

## Assumptions

- The DUT remains Verilog-2001.
- The DUT is combinational, so no clock is required for functional verification.
- Reference arithmetic in the testbench is sized and treated as signed so the comparison does not accidentally hide signedness errors.
- The testbench uses a `#1` delay per input pair; therefore simulation time directly limits how many combinations execute.

## Status

**Status: PARTIAL VERIFICATION — NOT YET EXHAUSTIVE PASS**

Next action: rerun XSim for at least 70 us and provide the final transcript containing the test count and error count.
