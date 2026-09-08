# Memory Interface and Dataflow — Performance Analysis

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Performance Analyst  
**Status:** Prediction only; no post-synthesis or post-implementation measurements included.

## 1. Scope

This analysis derives the expected latency, bandwidth, throughput, and resource usage for the selected memory/dataflow architecture before RTL generation.

## 2. Assumptions

- FPGA: XC7A35T-1CPG236C-1.
- Clock: 100 MHz, so one clock period is 10 ns.
- Synchronous BRAM read latency: 1 clock cycle. This is an architectural assumption to be confirmed against the chosen Vivado BRAM inference/configuration.
- Activation memory: one 32-bit word per address.
- Weight memory: one 32-bit word per address.
- Activation and weight memories operate independently and are read in parallel.
- Four INT8 x INT8 MAC lanes are active for every fetched word.
- Each 4-product group is reduced to an 18-bit signed partial sum.
- The partial sum is sign-extended to INT32 before accumulation.
- The running accumulator is INT32.
- A registered accumulator update occurs once per returned memory word.
- The final result is captured in a result register and `done` is asserted in the same final-result stage unless RTL timing requires an additional output register.
- No DSP inference is assumed for the prediction because previous measured synthesis of the 4-MAC datapath mapped the arithmetic to LUT/carry fabric. This is a project-specific prediction, not a universal Vivado rule.

## 3. Work Per Convolution

The 3x3, single-channel convolution contains:

`3 x 3 x 1 = 9` INT8 multiplications.

With four MAC lanes, the nine products are grouped as:

- Word 0: P0, P1, P2, P3
- Word 1: P4, P5, P6, P7
- Word 2: P8, 0, 0, 0

Therefore three memory words are required.

The zero-filled final word keeps the four-lane datapath uniform.

## 4. BRAM Bandwidth Derivation

Each activation memory access returns:

`32 bits / 8 bits per INT8 = 4 INT8 activations.`

Each weight memory access returns:

`32 bits / 8 bits per INT8 = 4 INT8 weights.`

Because the two memories are independent:

`32 + 32 = 64 operand bits per access cycle.`

Equivalently, eight INT8 operand values are supplied per memory-access cycle: four activations plus four weights.

For one 3x3 convolution, the useful operand payload is:

`9 activations x 8 = 72 bits`

and

`9 weights x 8 = 72 bits`.

The physical memory traffic for the packed three-word scheme is:

`3 x 32 = 96 bits` from activation memory and
`3 x 32 = 96 bits` from weight memory.

Thus each memory has 24 bits of padding/unused lane capacity over the three words:

`96 - 72 = 24 bits.`

Total physical operand traffic is therefore:

`96 + 96 = 192 bits`

for 9 useful activation-weight pairs.

The packing efficiency per memory is:

`72 / 96 = 75%`.

The 25% unused capacity is the cost of maintaining a uniform four-lane datapath for the final single-product word.

## 5. Exact Cycle Schedule

Under the stated one-cycle BRAM latency and registered accumulator-update assumptions:

| Clock edge / cycle | Action | State after edge |
|---|---|---|
| 1 | Accept `start`; issue address 0 read | Read request for Word 0 is outstanding |
| 2 | Issue address 1; consume Word 0; form S0; update ACC | `ACC = S0`; Word 1 is outstanding |
| 3 | Issue address 2; consume Word 1; form S1; update ACC | `ACC = S0 + S1`; Word 2 is outstanding |
| 4 | Consume Word 2; form S2; update ACC | `ACC = S0 + S1 + S2` |
| 5* | Assert `done` / expose final result if an additional registered output boundary is used | Final result available externally |

`*` The exact cycle-4 versus cycle-5 external timing depends on whether `result` is driven directly from the final accumulator update path or from a separate result register. The project should prefer an explicit result register if it improves interface clarity, even if that costs one cycle.

### Important timing conclusion

The memory/dataflow portion has a minimum of three returned-word computation opportunities after the first BRAM request. The one-cycle BRAM latency creates a startup bubble, but subsequent requests overlap with computation.

If the final accumulator value is captured into a dedicated result register on the same edge as the third accumulator update, the result register receives the new sum on the following combinational visibility interval and `done` can be designed for that registered boundary. Therefore, RTL signal semantics must define exactly which edge constitutes completion.

At 100 MHz:

- 1 cycle = 10 ns.
- Start edge to third word consumption = 3 clock periods = 30 ns.
- With an additional output register stage, start edge to externally registered result = 4 clock periods = 40 ns.

The design should not claim one of these as measured latency until RTL simulation defines the exact handshake convention.

## 6. Running Accumulator Analysis

The running accumulator performs:

`ACC0 = 0`

`ACC1 = ACC0 + S0`

`ACC2 = ACC1 + S1`

`ACC3 = ACC2 + S2`

Therefore the final mathematical result is:

`ACC3 = S0 + S1 + S2`.

This eliminates the need to store all three partial sums followed by a separate final three-input accumulation structure.

### What is actually improved?

The main architectural benefit is reduced hardware and simpler control/dataflow. It does **not** automatically reduce the total number of clock cycles. Latency improves only if the accumulator update can be placed in the existing per-word processing stage without creating an additional sequential boundary.

