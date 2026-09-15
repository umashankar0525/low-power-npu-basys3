# Phase 6 Revision Guide — INT8 Quantization and Requantization

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Purpose:** Revision material for the completed `/test int8_quantization` mastery check  
**Module status:** COMPLETE  

---

## 1. Assumptions and Design Contract

All answers in this guide are based on the Phase-6 design contract:

- Quantization scheme: symmetric per-tensor INT8.
- Generated INT8 range: `[-127, +127]`.
- Zero-point: `0`.
- Convolution kernel: `3 x 3`.
- Input channels: `1`.
- Output channels: `1` for the current arithmetic block.
- Number of products per output: `9`.
- Accumulator RTL width: signed INT32.
- Maximum legal positive integer accumulation under the present contract: `145161`.
- Post-ReLU magnitude width used by the requantizer: `18` unsigned bits.
- Requantization coefficient: unsigned 24-bit `M_INT`.
- Fractional-bit range: `FRAC_BITS = 0..42`.
- Requantization output range after ReLU/saturation: `0..127`.
- FPGA target: XC7A35T-1CPG236C, Basys 3.
- Target clock: `100 MHz`, so `Tclk = 10 ns`.
- Representative physical requantization parameters: `M_INT = 13,421,773`, `FRAC_BITS = 27`.
- The current `70 ns` end-to-end start-to-done latency remains architecturally derived and must be re-measured after full engine + controller + pipelined requantizer integration.

---

# Part 1 — Quantization Mathematics

## Q1. How is the symmetric INT8 scale derived, and what does `x ~= S*q` mean?

For symmetric INT8 quantization using the generated range:

```text
q in [-127,+127]
```

the scale is:

```text
S = max(|x|) / 127
```

If:

```text
max(|x|) = 0.8
```

then:

```text
S = 0.8 / 127
  = 0.006299212598425197...
```

So:

```text
S ~= 0.00629921
```

The relation:

```text
x ~= S*q
```

means that the integer code `q` represents the real value `x` in steps of size `S`.

For example, for `q = 100`:

```text
x ~= 100 * 0.00629921
  ~= 0.629921
```

Conversely, quantization is approximately:

```text
q ~= x / S
```

followed by the project-defined rounding rule and clipping to `[-127,+127]`.

### Key revision point

`S` is the real-value size of one integer step. The integer by itself has no real-world numerical meaning unless its scale is known.

---

## Q2. Why is the accumulator scale `S_acc = S_a * S_w`?

Start from the quantized representations:

```text
a ~= S_a * q_a
w ~= S_w * q_w
```

A single real-valued product is:

```text
a*w ~= (S_a*q_a)(S_w*q_w)
```

Rearrange:

```text
a*w ~= (S_a*S_w)(q_a*q_w)
```

Therefore the integer product `q_a*q_w` has scale:

```text
S_a*S_w
```

For convolution:

```text
y = sum_i(a_i*w_i)
```

becomes:

```text
y ~= S_a*S_w * sum_i(q_a,i*q_w,i)
```

Define the integer accumulator:

```text
ACC = sum_i(q_a,i*q_w,i)
```

Then:

```text
y ~= S_acc * ACC
```

with:

```text
S_acc = S_a*S_w
```

### Key revision point

The integer accumulator stores only integer MAC results. `S_acc` tells us how to interpret that integer accumulation in the real-number domain.

---

## Q3. What is the maximum positive 3x3 convolution accumulator, and why are 18 unsigned magnitude bits sufficient after ReLU?

A `3 x 3 x 1` convolution contains:

```text
3*3*1 = 9 products
```

The largest generated INT8 magnitude is `127`, so the largest positive product is:

```text
127*127 = 16129
```

Therefore:

```text
ACC_max = 9*16129
        = 145161
```

Now check unsigned width:

```text
2^17 - 1 = 131071
2^18 - 1 = 262143
```

Since:

```text
131071 < 145161 <= 262143
```

we need:

```text
18 unsigned magnitude bits
```

Before ReLU the accumulator can be positive or negative, so the main accumulator remains signed and wide. After ReLU:

```text
ReLU(ACC) = max(0, ACC)
```

