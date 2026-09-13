# INT8 Quantization — Simulation Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 8 — SIMULATION UNDERSTANDING CHECK

## Assumptions

- The behavioral XSim run for `tb_requantize_relu` completed with all directed checks passing.
- The RTL unit under test is combinational.
- Target FPGA clock is 100 MHz, so the required clock period is 10 ns.
- Behavioral simulation checks logical function, not routed physical delay.

## Learner checkpoint

### 1. Why `acc=169` and `acc=170` both produce `q_out=127` but prove different behavior

**Status: PASSED**

For `M_INT=3` and `FRAC_BITS=2`:

```text
acc = 169
product = 169 × 3 = 507
q_pre = (507 + 2) >> 2 = 127
q_out = 127
```

This reaches 127 naturally without output saturation.

For:

```text
acc = 170
product = 170 × 3 = 510
q_pre = (510 + 2) >> 2 = 128
q_out = 127
```

This first produces 128 internally and only then saturates to 127. Therefore the two vectors produce the same final output while exercising different internal paths.

### 2. Why behavioral simulation PASS does not prove 10 ns timing closure

**Status: PASSED**

The learner correctly stated that synthesized/implemented timing information is required, including the critical path and setup slack, especially WNS.

Behavioral XSim verifies the logical relationship between inputs and outputs according to the RTL model. It does not model the final synthesized and routed FPGA path delays through DSP48E1 blocks, LUTs, carry chains, routing, clock skew, setup time, or placement-dependent delay.

The 100 MHz target requires:

```text
Tclk = 1 / 100 MHz = 10 ns
```

To prove the implementation meets that requirement, timing analysis must confirm that the critical register-to-register path satisfies the 10 ns constraint. In particular:

```text
WNS >= 0 ns
```

is required for setup timing closure under the applied 100 MHz constraint.

## Gate result

**SIMULATION UNDERSTANDING GATE: PASSED**

The learner has demonstrated understanding of both:

1. functional boundary-path verification, and
2. the difference between behavioral correctness and physical timing closure.

Step 8 behavioral functional verification is therefore complete. The next workflow stage is Step 9 measured-vs-predicted analysis, but physical resource and timing comparisons remain incomplete until synthesis/implementation measurements are available.