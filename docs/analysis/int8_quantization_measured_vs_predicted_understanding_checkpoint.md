# INT8 Quantization — Measured vs Predicted Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED UNDERSTANDING CHECK

## Assumptions

- The current `requantize_relu.v` defaults are `M_INT = 1` and `FRAC_BITS = 0`.
- Those defaults do not exercise the intended nontrivial fixed-point multiplication path.
- The current `requantize_relu.v` block is combinational.
- The system target is 100 MHz, corresponding to a 10 ns clock period.

## Learner checkpoint

### 1. Why the default parameter set can produce a misleading resource count

**Status: PASSED**

The learner correctly stated that a synthesis result such as `0 DSP` for `M_INT=1, FRAC_BITS=0` would not disprove the earlier 1–2 DSP prediction. That parameter set is trivial enough that synthesis can optimize the multiplication away, so it is not representative of the intended requantization datapath.

### 2. Why the standalone combinational block cannot prove the 10 ns timing requirement

**Status: PASSED**

The learner correctly stated that a meaningful 100 MHz timing check requires a registered context so that static timing analysis has a real register-to-register setup path and can report WNS against the 10 ns requirement.

A standalone combinational block can be synthesized for area estimation, but by itself it does not represent the actual engine-result-register to activation-capture-register timing path that matters architecturally.

## Final learner restatement

The learner explicitly confirmed both required ideas:

1. A `0 DSP` result from the trivial default parameter configuration would only show that Vivado optimized that special case; it would not invalidate the nontrivial 1–2 DSP prediction.
2. Only a registered source-to-destination context creates the meaningful setup path whose WNS can be compared with the 10 ns requirement.

## Gate result

**STEP 9 UNDERSTANDING GATE: PASSED**

The next physical-measurement task is to synthesize a nontrivial representative requantization configuration and measure resource usage in a registered context before completing the Step 9 measured-vs-predicted comparison.