therefore:

```text
0 <= ACC <= 145161
```

and the requantization magnitude path only needs 18 unsigned bits.

### Key revision point

The 18-bit statement applies to the bounded non-negative magnitude entering requantization. It does not mean the main convolution accumulator should be only 18 bits wide.

---

# Part 2 — Fixed-Point Requantization

## Q4. Why is `M = S_acc / S_out` required instead of clipping the accumulator directly to `0..127`?

The real interpretation of the integer accumulator is:

```text
y ~= S_acc * ACC
```

The output tensor is represented as:

```text
y ~= S_out * q_out
```

Equating the two representations:

```text
S_out*q_out ~= S_acc*ACC
```

so:

```text
q_out ~= (S_acc/S_out)*ACC
```

Define:

```text
M = S_acc / S_out
```

Therefore:

```text
q_out ~= M*ACC
```

Directly clipping the accumulator would ignore the fact that `ACC` and `q_out` use different scales.

Example:

```text
S_acc = 0.0001
S_out = 0.01
M     = 0.01
ACC   = 500
```

The real value is:

```text
y = 500*0.0001 = 0.05
```

The correct output code is:

```text
q_out = 0.05/0.01 = 5
```

Direct clipping would incorrectly produce `127`.

To avoid floating-point hardware, represent the real multiplier as:

```text
M ~= M_INT / 2^F
```

Then:

```text
q_out ~= (ACC*M_INT) / 2^F
```

which hardware implements with:

```text
integer multiply + rounding + right shift + saturation
```

### Key revision point

Requantization is a change of numerical scale, not just a range clamp.

---

## Q5. Why is the positive requantization equation

```text
q_pre = (acc*M_INT + 2^(F-1)) >> F
```

used?

First compute the integer product:

```text
P = acc*M_INT
```

because:

```text
M ~= M_INT/2^F
```

and therefore:

```text
acc*M ~= (acc*M_INT)/2^F
```

A right shift by `F` performs integer division by `2^F`:

```text
P >> F = floor(P/2^F)
```

That would truncate the fractional part. To implement round-to-nearest for positive values, add half of the divisor before shifting:

```text
half divisor = 2^F / 2 = 2^(F-1)
```

So:

```text
q_pre = floor((P + 2^(F-1))/2^F)
```

Example for `F = 4`:

```text
2^F     = 16
2^(F-1) = 8
```

For `P = 40`:

```text
40/16 = 2.5
(40+8)/16 = 48/16 = 3
```

so the half-step rounds upward.

### Key revision point

The rounding bias does not change the fixed-point scale. It compensates for the truncation that would otherwise occur during the final right shift.

---

# Part 3 — Widths and Pipeline Architecture

## Q6. Why is the raw product 42 bits, and why is the rounding intermediate 43 bits?

The post-ReLU magnitude is 18 bits and the coefficient is 24 bits:

```text
18-bit magnitude * 24-bit M_INT
```

A full unsigned product can require the sum of the operand widths:

```text
18 + 24 = 42 bits
```

Therefore the raw product register is:

```text
42 bits
```

The design then computes:

```text
rounded_num = product + rounding_bias
```

Adding two non-negative values can generate one carry beyond the most-significant bit of the original 42-bit product. Therefore the conservative addition width is:

```text
42 + 1 = 43 bits
```

The actual project boundary case confirms this is not merely theoretical:

```text
max product = 145161 * 16777215
            = 2435397306615
```

and with the maximum Phase-6 rounding bias for `F = 42`:

```text
2^(42-1) = 2^41
          = 2199023255552
```

then:

```text
rounded maximum = 2435397306615 + 2199023255552
                = 4634420562167
```

which requires the extra carry bit.

### Key revision point

Preserving full intermediate width is essential because the final INT8 result can look correct even when upper arithmetic bits were accidentally lost.

---

## Q7. Why was the pipeline register placed after the DSP and before the rounding carry chain?

The original unpipelined design failed the 100 MHz setup constraint:

```text
WNS = -0.405 ns
TNS = -2.381 ns
```

The critical combinational work included:

