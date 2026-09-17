# Phase 8 — Basys 3 Top-Level Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 3 — `/analyze basys3_top_level` understanding gate  
**Status:** PARTIAL — two corrections required before Step 4 / RTL eligibility.

## Passed concepts

The learner correctly explained:

- debounce latency versus core compute latency,
- 70 ns core latency from 7 cycles at 100 MHz,
- 90 ns initiation interval from 9 cycles at 100 MHz,
- 800 MB/s peak internal dual-interface bandwidth,
- 266.67 MB/s sustained physical bandwidth,
- approximately 12 board IOBs because the memory buses become internal,
- the 48 logical wrapper-FF derivation,
- why BRAM must be non-zero but exact primitive mapping is deferred to synthesis,
- why 100 MHz closure is a reasonable prediction rather than a guarantee,
- why LUT/FF/CARRY predictions are ranges before synthesis.

## Correction 1 — useful-byte interpretation

The final values `24 physical bytes`, `18 useful bytes`, and `75% packing efficiency` are correct, but the useful-data explanation must use the actual operand organization.

Each transaction contains:

```text
9 INT8 activations = 9 bytes useful
9 INT8 weights     = 9 bytes useful
```

Therefore:

```text
useful bytes = 9 + 9 = 18 bytes
```

The physical transfer is:

```text
3 activation words x 4 bytes = 12 bytes
3 weight words     x 4 bytes = 12 bytes
physical total                = 24 bytes
```

Hence:

```text
packing efficiency = 18 / 24 = 75%
```

The design does not contain three 24-bit activation operands or three 24-bit weight operands; rather, it contains nine INT8 elements per operand set packed across three 32-bit words.

## Correction 2 — DSP prediction for `M_INT = 3`

`M_INT = 3` does not imply a 3-bit-by-3-bit multiplier.

The requantizer still conceptually multiplies the accumulator by a 24-bit compile-time constant whose numerical value is 3. Because the constant is fixed, synthesis can implement:

```text
x * 3 = (x << 1) + x
```

or another equivalent constant-multiply structure using LUT/carry logic instead of a DSP48E1.

Therefore `DSP = 0` is a reasonable prediction because of **constant-multiplier optimization**, not because the multiplication is inherently only 3 bits wide.

Final DSP mapping remains a synthesis measurement, not a guaranteed prediction.

## Gate result

**BASYS3 TOP-LEVEL ANALYSIS UNDERSTANDING GATE: NOT YET PASSED**

The learner must restate the two corrected points above before Step 3 can pass and before Phase-8 RTL generation becomes eligible.