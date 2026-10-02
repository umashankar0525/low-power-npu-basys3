# Basys 3 Timing Closure Stage 2 — Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure_stage2`  
**Workflow stage:** Step 2 — design understanding gate  
**Status:** PASSED — Step 3 analysis is unlocked.

## Assessment

The learner correctly explained the selected second timing-closure split.

### 1. Why split after the multipliers

Correctly identified the current path:

```text
BRAM
-> 4 x multipliers
-> reduction tree
-> partial_sum_pipe
```

and the new partition:

```text
Stage A1:
BRAM
-> 4 x multipliers
-> product registers

Stage A2:
product registers
-> reduction tree
-> partial_sum_pipe
```

This removes the reduction tree from the BRAM-to-multiplier timing stage.

### 2. Register-bit derivation

Correctly derived:

```text
4 products x 16 bits/product
= 64 RTL register bits
```

The learner also correctly noted that physical FF usage may differ after synthesis optimization.

### 3. Timing benefit

Correctly expressed the old requirement conceptually as:

```text
T_BRAM + T_mult + T_reduce < 10 ns
```

and the new requirements as approximately:

```text
T_BRAM + T_mult < 10 ns

T_reduce < 10 ns
```

with separate register boundaries.

### 4. Tradeoff

Correctly identified the intended tradeoff:

```text
+ approximately 64 register bits
+ one cycle latency
80 ns -> 90 ns
```

while preserving the same functional result.

## Gate result

**BASYS3 TIMING CLOSURE STAGE-2 DESIGN UNDERSTANDING GATE: PASSED**

Next workflow step:

```text
Step 3 — /analyze basys3_timing_closure_stage2
```
