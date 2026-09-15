# INT8 Quantization — Timing-Refinement Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 SUPPORT — TIMING-REFINEMENT DESIGN UNDERSTANDING CHECK

## Assumptions

- The measured baseline worst setup path contains pre-DSP LUT logic, one DSP48E1, post-DSP carry-chain rounding logic, and output/saturation LUT logic.
- The selected refinement inserts a 42-bit product pipeline register immediately after the DSP result and before rounding.
- The child engine registers its final convolution `result` and `done` together at S5.
- The outer control FSM does not capture the final activation until S7.
- The current architectural goal is to preserve the existing 70 ns external start-to-done latency if timing closure can be achieved with the hidden S5-to-S6 pipeline stage.

## Learner checkpoint

### 1. Why the DSP output is the selected pipeline boundary

**Status: PASSED**

The learner correctly explained that the DSP is the largest single delay contributor on the measured critical path and that the post-DSP CARRY4/output logic is also significant. Therefore placing the register after the DSP divides the long path into two useful stages. A register after the entire requantization block would not split the failing path, while placing it before the DSP would leave the DSP and post-DSP arithmetic together in the next stage.

### 2. Why the product register captures the completed result at S6 rather than S5

**Status: PASSED**

The learner correctly explained that the completed engine result is only registered at S5. Because sequential elements update on the same edge, the new result cannot propagate through the combinational DSP and also be captured by the product register on that same S5 edge. During S5-to-S6, the new result propagates through the DSP, and the 42-bit product register captures it at S6.

### 3. Why no additional FSM state is required

**Status: PASSED**

The learner correctly stated that the new register uses the already-existing registered-handshake interval. The final activation was already scheduled to be captured at S7, so the new S6 product register can occupy the existing gap without adding another supervisory state. Therefore the external start-to-done latency can potentially remain 70 ns, subject to successful re-synthesis and implementation timing.

## Gate result

**TIMING-REFINEMENT DESIGN UNDERSTANDING GATE: PASSED**

The timing-refinement architecture is now understood and the project is permitted to proceed to the RTL refinement implementation. After implementation, the refined datapath must be re-verified functionally and then re-synthesized/re-implemented before any 100 MHz timing-closure claim is made.
