# Phase 8 — Physical Measurement Sequence

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization

## Decision

Phase 7 remains complete at the behavioral integration level. The missing synthesis/resource and post-route timing evidence for `convolution_integration` should be collected **inside Phase 8**, not used to reopen Phase 7.

## Recommended sequence

1. **Baseline physical characterization of `convolution_integration`**
   - synthesize the Phase-7 integrated core by itself,
   - record LUT/FF/CARRY/DSP utilization,
   - implement/place-route it with the 100 MHz constraint,
   - record WNS/TNS/hold slack and critical path.

2. **Design and build `basys3_top_level`**
   - add board input conditioning,
   - add/attach activation and weight memories,
   - add result/status observability,
   - add Basys-3 clock/pin constraints.

3. **Final physical characterization of the complete board top**
   - synthesize again,
   - implement again,
   - re-measure resources and timing,
   - compare against the `convolution_integration` baseline.

## Why measure twice?

The first run isolates the accelerator-core physical cost and timing. The second run measures the real board-level system after memory and infrastructure are added. The difference shows the incremental cost and timing impact of the Phase-8 wrapper.

This also prevents Phase-6 unit-level timing results from being incorrectly reused as proof for either the Phase-7 integrated core or the final Phase-8 board top.

## Gate concept

The learner should be able to explain why the baseline core synthesis/implementation belongs at the beginning of Phase 8 and why the final board-top synthesis/implementation must still be repeated after board integration.