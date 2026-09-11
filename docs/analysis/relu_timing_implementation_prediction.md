# ReLU Timing Wrapper — Implementation Timing Prediction and Measurement

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Status:** Implementation timing measured; 100 MHz timing closure achieved; detailed setup critical path analyzed.

## Understanding checkpoint

The user correctly identified the timing-summary abbreviations:

- **WNS:** Worst Negative Slack — the worst setup slack among the analyzed setup paths. In this implementation it is **+6.213 ns**, so the worst setup path has positive margin.
- **WHS:** Worst Hold Slack — the worst hold slack among the analyzed hold paths. In this implementation it is **+0.196 ns**, so the worst hold path passes.
- **TNS:** Total Negative Slack — aggregate negative setup slack across failing setup endpoints. Here it is **0.000 ns**, with zero failing setup endpoints.
- **THS:** Total Hold Slack — aggregate negative hold slack across failing hold endpoints. Here it is **0.000 ns**, with zero failing hold endpoints.

Note: the user's phrase “THDS” should be **THS** (Total Hold Slack).

## 1. Objective

Predict the timing behavior before running synthesis, placement, routing, and static timing analysis, then compare the prediction against the measured implementation result.

## 2. Explicit assumptions

- Target clock frequency: 100 MHz.
- Clock period: 10 ns.
- The timing wrapper contains an INT32 accumulator launch register and an INT8 output capture register.
- `relu_activation` is purely combinational.
- The XDC clock constraint is applied to the wrapper `clk` port.
- The target device is XC7A35T-1CPG236C-1.
- No physical timing value is inferred from behavioral simulation.

## 3. Clock-period derivation

The required clock period follows directly from:

`Tclk = 1 / fclk`

For 100 MHz:

`Tclk = 1 / (100 x 10^6) = 10 ns`

The XDC establishes this requirement with a 10 ns clock constraint.

## 4. Timing path prediction

The intended setup path is:

`accumulator_reg Q -> relu_activation logic -> output_activation D`

The general setup requirement is:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

Timing slack is evaluated by Vivado after implementation. A positive WNS means the worst setup path has remaining margin; a negative WNS means a setup violation.

## 5. Resource/timing expectation

The standalone ReLU synthesis measurement was small: 13 LUTs, 0 registers, 0 DSPs, and 0 BRAMs. The timing wrapper adds the sequential boundaries needed to measure the combinational ReLU path.

Prediction: the small ReLU datapath should have positive setup and hold slack at 100 MHz, but this was only a prediction until implementation timing was measured.

## 6. Measured implementation timing

Vivado post-implementation Design Timing Summary reports:

| Metric | Measured result | Interpretation |
|---|---:|---|
| Worst Negative Slack (WNS) | **+6.213 ns** | Worst setup path meets timing with substantial margin |
| Total Negative Slack (TNS) | **0.000 ns** | No setup violations |
| Number of failing setup endpoints | **0** | All setup endpoints pass |
| Worst Hold Slack (WHS) | **+0.196 ns** | Worst hold path meets timing |
| Total Hold Slack (THS) | **0.000 ns** | No hold violations |
| Number of failing hold endpoints | **0** | All hold endpoints pass |
| Worst Pulse Width Slack | **+4.500 ns** | Pulse-width requirement passes |
| Failing pulse-width endpoints | **0** | No pulse-width violations |
| Total setup endpoints | **7** | All checked endpoints pass |
| Total hold endpoints | **7** | All checked endpoints pass |

Vivado reports: **“All user specified timing constraints are met.”**

## 7. Interpretation of WNS

The 100 MHz requirement gives a 10 ns clock period. The measured WNS is +6.213 ns, so the worst setup path has 6.213 ns of positive timing margin under Vivado's STA calculation.

This does **not** mean that the ReLU logic delay is exactly:

`10 ns - 6.213 ns = 3.787 ns`

because WNS is based on the complete timing calculation, including clock-path effects and setup-related terms. The exact data-path delay must be obtained from the detailed timing path report.

## 8. Interpretation of hold slack

The measured WHS is +0.196 ns. Therefore the worst hold path also meets its requirement, although its margin is much smaller than the setup margin.

The important acceptance condition is not merely positive setup slack. Both setup and hold must pass without failing endpoints.

## 9. Prediction versus measurement

| Metric | Prediction | Measurement |
|---|---|---|
| Clock period | 10 ns | **10 ns** |
| ReLU architectural latency | 1 cycle in timing wrapper | **1 cycle** |
| Setup slack | Positive expected | **+6.213 ns** |
| Hold slack | Positive expected | **+0.196 ns** |
| Setup violations | None expected | **0** |
| Hold violations | None expected | **0** |
| 100 MHz closure | Expected, not guaranteed | **Achieved** |

The prediction was directionally correct: the small ReLU datapath achieved a large positive setup margin and also passed hold timing.

