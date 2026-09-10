# ReLU Timing Wrapper — Measured Performance Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 4 — Activation and Output Processing  
**Module:** `rtl/activation/relu_timing_wrapper.v`  
**Target:** XC7A35T-1CPG236C-1 / Basys 3  
**Status:** Functional verification measured; implementation timing pending.

## 1. Objective

Measure the functional behavior of the synchronous timing wrapper around the previously verified combinational `relu_activation` block. The wrapper is intended to create the physical timing path that will later be analyzed with a 100 MHz clock constraint:

`accumulator_reg -> relu_activation -> output_activation`

## 2. Explicit assumptions

- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- `rst` is synchronous and active high.
- `accumulator_input` is a completed signed INT32 accumulator value.
- `accumulator_reg` captures the input on a rising edge.
- `relu_activation` is combinational.
- `output_activation` captures the ReLU/saturated result on the following rising edge.
- Behavioral simulation does not measure FPGA propagation delay, routing delay, or setup slack.
- The corrected testbench drives synchronous inputs on the falling edge to avoid same-edge simulation races.

## 3. Latency derivation

At rising edge N:

`accumulator_reg <= accumulator_input`

The new accumulator value then propagates through the combinational ReLU logic during cycle N to N+1.

At rising edge N+1:

`output_activation <= relu_output`

Therefore:

`output_activation[N+1] = ReLU_saturate(input[N])`

The wrapper has exactly **one clock cycle of architectural latency** from input capture to output capture.

At 100 MHz:

`1 cycle × 10 ns/cycle = 10 ns`

This is latency, not the ReLU combinational propagation delay. The latter must be measured by implementation timing.

## 4. Functional simulation measurement

Vivado 2018.2 XSim successfully compiled and elaborated:

- `relu_activation`
- `relu_timing_wrapper`
- `tb_relu_timing_wrapper`

The corrected testbench was run first to 1000 ns and then continued with `run 3000ns`.

The final XSim summary was:

`PASS: relu_timing_wrapper verification completed with 113 passes and 0 failures.`

The simulator ended at:

`$finish called at time : 2216 ns`

This means the complete verification sequence finished naturally before the 3000 ns run limit.

## 5. Measured results

The final run demonstrated:

- synchronous reset behavior: PASS
- signed INT32 negative values -> 0: PASS
- 0 -> 0: PASS
- positive values within INT8 range -> unchanged: PASS
- 128 and larger positive values -> 127: PASS
- INT32 maximum -> 127: PASS
- back-to-back sample alignment: PASS
- randomized signed INT32 inputs: PASS
- total failures: **0**

The previously observed `-25 -> 42` mismatch did not reappear after changing stimulus timing so that the input is established on `negedge clk` before the intended capture edge.

## 6. Why 113 passes is the correct result

The final pass count consists of the complete verification suite, including reset, directed tests, back-to-back tests, and 100 randomized transactions.

The exact decomposition is determined by the testbench's implemented checks; the important acceptance criterion is the final reported result:

`113 passes, 0 failures`

Because `$finish` occurred at 2216 ns, the testbench completed before the 3000 ns simulation window expired.

## 7. Timing interpretation

The successful behavioral simulation proves functional cycle alignment, but it does **not** prove 100 MHz timing closure.

The actual implementation timing question remains:

`accumulator_reg Q -> ReLU logic -> output_activation D`

For a 100 MHz clock:

`Tclk = 10 ns`

The setup requirement is derived from:

`Tclk >= Tclk->Q + TReLU + Trouting + Tsetup`

or equivalently:

`setup slack = data required time - data arrival time`

A positive setup slack means the implemented path meets the 10 ns requirement. A negative slack means a timing violation.

## 8. Predicted vs measured status

| Metric | Prediction | Measurement | Status |
|---|---:|---:|---|
| Wrapper architectural latency | 1 cycle | 1 cycle observed | MATCH |
| Clock period | 10 ns | 10 ns testbench clock | MATCH |
| Functional failures | 0 | 0 | MATCH |
| Directed boundary behavior | Correct | PASS | MATCH |
| Back-to-back alignment | Correct | PASS | MATCH |
| Randomized tests | 100 planned | 100 completed | MATCH |
| Physical ReLU delay | Small, TBD | Not yet measured | TBD |
| Setup slack at 100 MHz | Positive expected | Not yet measured | TBD |
| Hold slack | Not yet predicted quantitatively | Not measured | TBD |

## 9. Remaining measurement

The next performance step is implementation timing, not another functional simulation.

Required sequence:

1. Create/apply the actual 100 MHz XDC clock constraint.
2. Synthesize the integrated timing path.
3. Implement the design so routing delay is included.
4. Run `report_timing` or `report_timing_summary` for setup and hold.
5. Record worst negative slack, worst hold slack, data-path delay, and the actual critical path.
6. Compare measured timing against the 10 ns clock-period requirement.

The standalone combinational ReLU synthesis result of 13 LUTs, 0 FFs, 0 DSPs, and 0 BRAMs remains a resource measurement; it is not a timing-closure measurement.

## 10. Conclusion

The corrected timing-wrapper verification is functionally complete: **113 passes and 0 failures**, with all 100 randomized transactions completed by 2216 ns.

The earlier same-edge stimulus race has been eliminated. The wrapper's one-cycle latency is now demonstrated consistently.

The project should now proceed to implementation timing analysis with the real 100 MHz clock constraint. No timing number should be claimed until that measurement is performed.
