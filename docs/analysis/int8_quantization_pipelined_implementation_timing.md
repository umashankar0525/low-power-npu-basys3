# INT8 Quantization — Pipelined Implementation Timing

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — TIMING-REFINEMENT POST-ROUTE MEASUREMENT  
**Status:** 100 MHz timing closure proven; refined worst setup path characterized

## 1. Assumptions

- The supplied screenshots are from the implemented/routed `requantize_timing_wrapper` after the pipeline refinement.
- The active clock is `clk_100MHz` with a 10.000 ns period.
- The implementation uses `requantize_relu_pipelined` with one DSP48E1 and `PREG = 1` as confirmed by the refined synthesis report.
- The timing report is from the slow-process setup corner shown by Vivado.
- The detailed path shown as `Path 1` is the global worst setup path because its slack equals the design WNS of `+3.703 ns`.

## 2. Measured Post-Route Timing Summary

Vivado reports:

```text
Setup WNS  = +3.703 ns
Setup TNS  = 0.000 ns
Failing setup endpoints = 0 / 37

Hold WHS   = +0.694 ns
Hold THS   = 0.000 ns
Failing hold endpoints = 0 / 37

Pulse-width WPWS = +4.500 ns
Pulse-width TPWS = 0.000 ns
Failing pulse-width endpoints = 0 / 28
```

Vivado explicitly reports:

```text
All user specified timing constraints are met.
```

Therefore the refined implementation closes setup, hold, and pulse-width timing at the 100 MHz / 10 ns target.

## 3. Comparison Against the Unpipelined Implementation

Previous unpipelined routed result:

```text
WNS = -0.405 ns
TNS = -2.381 ns
Failing setup endpoints = 7 / 7
WHS = +0.795 ns
```

Refined pipelined routed result:

```text
WNS = +3.703 ns
TNS = 0.000 ns
Failing setup endpoints = 0 / 37
WHS = +0.694 ns
```

Setup-slack improvement:

```text
+3.703 - (-0.405) = +4.108 ns
```

The original setup violation is therefore removed, and the refined implementation has 3.703 ns of positive worst-case setup margin at the specified 10 ns clock.

Hold timing remains clean. The worst hold slack changed from `+0.795 ns` to `+0.694 ns`, but there are still zero hold failures.

## 4. Refined Worst Setup Path

The new global worst setup path is `Path 1`.

Measured summary:

```text
Slack           = +3.703 ns
Source          = accumulator_reg_reg[31]/C
Destination     = u_requantize/product_reg_reg/B[8]
Path group      = clk_100MHz
Path type       = Setup (Max at Slow Process Corner)
Requirement     = 10.000 ns
Data path delay = 2.781 ns
Logic delay     = 0.642 ns
Route delay     = 2.139 ns
Logic levels    = 1 (LUT2 = 1)
Clock path skew = +0.056 ns
Clock uncertainty = 0.035 ns
```

The source data bit is the accumulator sign bit. The destination is a DSP48E1 data input feeding the product register implemented inside the DSP.

The top ten worst setup paths shown by Vivado all start from `accumulator_reg_reg[31]` and terminate on different DSP input bits belonging to `product_reg_reg`. Therefore the limiting stage after refinement is **Stage 1**:

```text
accumulator launch register
 -> ReLU/sign gating
 -> DSP multiplier input
 -> DSP internal product register (PREG)
```

Stage 2 is not the global limiting path because any Stage-2 path necessarily has slack greater than or equal to the global WNS of `+3.703 ns`.

## 5. Cell-by-Cell Data Path

The detailed routed path is:

```text
FDRE accumulator_reg_reg[31]/Q
    C->Q delay = 0.518 ns

route from accumulator sign bit
    net delay = 1.545 ns

LUT2 at SLICE_X10Y7
    logic delay = 0.124 ns

route to DSP48E1
    net delay = 0.593 ns

DSP48E1 at DSP48_X0Y2
    destination = product_reg_reg/B[8]
```

Summing the reported data-path increments:

```text
0.518 + 1.545 + 0.124 + 0.593
= 2.780 ns
```

which rounds to the Vivado-reported:

```text
Data Path Delay = 2.781 ns
```

The route component is:

```text
1.545 + 0.593 = 2.138 ns
```

which rounds to the reported `2.139 ns`.

The logic component is:

```text
0.518 + 0.124 = 0.642 ns
```

