# INT8 Quantization — Design Review

**Role:** Design Reviewer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 10 — DESIGN REVIEW  
**Review status:** CHANGES REQUIRED BEFORE STEP 10 CAN PASS

## 1. Review Objective

Review the complete Phase-6 INT8 quantization work against its documented numerical contract, implementation, verification plan, synthesis/resource evidence, and routed timing evidence.

The review covers:

```text
host-side quantization/reference logic
baseline combinational requantization
pipelined requantization refinement
clocked RTL verification
timing-wrapper synthesis
post-route timing closure
resource mapping
control/latency assumptions
verification completeness
```

## 2. Assumptions

- FPGA target: XC7A35T-1CPG236C on Basys 3.
- Target clock: 100 MHz, `Tclk = 10 ns`.
- Current arithmetic contract is 3x3, one input channel, one output channel.
- Generated INT8 operands use `[-127,+127]`.
- Maximum legal positive convolution accumulator under the present generated-data contract is `145161`.
- Hardware requantization uses a 24-bit unsigned `M_INT` and compile-time `FRAC_BITS` in `0..42`.
- Representative physical measurements use `M_INT = 13,421,773` and `FRAC_BITS = 27`.
- Those physical parameters are representative, not yet final layer-specific model parameters.
- The timing wrapper is a measurement harness, not an integrated NPU top.

## 3. Evidence Reviewed

The review inspected the following repository evidence:

```text
docs/design/int8_quantization.md
docs/design/int8_quantization_timing_refinement.md
python/quantization/int8_quantizer.py
rtl/activation/requantize_relu_pipelined.v
rtl/activation/requantize_timing_wrapper.v
rtl/control/control_fsm.v
docs/verification/int8_quantization.md
docs/verification/int8_quantization_pipelined_simulation.md
docs/analysis/int8_quantization_measured_vs_predicted.md
```

Repository directory inspection also shows that the current `python/` tree contains only the `quantization/` directory and no committed Python verification/test file, while `tb/unit/` contains the RTL unit testbenches including both requantization testbenches.

## 4. Architectural Review

### 4.1 Quantization contract

The selected symmetric per-tensor scheme is internally consistent:

```text
x ~= S*q
S = max(|x|)/127
q in [-127,+127]
zero-point = 0
```

The design explicitly defines ties-away-from-zero rounding for input quantization and uses positive round-to-nearest for the post-ReLU requantization path.

The accumulator scaling relation is correctly derived as:

```text
S_acc = S_a * S_w
```

and the output requantization ratio is:

```text
M = S_acc / S_out
M ~= M_INT / 2^F
```

This is a sound integer-only architecture for the present scope.

### 4.2 Width derivation

The important widths were derived and later verified:

```text
maximum legal positive accumulator = 9 * 127 * 127 = 145161
18 unsigned magnitude bits required
18 x 24 multiply -> 42-bit raw product
43-bit conservative rounding intermediate
```

The maximum-width behavioral test preserved:

```text
product = 2435397306615
rounded_num = 4634420562167
```

so the chosen widths are not merely theoretical; the boundary arithmetic was exercised.

### 4.3 Timing refinement

The original unpipelined datapath correctly exposed a real physical problem rather than hiding it:

```text
WNS = -0.405 ns
TNS = -2.381 ns
```

The failing path combined the DSP operation with post-DSP carry-chain rounding and saturation logic.

The redesign placed a full 42-bit product register directly after the DSP. The placement was well justified because it separates:

```text
Stage 1: sign/ReLU preparation -> multiply -> product register
Stage 2: rounding -> shift -> saturation -> activation capture
```

This is a strong measurement-driven design decision.

## 5. RTL Review

### 5.1 Pipelined datapath

`requantize_relu_pipelined.v` matches the selected architecture:

```text
acc_in
 -> positive/sign gate
 -> 18-bit magnitude
 -> 42-bit product_next
 -> 42-bit product_reg
 -> 43-bit rounding path
 -> right shift
 -> saturation to 127
 -> q_out
```

The product register preserves the full multiply width, and non-positive inputs are converted to zero before the pipeline boundary, so no separate sign state is required after the register.

### 5.2 Reset

The product register uses synchronous active-high reset and is explicitly cleared to zero. The behavioral test confirms deterministic reset behavior.

### 5.3 Contract dependence

The RTL intentionally uses only `acc_in[17:0]` for the positive magnitude. This is correct under the documented Phase-6 bound but means the implementation is not a general full-range INT32 requantizer.

This is acceptable for the present module only because the bound is explicit and mathematically derived. Any future increase in channel count, kernel accumulation depth, or operand range requires re-deriving this width.

## 6. Verification Review

### 6.1 RTL verification — PASS

The pipelined RTL behavioral simulation is strong for the hardware datapath. It verifies:

```text
synchronous reset
negative and zero ReLU behavior
identity scaling
rounding half steps
non-power-of-two scaling
natural 127 versus saturation-to-127
maximum-width product preservation
43-bit rounded intermediate
back-to-back sample-to-cycle association
```

The simulation reports zero failures.

The internal-signal checks are particularly valuable because they prevent a correct final INT8 value from hiding truncation or saturation-path errors.

### 6.2 Physical verification — PASS for representative configuration

The refined synthesis result confirms:

```text
DSP48E1 = 1
PREG = 1
LUTs = 27
Slice FFs = 26
CARRY4 = 5
BRAM = 0
```

The 42-bit product state is absorbed into the DSP output register rather than consuming 42 slice FFs.

The final routed implementation reports:

```text
WNS = +3.703 ns
TNS = 0.000 ns
WHS = +0.694 ns
THS = 0.000 ns
setup failures = 0
hold failures = 0
```

