# INT8 Quantization — Timing-Refinement RTL Implementation

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 SUPPORT — TIMING-CLOSURE RTL REFINEMENT IMPLEMENTATION

## 1. Objective

Implement the previously derived timing refinement for the requantization path without discarding the already-verified combinational baseline.

The measured baseline implementation was functionally correct but failed the 100 MHz setup requirement:

```text
WNS = -0.405 ns
TNS = -2.381 ns
7 / 7 output endpoints failed setup
```

The routed critical path contained:

```text
launch register
 -> pre-DSP LUT logic
 -> DSP48E1
 -> CARRY4 rounding chain
 -> saturation/output LUT logic
 -> activation capture register
```

The selected refinement inserts one register immediately after the raw fixed-point product and before rounding.

## 2. Assumptions

- Target FPGA: XC7A35T-1CPG236C.
- Target clock: 100 MHz.
- Clock period: 10 ns.
- Generated INT8 operands remain in `[-127, +127]`.
- The maximum legal positive 3x3 single-channel accumulator remains `145161`.
- `M_INT` is an unsigned 24-bit layer constant.
- `FRAC_BITS` remains a compile-time constant in `0..42`.
- Reset for the pipelined module is synchronous active-high.
- The child engine result register corresponds to the architectural S5 launch boundary.
- The new product register corresponds to S6.
- The existing activation capture register corresponds to S7.
- The redesigned path has not yet been re-simulated, re-synthesized, or re-implemented. No timing-closure claim is made in this document.

## 3. Files

The verified combinational baseline is preserved unchanged:

```text
rtl/activation/requantize_relu.v
```

The new timing-refined module is:

```text
rtl/activation/requantize_relu_pipelined.v
```

The measurement wrapper is updated to use the pipelined module:

```text
rtl/activation/requantize_timing_wrapper.v
```

The 100 MHz wrapper constraint remains:

```text
vivado/constraints/requantize_timing_wrapper.xdc
```

## 4. Why the Existing Combinational Module Is Preserved

The existing `requantize_relu.v` has already passed the directed Phase 6 behavioral testbench. Replacing it immediately would remove a known-good reference point.

Keeping it provides two useful implementations of the same numerical contract:

```text
requantize_relu.v
    = verified combinational baseline

requantize_relu_pipelined.v
    = timing-refined sequential implementation
```

The pipelined implementation can now be verified against both the mathematical reference and the previously verified combinational behavior.

This separation also makes latency explicit: the original block is combinational, while the new block introduces one registered product stage.

## 5. Stage 1 Derivation

For positive accumulators, the raw product is:

```text
product = acc_mag * M_INT
```

The post-ReLU magnitude width is 18 bits and the coefficient width is 24 bits.

Therefore the exact multiplication width is:

```text
18 + 24 = 42 bits
```

The new module computes:

```text
product_next = acc_mag * M_INT
```

and captures the result in:

```text
product_reg[41:0]
```

on the rising clock edge.

This is the selected pipeline boundary.

The full 42-bit product is stored. No truncation is permitted at this boundary because the later rounding result depends on low product bits as well as high product bits.

## 6. ReLU Handling Across the Pipeline Boundary

The input sign test remains before the multiplier:

```text
acc_positive = (~acc_in[31]) && (|acc_in)
```

The selected magnitude is:

```text
acc_mag = acc_positive ? acc_in[17:0] : 0
```

Therefore every non-positive accumulator produces:

```text
product_next = 0
```

and consequently:

```text
product_reg = 0
```

on the next edge.

Because the sign decision has already been converted into a zero/nonzero magnitude before the pipeline register, no separate sign flag is required in Stage 2.

This avoids an unnecessary control bit crossing the pipeline boundary and preserves the ReLU contract:

```text
acc_in <= 0  -> q_out = 0
```

## 7. Stage 2 Derivation

The registered raw product is zero-extended to 43 bits:

```text
product_ext = {1'b0, product_reg}
```

For `FRAC_BITS > 0`, positive round-to-nearest remains:

```text
rounded_num = product_ext + 2^(FRAC_BITS - 1)
q_pre_wide  = rounded_num >> FRAC_BITS
```

For `FRAC_BITS = 0`:

```text
rounded_num = product_ext
q_pre_wide  = rounded_num
```

The final saturation rule is unchanged:

```text
if any bit q_pre_wide[42:7] is 1:
    q_out = 127
else:
    q_out = q_pre_wide[7:0]
```

Since Stage 1 maps non-positive inputs to a registered product of zero, the Stage 2 output logic no longer needs the original `acc_positive` signal.

## 8. Architectural Cycle Alignment

The new internal register is intentionally aligned with the existing control schedule.