which exactly matches the report.

## 6. Logic Versus Routing After Pipelining

Vivado gives:

```text
Logic delay = 0.642 ns = 23.087%
Route delay = 2.139 ns = 76.913%
```

This is a major change from the original unpipelined critical path, where approximately 58.5% of the data-path delay was logic and 41.5% was routing.

After the DSP output pipeline register was introduced, the long chain containing the DSP, rounding carry chain, and saturation logic no longer lies in one register-to-register path. The new worst path contains only one LUT level before the DSP endpoint.

Therefore the refined Stage-1 path is now **routing-dominated rather than arithmetic-logic-dominated**.

The sign bit also has a reported high fanout of 18. This is consistent with the ReLU/sign decision controlling the 18-bit magnitude selection before the multiplier. That fanout contributes to the routing significance of this path.

## 7. Important DSP Timing Interpretation

The data-path table reports only `2.781 ns`, but the DSP's internal registered timing cost is not represented as a normal LUT-style propagation level in that number.

The destination clock-path calculation includes a DSP setup term of approximately:

```text
DSP48E1 setup term = 3.536 ns
```

Vivado reports:

```text
Arrival Time  = 7.352 ns
Required Time = 11.055 ns
```

so:

```text
Slack = 11.055 - 7.352
      = +3.703 ns
```

This explains why it would be incorrect to estimate slack as simply:

```text
10.000 - 2.781
```

The proper timing analysis includes source and destination clock insertion, clock pessimism, uncertainty, and the DSP48E1 setup requirement associated with its internal registered stage.

## 8. Why the Pipeline Fix Worked

The original failing path contained:

```text
launch register
 -> pre-DSP LUT logic
 -> DSP48E1 combinational operation
 -> CARRY4 rounding chain
 -> saturation/output LUTs
 -> activation capture register
```

The refined design inserts the product register at the DSP boundary. Synthesis confirms this is implemented as:

```text
DSP48E1 PREG = 1
```

The resulting physical structure separates the operation into two timing stages:

```text
Stage 1:
accumulator register
 -> sign/ReLU gating
 -> DSP
 -> DSP PREG

Stage 2:
DSP PREG
 -> rounding
 -> shift
 -> saturation
 -> activation register
```

The new global worst path is Stage 1, and it passes with `+3.703 ns` slack. Therefore the pipeline split successfully removed the original long combinational dependency through both the DSP and the post-DSP arithmetic.

## 9. Resource and Timing Result Together

The refined synthesis measured:

```text
LUTs        = 27
Slice FFs   = 26
DSP48E1     = 1
CARRY4      = 5
DSP PREG    = 1
BRAM        = 0
```

The 42-bit product register does not appear in the Slice Register count because it is implemented inside the DSP48E1 `PREG`.

The 26 slice FFs are:

```text
1 sign bit + 18 magnitude bits = 19 accumulator FFs
7 output FFs                    = 7
----------------------------------
total                           = 26
```

The resource-mapping understanding checkpoint for this accounting has passed.

## 10. Fmax Caution

A positive WNS of `+3.703 ns` at a 10 ns constraint proves timing closure at 100 MHz.

Although:

```text
10.000 - 3.703 = 6.297 ns
```

this must not be treated as a formally measured minimum clock period or guaranteed Fmax. A tighter clock constraint can change placement, routing, clock uncertainty impact, and optimization choices.

Accepted claim:

```text
100 MHz timing closure is proven for this implementation.
```

Higher-frequency Fmax remains unmeasured.

## 11. Step-9 Timing-Refinement Verdict

```text
Refined behavioral verification       : COMPLETE / PASS
Refined synthesis                     : COMPLETE
DSP48E1                               : 1
DSP PREG                              : 1
Post-route setup timing               : PASS
WNS                                    : +3.703 ns
TNS                                    : 0.000 ns
Post-route hold timing                : PASS
WHS                                    : +0.694 ns
THS                                    : 0.000 ns
Pulse-width timing                    : PASS
100 MHz timing closure                : PROVEN
New limiting stage                    : STAGE 1
Worst-path data delay                 : 2.781 ns
Worst-path logic levels               : 1 LUT2
Worst-path delay composition          : 23.087% logic / 76.913% routing
Detailed refined critical-path review : COMPLETE
```

The timing-refinement physical measurement is now fully characterized for the present 100 MHz measurement configuration.