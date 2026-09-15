# Phase 7 — Convolution Integration Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 6 — verification understanding gate

## Learner responses

### 1. Why the testbench memory must model one-clock read latency

**Status: PASSED**

The learner correctly identified that the testbench is modeling the latency behavior expected from the later BRAM-backed memory system. The important architectural point is that the DUT was designed for a synchronous one-clock-latency memory interface. If the testbench supplied data immediately from the requested address, it would verify a different zero-latency architecture and could hide sequencing errors.

### 2. Why checking only `activation_out = 34` is insufficient

**Status: PARTIAL**

The learner correctly noted that the internal requantization sequence also needs verification, including the product register and the rounding, shifting, and saturation stages.

The full integration requirement is broader: a final correct output can still occur despite wrong memory-request order, extra reads, handshake errors, off-by-one capture timing, or stale data from another transaction. Therefore the nominal integration test must also check the `0 -> 1 -> 2` memory address sequence, read-enable counts, `engine_start`, `engine_done`, `engine_result`, `product_reg`, `capture_activation`, `activation_out`, `busy`, and `done` timing.

### 3. Why E5, E6, and E7 are inspected separately

**Status: PARTIAL**

The learner correctly connected these edges to the FSM-controlled transaction sequence, but the key verification purpose is to prove data association across sequential pipeline boundaries:

```text
E5: engine_result becomes the final signed INT32 convolution result
E6: product_reg captures the product derived from that E5 result
E7: activation_out captures the INT8 q_out derived from that product_reg
```

Observing these edges separately proves the final output was neither captured early nor late and did not come from an older pipeline value.

### 4. Why the second legal transaction should have a different expected output

**Status: PASSED**

The learner correctly identified that changing the inputs should change the expected result. Using a deliberately different result for transaction 2 is stronger than repeating the same vector because it proves the second `done` pulse is associated with fresh transaction data rather than a stale `activation_out` or leftover pipeline state from transaction 1.

## Gate result

**VERIFICATION UNDERSTANDING GATE: NOT YET PASSED**

Points 1 and 4 are passed. The learner must restate points 2 and 3 precisely before Step 7 integration-testbench generation is permitted.
