# INT8 Quantization — Measured vs Predicted Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED  
**Status:** COMPLETE for the present representative requantization configuration

## 1. Objective

Compare the original arithmetic, resource, and timing predictions against the measurements collected from behavioral simulation, synthesis, and routed implementation, including the timing-refinement iteration required to meet 100 MHz.

## 2. Assumptions

- Target FPGA: XC7A35T-1CPG236C.
- Target clock: 100 MHz.
- Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

- Generated INT8 activations and weights use `[-127,+127]`.
- One present convolution contains nine INT8xINT8 products.
- Maximum positive accumulator under the current 3x3 single-channel contract is `145161`.
- ReLU is applied before positive fixed-point requantization.
- Representative physical-measurement parameters are:

```text
M_INT = 13,421,773 = 24'hCCCCCD
FRAC_BITS = 27
```

- These physical measurements are representative, not yet layer-specific final-network measurements.

## 3. Functional Arithmetic Predictions Versus Measurement

### 3.1 Positive accumulator magnitude

Prediction:

```text
9 * 127 * 127 = 145161
2^17 = 131072
2^18 = 262144
```

Therefore 18 unsigned magnitude bits are required.

Behavioral measurement preserved:

```text
acc_mag = 145161
```

Result: **CONFIRMED**.

### 3.2 Raw product width

Prediction:

```text
145161 * 16777215 = 2435397306615
2^41 < 2435397306615 < 2^42
```

Therefore the raw product requires 42 bits.

Behavioral measurement:

```text
product/product_reg = 2435397306615
```

Result: **CONFIRMED**.

### 3.3 Rounding width

For `FRAC_BITS=42`, the rounding bias is:

```text
2^41 = 2199023255552
```

so:

```text
2435397306615 + 2199023255552
= 4634420562167
```

A conservative 43-bit rounding intermediate is therefore appropriate.

Behavioral measurement:

```text
rounded_num = 4634420562167
q_pre_wide = 1
q_out = 1
```

Result: **CONFIRMED**.

### 3.4 ReLU, rounding, and saturation

Directed simulation confirmed:

```text
-1      -> 0
0       -> 0
1       -> 1
126     -> 126
127     -> 127
128     -> 127
145161  -> 127
```

Positive round-to-nearest with `M_INT=1, FRAC_BITS=1` produced:

```text
1 -> 1
2 -> 1
3 -> 2
4 -> 2
```

Non-power-of-two scaling with `M_INT=3, FRAC_BITS=2` produced:

```text
1   -> 1
2   -> 2
3   -> 2
5   -> 4
169 -> 127 naturally
170 -> 128 internally -> saturated to 127
```

Result: **CONFIRMED**.

## 4. Original Physical Prediction

Before physical measurement, the representative requantization path was predicted to require:

```text
DSP48E1      : 1 optimized target, 1-2 conservative
LUTs         : ~15-35 optimized case, ~60-80 fabric-heavy case
BRAM         : 0
Timing       : 100 MHz plausible but not proven
```

The expected risk path was:

```text
engine register
 -> ReLU/sign logic
 -> multiply
 -> rounding
 -> shift
 -> saturation
 -> activation register
```

The analysis specifically identified the multiplier plus post-DSP rounding/saturation logic as the principal timing risk.

## 5. Baseline Unpipelined Synthesis Measurement

For the representative configuration, Vivado synthesized the baseline registered wrapper as:

```text
LUTs        = 37
Slice FFs   = 39
DSP48E1     = 1
CARRY4      = 5
BRAM        = 0
DSP PREG    = 0
```

DSP mapping reported:

```text
A Size = 24
B Size = 17
C Size = 41
P Size = 42
```

with:

```text
AREG = 0
BREG = 0
MREG = 0
PREG = 0
```

The one-DSP optimized target was therefore achieved.

The measured 37 LUTs were close to the predicted low-resource range and far below the fabric-heavy estimate.

## 6. Baseline Routed Timing Measurement

