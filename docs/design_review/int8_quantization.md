# INT8 Quantization — Design Review

**Role:** Design Reviewer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 10 — DESIGN REVIEW  
**Review status:** APPROVED

## 1. Review Objective

Review the complete Phase-6 INT8 quantization work against its numerical contract, RTL implementation, software reference implementation, directed verification, synthesis/resource evidence, routed timing evidence, and timing-refinement decisions.

## 2. Assumptions

- FPGA target: XC7A35T-1CPG236C on Basys 3.
- Target clock: 100 MHz, so `Tclk = 10 ns`.
- Present arithmetic contract: 3x3 convolution, one input channel, one output channel.
- Generated INT8 operands use `[-127,+127]`.
- Maximum legal positive accumulator under this generated-data contract is `145161`.
- Hardware requantization uses a 24-bit unsigned `M_INT` and compile-time `FRAC_BITS` in `0..42`.
- Representative physical measurements use `M_INT = 13,421,773` and `FRAC_BITS = 27`.
- Those physical parameters are representative rather than final trained-network layer parameters.
- The timing wrapper is a measurement harness, not the final integrated NPU top.

## 3. Evidence Reviewed

The final review includes:

```text
docs/design/int8_quantization.md
docs/design/int8_quantization_timing_refinement.md
python/quantization/int8_quantizer.py
python/verification/test_int8_quantizer.py
rtl/activation/requantize_relu_pipelined.v
rtl/activation/requantize_timing_wrapper.v
rtl/control/control_fsm.v
docs/verification/int8_quantization.md
docs/verification/int8_quantization_pipelined_simulation.md
docs/verification/int8_quantization_python_verification.md
docs/analysis/int8_quantization_measured_vs_predicted.md
```

## 4. Numerical Architecture Review

The selected symmetric per-tensor quantization contract is internally consistent:

```text
x ~= S*q
S = max(|x|)/127
q in [-127,+127]
zero-point = 0
```

Input quantization explicitly uses round-to-nearest with exact ties away from zero. The accumulator scale is correctly derived as:

```text
S_acc = S_a * S_w
```

and the output requantization ratio is:

```text
M = S_acc / S_out
M ~= M_INT / 2^F
```

The present 3x3 single-channel bound is:

```text
9 * 127 * 127 = 145161
```

so the post-ReLU positive magnitude requires 18 unsigned bits. With a 24-bit unsigned coefficient:

```text
18 + 24 = 42-bit raw product
```

and a 43-bit intermediate is retained for the rounding-bias addition.

The maximum-width directed verification preserved both:

```text
product = 2435397306615
rounded_num = 4634420562167
```

Therefore the selected widths are supported by both derivation and measurement.

## 5. RTL Review

`requantize_relu_pipelined.v` implements the selected two-stage architecture:

```text
Stage 1:
acc_in
 -> sign/ReLU gate
 -> 18-bit magnitude
 -> 42-bit multiply
 -> product register

Stage 2:
product register
 -> 43-bit rounding path
 -> right shift
 -> saturation to 127
 -> q_out
```

The full 42-bit raw product is preserved at the pipeline boundary. Non-positive inputs are converted to zero before multiplication, so no separate sign state is required across the pipeline boundary.

The product register uses synchronous active-high reset and was verified to initialize deterministically.

The RTL is intentionally contract-bounded rather than a general full-range INT32 requantizer because it uses `acc_in[17:0]` for the positive magnitude. This is accepted for Phase 6 because the bound is explicitly derived. Any future increase in accumulation depth, channel count, or operand range requires a fresh width derivation.

## 6. Hardware Verification Review

The pipelined RTL behavioral verification passes the required directed cases:

```text
synchronous reset
negative and zero ReLU handling
identity scaling
rounding half steps
non-power-of-two scaling
natural 127 versus saturated 127
maximum-width product preservation
43-bit rounded intermediate
back-to-back pipeline sample association
```

The simulation reports zero failures.

The verification checks internal arithmetic state as well as the final INT8 output, which prevents a correct final value from hiding internal truncation or saturation-path errors.

## 7. Python Verification Review

The original blocking review finding DR-1 required independent software-side verification. That corrective action is now complete.

The committed artifact:

