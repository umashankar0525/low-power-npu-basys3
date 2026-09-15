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

## Learner checkpoint

### 1. Why the rising edge is required

**Status: PASSED**

The learner correctly restated that the rising clock edge is what actually captures the new multiplication result into `product_reg`. Without that active edge, waiting `#1` does not transfer the new input sample through the pipeline register; `product_reg` continues to hold the previous product.

### 2. Why `#1` is used after the edge

**Status: PASSED**

The learner previously established that the post-edge delay gives the nonblocking register update and the downstream combinational rounding, shifting, saturation, and output logic time to settle before the testbench samples them.

The complete sequence is therefore:

```text
before rising edge:
    acc_in is stable

at rising edge:
    product_reg captures the corresponding product

after rising edge:
    nonblocking update takes effect
    Stage-2 combinational logic responds
    #1 gives the testbench a safe settle interval before checking
```

## Gate result

**POST-EDGE SAMPLING UNDERSTANDING GATE: PASSED**

The refined pipelined requantizer has completed its behavioral-verification understanding requirements. The project may now proceed to refined synthesis/resource measurement and then post-route timing measurement.