## 10. Important timing-analysis distinction

WNS is a complete STA result rather than a direct measurement of one RTL block's intrinsic delay. Vivado accounts for the launch/capture timing relationship, data-path delay, clock characteristics, clock skew/uncertainty, and required setup relationship when calculating slack.

Therefore:

- **+6.213 ns WNS** proves the worst setup path meets the 100 MHz requirement.
- It does **not** by itself identify the exact ReLU propagation delay.
- Detailed `report_timing` is required to identify the critical path and its individual data-delay components.

## 11. Detailed setup critical-path measurement

The user supplied the post-implementation result of:

`report_timing -setup -max_paths 10`

The first reported path is the worst setup path and therefore corresponds to the measured **WNS = +6.213 ns**.

### 11.1 Launch and capture registers

- **Launch register:** `accumulator_reg_reg[20]/C`
- **Capture register:** `output_activation_reg[6]/D`
- Both are rising-edge-triggered FDRE registers clocked by `clk_100MHz`.
- The launch and capture clock edges are one period apart: 0 ns and 10 ns.

The important architectural path is therefore:

`accumulator_reg[20] Q -> ReLU/saturation logic -> output_activation[6] D`

This is exactly the register-to-register timing boundary created by the timing wrapper.

### 11.2 Measured data-path delay

For the worst path:

- **Data Path Delay = 3.750 ns**
- **Logic delay = 0.828 ns (22.080%)**
- **Routing delay = 2.922 ns (77.920%)**
- **Logic levels = 3**
- Implemented logic on this path: **1 LUT4 + 2 LUT5**

The first-principles decomposition is:

`3.750 ns = 0.828 ns logic + 2.922 ns routing`

So the dominant portion of this path is **routing**, not LUT propagation.

Routing fraction:

`2.922 / 3.750 x 100 = 77.92%`

Logic fraction:

`0.828 / 3.750 x 100 = 22.08%`

This is an implementation-specific measurement for the reported path; it is not a universal property of ReLU logic.

### 11.3 Cell-by-cell path interpretation

The reported data path after the launch register is:

1. `accumulator_reg_reg[20]/Q`
   - FDRE clock-to-Q increment: **0.456 ns**
   - This is the launch register's clock-to-Q contribution, separate from the reported 3.750 ns data-path delay.

2. `output_activation[6]_i_6`
   - LUT4 propagation: **0.124 ns**
   - Following routed net: **0.947 ns**

3. `output_activation[6]_i_3`
   - LUT5 propagation: **0.124 ns**
   - Following routed net: **1.317 ns**

4. `output_activation[6]_i_1`
   - LUT5 propagation: **0.124 ns**
   - Final net into `relu_output[6]`: **0.000 ns** in the report

5. `output_activation_reg[6]/D`
   - Capture register setup increment: **0.031 ns**

The large routed-net increments explain why the path's physical delay is dominated by interconnect even though only three LUT levels are present.

### 11.4 Clock-path effects

For the same worst path, Vivado reports:

- Destination Clock Delay (DCD): **4.272 ns**
- Source Clock Delay (SCD): **4.627 ns**
- Clock Pessimism Removal (CPR): **0.322 ns**
- Clock Path Skew: **-0.033 ns**
- Clock Uncertainty: **0.035 ns**
- Total System Jitter (TSJ): **0.071 ns**

The reported skew is derived as:

`Clock Path Skew = DCD - SCD + CPR`

Using the reported values:

`4.272 - 4.627 + 0.322 = -0.033 ns`

Therefore the clock relationship contributes a small **negative** skew term to the setup timing budget, while CPR recovers part of the pessimism between the two clock paths.

### 11.5 Required time and slack

Vivado reports:

- Requirement: **10.000 ns** between the source and destination rising clock edges.
- Required time at the capture endpoint: **14.590 ns** after including the reported clock-path effects, CPR, uncertainty, and capture setup.
- Reported slack: **+6.213 ns**.

The key STA relationship remains:

`Slack = Required Time - Arrival Time`

Vivado's printed path table uses its internal timing-path reference frame, which is why the displayed arrival-time field is negative in this report. Do not interpret the `-8.377` value as a negative physical signal delay. The physically meaningful data-path quantity reported separately is **3.750 ns**.

### 11.6 Why the path still has large positive slack

The path has only three LUT levels and a measured data-path delay of 3.750 ns. The 100 MHz clock provides a 10 ns cycle. After accounting for clock-path skew, uncertainty, clock-to-Q, and setup requirements, the resulting worst setup slack is still **+6.213 ns**.

Therefore the implementation has substantial setup margin at 100 MHz.

## 12. Other reported setup paths

The next worst setup paths in the supplied report are:

