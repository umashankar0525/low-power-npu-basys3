# INT8 Quantization — Testbench Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 7 — TESTBENCH UNDERSTANDING CHECK

## Assumptions

- `M_INT` and `FRAC_BITS` are Verilog module parameters and are fixed at elaboration time for each DUT instance.
- The maximum legal positive accumulator under the Phase 6 generated-data contract is `145161`.
- The maximum coefficient is `16777215` (`24'hFFFFFF`).
- The maximum fractional shift under the selected architecture is `42`.

## Learner checkpoint

### 1. Why four parameterized DUT instances are used

**Status: PASSED**

The learner correctly stated that `M_INT` and `FRAC_BITS` are compile-time/elaboration-time parameters, so they cannot be changed dynamically on one already-instantiated DUT during simulation. Separate instances are therefore required to exercise the identity, half-scale, three-quarter-scale, and maximum-width configurations in the same testbench.

### 2. Why the maximum-width test checks internal arithmetic as well as `q_out`

**Status: NEEDS PRECISION RESTATEMENT**

The learner correctly identified the important internal values:

```text
acc_mag     = 145161
product     = 2435397306615
rounded_num = 4634420562167
q_pre       = 1
q_out       = 1
```

The remaining key point is why checking only the final `q_out = 1` is insufficient.

The final INT8 value is heavily compressed by the large right shift and saturation logic. A width or truncation error in the 42-bit multiplication path or 43-bit rounding path could potentially be hidden by later operations and still produce the same small final output for some cases. Checking the internal `product`, `rounded_num`, and `q_pre` separately proves that the full-width arithmetic itself is correct and localizes any failure to the exact transformation where it occurs.

## Current hard gate

Before Step 8 simulation is run, the learner must restate in their own words why checking only `q_out = 1` is weaker than also checking the exact 42-bit product and 43-bit rounded intermediate.