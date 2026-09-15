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

**Status: PARTIAL — NEEDS PRECISE RESTATEMENT**

The learner said this is needed "for the computation and to keep the output stable." That is directionally reasonable but does not yet show the required cycle-level understanding.

The precise reason is:

```text
edge N:
    engine registers final INT32 result

edge N+1:
    requantizer sees that result and captures the 42-bit fixed-point product into product_reg

between N+1 and N+2:
    rounding, shift, and saturation combinational logic produce the correct q_out from product_reg

edge N+2:
    architectural activation register captures that valid q_out
```

The separate edges are required by the explicit pipeline register inside the requantizer.

### 3. Why 70 ns is still a prediction

**Status: PASSED WITH TERMINOLOGY CORRECTION**

The learner correctly stated that full integration has not yet been built and measured. The correct term is **70 ns latency prediction**, not a 70 ns timing margin. It becomes a measured latency only after an integrated simulation measures accepted `start` to external `done`.

### 4. Why integration verification must inspect more than the final output

**Status: PASSED**

The learner correctly identified that a design can produce the right final INT8 value while still having wrong cycle timing, address sequencing, or handshakes. Therefore integration verification must inspect memory addresses, read enables, `engine_start`, `engine_done`, `capture_activation`, `busy`, `done`, and cycle-to-cycle data association.

## Gate result

**TEACHING UNDERSTANDING GATE: NOT YET PASSED**

The only missing point is the exact two-edge requantizer pipeline sequence. The learner must restate why the final INT32 result is sampled into `product_reg` on one edge and why the activation register can only capture the corresponding `q_out` on the following edge.
