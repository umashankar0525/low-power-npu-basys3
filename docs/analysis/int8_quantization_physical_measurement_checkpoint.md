# INT8 Quantization — Physical Measurement Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — PHYSICAL MEASUREMENT PREPARATION  

## Assumptions

- Target FPGA is XC7A35T-1CPG236C on Basys 3.
- Target clock is 100 MHz, so the required clock period is 10 ns.
- The current `requantize_relu.v` default parameters are `M_INT=1` and `FRAC_BITS=0`.
- The physically interesting requantization path is a registered source-to-destination path, not an isolated unconstrained combinational block.

## Learner checkpoint

### 1. Why the default parameter configuration can give a misleading resource result

**Status: PASSED**

The learner correctly stated that a synthesis result such as `0 DSP` for the default `M_INT=1`, `FRAC_BITS=0` configuration would not disprove the earlier 1–2 DSP prediction. That configuration is trivial and allows Vivado to simplify or eliminate the wide multiplier because the arithmetic effectively collapses toward an identity operation.

Therefore resource measurements intended to evaluate the requantization architecture must use a nontrivial, explicitly identified coefficient/shift configuration, preferably the final layer-specific values when available. A representative configuration may be used for architectural measurement only if it is clearly labeled as representative rather than final.

### 2. Why standalone combinational synthesis does not prove the 10 ns requirement

**Status: PASSED**

The learner correctly stated that only a registered context provides the meaningful register-to-register setup path whose WNS can be compared against the 100 MHz clock requirement.

A standalone combinational `requantize_relu` block has no launch and capture registers defining the system setup path. The physical requirement we ultimately need to verify is conceptually:

```text
engine result register
  -> requantization combinational logic
  -> activation capture register
```

Static timing analysis on that registered path can report the critical path and setup slack, including WNS, relative to the 10 ns clock period.

## Gate result

**PHYSICAL-MEASUREMENT UNDERSTANDING GATE: PASSED**

The learner may now proceed to physical synthesis/timing measurement setup. Measured resource and timing claims must still be based on actual Vivado reports rather than prediction.
