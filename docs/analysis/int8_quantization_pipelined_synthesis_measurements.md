# INT8 Quantization — Pipelined Synthesis Measurements

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 — TIMING-REFINEMENT SYNTHESIS RESOURCE MEASUREMENT  
**Status:** refined synthesis complete; post-route timing pending

## 1. Assumptions

- Vivado version: 2018.2.
- Device: XC7A35T-1CPG236C.
- Top: `requantize_timing_wrapper`.
- Refined DUT: `requantize_relu_pipelined`.
- Representative parameters: `M_INT = 13,421,773 = 24'hCCCCCD`, `FRAC_BITS = 27`.
- Active timing constraint: 100 MHz, 10 ns period.
- The supplied report is post-synthesis, not post-route timing.

## 2. Measured Utilization

The refined synthesized top reports:

```text
Slice LUTs      = 27
Slice Registers = 26
DSP48E1         = 1
CARRY4          = 5
Block RAM       = 0
Bonded IOB      = 29
BUFG            = 1
```

Device utilization:

```text
LUT  = 27 / 20800 = 0.13%
FF   = 26 / 41600 = 0.06%
DSP  = 1 / 90     = 1.11%
BRAM = 0
```

Synthesis completed with 0 errors and 0 critical warnings.

## 3. DSP Output Register Inference

The central refinement goal was to place the 42-bit product pipeline register directly at the DSP output and allow Vivado to absorb it into DSP48E1 PREG.

The synthesis report explicitly states:

```text
register u_requantize/product_reg_reg is absorbed into DSP u_requantize/product_reg_reg
operator u_requantize/product_next is absorbed into DSP u_requantize/product_reg_reg
```

The DSP mapping report gives:

```text
A Size = 24
B Size = 17
C Size = 41
P Size = 42
AREG = 0
BREG = 0
MREG = 0
PREG = 1
```

Therefore the timing-refinement register was successfully implemented as the DSP48E1 output register rather than as 42 slice flip-flops.

This is a direct confirmation of the intended structural refinement.

## 4. Why Slice FF Usage Is Only 26

At RTL level the wrapper structurally contains:

```text
32-bit accumulator launch register
42-bit product pipeline register
8-bit activation capture register
```

A naive total would therefore be 82 registered bits.

However, the 42-bit product register is absorbed into the DSP48E1 PREG and does not appear as slice FFs.

Vivado also removes `accumulator_reg[30:18]`, thirteen bits in total. The remaining accumulator bits that can affect the datapath are:

```text
bit 31      : sign
bits 17:0   : supported magnitude
```

so the wrapper retains 19 accumulator FFs.

Vivado also removes `output_activation_reg[7]` because the ReLU/saturated output range is 0..127, making bit 7 permanently zero.

Hence the measured slice-register count is exactly:

```text
19 accumulator FFs + 7 output FFs = 26 slice FFs
```

The 42-bit product state still exists physically, but inside the DSP48E1 PREG.

## 5. Why Accumulator Bits 30:18 Are Functionally Redundant

The RTL computes:

```text
acc_positive = (~acc_in[31]) && (|acc_in)
acc_mag      = acc_positive ? acc_in[17:0] : 18'd0
```

For a non-negative value, if `acc_in[17:0]` is nonzero, the reduction-OR is already true and the selected magnitude is exactly those low 18 bits. If `acc_in[17:0]` is zero, the selected magnitude is zero regardless of whether any of bits 30:18 are set.

Therefore bits 30:18 cannot change `acc_mag`, so synthesis can remove their launch registers. This optimization is consistent with the bounded Phase-6 numerical contract.

## 6. Baseline Versus Refined Synthesis

The previous unpipelined measurement was:

```text
LUTs        = 37
Slice FFs   = 39
DSP48E1     = 1
CARRY4      = 5
DSP PREG    = 0
```

The refined measurement is:

```text
LUTs        = 27
Slice FFs   = 26
DSP48E1     = 1
CARRY4      = 5
DSP PREG    = 1
```

Differences:

```text
LUT reduction = 37 - 27 = 10 LUTs
Slice FF reduction = 39 - 26 = 13 FFs
DSP count change = 0
CARRY4 change = 0
PREG changes from 0 to 1
```

The key architectural result is not the LUT/FF reduction itself; it is that the new pipeline boundary was absorbed into the existing DSP without increasing DSP count.

## 7. DUT Cell Accounting

The refined `u_requantize` instance contains 33 cells.

Arithmetic primitive count is:

```text
27 LUTs + 5 CARRY4 + 1 DSP48E1 = 33 cells
```

This exactly matches the reported instance size, so the refined arithmetic DUT resource accounting is:

```text
LUTs    = 27
CARRY4  = 5
DSP48E1 = 1, with PREG=1
BRAM    = 0
```

The DSP-internal PREG is not counted among slice registers.

## 8. I/O Reduction

Bonded IOB usage drops from the previous 42 to 29 because thirteen unused accumulator input bits are removed from the implemented logic.

The retained top-level I/O count is:

```text
clk                 = 1
rst                 = 1
used accumulator    = 19
output_activation   = 8
-------------------------
total               = 29
```

This is a measurement-wrapper artifact and not a final NPU package-I/O requirement.

## 9. Warning Interpretation

The fourteen synthesis warnings are accounted for by:

```text
13 unused accumulator register bits: [30:18]
1 constant output register bit: output_activation_reg[7]
```

These are expected optimization warnings, not functional failures.

The log also shows that `requantize_timing_wrapper.xdc` was parsed and applied before synthesis timing optimization. The later `No constraint will be written out` message therefore does not mean the clock constraint was absent from this run.

## 10. Timing Status

The synthesis result strongly supports the timing-refinement strategy because the DSP output register is now active:

```text
PREG = 1
```

However, synthesis alone does not prove 100 MHz closure.

The required next measurement is a fresh implementation and routed timing summary. Timing closure is accepted only if:

```text
setup WNS >= 0 ns
setup TNS = 0 ns
hold violations = 0
```

The worst Stage-1 and Stage-2 paths should also be inspected so that the measured effect of the pipeline split is understood, not merely accepted from a pass/fail flag.

## 11. Current Step-9 Status

```text
Refined behavioral verification       : COMPLETE / PASS
Refined synthesis                     : COMPLETE
DSP48E1 count                         : 1
DSP PREG                              : 1 / CONFIRMED
Refined LUT count                     : 27
Refined slice FF count                : 26
Refined CARRY4 count                  : 5
Refined BRAM                          : 0
Post-route timing                     : PENDING
100 MHz timing closure                : NOT YET CLAIMED
```
