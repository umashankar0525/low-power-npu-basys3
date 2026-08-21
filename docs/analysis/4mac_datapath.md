# 4-MAC Datapath — Analysis

## Role
Performance Analyst.

## Active Phase
Phase 2 — 4-MAC Compute Datapath + Scheduling.

## Assumptions

- Target clock = 100 MHz.
- Clock period = 10 ns.
- One 3x3 convolution requires 9 INT8 x INT8 products.
- Four multiplier lanes are available.
- Timing closure is not assumed before Vivado synthesis/implementation.

## Arithmetic Resource Prediction

Four multiplier operations must be supported in parallel during the first two product groups. The architecture also requires the ninth product during the third group.

A four-input balanced reduction requires three additions total: P0+P1, P2+P3, and the sum of those two partial sums. The first two additions can occur in parallel, giving an adder depth of two for each four-product reduction.

## Width Derivation

Maximum signed INT8 product:

(-128) x (-128) = 16384

Therefore the product requires signed INT16.

Maximum four-product positive partial sum:

4 x 16384 = 65536

INT17 cannot represent +65536, so S0 and S1 require signed INT18.

Maximum combined partial sum:

65536 + 65536 = 131072

INT18 tops out at +131071, so T requires signed INT19.

Maximum final convolution result:

131072 + 16384 = 147456

The final result is stored in signed INT32.

## Latency Options Considered

Option A: register T before adding P8. This gives a conservative four-stage schedule and was initially predicted as 40 ns at 100 MHz.

Option B: accept start and execute the first computation on the same active edge, then perform S1 on the next edge, T and P8 on the third edge, and result/done on the fourth edge. The start-accepting edge to result edge is therefore three clock periods, or 30 ns at 100 MHz.

The implemented RTL follows Option B.

## Measured Verification Result

The corrected XSim behavioral simulation completed with all seven directed cases passing:

- Case 1: result = 0 — PASS
- Case 2: result = 54 — PASS
- Case 3: result = -54 — PASS
- Case 4: result = 54 — PASS
- Case 5: result = 147456 — PASS
- Case 6: result = -146304 — PASS
- Case 7: result = -165 — PASS
- Overall: ALL TESTS PASSED

The first testbench run reported 14 failures, all due to an incorrect one-clock-later expectation for done. Arithmetic results were already correct. The verification expectation was corrected to count latency from the active edge that accepts start.

The corrected testbench passed all directed cases, including both INT8 boundary cases. Its cycle-level done check verifies the implemented start-to-done latency as three clock periods, equivalent to 30 ns at the 100 MHz target clock.

## Prediction vs Measurement

| Metric | Prediction | Measured/Verified | Status |
|---|---:|---:|---|
| Product width | INT16 | Boundary cases correct | PASS |
| S0/S1 width | INT18 | Boundary case correct | PASS |
| T width | INT19 | Boundary case correct | PASS |
| Final result width | INT32 | Boundary cases correct | PASS |
| Maximum positive result | 147456 | 147456 | PASS |
| Maximum negative result | -146304 | -146304 | PASS |
| Start-to-result latency | 30 ns for implemented schedule | 3 clocks = 30 ns at 100 MHz | PASS |
| Functional directed tests | 7 cases | 7/7 pass | PASS |

## Resource Prediction — Not Yet Measured

The architecture is intended to expose four parallel multiplier lanes during the first two product groups. The third group uses one multiplier lane for P8 unless the architecture is later changed to exploit otherwise idle lanes.

Across the nine product operations and three product-generation groups, raw multiplication-lane utilization is:

9 / (3 x 4) = 75%

This is an activity prediction, not a synthesized resource utilization figure.

Exact DSP/LUT mapping remains unknown until Vivado synthesis and must be measured rather than assumed.

## Timing Prediction — Not Yet Measured

At 100 MHz, one clock period is 10 ns. Behavioral simulation verifies functional behavior but does not establish FPGA timing closure.

The critical path must be measured after synthesis and implementation, especially through the reduction network and final addition.

## Architectural Observation

The implemented RTL favors lower start-to-result latency by overlapping final arithmetic work. This differs from the earlier conservative Option A prediction. Timing closure will determine whether this latency optimization is worth its combinational delay.

## Next Step

Run Vivado synthesis/implementation and measure LUT usage, DSP usage, register usage, worst negative slack, maximum achievable clock frequency, and the critical path through the reduction/final-add logic. These measured values will replace predictions where appropriate.