```text
DSP multiply -> post-DSP rounding/carry logic -> shift/saturation
```

The chosen refinement splits this into two stages:

```text
Stage 1:
accumulator/sign handling -> DSP multiply -> product register

Stage 2:
rounding -> shift -> saturation -> destination register
```

Placing the register before the DSP would not remove the DSP-plus-rounding combination from the following cycle. Placing the register only after the entire requantization block would also leave the long DSP-plus-rounding path intact.

The DSP output boundary is especially effective because Xilinx DSP48E1 blocks provide a dedicated output pipeline register (`PREG`). This allows the design to register the multiplication result without implementing the 42-bit pipeline state in ordinary slice flip-flops.

### Key revision point

The register was placed where it directly breaks the measured critical path and where the FPGA architecture provides a dedicated low-cost pipeline resource.

---

# Part 4 — FPGA Mapping and Resource Interpretation

## Q8. What do `DSP48E1 = 1`, `PREG = 1`, and `Slice FFs = 26` mean?

The refined synthesis reported:

```text
DSP48E1 = 1
PREG    = 1
Slice FFs = 26
```

### `DSP48E1 = 1`

The multiplier is implemented using one dedicated DSP48E1 block rather than a large LUT-based multiplier.

### `PREG = 1`

`PREG` is the DSP48E1 output pipeline register. `PREG = 1` means the DSP output register is enabled and the multiplication result is registered inside the DSP block.

### Where did the 42-bit `product_reg` go?

Although the RTL contains a logical 42-bit product register, Vivado absorbed that state into the DSP48E1 output register. Therefore those bits are not implemented as 42 ordinary Slice FFs.

### Why are there exactly 26 Slice FFs?

The source accumulator register contributes only the bits that affect the synthesized requantization logic:

```text
accumulator_reg[31]  -> sign/ReLU decision = 1 FF
accumulator_reg[17:0] -> magnitude          = 18 FFs
                                           --------
                                           = 19 FFs
```

Accumulator bits `[30:18]` are optimized away because under the bounded Phase-6 contract they do not affect the useful 18-bit positive magnitude.

The destination activation register only needs:

```text
q_out[6:0] = 7 FFs
```

because after ReLU and saturation:

```text
0 <= q_out <= 127
```

so bit `7` is always `0` and is optimized away.

Therefore:

```text
19 + 7 = 26 Slice FFs
```

The 42-bit DSP product state is not part of this Slice-FF count because it resides in the DSP's dedicated `PREG` resource.

### Key revision point

RTL registers do not necessarily map one-for-one to Slice FFs. Synthesis can move arithmetic pipeline state into dedicated hard-block registers.

---

# Part 5 — Timing Analysis

## Q9. What do `WNS = +3.703 ns`, `TNS = 0`, and `WHS = +0.694 ns` tell us?

The refined routed implementation reports:

```text
WNS = +3.703 ns
TNS = 0.000 ns
WHS = +0.694 ns
THS = 0.000 ns
```

### WNS

Worst setup slack is `+3.703 ns`, so even the worst setup path has positive margin relative to the 10 ns timing requirement.

### TNS

Total negative setup slack is zero, which means there are no setup paths with negative slack.

### WHS

Worst hold slack is `+0.694 ns`, so the worst hold path also has positive timing margin.

At 100 MHz:

```text
Tclk = 1/100 MHz = 10 ns
```

Because all relevant setup and hold timing checks have non-negative slack, the design is proven to meet the 100 MHz constraint for the representative implementation.

However, this does not directly prove a maximum achievable clock frequency. A 100 MHz timing run answers:

```text
Does the implementation meet a 10 ns requirement?
```

It does not automatically answer:

```text
What is the smallest clock period this implementation can meet after place and route?
```

That requires tighter constraints and re-running timing, or an explicit implementation/timing sweep.

### Key revision point

Positive slack proves the design meets the constraint that was analyzed. It does not by itself establish a guaranteed `Fmax`.

---

## Q10. Why is setup slack not simply `10 - 2.781 = 7.219 ns`?

The refined worst path reports approximately:

```text
clock period    = 10.000 ns
data path delay = 2.781 ns
actual slack    = +3.703 ns
```

