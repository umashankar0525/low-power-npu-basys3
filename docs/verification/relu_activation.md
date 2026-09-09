# Verification Plan — `relu_activation`

## Role
Verification Engineer

## Active Phase
Phase 4 — Activation and Output Processing

## DUT
`rtl/activation/relu_activation.v`

## Verification Objective

Prove that the module correctly performs INT32 ReLU followed by saturating conversion to signed INT8, with no clock-cycle latency.

The required transfer function is:

\[
y =
\begin{cases}
0 & x < 0\\
127 & x > 127\\
x & 0 \le x \le 127
\end{cases}
\]

## Assumptions

1. `input_acc` is the completed signed INT32 accumulator result.
2. `output_act` is a signed INT8 value.
3. The DUT is purely combinational; there is no clock or reset.
4. The verification environment may change `input_acc` and then allow combinational propagation before sampling `output_act`.
5. The signed INT32 interpretation uses two's-complement representation.

## Required Test Categories

### 1. Negative inputs — ReLU behavior

| Input | Expected output | Reason |
|---:|---:|---|
| -1 | 0 | Negative input is removed by ReLU |
| -128 | 0 | Negative input is removed by ReLU |
| -32768 | 0 | Negative input is removed by ReLU |
| INT32_MIN = -2147483648 | 0 | Most-negative INT32 value is negative |

### 2. Representable non-negative INT8 values

| Input | Expected output |
|---:|---:|
| 0 | 0 |
| 1 | 1 |
| 126 | 126 |
| 127 | 127 |

These cases prove that valid INT8 values pass through unchanged.

### 3. Positive saturation boundary

| Input | Expected output | Reason |
|---:|---:|---|
| 128 | 127 | First value outside signed INT8 range |
| 129 | 127 | Positive overflow must saturate |
| 130 | 127 | Demonstrates why truncation is unsafe |
| 255 | 127 | Positive value remains saturated |
| INT32_MAX = 2147483647 | 127 | Maximum positive accumulator must saturate |

### 4. Critical boundary checks

The most important transition points are:

- `-1 → 0`
- `0 → 0`
- `127 → 127`
- `128 → 127`

These establish the exact ReLU and saturation boundaries.

## Bit-Level Checks

For a negative signed INT32 input, `input_acc[31] = 1`. The DUT must therefore select zero.

For a non-negative input, saturation is required when `input_acc[31:7] != 0`. This detects every non-negative value ≥ 128.

For values 0 through 127, `input_acc[31:7] = 0`, so `input_acc[7:0]` is the exact signed INT8 result.

## Zero-Cycle Verification

Because the DUT contains no clocked state, changing `input_acc` must cause `output_act` to update without waiting for a rising clock edge.

The testbench should therefore use input changes followed by a small combinational settling delay and compare the output. A clock should not be required for correctness.

Important distinction:

- **Architectural latency:** 0 cycles.
- **Physical propagation delay:** non-zero and to be measured after synthesis/implementation.

## Verification Oracle

For every test vector, calculate the expected result independently using the mathematical transfer function rather than duplicating the RTL condition structure.

Pseudo-reference behavior:

```text
if x < 0:
    expected = 0
else if x > 127:
    expected = 127
else:
    expected = x
```

The verification environment must compare the DUT output against this independent expected value.

## Pass Criteria

The module passes functional verification only if:

1. Every negative test produces exactly `0`.
2. Every input from `0` through `127` produces the same numerical value.
3. Every input greater than `127` produces exactly `127`.
4. INT32 minimum and maximum boundaries behave correctly.
5. No clock edge is required for functional output correctness.
6. No unexpected `X` or `Z` output is observed for valid driven inputs.

## Future Measurements

After functional verification, synthesis/implementation must measure actual LUT usage and timing. The current prediction is small LUT-only combinational logic with zero FF, BRAM, and DSP usage. These are predictions, not measured results.

## Verification Status

**Plan complete. Simulation not yet executed.**
