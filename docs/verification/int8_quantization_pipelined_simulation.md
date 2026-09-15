# INT8 Quantization — Pipelined Requantizer Behavioral Simulation

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** TIMING-REFINEMENT FUNCTIONAL SIMULATION  
**Status:** PASS

## 1. Assumptions

- Simulator: Vivado XSim 2018.2.
- DUT: `rtl/activation/requantize_relu_pipelined.v`.
- Testbench: `tb/unit/tb_requantize_relu_pipelined.v`.
- Simulation top: `tb_requantize_relu_pipelined`.
- Testbench clock period: 10 ns, corresponding to 100 MHz.
- Reset is synchronous and active high.
- Inputs are driven before the rising edge that captures `product_reg`.
- The `#1` delay after a rising edge is used only as a post-edge settle delay so nonblocking register updates and Stage-2 combinational logic have time to settle in simulation.

## 2. Compile and Elaboration Result

XSim successfully analyzed:

```text
requantize_relu_pipelined.v
tb_requantize_relu_pipelined.v
```

and successfully built the simulation snapshot:

```text
tb_requantize_relu_pipelined_behav
```

No compile or elaboration error prevented simulation.

A Webtalk path warning was observed:

```text
source C:/Users/UMA -notrace
couldn't read file "C:/Users/UMA"
```

The local project path contains a space in `UMA SHANKAR`. This warning occurred in the Webtalk/telemetry stage and did not prevent XSim from compiling, elaborating, running the DUT, or completing the directed tests.

## 3. Reset Verification

The first test asserts synchronous reset across a rising edge.

Measured result:

```text
PASS reset: all product registers and outputs are zero
```

Why this passes:

- `rst=1` is present at the active clock edge.
- Each DUT executes its synchronous reset branch.
- Each `product_reg` becomes 42'd0.
- Stage 2 receives a zero registered product.
- Rounding/shift logic therefore produces zero.
- `q_out` is zero for every parameter instance.

This confirms deterministic pipeline initialization.

## 4. Identity / ReLU / Saturation Verification

Configuration:

```text
M_INT = 1
FRAC_BITS = 0
```

Measured directed results:

```text
-1      -> product=0      -> q=0
0       -> product=0      -> q=0
1       -> product=1      -> q=1
126     -> product=126    -> q=126
127     -> product=127    -> q=127
128     -> product=128    -> q=127
145161  -> product=145161 -> q=127
```

Signal-by-signal interpretation:

- Negative `acc_in` fails the positive/ReLU gate, so `acc_mag=0`; after the capture edge, `product_reg=0`; Stage 2 therefore outputs zero.
- Zero also produces `acc_mag=0`, so the same zero path is exercised.
- Positive values 1, 126, and 127 pass through the identity multiplier exactly because `M_INT=1` and `FRAC_BITS=0`.
- At 128, the registered product is correctly 128, but `q_pre_wide[7]` is set, so output saturation clamps the final signed-INT8 activation to 127.
- At 145161, the exact registered product is preserved and the same saturation rule clamps the output to 127.

The explicit internal saturation checkpoint also passes.

## 5. Positive Round-to-Nearest Verification

Configuration:

```text
M_INT = 1
FRAC_BITS = 1
```

Measured results:

```text
1 -> product=1 -> q=1
2 -> product=2 -> q=1
3 -> product=3 -> q=2
4 -> product=4 -> q=2
```

For the half-step case `acc=3`:

```text
product_reg = 3
rounding bias = 1
rounded_num = 4
q_pre_wide = 4 >> 1 = 2
q_out = 2
```

The internal rounding-path check passes, confirming that moving the multiplier result behind a register did not change the arithmetic rule.

## 6. Non-Power-of-Two Multiplier Verification

Configuration:

```text
M_INT = 3
FRAC_BITS = 2
```

Measured results:

```text
1   -> product=3   -> q=1
2   -> product=6   -> q=2
3   -> product=9   -> q=2
5   -> product=15  -> q=4
169 -> product=507 -> q=127
170 -> product=510 -> q=127
```