The original unpipelined implementation failed the 10 ns target:

```text
WNS = -0.405 ns
TNS = -2.381 ns
Failing setup endpoints = 7 / 7
WHS = +0.795 ns
THS = 0
```

The worst path had:

```text
Data path delay = 10.362 ns
Logic delay     = 6.066 ns
Route delay     = 4.296 ns
Logic levels    = 10
```

and included:

```text
pre-DSP LUT logic
 -> DSP48E1
 -> CARRY4 rounding chain
 -> saturation/output LUTs
```

Therefore the original prediction that 100 MHz was plausible but timing-risky was correct; the first implementation did **not** close timing.

## 7. Timing-Refinement Decision

The measured failing path motivated a pipeline boundary immediately after the DSP multiply and before the rounding carry chain.

The new stage stores the full 42-bit product.

Architectural derivation showed that this register could occupy the existing S5-to-S6 handshake interval:

```text
S5: child engine registers final result
S5 -> S6: result propagates through Stage 1
S6: product register captures DSP result
S6 -> S7: rounding/shift/saturation execute
S7: final activation capture remains scheduled
```

Therefore no additional FSM state was required and the intended external start-to-done schedule remained potentially 7 clocks / 70 ns, subject to re-verification.

## 8. Refined Behavioral Verification

The pipelined DUT passed clocked XSim verification with:

```text
TB_REQUANTIZE_RELU_PIPELINED_PASS
failures = 0
```

The testbench confirmed:

```text
synchronous reset
ReLU/non-positive behavior
identity scaling
round-to-nearest
non-power-of-two scaling
natural versus saturated 127
maximum-width 42-bit product
43-bit rounded intermediate
back-to-back sample-to-cycle association
```

Back-to-back samples:

```text
acc=1 -> product_reg=3  -> q=1
acc=3 -> product_reg=9  -> q=2
acc=5 -> product_reg=15 -> q=4
```

Result: **PIPELINE FUNCTIONAL CORRECTNESS CONFIRMED**.

## 9. Refined Synthesis Measurement

The refined implementation synthesized as:

```text
LUTs        = 27
Slice FFs   = 26
DSP48E1     = 1
CARRY4      = 5
BRAM        = 0
DSP PREG    = 1
```

Vivado explicitly reported that `product_reg` was absorbed into the DSP output register.

Therefore the new 42-bit pipeline state did not require 42 ordinary slice FFs.

The remaining 26 slice FFs are:

```text
bit 31 + bits 17:0 = 19 accumulator FFs
output bits 6:0     = 7 output FFs
-------------------------------------
total               = 26 slice FFs
```

Accumulator bits `[30:18]` were optimized away because they cannot affect the bounded 18-bit magnitude datapath. Output bit 7 was optimized away because ReLU/saturation restricts the output to `0..127`.

## 10. Refined Routed Timing Measurement

The pipelined implementation closes timing at 100 MHz:

```text
Setup WNS  = +3.703 ns
Setup TNS  = 0.000 ns
Setup failures = 0 / 37

Hold WHS   = +0.694 ns
Hold THS   = 0.000 ns
Hold failures = 0 / 37

Pulse-width WPWS = +4.500 ns
Pulse-width TPWS = 0.000 ns
```

Vivado reports:

```text
All user specified timing constraints are met.
```

The setup-slack improvement from the original implementation is:

```text
+3.703 - (-0.405) = +4.108 ns
```

Result: **100 MHz TIMING CLOSURE PROVEN** for the present representative configuration.

## 11. New Critical Path After Refinement

The global worst setup path is now Stage 1:

```text
Source      = accumulator_reg_reg[31]
Destination = DSP48E1 product_reg/PREG input
WNS         = +3.703 ns
Data delay  = 2.781 ns
Logic delay = 0.642 ns
Route delay = 2.139 ns
Logic levels = 1 LUT2
```

Delay composition:

```text
logic = 23.087%
route = 76.913%
```

