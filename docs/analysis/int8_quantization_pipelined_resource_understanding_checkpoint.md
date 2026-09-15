# INT8 Quantization — Pipelined Resource Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — RESOURCE-MAPPING UNDERSTANDING CHECK

## Assumptions

- The refined synthesis uses one DSP48E1 with `PREG = 1`.
- The 42-bit product register is absorbed into the DSP48E1 output register and therefore is not counted as Slice Registers.
- Synthesis removes accumulator bits `[30:18]` because they do not affect the bounded 18-bit magnitude datapath.
- Synthesis removes `output_activation_reg[7]` because the ReLU/saturated output range is `0..127`.

## Learner checkpoint

### 1. Why the product register does not increase the Slice Register count

**Status: PASSED**

The learner correctly explained that the 42-bit product state is physically stored inside the DSP48E1 `PREG`, so those 42 registered bits do not appear as slice FFs.

### 2. Why the reported Slice Register count is 26

**Status: PASSED**

The learner correctly identified the retained accumulator register bits as:

```text
bit 31      : sign
bits 17:0   : magnitude
```

which gives:

```text
1 + 18 = 19 accumulator slice FFs
```

The output register retains only bits `[6:0]` because bit 7 is constant zero after ReLU/saturation, giving:

```text
7 output slice FFs
```

Therefore:

```text
19 + 7 = 26 slice FFs
```

## Gate result

**PIPELINED RESOURCE-MAPPING UNDERSTANDING GATE: PASSED**

The project may proceed to detailed inspection of the refined post-route critical path. The top-level timing summary already shows 100 MHz setup and hold closure, but the new limiting path should still be inspected cell-by-cell before the timing-refinement analysis is considered fully characterized.
