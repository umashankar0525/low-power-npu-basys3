# ReLU Timing Wrapper — Implementation Timing Prediction

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Status:** Prediction complete; post-implementation timing measurement pending.

## 1. Objective

Predict the timing behavior before running synthesis, placement, routing, and static timing analysis. The goal is to compare the measured implementation result against a 100 MHz requirement.

## 2. Explicit assumptions

- Target clock frequency: 100 MHz.
- Clock period: 10 ns.
- The timing wrapper contains an INT32 accumulator launch register and an INT8 output capture register.
- `relu_activation` is purely combinational.
- The XDC clock constraint is applied to the wrapper `clk` port.
- The target device is XC7A35T-1CPG236C-1.
- No physical timing value is assumed from behavioral simulation.
- No numerical setup/hold slack is claimed until Vivado implementation timing is measured.

## 3. Clock-period derivation

The required clock period follows directly from:

`Tclk = 1 / fclk`

For 100 MHz:

`Tclk = 1 / (100 x 10^6) = 10 ns`

The committed XDC establishes this requirement using `create_clock -period 10.000` on `clk`.

## 4. Timing path prediction

The intended setup path is:

`accumulator_reg Q -> relu_activation logic -> output_activation D`

The general setup requirement is:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

Therefore:

`setup slack = 10 ns - data arrival time`

A positive setup slack means the path meets 100 MHz. A negative slack means a setup violation.

## 5. Resource/timing expectation

The standalone ReLU synthesis measurement was small: 13 LUTs, 0 registers, 0 DSPs, and 0 BRAMs. The timing wrapper adds two register banks around the combinational block, creating the actual register-to-register timing path. Because the ReLU logic is small, the prediction is that the path should have positive setup slack at 100 MHz, but this is only a prediction.

## 6. Required measurement

The user must run synthesis and implementation with the timing wrapper as the top module and the 100 MHz XDC applied. Static timing analysis must then report the actual worst setup and hold results.

Record at minimum:

- Worst Setup Slack (WNS)
- Total Negative Slack (TNS), if reported
- Worst Hold Slack (WHS)
- Critical-path data delay
- Launch register
- Capture register
- Logic/routing on the critical path
- Whether the path meets the 10 ns requirement

## 7. Acceptance criterion

For the 100 MHz target, the primary setup acceptance condition is:

`WNS >= 0 ns`

Hold timing must also satisfy the implementation report's hold requirement. A design should not be declared timing-closed from setup alone if hold violations remain.

## 8. Prediction versus measurement

| Metric | Prediction | Measurement |
|---|---|---|
| Clock period | 10 ns | Pending |
| ReLU architectural latency | 1 cycle | Already functionally verified |
| Setup slack | Positive expected | Pending |
| Hold slack | Positive expected | Pending |
| Critical path | `accumulator_reg -> ReLU -> output_activation` expected | Pending |
| 100 MHz closure | Expected, not guaranteed | Pending |

## 9. Conclusion

The timing constraint and prediction are complete. The next step is post-implementation static timing analysis. No physical timing number should be claimed until Vivado reports it after implementation.
