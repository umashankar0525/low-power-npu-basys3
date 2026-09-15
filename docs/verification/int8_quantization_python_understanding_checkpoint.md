# INT8 Quantization — Python Verification Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 10 CORRECTIVE VERIFICATION — UNDERSTANDING CHECK

## Learner checkpoint

The learner correctly distinguished the purpose of three representative Python verification checks:

```text
145161
```

verifies the maximum legal 3x3 integer convolution result under the present generated-data contract;

```text
M_INT = 13,421,773
FRAC_BITS = 27
```

verifies the requantization-parameter generation for the representative real multiplier `M = 0.1` with a 24-bit unsigned coefficient;

and the exact packed words

```text
FE02FF01
FC04FD03
00000005
```

verify BRAM packing order, byte placement, final-word zero padding, and normal 8-bit two's-complement storage of negative INT8 values.

## Gate result

**PYTHON VERIFICATION UNDERSTANDING GATE: PASSED**

The learner understands that these checks validate three different software responsibilities rather than duplicating the same behavior.

Corrective Python verification is therefore closed from the Verification Engineer perspective. The next workflow action is to return to Design Reviewer mode and re-run `/review int8_quantization` so DR-1 can be closed against the new Python verification evidence.
