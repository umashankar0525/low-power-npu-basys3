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
- Behavioral simulation does not establish FPGA timing closure.

## Arithmetic Resource Prediction

Four multiplier operations must be supported in parallel because four products are generated per compute group.

The selected architecture requires one long-lived INT32 accumulator register rather than four independent INT32 accumulators.

The balanced four-input reduction requires three additions total:

1. P0 + P1
2. P2 + P3
3. sum01 + sum23

The first two additions can occur in parallel, giving an adder depth of two.

## Cycle Schedule Prediction

Cycle 1:

P0, P1, P2, P3 are generated.

Cycle 2:

P4, P5, P6, P7 are generated.

Cycle 3:

P8 is generated while S0 + S1 is formed.

Cycle 4:

The final T + P8 operation produces the result.

## Measured Behavioral Result

The XSim directed verification completed with all seven cases passing.

Observed results:

- Case 1: 0
- Case 2: 54
- Case 3: -54
- Case 4: 54
- Case 5: 147456
- Case 6: -146304
- Case 7: -165

The boundary calculations were confirmed independently:

(-128) x (-128) = 16384

9 x 16384 = 147456

127 x (-128) = -16256

9 x (-16256) = -146304

Therefore the behavioral implementation correctly covers the derived convolution result range:

-146304 <= R <= 147456

## Measured Latency

The corrected testbench measures latency from the active clock edge that accepts start to the edge at which done/result become valid.

The implemented schedule behaves as a three-clock-period start-to-result latency because the first processing stage executes on the same edge that accepts start.

At 100 MHz:

Tclk = 10 ns

Measured behavioral latency = 3 x 10 ns = 30 ns

This is a behavioral cycle result, not a claim about physical FPGA propagation delay.

## Important Timing Distinction

The Basys 3 target clock is specified as 100 MHz for this project. The uncertainty is not the nominal board clock; it is whether the synthesized implementation can meet a 10 ns clock period after routing and placement.

Behavioral simulation verifies logical behavior and cycle sequencing. It does not provide LUT/DSP mapping, routed combinational delay, setup slack, hold slack, or maximum achievable clock frequency.

Therefore the next performance step is synthesis and implementation timing analysis.

## Utilization Prediction

The simple product schedule has:

Cycle 1: 4/4 multiplier lanes active = 100% multiplication-lane utilization.
Cycle 2: 4/4 active = 100%.
Cycle 3: 1/4 active = 25%.

Across the three product-generation cycles, raw multiplication-lane utilization is:

9 / (3 x 4) = 75%.

This is a prediction for multiplication-lane activity and does not include reduction hardware utilization.

## Resource Prediction

Predicted architectural resources:

- Four parallel multiplier operations.
- Three additions for a balanced four-input reduction.
- One shared INT32 accumulator register.
- Additional intermediate registers according to the implemented pipeline boundaries.

Exact DSP/LUT/FF mapping remains unknown until Vivado synthesis.

## Timing Prediction

At 100 MHz, each cycle provides 10 ns.

The current low-latency schedule can place dependent additions in the same cycle. That reduces behavioral latency but may increase the critical path compared with a more deeply registered four-stage implementation.

No numerical implementation delay is claimed before synthesis and implementation.

## Next Step

Run Vivado synthesis for the actual target FPGA and record LUTs, FFs, DSP usage, inferred multiplier implementation, worst negative slack, total negative slack, and maximum achievable frequency. Compare those measurements against the predictions above.
