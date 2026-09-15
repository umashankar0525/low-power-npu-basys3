# INT8 Quantization — Pipelined Requantizer Post-Edge Delay Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** TIMING-REFINEMENT FUNCTIONAL-VERIFICATION UNDERSTANDING CHECK

## Assumptions

- `requantize_relu_pipelined` contains a clocked 42-bit `product_reg` stage.
- `product_reg` is updated on the rising edge using nonblocking assignment semantics.
- Stage-2 rounding, shifting, saturation, and `q_out` are combinational from the registered product.
- The testbench uses `#1` only after the required rising edge.

## Current learner response

The learner answered that `#1` is valid "because this is just for testing."

**Status: NOT YET PASSED**

That statement is too general and does not explain the timing mechanism.

## Required concept

The rising edge performs the actual pipeline capture:

```text
At the rising edge:
    product_reg captures the new 42-bit product
```

After that edge, the nonblocking update of `product_reg` and the downstream combinational Stage-2 logic require simulation delta/settling time before the testbench samples them. The `#1` delay provides a short post-edge settle interval:

```text
rising edge -> product_reg update -> Stage-2 combinational propagation -> #1 check
```

Therefore `#1` is valid only as a post-edge observation delay.

If `acc_in` is changed and the testbench waits only `#1` without a rising edge, the pipeline register does not capture the new product. `product_reg` keeps the previous value, and `q_out` still corresponds to the previous registered sample.

## Gate result

**POST-EDGE DELAY UNDERSTANDING GATE: NEEDS RESTATEMENT**

The learner must explain that the clock edge causes the state update, while `#1` only allows the registered and downstream combinational signals to settle before checking them.
