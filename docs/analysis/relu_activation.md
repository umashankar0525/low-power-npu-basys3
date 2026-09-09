# ReLU Activation — Performance Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `relu_activation`  
**Status:** Prediction completed; RTL generated; behavioral simulation measured; synthesis/resource measurement completed; implementation timing pending.

## 1. Purpose

This analysis predicts and then measures the latency, arithmetic behavior, resource implications, and timing considerations of the INT32-to-INT8 ReLU activation stage.

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
9. Behavioral simulation does not measure physical FPGA propagation delay.
10. The supplied synthesis report is for the standalone `relu_activation` top, so its I/O count reflects the module ports rather than the final integrated NPU interface.
11. Because the standalone ReLU module has no clock, a meaningful register-to-register 100 MHz timing path cannot be obtained from this top alone. Integrated timing remains to be measured.

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
- Physical combinational delay: **not measured by behavioral simulation or standalone synthesis utilization**
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

On the target Artix-7 FPGA, this should be substantially simpler than the INT8×INT8 MAC datapath. Nevertheless, the exact delay must be established from implementation timing reports rather than assumed.

## 8. Resource-Usage Prediction

### LUTs

A small number of LUTs is expected for:

- wide non-zero detection of `x[31:7]`
- output selection
- any synthesis-generated comparison/mux logic

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

## 12. Behavioral Simulation Measurement

### Testbench

The unit testbench was executed with Vivado XSim using:

- DUT: `rtl/activation/relu_activation.v`
- Testbench: `tb/unit/tb_relu_activation.v`
- Simulation type: behavioral simulation
- Clock: **none**, because the DUT is combinational
- Independent reference model: used by the testbench
- Randomized coverage: 100 deterministic `$random` input cases in addition to directed cases

### Observed results

The XSim console reported:

- **PASS count = 117**
- **FAIL count = 0**
- **RESULT: ALL TESTS PASSED**

The directed cases included the important boundaries and extremes:

| Input | Observed output | Expected behavior | Result |
|---:|---:|---:|---|
| -1 | 0 | ReLU to 0 | PASS |
| -128 | 0 | ReLU to 0 | PASS |
| -32768 | 0 | ReLU to 0 | PASS |
| INT32_MIN | 0 | ReLU to 0 | PASS |
| 0 | 0 | unchanged | PASS |
| 1 | 1 | unchanged | PASS |
| 126 | 126 | unchanged | PASS |
| 127 | 127 | unchanged | PASS |
| 128 | 127 | saturate | PASS |
| 129 | 127 | saturate | PASS |
| 130 | 127 | saturate | PASS |
| 255 | 127 | saturate | PASS |
| INT32_MAX | 127 | saturate | PASS |

The randomized cases also produced zero failures. Representative examples included both large positive values mapping to `127` and large negative values mapping to `0`.

### Simulation time interpretation

The testbench called `$finish` at **117 ns**. This must **not** be interpreted as ReLU latency.

Because the DUT has no clock, the testbench advances simulation time using its own `#1` settling delays between checks. Therefore the 117 ns completion time reflects the testbench execution schedule, not FPGA propagation delay or architectural latency.

The XSim log also states that the simulator was configured to run for 1000 ns, but `$finish` terminated the testbench earlier at 117 ns.

## 13. Synthesis Resource Measurement

The supplied Vivado 2018.2 synthesis report is explicitly for:

- **Design:** `relu_activation`
- **Device:** `7a35tcpg236-1`
- **Design state:** Synthesized
- **Tool:** Vivado 2018.2

The synthesis completed successfully with **0 errors, 0 critical warnings, and 0 warnings**.

### Measured resources

| Resource | Prediction | Synthesized measurement | Interpretation |
|---|---:|---:|---|
| Slice LUTs | Small | **13** | MATCH; 0.06% of 20,800 LUTs |
| LUT as Logic | Small | **13** | All used LUTs implement logic |
| Slice Registers | 0 | **0** | MATCH |
| BRAM | 0 | **0** | MATCH |
| DSP | 0 | **0** | MATCH |
| F7/F8 Muxes | 0 expected | **0 / 0** | MATCH |

The utilization fraction for LUTs is derived directly from the report:

\[
\frac{13}{20800}\times100 = 0.0625\% \approx 0.06\%
\]

For registers, DSPs, and BRAMs:

\[
\frac{0}{41600}=0\%,\qquad
\frac{0}{90}=0\%,\qquad
\frac{0}{50}=0\%
\]

### Primitive-level observation

