# ReLU Activation — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Status:** Design derivation complete; RTL not yet generated

## 1. Objective

Design the output activation stage that converts the completed INT32 convolution accumulator into a non-negative output and then into signed INT8 using saturation.

## 2. Assumptions

- Clock: 100 MHz.
- Input to this module: completed signed INT32 accumulator value.
- ReLU is evaluated after the complete 3x3 accumulation.
- Output representation: signed INT8.
- INT8 conversion uses saturation to the signed INT8 range [-128, 127].
- This design is initially intended as a combinational datapath; timing will be evaluated during synthesis.
- No pipeline register is introduced in this first version unless timing analysis later shows it is necessary.

## 3. Functional Definition

ReLU is:

    relu(x) = x, x > 0
              0, x <= 0

After ReLU, the value is converted to signed INT8 by saturation:

    y = 0,   x <= 0
        x,   0 < x <= 127
        127, x > 127

Because ReLU has already removed all negative values, the lower saturation boundary (-128) is never reached for a correctly ordered ReLU-then-saturation operation. The combined behavior therefore has three regions.

## 4. Bit-Level Derivation

For a signed two's-complement INT32 value, bit 31 is the sign bit.

- If `acc[31] = 1`, the accumulator is negative, so ReLU output is zero.
- If `acc[31] = 0`, the accumulator is non-negative and can proceed to the INT8 range check.

For a non-negative INT32 value, values greater than 127 are detected by checking whether any upper bit above bit 6 is set. Equivalently, for non-negative input:

    acc > 127  <=>  |acc[31:7] = 1

The exact hardware decision is therefore:

1. Negative (`acc[31]=1`) -> output 0.
2. Non-negative and upper bits `[31:7]` contain a 1 -> output 127.
3. Otherwise -> output `acc[7:0]`.

## 5. Why ReLU Must Follow Accumulation

The convolution output is:

    ACC = p0 + p1 + ... + p8

ReLU must be applied to this complete result. Applying ReLU to each product changes the mathematical operation because negative products would be discarded before cancellation with positive products.

Example:

    p0 = -10
    p1 = +20

Correct ordering:

    ReLU(-10 + 20) = ReLU(10) = 10

Incorrect ordering:

    ReLU(-10) + ReLU(20) = 0 + 20 = 20

Thus ReLU belongs after the final accumulator value is available.

## 6. Why Conversion Is Separate

ReLU only enforces non-negativity. It does not change the numeric width.

Example:

    INT32 130 -> ReLU -> INT32 130

The value 130 cannot be represented by signed INT8 because:

    signed INT8 range = [-128, 127]

Therefore saturation is required:

    130 -> 127

Taking only `acc[7:0]` would instead reinterpret 130's low byte as a negative signed INT8 value (-126), which is incorrect.

## 7. Interface Concept

Conceptual module interface:

    input  signed [31:0] acc_in
    output signed [7:0]  output_data

No clock is required for the initial combinational implementation. A later registered wrapper may be considered if timing closure requires it.

## 8. Timing Derivation

For the initial combinational implementation, there is no additional clock-cycle latency by architectural definition. The input is transformed continuously into the output.

At 100 MHz, the available clock period is:

    Tclk = 1 / 100 MHz = 10 ns

Therefore, the combinational ReLU/saturation logic must have sufficient propagation delay margin to fit within the surrounding synchronous path's 10 ns period. Actual timing cannot be claimed until synthesis/implementation measurement.

## 9. Resource Prediction

Expected logic is small:

- One sign-bit test.
- One reduction-OR across upper bits `[31:7]` for overflow detection.
- One 8-bit selection path.
- Constant output values 0 and 127.

No DSP is mathematically required.

Exact LUT count, FF count, and timing are predictions only until synthesis is performed.

## 10. Design Decision

Use a combinational ReLU followed by INT8 saturation:

    INT32 accumulator
          |
          v
       sign test
       /       \
    negative   non-negative
       |            |
       v            v
       0       overflow test
                  /    \
                yes     no
                 |       |
                127   acc[7:0]

This is the baseline design for verification and later synthesis measurement.

## 11. Verification Targets

The verification plan must include at minimum:

- Negative INT32 input -> 0.
- Zero -> 0.
- Small positive value -> unchanged.
- 127 -> 127.
- 128 -> 127.
- 130 -> 127.
- Maximum positive INT32 -> 127.
- Values around zero.
- Values around the INT8 positive boundary.

Verification must check the numeric result and explain why each boundary case passes.

## 12. RTL Gate

Concept and mathematical derivation are complete. RTL generation is permitted only after the user confirms understanding of:

1. ReLU is applied to the completed INT32 accumulator.
2. ReLU and width conversion are separate operations.
3. Signed INT8 saturation clamps values above 127 to 127.
4. For non-negative values, `acc[31:7] != 0` detects values above 127.
5. The initial design is combinational and adds zero architectural clock cycles.
