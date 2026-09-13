# INT8 Quantization — Behavioral Simulation Results

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 8 — SIMULATION / FUNCTIONAL MEASUREMENT  
**Status:** Behavioral XSim functional verification PASSED; synthesis/resource/timing measurement still pending

## 1. Evidence supplied

The Vivado 2018.2 XSim log shows successful compile, elaboration, and behavioral simulation of:

```text
rtl/activation/requantize_relu.v
tb/unit/tb_requantize_relu.v
```

The simulation testbench top was:

```text
tb_requantize_relu
```

The simulator reached the testbench `$finish` at:

```text
23 ns
```

with:

```text
TB_REQUANTIZE_RELU_PASS: all directed checks passed
```

The GUI screenshot at 23,000 ps also shows:

```text
failures              = 0
acc_identity          = 0x00000080 = 128
q_identity            = 0x7F       = 127
acc_half              = 0x00000003 = 3
q_half                = 0x02       = 2
acc_three_quarters    = 0x000000AA = 170
q_three_quarters      = 0x7F       = 127
acc_max               = 0x00023709 = 145161
q_max                 = 0x01       = 1
```

These visible values agree with the final directed vectors in each parameterized DUT configuration.

## 2. Compile and elaboration result

XSim successfully analyzed both Verilog sources and elaborated four specialized `requantize_relu` instances corresponding to the four parameter configurations.

This matters because `M_INT` and `FRAC_BITS` are elaboration-time parameters. The elaborator therefore had to construct distinct hardware models for the identity, one-half, three-quarter, and maximum-width configurations before simulation could begin.

No compile or elaboration error occurred in the DUT or testbench.

## 3. Configuration A — identity scaling / ReLU / saturation

Parameters:

```text
M_INT = 1
FRAC_BITS = 0
```

For positive inputs:

```text
product = acc_mag
q_pre   = product
```

### `acc = -1 -> q = 0`

Signal reasoning:

```text
acc_in[31] = 1
acc_positive = 0
acc_mag = 0
q_out = 0
```

The PASS proves the negative input is blocked by the ReLU/sign path before multiplication can contribute to the output.

### `acc = 0 -> q = 0`

Signal reasoning:

```text
|acc_in| = 0
acc_positive = 0
acc_mag = 0
q_out = 0
```

This separately verifies zero handling rather than relying only on the negative case.

### `acc = 1 -> q = 1`

Signal reasoning:

```text
acc_positive = 1
acc_mag = 1
product = 1
q_pre = 1
q_pre[42:7] = 0
q_out = 1
```

This proves a small legal positive code passes through without accidental zeroing or saturation.

### `acc = 126 -> q = 126`

The unsaturated positive path remains intact immediately below the INT8 positive boundary.

### `acc = 127 -> q = 127`

This proves the exact highest legal positive signed-INT8 activation is preserved.

### `acc = 128 -> q = 127`

Before saturation:

```text
q_pre = 128
```

so bit 7 is set. The saturation reduction therefore detects an out-of-range positive value and forces:

```text
q_out = 127
```

The GUI screenshot shows this final vector directly:

```text
acc_identity = 0x00000080
q_identity   = 0x7F
```

### `acc = 145161 -> q = 127`

This is the maximum legal positive accumulator magnitude for the current 3×3, one-channel, `[-127,+127]` generated-data contract.

With identity scaling the pre-saturation result is far above 127, so the correct final result is 127. Passing this case proves the maximum legal positive magnitude is not misinterpreted as negative and reaches the saturation path correctly.

The testbench also reported:

```text
PASS identity internal negative-path check
PASS identity internal saturation-path check
```

so this configuration is not accepted solely from final outputs; the relevant internal path behavior was also checked.

## 4. Configuration B — positive round-to-nearest, M = 1/2

Parameters:

```text
M_INT = 1
FRAC_BITS = 1
rounding_bias = 2^(1-1) = 1
```

For positive inputs:

```text
q_pre = (acc + 1) >> 1
```

Measured directed results:

```text
acc = 1 -> q = 1
acc = 2 -> q = 1
acc = 3 -> q = 2
acc = 4 -> q = 2
```

Signal-by-signal derivation:

```text
acc=1: product=1, rounded=2, 2>>1=1
acc=2: product=2, rounded=3, 3>>1=1
acc=3: product=3, rounded=4, 4>>1=2
acc=4: product=4, rounded=5, 5>>1=2
```

The two half-step values are especially important:

```text
0.5 -> 1
1.5 -> 2
```

which confirms the selected positive round-to-nearest rule.

The testbench additionally reported:

```text
PASS half internal rounding-path check
```

The GUI screenshot shows the final half-scale vector:

```text
acc_half = 3
q_half   = 2
```

which matches the derived rounded result.

## 5. Configuration C — non-power-of-two multiplier, M = 3/4

Parameters:

```text
M_INT = 3
FRAC_BITS = 2
rounding_bias = 2
```

The effective fixed-point multiplier is:

```text
M_hat = 3 / 4 = 0.75
```

Measured directed results:

