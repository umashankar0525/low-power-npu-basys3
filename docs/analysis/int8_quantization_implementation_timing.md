# INT8 Quantization — Post-Implementation Timing Measurement

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED, IMPLEMENTATION TIMING SUBSTAGE  
**Status:** 100 MHz setup timing FAILS for the current unpipelined registered measurement wrapper; hold timing passes

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

and raises the implementation timing warning:

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

It is tempting to approximate the needed period as:

```text
10.000 ns + 0.405 ns = 10.405 ns
```

which corresponds to an approximate frequency near 96 MHz. This is only a rough interpretation because the exact maximum frequency depends on clock uncertainty, setup time, routing, and the precise critical path reported by static timing analysis. The implementation report should be treated as the authoritative source.

## 4. Why Seven Endpoints Fail

Synthesis previously optimized away `output_activation_reg[7]` because ReLU constrains the output range to 0...127, making the sign bit permanently zero.

Therefore only seven physical output capture flip-flops remain:

```text
output_activation[6:0]
```

The implementation timing summary reports:

```text
7 failing endpoints / 7 total setup endpoints
```

The detailed setup-path list confirms the seven endpoints are exactly:

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

Therefore there is no measured hold violation in this implementation.

The failure is specifically a **setup / maximum-delay** problem, not a minimum-delay/hold problem.

## 6. Prediction Versus Measurement

### Original timing prediction

Before synthesis and implementation, the architecture predicted:

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

These are independent properties.

The arithmetic can produce the correct answer and still produce it too late for the next 100 MHz capture edge.

## 8. Architectural Consequence

The previously predicted first refinement is now justified by measurement:

```text
insert one internal requantization pipeline register
```

The earlier control analysis identified an existing registered-handshake gap:

```text
S5: child engine registers result and engine_done
S6: outer FSM observes engine_done
S7: activation result is captured
```

A requantization register may potentially be placed at S6 so that the long path is divided into two shorter paths:

```text
S5 -> S6:
engine result register
  -> multiply / rounding portion
  -> requantization pipeline register

S6 -> S7:
requantization pipeline register
  -> final saturation/output selection
  -> activation capture register
```

If the register is aligned with the already existing S5-to-S6 handshake interval, it may be possible to improve timing without increasing the externally observed start-to-done latency.

This must be re-derived before RTL modification; it is not yet claimed as implemented behavior.

## 9. Detailed Worst Setup-Path Measurement

The implementation setup-path table identifies `Path 1` as the worst path because it has the most negative slack.

Measured values:

```text
Path name      : Path 1
Slack          : -0.405 ns
Logic levels   : 10
High fanout    : 18
From           : accumulator_reg_reg[4]/C
To             : output_activation_reg[6]/D
Total delay    : 10.362 ns
Logic delay    : 6.066 ns
Net delay      : 4.296 ns
Requirement    : 10.000 ns
```

The remaining six failing setup paths have slacks from `-0.372 ns` to `-0.250 ns`, so `Path 1` is the correct worst-path candidate.

Delay decomposition:

```text
logic fraction = 6.066 / 10.362 ≈ 58.5%
net fraction   = 4.296 / 10.362 ≈ 41.5%
```

This means the failure is not caused by routing alone. A majority of the measured path delay is logic delay, while routing still contributes a substantial fraction.

The simple difference:

```text
10.000 - 10.362 = -0.362 ns
```

does not exactly equal the reported slack `-0.405 ns`. The additional approximately `0.043 ns` comes from timing-analysis effects outside the raw data-path-delay column, such as clock-path/setup/uncertainty terms. Therefore the reported Vivado slack, not `requirement - total delay` alone, is the authoritative timing verdict.

This table is sufficient to identify the worst setup path and quantify its logic-versus-routing split. It is not yet sufficient to identify every primitive on the path or prove exactly where the DSP48E1, carry-chain, and saturation logic appear.

## 10. Detailed Cell-Level Path Information Still Needed

Before modifying the RTL pipeline boundary, open `Path 1` itself in Vivado and record the detailed timing path showing the sequence of cells/nets.

The remaining useful fields are:

```text
actual launch pin / register Q path
DSP48E1 cell and pins, if present
CARRY4/LUT sequence after the DSP
individual incremental delays
clock uncertainty/setup contribution
```

This will tell us whether the best pipeline split should be immediately after the DSP multiply/add, after rounding, or closer to the saturation/output logic.

## 11. Current Step 9 State

```text
Functional XSim verification        : COMPLETE / PASS
Synthesis resource measurement      : COMPLETE
Post-implementation setup timing    : COMPLETE / FAIL at 100 MHz
Post-implementation hold timing     : COMPLETE / PASS
Worst setup-path summary inspection : COMPLETE
Detailed cell-level path inspection : PENDING
Timing-closure RTL refinement       : NOT YET PERFORMED
```

Step 9 has now confirmed both the resource mapping and the timing limitation of the current baseline. The next action is to inspect the cell-level detail of `Path 1`, then re-derive the one-stage timing split before modifying RTL.
