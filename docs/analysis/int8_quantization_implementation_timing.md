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

This is strongly consistent with every physically implemented output bit of the capture register being reached through the same long requantization datapath.

This interpretation should be confirmed by opening the detailed setup path report and checking the seven endpoint names.

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

## 9. Information Still Needed From the Detailed Timing Report

The screenshots provide the summary values but do not yet expose the exact worst path.

Before changing RTL, record the worst setup path details:

```text
startpoint register
endpoint register
data path delay
logic delay vs routing delay
DSP48E1 involvement
number of logic levels
clock uncertainty / setup requirement
```

This will tell us whether the dominant delay is mainly:

```text
DSP multiplier
DSP-to-fabric transition
carry-chain rounding/correction
saturation/reduction logic
routing
```

and therefore where the pipeline boundary should be placed.

## 10. Current Step 9 State

```text
Functional XSim verification        : COMPLETE / PASS
Synthesis resource measurement      : COMPLETE
Post-implementation setup timing    : COMPLETE / FAIL at 100 MHz
Post-implementation hold timing     : COMPLETE / PASS
Detailed critical-path inspection   : PENDING
Timing-closure RTL refinement       : NOT YET PERFORMED
```

Step 9 has now confirmed both the resource mapping and the timing limitation of the current baseline. The next action is to inspect the exact worst setup path, then re-derive the one-stage timing split before modifying RTL.
