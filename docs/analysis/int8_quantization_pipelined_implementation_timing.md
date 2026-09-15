# INT8 Quantization — Pipelined Implementation Timing

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — TIMING-REFINEMENT POST-ROUTE MEASUREMENT  
**Status:** 100 MHz setup/hold timing closure observed; detailed critical-path inspection still pending

## 1. Assumptions

- The screenshots are from the implemented/routed `requantize_timing_wrapper` after the pipeline refinement.
- The active clock is `clk_100MHz` with a 10.000 ns period.
- The implementation uses the refined `requantize_relu_pipelined` that synthesized with one DSP48E1 and `PREG = 1`.
- These screenshots provide the top-level timing summary, but not yet the detailed worst Stage-1 and Stage-2 path cell breakdown.

## 2. Measured Post-Route Timing

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

Therefore the refined implementation closes timing at the 100 MHz / 10 ns target.

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

Slack improvement:

```text
+3.703 - (-0.405) = +4.108 ns
```

The setup violation is therefore removed with 3.703 ns of positive worst-case setup margin at the specified 10 ns clock.

Hold timing remains clean after the redesign. The hold margin changed from 0.795 ns to 0.694 ns, but remains positive and has zero failing endpoints.

## 4. What the Result Proves

This routed result proves, for the current measurement configuration and constraints:

```text
100 MHz setup timing : PASS
100 MHz hold timing  : PASS
TNS                  : 0
THS                  : 0
Pulse width timing   : PASS
```

The result is stronger than synthesis-only evidence because placement and routing delay are included.

## 5. Relationship to the Pipeline Refinement

The refined synthesis had already confirmed:

```text
DSP48E1 count = 1
PREG = 1
```

The post-route result now shows that the structural split is not merely inferred; it also resolves the original physical setup violation at 100 MHz.

The original long path combined:

```text
pre-DSP logic
-> DSP48E1
-> rounding carry chain
-> saturation/output logic
```

The refined architecture registers the DSP result before rounding/saturation. The measured WNS improvement of 4.108 ns is consistent with the intended effect of breaking that long path into two shorter register-to-register paths.

This is an interpretation supported by the architecture and timing result. The exact new Stage-1 and Stage-2 critical-path compositions still need to be inspected before claiming which stage is now dominant.

## 6. Fmax Caution

A positive WNS of 3.703 ns at a 10 ns constraint means the implementation has substantial margin at 100 MHz.

However, the simple quantity:

```text
10.000 ns - 3.703 ns = 6.297 ns
```

must not be treated as a formally measured minimum clock period or guaranteed Fmax without a dedicated tighter-clock timing sweep. Clock skew, uncertainty, setup terms, and implementation changes under a different constraint can alter the result.

Therefore the accepted statement is:

```text
100 MHz timing closure is proven for this implementation.
```

A higher-frequency Fmax claim remains unmeasured.

## 7. Remaining Measurement Work

Before closing the timing-refinement analysis completely, inspect the detailed worst setup path and identify:

```text
startpoint
endpoint
whether the worst path is Stage 1 or Stage 2
logic levels
logic delay
routing delay
DSP involvement
CARRY4 involvement
```

This is needed to explain why the refined design passes signal-by-signal and to characterize the new limiting stage.

## 8. Current Step-9 Status

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
100 MHz timing closure                : PROVEN
Detailed refined critical-path review : PENDING
```

The earlier synthesis-understanding checkpoint still requires the learner to explain why only 26 slice FFs remain even though a 42-bit product register exists. The `PREG` half of that checkpoint is already passed.