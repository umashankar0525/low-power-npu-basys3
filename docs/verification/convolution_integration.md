# Convolution Integration — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 6 — `/verify convolution_integration`  
**Status:** Verification plan complete; integration testbench and XSim measurement not yet generated or run.

---

## 1. Verification Objective

Verify that `rtl/top/convolution_integration.v` correctly integrates the already-built:

```text
control_fsm
memory_interface_dataflow
requantize_relu_pipelined
architectural activation_out register
```

into one coherent transaction:

```text
external start
 -> supervisory launch
 -> three synchronous activation/weight memory reads
 -> signed INT32 3x3 convolution result
 -> pipelined ReLU + requantization
 -> architectural INT8 output capture
 -> external done
```

The test must prove more than the final numerical output. It must prove, cycle by cycle, that:

- the transaction is launched exactly once,
- memory requests occur in the intended order,
- the correct packed words are consumed,
- the convolution result is correct,
- the requantizer samples the final result at the correct edge,
- the output register captures only the valid transaction result,
- `done` is aligned with a valid `activation_out`,
- `busy` and restart behavior obey the supervisory protocol,
- no stale value from a previous transaction leaks into a later one,
- reset returns the entire integrated path to a safe, known state.

A final `PASS` line or `error_count = 0` is not sufficient evidence by itself. The simulation result must later be explained signal by signal.

---

## 2. Explicit Assumptions

1. FPGA target: XC7A35T-1CPG236C on Basys 3.
2. Clock frequency: 100 MHz.
3. Clock period:

```text
Tclk = 10 ns
```

4. Reset is synchronous and active high.
5. External `start` is a one-clock pulse and is legal only when `busy = 0`.
6. `control_fsm` is the existing five-state Moore controller.
7. `memory_interface_dataflow` is the existing 3x3 convolution engine.
8. Activation and weight memories are modeled as synchronous one-clock-latency memories.
9. Each memory word is 32 bits and contains four signed INT8 lanes:

```text
lane 0 -> bits [7:0]
lane 1 -> bits [15:8]
lane 2 -> bits [23:16]
lane 3 -> bits [31:24]
```

10. One convolution uses three activation words and three weight words.
11. Word 2 contains the ninth useful element in lane 0 and zero padding in lanes 1..3.
12. Quantizer-generated activation and weight values are in `[-127,+127]`.
13. The current legal maximum positive 3x3 accumulator is:

```text
9 x 127 x 127 = 145161
```

14. The integration core contains no physical BRAM; the testbench provides the memory behavior.
15. The requantizer contains one registered 42-bit product stage.
16. `q_out` is combinational from the registered product.
17. `activation_out` is the architectural result register and changes only on reset or `capture_activation`.
18. The predicted accepted-start-to-done latency is 7 clock periods = 70 ns.
19. The predicted next legal accepted start is 9 clock periods after the previous accepted start.
20. Behavioral simulation does not prove synthesis resource counts, DSP mapping, timing closure, Fmax, BRAM inference, or power.

---

## 3. Verification Layers

The integration test should be evaluated in four layers.

### Layer A — External protocol

Observe:

```text
start
busy
done
activation_out
```

Prove that the external user sees a clean transaction interface.

### Layer B — Memory transaction behavior

Observe:

```text
activation_rd_en
activation_addr
activation_data
weight_rd_en
weight_addr
weight_data
```

Prove that exactly three memory requests occur, in address order `0 -> 1 -> 2`, and that the one-clock-latency memory model returns the intended words.

### Layer C — Internal integration timing

For verification/debug, hierarchical observation is permitted for:

```text
engine_start
engine_done
engine_result
capture_activation
requantized_q
u_requantize_relu_pipelined.product_reg
```

These internal signals should not define the public interface, but they are valuable for proving the exact E5/E6/E7 data association.

### Layer D — Numerical end-to-end correctness

For each directed case, calculate independently:

```text
INT8 packed memory contents
 -> 9-term signed convolution sum
 -> ReLU
 -> fixed-point requantization
 -> expected INT8 activation_out
```

