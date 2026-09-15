# Phase 7 — Convolution Integration Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 2 — `/design convolution_integration` understanding gate

## Learner responses

### 1. Why activation and weight memories stay outside the integration core

**Status: PARTIAL**

The learner said the memories are stored in BRAM and that the wrapper only simulates memory. The important architectural point is broader: the integration core exposes the memory interface so verification can use a cycle-accurate one-clock-latency memory model, while a later board/platform wrapper can connect the same interface to inferred or explicit BRAM. This keeps physical storage implementation separate from the convolution core and preserves verification flexibility.

### 2. Why an architectural `activation_out` register is still required

**Status: NOT YET PASSED**

The learner said it is needed because the value is captured and requantized before `product_reg`. This is not the correct reason.

`product_reg` is an **internal requantizer pipeline register**. It stores the 42-bit fixed-point product and changes as the internal pipeline runs. The architectural `activation_out` register is required so that the external transaction result changes only when `capture_activation` is asserted. This gives the system the clean contract:

```text
done = 1  =>  activation_out already contains the completed transaction result
```

### 3. Why the existing `CAPTURE_ACTIVATION` state avoids another FSM state

**Status: PARTIAL**

The learner correctly associated `done = 1` with valid output, but the exact reason is the existing cycle slot:

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

Because `CAPTURE_ACTIVATION` already provides the full E6->E7 interval needed for the second requantizer stage, a separate `WAIT_REQUANT` state is unnecessary for the current pipeline depth.

### 4. What is registered at E5, E6, and E7

**Status: PASSED WITH ONE PRECISION NOTE**

The learner correctly identified:

```text
E5 -> final signed INT32 convolution result is registered by the engine
E6 -> 42-bit fixed-point product is registered in requantizer product_reg
E7 -> architectural activation_out register captures the valid INT8 q_out
```

At E5 the engine also registers its one-cycle `engine_done` pulse; at E7 the controller enters `DONE`, causing external `done` to be asserted for the following state interval.

## Gate result

**DESIGN UNDERSTANDING GATE: NOT YET PASSED**

The learner must restate three design decisions precisely:

1. Why the memory interface is kept outside the integration core rather than permanently binding the core to one BRAM implementation.
2. Why `activation_out` is needed even though `product_reg` already exists.
3. Why the E6->E7 `CAPTURE_ACTIVATION` interval means no additional FSM state is currently required.
