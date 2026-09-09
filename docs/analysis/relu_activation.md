# ReLU Activation — Performance Analysis (Predictions)

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `relu_activation`  
**Status:** Prediction only; no RTL generated in this phase.

## 1. Purpose

This analysis predicts the latency, arithmetic behavior, resource usage, and timing implications of the proposed INT32-to-INT8 ReLU activation stage.

The intended function is:

\[
y =
\begin{cases}
0, & x < 0\\
 x, & 0 \le x \le 127\\
127, & x > 127
\end{cases}
\]

This combines ReLU with **signed INT8 saturation** so that the output is always a valid signed INT8 value.

## 2. Explicit Assumptions

1. Input `x` is a signed 32-bit accumulator result.
2. Output `y` is a signed 8-bit activation.
3. ReLU and saturation are implemented as combinational logic.
4. No register is inserted inside this module.
5. The surrounding accelerator operates at 100 MHz.
6. The clock period is therefore:
   \[
   T = \frac{1}{100\text{ MHz}} = 10\text{ ns}
   \]
7. Vivado/Xilinx synthesis maps the comparison, multiplexing, and constant generation into FPGA LUT/carry logic as appropriate.
8. No DSP block is required for this function.
9. Actual post-synthesis/post-implementation propagation delay is not yet known and must be measured later.

## 3. Functional Decision Derivation

### Step 1 — Detect a negative INT32 value

For a two's-complement signed 32-bit number:

\[
x < 0 \iff x[31] = 1
\]

Therefore the sign bit alone determines whether ReLU should produce zero.

### Step 2 — Handle non-negative values

After ReLU, only values from 0 upward remain.

The signed INT8 maximum is:

\[
127 = 2^7-1
\]

A non-negative 32-bit value exceeds 127 exactly when any bit from bit 7 through bit 31 is set:

\[
x > 127 \iff x[31:7] \ne 0
\]

This is sufficient because the negative case has already been separated by `x[31]`.

### Step 3 — Final selection

The priority is therefore:

1. If `x[31] = 1`, output `0`.
2. Otherwise, if `x[31:7] != 0`, output `127`.
3. Otherwise, output `x[7:0]`.

This gives exact signed INT8 saturation after ReLU.

## 4. Boundary-Case Predictions

| Input INT32 | ReLU result | Saturated INT8 prediction |
|---:|---:|---:|
| -146304 | 0 | 0 |
| -1 | 0 | 0 |
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| 126 | 126 | 126 |
| 127 | 127 | 127 |
| 128 | 128 | 127 |
| 130 | 130 | 127 |
| 255 | 255 | 127 |
| 32767 | 32767 | 127 |
| 147456 | 147456 | 127 |

The two important transition points are therefore **127 → 127** and **128 → 127**.

## 5. Why Direct Truncation Is Not Acceptable

If the design simply assigned `y = x[7:0]`, then values above the INT8 range would wrap instead of saturate.

For example:

\[
130 = 0x00000082
\]

Taking the low eight bits gives:

\[
0x82
\]

Interpreted as signed INT8, `0x82` equals -126, which is incorrect after ReLU.

Therefore saturation is functionally necessary, not an optional optimization.

## 6. Latency Prediction

Because the proposed module is combinational and contains no register, its **architectural clock latency is zero cycles**.

That means the module does not intentionally consume an additional 10 ns clock period.

However, zero-cycle architectural latency does **not** mean zero physical delay. The signal must still propagate through FPGA logic before the downstream register captures it.

If the upstream accumulator register changes immediately after a clock edge, the ReLU/saturation output settles sometime later within that same 10 ns period. The downstream register must capture the settled value at the next active edge.

Therefore:

- Additional pipeline cycles: **0 predicted**
- Physical combinational delay: **not yet measured**
- Available timing budget at 100 MHz: **10 ns**, shared with other combinational logic in the same pipeline stage

## 7. Timing-Critical Logic Prediction

The critical path is expected to consist primarily of:

1. Reading the INT32 sign bit.
2. Detecting whether `x[31:7]` contains any set bit.
3. Selecting between constants `0`, `127`, and `x[7:0]`.

There is no multiplication, division, or wide addition.

The overflow detection can conceptually be reduced as an OR-reduction:

\[
O = x[31] \lor x[30] \lor \dots \lor x[7]
\]

with the negative test evaluated first by the control priority.

On the target Artix-7 FPGA, this should be substantially simpler than the INT8×INT8 MAC datapath. Nevertheless, the exact delay must be established from synthesis and implementation timing reports rather than assumed.

## 8. Resource-Usage Prediction

### LUTs

A small number of LUTs is expected for:

- wide non-zero detection of `x[31:7]`
- output selection
- any synthesis-generated comparison/mux logic

The exact LUT count is implementation-dependent.

### Flip-flops

**Prediction: 0 additional FFs**, because the module is intentionally combinational.

### DSPs

**Prediction: 0 DSPs.** No arithmetic operation requiring a DSP is present.

### BRAM

**Prediction: 0 BRAMs.** The module contains no memory.

## 9. Power Implication Prediction

The module is small, so its dynamic power contribution is expected to be much smaller than the MAC datapath and memory system.

However, the output logic can toggle whenever the INT32 accumulator changes. Since this is a data-dependent combinational block, actual dynamic power depends on switching activity and input statistics.

No quantitative power number is claimed at this stage because switching activity and implementation capacitance have not been measured.

## 10. Dataflow Placement

The intended dataflow is:

```text
INT32 running accumulator
        |
        v
   ReLU decision
        |
        v
 INT8 saturation
        |
        v
   INT8 output
```

ReLU must operate on the **complete accumulated convolution result**, not on individual products or partial sums. Otherwise negative intermediate values could be discarded before later positive contributions arrive.

## 11. Throughput Implication

Because the block is combinational and adds no register stage, it does not by itself reduce the number of convolution results produced per cycle.

If the existing pipeline produces one completed convolution result every three processing cycles, the activation block can remain in that output path without adding an architectural cycle, provided its physical delay fits within the available timing budget.

Thus the predicted steady-state throughput remains approximately:

\[
\frac{100\text{ MHz}}{3} \approx 33.33\text{ million convolution results/s}
\]

This is a system-level prediction inherited from the current 4-MAC/3-word schedule, not a standalone ReLU throughput measurement.

## 12. Verification Targets Before RTL Simulation

The future verification stage should explicitly test:

1. Negative minimum-like accumulator values → `0`.
2. `-1` → `0`.
3. `0` → `0`.
4. `1` → `1`.
5. `127` → `127`.
6. `128` → `127`.
7. Large positive INT32 values → `127`.
8. The maximum expected convolution accumulator, `147456` → `127`.
9. A negative value with many lower bits set → still `0`.
10. No X/Z-dependent behavior in simulation for valid inputs.

## 13. Predicted vs Measured Checklist

| Metric | Predicted now | Measured later |
|---|---:|---:|
| Architectural latency | 0 cycles | TBD |
| Clock period | 10 ns at 100 MHz | TBD/confirmed by constraint |
| Additional FFs | 0 | TBD |
| DSPs | 0 | TBD |
| BRAMs | 0 | TBD |
| LUTs | Small | TBD |
| Physical combinational delay | < available 10 ns budget expected | TBD from timing report |
| Dynamic power | Small contribution expected | TBD from power analysis |

## 14. Analysis Conclusion

The ReLU activation stage is predicted to be a very small combinational block with zero architectural latency and no DSP/BRAM requirement. The main functional risk is not ReLU itself but incorrect INT32-to-INT8 conversion; saturation must prevent positive values above 127 from wrapping into negative INT8 values.

The principal performance question is therefore **timing closure**, not cycle count. The design should preserve the existing throughput if the combinational ReLU/saturation delay fits inside the available 100 MHz timing budget.

No RTL should be generated from this analysis until the design assumptions and predictions are confirmed by the user.