The expected value must come from documented arithmetic or an independent reference, not by copying the RTL expression into the testbench.

---

## 4. Testbench Memory Model Requirement

The most important environmental requirement is that the testbench must model **one full clock of synchronous read latency**.

The memory model must behave conceptually as:

```text
on rising edge:
    if rd_en:
        data_out <= memory[addr]
```

Because nonblocking updates occur after the edge, the engine cannot consume a newly requested word on the same edge that the address is launched.

For one transaction, the intended request/response relationship is:

```text
E1: engine presents request for word 0
E2: word 0 appears; engine presents request for word 1
E3: word 1 appears; engine consumes word 0 and requests word 2
E4: word 2 appears; engine consumes word 1
E5: engine consumes word 2 and registers final result
```

A zero-latency combinational memory model is not acceptable because it would verify a different architecture.

---

## 5. Primary Integration Configuration

For most directed tests, use a nontrivial but easy-to-check requantization configuration:

```text
M_INT     = 3
FRAC_BITS = 2
```

This represents:

```text
M_hat = 3 / 4 = 0.75
```

For a positive accumulator:

```text
product = acc x 3
q_pre   = (product + 2) >> 2
q_out   = min(q_pre, 127)
```

This configuration is preferable to identity scaling for the main integration test because it proves that the parameterized requantizer is actually present in the end-to-end path rather than simply forwarding the convolution result.

---

## 6. Directed Test 1 — Reset and Idle State

### Stimulus

- Assert `rst = 1` across a rising edge.
- Keep `start = 0`.
- Keep memory contents arbitrary but known.

### Expected public outputs after the reset edge

```text
busy           = 0
done           = 0
activation_out = 0
```

### Expected engine memory interface

```text
activation_rd_en = 0
weight_rd_en     = 0
activation_addr  = 0
weight_addr      = 0
```

### Expected internal pipeline state

The requantizer product register must be zero after the reset edge.

### Why this test matters

Reset is shared by every sequential child block. This test proves the integrated system enters a known idle state rather than merely proving that the outer controller resets.

---

## 7. Directed Test 2 — Positive Unsaturated End-to-End Convolution

Use activation vector:

```text
[1,2,3,4,5,6,7,8,9]
```

and weight vector:

```text
[1,1,1,1,1,1,1,1,1]
```

### Packed activation words

```text
A0 = 0x04030201
A1 = 0x08070605
A2 = 0x00000009
```

### Packed weight words

```text
W0 = 0x01010101
W1 = 0x01010101
W2 = 0x00000001
```

### Independent convolution derivation

```text
acc = 1+2+3+4+5+6+7+8+9
    = 45
```

### Independent requantization derivation

With `M_INT=3`, `FRAC_BITS=2`:

```text
product = 45 x 3 = 135
bias    = 2^(2-1) = 2
rounded = 135 + 2 = 137
q_pre   = 137 >> 2 = 34
```

No saturation is required.

Expected architectural output:

```text
activation_out = 34
```

### Required signal-level evidence

The test must later show:

```text
three activation reads: 0,1,2
three weight reads:     0,1,2
engine_result at E5:    45
product_reg at E6:      135
requantized_q before E7:34
activation_out at E7:   34
done after E7:          1
```

This is the main end-to-end proof case.

---

## 8. Directed Test 3 — Negative Convolution Through ReLU

Use activation vector:

```text
[-1,-2,-3,-4,-5,-6,-7,-8,-9]
```

and weights all `+1`.

### Packed activation words

```text
A0 = 0xFCFDFEFF
A1 = 0xF8F9FAFB
A2 = 0x000000F7
```

### Independent convolution result

```text
acc = -(1+2+3+4+5+6+7+8+9)
    = -45
```

The requantizer performs ReLU before multiplication:

```text
acc <= 0 -> magnitude = 0
product_reg -> 0
q_out -> 0
```

Expected:

```text
engine_result  = -45
activation_out = 0
```

### Why this test matters

A final zero alone is not enough. The waveform must distinguish:

