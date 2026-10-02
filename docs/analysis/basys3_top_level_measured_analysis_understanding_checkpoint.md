# Phase 8 — Basys 3 Top-Level Measured Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 9 — measured-vs-predicted analysis understanding gate  
**Status:** PARTIAL — two short clarifications required before the gate passes.

## Assessment

### 1. Why 70 ns predicted = 70 ns measured is stronger than a PASS line
**PARTIAL.**

The learner correctly stated that the measured result shows the original seven-cycle accelerator latency is preserved.

The remaining clarification is why this is stronger than merely seeing `PASS`:

```text
accepted_start_time = 1065 ns
raw_done_time       = 1135 ns
measured latency    = 70 ns
```

This is quantitative evidence that directly matches the prediction. A generic `PASS` line only summarizes that the testbench checks succeeded; by itself it does not show the measured latency value or its agreement with the prediction.

### 2. Why three paired request cycles equal six total 32-bit word reads
**PASSED.**

The learner correctly explained:

```text
3 paired cycles
= 3 activation-word reads
+ 3 weight-word reads
= 6 total 32-bit word reads
```

### 3. Why behavioral predictions can be validated while physical metrics remain unmeasured
**PARTIAL.**

The learner correctly distinguished behavioral validation from synthesis evidence.

The remaining clarification is:

- XSim can validate RTL behavior such as timing relationships, request sequencing, result values, busy masking, and reset protocol.
- XSim does not decide or model final FPGA resource mapping, placement, routing, or static timing.
- Therefore LUT/FF/BRAM/DSP mapping requires synthesis reports, while routed 100 MHz closure requires implementation/post-route STA.

## Gate result

**BASYS3 TOP-LEVEL STEP-9 UNDERSTANDING GATE: NOT YET PASSED**

The learner only needs to restate the two remaining distinctions:
1. why the numerical 70 ns measurement is stronger evidence than a generic PASS line;
2. why simulation can validate behavior but cannot measure physical resource mapping or routed timing.
