# Basys 3 Timing Closure — Step 9 Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 9 — measured-vs-predicted understanding gate  
**Status:** PASSED — fresh synthesis and implementation measurements are unlocked.

## Assessment

The learner correctly explained why pre-pipeline physical results cannot be reused as evidence for the modified RTL.

The old physical baseline was:

```text
LUT = 465
FF  = 138
WNS = -3.453 ns
```

After introducing `partial_sum_pipe`, the new RTL changes:

```text
register count
sequential boundaries
synthesis optimization opportunities
placement
routing
carry-chain partitioning
clock/data arrival relationships
potential critical-path location
```

Therefore the correct interpretation is:

```text
old physical results
-> comparison baseline only

new modified RTL
-> requires fresh synthesis and fresh implementation evidence
```

The learner correctly summarized:

```text
Old RTL -> 465 LUT, 138 FF, WNS = -3.453 ns
New RTL -> ? LUT, ? FF, WNS = ?
```

## Gate result

**BASYS3 TIMING CLOSURE STEP-9 UNDERSTANDING GATE: PASSED**

The next physical work is:

```text
fresh synthesis of modified RTL
-> fresh utilization report
-> fresh implementation
-> fresh post-route timing report
```

The old reports remain useful only for measured-before vs measured-after comparison.
