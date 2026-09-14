# INT8 Quantization — Step 9 Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED UNDERSTANDING CHECK

## Assumptions

- The default RTL parameters are `M_INT = 1` and `FRAC_BITS = 0`.
- A trivial parameter configuration can be constant-folded or simplified by synthesis.
- The actual timing requirement is a registered FPGA path at 100 MHz, not an unregistered combinational block in isolation.
- The 100 MHz target corresponds to a 10 ns clock period.

## Learner checkpoint

### 1. Why the default parameter configuration can give a misleading resource count

**Status: PASSED**

The learner correctly stated that synthesizing the default `M_INT = 1`, `FRAC_BITS = 0` configuration can allow Vivado to simplify or remove the multiplier. Therefore a result such as `0 DSP` would describe that trivial specialization rather than disproving the earlier 1-to-2-DSP prediction for a nontrivial fixed-point requantization coefficient.

### 2. Why standalone combinational synthesis cannot prove the 10 ns requirement

**Status: PASSED**

The learner correctly stated that meaningful timing analysis requires a registered context so that Vivado can report the actual register-to-register setup path and its WNS. A standalone combinational `requantize_relu` block has no source and destination registers representing the intended system timing boundary, so it cannot by itself establish that the accelerator meets the 100 MHz requirement.

## Gate result

**STEP 9 UNDERSTANDING GATE: PASSED**

The next physical-measurement activity should use a nontrivial requantization configuration and a registered measurement wrapper or the real integrated registered datapath. Resource and timing measurements must remain clearly labeled as representative unless they use the final layer-specific `M_INT` and `FRAC_BITS` values.
