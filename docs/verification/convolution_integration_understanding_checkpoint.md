# Phase 7 — Convolution Integration Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 6 — verification understanding gate

## Learner responses

### 1. Why the testbench memory must model one-clock read latency

**Status: PASSED**

The learner correctly identified that the testbench is modeling the latency behavior expected from the later BRAM-backed memory system. The DUT was designed for a synchronous one-clock-latency memory interface. A zero-latency memory model would verify a different architecture and could hide sequencing errors.

### 2. Why checking only `activation_out = 34` is insufficient

**Status: PASSED**

The learner correctly restated that a final correct output can still appear despite wrong address sequencing, extra reads, handshake errors, off-by-one capture timing, or stale pipeline data. Therefore integration verification must also inspect memory addresses/read enables and the relevant control/timing signals rather than accepting the final INT8 value alone.

### 3. Why E5, E6, and E7 are inspected separately

**Status: PASSED**

The learner correctly restated that these edges prove data association across sequential pipeline stages:

```text
E5: final engine_result is registered
E6: product_reg captures the product derived from that engine_result
E7: activation_out captures the INT8 result derived from that product
```

Observing these edges separately proves that the final output is neither captured early nor late and is associated with the correct transaction.

### 4. Why the second legal transaction should have a different expected output

**Status: PASSED**

The learner correctly identified that using a deliberately different second result proves the second `done` pulse is associated with fresh transaction data rather than a stale `activation_out` or leftover pipeline state from transaction 1.

## Gate result

**VERIFICATION UNDERSTANDING GATE: PASSED**

All required Step-6 verification concepts have now been restated correctly.

The workflow may proceed to:

```text
Step 7: integration testbench generation -> tb/integration/tb_convolution_integration.v
```

No integrated XSim result is claimed at this point. Simulation and measurement remain Step 8.