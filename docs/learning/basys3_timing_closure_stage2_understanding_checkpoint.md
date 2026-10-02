# Basys 3 Timing Closure Stage 2 — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure_stage2`  
**Workflow stage:** Stage-2 timing-closure teaching gate  
**Status:** PASSED — Stage-2 design work is unlocked.

## Assessment

The learner correctly explained why the first timing-closure pipeline moved the bottleneck.

### Before the first pipeline

The critical path combined:

```text
BRAM
-> multiplication/reduction
-> sign extension
-> INT32 accumulator addition
-> accumulator register
```

Thus Stage A arithmetic and Stage B accumulation both had to fit inside one 10 ns clock period.

### After the first pipeline

The inserted `partial_sum_pipe` split the path into:

```text
Stage A:
BRAM
-> multiplication/reduction
-> partial_sum_pipe

Stage B:
partial_sum_pipe
-> INT32 accumulator addition
-> accumulator
```

The learner correctly explained that the accumulator addition now has its own register-to-register timing budget.

### Measured critical-path migration

The learner stated that fresh STA would be required to confirm the new critical path.

That evidence is already available.

The fresh post-route timing report confirms the actual current worst path is:

```text
RAMB18E1 activation output
-> multiply/reduction logic
-> partial_sum_pipe_reg[17]/D
```

with:

```text
WNS        = -1.260 ns
data delay = 11.289 ns
logic      = 6.813 ns
route      = 4.476 ns
logic levels = 13
CARRY4       = 7
```

Therefore the next timing-closure iteration must target Stage A rather than the accumulator path.

## Gate result

**BASYS3 TIMING CLOSURE STAGE-2 TEACHING GATE: PASSED**

Next workflow step:

```text
/design basys3_timing_closure_stage2
```
