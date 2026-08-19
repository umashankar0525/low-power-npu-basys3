# 4-MAC Compute Datapath — Design

## Role
Design Engineer.

## Active Phase
Phase 2 — 4-MAC Compute Datapath + Scheduling.

## Assumptions

- Target FPGA: XC7A35T-1CPG236C.
- Target clock: 100 MHz, giving a 10 ns clock period.
- Verilog-2001 is required; SystemVerilog is not used.
- One 3x3 convolution has 9 INT8 activation/weight products.
- Four multiplication lanes operate in parallel.
- Each INT8 x INT8 product is represented as signed INT16.
- Pairwise reduction is widened to INT17.
- A four-product partial sum is represented as signed INT18.
- The final convolution accumulation is signed INT32.
- No saturation is included in this datapath stage.

## Architectural Decision

Use four parallel signed INT8 multipliers followed by a balanced reduction network and a shared INT32 accumulator. Do not instantiate four long-lived independent INT32 accumulators.

The datapath responsibilities are separated:

1. Four multipliers compute products.
2. A balanced adder tree reduces groups of products.
3. The resulting partial sum is sign-extended to INT32.
4. A shared INT32 accumulator retains the convolution partial result.

This separation keeps arithmetic blocks independently understandable and verifiable.

## Datapath Width Derivation

INT8 x INT8 produces a mathematical range of -16256 through 16384, requiring INT16.

Two maximum positive products produce:

2 x 16384 = 32768

Signed INT16 maximum is 32767, so the pairwise adder must use INT17.

Four maximum positive products produce:

4 x 16384 = 65536

Signed INT17 maximum is 65535, so the four-product partial sum requires INT18.

The final 3x3 convolution is bounded by -146304 through 147456 and therefore fits in signed INT32.

## Reduction Structure

For four products P0 through P3:

sum01 = P0 + P1
sum23 = P2 + P3
partial = sum01 + sum23

The first two additions are independent and can occur in parallel. The final addition forms the second combinational addition level. Therefore the balanced tree has an adder depth of two.

## Scheduling

A simple product schedule is:

Cycle 1: P0 P1 P2 P3
Cycle 2: P4 P5 P6 P7
Cycle 3: P8 and three unused multiplier lanes

The third cycle has only 25% multiplier utilization because only one of four products remains. However, reduction work from already-produced products can overlap with P8 computation where the datapath timing and register placement permit.

After the first two product groups:

S0 = P0 + P1 + P2 + P3
S1 = P4 + P5 + P6 + P7

The final result is:

Final = S0 + S1 + P8

A key design objective is to overlap S0/S1 reduction with P8 computation rather than treating multiplication and reduction as completely serial operations.

## State and Registers

The shared INT32 accumulator is the primary long-lived state for one convolution. Intermediate registered values may be introduced where required by timing or schedule, but additional state must be justified by a concrete latency/timing benefit.

## Resource Prediction

At the architectural level, four signed multipliers and a small adder tree are required. Exact LUT/DSP mapping must not be assumed. Vivado synthesis and implementation will determine actual DSP and LUT usage.

The existing INT32 accumulator contributes 32 flip-flops. Additional registers depend on the final pipeline/register placement and must be measured after RTL synthesis.

## Timing Prediction

At 100 MHz, the clock period is 10 ns. The balanced reduction tree has two adder levels, but exact delay cannot be claimed before synthesis/implementation. The critical path is expected to involve multiplication and/or the reduction path depending on register placement and FPGA mapping.

## Design Constraint

No RTL should be generated from this document until the cycle-level register placement and latency are explicitly derived and confirmed by the user.

## Next Step

Analyze the proposed datapath and schedule before RTL generation. Derive the expected cycle count, register boundaries, resource usage, and critical path from first principles.
