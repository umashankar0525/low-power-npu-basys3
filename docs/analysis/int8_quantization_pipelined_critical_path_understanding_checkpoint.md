# INT8 Quantization — Pipelined Critical-Path Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — REFINED CRITICAL-PATH UNDERSTANDING CHECK

## Assumptions

- The routed refined design is `requantize_timing_wrapper` using `requantize_relu_pipelined`.
- The target clock is 100 MHz, so the clock period is 10.000 ns.
- The global worst setup path has WNS = +3.703 ns.
- The refined worst path begins at `accumulator_reg_reg[31]` and ends at the DSP48E1 product register input.
- The DSP48E1 product register is implemented with `PREG = 1`.

## Learner checkpoint

### 1. Why Stage 1 is the limiting stage

**Status: PASSED**

The learner correctly stated that the global WNS path belongs to Stage 1 and that the DSP lies in Stage 1. Since the design-wide worst setup slack is produced by the path from the accumulator launch register into the DSP internal product register, Stage 1 is the current timing-limiting stage.

The refined Stage-1 path is:

```text
accumulator register
 -> sign/ReLU gating
 -> DSP input
 -> DSP48E1 PREG
```

### 2. Why slack is not simply `10 ns - 2.781 ns`

**Status: PASSED**

The learner correctly identified that the DSP registered endpoint has its own setup requirement. Vivado's setup analysis also includes clock insertion, skew, clock pessimism, uncertainty, and endpoint setup timing.

Therefore the reported 2.781 ns data-path delay is only one part of the full setup equation. Vivado reports:

```text
Arrival Time  = 7.352 ns
Required Time = 11.055 ns
Slack         = +3.703 ns
```

and this full static-timing result, rather than `10 - 2.781`, is the correct timing verdict.

## Gate result

**PIPELINED CRITICAL-PATH UNDERSTANDING GATE: PASSED**

The refined physical timing behavior is now understood well enough to close the Step-9 measured-vs-predicted analysis for the present representative configuration.