```text
acc = 1   -> q = 1
acc = 2   -> q = 2
acc = 3   -> q = 2
acc = 5   -> q = 4
acc = 169 -> q = 127
acc = 170 -> q = 127
```

The first four cases prove the datapath performs an actual multiply by 3 followed by a rounded right shift rather than behaving as a simple power-of-two shifter.

Their arithmetic is:

```text
acc=1:   product=3,  rounded=5,  5>>2  = 1
acc=2:   product=6,  rounded=8,  8>>2  = 2
acc=3:   product=9,  rounded=11, 11>>2 = 2
acc=5:   product=15, rounded=17, 17>>2 = 4
```

### Saturation threshold pair: 169 and 170

For `acc = 169`:

```text
product = 169 * 3 = 507
rounded = 507 + 2 = 509
q_pre   = 509 >> 2 = 127
```

So 127 is reached naturally and must remain 127 without saturation changing it.

For `acc = 170`:

```text
product = 170 * 3 = 510
rounded = 510 + 2 = 512
q_pre   = 512 >> 2 = 128
```

Now the value is outside the positive INT8 range, so saturation must force:

```text
q_out = 127
```

Both final outputs are 127, but they prove different paths: `169` proves the exact legal boundary, while `170` proves the first overflowing code is saturated.

The log reports:

```text
PASS 3/4 internal saturation-threshold check
```

and the GUI screenshot shows the final threshold-overflow vector:

```text
acc_three_quarters = 0xAA = 170
q_three_quarters   = 0x7F = 127
```

## 6. Configuration D — maximum-width arithmetic

Parameters and input:

```text
acc       = 145161
M_INT     = 16777215
FRAC_BITS = 42
```

### Sign gate

Measured:

```text
acc_positive = 1
```

This is correct because `145161` is positive and nonzero.

### 18-bit magnitude

Measured:

```text
acc_mag = 145161
```

This proves the full legal accumulator magnitude survives the post-ReLU 18-bit extraction without truncation.

### 42-bit product

Expected and observed:

```text
145161 * 16777215
= 2435397306615
```

The testbench reported:

```text
PASS max: 42-bit product = 2435397306615
```

Because this value is greater than `2^41` but less than `2^42`, its correct observation demonstrates that the product datapath preserved the full derived 42-bit width.

### 43-bit rounded intermediate

For `FRAC_BITS = 42`:

```text
rounding_bias = 2^41
              = 2199023255552
```

Therefore:

```text
rounded_num
= 2435397306615 + 2199023255552
= 4634420562167
```

The testbench reported exactly:

```text
PASS max: 43-bit rounded_num = 4634420562167
```

This proves the carry-capable 43-bit rounding path is preserved.

### Shifted pre-saturation value

Measured:

```text
q_pre = 4634420562167 >> 42
      = 1
```

The testbench reported:

```text
PASS max: q_pre = 1 after >> 42
```

### Final output

Since `q_pre = 1` is inside `[0,127]`, saturation must not modify it:

```text
q_out = 1
```

The testbench reported:

```text
PASS max: q_out = 1
```

and the GUI screenshot shows:

```text
acc_max = 0x00023709 = 145161
q_max   = 0x01       = 1
```

This case is especially strong because both internal wide values and the final compressed output were checked. Therefore a width/truncation error cannot be hidden merely because the final result happens to be small.

## 7. Failure counter and unknown-state evidence

The final GUI state shows:

```text
failures = 0
```

The testbench was written so failed comparisons increment this counter, and case-inequality checks make `X`/`Z` values fail rather than silently compare as equal.

Therefore the observed all-pass result means none of the directed checks encountered a mismatching or unknown final value under the tested legal inputs and parameter sets.

## 8. Webtalk path warning

The log contains:

```text
source C:/Users/UMA -notrace
couldn't read file "C:/Users/UMA": no such file or directory
```

This occurs in the Webtalk portion because the Windows user path contains a space (`UMA SHANKAR`). It did not stop XSim compilation, elaboration, or behavioral execution. XSim proceeded to run the complete testbench and reached `$finish` with zero failures.

This warning therefore does not invalidate the functional simulation result shown here.

## 9. Functional verification conclusion

Behavioral verification of `requantize_relu.v` PASSED for the directed cases defined in the verification plan.

The simulation provides evidence for:

```text
negative ReLU behavior
zero handling
positive pass-through
INT8 positive boundary preservation
saturation immediately above 127
maximum legal accumulator handling
positive round-to-nearest behavior
non-power-of-two requantization
saturation-threshold transition
18-bit accumulator magnitude preservation
42-bit multiplication width
43-bit rounding width
maximum FRAC_BITS shift behavior
absence of directed-check mismatches
```

## 10. What is not yet measured

This behavioral PASS does **not** measure or prove:

```text
DSP48E1 count
LUT count
FF count
critical-path delay
WNS / TNS
100 MHz timing closure
post-route timing
power
```

Those quantities were predicted during `/analyze int8_quantization` and still require synthesis/implementation reports before the measured-vs-predicted analysis can be completed.

Therefore Step 8 is complete for **functional behavioral simulation**, but the hardware resource/timing measurement portion remains pending.
