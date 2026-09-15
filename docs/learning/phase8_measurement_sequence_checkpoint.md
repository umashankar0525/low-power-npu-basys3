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

**Status: NOT YET PASSED**

The learner did not yet state the second reason explicitly. The complete board top adds infrastructure such as memories, synchronizers/debouncers, one-pulse generation, status/LED logic, and additional routing/fanout. Those additions can change both resource usage and timing.

The second physical run is therefore needed to measure the final board-level design and compare it against the core-only baseline:

```text
board-wrapper resource overhead
= final board-top resources - core-only resources
```

and to determine whether the added infrastructure changes the critical path or 100 MHz timing closure.

## Gate result

**BASELINE-MEASUREMENT CONCEPT: PARTIAL**

The core-only measurement purpose is understood. The learner must still restate why the full board top must be synthesized and implemented again after Phase-8 integration.