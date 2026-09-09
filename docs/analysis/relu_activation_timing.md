# ReLU Activation — Integrated Timing Measurement Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `relu_activation`  
**Status:** Prediction only; integrated timing measurement not yet performed.

## 1. Objective

The standalone `relu_activation` synthesis confirmed the expected lightweight logic but did not prove operation at 100 MHz. The purpose of the next measurement is to create a real synchronous register-to-register timing path around the combinational ReLU block.

## 2. Explicit Assumptions

- Target clock: 100 MHz.
- Clock period: 10 ns.
- ReLU remains combinational with 0 architectural cycles.
- Input to ReLU represents the completed signed INT32 accumulator result.
- Output register captures the final signed INT8 activation.
- Timing is evaluated after synthesis/implementation with the actual clock constraint.
- The wrapper is a measurement structure; it does not change the intended ReLU architecture by inserting a pipeline register inside the ReLU module.

## 3. Intended Timing Path

```text
              100 MHz clock
                    |
                    v
          +-------------------+
          | Accumulator       |
          | Register          |
          +-------------------+
                    |
                    | INT32
                    v
          +-------------------+
          | relu_activation   |
          | ReLU + saturation |
          +-------------------+
                    |
                    | INT8
                    v
          +-------------------+
          | Output Register   |
          +-------------------+
```

The accumulator register is the **launch endpoint** and the output register is the **capture endpoint**. This gives static timing analysis a real synchronous path containing the ReLU combinational logic.

## 4. Timing Derivation

At 100 MHz:

\[
T_{clk}=\frac{1}{100\,MHz}=10\,ns
\]

For setup timing, the data launched by the accumulator register must reach and satisfy the output register before the next active clock edge. Conceptually:

\[
T_{clk\to Q}+T_{ReLU}+T_{routing}+T_{setup}\le10\,ns
\]

The timing slack can be viewed conceptually as:

\[
Slack=T_{required}-T_{arrival}
\]

For a 10 ns requirement:

- Positive slack → timing requirement is met.
- Zero slack → exactly meets the requirement.
- Negative slack → timing violation.

### Example prediction only

If a hypothetical implemented path consumed 7 ns total, then:

\[
Slack=10-7=+3\,ns
\]

This +3 ns is **not a measured result**; it only illustrates the interpretation of slack.

## 5. Why the Standalone ReLU Cannot Prove 100 MHz

The standalone module contains no clock and no flip-flops. Its 13-LUT synthesis result tells us about resource mapping, but not whether a real synchronous data path can meet a 10 ns clock period.

Adding a fake clock solely to the combinational module would not represent the intended architecture. The meaningful measurement is the actual accelerator-style path:

```text
accumulator register -> ReLU/saturation -> output register
```

under the real 100 MHz constraint.

## 6. Timing-Wrapper Design Prediction

Before RTL generation, the expected wrapper behavior is defined as follows:

1. On clock edge **N**, the accumulator register launches a known INT32 value.
2. During the interval from edge **N** to edge **N+1**, the combinational ReLU/saturation logic evaluates that value.
3. The resulting INT8 value must become stable early enough to satisfy the output register's setup requirement.
4. On edge **N+1**, the output register captures the ReLU result.
5. Therefore, the ReLU logic receives one full clock period as its available timing window, subject to clock-to-Q, routing, setup, and any clock uncertainty represented by the timing constraints.

The important distinction is that the output register captures **at edge N+1**; it does not capture sometime after N+1. If the data becomes stable too late, the path has negative setup slack and therefore violates timing.

## 7. Expected Timing Prediction

The ReLU logic contains sign detection, a reduction/non-zero check over `input_acc[31:7]`, and output selection. This is expected to be a small combinational path relative to the 10 ns clock period.

A numerical implementation delay is **not assumed**. The prediction is only qualitative: the path should have positive slack at 100 MHz if placement, routing, clock constraints, and the surrounding wrapper do not introduce an unexpected bottleneck.

For example, if the eventual report showed +2 ns slack, the measured path would have approximately 8 ns of available-to-arrival timing usage under a 10 ns requirement:

\[
T_{path}=10-2=8\,ns
\]

That would mean the path meets the 100 MHz requirement with 2 ns of timing margin. This remains an example until Vivado implementation produces the actual report.

## 8. What Must Be Measured

The implementation timing report should provide evidence for:

1. The worst register-to-register setup path.
2. The path delay/arrival time.
3. The required clock period.
4. Setup slack.
5. Whether the ReLU path is the critical path of this stage.

Vivado provides `report_timing` for reporting timing paths. The AMD Vivado documentation describes `report_timing` as a command for reporting timing paths and supports setup/max-delay analysis and path selection options. citeturn1view0

## 9. Measurement Discipline

The next RTL wrapper must not be generated until the timing-wrapper concept is understood. After the wrapper is generated, the verification flow should establish that:

- the accumulator register launches a known INT32 value,
- the ReLU produces the mathematically correct INT8 result,
- the output register captures that result on the expected clock edge,
- the 100 MHz constraint is applied,
- the implementation timing report provides the measured slack.

Functional simulation and timing analysis answer different questions: simulation proves logical behavior, while static timing analysis proves whether the implemented synchronous path meets its clock requirement.