The refined worst path is therefore routing-dominated, not arithmetic-chain-dominated.

The data-path increments are approximately:

```text
FDRE C->Q  = 0.518 ns
route      = 1.545 ns
LUT2       = 0.124 ns
route      = 0.593 ns
-----------------------
total      = 2.780 ns ~= 2.781 ns reported
```

Vivado's full setup equation also includes the DSP registered endpoint's setup requirement plus clock insertion, skew, pessimism, and uncertainty. Therefore slack is not simply `10 - 2.781`.

Measured timing values are:

```text
Arrival Time  = 7.352 ns
Required Time = 11.055 ns
Slack         = +3.703 ns
```

## 12. Prediction Versus Final Measurement Table

| Item | Prediction | Final measured result | Verdict |
|---|---|---|---|
| Max positive accumulator | 145161 | 145161 preserved | Confirmed |
| Magnitude width | 18 unsigned bits | Maximum legal value preserved | Confirmed |
| Raw product width | 42 bits | 2435397306615 exact | Confirmed |
| Rounding intermediate | 43 bits conservative | 4634420562167 exact | Confirmed |
| ReLU/round/saturation | Directed behavior as specified | All tests pass | Confirmed |
| DSP usage | 1 optimized, 1-2 conservative | 1 DSP48E1 | Optimized target confirmed |
| Baseline LUTs | ~15-35 optimized | 37 | Slightly above low estimate |
| Refined LUTs | Not separately predicted | 27 | Measured |
| BRAM | 0 | 0 | Confirmed |
| Baseline PREG | 0 expected | 0 | Confirmed |
| Refined PREG | Desired 1 | 1 | Confirmed |
| Baseline 100 MHz timing | Plausible, unproven | WNS -0.405 ns | Failed |
| Refined 100 MHz timing | Pipeline expected to fix violation | WNS +3.703 ns, TNS 0 | Proven |
| Hold timing after refinement | Must remain non-negative | WHS +0.694 ns | Proven |
| New limiting stage | Unknown before implementation | Stage 1 | Measured |

## 13. Fmax Limitation

The positive WNS at a 10 ns clock proves 100 MHz closure.

Although:

```text
10.000 - 3.703 = 6.297 ns
```

this is not a formally measured minimum clock period or guaranteed Fmax. A tighter constraint can change placement, routing, uncertainty impact, and optimization decisions.

Accepted claim:

```text
100 MHz timing closure is proven for this implementation.
```

Higher-frequency Fmax remains unmeasured.

## 14. External-Latency Interpretation

The pipeline register was deliberately inserted into an already existing control gap rather than by adding a new FSM state.

The design derivation therefore predicts that final activation capture remains at S7 and that external start-to-done latency remains:

```text
7 clocks * 10 ns = 70 ns
```

The pipelined unit verification proves the local product-stage timing and sample association, but a fresh integrated control-level simulation would be required if the project wants a new measured end-to-end S0-to-S7 latency trace after integration.

Thus:

```text
architectural external-latency prediction = 70 ns
new standalone timing-refinement physical latency penalty = no additional FSM state
integrated re-measurement = optional follow-up if required for final review evidence
```

## 15. Step 9 Verdict

The required measured-vs-predicted work for the representative Phase-6 requantization implementation is complete:

```text
functional arithmetic measurement        : COMPLETE / PASS
baseline synthesis resource measurement  : COMPLETE
baseline routed timing measurement       : COMPLETE / FAIL at 100 MHz
pipeline refinement                      : COMPLETE
refined behavioral verification          : COMPLETE / PASS
refined synthesis resource measurement   : COMPLETE
DSP PREG inference                       : COMPLETE / CONFIRMED
refined routed setup timing              : COMPLETE / PASS
refined routed hold timing               : COMPLETE / PASS
critical-path characterization           : COMPLETE
100 MHz timing closure                   : PROVEN
```

**STEP 9 STATUS: COMPLETE.**

The module workflow may now advance to Step 10 `/review int8_quantization`.