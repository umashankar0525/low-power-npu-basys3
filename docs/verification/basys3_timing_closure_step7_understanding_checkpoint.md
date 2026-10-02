# Basys 3 Timing Closure — Step 7 Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 7 verification-artifact understanding gate  
**Status:** PASSED — Step 8 simulation is unlocked.

## Assessment

The learner correctly explained why the timing-closure testbench must verify intermediate pipeline state rather than only the final board result.

### Registered-state observation

The learner correctly identified that DUT sequential logic updates on the rising clock edge using nonblocking assignments.

Therefore sampling at the following falling edge allows the testbench to observe the post-update registered values.

Expected progression:

```text
after E2:
partial_sum_pipe = 10
accumulator      = 0

after E3:
partial_sum_pipe = 26
accumulator      = 10

after E4:
partial_sum_pipe = 9
accumulator      = 36

after E5:
final engine result = 45
```

### Why final-output-only checking is insufficient

The learner correctly explained that:

```text
activation_out = 34
```

alone would prove only the final arithmetic result for the directed vector.

It would not prove that the new pipeline schedule is architecturally correct.

Intermediate checks are required to detect:

```text
wrong partial-sum timing
wrong accumulator timing
off-by-one FSM state
data/control misalignment
stale partial_sum_pipe contents
```

### Gate result

**BASYS3 TIMING CLOSURE STEP-7 UNDERSTANDING GATE: PASSED**

The workflow may now proceed to:

```text
Step 8 — behavioral simulation and measurement
```

Expected simulation evidence:

```text
PASS with zero errors
three paired operand requests
S0 = 10
S1 = 26
S2 = 9
accumulator progression 0 -> 10 -> 36
engine result = 45
activation_out = 34 / 0x22
accepted core_start -> raw core_done = 80 ns
exactly one completion event
```
