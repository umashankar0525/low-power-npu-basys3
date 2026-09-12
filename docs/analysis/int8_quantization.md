# INT8 Quantization — Performance Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** ANALYZE / PREDICT  
**Status:** Prediction only — no RTL, synthesis, implementation, or simulation measurements yet

## 1. Objective

Predict the numerical precision, arithmetic widths, FPGA resource implications, and timing risk of the selected Phase 6 quantization/requantization architecture before implementation.

The selected design performs:

```text
FP32 data
  -> symmetric INT8 quantization in Python
  -> INT8 x INT8 convolution
  -> INT32 accumulator
  -> ReLU sign check
  -> fixed-point requantization
  -> rounded right shift
  -> saturation to 0...127
  -> INT8 activation
```

The critical new hardware operation is the requantization conversion:

```text
M = S_acc / S_out
  = (S_a x S_w) / S_out
```

approximated as:

```text
M_hat = M_int / 2^F
```

with a 24-bit unsigned coefficient target.

## 2. Assumptions

- Target FPGA: XC7A35T-1CPG236C, Basys 3.
- Target clock: 100 MHz.
- Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

- Convolution kernel: 3 x 3.
- Input channels: 1.
- Output channels: 1.
- Four parallel MAC lanes.
- Quantizer-generated activation and weight values use `[-127, +127]`.
- INT8 x INT8 products are accumulated in signed INT32.
- ReLU is applied before the positive requantization multiplier.
- Output after ReLU uses signed-INT8 codes `[0, 127]`.
- Requantization coefficient width target: 24 bits unsigned.
- `M_int` and `F` are constants generated offline for a fixed layer/test configuration.
- The right shift by `F` is therefore a compile-time constant, not a runtime-variable barrel shift.
- The first implementation target is one output activation per completed convolution transaction.
- No floating-point arithmetic is implemented in FPGA logic.
- Resource figures in this document are predictions until Vivado synthesis.
- Timing figures in this document are architectural budgets only until implementation timing is measured.

## 3. Accumulator Range From First Principles

The normal Phase 6 quantizer uses:

```text
q_a, q_w in [-127, +127]
```

The largest product magnitude is:

```text
127 x 127 = 16129
```

Nine equal-sign products give the conservative convolution magnitude bound:

```text
9 x 16129 = 145161
```

For the positive post-ReLU path, the largest useful accumulator is therefore:

```text
acc_max = 145161
```

Unsigned width check:

```text
2^17 = 131072
2^18 = 262144
```

Since:

```text
131072 < 145161 < 262144
```

an 18-bit **unsigned magnitude** is sufficient after the ReLU sign check.

However, before ReLU the value is signed. A signed 18-bit number only reaches:

```text
+131071
```

which is insufficient. A signed 19-bit number reaches:

```text
+262143
```

so 19 signed bits are the mathematical minimum for the complete quantizer-generated convolution range.

The existing INT32 accumulator is therefore much wider than mathematically required for the current 3x3, one-channel case, but it remains the correct architectural accumulator width for extensibility and safety.

## 4. Requantization Coefficient Representation

The real multiplier is:

```text
M = S_acc / S_out
```

The fixed-point approximation is:

```text
M_hat = M_int / 2^F
```

with:

```text
M_int = round(M x 2^F)
```

The 24-bit unsigned coefficient constraint is:

```text
0 <= M_int <= 2^24 - 1
                  = 16777215
```

For a given positive `M`, the Python generator should choose the largest useful `F` for which the rounded coefficient still satisfies that bound.

A robust implementation rule is therefore:

```text
increase F while round(M x 2^F) <= 16777215
```

rather than relying on an approximate logarithm alone.

## 5. Fixed-Point Coefficient Error Bound

Because `M_int` is obtained by rounding `M x 2^F` to the nearest integer, the coefficient rounding error before division is at most one-half integer step:

```text
|M x 2^F - M_int| <= 0.5
```

Divide both sides by `2^F`:

```text
|M - M_hat| <= 0.5 / 2^F
```

Therefore:

```text
|M - M_hat| <= 2^(-F-1)
```

This gives a direct first-principles upper bound on the multiplier approximation error.

For `M > 0`, the relative coefficient error satisfies:

```text
relative_error <= 2^(-F-1) / M
```

