# ReLU Timing Wrapper — Detailed Hold Timing Measurement

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Measurement:** Post-implementation `report_timing -hold -max_paths 10`

## 1. What this report analyzes

The supplied report is a **hold** timing report, so it is a **minimum-delay** analysis. AMD documents that `report_timing -hold` is equivalent to minimum-delay analysis. `report_timing -setup` is the corresponding maximum-delay/setup analysis. citeturn1view0

Therefore, this report does **not** replace the setup report needed to inspect the maximum-delay path associated with the 100 MHz performance limit. It does, however, give us the detailed physical hold path.

## 2. Worst hold path

The first path is the worst hold path because it has the smallest slack:

- **Slack:** +0.196 ns — MET
- **Path type:** Hold / minimum delay
- **Path group:** `clk_100MHz`
- **Source clock pin:** `accumulator_reg_reg[4]/C`
- **Actual data launch pin:** `accumulator_reg_reg[4]/Q`
- **Destination:** `output_activation_reg[4]/D`
- **Requirement:** 0.000 ns
- **Data-path delay:** 0.288 ns
- **Logic delay:** 0.227 ns (78.877%)
- **Routing delay:** 0.061 ns (21.123%)
- **Logic levels:** 1 LUT5

The `/C` source shown by Vivado is the clock pin of the launching FDRE. The actual data path begins at `/Q` and ends at the destination `/D` pin:

`accumulator_reg[4]/Q → LUT5 → output_activation_reg[4]/D`

## 3. Hold-slack derivation

The report gives:

- Required time = -1.504 ns
- Arrival time = 1.700 ns

For hold timing:

`Slack = Arrival Time - Required Time`

Therefore:

`Slack = 1.700 - (-1.504)`

`Slack = +0.196 ns`

Because the result is positive, the path passes hold timing.

## 4. Clock-path information

The worst path reports:

- Source Clock Delay (SCD) = 1.412 ns
- Destination Clock Delay (DCD) = 1.927 ns
- Clock Pessimism Removal (CPR) = 0.515 ns
- Reported Clock Path Skew = 0.000 ns

The reported skew is consistent with:

`DCD - SCD - CPR`

`= 1.927 - 1.412 - 0.515`

`= 0.000 ns`

This demonstrates why we should not interpret the raw difference between source and destination clock delays as the final skew: Vivado applies clock pessimism removal.

## 5. Logic versus routing

For the worst hold path:

`Total data delay = Logic delay + Routing delay`

`= 0.227 + 0.061`

`= 0.288 ns`

The percentages reported by Vivado are:

`Logic = 0.227 / 0.288 × 100 = 78.877%`

`Routing = 0.061 / 0.288 × 100 = 21.123%`

Thus the bit-4 worst hold path is primarily determined by LUT/cell delay.

However, the other paths show that routing can dominate different bits. The reported bit-15 → output-bit-1 path has 0.231 ns logic delay and 0.355 ns routing delay, making routing about 60.5% of its total 0.586 ns data delay.

This is an important FPGA lesson: physical routing can become a major part of timing even when the RTL logic is simple.

## 6. Other reported hold paths

| Source | Destination | Data delay | Logic | Routing | Slack |
|---|---|---:|---:|---:|---:|
| accumulator[5] | output[5] | 0.308 ns | 0.186 ns | 0.122 ns | +0.202 ns |
| accumulator[0] | output[0] | 0.405 ns | 0.186 ns | 0.219 ns | +0.297 ns |
| accumulator[6] | output[6] | 0.446 ns | 0.186 ns | 0.260 ns | +0.338 ns |
| accumulator[31] | output[3] | 0.446 ns | 0.186 ns | 0.260 ns | +0.342 ns |
| accumulator[31] | output[2] | 0.457 ns | 0.186 ns | 0.271 ns | +0.354 ns |
| accumulator[15] | output[1] | 0.586 ns | 0.231 ns | 0.355 ns | +0.458 ns |

The minimum slack among the supplied paths is **+0.196 ns**, matching the previously measured WHS.

## 7. Relationship to the existing timing summary

Previously measured implementation timing:

- WNS = +6.213 ns
- TNS = 0 ns
- WHS = +0.196 ns
- THS = 0 ns
- Failing setup endpoints = 0
- Failing hold endpoints = 0

The detailed report now explains the **hold** side of that summary. It confirms that the worst minimum-delay path has +0.196 ns margin.

The 0.288 ns data-path delay must **not** be interpreted as the ReLU's general propagation delay or as the setup-path delay. It belongs specifically to this implemented minimum-delay hold path. Setup analysis can select a different path and uses maximum delays.

## 8. Timing conclusion

The detailed hold report confirms:

`accumulator_reg Q → ReLU LUT → output_activation D`

has a positive hold margin for the worst reported path.

Therefore, the wrapper passes hold timing. Combined with the existing positive WNS and zero TNS, the implementation meets the 100 MHz timing constraint.

## 9. Remaining measurement

The remaining detailed timing report should be generated with:

`report_timing -setup -max_paths 10`

That report is required to analyze the **maximum-delay setup path** and determine its actual logic delay, routing delay, clock relationship, arrival time, required time, and slack. AMD documents `-setup` as maximum-delay analysis and `-hold` as minimum-delay analysis. citeturn1view0
