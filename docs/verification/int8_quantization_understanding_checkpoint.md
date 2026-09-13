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

**Status: PASSED**

The learner correctly stated that if the Verilog testbench copied the RTL logic, both could contain the same bug and still agree, producing a false PASS.

The Python model is therefore used as an independent expected-value implementation of the mathematical specification. It independently calculates quantization, integer convolution, requantization, rounding, clipping, and BRAM packing behavior rather than copying values or logic from the RTL.

This makes agreement between Python and RTL stronger evidence that the hardware matches the intended numerical contract rather than merely matching a duplicated implementation error.

## Verification understanding gate

**STATUS: PASSED**

The learner has demonstrated understanding of:

1. why separate directed tests are needed for different arithmetic properties;
2. why the maximum-width internal test is important even when its final output is small; and
3. why independent expected-value generation prevents a duplicated RTL bug from causing a false PASS.

The module is ready for the next mandatory workflow step:

```text
Step 7: Testbench generation
```

No simulation result is claimed yet. The testbench must be generated from the documented verification plan before XSim is run.