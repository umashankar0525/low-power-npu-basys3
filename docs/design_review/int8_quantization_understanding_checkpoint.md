# INT8 Quantization — Design Review Understanding Checkpoint

**Role:** Design Reviewer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 10 — REVIEW UNDERSTANDING CHECK

## Assumptions

- Hardware-side RTL, behavioral verification, synthesis mapping, and 100 MHz routed timing have passed for the representative configuration.
- The overall module review remains blocked by the missing Python-side verification artifact and execution evidence.

## Learner checkpoint

### 1. Why the hardware can pass while the overall module review still cannot pass

**Status: PASSED**

The learner correctly explained that the software/Python side has not yet completed its separate verification, so the full Phase-6 module cannot be approved even though the hardware side is functionally and physically successful.

### 2. Which Python-side behaviors still require independent verification

**Status: PARTIAL — NEEDS COMPLETE RESTATEMENT**

The learner correctly named:

```text
maximum 3x3 integer convolution
requantization / reference behavior
requantization parameter generation
```

The remaining required behaviors from the verification plan are:

```text
symmetric scale derivation
all-zero tensor scale handling
round-to-nearest ties away from zero
input clipping to [-127,+127]
BRAM packing / byte order / two's-complement storage
representative requantize_relu() reference outputs
```

The complete Python verification set should therefore cover both quantization/data-generation behavior and the integer reference arithmetic.

## Gate result

**DESIGN-REVIEW UNDERSTANDING GATE: NOT YET PASSED**

Before corrective Python verification begins, the learner must restate the complete software-side verification scope in their own words.
