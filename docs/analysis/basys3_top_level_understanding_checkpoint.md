# Phase 8 — Basys 3 Top-Level Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 3 — `/analyze basys3_top_level` understanding gate  
**Status:** PASSED — Step 4 learner confirmation is satisfied and Step 5 RTL generation is now eligible.

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

**PASSED.**

The learner correctly restated the actual operand organization:

```text
9 INT8 activations = 9 useful bytes
9 INT8 weights     = 9 useful bytes
useful total       = 18 bytes
```

The physical transfer remains:

```text
3 activation words x 4 bytes = 12 bytes
3 weight words     x 4 bytes = 12 bytes
physical total                = 24 bytes
```

Therefore:

```text
packing efficiency = 18 / 24 = 75%
```

The operand sets are nine INT8 values each, packed across three 32-bit words; they are not three 24-bit operands.

## Correction 2 — DSP prediction for `M_INT = 3`

**PASSED.**

The learner correctly restated that `M_INT = 3` is still represented as a 24-bit compile-time constant whose numerical value is 3.

Vivado may optimize the constant multiplication using an equivalent structure such as:

```text
x * 3 = (x << 1) + x
```

Therefore `DSP = 0` is a reasonable prediction because of constant-multiplier optimization, not because the operation is a 3-bit-by-3-bit multiplication.

Final DSP mapping remains a synthesis measurement.

## Gate result

**BASYS3 TOP-LEVEL ANALYSIS UNDERSTANDING GATE: PASSED**

The learner has correctly restated the prediction model and its two corrected details. This satisfies the mandatory Step-4 confirmation requirement as well.

The workflow may now proceed to:

```text
Step 5 — RTL generation for basys3_top_level
```

No simulation or measurement should occur until the RTL is generated and the later verification/testbench stages are completed in sequence.