# INT8 Quantization — Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** VERIFY / UNDERSTANDING CHECK

## Assumptions

- The RTL under verification is `rtl/activation/requantize_relu.v`.
- Python provides an independent software-side reference model.
- Separate directed tests are used to isolate ReLU/saturation, rounding, and maximum-width arithmetic behavior.

## Learner checkpoint

### 1. Why separate tests are required

**Status: PASSED**

The learner correctly stated that one ordinary positive test cannot prove every arithmetic rule. Separate tests are required because ReLU/sign behavior, saturation, rounding boundaries, and maximum-width arithmetic exercise different failure modes.

### 2. Why the maximum-width case is useful even when the final result is only 1

**Status: PASSED**

The learner correctly identified that this case exercises the full arithmetic path at its derived limits: maximum 18-bit positive accumulator magnitude, maximum 24-bit coefficient, 42-bit raw multiplication result, 43-bit rounding intermediate, and maximum allowed fractional shift. A small final output does not make the internal-width test weak; it can reveal truncation or width errors that a small-input case would not expose.

### 3. Why the Python reference must be independent

**Status: NEEDS PRECISION RESTATEMENT**

The learner recognized that Python is used to verify quantization behavior such as ties-away-from-zero rounding and BRAM packing. The remaining key idea is independence.

If the Verilog testbench simply copies the same arithmetic structure or mistake as the RTL, both implementations can agree while both are wrong. The Python model is stronger because it independently implements the numerical specification and generates expected values from that specification rather than from the RTL implementation.

Independent agreement therefore gives stronger evidence that the RTL matches the intended mathematical contract instead of merely matching a duplicate implementation of the same bug.

## Current hard gate

Before moving to testbench generation, the learner must restate in their own words why an independently implemented Python expected-value model is stronger than copying the RTL equation directly into the Verilog testbench.
