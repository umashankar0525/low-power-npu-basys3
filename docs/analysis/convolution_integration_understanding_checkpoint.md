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

**Status: PARTIAL**

The learner correctly noted that the 42-bit requantizer product register is expected to map into the DSP48E1 `PREG` rather than into 42 Slice flip-flops.

The complete reason is broader: the 127-bit number is an RTL-visible logical storage count, while physical implementation is decided by synthesis. Registers may be absorbed into dedicated FPGA resources such as DSP registers, constant bits may be optimized away, and other redundant logic may be removed or encoded differently. Therefore logical register bits and final Slice-FF count are not identical quantities.

### 6. Why 5 logical multipliers can still correspond to only 1 expected DSP48E1

**Status: PARTIAL**

The learner correctly identified that the requantizer multiplier uses a DSP48E1 in the representative Phase-6 implementation.

The missing distinction is that the other four logical multipliers are the small signed INT8 x INT8 multipliers inside the convolution engine. Existing project synthesis evidence indicates those four map to LUT/carry fabric under the current RTL/tool configuration. Thus:

```text
4 logical INT8 multipliers -> expected LUT/carry implementation
1 logical 18x24 requantization multiplier -> expected DSP48E1

5 logical multipliers total
1 expected DSP48E1 total
```

This remains a prediction until integrated synthesis confirms the mapping.

## Gate result

**PREDICTION-ANALYSIS UNDERSTANDING GATE: NOT YET PASSED**

Points 1-4 are passed. The learner must restate points 5 and 6 precisely before Phase-7 RTL generation is permitted.