The absolute output-code error caused only by coefficient approximation is bounded by:

```text
|acc| x |M - M_hat|
```

so under the Phase 6 accumulator bound:

```text
coefficient_output_error <= 145161 x 2^(-F-1)
```

This is separate from the final output rounding error, which can add up to approximately 0.5 output-code step before saturation.

## 6. Representative Coefficient Example

Assume a representative requantization multiplier:

```text
M = 0.1
```

A 24-bit coefficient permits:

```text
F = 27
```

because:

```text
M_int = round(0.1 x 2^27)
      = 13421773
```

which fits within 24 unsigned bits.

The represented multiplier is:

```text
M_hat = 13421773 / 2^27
      ~= 0.10000000149
```

The absolute multiplier error is therefore approximately:

```text
1.49 x 10^-9
```

At the maximum positive accumulator:

```text
145161 x 1.49 x 10^-9
~= 0.000216 output-code steps
```

This is far below the unavoidable final nearest-integer rounding uncertainty of approximately 0.5 code step.

This example does **not** prove every future scale configuration has the same error. It demonstrates why a 24-bit coefficient can provide very fine requantization precision when `F` is chosen appropriately.

## 7. Useful Upper Bound on Fractional Shift F

The multiplication stage produces a finite-width integer product. There is no numerical value in choosing an arbitrarily large `F` if the rounded result would always become zero.

Using the bounded positive accumulator and a 24-bit coefficient:

```text
acc_max   = 145161
M_int_max = 16777215
```

The largest possible integer product is:

```text
145161 x 16777215
= 2435397306615
```

Compare powers of two:

```text
2^41 = 2199023255552
2^42 = 4398046511104
```

Therefore:

```text
2^41 < 2435397306615 < 2^42
```

so the exact unsigned multiplication result requires **42 bits**.

For round-to-nearest before a right shift by `F`, the threshold for rounding a positive value up from zero is:

```text
2^(F-1)
```

If:

```text
F >= 43
```

then:

```text
2^(F-1) >= 2^42
```

which is already larger than every possible 42-bit product under the stated bounded-data contract. The rounded output would therefore always be zero.

Hence, for this exact Phase 6 bounded architecture, there is no useful precision benefit in selecting:

```text
F > 42
```

A practical parameter generator should therefore use:

```text
F <= 42
```

in addition to the 24-bit coefficient-fit condition.

This cap follows from the arithmetic range; it is not an arbitrary software limit.

## 8. Product Width and Rounding Width

The useful post-ReLU accumulator magnitude is 18 unsigned bits.

The coefficient is 24 unsigned bits.

An unsigned multiply therefore requires up to:

```text
18 + 24 = 42 bits
```

which matches the exact numerical bound derived above.

The rounding operation is:

```text
rounded_num = product + 2^(F-1)
q_pre       = rounded_num >> F
```

For `F <= 42`, the rounding constant fits at or below bit 41.

The addition can generate one carry beyond a 42-bit product, so a conservative rounding intermediate is:

```text
43 bits
```

Prediction:

```text
positive accumulator magnitude : 18 bits
requantization coefficient      : 24 bits
raw multiply result             : 42 bits
rounding-add intermediate        : 43 bits
final stored activation          : 8 bits
```

These widths should be preserved explicitly in the later RTL design so accidental truncation cannot occur before the right shift.

## 9. DSP48E1 Mapping Analysis

AMD 7-series DSP48E1 slices contain a native two's-complement multiplier with a 25-bit input and an 18-bit input. The XC7A35T contains 90 DSP48E1 slices.

At first glance, an 18-bit accumulator magnitude multiplied by a 24-bit coefficient appears to fit a 25 x 18 multiplier. There is an important signedness detail, however.

The coefficient is 24-bit **unsigned**. To present every possible 24-bit unsigned value as a positive two's-complement operand requires a leading zero, so it becomes a 25-bit signed-positive quantity. That fits the 25-bit DSP input.

The accumulator magnitude is 18-bit **unsigned** and can reach 145161. An 18-bit signed operand only reaches +131071. Therefore the full accumulator range would require 19 signed bits after zero extension, which does not directly fit the native 18-bit signed DSP input.

Consequently, a simple generic expression does not guarantee a one-DSP implementation for the full exact unsigned range.

### Architectural lower bound

