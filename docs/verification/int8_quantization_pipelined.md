# INT8 Quantization — Pipelined Requantizer Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** TIMING-REFINEMENT FUNCTIONAL VERIFICATION PLAN

## 1. Objective

Verify that `rtl/activation/requantize_relu_pipelined.v` preserves the numerical behavior of the already-verified combinational requantizer while introducing exactly one registered 42-bit product stage.

The verification must prove both:

1. arithmetic correctness, and
2. pipeline sequencing correctness.

A numerically correct result appearing in the wrong cycle is a verification failure.

## 2. Assumptions

- Clock frequency for verification: 100 MHz.
- Clock period: 10 ns.
- Reset is synchronous and active high.
- `acc_in` is driven and made stable before a rising clock edge.
- At that edge, `product_reg` captures the corresponding 42-bit product.
- `q_out` becomes combinationally valid from that registered product during the following cycle.
- Generated INT8 operands remain in `[-127,+127]`.
- Maximum legal positive accumulator for the present 3x3 single-channel contract is `145161`.
- `M_INT` is unsigned 24-bit.
- `FRAC_BITS` is compile-time constant in `0..42`.

## 3. Verification Strategy

The testbench will use a real 10 ns clock and will never check a newly applied input before a rising edge has captured its product.

For one transaction:

```text
Before edge N:
    drive acc_in

At edge N:
    product_reg captures acc_mag * M_INT

After edge N, during N -> N+1:
    check product_reg
    check rounded/shifted behavior
    check q_out
```

For back-to-back operation, a new `acc_in` may be presented before every rising edge. After each edge, `q_out` must correspond to the input that was present immediately before that edge, not the next input already being prepared.

## 4. Required Test Classes

### 4.1 Reset behavior

Assert synchronous reset across a rising edge and verify:

```text
product_reg = 0
q_out       = 0
```

This proves the pipeline starts from a deterministic state.

### 4.2 ReLU / non-positive handling

Verify at minimum:

```text
acc_in = -1 -> product_reg = 0 -> q_out = 0
acc_in =  0 -> product_reg = 0 -> q_out = 0
```

The key point is that non-positive inputs are converted to zero before multiplication, so Stage 2 needs no separate sign flag.

### 4.3 Identity-scale behavior

Use a parameter instance with:

```text
M_INT = 1
FRAC_BITS = 0
```

Check:

```text
1      -> 1
126    -> 126
127    -> 127
128    -> 127
145161 -> 127
```

Each value must be checked only after the product-capture edge.

### 4.4 Positive rounding behavior

Use:

```text
M_INT = 1
FRAC_BITS = 1
```

Expected:

```text
1 -> 1
2 -> 1
3 -> 2
4 -> 2
```

This proves the rounding-bias logic is preserved after the pipeline split.

### 4.5 Non-power-of-two coefficient behavior

Use:

```text
M_INT = 3
FRAC_BITS = 2
```

Expected:

```text
1   -> 1
2   -> 2
3   -> 2
5   -> 4
169 -> 127 naturally
170 -> 127 by saturation after internal value 128
```

The 169/170 pair must again distinguish natural 127 from saturation to 127.

### 4.6 Maximum-width arithmetic

Use:

```text
M_INT = 0xFFFFFF
FRAC_BITS = 42
acc_in = 145161
```

Verify exact Stage-1 product:

```text
145161 * 16777215 = 2435397306615
```

Then verify Stage-2 exact rounded numerator:

```text
2435397306615 + 2^41 = 4634420562167
```

and final result:

```text
q_out = 1
```

This catches width/truncation errors that the final saturated INT8 output alone could hide.

### 4.7 Back-to-back pipeline sequencing

Apply a different legal accumulator before several consecutive rising edges.

Example sequence:

```text
before edge N     : acc = 1
before edge N+1   : acc = 3
before edge N+2   : acc = 5
```

For the `M_INT=3, FRAC_BITS=2` instance, the outputs observed after each corresponding capture edge must be:

```text
after edge N      : 1
after edge N+1    : 2
after edge N+2    : 4
```

This proves that the single pipeline stage does not reorder, duplicate, or drop consecutive samples.

## 5. Internal Checks

The testbench should inspect internal DUT signals hierarchically where useful, especially:

```text
product_reg
rounded_num
q_pre_wide
```

The purpose is not merely to see the correct final `q_out`; it is to prove that the stage boundary preserves the exact 42-bit product and that the Stage-2 arithmetic is correct.

## 6. Pass/Fail Rules

A test passes only when all expected values match exactly using four-state-safe comparisons.

The final testbench must maintain a failure counter and print an unambiguous final result such as:

```text
TB_REQUANTIZE_RELU_PIPELINED_PASS
```

only when the failure count is zero.

Any mismatch in arithmetic value, internal product value, reset behavior, or cycle association is a failure.

## 7. What This Verification Does Not Prove

A passing behavioral simulation proves functional and cycle-level correctness of the RTL model.

It does **not** prove:

```text
100 MHz setup closure
DSP PREG inference
post-route WNS/TNS
hold timing
final LUT/FF/DSP utilization
```

Those must be measured again after functional verification passes.

## 8. Verification Exit Criteria

Functional verification is complete only when:

```text
reset tests pass
non-positive tests pass
identity tests pass
rounding tests pass
non-power-of-two tests pass
saturation-threshold tests pass
maximum-width internal checks pass
back-to-back sequencing tests pass
failure_count = 0
```

Only after that point should the refined timing wrapper be re-synthesized and re-implemented for timing closure measurement.
