# Phase 8 — Basys 3 Top-Level Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 6 — `/verify basys3_top_level` understanding gate  
**Status:** PASSED — Step 7 testbench generation is unlocked.

## Learner restatement assessment

### 1. Simulation debounce acceleration
**PASSED.** The learner correctly explained that reducing the debounce threshold changes only the human-interface waiting time. The simulation clock remains 100 MHz, so the accelerator's 7-cycle transaction latency remains 70 ns.

### 2. Button bounce rejection
**PASSED.** The learner correctly explained that unstable physical-button transitions must not create `start_rise` or `core_start`; only a signal that remains stable for the programmed debounce interval may be accepted.

### 3. Held-button behavior
**PASSED.** The learner correctly explained that the edge detector converts a long stable press into one rising event, so holding the button does not repeatedly retrigger the accelerator.

### 4. Memory sequencing and latency
**PASSED.** The learner correctly distinguished the address-order requirement (`0 -> 1 -> 2`) from the independent one-clock synchronous-read latency requirement. Both must be verified because the convolution schedule depends on both.

### 5. Accelerator latency measurement boundary
**PASSED.** The learner correctly stated that the 70 ns accelerator latency is measured from accepted internal `core_start`, not from the asynchronous physical button, because synchronizer/debounce latency belongs to the board interface.

### 6. Persistent completion status
**PASSED.** The learner correctly explained that `done_latched` is a board-side register that samples the raw `core_done` event and preserves it for human observation. This board observability delay does not change the accelerator's completion time.

### 7. Busy-mask verification condition
**PASSED.** The learner correctly identified the actual property under test:

```text
start_rise = 1
core_busy  = 1
=> core_start = 0
```

and correctly explained why merely pressing the physical button while busy is insufficient because synchronization/debounce latency can shift the resulting `start_rise` until after the core becomes idle.

### 8. Behavioral versus physical proof
**PASSED.** The learner correctly separated behavioral verification from implementation proof. RTL simulation can verify protocol, sequencing, data association, result, and status behavior, but BRAM inference must come from synthesis evidence and the 100 MHz physical timing requirement must come from post-route static timing analysis.

## Gate result

**BASYS3 TOP-LEVEL VERIFICATION UNDERSTANDING GATE: PASSED**

Step 6 is complete. The next permitted workflow action is:

```text
Step 7 — generate tb/integration/tb_basys3_top_level.v
```

Simulation must not be claimed until that testbench is generated and then actually run in Step 8.