Only one mathematical multiplication is required, so the arithmetic lower bound is one multiplier resource.

### Practical mapping prediction

Two implementation outcomes are plausible:

```text
Outcome A:
1 DSP48E1 + small correction/decomposition logic

Outcome B:
2 DSP48E1 slices for a straightforward widened unsigned multiply
```

A one-DSP decomposition is possible in principle by separating the accumulator's top magnitude bit from the lower 17 bits:

```text
acc = acc_low17 + acc_bit17 x 2^17
```

Then:

```text
acc x M_int
= acc_low17 x M_int
  + acc_bit17 x (M_int << 17)
```

The first term uses a 17-bit unsigned accumulator portion, which can be zero-extended safely into the DSP's 18-bit signed-positive input. The second term is a conditional shifted copy of the coefficient and can be added separately.

Whether Vivado automatically produces this one-DSP structure from straightforward RTL is not assumed. Synthesis must measure it.

### Predicted DSP usage

For planning purposes:

```text
minimum / optimized target : 1 DSP48E1
conservative direct-mapping prediction : 1 to 2 DSP48E1
```

Since the XC7A35T has 90 DSP slices:

```text
1 DSP = 1 / 90 ~= 1.11% of device DSPs
2 DSP = 2 / 90 ~= 2.22% of device DSPs
```

This is a small fraction of the device, but exact mapping must be measured.

## 10. LUT Resource Prediction

The requantization stage contains more than the multiplier:

```text
sign/ReLU decision
fixed-point multiply
rounding bias addition
constant right shift
saturation test
8-bit output selection
```

Because `F` is a compile-time constant, the right shift is wiring selection rather than a general variable barrel shifter. It should therefore require little or no dedicated LUT logic by itself.

The largest fabric cost outside the multiplier is the rounding addition if it is not absorbed into DSP arithmetic.

### Fabric-add case

A 43-bit rounding addition maps naturally onto FPGA carry-chain logic. A first-order estimate is approximately one LUT/carry bit per arithmetic bit:

```text
~43 LUT-scale bit positions
```

The saturation detector checks whether the shifted positive result contains any set bit above output bit 6. In the worst wide-result case, this is a reduction-OR across several tens of bits. With 6-input LUTs, a first reduction level for about 35 upper bits requires approximately:

```text
ceil(35 / 6) = 6 LUTs
```

followed by approximately one additional reduction LUT:

```text
~7 LUTs total for the wide overflow reduction
```

An 8-bit output selection path can require approximately one LUT per output bit if implemented separately:

```text
~8 LUTs
```

So if the rounding adder remains in fabric, a first-order total outside the multiplier is roughly:

```text
43 + 7 + 8 = 58 LUT-scale functions
```

Allowing control/mux/sign handling and synthesis differences gives a reasonable prediction band of approximately:

```text
60 to 80 LUTs outside the multiplier
```

### DSP-post-adder case

If the DSP48E1 post-adder absorbs the rounding bias addition, the approximately 43-bit fabric adder can disappear from the LUT count.

Then a more likely external-logic range is approximately:

```text
15 to 35 LUTs
```

for sign gating, saturation detection, output selection, and glue logic.

These are first-principles architectural estimates, not synthesis results.

## 11. Flip-Flop Prediction

The baseline design was originally specified as combinational between the engine result register and the activation capture register.

Under that exact baseline:

```text
new architectural pipeline FFs inside requantization = 0
```

The final INT8 output register belongs to the surrounding integration path and should not be double-counted as a new requantization-internal register.

However, timing analysis below identifies a strong reason to consider one DSP/output pipeline stage. If such a stage is added, FF usage rises, but the external transaction latency may not necessarily increase because of the existing registered `engine_done` visibility gap.

## 12. Timing Budget

At 100 MHz:

```text
Tclk = 10 ns
```

The combinational path contains:

```text
engine result register
 -> sign/ReLU gating
 -> wide fixed-point multiply
 -> rounding add
 -> constant shift wiring
 -> saturation detection
 -> output mux
 -> capture register
```

The previous ReLU-only path was very small. The new wide multiplier is now the dominant timing element.

No numerical propagation delay can be claimed before implementation.

### Qualitative timing prediction