```text
correct signed convolution result = -45
then ReLU forces the requantization path to zero
```

from an accidental earlier arithmetic zero.

---

## 9. Directed Test 4 — Maximum Legal Positive Accumulator and Saturation

Use:

```text
activation[i] = 127 for all 9 terms
weight[i]     = 127 for all 9 terms
```

Independent convolution result:

```text
127 x 127 = 16129
9 x 16129 = 145161
```

This is the maximum legal positive accumulator under the current generated-data contract.

With the primary integration parameters:

```text
product = 145161 x 3 = 435483
rounded = 435483 + 2 = 435485
q_pre   = 435485 >> 2 = 108871
```

Since:

```text
108871 > 127
```

expected architectural output is:

```text
activation_out = 127
```

### Why this test matters

It proves simultaneously that:

- the 9-term INT32 accumulation reaches the correct legal maximum,
- no sign corruption occurs,
- the integrated result feeds the requantizer correctly,
- output saturation is active,
- a very large legal accumulator does not wrap before the activation stage.

---

## 10. Directed Test 5 — Parameterized Rounding Visibility

Use a vector whose convolution sum is exactly `5`.

One simple construction is:

```text
activations = [5,0,0,0,0,0,0,0,0]
weights     = [1,0,0,0,0,0,0,0,0]
```

Then:

```text
engine_result = 5
```

With `M_INT=3`, `FRAC_BITS=2`:

```text
product = 5 x 3 = 15
rounded = 15 + 2 = 17
q_pre   = 17 >> 2 = 4
```

Expected:

```text
activation_out = 4
```

### Why this test matters

This small value makes the fixed-point transformation visible without saturation. It proves that the integration wrapper passes the selected requantization parameters into the child module and that the end-to-end result is not simply the raw accumulator.

---

## 11. Directed Test 6 — E5/E6/E7 Pipeline Association

This is a timing test rather than a new numerical vector.

For a known positive transaction, monitor:

```text
engine_result
engine_done
product_reg
capture_activation
requantized_q
activation_out
done
```

The required sequence is:

### E5

```text
engine_result registers the final INT32 convolution value
engine_done becomes 1 after the edge
product_reg still corresponds to the pre-E5 engine_result
```

### E6

```text
controller enters CAPTURE_ACTIVATION
capture_activation = 1 during E6->E7
product_reg captures the product derived from the E5 final engine_result
```

### E6 -> E7

```text
rounding + right shift + saturation generate the correct requantized_q
```

### E7

```text
activation_out captures requantized_q
controller enters DONE
done becomes 1 after the edge
```

### Pass condition

The test fails if `activation_out` is captured one cycle early, one cycle late, or from the wrong `product_reg` sample.

---

## 12. Directed Test 7 — Predicted 70 ns Latency

Let `E0` be the rising edge where a legal external `start` is sampled while idle.

Expected done edge:

```text
E7
```

Elapsed periods:

```text
7
```

At 100 MHz:

```text
7 x 10 ns = 70 ns
```

The testbench must record timestamps or an edge counter at:

```text
accepted start edge
external done assertion edge
```

and compare the measured difference against exactly 7 periods.

This measurement must be edge-to-edge. `$finish` time or arbitrary stimulus delays are not valid latency measurements.

---

## 13. Directed Test 8 — Busy Duration and Legal Restart

For one complete transaction:

```text
E0 accepted start
E7 done becomes active
E8 controller returns to IDLE; busy becomes 0
```

Expected busy-high duration:

```text
E0 -> E8 = 8 periods = 80 ns
```

The earliest next legal start can be presented during E8->E9 and sampled at E9.

Therefore expected accepted-start spacing is:

```text
E0 -> E9 = 9 periods = 90 ns
```

The test should perform two legal transactions with different expected outputs.

Example:

```text
transaction 1 -> expected activation_out = 34
transaction 2 -> expected activation_out = 4
```

The second result must replace the first only at the correct capture edge.

### Why this matters

Using different outputs proves that the second `done` event is associated with new data and not a stale result from the previous pipeline state.

