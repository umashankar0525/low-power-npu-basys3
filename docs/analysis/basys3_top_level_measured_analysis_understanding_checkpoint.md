# Phase 8 — Basys 3 Top-Level Measured Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 9 — measured-vs-predicted analysis understanding gate  
**Status:** PASSED — Step 10 design review is unlocked.

## Assessment

### 1. Why 70 ns predicted = 70 ns measured is stronger than a PASS line
**PASSED.**

The learner correctly explained that the 70 ns result is backed by measured timestamps rather than only by a generic pass summary:

```text
accepted_start_time = 1065 ns
raw_done_time       = 1135 ns
measured latency    = 70 ns
```

Therefore the seven-cycle latency prediction is quantitatively validated.

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
**PASSED.**

The learner correctly distinguished the evidence domains.

Behavioral simulation validates RTL-level behavior such as:

```text
latency
request sequence
memory timing relationship
result value
busy/reset protocol
```

but does not determine final FPGA physical implementation.

Therefore:

```text
LUT / FF / BRAM / DSP utilization
-> synthesis evidence

routed setup/hold slack and 100 MHz physical closure
-> implementation + post-route static timing analysis
```

## Gate result

**BASYS3 TOP-LEVEL STEP-9 UNDERSTANDING GATE: PASSED**

Step 9 measured-vs-predicted behavioral analysis is complete.

The next workflow action is:

```text
Step 10 — /review basys3_top_level
```

The design review must explicitly distinguish the behaviorally verified portions from the still-pending physical evidence, including final board-top resource mapping, BRAM inference, routed timing, constraints, and hardware-board validation.
