# INT8 Quantization — Pipelined Requantizer Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** TIMING-REFINEMENT FUNCTIONAL-VERIFICATION UNDERSTANDING CHECK

## Assumptions

- `requantize_relu_pipelined` contains one 42-bit registered product stage.
- The input accumulator is stable before a rising edge.
- At that rising edge, the raw 42-bit product is captured into `product_reg`.
- Rounding, shifting, and saturation are combinational from `product_reg`.
- Therefore `q_out` becomes valid during the cycle immediately after the product-capture edge.

## Learner checkpoint

### 1. Why the old `#1` combinational testbench is no longer valid

**Status: PASSED**

The learner correctly explained that the old testbench assumes the entire requantization path is combinational, while the refined design now contains a clocked pipeline boundary. A simple input change followed by `#1` no longer represents the DUT timing contract because the corresponding product is not available in `product_reg` until a rising clock edge captures it.

### 2. Exact edge-to-cycle behavior of the pipelined module

**Status: PASSED**

The learner correctly restated the required sequence:

```text
Before edge N:
    acc_in is stable

At edge N:
    product_reg captures acc_mag * M_INT

During cycle N -> N+1:
    rounding, shifting, saturation, and q_out are computed from product_reg
```

This is the timing contract the clocked verification testbench must follow.

## Gate result

**PIPELINED REQUANTIZER TIMING UNDERSTANDING GATE: PASSED**

The project may now proceed to the detailed functional verification plan for the pipelined requantizer. Testbench generation remains gated on understanding that verification plan.