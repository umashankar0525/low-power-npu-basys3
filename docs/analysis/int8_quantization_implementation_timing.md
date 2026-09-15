# INT8 Quantization — Post-Implementation Timing Measurement

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED, IMPLEMENTATION TIMING SUBSTAGE  
**Status:** 100 MHz setup timing FAILS for the current unpipelined registered measurement wrapper; hold timing passes; detailed critical path inspected

## 1. Assumptions

- The timing screenshots are from the implemented/routed `requantize_timing_wrapper` design.
- The active clock is `clk_100MHz` with a 10.000 ns period.
- The measurement wrapper still uses the representative nontrivial parameters:

```text
M_INT     = 13,421,773
FRAC_BITS = 27
```

- The source register is the wrapper accumulator register.
- The destination register is the wrapper output activation register.
- No internal pipeline register has yet been inserted into `requantize_relu`.

## 2. Measured Timing Summary

The implementation timing summary reports:

```text
Clock: clk_100MHz
Setup WNS = -0.405 ns
Setup TNS = -2.381 ns
Setup failing endpoints = 7 / 7

Hold WHS = +0.795 ns
Hold THS = 0.000 ns
Hold failing endpoints = 0 / 7

Worst Pulse Width Slack = +4.500 ns
Total Pulse Width Negative Slack = 0.000 ns
```

Vivado also reports:

```text
Timing constraints are not met.
```

and raises:

```text
[Timing 38-282] The design failed to meet the timing requirements.
```

## 3. Setup-Timing Interpretation

For a 100 MHz clock:

```text
Tclk = 1 / 100 MHz = 10.000 ns
```

Setup slack is conceptually:

```text
setup_slack = required_arrival_time - actual_arrival_time
```

The measured worst setup slack is:

```text
WNS = -0.405 ns
```

A negative value means the worst data path arrives too late. The path misses its required setup deadline by 0.405 ns.

Therefore the current unpipelined register-to-register path does not meet the 10 ns requirement.

A rough period estimate is:

```text
10.000 ns + 0.405 ns = 10.405 ns
```

which is near 96 MHz. This is not a formal Fmax because setup time, clock uncertainty, routing, and clock-path effects are included in static timing analysis.

## 4. Why Seven Endpoints Fail

Synthesis optimized away `output_activation_reg[7]` because ReLU constrains the output range to 0...127, making the sign bit permanently zero.

Therefore only seven physical output capture flip-flops remain:

```text
output_activation[6:0]
```

The seven failing endpoints are:

```text
output_activation_reg[6]/D
output_activation_reg[2]/D
output_activation_reg[1]/D
output_activation_reg[5]/D
output_activation_reg[4]/D
output_activation_reg[3]/D
output_activation_reg[0]/D
```

Therefore every physically implemented output capture bit fails setup in this baseline implementation.

## 5. Hold-Timing Interpretation

The worst hold slack is positive:

```text
WHS = +0.795 ns
```

and:

```text
THS = 0.000 ns
hold failing endpoints = 0
```

Therefore there is no measured hold violation. The failure is specifically a setup / maximum-delay problem.

## 6. Prediction Versus Measurement

### Original timing prediction

```text
100 MHz feasibility: plausible but unproven
risk level: moderate
new dominant path: fixed-point requantization multiplier + rounding/saturation logic
preferred fallback if timing fails: one registered requantization stage
```

### Measured implementation result

```text
WNS = -0.405 ns
TNS = -2.381 ns
setup endpoints failing = 7 / 7
```

### Comparison

```text
Prediction: 100 MHz might be achievable, but the unpipelined path carried moderate timing risk.
Measured:   the current unpipelined registered wrapper misses setup timing by 0.405 ns worst case.
Result:     timing risk CONFIRMED; 100 MHz closure NOT achieved in the current structure.
```

## 7. Why This Is Not a Functional Failure

The earlier XSim behavioral verification passed all directed numerical checks.

Therefore:

```text
functional correctness = PASS
physical 100 MHz setup timing = FAIL
```

The arithmetic can produce the correct answer and still produce it too late for the next 100 MHz capture edge.

## 8. Detailed Worst Setup-Path Summary

The implementation setup-path table identifies `Path 1` as the worst path.

```text
Slack          = -0.405 ns
Logic levels   = 10
High fanout    = 18
Source         = accumulator_reg_reg[4]/C
Destination    = output_activation_reg[6]/D
Data path      = 10.362 ns
Logic delay    = 6.066 ns
Net delay      = 4.296 ns
Requirement    = 10.000 ns
Clock skew     = -0.039 ns
Clock uncertainty = 0.035 ns
```

Delay fractions:

```text
logic fraction = 6.066 / 10.362 ≈ 58.5%
net fraction   = 4.296 / 10.362 ≈ 41.5%
```

This proves the failure is not caused by routing alone. Logic delay is the larger component, while routing is still substantial.

The learner correctly restated this point: the combinational arithmetic is a major cause of the timing failure, not merely placement/routing.

## 9. Exact Cell-Level Critical Path

The detailed routed report exposes the following data-path sequence from the launch register to the capture register:

