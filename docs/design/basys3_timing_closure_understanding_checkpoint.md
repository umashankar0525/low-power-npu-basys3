# Basys 3 Timing Closure — Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 2 — design understanding gate  
**Status:** PASSED — Step 3 `/analyze basys3_timing_closure` is unlocked.

## Assessment

The learner correctly explained all required design concepts.

### 1. Pipeline boundary
**PASSED.**

The learner correctly identified the selected split:

```text
BRAM
-> four products
-> reduction tree
-> sign extension
-> partial_sum_pipe
-> 32-bit accumulator addition
-> accumulator register
```

and correctly explained that the register removes the accumulator addition from the original BRAM-to-accumulator combinational path.

### 2. Two timing stages
**PASSED.**

Correctly identified:

```text
Stage A:
BRAM -> multiply/reduction -> partial_sum_pipe

Stage B:
partial_sum_pipe -> accumulator add -> accumulator register
```

### 3. Need for ST_PIPE0
**PASSED.**

The learner correctly explained that the extra state represents pipeline timing and prevents control/data misalignment or premature accumulation.

### 4. E0 through E5 schedule
**PASSED.**

The learner correctly described:

```text
E0 request word 0
E1 receive word 0 / request word 1
E2 capture S0 / receive word 1 / request word 2
E3 accumulate S0 / capture S1 / receive word 2
E4 accumulate S1 / capture S2
E5 consume S2 / produce result / done
```

### 5. Memory request count
**PASSED.**

Correctly stated that the amount of data is unchanged, so the design still needs only three paired operand-word requests.

### 6. FSM-based validity
**PASSED.**

Correctly explained that the fixed deterministic order:

```text
word0 -> S0
word1 -> S1
word2 -> S2
```

allows FSM state to encode the valid-word identity without an additional tag pipeline.

### 7. Numerical preservation
**PASSED.**

Correct derivation:

```text
S0 = 10
S1 = 26
S2 = 9

10 + 26 + 9 = 45

45 x 3 = 135
135 + 2 = 137
137 >> 2 = 34 = 0x22
```

### 8. Latency consequence
**PASSED.**

Correctly identified the expected change:

```text
old = 7 cycles = 70 ns
new = 8 cycles = 80 ns
```

subject to Step-3 cycle-accurate prediction and later simulation measurement.

### 9. Resource consequence
**PASSED.**

Correctly predicted the major new state as approximately:

```text
+32 FF
```

while expecting BRAM, IOB, BUFG, and major arithmetic structure to remain broadly unchanged, with exact LUT/CARRY/DSP/FF values left to synthesis.

### 10. Timing-proof boundary
**PASSED.**

The learner correctly stated that improved architecture only predicts better timing. Actual closure still requires:

```text
synthesis
-> implementation
-> post-route STA
```

with the target conditions:

```text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
```

## Gate result

**BASYS3 TIMING CLOSURE STEP-2 DESIGN UNDERSTANDING GATE: PASSED**

The next workflow step is:

```text
Step 3 — /analyze basys3_timing_closure
```

RTL modification remains locked until Step 3 predictions are completed and understood.
