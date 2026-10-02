# Basys 3 Timing Closure — Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 6 — verification understanding gate  
**Status:** PASSED — Step 7 verification-artifact generation is unlocked.

## Assessment

The learner correctly explained all required verification concepts.

### 1. Final-output-only checking is insufficient

Correctly explained that a faulty pipeline schedule could still accidentally produce `0x22`, so internal cycle-by-cycle behavior must be observed.

### 2. Expected partial sums

```text
S0 = 10
S1 = 26
S2 = 9
```

### 3. Expected accumulator progression

```text
after S0 -> 10
after S1 -> 36
final     -> 45
```

### 4. Memory request count

Correctly explained that the redesign changes computation timing, not operand volume, so the transaction still requires exactly three paired memory requests.

### 5. Pipeline reset requirement

Correctly explained that `partial_sum_pipe` is new sequential state and must be reset to prevent stale partial sums from contaminating a later transaction.

### 6. Completion pulse semantics

Correctly explained that `done` must remain one cycle wide so one completed transaction corresponds to one completion event.

### 7. Latency derivation

```text
8 cycles x 10 ns = 80 ns
```

### 8. Latency measurement point

Correctly distinguished:

```text
physical button
-> synchronization/debounce latency

accepted core_start
-> accelerator transaction latency
```

Therefore accepted `core_start` is the correct measurement origin.

### 9. Simulation proof boundary

Correctly explained that RTL simulation proves function and cycle sequencing but cannot prove placement/routing delay or post-route timing closure.

### 10. Final timing-closure requirements

```text
WNS  >= 0 ns
TNS  = 0 ns
WHS  >= 0 ns
THS  = 0 ns
WPWS >= 0 ns
TPWS = 0 ns
```

## Gate result

**BASYS3 TIMING CLOSURE STEP-6 VERIFICATION UNDERSTANDING GATE: PASSED**

The workflow may now proceed to:

```text
Step 7 — verification artifact generation
```

The artifact must verify both the internal timing-closure pipeline and the integrated top-level 80 ns transaction behavior before synthesis and implementation are rerun.
