# Phase 7 — Convolution Integration Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 2 — `/design convolution_integration` understanding gate

## Learner responses

### 1. Why activation and weight memories stay outside the integration core

**Status: PASSED**

The learner correctly restated that the core should remain independent of the physical memory implementation. During simulation, the exposed memory interface can connect to a cycle-accurate one-clock-latency memory model; later, the same interface can connect to inferred or explicit FPGA BRAM. This preserves verification flexibility and avoids binding the convolution core to one storage implementation.

### 2. Why an architectural `activation_out` register is still required

**Status: PASSED**

The learner correctly distinguished the two registers:

- `product_reg` is an internal 42-bit pipeline register inside the requantizer.
- `activation_out` is the architectural transaction-result register visible to the outside of the integration core.

The architectural contract is therefore:

```text
done = 1  =>  activation_out already contains the completed transaction result
```

### 3. Why the existing `CAPTURE_ACTIVATION` state avoids another FSM state

**Status: PASSED**

The learner correctly restated that `CAPTURE_ACTIVATION` already provides the E6->E7 clock interval required for stage-2 requantization:

```text
E6:
    product_reg captures the product from the final INT32 result
    controller enters CAPTURE_ACTIVATION

E6 -> E7:
    rounding + right shift + saturation compute q_out

E7:
    activation_out captures q_out
    controller enters DONE
```

Because this interval already exists in the current controller schedule, a separate `WAIT_REQUANT` state would be unnecessary for the present one-register requantizer pipeline.

### 4. What is registered at E5, E6, and E7

**Status: PASSED**

The learner correctly identified:

```text
E5 -> final signed INT32 convolution result is registered by the engine
      engine_done is also registered high for one cycle

E6 -> 42-bit fixed-point product is registered in requantizer product_reg

E7 -> architectural activation_out register captures the valid INT8 q_out
      controller enters DONE, making external done active
```

## Gate result

**DESIGN UNDERSTANDING GATE: PASSED**

Step 2 `/design convolution_integration` is complete.

The next workflow step is:

```text
Step 3: /analyze convolution_integration
```

No Phase-7 integration RTL should be generated until the prediction analysis is completed and its understanding gate is passed.
