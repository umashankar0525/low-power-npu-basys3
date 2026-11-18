# INT8 Quantization — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** TEACH / UNDERSTANDING CHECK

## Assumptions

- Activations use one symmetric per-tensor scale `S_a`.
- Weights use one symmetric per-tensor scale `S_w`.
- The 3x3 convolution sums nine INT8×INT8 products into an INT32 accumulator.
- The next INT8 activation may use a different scale `S_out`.

## Checkpoint 1 — Scale meaning

**Status: PASSED**

The learner correctly restated that the scale tells us how much real numerical value an INT8 code represents, and that the same INT8 code can represent different FP32 values when the scale changes.

For symmetric quantization:

```text
x ≈ S × q
```

Therefore the numerical meaning is carried by the pair `(q, S)`, not by the INT8 code alone.

## Checkpoint 2 — Product and accumulator scale

**Status: PASSED**

The learner correctly restated that both the activation and weight already carry scale factors, so their multiplication also multiplies the scale factors.

Starting from:

```text
x ≈ S_a × q_a
w ≈ S_w × q_w
```

we obtain:

```text
xw ≈ (S_a × S_w)(q_a × q_w)
```

so:

```text
S_product = S_a × S_w
```

For the 3x3 convolution:

```text
acc = Σ(q_ai × q_wi)
```

and, under the stated per-tensor-scale assumption:

```text
y ≈ (S_a × S_w) acc
```

therefore:

```text
S_acc = S_a × S_w
```

## Checkpoint 3 — Saturation versus requantization

**Status: PASSED**

The learner correctly restated the final distinction:

- **Saturation** only limits an integer to the allowed INT8 range.
- **Requantization** converts the accumulator from `S_acc` units to `S_out` units using the scale ratio before rounding and clipping.

The accumulator represents a real value as:

```text
y ≈ S_acc × acc
```

while the output INT8 value must satisfy:

```text
y ≈ S_out × q_out
```

Therefore:

```text
q_out ≈ round((S_acc / S_out) × acc)
```

with:

```text
S_acc = S_a × S_w
```

Requantization does not reconstruct the exact original FP32 value because earlier quantization may already have introduced rounding or clipping error. Its purpose is to preserve the represented real quantity approximately while changing from accumulator-scale units to output-scale units.

## Teaching gate result

**TEACHING GATE: PASSED**

The learner has demonstrated understanding of:

1. why the pair `(q, S)` is required to interpret an INT8 value;
2. why the product and INT32 accumulator scale are `S_a × S_w` under the baseline per-tensor model;
3. why raw saturation alone is not a complete accumulator-to-output conversion;
4. how requantization uses `S_acc / S_out` before rounding and clipping;
5. why requantization is approximate rather than an exact reconstruction of the original FP32 value.

The module is now ready to move to the next mandatory workflow step:

```text
/design int8_quantization
```

No Python implementation or RTL modification should be generated until DESIGN and ANALYZE/PREDICT are completed and the learner confirms understanding.


---

## Project completion status update — 2026-11-18

**Project lifecycle status: COMPLETED (owner-confirmed).** The project owner confirms all phases are complete, the bitstream was programmed onto the physical Basys 3 FPGA, and expected output was observed. This supersedes earlier active-phase, pending, and pre-board-test status wording; original learning content and historical checkpoints remain preserved.

**Evidence boundary:** the owner supplied a Basys 3 board photograph in the project conversation. It documents the physical setup and illuminated indicators but does not independently establish exact latency, power, resource counts, or post-route timing. The historical docs/analysis/basys3_top_level.md report records WNS = -3.453 ns at the 100 MHz constraint; no newer timing report was supplied. Do not reinterpret the historical STA result as a pass without updated Vivado evidence.

The documented fixed demonstration vector produces accumulator 45 and requantized INT8 output 34 (0x22); LED1 and LED5 are result bits and LED8 is the latched completion indicator. The owner reports that the expected board output was observed.