A dedicated DSP48E1 multiplier is designed for high-speed arithmetic and makes 100 MHz plausible. However, the baseline specifically asks for an unpipelined or minimally pipelined path plus surrounding fabric logic. Routing and register placement can still make the 10 ns requirement fail.

Therefore the pre-synthesis timing classification is:

```text
100 MHz feasibility: plausible
confidence without synthesis: insufficient
risk level: moderate
```

It would be incorrect to declare timing closure solely because the DSP block itself is capable of high frequency. The complete register-to-register path, including routing, rounding, and saturation logic, must meet setup timing.

## 13. Important Control/Timing Opportunity: One Pipeline Stage May Be Hidden

The current supervisory Control FSM already has a registered-handshake delay between the child engine's completion edge and the final activation capture edge.

From the previously derived control sequence:

```text
S5: child engine registers result and engine_done
S6: outer FSM observes engine_done and enters CAPTURE_ACTIVATION
S7: final output register captures the activation result
```

The engine result is therefore available after S5, while the final activation register is not captured until S7.

This creates an architectural opportunity.

A one-stage requantization register could capture the multiplier/rounding result at S6:

```text
S5 -> S6:
engine result -> requantization datapath -> requantization register

S6 -> S7:
requantization register -> final activation capture register
```

If implemented carefully, this **does not have to add another external start-to-done cycle**, because the register is inserted into a cycle that already exists due to the registered `engine_done` handshake.

This is a stronger option than immediately adding a new FSM state.

### Prediction

If the purely combinational requantization path fails timing, the preferred first refinement is:

```text
use one internal registered requantization stage aligned with the existing S5-to-S6 handshake gap
```

rather than immediately increasing transaction latency.

A two-or-more-stage arithmetic pipeline would require the control timing to be re-derived and may add external latency.

## 14. External Latency Prediction

If the baseline requantization logic is combinational and the existing FSM state sequence is unchanged, the previously derived outer Control FSM latency remains:

```text
7 clock periods
```

At 100 MHz:

```text
7 x 10 ns = 70 ns
```

If one requantization pipeline register is inserted and aligned with the existing S5-to-S6 handshake gap as described above, the external 70 ns latency can potentially remain unchanged.

If a pipeline stage instead requires a genuinely new wait state, then each added state contributes:

```text
1 cycle = 10 ns
```

For example:

```text
70 ns + 1 added cycle = 80 ns
```

This distinction must be verified in the final integrated timing schedule before RTL is changed.

## 15. Throughput Prediction

The requantization stage handles one scalar convolution output per transaction. It does not change the number of BRAM words or the four-MAC 4+4+1 product schedule.

Therefore, if it fits within the existing control schedule, the transaction-throughput bound remains unchanged from the Control FSM prediction.

If an additional FSM cycle becomes necessary, the minimum interval between accepted transactions increases by one 10 ns cycle.

No higher-throughput overlapping architecture is assumed in Phase 6.

## 16. Power Prediction

ReLU-before-requantization has a power advantage in principle.

For negative accumulator values:

```text
output = 0
```

so the multiplier does not need to process the original negative magnitude if its input is explicitly gated or replaced with zero.

This can reduce dynamic switching activity in the wide multiplier path.

No numerical power reduction percentage is predicted because that would require at least:

```text
fraction of negative accumulators
signal toggle rates
actual DSP/LUT mapping
clock-enable behavior
post-implementation power analysis
```

The correct Phase 6 prediction is therefore qualitative only: ReLU-first enables activity reduction; the magnitude is unknown until representative activity is measured.

## 17. Numerical Error Budget

The full quantized path contains distinct error sources.

### A. Input activation quantization

For activation scale `S_a`, nearest rounding contributes at most approximately:

```text
S_a / 2
```

real-value error per unclipped activation sample.

### B. Weight quantization

For weight scale `S_w`, nearest rounding contributes at most approximately:

```text
S_w / 2
```

real-value error per unclipped weight sample.

### C. Requantization coefficient approximation

```text
|M - M_hat| <= 2^(-F-1)
```

### D. Output integer rounding

Nearest output-code rounding contributes at most approximately:

```text
0.5 output-code step
```

before clipping.

### E. Clipping/saturation

If the true output exceeds the calibrated INT8 representable range, clipping error is not bounded by half a code step; it can be much larger.

