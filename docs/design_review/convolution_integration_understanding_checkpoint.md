# Phase 7 — Convolution Integration Design-Review Understanding Checkpoint

**Role:** Design Reviewer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 10 — design-review understanding gate

## Learner responses

### 1. Why behavioral approval can coexist with deferred physical FPGA sign-off

**Status: PASSED**

The learner correctly stated that the behavioral integration evidence is strong enough to approve the transaction logic because the simulation verified more than just the final numerical output. The remaining unverified properties are physical FPGA properties such as integrated LUT/FF/CARRY/DSP usage and routed setup/hold timing.

### 2. Why the E5 -> E6 -> E7 sequence is the most important integration timing relationship

**Status: PARTIAL**

The learner connected this region to the combinational logic between the pipeline stages, but the critical review point is data association across sequential boundaries.

The exact reason is:

```text
E5: engine_result registers the final INT32 convolution result
E6: product_reg captures the product derived from that E5 result
E7: activation_out captures q_out derived from that E6 product_reg
```

Checking these three edges proves that the architectural output corresponds to the same transaction and was not captured one cycle early, one cycle late, or from stale pipeline data.

### 3. Why measured 70 ns behavioral latency does not prove 100 MHz post-route timing closure

**Status: PASSED**

The learner correctly stated that 100 MHz physical timing closure also requires setup/hold timing evidence. Behavioral simulation establishes cycle ordering and timestamps under an ideal clock model, but does not include placed/routed propagation delays.

### 4. Why one DSP48E1 is still only a prediction

**Status: PASSED**

The learner correctly distinguished the five logical multipliers from their expected implementation:

```text
4 INT8 x INT8 convolution multipliers -> expected LUT/carry implementation
1 18 x 24 requantization multiplier   -> expected DSP48E1
```

The expected physical DSP count is therefore one, but this remains a prediction until integrated synthesis confirms technology mapping.

### 5. Why the 80 ns busy duration is described more cautiously

**Status: PASSED**

The learner correctly stated that the 80 ns busy duration is supported by the verified FSM sequence but was not independently timestamped in the current testbench. In contrast, the 70 ns start-to-done latency and 90 ns accepted-start spacing were explicitly timestamped/asserted.

## Gate result

**DESIGN-REVIEW UNDERSTANDING GATE: NOT YET PASSED**

Points 1, 3, 4, and 5 are passed. Point 2 must be restated in terms of correct transaction data association across the E5/E6/E7 registered pipeline boundaries before Step 11 `/test convolution_integration` is permitted.
