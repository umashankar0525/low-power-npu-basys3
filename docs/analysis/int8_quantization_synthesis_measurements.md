# INT8 Quantization — Synthesis Measurements

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — MEASURED VS PREDICTED, SYNTHESIS RESOURCE SUBSTAGE  
**Status:** Synthesis resource measurements recorded; post-route timing still pending

## 1. Measurement Context

Vivado 2018.2 synthesized `requantize_timing_wrapper` for:

```text
Device: XC7A35T-1CPG236C
M_INT = 13,421,773 = 24'hCCCCCD
FRAC_BITS = 27
Target clock = 100 MHz
Clock period = 10 ns
```

The synthesis log shows that Vivado parsed:

```text
requantize_timing_wrapper.xdc
```

for this run. No second clock-creation XDC is shown in the constraint-processing section.

Synthesis completed with:

```text
0 errors
0 critical warnings
1 warning
```

The single warning removes `output_activation_reg[7]` because that bit is constant zero after ReLU/saturation.

## 2. Measured Top-Level Utilization

The synthesis utilization report gives:

```text
Slice LUTs      = 37
Slice Registers = 39
DSP48E1         = 1
Block RAM       = 0
Bonded IOB      = 42
BUFG            = 1
```

Device utilization is therefore:

```text
LUT  : 37 / 20800 = 0.18%
FF   : 39 / 41600 = 0.09%
DSP  : 1 / 90     = 1.11%
BRAM : 0
```

The IOB and BUFG counts belong to the standalone measurement wrapper and are not representative of the final internal NPU integration.

## 3. Separating Wrapper Resources From Requantization Resources

The top-level primitive counts are:

```text
FDRE    = 39
IBUF    = 34
OBUF    = 8
BUFG    = 1
LUTs    = 37 total
CARRY4  = 5
DSP48E1 = 1
```

The synthesis report also states:

```text
Instance u_requantize : 43 cells
```

Now count the arithmetic cells:

```text
37 LUTs + 5 CARRY4 + 1 DSP48E1 = 43 cells
```

That exactly matches the reported `u_requantize` instance size.

Therefore the synthesized arithmetic DUT accounts for:

```text
requantize_relu:
  LUTs    = 37
  CARRY4  = 5
  DSP48E1 = 1
  FFs     = 0 internal
  BRAM    = 0
```

The wrapper accounts for the clocked and I/O scaffolding.

This directly confirms the earlier architectural statement that baseline `requantize_relu` is combinational and contains no internal pipeline registers.

## 4. Why the Wrapper Has 39 FFs Instead of the Naive 40

Before synthesis, the wrapper contains:

```text
32-bit accumulator launch register
8-bit output capture register
```

so the structural count appears to be:

```text
32 + 8 = 40 FFs
```

However, after ReLU the valid output range is:

```text
0 ... 127
```

An 8-bit signed representation of every value in that range has:

```text
bit[7] = 0
```

Vivado therefore propagated constant zero through `output_activation_reg[7]` and removed that sequential element.

Hence:

```text
32 launch FFs + 7 physically necessary output FFs = 39 FFs
```

This optimization is expected and does not indicate a missing functional output bit.

## 5. DSP Prediction Versus Measurement

### Prediction

The pre-synthesis analysis predicted:

```text
optimized target             = 1 DSP48E1
conservative direct mapping  = 1 to 2 DSP48E1
```

The uncertainty came from the unsigned 18-bit accumulator magnitude. A native signed 18-bit DSP input only reaches +131071, while the architectural legal magnitude can reach 145161.

The predicted one-DSP workaround decomposed the magnitude as:

```text
acc_mag = acc_low17 + acc_bit17 * 2^17
```

so:

```text
acc_mag * M_INT
= acc_low17 * M_INT
+ acc_bit17 * (M_INT << 17)
```

The first multiplication fits a positive 17-bit value on the DSP multiplier input; the top bit can become a conditional correction term.

### Measured

Vivado inferred exactly:

```text
DSP48E1 = 1
```

and reported the DSP operation as:

```text
C + (A:0xCCCCCD) * B
A Size = 24
B Size = 17
C Size = 41
P Size = 42
```

with no DSP pipeline registers:

```text
AREG = 0
BREG = 0
MREG = 0
PREG = 0
```

The measured 17-bit `B` multiplier operand plus a `C` correction term is strongly consistent with the earlier predicted decomposition of the 18-bit unsigned magnitude into a 17-bit multiplication plus a correction for the top bit.

The report by itself does not expose every Boolean detail of the correction path, so this is recorded as a mapping interpretation rather than a formal proof of the exact decomposition netlist.

### Comparison

```text
Prediction: 1 to 2 DSP48E1, optimized target 1
Measured:   1 DSP48E1
Result:     OPTIMIZED TARGET CONFIRMED
```

## 6. LUT Prediction Versus Measurement

### Prediction

Two pre-synthesis cases were estimated:

