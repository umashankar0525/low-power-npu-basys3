# Basys 3 Timing Closure Stage 2 — Step 8 Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure_stage2`  
**Workflow stage:** Step 8 — simulation understanding gate  
**Status:** PASSED — fresh synthesis and implementation measurements are unlocked.

## Assessment

The learner correctly distinguished behavioral verification from physical timing verification.

### What XSim proves

The completed Stage-2 XSim run proves cycle-by-cycle RTL correctness:

```text
word-0 products = 1,2,3,4
word-1 products = 5,6,7,8
word-2 products = 9,0,0,0

partial sums:
10 -> 26 -> 9

accumulator:
0 -> 10 -> 36 -> 45

BRAM request count = 3
request order = 0 -> 1 -> 2

latency = 9 cycles = 90 ns
reset/recovery = correct
completion behavior = correct
```

### What XSim does not prove

Behavioral simulation does not model final placed-and-routed FPGA path delays.

Therefore it does not prove that:

```text
BRAM
-> multiplier
-> product_pipe
```

meets the 10 ns setup requirement.

Only fresh synthesis, place-and-route, and post-route static timing analysis can determine:

```text
WNS
TNS
WHS
THS
WPWS
TPWS
new critical path
logic delay
route delay
failing endpoints
```

## Gate result

**BASYS3 TIMING CLOSURE STAGE-2 STEP-8 UNDERSTANDING GATE: PASSED**

Next measurement flow:

```text
fresh synthesis
-> fresh utilization
-> fresh implementation
-> fresh post-route STA
```

Physical success criteria remain:

```text
WNS  >= 0 ns
TNS  = 0 ns
WHS  >= 0 ns
THS  = 0 ns
WPWS >= 0 ns
TPWS = 0 ns
```