Static timing analysis uses:

```text
slack = required time - arrival time
```

The required and arrival times include more than just the nominal clock period and combinational data delay. They can include:

- source and destination clock path delays,
- clock skew,
- clock uncertainty,
- destination register setup requirement,
- timing effects internal to hard blocks such as DSP48E1,
- implementation-specific clock/data path adjustments.

Therefore:

```text
10 - 2.781 = 7.219 ns
```

is only the difference between the nominal period and reported data-path delay. It is not the complete setup-slack equation.

The correct value for closure decisions is the full timing-engine result:

```text
+3.703 ns
```

### Key revision point

Never estimate setup slack from only `clock period - data delay` when the timing report already provides the complete required and arrival times.

---

# Part 6 — Verification Reasoning

## Q11. Why is checking only `q_out = 1` insufficient in the maximum-width test?

In the maximum-width case:

```text
accumulator = 145161
M_INT       = 0xFFFFFF = 16777215
F           = 42
```

The final reference output is:

```text
q_out = 1
```

Checking only the final output is weak because a width bug or truncation error in the internal arithmetic could still happen to produce the same final small value after a very large right shift.

Therefore the test also checks:

```text
product_reg = 2435397306615
rounded_num = 4634420562167
```

These values prove that:

- the full 18x24 product was preserved,
- the 42-bit raw product was not truncated,
- the rounding operation used the required wide intermediate,
- the carry into the 43rd bit was preserved,
- the final `q_out = 1` came from the correct full-width computation.

### Key revision point

Final outputs alone can hide internal arithmetic defects. Boundary verification should inspect important internal states where width correctness matters.

---

## Q12. What do the three important Python results verify, and why must the Python model be independent of the RTL?

### Result 1: `145161`

This verifies the integer convolution/reference arithmetic for the maximum present 3x3 case:

```text
9*127*127 = 145161
```

It checks that the software-side convolution/range model matches the hand-derived accumulator bound.

### Result 2: `M_INT = 13421773`, `F = 27`

For the representative real multiplier:

```text
M = 0.1
```

parameter generation selects:

```text
M_INT = 13421773
F     = 27
```

because:

```text
round(0.1*2^27) = 13421773
```

while the next candidate would be:

```text
round(0.1*2^28) = 26843546
```

which exceeds the unsigned 24-bit maximum:

```text
2^24 - 1 = 16777215
```

Therefore this result verifies fixed-point requantization parameter generation and the coefficient-width constraint.

### Result 3: BRAM words

For input bytes:

```text
[1, -1, 2, -2, 3, -3, 4, -4, 5]
```

packing four INT8 values per 32-bit word with lane 0 in bits `[7:0]` produces:

```text
0xFE02FF01
0xFC04FD03
0x00000005
```

These words verify the BRAM packing contract:

```text
lane 0 -> bits [7:0]
lane 1 -> bits [15:8]
lane 2 -> bits [23:16]
lane 3 -> bits [31:24]
```

They also verify:

- negative INT8 values are stored using their normal 8-bit two's-complement byte representation,
- the final unused lanes are zero-padded.

For example:

```text
[1, -1, 2, -2]
 -> bytes [01, FF, 02, FE]
 -> 32-bit word 0xFE02FF01
```

### Why must Python be independent of the RTL?

Verification requires two independently derived views of the specification:

```text
mathematical specification
        |
        +--> independent Python reference --> expected result
        |
        +--> RTL implementation            --> actual result
```

If the RTL generated its own expected values, the same implementation bug could appear in both the design and the supposed reference result. That would create a circular test and false confidence.

An independent Python model instead derives results from the mathematical contract, so agreement between Python and RTL is meaningful evidence of correctness.

### Key revision point

A reference model is valuable only when it is independently derived from the specification rather than copied from the implementation under test.

---

# Part 7 — Measured Phase-6 Hardware Results to Remember

## Baseline combinational implementation

Representative parameters:

```text
M_INT = 13421773
F     = 27
```

Baseline resources:

```text
LUTs      = 37
Slice FFs = 39
CARRY4    = 5
DSP48E1   = 1
BRAM      = 0
PREG      = 0
```

