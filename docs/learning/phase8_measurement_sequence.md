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

---

## Project completion status update — 2026-11-18

**Project lifecycle status: COMPLETED (owner-confirmed).** The project owner confirms all phases are complete, the bitstream was programmed onto the physical Basys 3 FPGA, and expected output was observed. This supersedes earlier active-phase, pending, and pre-board-test status wording; original learning content and historical checkpoints remain preserved.

**Evidence boundary:** the owner supplied a Basys 3 board photograph in the project conversation. It documents the physical setup and illuminated indicators but does not independently establish exact latency, power, resource counts, or post-route timing. The historical docs/analysis/basys3_top_level.md report records WNS = -3.453 ns at the 100 MHz constraint; no newer timing report was supplied. Do not reinterpret the historical STA result as a pass without updated Vivado evidence.

The documented fixed demonstration vector produces accumulator 45 and requantized INT8 output 34 (0x22); LED1 and LED5 are result bits and LED8 is the latched completion indicator. The owner reports that the expected board output was observed.