| Source | Destination | Data-path delay | Logic | Route | Slack |
|---|---|---:|---:|---:|---:|
| `accumulator_reg_reg[28]` | `output_activation_reg[0]` | 3.701 ns | 0.966 ns | 2.735 ns | **+6.273 ns** |
| `accumulator_reg_reg[20]` | `output_activation_reg[5]` | 3.574 ns | 0.828 ns | 2.746 ns | **+6.387 ns** |
| `accumulator_reg_reg[28]` | `output_activation_reg[4]` | 3.407 ns | 0.966 ns | 2.441 ns | **+6.565 ns** |
| `accumulator_reg_reg[28]` | `output_activation_reg[3]` | 3.337 ns | 0.966 ns | 2.371 ns | **+6.636 ns** |
| `accumulator_reg_reg[28]` | `output_activation_reg[2]` | 3.333 ns | 0.966 ns | 2.367 ns | **+6.638 ns** |
| `accumulator_reg_reg[28]` | `output_activation_reg[1]` | 3.192 ns | 0.966 ns | 2.226 ns | **+6.777 ns** |

The first path is the limiting setup path because it has the smallest slack.

A useful observation is that all listed paths have the same **3 LUT levels**, so the variation in slack is primarily caused by implementation-dependent routing and clock-path differences rather than a large change in logical depth.

## 13. Critical-path performance interpretation

For the worst setup path, the measured data path is:

`accumulator_reg Q -> 3 LUT levels -> output_activation D`

with:

- **3.750 ns data-path delay**
- **0.828 ns logic delay**
- **2.922 ns routing delay**
- **+6.213 ns WNS**

The route-to-logic ratio is approximately:

`2.922 / 0.828 = 3.53`

So the routing component is about **3.5 times** the logic component on this particular worst path.

This is an important FPGA timing observation: once the Boolean function is small, placement and routing can dominate the physical delay. Optimizing only the RTL Boolean expression may therefore have limited timing benefit unless it also changes the physical implementation.

## 14. Prediction versus detailed measurement

| Quantity | Prediction before implementation | Measured |
|---|---|---:|
| Clock period | 10 ns | **10.000 ns** |
| ReLU architectural latency | 1 cycle | **1 cycle** |
| Setup slack | Positive | **+6.213 ns** |
| Hold slack | Positive | **+0.196 ns** |
| Worst setup data-path delay | Small | **3.750 ns** |
| Worst setup logic delay | Small | **0.828 ns** |
| Worst setup routing delay | Expected nonzero | **2.922 ns** |
| Logic levels | Small | **3** |
| Setup violations | None expected | **0** |
| Hold violations | None expected | **0** |
| 100 MHz closure | Expected, not guaranteed | **Achieved** |

The prediction was directionally correct. The important refinement from the detailed report is that the implementation's small logic depth does **not** imply negligible physical delay: routing is the dominant contributor to the measured 3.750 ns data-path delay.

## 15. Important distinction: data-path delay vs WNS

Do not equate the following quantities:

- **3.750 ns** = measured data-path delay for the reported setup path.
- **+6.213 ns** = worst setup slack after the full STA timing calculation.
- **10.000 ns** = clock period requirement.

The 3.750 ns value is now a directly measured implementation quantity. The +6.213 ns value is the remaining setup margin after the timing engine accounts for the complete launch/capture timing relationship.

It is therefore valid to say:

> “The worst reported setup path has 3.750 ns of data-path delay and still meets the 10 ns clock requirement with +6.213 ns WNS.”

It is **not** valid to say:

> “The ReLU delay is 10 ns - 6.213 ns = 3.787 ns.”

The latter incorrectly treats slack as if it were the block's raw propagation delay.

## 16. Remaining measurement scope

The supplied report completes the detailed **setup-path** analysis for the worst ten reported paths.

The hold-side detailed path has not yet been supplied. The timing-summary result already establishes that hold timing passes with **+0.196 ns WHS** and **0 failing hold endpoints**, but a detailed `report_timing -hold -max_paths 10` would be required to explain the exact worst hold path and its individual minimum-delay components.

## 17. Conclusion

Implementation timing is complete for the ReLU timing wrapper at the required 100 MHz clock. The detailed setup report confirms that the worst setup path launches from `accumulator_reg_reg[20]` and is captured at `output_activation_reg[6]`.

Measured worst setup path:

- **Data-path delay:** 3.750 ns
- **Logic delay:** 0.828 ns
- **Routing delay:** 2.922 ns
- **Logic levels:** 3 (1 LUT4 + 2 LUT5)
- **Clock skew:** -0.033 ns
- **Clock uncertainty:** 0.035 ns
- **Setup slack:** +6.213 ns

The major physical insight is that routing accounts for **77.92%** of the measured data-path delay on this path. Despite this, the design has a substantial positive setup margin and meets the 100 MHz requirement. Hold timing also passes according to the timing summary, with +0.196 ns WHS.

The next deeper timing exercise would be the detailed hold-path report; no new architectural RTL is required for that measurement.
