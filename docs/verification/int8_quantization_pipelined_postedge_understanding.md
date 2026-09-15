# INT8 Quantization — Pipelined Post-Edge Sampling Understanding

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** POST-SIMULATION UNDERSTANDING CHECK

## Assumptions

- `requantize_relu_pipelined` uses a clocked `product_reg` updated by a nonblocking assignment.
- The testbench applies `acc_in` before a rising edge.
- The rising edge is the architectural event that captures the new product into `product_reg`.
- The `#1` delay is only a simulation settle delay after that edge.

## Learner response

The learner correctly identified that the downstream combinational logic must be allowed to settle before checking, especially because the register update uses nonblocking assignment semantics.

However, the response did not yet explicitly state that the **rising clock edge is required to capture the new product**. Without that active edge, changing `acc_in` and waiting `#1` leaves `product_reg` holding the previous sample, so the downstream output still corresponds to the previous registered product.

## Current status

```text
Why a post-edge settle delay is needed : PASSED
Why the rising edge itself is required : NEEDS RESTATEMENT
```

## Gate

**POST-EDGE SAMPLING UNDERSTANDING GATE: NOT YET PASSED**

Before proceeding to refined synthesis/resource measurement, the learner must restate both points:

1. the rising edge captures the new product into `product_reg`; and
2. `#1` is only used afterward to let the nonblocking register update and downstream combinational logic settle before checking.
