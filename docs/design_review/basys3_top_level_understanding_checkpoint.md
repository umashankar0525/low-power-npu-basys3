# Phase 8 — Basys 3 Top-Level Design Review Understanding Checkpoint

**Role:** Design Reviewer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 10 — design review understanding gate  
**Status:** PASSED — Step 11 `/test basys3_top_level` is unlocked.

## Assessment

### 1. Behavioral approval versus physical sign-off
**PASSED.**

The learner correctly distinguished RTL/XSim correctness from physical FPGA proof. Behavioral simulation does not prove BRAM mapping, pin assignments, I/O standards, placement/routing, or timing closure.

### 2. Evidence for 70 ns latency and result 34
**PASSED.**

The learner correctly related the 100 MHz clock to a 10 ns period and the seven-cycle transaction to 70 ns, and correctly derived:

```text
45 x 3 = 135
135 + 2 = 137
137 >> 2 = 34
```

The Step-8 timestamps provide direct quantitative evidence:

```text
accepted_start_time = 1065 ns
raw_done_time       = 1135 ns
latency             = 70 ns
```

### 3. Why ram_style does not prove BRAM
**PASSED.**

The learner correctly explained that `ram_style="block"` is an inference directive/request and that actual BRAM use must be confirmed from Vivado synthesis/utilization evidence.

### 4. Why the missing Basys-3 XDC blocks board readiness
**PASSED.**

The learner correctly explained that the XDC establishes logical-port to package-pin mapping, I/O standards, and the board clock constraint. Without it, the design is not board-ready.

### 5. Remaining Vivado reports
**PASSED.**

The learner correctly identified the need for utilization, timing, I/O/clock, and implementation evidence. Physical sign-off requires resource mapping and post-route timing data such as WNS/TNS/WHS/THS.

### 6. Why the original physical-reset-abort test was invalid
**PASSED.**

The learner correctly identified the actual cause: the physical reset path is much slower than the accelerator transaction.

```text
core transaction latency = 70 ns
physical reset path       = synchronizer + debounce + synchronous sampling
hardware debounce         = approximately 10 ms
```

The learner correctly derived:

```text
10 ms / 70 ns ≈ 142,857
```

and explained that the physical reset button can prove eventual cleaned reset behavior, but cannot reliably prove interruption of a specific 70 ns transaction before completion.

The corrected verification split is understood:

```text
physical reset button
-> synchronization/debounce/eventual clear

clean internal reset_level while core_busy=1
-> synchronous abort
-> no stale done
```

### 7. Proven versus open Phase-8 work
**PASSED.**

The learner correctly separated behaviorally established items from still-open physical tasks: dedicated XDC, final top synthesis/implementation, BRAM/resource mapping, routed timing, bitstream, and hardware-board validation.

## Gate result

**BASYS3 TOP-LEVEL DESIGN REVIEW UNDERSTANDING GATE: PASSED**

Step 10 design review is behaviorally complete.

The next workflow action is:

```text
Step 11 — /test basys3_top_level
```

Important boundary:

```text
behavioral design review = approved
physical FPGA sign-off   = still pending
```

The knowledge test may proceed, but passing it must not be interpreted as physical closure of Phase 8.