The synthesis report shows:

- `LUT5`: 10
- `LUT4`: 3
- `IBUF`: 32
- `OBUF`: 8

The internal logic therefore maps to exactly **13 LUT primitives**, consistent with the top-level LUT utilization. The RTL component statistics also identify **two 2-input 8-bit muxes**. This is consistent with the expected implementation of the three-way decision using mux logic and constant values.

### Important I/O interpretation

The standalone synthesis report shows:

- **40 Bonded IOBs used**
- **106 Bonded IOBs available**
- Utilization:
  \[
  \frac{40}{106}\times100 \approx 37.74\%
  \]

The primitive report explains this as **32 IBUF + 8 OBUF = 40 I/O buffers**.

This is **not an internal ReLU resource cost**. It exists because `relu_activation` was synthesized as the top-level design and therefore its 32-bit input and 8-bit output are external ports. In the final NPU, these signals should be internal connections between accelerator blocks, so the 40 IOB count should not be carried into the system-level resource estimate.

## 14. Timing Measurement Status

The synthesis log explicitly reports:

> `No constraint files found.`

It also reports:

> `WARNING: [Constraints 18-5210] No constraint will be written out.`

Therefore the synthesis run does **not** establish that the ReLU stage meets the 100 MHz requirement.

This is expected for the standalone module because `relu_activation` has **no clock port** and contains no sequential elements. There is no register-to-register timing path for Vivado to analyze as a normal 100 MHz synchronous path.

The correct next timing measurement is therefore an **integrated timing wrapper or integrated accelerator path** containing:

```text
upstream accumulator register
          |
          v
     relu_activation
          |
          v
 downstream output register
```

with a 100 MHz clock constraint. The resulting register-to-register setup slack will determine whether the ReLU logic fits in the actual 10 ns stage budget.

A fake clock should not be added directly to the combinational ReLU module merely to manufacture a timing number, because that would not represent the real architecture.

## 15. Predicted vs Measured Checklist

| Metric | Predicted | Measured/observed | Status |
|---|---:|---:|---|
| Architectural latency | 0 cycles | 0-cycle combinational behavior verified; no clock used | MATCH |
| Clock period | 10 ns at 100 MHz | Not applicable to standalone ReLU top | N/A |
| Additional FFs | 0 | **0** synthesized | MATCH |
| DSPs | 0 | **0** synthesized | MATCH |
| BRAMs | 0 | **0** synthesized | MATCH |
| LUTs | Small | **13 LUTs** synthesized | MATCH |
| Physical combinational delay | Expected to fit within timing budget | Not measured | TBD integrated implementation timing |
| Dynamic power | Small contribution expected | Not measured | TBD power analysis |
| Functional correctness | Boundary cases should pass | **117 pass, 0 fail** | MATCH |

## 16. Performance Interpretation

The synthesis result is a strong confirmation of the intended lightweight architecture.

The ReLU/saturation block consumes only **13 LUTs**, with **0 FF, 0 DSP, and 0 BRAM**. Relative to the available XC7A35T resources, the internal logic cost is negligible: 13 LUTs is only 0.06% of the available 20,800 LUTs.

This also validates an important architectural decision: the activation stage does not require a DSP or memory resource. Its function is dominated by simple bit inspection and output selection.

The measured 13-LUT result should not be confused with the earlier `four_mac_datapath` synthesis result of 691 LUTs. Those are different top-level designs and must remain separate measurements.

## 17. Remaining Measurements

The following measurements are still required before final design review:

1. Build an integrated accumulator-to-ReLU-to-output-register timing path.
2. Apply the actual 100 MHz clock constraint to that integrated design.
3. Obtain worst-case setup slack and data-path delay after implementation.
4. Confirm that the ReLU stage does not become the critical path of the output stage.
5. Perform power analysis only after realistic switching activity is available.

## 18. Analysis Conclusion

The predictions for functional behavior and hardware resources were confirmed:

- **117/117 behavioral tests passed.**
- **0 FF** synthesized, matching the combinational design.
- **0 DSP** synthesized, matching the absence of multiplier/DSP arithmetic.
- **0 BRAM** synthesized, matching the absence of memory.
- **13 LUTs** synthesized, confirming that the logic is small.

The remaining performance question is **physical timing in the integrated pipeline**, not architectural latency. The standalone synthesis report cannot prove 100 MHz timing because no clock constraints and no sequential timing path exist in the standalone ReLU top.

The next correct step is integrated timing measurement, followed by design review.
