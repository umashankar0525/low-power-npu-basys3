# INT8 Quantization — Measurement Wrapper Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 SUPPORT — MEASUREMENT WRAPPER UNDERSTANDING CHECK

## Assumptions

- `requantize_timing_wrapper` contains a launch register and a capture register only to create a meaningful register-to-register timing path.
- The arithmetic DUT under characterization remains the combinational `requantize_relu` block.
- `relu_timing_wrapper.xdc` and `requantize_timing_wrapper.xdc` each create a 100 MHz clock on a top-level `clk` port for different measurement wrappers.

## Learner checkpoint

### 1. Why wrapper registers are separated from the requantization resource count

**Status: PASSED**

The learner correctly explained that the wrapper registers exist only to establish the launch and capture timing boundaries required for static timing analysis. They are measurement scaffolding, not internal arithmetic or pipeline resources of `requantize_relu`, so they must not be counted as requantization-internal FFs.

### 2. Why only one clock-creation XDC should be active for this measurement

**Status: PASSED**

The learner correctly identified that multiple clock definitions can become a problem. More precisely, both measurement XDC files would attempt to create a clock constraint on the same active top-level `clk` port, which can create duplicate or conflicting timing constraints and make the timing interpretation ambiguous.

### 3. Why the older XDC should be disabled rather than deleted

**Status: NEEDS RESTATEMENT**

The old `relu_timing_wrapper.xdc` is still valid for the earlier ReLU-only timing characterization. It should therefore remain in the repository for reuse and traceability, but be disabled during the requantization timing run so that only the matching `requantize_timing_wrapper.xdc` clock constraint is active.

## Current gate

Before synthesis, the learner should restate why the old ReLU timing XDC is kept but disabled instead of being permanently deleted.
