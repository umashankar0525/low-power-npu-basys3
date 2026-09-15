# Phase 8 — Baseline Physical Measurement Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization

## Learner response

### Why characterize `convolution_integration` before the board wrapper

**Status: PASSED**

The learner correctly identified that synthesizing and implementing the core first provides isolated physical measurements for the accelerator itself, including:

```text
LUT
FF
CARRY
DSP
WNS
WHS
TNS
THS
100 MHz timing-closure status
critical path
```

This baseline also allows any timing violation in the core to be identified and corrected before board-level infrastructure is added.

### Why repeat synthesis/implementation after `basys3_top_level`

**Status: PASSED**

The learner correctly stated that the complete board top adds memories, input-conditioning logic, pulse-generation logic, status/LED logic, and additional routing/fanout. These additions can change both resource usage and timing paths.

Therefore the final board-level design must be synthesized and implemented again so that we can:

```text
measure final LUT/FF/CARRY/DSP/BRAM usage
measure final WNS/TNS/WHS/THS
check whether 100 MHz still closes
identify any new critical path
compare final board-top cost against the core-only baseline
```

Conceptually:

```text
board-wrapper resource overhead
= final board-top resources - core-only resources
```

and timing must also be re-evaluated because the added hierarchy, placement, routing, fanout, and memory resources can alter physical path delays.

## Gate result

**BASELINE-MEASUREMENT CONCEPT: PASSED**

The learner now understands both why `convolution_integration` is physically characterized first and why synthesis/implementation must be repeated after `basys3_top_level` is built.

The next permitted activity is Phase-8 baseline physical characterization of `convolution_integration` before proceeding deeper into board-top design.