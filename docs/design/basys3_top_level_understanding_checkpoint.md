# Phase 8 — Basys 3 Top-Level Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 2 — `/design basys3_top_level` understanding gate  
**Status:** PASSED — Step 3 `/analyze basys3_top_level` is unlocked.

## Learner restatement assessment

### 1. Reuse of `convolution_integration`
**PASSED.** The learner correctly explained that the board top must integrate the already designed and verified accelerator core rather than duplicate convolution logic.

### 2. Start-signal conditioning order
**PASSED.** The learner correctly explained the purpose and ordering of synchronizer, debouncer, one-cycle pulse generation, and busy masking.

### 3. Debounce-counter derivation
**PASSED.** At 100 MHz, one cycle is 10 ns. A 10 ms interval therefore spans 1,000,000 clock cycles. Since `2^19 = 524,288 < 1,000,000` and `2^20 = 1,048,576 >= 1,000,000`, a 20-bit counter is required.

### 4. One-clock memory-read contract
**PASSED.** The learner correctly stated that Phase 8 must preserve the one-clock synchronous-read behavior assumed by the Phase-7 engine schedule.

### 5. Packed-word ordering
**PASSED.** The learner correctly explained little-lane packing:

```text
[1,2,3,4] -> 0x04030201
[5,6,7,8] -> 0x08070605
[9,0,0,0] -> 0x00000009
```

with the first element occupying bits `[7:0]`.

### 6. Expected result derivation
**PASSED.** The learner correctly derived:

```text
accumulator = 45
M_INT = 3
product = 135
rounding bias = 2^(2-1) = 2
rounded = 137
137 >> 2 = 34
```

so the expected board-visible INT8 result is decimal 34 (`0010_0010`).

### 7. BRAM proof requirement
**PASSED.** The learner correctly distinguished an RTL memory declaration from the actual physical resource chosen by Vivado. BRAM use must be confirmed from synthesis/netlist utilization evidence.

### 8. `done_latched` ownership
**PASSED.** The learner correctly explained that the one-cycle core `done` pulse remains part of the accelerator protocol while `done_latched` is board-wrapper observability logic, so human-visible status is added without changing the core's 70 ns transaction latency.

### 9. Single-clock strategy
**PASSED.** The learner correctly explained that synchronizers, debounce counters, pulse generation, control, and compute can all remain in the existing 100 MHz domain. This avoids creating a separate button clock and the additional CDC/clock-routing/constraint complexity that would follow.

### 10. Final physical measurements
**PASSED.** The learner correctly identified the need to repeat resource and timing measurements on the complete board top, including LUT, FF, CARRY, DSP, BRAM, I/O and clock resources, plus WNS/TNS and hold timing. The final implementation must independently prove that the full board-level design still meets the 100 MHz requirement.

## Gate result

**BASYS3 TOP-LEVEL DESIGN UNDERSTANDING GATE: PASSED**

The design has been restated correctly. Step 3 `/analyze basys3_top_level` is now permitted. No RTL may be generated until the prediction/analysis step is completed and its understanding gate is passed.