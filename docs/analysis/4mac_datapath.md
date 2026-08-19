# 4-MAC Datapath — Analysis

## Role
Performance Analyst.

## Active Phase
Phase 2 — 4-MAC Compute Datapath + Scheduling.

## Assumptions

- Target clock = 100 MHz.
- Clock period = 1 / 100 MHz = 10 ns.
- One 3x3 convolution requires 9 INT8 x INT8 products.
- Four multiplier lanes operate in parallel.
- Architecture uses a balanced reduction tree and one shared INT32 accumulator.
- Timing closure is not assumed before Vivado implementation.

## Arithmetic Resource Prediction

Four multiplier operations must be supported in parallel because four products are generated per compute group.

The selected architecture requires one long-lived INT32 accumulator register rather than four independent INT32 accumulators.

The balanced four-input reduction requires three additions total:

1. P0 + P1
2. P2 + P3
3. sum01 + sum23

The first two additions can occur in parallel, giving an adder depth of two.

## Cycle Schedule

Cycle 1:

P0, P1, P2, P3 are generated.

Their reduction can form S0 = P0 + P1 + P2 + P3, subject to the chosen register placement.

Cycle 2:

P4, P5, P6, P7 are generated.

Their reduction forms S1 = P4 + P5 + P6 + P7.

Cycle 3:

P8 is generated. Because S0 and S1 are already available, T = S0 + S1 can overlap P8 computation.

A final operation T + P8 is then required.

## Latency Alternatives

Option A: Register T before adding P8.

- Cycles 1-3: product generation and intermediate reduction.
- Cycle 4: T + P8.
- Predicted ideal latency = 4 cycles.
- At 100 MHz: 4 x 10 ns = 40 ns.
- Advantage: shorter Cycle-3 combinational path and lower timing risk.

Option B: Compute T + P8 combinationally in Cycle 3 and capture the final result at the Cycle-3 boundary.

- Predicted ideal latency = 3 cycles.
- At 100 MHz: 3 x 10 ns = 30 ns.
- Cycle 3 contains two dependent addition levels: S0 + S1, followed by T + P8.
- Advantage: lower latency.
- Risk: longer critical path and therefore greater timing risk.

Initial architecture choice: Option A, because this project prioritizes understandable low-power architecture and timing margin. Option B remains a future optimization if implementation timing permits.

## Utilization Prediction

The simple product schedule has:

Cycle 1: 4/4 multiplier lanes active = 100% multiplication-lane utilization.
Cycle 2: 4/4 active = 100%.
Cycle 3: 1/4 active = 25%.

Across the three product-generation cycles, raw multiplication-lane utilization is:

9 / (3 x 4) = 75%.

This is a prediction for multiplication-lane activity and does not include reduction hardware utilization.

## Resource Prediction

- Four parallel multiplier operations.
- Three adders for a four-input balanced reduction.
- One shared INT32 accumulator register.
- Additional intermediate registers depend on final pipeline placement.

Exact DSP/LUT mapping is unknown until Vivado synthesis. It must be measured rather than assumed.

## Timing Prediction

At 100 MHz, each cycle provides 10 ns. Option A intentionally keeps the final cycle to a single addition, while Option B puts two dependent addition levels into Cycle 3. Therefore Option A is predicted to be easier to close at 100 MHz.

No numerical implementation delay is claimed before synthesis and implementation.

## Next Step

User understanding is confirmed for the current analysis. Before RTL generation, perform a final design confirmation of Option A, including the exact register boundaries and the meaning of a four-cycle latency.