```text
python/verification/test_int8_quantizer.py
```

checks the Python implementation against hand-derived values.

Measured result:

```text
34 directed checks
0 failures
PY_INT8_QUANTIZER_PASS
```

The verified software responsibilities are:

```text
symmetric scale derivation
all-zero scale handling
ReLU output scale derivation
ties-away-from-zero rounding
input clipping to [-127,+127]
maximum 3x3 integer convolution = 145161
requantization parameter generation
M = 0.1 -> M_INT = 13421773, F = 27
proof that F = 28 exceeds the 24-bit coefficient range
BRAM packing and byte order
zero padding of the final packed word
two's-complement storage of negative INT8 values
representative requantize_relu() reference outputs
maximum-width reference requantization
```

The exact BRAM packing check produced:

```text
FE02FF01
FC04FD03
00000005
```

Therefore the software numerical-contract verification required by the original verification plan is now closed.

## 8. Physical Implementation Review

The refined synthesis measurement is:

```text
LUTs        = 27
Slice FFs   = 26
DSP48E1     = 1
CARRY4      = 5
BRAM        = 0
DSP PREG    = 1
```

Vivado absorbed the 42-bit product register into the DSP48E1 output register, so the pipeline boundary did not require 42 extra slice FFs.

The routed timing result is:

```text
WNS = +3.703 ns
TNS = 0.000 ns
WHS = +0.694 ns
THS = 0.000 ns
setup failures = 0
hold failures = 0
```

Therefore 100 MHz timing closure is proven for the representative configuration.

The original unpipelined implementation had:

```text
WNS = -0.405 ns
TNS = -2.381 ns
```

so the measured setup-slack improvement is:

```text
+3.703 - (-0.405) = +4.108 ns
```

The new worst path is Stage 1 and is routing-dominated, confirming that the original long arithmetic chain was successfully broken by the DSP output pipeline register.

## 9. Review Findings

### DR-1 — Python verification plan not closed

**Severity:** BLOCKER  
**Final status:** CLOSED

Corrective evidence now exists in both the committed Python test artifact and the verification-results document. All required directed Python checks pass with zero failures.

### DR-2 — Integrated 70 ns latency remains derived, not re-measured

**Severity:** MEDIUM / NON-BLOCKING  
**Final status:** OPEN FOLLOW-UP

The design derivation shows that the new product register occupies the existing S5-to-S6 handshake interval and therefore should not move the final S7 activation-capture edge.

Accepted current statement:

```text
70 ns external start-to-done latency = architecturally derived
```

Not yet accepted as:

```text
70 ns external start-to-done latency = newly measured after full integration
```

This must be re-measured when the pipelined requantizer is exercised in a complete engine + controller integration test.

### DR-3 — Input and parameter bounds are contract-based

**Severity:** LOW  
**Final status:** ACCEPTED FOR PHASE 6

The current bounds are explicit and appropriate for the learning architecture. They must be re-derived if the accelerator dimensions change.

### DR-4 — Physical measurements are representative

**Severity:** INFORMATIONAL  
**Final status:** ACCEPTED

The current physical result demonstrates the architecture and timing-refinement method but should not be presented as a guarantee for every future layer-specific coefficient pair.

## 10. Approved Design Decisions

The review approves:

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
- post-DSP pipeline boundary
- DSP48E1 PREG inference
- preservation of the existing FSM state count
- independent Python numerical reference
- exact BRAM packing verification
- measurement-driven timing refinement
- explicit routed critical-path inspection
```

## 11. Final Step-10 Verdict

All blocking review findings are now closed.

```text
Functional RTL behavior          : APPROVED
Pipeline sequencing              : APPROVED
Python numerical contract        : APPROVED
BRAM packing/reference behavior  : APPROVED
DSP mapping                      : APPROVED
Resource use                     : APPROVED
100 MHz setup timing             : APPROVED
100 MHz hold timing              : APPROVED
Critical-path characterization   : APPROVED
```

Therefore:

```text
STEP 10 /review int8_quantization
VERDICT: APPROVED
```

The module workflow may now advance to:

```text
Step 11: /test int8_quantization
```

The only remaining review note is the non-blocking future integration measurement of the derived 70 ns end-to-end latency.