Baseline routed timing:

```text
WNS = -0.405 ns
TNS = -2.381 ns
setup failing endpoints = 7/7
WHS = +0.795 ns
hold failing endpoints = 0
```

Conclusion: functionality was correct, but the representative unpipelined design did not meet the 100 MHz setup constraint.

## Refined pipelined implementation

Refined resources:

```text
LUTs      = 27
Slice FFs = 26
CARRY4    = 5
DSP48E1   = 1
BRAM      = 0
PREG      = 1
```

Refined routed timing:

```text
WNS = +3.703 ns
TNS = 0.000 ns
WHS = +0.694 ns
THS = 0.000 ns
```

Improvement in WNS:

```text
+3.703 - (-0.405) = +4.108 ns
```

Conclusion: the DSP output pipeline successfully separated the multiply from the post-DSP rounding/carry logic and closed 100 MHz timing for the representative configuration.

---

# Part 8 — Python Verification Results to Remember

The corrective Python verification completed:

```text
34 directed checks
0 failures
```

Important verified behaviors:

```text
symmetric scale derivation
all-zero scale handling
ReLU output scale derivation
ties-away-from-zero input rounding
clipping to [-127,+127]
maximum 3x3 integer convolution = 145161
M=0.1 -> M_INT=13421773, F=27
F=28 coefficient does not fit 24 bits
BRAM packing = FE02FF01 / FC04FD03 / 00000005
representative requantize_relu() outputs
maximum-width requantization reference
```

---

# Part 9 — Interview-Level Summary

A concise explanation of the completed Phase-6 architecture is:

> Floating-point activations and weights are converted to symmetric INT8 using explicit scales. Integer MAC accumulation has scale `S_a*S_w`. The accumulator is converted to the output INT8 scale using a fixed-point multiplier `M_INT/2^F`, positive round-to-nearest, ReLU, and saturation. The maximum present 3x3 accumulation is `145161`, so an 18-bit positive magnitude is sufficient after ReLU. The 18x24 fixed-point multiply requires a 42-bit product and the rounding operation uses a 43-bit intermediate. The original DSP-plus-rounding path failed 100 MHz timing, so the product was registered in the DSP48E1 `PREG`, separating the multiply and rounding stages. This reduced fabric resources and changed routed setup slack from `-0.405 ns` to `+3.703 ns`. Python verification independently confirms quantization, parameter generation, convolution arithmetic, BRAM packing, and requantization behavior.

---

# Part 10 — Remaining Integration Follow-Up

The only carried-forward Phase-6 review item is the integrated latency measurement.

Current accepted statement:

```text
70 ns external start-to-done latency = architecturally derived
```

Not yet accepted as a fresh post-refinement measurement:

```text
70 ns external start-to-done latency = measured after full pipeline integration
```

This should be re-measured when the following are integrated together:

```text
full compute engine
+ controller FSM
+ pipelined requantizer
```

This follow-up does not reopen the completed Phase-6 INT8 quantization module.

---

# Final Revision Checklist

Before an interview or future project review, make sure you can derive or explain without memorization:

1. `S = max(|x|)/127`.
2. `S_acc = S_a*S_w`.
3. `9*127*127 = 145161`.
4. Why 18 unsigned magnitude bits are sufficient after ReLU.
5. `M = S_acc/S_out`.
6. Why `M ~= M_INT/2^F` enables integer-only hardware.
7. Why `2^(F-1)` implements positive round-to-nearest before the right shift.
8. Why `18 x 24 -> 42` product bits and why rounding uses 43 bits.
9. Why the best pipeline boundary was after the DSP.
10. What `PREG = 1` means physically.
11. Why the refined design uses exactly 26 Slice FFs.
12. Why positive routed slack proves 100 MHz closure but not a guaranteed `Fmax`.
13. Why setup slack is not simply `clock period - data path delay`.
14. Why internal maximum-width signals must be checked during verification.
15. Why Python verification must be independent of RTL.
16. How the BRAM words `FE02FF01`, `FC04FD03`, `00000005` encode lane order, signed bytes, and zero padding.