The running accumulator also introduces a 32-bit addition into every word-processing iteration. Consequently, the accumulator adder is a likely timing-critical component.

## 7. Arithmetic Width Derivation

Maximum positive INT8 product:

`(-128) x (-128) = 16384`.

Four such products give the largest positive four-lane partial sum:

`4 x 16384 = 65536`.

An 18-bit signed integer has range:

`-131072 ... +131071`.

Therefore 18 bits are sufficient for a four-product partial sum.

For the full nine-product convolution:

`9 x 16384 = 147456`.

This exceeds the maximum positive value of a signed 18-bit number (+131071), so the final accumulator requires more than 18 bits. The project specification therefore uses INT32.

## 8. Resource Prediction

### BRAM

Two independent packed memories are required:

- 1 activation memory
- 1 weight memory

Prediction: **2 BRAM resources**, assuming each inferred memory maps to one block RAM resource at the selected depth/width and is not optimized into distributed RAM.

This prediction must be checked because a very small memory can be implemented by Vivado using LUT RAM instead of block RAM depending on coding style, depth, and synthesis settings.

### MAC / multiplier hardware

There are four parallel INT8 multipliers.

Prediction: four multiplier datapaths.

However, based on the previously measured 4-MAC datapath on this project, Vivado mapped the arithmetic into LUT/carry resources rather than DSP48 slices. Therefore the conservative project prediction is:

- DSP48: **0 expected** under the current synthesis behavior.
- LUT/carry usage: **non-zero and likely dominant**.

Exact LUT count cannot be derived reliably from first principles because synthesis sharing, constant propagation, signed arithmetic implementation, and carry-chain mapping affect the result.

### Registers

At minimum, the architecture requires state for:

- accumulator: 32 FFs
- result register, if used: 32 FFs
- control state / word address / handshake state: several FFs
- BRAM output registers, if explicitly instantiated: 32 bits per memory as applicable

A precise FF count therefore depends on the RTL boundary chosen in the next phase.

## 9. Throughput Prediction

One convolution requires three packed word-processing iterations.

Ignoring startup/finish overhead and assuming a new convolution can be launched every three processing cycles, the steady-state theoretical throughput is:

`1 convolution / 3 cycles`.

At 100 MHz:

`100,000,000 / 3 = 33,333,333.33 convolutions/s`.

This is an idealized throughput bound. It assumes continuous work, no additional window/address-generation stalls, and enough surrounding memory bandwidth to supply each new convolution.

For a single standalone convolution, startup and completion overhead make the effective throughput lower.

## 10. Critical-Path Prediction

Likely timing-critical paths, in descending architectural concern:

1. 32-bit signed accumulator addition.
2. Four INT8 multipliers if implemented in LUT/carry fabric.
3. Four-product partial-sum reduction.
4. Control/address decode only if implemented with unnecessarily deep combinational logic.

The accumulator is especially important because it is 32 bits wide and is used on every word-processing iteration.

A future timing report must determine whether the accumulator, multiplier, or reduction network actually limits Fmax.

## 11. Expected Design Tradeoff

The selected architecture favors simplicity and regularity:

- Separate activation and weight memories avoid packing both operand types into one 32-bit word.
- Four lanes are always instantiated.
- The final word uses three zero lanes instead of a special one-lane datapath.
- A running INT32 accumulator removes a separate final three-way accumulation structure.

The cost is 25% packing inefficiency in each memory for the final word and potentially a timing-critical 32-bit accumulator adder.

## 12. Prediction Summary

| Metric | Prediction |
|---|---:|
| Clock | 100 MHz |
| Clock period | 10 ns |
| Convolution products | 9 |
| Packed words / convolution | 3 |
| MAC lanes | 4 |
| Activation memory width | 32 bits |
| Weight memory width | 32 bits |
| Parallel operand bandwidth | 64 bits/cycle |
| Useful payload / memory | 72 bits |
| Physical payload / memory | 96 bits |
| Packing efficiency | 75% |
| Partial sum width | 18 bits |
| Final accumulator width | 32 bits |
| BRAM prediction | 2, subject to inference |
| DSP prediction | 0, based on prior project synthesis behavior |
| Steady-state convolution throughput | 1 / 3 cycles |
| Ideal throughput @100 MHz | ~33.33 Mconv/s |
| Start edge → third word consumption | 30 ns |
| Start edge → result with extra output register | 40 ns |

## 13. What Must Be Measured Later

After RTL generation and simulation, compare these predictions against:

- exact `start` to `done` latency,
- actual result-register timing,
- inferred BRAM versus LUT RAM,
- LUT count,
- FF count,
- DSP48 count,
- achieved Fmax,
- critical path and timing slack,
- actual sustained throughput.

No measured values are claimed in this document.

## 14. Analysis Conclusion

The selected dataflow can supply four MAC lanes continuously after the initial BRAM read latency. Three packed memory words are sufficient for one 3x3 convolution. A running INT32 accumulator reduces architectural hardware and simplifies the reduction schedule, but its 32-bit adder is a likely timing-critical path. The predicted steady-state work rate is one convolution every three processing cycles, while standalone latency is expected to be approximately 30 ns to consume the final word, or approximately 40 ns if an additional registered output boundary is intentionally used.

The next step remains blocked until the user confirms understanding. No RTL should be generated until this analysis is understood and accepted.