---

## 14. Directed Test 9 — Start While Busy Is Ignored

During a valid transaction, pulse external `start` again while `busy=1`.

Expected:

- no second internal `engine_start` pulse,
- no restart of memory address sequence,
- no extra activation/weight read requests,
- exactly one convolution result,
- exactly one activation capture,
- exactly one external `done`.

A useful scoreboard invariant is:

```text
one legal accepted start -> exactly three activation reads and three weight reads
```

An illegal extra start while busy must not increase those counts.

---

## 15. Directed Test 10 — Reset During an Active Transaction

Start a normal transaction, then assert synchronous reset before convolution completion.

After the reset edge, expected public behavior is:

```text
busy           = 0
done           = 0
activation_out = 0
```

Expected engine behavior:

```text
activation_rd_en = 0
weight_rd_en     = 0
engine result/accumulator state reset according to child RTL
```

Expected requantizer state:

```text
product_reg = 0
```

No completion pulse from the abandoned transaction may appear later.

Then release reset and run a new legal transaction to prove recovery without re-elaboration.

---

## 16. Directed Test 11 — Maximum-Width Requantization Integration Check

The Phase-6 unit verification already targeted the maximum-width requantizer case. Integration should include one secondary parameter configuration to prove the engine's legal maximum result crosses the module boundary without truncation.

Use:

```text
M_INT     = 16777215
FRAC_BITS = 42
```

and the maximum legal convolution:

```text
engine_result = 145161
```

Independent arithmetic:

```text
raw product
= 145161 x 16777215
= 2435397306615

rounding bias
= 2^41
= 2199023255552

rounded numerator
= 4634420562167

q_pre
= 4634420562167 >> 42
= 1
```

Expected:

```text
activation_out = 1
```

### Why this test matters

The final value `1` looks small, but the internal path exercises:

- maximum legal 18-bit positive accumulator magnitude,
- full 24-bit coefficient,
- 42-bit product,
- 43-bit rounding intermediate,
- maximum legal fractional shift.

For the integration test, the key evidence is that the engine-generated `145161` reaches the requantizer intact and produces the same maximum-width result already expected from the numerical contract.

---

## 17. Continuous Invariants

The future testbench should continuously check these properties for valid operation:

1. `activation_rd_en` and `weight_rd_en` must assert together for this architecture.
2. Activation and weight addresses must match on every simultaneous request.
3. Legal request addresses are only `0`, `1`, and `2`.
4. Exactly three activation requests occur per successful transaction.
5. Exactly three weight requests occur per successful transaction.
6. Request address order is exactly `0 -> 1 -> 2`.
7. `done=1` implies `busy=1` under the current controller contract.
8. `done=1` implies `activation_out` already equals the expected completed result.
9. `activation_out` must not change while `capture_activation=0`, except during reset.
10. `capture_activation` must occur exactly once per successful transaction.
11. External `done` must occur exactly once per successful transaction.
12. `done` must never occur before the activation capture event.
13. No extra internal engine launch may occur from a `start` pulse while busy.
14. No `X` or `Z` is permitted on the public outputs for known valid stimulus.
15. No stale transaction result may appear as the completed output of the next transaction.

---

## 18. Scoreboard Counts Per Successful Transaction

For one successful transaction, expected event counts are:

```text
accepted external start   = 1
internal engine_start     = 1
activation read requests  = 3
weight read requests      = 3
engine_done               = 1
capture_activation        = 1
external done             = 1
architectural output update = 1
```

The scoreboard should keep separate counters for each event.

A final count match is necessary but not sufficient: ordering and data correctness must also be checked.

---

## 19. Signal-by-Signal Nominal Timeline

For the positive unsaturated case, the future result review should be able to explain a timeline equivalent to:

