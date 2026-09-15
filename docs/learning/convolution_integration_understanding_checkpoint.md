# Phase 7 — Convolution Integration Teaching Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 1 — `/teach convolution_integration` understanding gate  

## Learner responses

### 1. Why the requantizer cannot use the new convolution result on the same edge

**Status: PASSED**

The learner correctly identified that both producer and consumer are clocked blocks using registered state. With nonblocking sequential logic, the consumer sees the producer's old registered value during the same active edge; the newly registered result becomes visible only after that edge.

### 2. Why product capture and activation capture occur on different edges

**Status: PASSED**

The learner correctly explained that after the final INT32 result is sampled into the requantizer's `product_reg`, the rounding, right-shift, and saturation logic still has to compute the corresponding INT8 `q_out` during the following clock period.

The required sequence is therefore:

```text
edge N:
    engine registers final INT32 result

edge N+1:
    requantizer sees that result and captures the fixed-point product into product_reg

between N+1 and N+2:
    rounding + shift + saturation combinational logic produce valid q_out

edge N+2:
    architectural activation register captures q_out
```

The activation register must therefore wait until the edge after the product-register capture; otherwise it could capture the previous transaction's or previous pipeline stage's value.

### 3. Why 70 ns is still a prediction

**Status: PASSED WITH TERMINOLOGY CORRECTION**

The learner correctly stated that full integration has not yet been built and measured. The correct term is **70 ns latency prediction**, not a 70 ns timing margin. It becomes a measured latency only after an integrated simulation measures accepted `start` to external `done`.

### 4. Why integration verification must inspect more than the final output

**Status: PASSED**

The learner correctly identified that a design can produce the right final INT8 value while still having wrong cycle timing, address sequencing, or handshakes. Therefore integration verification must inspect memory addresses, read enables, `engine_start`, `engine_done`, `capture_activation`, `busy`, `done`, and cycle-to-cycle data association.

## Gate result

**TEACHING UNDERSTANDING GATE: PASSED**

The learner now demonstrates the required cycle-level understanding for Phase-7 convolution integration. Step 1 `/teach convolution_integration` is complete.

The next workflow step is:

```text
Step 2: /design convolution_integration
```

No Phase-7 integration RTL should be generated until the design document, prediction analysis, and subsequent understanding gate are completed.
