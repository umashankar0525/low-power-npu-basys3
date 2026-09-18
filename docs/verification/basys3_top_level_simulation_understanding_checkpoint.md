# Phase 8 — Basys 3 Top-Level Simulation Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 8 — simulation + measurement understanding gate  
**Status:** PASSED — Step 9 measured-vs-predicted analysis is unlocked.

## Passed concepts

### 1. Measured accelerator latency
**PASSED.**

The learner correctly converted:

```text
accepted_start_time = 0x429 = 1065 ns
raw_done_time       = 0x46F = 1135 ns
```

and derived:

```text
1135 ns - 1065 ns = 70 ns
```

which matches the predicted 7-cycle latency at 100 MHz.

### 2. Meaning of the memory checks
**PASSED.**

The learner correctly restated that:

```text
request_count = 3
```

proves that three paired operand-read cycles occurred, while the zero-error assertions additionally prove that:

```text
logical request order = 0 -> 1 -> 2
```

and that each activation/weight return matched the **previous clock's request**.

Therefore the completed simulation proves more than the existence of three reads. It proves both:

```text
correct memory sequencing
+
one-clock synchronous memory-return behavior
```

for the directed transactions.

### 3. Behavioral versus physical proof
**PASSED.**

The learner correctly distinguished behavioral simulation from physical implementation evidence.

```text
BRAM inference / mapping
-> synthesis utilization / primitive report

100 MHz physical timing closure
-> implementation + post-route static timing analysis
-> WNS/TNS/WHS/THS
```

Behavioral XSim proves protocol and functional timing relationships but does not prove FPGA resource mapping or routed timing closure.

## Gate result

**BASYS3 TOP-LEVEL SIMULATION UNDERSTANDING GATE: PASSED**

Step 8 behavioral simulation + measurement and its understanding checkpoint are complete.

The workflow may now proceed to:

```text
Step 9 — update docs/analysis/basys3_top_level.md
         with measured-vs-predicted behavioral results
```

Physical resource and timing measurements remain pending until board-top synthesis and implementation are performed.