| Edge | Important signal behavior |
|---|---|
| E0 | external `start` accepted; controller enters launch path; `busy` becomes high |
| E1 | `engine_start` sampled by engine; request address 0 launched |
| E2 | memory returns word 0; request address 1 launched |
| E3 | engine consumes word 0; memory returns word 1; request address 2 launched |
| E4 | engine consumes word 1; memory returns word 2; read enables deassert |
| E5 | engine consumes word 2; `engine_result=45`; `engine_done=1` after edge |
| E6 | controller observes completion; `product_reg=135`; `capture_activation=1` |
| E6->E7 | `requantized_q=34` after rounding/shift/saturation settles |
| E7 | `activation_out=34`; controller enters DONE; `done=1` after edge |
| E8 | controller returns IDLE; `busy=0`; output remains 34 |

The exact simulator display time may be offset by reset/stimulus setup, but the **edge spacing** must match this schedule.

---

## 20. Failure Localization Strategy

If the final INT8 result is wrong, debug should proceed in this order:

```text
1. Were addresses 0,1,2 requested correctly?
2. Did the one-cycle memory model return the intended packed words?
3. Did the signed lane unpacking produce the intended operands?
4. Did engine_result equal the independent 9-term convolution sum?
5. Did product_reg capture the product from that final engine_result at E6?
6. Did rounding/shift/saturation produce the independently expected q_out?
7. Did activation_out capture q_out only at the intended E7 edge?
8. Was done asserted only after activation_out became valid?
```

This ordering prevents an integration bug from being misdiagnosed as an arithmetic bug.

---

## 21. What a Passing Behavioral Test Will Prove

A complete zero-error integration simulation with the required waveform evidence will support the claims that:

- child modules are wired correctly,
- the synchronous memory contract is respected,
- one 3x3 convolution reads the intended three packed words,
- signed convolution arithmetic reaches the expected INT32 result for directed cases,
- the pipelined requantizer receives the correct transaction result,
- architectural activation capture is cycle-aligned with the requantizer pipeline,
- `done=1` coincides with a valid registered output,
- the predicted 70 ns start-to-done latency is either confirmed or contradicted by measurement,
- legal repeated transactions do not contaminate each other,
- reset safely aborts an active transaction.

---

## 22. What Behavioral Simulation Will Not Prove

Even a fully passing XSim integration test will **not** prove:

```text
actual Slice LUT count
actual Slice FF count
actual DSP48E1 count
whether the four INT8 multipliers remain in LUT/carry fabric
whether physical memories infer BRAM
10 ns setup closure after full integration
hold timing
maximum clock frequency
routing congestion
power consumption
```

Those require synthesis/implementation reports and belong to later measurement and analysis-update work.

---

## 23. Pass Criteria

The integration test passes only if all required directed scenarios complete with zero errors **and** the recorded signal sequence demonstrates why they pass.

Minimum pass criteria are:

- reset produces a clean idle integrated state,
- one legal start produces exactly one engine launch,
- memory request sequence is exactly `0 -> 1 -> 2`, once per successful transaction,
- one-clock memory latency is respected,
- positive unsaturated case gives exact `engine_result=45` and `activation_out=34`,
- negative case gives exact `engine_result=-45` and post-ReLU `activation_out=0`,
- maximum legal accumulator case gives `engine_result=145161` and saturated output `127` under the primary parameters,
- fixed-point rounding visibility case produces exact output `4` from accumulator `5`,
- E5/E6/E7 pipeline association is correct,
- measured accepted-start-to-done interval equals the observed edge count and is compared with the 70 ns prediction,
- `busy` duration and legal restart timing match the observed controller behavior,
- start while busy produces no extra launch or memory traffic,
- back-to-back legal transactions produce independent outputs,
- reset during a transaction prevents stale completion,
- maximum-width secondary configuration preserves the legal full-width result path,
- no public valid-operation output contains `X` or `Z`.

A final simulator summary must include the number of failures, but the project will not accept `0 failures` alone without the signal-by-signal interpretation above.

---

## 24. Next Workflow Step

After the learner confirms understanding of this verification plan, proceed to:

```text
Step 7: integration testbench generation
        -> tb/integration/tb_convolution_integration.v
```

Only after the testbench exists and is reviewed should Step 8 XSim simulation and measurement be performed.