Therefore 100 MHz timing closure is proven for the representative measurement configuration.

### 6.3 Python numerical-contract verification — BLOCKING GAP

The original verification plan explicitly requires a Python verification layer covering:

```text
symmetric scale derivation
all-zero scale handling
ties-away-from-zero rounding
input clipping
3x3 integer convolution
requantization parameter generation
BRAM packing
Python-to-RTL/reference cross-check cases
```

Its pass criteria state that every directed Python numerical-contract test must match the hand-derived result.

The current repository contains `python/quantization/int8_quantizer.py`, but no committed Python verification/test artifact is present in the current `python/` tree.

Therefore there is currently no repository evidence that the software-side quantization and BRAM-packing implementation has been executed against the verification cases required by the verification plan.

This is not a cosmetic documentation issue. Phase 6 explicitly contains both software-side data generation and RTL requantization, so hardware-only verification is insufficient to close the whole `int8_quantization` module.

**Severity: BLOCKER for Step-10 approval.**

## 7. Design Review Findings

### Finding DR-1 — Python verification plan has not been closed

**Severity:** BLOCKER  
**Status:** OPEN

Required corrective action:

Create and run an independent Python verification artifact, preferably under:

```text
python/verification/test_int8_quantizer.py
```

At minimum it must verify the already-derived cases from `docs/verification/int8_quantization.md`:

```text
1. nonzero symmetric scale
2. all-zero scale -> 1.0
3. +0.5/-0.5 tie behavior away from zero
4. clipping to [-127,+127]
5. maximum 3x3 integer convolution -> 145161
6. M=0.1 parameter generation -> M_INT=13421773, F=27
7. proof that F=28 does not fit the 24-bit coefficient
8. BRAM packing:
   0xFE02FF01
   0xFC04FD03
   0x00000005
9. representative requantize_relu reference outputs matching hand-derived values
```

The results must be documented signal/value by signal/value, not merely summarized as “tests pass.”

### Finding DR-2 — Integrated 70 ns latency remains derived, not re-measured

**Severity:** MEDIUM / NON-BLOCKING FOR THIS UNIT REVIEW  
**Status:** OPEN FOLLOW-UP

The timing-refinement design derives that the product register occupies the existing S5-to-S6 handshake interval and therefore does not move the final S7 activation-capture edge.

However, the current repository evidence proves the pipelined unit and timing wrapper, not a fresh integrated engine + controller + pipelined requantizer end-to-end waveform.

Therefore the accepted statement is:

```text
70 ns external start-to-done latency = architecturally derived
```

not:

```text
70 ns external start-to-done latency = newly measured after pipeline integration
```

This should be re-measured when the pipelined block is integrated into the system-level datapath.

### Finding DR-3 — Input and parameter bounds are contract-based rather than hardware-guarded

**Severity:** LOW / ACCEPTED SCOPE LIMITATION  
**Status:** ACCEPTED FOR PHASE 6

The RTL assumes:

```text
valid positive magnitude <= 145161
FRAC_BITS in 0..42
M_INT fits 24 unsigned bits
```

The module contains no runtime assertion or hardware fallback for violating those assumptions.

That is acceptable in the present learning architecture because the values are compile-time/generated-data contracts, but future generalization must re-derive the widths rather than reusing the block blindly.

The Python reference similarly should be treated as a contract-driven reference rather than as proof that arbitrary INT32 inputs are supported by the RTL.

### Finding DR-4 — Physical numbers are representative, not final layer-specific measurements

**Severity:** INFORMATIONAL  
**Status:** ACCEPTED

The measured configuration uses:

```text
M_INT = 13,421,773
FRAC_BITS = 27
```

This is sufficient to demonstrate the architecture, DSP mapping, and timing-refinement method, but it is not yet a final trained-network layer measurement.

No claim should be made that every future coefficient pair will produce identical utilization or slack without re-measurement.

## 8. Strong Design Decisions

The following decisions are approved:

```text
- symmetric per-tensor INT8 baseline
- explicit ties-away-from-zero software rounding
- independent activation and weight scales
- integer-only hardware requantization
- 18-bit positive magnitude under the present contract
- 42-bit full product preservation
- 43-bit conservative rounding intermediate
- ReLU before positive requantization
- one-DSP target
- explicit post-DSP pipeline boundary
- preserving the existing FSM state count
- using measured timing evidence rather than assuming 100 MHz closure
- inspecting internal arithmetic during simulation
- inspecting the actual routed critical path after timing closure
```

## 9. Resource/Timing Review Verdict

For the representative hardware configuration:

```text
functional RTL behavior        : APPROVED
pipeline cycle association     : APPROVED
DSP mapping                    : APPROVED
resource use                   : APPROVED
100 MHz setup timing           : APPROVED
100 MHz hold timing            : APPROVED
critical-path characterization : APPROVED
```

The hardware refinement is therefore technically successful.

## 10. Overall Step-10 Verdict

The complete `int8_quantization` module cannot yet receive final Step-10 approval because the original verification plan includes a required Python numerical-contract layer that has not been demonstrated by a committed test artifact and execution evidence.

Therefore:

```text
STEP 10 /review int8_quantization
VERDICT: CHANGES REQUIRED
```

The single blocking action is:

```text
complete and document Python-side verification
```

After that passes, return to `/review int8_quantization` to close DR-1 and issue the final approval verdict.

Step 11 `/test int8_quantization` must not begin until Step 10 is approved.

## 11. Review Understanding Gate

Before corrective verification begins, the learner must explain in their own words:

1. Why the hardware can be considered functionally and physically successful while the overall Phase-6 module review still cannot pass.
2. Which software-side behaviors still require independent verification before Step 10 can be approved.
