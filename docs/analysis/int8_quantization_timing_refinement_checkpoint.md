# INT8 Quantization — Timing Refinement Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — TIMING-CLOSURE REFINEMENT UNDERSTANDING CHECK

## Assumptions

- Current routed baseline uses the representative nontrivial configuration `M_INT = 13,421,773`, `FRAC_BITS = 27`.
- Target clock remains 100 MHz, so each synchronous stage has a nominal 10 ns period.
- Current unpipelined implemented path has `WNS = -0.405 ns`.
- The worst measured path contains the DSP48E1 multiply/add, carry-chain rounding logic, output logic, and routing.
- The approximate present-path split around the DSP was estimated as roughly `6.890 ns` before the proposed register and `3.472 ns` after it.

## Learner checkpoint

### 1. Why a register after the DSP can improve timing

**Status: PASSED**

The learner correctly explained that adding a pipeline register after the DSP divides the original long combinational register-to-register path into two shorter synchronous paths. Each new path then receives its own clock-cycle timing budget instead of requiring the entire multiply, rounding, saturation, and routing chain to complete within one cycle.

### 2. Why the estimated 6.890 ns / 3.472 ns split is not a guaranteed post-redesign timing result

**Status: PASSED**

The learner correctly explained that changing the RTL changes the physical implementation problem. Vivado may choose different placement, routing, logic mapping, and optimization after the new register is inserted. Therefore the two values are only first-order estimates derived from the existing routed critical path. They must not be treated as measured timing for the redesigned pipeline.

## Gate result

**TIMING-REFINEMENT UNDERSTANDING GATE: PASSED**

The performance-analysis evidence is now sufficient to justify a design refinement proposal. Before any RTL modification, the next role should re-derive the pipeline boundary and control-cycle alignment, especially whether the added register can be placed in the existing S5-to-S6 handshake interval without adding an externally visible transaction cycle.
