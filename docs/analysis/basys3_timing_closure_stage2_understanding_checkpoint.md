# Basys 3 Timing Closure Stage 2 — Prediction Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure_stage2`  
**Workflow stage:** Step 3 prediction gate / Step 4 confirmation  
**Status:** PASSED — second RTL modification is unlocked.

## Assessment

The learner correctly explained all required Stage-2 timing-closure predictions.

### Latency

```text
9 cycles x 10 ns = 90 ns
```

### Initiation interval

```text
11 cycles x 10 ns = 110 ns
```

### Transaction rate

```text
1 / 110 ns
≈ 9.09 Mtransactions/s
```

### MAC throughput

```text
9.09 Mtransactions/s x 9 MAC/transaction
≈ 81.82 MMAC/s
```

### Physical operand bandwidth

```text
9.09 Mtransactions/s x 24 bytes/transaction
≈ 218.18 MB/s
```

Useful bandwidth:

```text
9.09 Mtransactions/s x 18 bytes/transaction
≈ 163.64 MB/s
```

### FF prediction reasoning

The learner correctly explained why physical FF count is a range rather than an exact 218:

```text
product registers add about 64 RTL bits
but synthesis can alter physical FF count through:
- optimization
- register merging/removal
- FSM encoding changes
- constant/sign-bit simplification
```

### Expected unchanged resources

```text
RAMB18E1 = 2 expected
DSP      = 0 expected
IOB      = 12 expected
BUFG     = 1 expected
```

### Old critical path expected to disappear

```text
BRAM
-> multiplier
-> reduction tree
-> partial_sum_pipe
```

### Likely replacement timing paths

```text
BRAM
-> multiplier
-> product_pipe

product_pipe
-> reduction tree
-> partial_sum_pipe

partial_sum_pipe
-> accumulator add
-> accumulator_reg
```

### Timing-proof boundary

The learner correctly explained that closure is more plausible because the new register is inserted directly inside the measured failing path, but implementation still determines:

```text
technology mapping
placement
routing
clock/data arrival
new critical-path migration
```

### Hold timing

The learner correctly explained that the new register boundaries can alter short-path timing and therefore hold must be re-measured.

### Closure criteria

```text
WNS  >= 0 ns
TNS  = 0 ns
WHS  >= 0 ns
THS  = 0 ns
WPWS >= 0 ns
TPWS = 0 ns
```

## Gate result

**BASYS3 TIMING CLOSURE STAGE-2 STEP-3 UNDERSTANDING GATE: PASSED**

This also satisfies Step 4 user confirmation.

The workflow may now proceed to:

```text
Step 5 — RTL modification
rtl/compute/memory_interface_dataflow.v
```