This separation is essential during verification. A hardware mismatch must not be excused as normal quantization error. The Python integer reference and RTL should match exactly at the integer-contract level for the same `M_int`, `F`, and rounding rule.

## 18. Verification-Relevant Predictions

Before RTL, the future verification plan should include values that exercise all numerically important boundaries:

```text
negative accumulator -> 0
zero accumulator -> 0
smallest positive accumulator
value that rounds down
value exactly around a half-LSB requantization threshold
value that rounds up
largest non-saturating output code
first value producing 128 before saturation -> 127
maximum bounded accumulator 145161
coefficient configurations with small and large F
all-zero tensor scale case
```

The Python reference must compute the expected integer output independently using exactly the specified coefficient and rounding rules.

## 19. Resource Prediction Summary

Prediction before synthesis:

```text
DSP48E1:
  optimized architectural target : 1
  conservative likely range      : 1 to 2

LUTs outside multiplier:
  if rounding adder uses fabric  : about 60 to 80
  if DSP absorbs wide addition   : about 15 to 35

Internal pipeline FFs:
  baseline combinational design  : 0
  optional timing register       : added only if selected after analysis/synthesis

BRAM:
  no additional BRAM required for requantization itself
```

The XC7A35T provides 90 DSP48E1 slices, so even a two-DSP implementation would consume only about 2.22% of the device's DSP resources.

## 20. Timing Prediction Summary

```text
clock period                         = 10 ns
baseline external start-to-done      = 70 ns if control sequence unchanged
new dominant path                    = fixed-point requantization multiplier
100 MHz outcome                      = plausible but unproven
preferred fallback if timing fails   = one registered requantization stage
possible latency cost of that stage  = 0 extra external cycles if aligned with existing handshake gap
```

Implementation timing must later report at minimum:

```text
WNS
TNS
critical-path startpoint
critical-path endpoint
logic levels / DSP involvement
setup pass/fail
hold pass/fail
```

## 21. Prediction Versus Measurement Table

| Item | Prediction | Measured |
|---|---:|---:|
| Quantizer-generated positive accumulator maximum | 145161 | Pending |
| Minimum post-ReLU magnitude width | 18 unsigned bits | Pending |
| Requant multiply width | 18 x 24 | Pending |
| Raw multiply result width | 42 bits | Pending |
| Rounding intermediate width | 43 bits conservative | Pending |
| Useful fractional shift cap | F <= 42 | Pending |
| DSP usage | 1 to 2 DSP48E1 | Pending |
| LUTs outside multiplier | ~15-35 if DSP absorbs add; ~60-80 if fabric add | Pending |
| Additional BRAM | 0 | Pending |
| Baseline control latency | 70 ns if state sequence unchanged | Pending |
| 100 MHz timing closure | Plausible, not guaranteed | Pending |

## 22. Analysis Conclusion

The selected fixed-point requantization architecture is numerically well matched to the current accelerator.

The most important predictions are:

```text
1. Quantizer-generated 3x3 positive accumulator magnitude fits in 18 unsigned bits.
2. A 24-bit requantization coefficient produces a 42-bit raw product.
3. Coefficient error is bounded by 2^(-F-1).
4. F > 42 is not useful under the bounded current architecture.
5. Requantization is likely to use 1 to 2 DSP48E1 slices depending on signed/unsigned mapping and synthesis structure.
6. The wide multiplier, not ReLU, becomes the main timing risk.
7. A one-stage requantization pipeline may be inserted into the already-existing engine_done visibility gap without necessarily increasing the 70 ns external transaction latency.
```

No RTL should be generated until the learner confirms understanding of these predictions.

## 23. Required Understanding Gate

Before Step 5 RTL generation, the learner must explain in their own words:

1. why the post-ReLU accumulator magnitude requires 18 unsigned bits even though the full signed sum requires 19 bits,
2. why an 18-bit magnitude times a 24-bit coefficient requires a 42-bit product,
3. why the coefficient approximation error is bounded by `2^(-F-1)`,
4. why a one-DSP mapping is possible as an optimization but not guaranteed by a straightforward unsigned multiply,
5. why 100 MHz cannot be claimed before timing measurement, and
6. how one pipeline register may fit into the existing Control FSM handshake gap without necessarily adding an external cycle.

After this understanding gate passes, the project may proceed to implementation planning and RTL generation.