The two 127 cases prove two different internal paths.

For `acc=169`:

```text
product_reg = 507
rounded_num = 507 + 2 = 509
q_pre_wide  = 509 >> 2 = 127
q_out       = 127
```

This is a natural 127 result and does not require saturation.

For `acc=170`:

```text
product_reg = 510
rounded_num = 510 + 2 = 512
q_pre_wide  = 512 >> 2 = 128
q_out       = 127
```

This result reaches 128 internally and is then correctly saturated to 127.

Both internal checks pass, so identical final outputs are not hiding a broken saturation boundary.

## 7. Maximum-Width Arithmetic Verification

Configuration:

```text
M_INT = 0xFFFFFF = 16777215
FRAC_BITS = 42
acc_in = 145161
```

Measured Stage-1 product:

```text
product_reg = 2435397306615
```

Derived from:

```text
145161 * 16777215 = 2435397306615
```

Measured Stage-2 rounded numerator:

```text
rounded_num = 4634420562167
```

because:

```text
2^41 = 2199023255552
2435397306615 + 2199023255552 = 4634420562167
```

Then:

```text
q_pre_wide = 1
q_out = 1
```

All maximum-width checks pass. This is important because a correct final INT8 output alone could otherwise hide truncation at the 42-bit pipeline boundary.

## 8. Back-to-Back Pipeline Sequencing

The testbench applies three different accumulators on consecutive cycles with no empty rising edge between samples:

```text
acc=1
acc=3
acc=5
```

For `M_INT=3`, `FRAC_BITS=2`, the measured corresponding outputs are:

```text
acc=1 -> product_reg=3  -> q=1
acc=3 -> product_reg=9  -> q=2
acc=5 -> product_reg=15 -> q=4
```

All three checks pass.

Why this matters:

- arithmetic correctness alone would not detect a one-cycle association error;
- the registered product changes to the exact product of the sample presented before that edge;
- the output after the edge corresponds to the same registered product;
- no input sample is reordered, duplicated, or dropped.

Therefore the single-stage pipeline sequencing is functionally correct for consecutive samples.

## 9. Final Testbench Result

XSim reports:

```text
TB_REQUANTIZE_RELU_PIPELINED_PASS: all directed checks passed
```

and simulation finishes at:

```text
236 ns
```

with the testbench failure counter equal to zero.

The final waveform values shown at the end are consistent with the final exercised cases:

```text
q_identity        = 0x7F = 127
q_half            = 0x02 = 2
q_three_quarters  = 0x04 = 4
q_max             = 0x01 = 1
failures          = 0
```

## 10. Verification Verdict

The timing-refined `requantize_relu_pipelined` passes behavioral verification for:

```text
synchronous reset
ReLU / non-positive handling
identity scaling
INT8 saturation
round-to-nearest
non-power-of-two scaling
saturation threshold distinction
full 42-bit product preservation
43-bit rounded arithmetic
back-to-back pipeline sequencing
```

Therefore:

```text
functional arithmetic correctness : PASS
pipeline cycle association         : PASS
behavioral verification            : PASS
```

## 11. What This Does Not Prove

This behavioral simulation does not prove physical timing closure.

It does not establish:

```text
DSP48E1 PREG inference
post-synthesis LUT/FF/DSP usage
post-route WNS/TNS
hold slack after redesign
100 MHz timing closure
```

Those must be measured with a fresh synthesis and implementation of the updated `requantize_timing_wrapper`.

## 12. Current Phase-6 Timing-Refinement Status

```text
Timing failure characterization          : COMPLETE
Pipeline split derivation                : COMPLETE
Timing-refinement RTL                    : COMPLETE
Clocked verification plan                : COMPLETE
Clocked testbench                        : COMPLETE
Behavioral XSim simulation               : COMPLETE / PASS
Refined synthesis/resource measurement   : NEXT
Refined post-route timing measurement    : PENDING
100 MHz timing closure                   : NOT YET CLAIMED
```
