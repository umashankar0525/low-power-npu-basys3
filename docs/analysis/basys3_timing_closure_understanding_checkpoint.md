# Basys 3 Timing Closure — Prediction Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 3 — prediction understanding gate / Step 4 confirmation  
**Status:** PASSED — RTL modification is unlocked.

## Assessment

The learner correctly explained all required Step-3 predictions.

### Latency
```text
8 cycles x 10 ns = 80 ns
```

### Initiation interval
```text
10 cycles x 10 ns = 100 ns
```

### Machine transaction rate
```text
1 / 100 ns
= 10 Mtransactions/s
```

### MAC throughput
```text
10 Mtransactions/s x 9 MAC/transaction
= 90 MMAC/s
```

### Sustained operand bandwidth
```text
physical:
24 bytes/transaction x 10 Mtransaction/s
= 240 MB/s

useful:
18 bytes/transaction x 10 Mtransaction/s
= 180 MB/s
```

### FF prediction reasoning

The learner correctly explained why the expected FF increase is a range rather than exactly +32:

```text
32-bit RTL pipeline register
-> upper sign-extension bits may be optimized

FSM implementation
-> physical FF count can vary with encoding
```

### Resources expected to remain stable

```text
RAMB18E1 = 2 expected
DSP      = 0 expected
IOB      = 12 expected
BUFG     = 1 expected
```

### Critical-path migration

Old path expected to disappear:

```text
BRAM
-> multiply/reduce
-> accumulator add
-> accumulator register
```

Expected replacement candidates:

```text
BRAM
-> multiply/reduce
-> partial_sum_pipe

partial_sum_pipe
-> INT32 add
-> accumulator register
```

### Timing prediction boundary

The learner correctly explained that exact WNS cannot be predicted because it depends on:

```text
technology mapping
placement
routing
clock skew
uncertainty
new critical-path migration
```

### Hold re-verification

The learner correctly explained that adding a register changes data-path and clock-path relationships, so hold timing must be measured again.

### Closure criteria

```text
WNS  >= 0
TNS  = 0
WHS  >= 0
THS  = 0
WPWS >= 0
TPWS = 0
```

## Gate result

**BASYS3 TIMING CLOSURE STEP-3 UNDERSTANDING GATE: PASSED**

This also satisfies the required Step-4 user understanding confirmation.

The workflow may now proceed to:

```text
Step 5 — RTL modification
rtl/compute/memory_interface_dataflow.v
```

No other RTL module is currently approved for modification unless subsequent evidence requires it.