```text
FDRE clock-to-Q
 -> routed net
 -> LUT4
 -> routed net
 -> LUT6
 -> routed net
 -> LUT5
 -> routed net
 -> DSP48E1
 -> routed net
 -> LUT1
 -> CARRY4
 -> CARRY4
 -> CARRY4
 -> routed net
 -> LUT4
 -> routed net
 -> LUT4
 -> output_activation_reg[6]/D
```

Vivado summarizes the 10 combinational logic levels as:

```text
CARRY4   = 3
DSP48E1  = 1
LUT1     = 1
LUT4     = 3
LUT5     = 1
LUT6     = 1
```

The major incremental logic delays visible in the path are:

```text
launch FF clock-to-Q     = 0.518 ns
pre-DSP LUT4             = 0.124 ns
pre-DSP LUT6             = 0.124 ns
pre-DSP LUT5             = 0.124 ns
DSP48E1                  = 3.656 ns
post-DSP LUT1            = 0.124 ns
CARRY4 #1                = 0.533 ns
CARRY4 #2                = 0.117 ns
CARRY4 #3                = 0.315 ns
post-carry LUT4          = 0.307 ns
final LUT4               = 0.124 ns
```

These cell delays sum to the reported logic delay:

```text
0.518 + 0.124 + 0.124 + 0.124 + 3.656 + 0.124
+ 0.533 + 0.117 + 0.315 + 0.307 + 0.124
= 6.066 ns
```

The DSP48E1 alone contributes:

```text
3.656 / 6.066 ≈ 60.3% of the logic delay
3.656 / 10.362 ≈ 35.3% of the full data-path delay
```

The three CARRY4 stages contribute:

```text
0.533 + 0.117 + 0.315 = 0.965 ns
```

which is:

```text
0.965 / 6.066 ≈ 15.9% of logic delay
0.965 / 10.362 ≈ 9.3% of total data-path delay
```

The LUT logic plus launch clock-to-Q accounts for the remainder of the logic delay.

## 10. Routing Interpretation

The total routed-net contribution is:

```text
4.296 ns
```

The visible significant routed increments are distributed across the path, including values around:

```text
0.533 ns
0.601 ns
0.693 ns
0.517 ns
0.680 ns
0.644 ns
0.628 ns
```

There is no single routing segment that alone explains the failure. The routing penalty is accumulated across many boundaries, especially around the pre-DSP logic, DSP-to-fabric transition, carry chain, and final output logic.

This reinforces the conclusion that placement optimization alone is not the strongest architectural fix. The current path is intrinsically long because it crosses pre-processing logic, one DSP48E1, rounding/correction carry logic, and output saturation logic in one clock period.

## 11. Clock-Path Terms and Exact Slack

The detailed report gives:

```text
Data arrival time  = 14.920 ns
Required time      = 14.515 ns
Slack              = 14.515 - 14.920
                   = -0.405 ns
```

The destination-clock calculation includes:

```text
clock pessimism correction = +0.322 ns
clock uncertainty          = -0.035 ns
capture FF setup time      = 0.031 ns
```

and the report also shows clock-path skew of approximately `-0.039 ns`.

This explains why simply subtracting the raw 10.362 ns data-path delay from the nominal 10.000 ns period does not reproduce the official WNS. Vivado's full setup equation is authoritative.

## 12. Pipeline-Split Implication From Measured Delays

The detailed path strongly supports the previously predicted one-stage refinement.

If a register were placed immediately after the DSP output, the existing measured path divides approximately into:

```text
source FF -> pre-DSP logic -> DSP       ≈ 6.890 ns of current data-path delay
post-DSP rounding/saturation -> output  ≈ 3.472 ns of current data-path delay
```

These are not post-refinement timing guarantees because adding a register changes placement, routing, setup terms, and optimization. They are first-principles estimates derived from the measured current path.

A boundary after the rounding/carry portion would move more work into the first stage. From the present path, the approximate delay through the DSP plus the three CARRY4 rounding stages is still below the current 10 ns requirement, but it leaves less margin than a boundary immediately after the DSP.

Therefore the detailed report establishes two useful facts before redesign:

```text
1. the DSP is the single largest logic-delay element;
2. the long path continues through rounding carry logic and saturation LUTs after the DSP.
```

The exact architectural pipeline boundary must be re-derived with the control schedule before RTL is changed.

## 13. Learner Understanding Checkpoint

**Status: PASSED**

The learner correctly stated that the approximately 58.5% logic / 41.5% routing split means the combinational logic takes more time than routing and that the arithmetic itself is a major cause of the timing problem.

The detailed cell report now strengthens that statement by identifying the DSP48E1 as the largest single logic-delay contributor and showing additional delay through three CARRY4 stages and final LUT logic.

## 14. Current Step 9 State

```text
Functional XSim verification        : COMPLETE / PASS
Synthesis resource measurement      : COMPLETE
Post-implementation setup timing    : COMPLETE / FAIL at 100 MHz
Post-implementation hold timing     : COMPLETE / PASS
Worst setup-path summary inspection : COMPLETE
Detailed cell-level path inspection : COMPLETE
Timing cause localization           : COMPLETE
Timing-closure RTL refinement       : NOT YET PERFORMED
```

The next analysis task is to re-derive the one-stage pipeline split against the existing S5/S6/S7 control schedule before any RTL modification is permitted.
