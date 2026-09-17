# Phase 8 — Basys 3 Top-Level Testbench Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 7 — testbench understanding gate  
**Status:** PASSED — Step 8 simulation + measurement is unlocked.

## Learner restatement assessment

### 1. Latency measurement boundary
**PASSED.** The learner correctly explained that accelerator latency begins at the clock edge where `core_start` is actually sampled by the core, because synchronization/debounce delay belongs to the board interface rather than the accelerator compute path.

Expected accelerator latency remains:

```text
7 cycles x 10 ns = 70 ns
```

### 2. One-clock memory-latency proof
**PASSED.** The learner correctly explained that the scoreboard records each request and checks that the returned activation/weight data matches that previous-cycle request. This separately verifies both request ordering (`0 -> 1 -> 2`) and one-clock synchronous read timing.

### 3. Busy-mask verification point
**PASSED.** The learner correctly identified the exact property:

```text
start_rise = 1
core_busy  = 1
=> core_start = 0
```

and correctly explained why a physical button press by itself would not deterministically create this condition because synchronizer/debounce latency can shift the resulting event.

### 4. Why `PASS` alone is insufficient
**PASSED.** The learner correctly distinguished summary status from evidence. Verification evidence must include the observed relationships that justify the pass result, including accepted start timing, 70 ns raw completion latency, request/return association, result value, busy masking, and persistent done status.

## Gate result

**BASYS3 TOP-LEVEL TESTBENCH UNDERSTANDING GATE: PASSED**

The workflow may now proceed to:

```text
Step 8 — simulation + measurement
```

No simulation result is assumed or claimed until Vivado XSim is actually run and the transcript and/or waveform evidence is reviewed signal by signal.