### S5

The child convolution engine registers:

```text
result <= final accumulator value
engine_done <= 1
```

The new result becomes visible after the S5 edge.

### S5 to S6

The completed result propagates through:

```text
sign/ReLU gate
 -> 18-bit magnitude
 -> DSP multiply/correction mapping
```

### S6

The new 42-bit product register captures the raw product.

The outer control FSM also enters its existing activation-capture state at this edge after observing the registered child `engine_done` handshake.

### S6 to S7

The registered product propagates through:

```text
rounding-bias addition
 -> constant right shift
 -> saturation/output selection
```

### S7

The existing external activation register captures the final INT8 activation.

Therefore the intended architectural sequence remains:

```text
S5 = engine result register
S6 = product pipeline register
S7 = activation capture register
```

No new FSM state is introduced by this RTL refinement.

## 9. Why the Measurement Wrapper Changes

The original wrapper measured one long path:

```text
accumulator_reg
 -> entire combinational requantize_relu
 -> output_activation register
```

The updated wrapper now measures two register-to-register paths:

```text
Path A:
accumulator_reg
 -> Stage-1 multiply logic
 -> product_reg

Path B:
product_reg
 -> Stage-2 rounding/saturation logic
 -> output_activation register
```

This is the physical structure we need Vivado to evaluate after the redesign.

The wrapper still contains the 32-bit launch register and 8-bit activation capture register as measurement scaffolding. The 42-bit `product_reg` is different: it is the intentional architectural timing-refinement register inside `requantize_relu_pipelined`.

## 10. DSP Register-Inference Goal

The previous synthesis report showed one DSP48E1 with:

```text
PREG = 0
```

The new register is written directly from the multiplication result:

```text
product_reg <= acc_mag * M_INT
```

This coding structure gives Vivado an opportunity to absorb the register into the DSP48E1 output register.

The desired synthesis outcome is therefore:

```text
DSP48E1 count = 1
PREG = 1
```

if the tool can preserve the earlier one-DSP mapping while using the internal DSP output register.

This is a synthesis goal, not an assumption. The actual result must be checked in the next synthesis report.

If Vivado instead implements the 42-bit product register in slice FFs, timing may still improve, but resource usage will differ from the preferred mapping.

## 11. Functional-Latency Consequence

The pipelined module itself has one sequential stage.

An input accumulator presented to `acc_in` before a rising edge produces the corresponding registered raw product immediately after that edge. The rounded/saturated `q_out` then becomes combinationally valid from that registered product during the following cycle.

In the real system, the external activation register captures that `q_out` one edge later.

Therefore verification must account for the one-cycle internal pipeline stage. A combinational testbench that changes `acc_in` and checks `q_out` after `#1` is no longer valid for this new module.

## 12. Verification Requirements Before Timing Re-Measurement

The timing-refined module must be re-verified before synthesis conclusions are accepted.

The new verification must check at least:

```text
reset clears product_reg
negative input becomes registered product 0 and q_out 0
zero input remains 0
identity-scale behavior with one-cycle pipeline latency
positive rounding behavior
non-power-of-two coefficient behavior
saturation threshold behavior
maximum-width product preservation
back-to-back inputs to prove pipeline sequencing
```

The testbench must explicitly model clock edges and distinguish:

```text
input presented before edge N
product captured at edge N
q_out valid during cycle N -> N+1
```

for the standalone pipelined module.

For the timing wrapper, the complete launch-to-output sequence requires the launch register, internal product register, and output capture register.

## 13. Timing Measurement Requirements After Functional Verification

After functional verification passes, rerun synthesis and implementation with:

```text
requantize_timing_wrapper
```

as the top and the existing 10 ns constraint.

Record:

```text
DSP48E1 count
DSP AREG/BREG/MREG/PREG configuration
LUT count
FF count
whether product_reg is absorbed into the DSP
post-route WNS
post-route TNS
hold slack
worst Stage-1 path
worst Stage-2 path
```

The 100 MHz timing issue is considered closed only if the implemented design reports:

```text
WNS >= 0 ns
TNS = 0 ns
```

for setup timing and no hold failures.

## 14. Current Status

```text
Timing failure characterized             : COMPLETE
Pipeline location derived                : COMPLETE
Design understanding gate                : PASSED
Pipelined RTL module                      : IMPLEMENTED
Timing measurement wrapper updated        : IMPLEMENTED
Functional verification of new RTL        : PENDING
Refined synthesis measurement             : PENDING
Refined implementation timing             : PENDING
100 MHz timing closure                    : NOT YET CLAIMED
```

The next workflow action is verification planning and testbench generation for `requantize_relu_pipelined` before any new timing result is accepted.
