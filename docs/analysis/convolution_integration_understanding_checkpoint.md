# Phase 7 — Convolution Integration Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 4 — prediction-analysis understanding gate

## Learner responses

### 1. Why latency is 70 ns but initiation interval is 90 ns

**Status: PASSED**

The learner correctly distinguished result latency from the earliest legal next accepted transaction. The completed result is available at 70 ns, but the controller remains busy through the `DONE` state and does not permit the next accepted start until the 90 ns initiation boundary.

### 2. Why sustained throughput uses 100 MHz / 9 instead of 100 MHz / 7

**Status: PASSED**

The learner correctly identified that sustained throughput must use the 9-cycle initiation interval, not the 7-cycle single-transaction latency.

### 3. Why memory bandwidth can be 800 MB/s peak but 266.67 MB/s sustained

**Status: PASSED**

The learner correctly identified that the sustained value is averaged over the full 90 ns initiation interval. The 800 MB/s value is the combined instantaneous port capability when two independent 32-bit memory ports each transfer one word per 100 MHz cycle.

### 4. Why useful lane utilization is 75%

**Status: PASSED**

The learner correctly derived:

```text
3 packed words x 4 lanes = 12 physical multiplier slots
9 useful convolution terms
9 / 12 = 75%
```

The three unused slots are the zero-padded lanes in the final packed word.

### 5. Why 127 logical registered bits does not mean 127 Slice FFs

**Status: PASSED**

The learner correctly restated that 127 logical register bits are an RTL-visible storage count, not a physical Slice-FF count. Synthesis may place registers in dedicated FPGA resources, optimize constant bits away, or remove redundant state. In particular, the 42-bit requantizer `product_reg` is expected to map into the DSP48E1 `PREG` rather than consume 42 Slice FFs.

### 6. Why 5 logical multipliers can still correspond to only 1 expected DSP48E1

**Status: PARTIAL — ONE DISTINCTION STILL MISSING**

The learner correctly stated that the single 18x24 requantization multiplier is expected to map to one DSP48E1 and that there are five logical multipliers total.

The missing statement is what happens to the other four logical multipliers:

```text
4 signed INT8 x INT8 convolution multipliers
    -> expected LUT/carry implementation

1 unsigned 18x24 requantization multiplier
    -> expected DSP48E1 implementation

5 logical multipliers total
1 expected DSP48E1 total
```

This mapping remains a prediction until integrated synthesis confirms it.

## Gate result

**PREDICTION-ANALYSIS UNDERSTANDING GATE: NOT YET PASSED**

Points 1-5 are passed. Only point 6 remains: the learner must explicitly state that the other four INT8 convolution multipliers are expected to map into LUT/carry fabric, leaving only the requantization multiplier in a DSP48E1.
