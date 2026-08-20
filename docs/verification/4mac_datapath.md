# 4-MAC Datapath — Verification Plan

## Role
Verification Engineer.

## Active Phase
Phase 2 — 4-MAC Compute Datapath + Scheduling.

## Verification Objective

Prove both functional correctness and cycle-level control behavior of the four-MAC datapath. A passing simulation is not sufficient by itself; every test must be explainable from the RTL signals and the independent mathematical reference.

## Independent Reference

For nine signed INT8 activation/weight pairs, the expected result is calculated directly as:

R = sum(A[i] * W[i]) for i = 0..8

The reference must not reproduce the RTL's S0, S1, or T reduction structure. This prevents a common RTL mistake from being duplicated by the testbench.

## Required Directed Tests

1. Reset: result and internal state are cleared; done is low.
2. All zeros: expected result 0.
3. Positive x positive: nine products of 2 x 3; expected result 54.
4. Negative x positive: nine products of -2 x 3; expected result -54.
5. Negative x negative: nine products of -2 x -3; expected result 54.
6. Maximum positive boundary: all inputs and weights -128; each product is 16384 and expected result is 147456.
7. Maximum negative boundary: activation 127 and weight -128 for all nine pairs; each product is -16256 and expected result is -146304.
8. Mixed signed values: independently varied values to exercise sign extension and reduction.
9. Back-to-back operations: verify state returns to idle after done and a new start produces a new result.
10. Start behavior: verify start is accepted only from the idle state as defined by the RTL contract.

## Cycle-Level Checks

For a valid start:

- Cycle 1: S0 represents P0+P1+P2+P3.
- Cycle 2: S1 represents P4+P5+P6+P7.
- Cycle 3: P8 is computed and T represents S0+S1.
- Cycle 4: result represents T+P8 and done is asserted for the result-valid cycle.

## Boundary Proofs

INT8 minimum times INT8 minimum:

(-128) x (-128) = 16384

9 x 16384 = 147456

This exercises the positive upper bound of the convolution.

127 x (-128) = -16256

9 x (-16256) = -146304

This exercises the negative lower bound.

The expected complete result range is:

-146304 <= R <= 147456

## Architectural Verification Concern

The current RTL must also be reviewed for inferred hardware. Multiplication expressions should not be duplicated unnecessarily in the RTL because functional simulation can pass even if synthesis creates redundant multiplier logic. Functional correctness and intended resource architecture are separate verification goals.

## Pass Criteria

A test passes only when:

1. The independent reference result equals the RTL result.
2. done occurs in the predicted cycle.
3. result is valid when done is asserted.
4. reset clears state as specified.
5. signed boundary cases match exactly.

## Next Step

Create the Verilog testbench after the RTL's multiplier/reduction structure has been reviewed. Then run XSim and explain each observed result signal-by-signal.