```text
DSP/post-adder optimized case : about 15 to 35 LUTs
fabric wide-adder case        : about 60 to 80 LUTs
```

### Measured

The arithmetic instance uses:

```text
37 LUTs
5 CARRY4
1 DSP48E1
```

### Comparison

The measured 37 LUTs are only two LUTs above the predicted 15–35 low-resource range and are far below the 60–80 LUT fabric-adder estimate.

Therefore the qualitative prediction was correct: Vivado did not leave the entire wide requantization operation as a large fabric implementation. The exact low-range estimate was slightly optimistic.

```text
Low-case predicted upper bound = 35 LUTs
Measured                       = 37 LUTs
Difference                     = +2 LUTs
```

The five `CARRY4` primitives show that some arithmetic/correction logic remains in FPGA carry-chain fabric even though the principal multiply/add operation is mapped into one DSP48E1.

## 7. Why Synthesis Reports a 42-Bit Adder Although RTL Uses a 43-Bit Conservative Intermediate

The generic RTL intentionally declares a 43-bit `rounded_num` to guarantee that a 42-bit product plus rounding bias cannot overflow for the full supported parameter envelope.

For this specific measurement configuration:

```text
M_INT = 13,421,773
FRAC_BITS = 27
rounding bias = 2^(27-1) = 2^26 = 67,108,864
```

Synthesis only needs to consider the 18-bit `acc_mag` signal itself, whose absolute unsigned maximum is:

```text
2^18 - 1 = 262143
```

The largest product possible for this fixed coefficient is:

```text
262143 * 13,421,773
= 3,518,423,839,539
```

After adding the rounding bias:

```text
3,518,423,839,539 + 67,108,864
= 3,518,490,948,403
```

Compare with:

```text
2^42 = 4,398,046,511,104
```

Since:

```text
3,518,490,948,403 < 2^42
```

the 43rd bit can never become one for this fixed parameter set. Vivado can therefore optimize the effective addition to 42 bits without changing behavior.

This does not invalidate the generic 43-bit RTL choice. The 43-bit width remains a safe architecture-level width for the broader legal parameter space, including the maximum-width test case.

## 8. BRAM Prediction Versus Measurement

Prediction:

```text
requantization itself requires 0 BRAM
```

Measured:

```text
Block RAM Tile = 0
RAMB36/FIFO    = 0
RAMB18         = 0
```

Result:

```text
CONFIRMED
```

## 9. I/O Count Is a Measurement-Wrapper Artifact

The synthesis report shows:

```text
Bonded IOB = 42
```

This follows directly from the standalone wrapper ports:

```text
clk               = 1
rst               = 1
accumulator_input = 32
output_activation = 8
----------------------
total             = 42
```

These IOBs must not be interpreted as the I/O cost of integrating `requantize_relu` inside the NPU, where these signals are internal nets rather than package pins.

## 10. Timing Status

The synthesis run successfully processed the 10 ns clock constraint, but the supplied report does not contain a `report_timing_summary` with WNS/TNS.

Therefore the following cannot yet be claimed:

```text
100 MHz timing closure
WNS >= 0
TNS = 0
critical-path delay
critical-path startpoint
critical-path endpoint
hold timing closure
```

The next required physical measurement is post-implementation timing.

The strongest evidence should come after placement and routing because routing delay is then included.

## 11. Measured Versus Predicted Resource Table

| Item | Prediction | Synthesis measurement | Result |
|---|---|---|---|
| DSP48E1 | 1 optimized target; 1–2 conservative | 1 | Optimized target confirmed |
| Requantization LUTs | ~15–35 low case; ~60–80 fabric-heavy case | 37 | Close to low case; low estimate +2 LUT |
| Internal requantization FFs | 0 baseline | 0 | Confirmed |
| Wrapper FFs | 40 structurally before optimization | 39 | 1 constant output bit removed |
| BRAM | 0 | 0 | Confirmed |
| CARRY4 | Not separately predicted | 5 | Measured |
| DSP pipeline regs | None in baseline | AREG/BREG/MREG/PREG all 0 | Confirmed |
| 100 MHz timing closure | Plausible, unproven | Not yet measured | Pending implementation |

## 12. Step 9 Status After Synthesis

The physical resource portion of Step 9 is now substantially measured:

```text
DSP count          : measured = 1
LUT count          : measured = 37 in u_requantize
internal FF count  : measured = 0
wrapper FF count   : measured = 39
BRAM               : measured = 0
carry-chain usage  : measured = 5 CARRY4
```

The remaining hard requirement before Step 9 can be closed is implemented timing:

```text
post-route WNS
post-route TNS
critical-path startpoint
critical-path endpoint
DSP involvement in critical path
setup pass/fail at 10 ns
hold pass/fail
```

Therefore:

**STEP 9 STATUS: IN PROGRESS — SYNTHESIS RESOURCE SUBSTAGE COMPLETE, POST-ROUTE TIMING PENDING.**
