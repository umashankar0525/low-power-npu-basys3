# Phase 8 — Basys 3 Top-Level Simulation Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 8 — simulation + measurement understanding gate  
**Status:** PARTIAL — one correction required before Step 9.

## Passed concepts

### 1. Measured accelerator latency
**PASSED.**

The learner correctly converted:

```text
accepted_start_time = 0x429 = 1065 ns
raw_done_time       = 0x46F = 1135 ns
```

and derived:

```text
1135 ns - 1065 ns = 70 ns
```

which matches the predicted 7-cycle latency at 100 MHz.

### 2. Meaning of the memory checks
**PARTIAL — address-order correction required.**

The learner correctly understood that `request_count = 3` alone is not sufficient evidence. The testbench also checks the exact logical request order, activation/weight request pairing, and that returned data corresponds to the previous-cycle request.

However, the learner stated the request order as:

```text
1 -> 2 -> 3
```

The actual logical address sequence is:

```text
0 -> 1 -> 2
```

because the three packed operand words are stored at logical addresses 0, 1, and 2.

### 3. Behavioral versus physical proof
**PASSED IN PRINCIPLE.**

The learner correctly stated that BRAM use and physical timing require synthesis and implementation rather than behavioral simulation.

The precise evidence boundary is:

```text
BRAM inference / mapping
-> synthesis utilization / primitive report

100 MHz physical timing closure
-> implementation + post-route static timing analysis
-> WNS/TNS/WHS/THS
```

## Gate result

**BASYS3 TOP-LEVEL SIMULATION UNDERSTANDING GATE: NOT YET PASSED**

Before Step 9, the learner must correct the memory address order to:

```text
0 -> 1 -> 2
```

and restate why `request_count = 3` plus the zero-error assertions proves both sequencing and one-clock data-return behavior.
