# Memory Interface and Dataflow — Verification Plan

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Verification Engineer  
**Status:** Verification plan and testbench created; simulation measurement pending.

## 1. Verification Objective

The primary objective is to prove that `memory_interface_dataflow` correctly handles a **one-cycle synchronous BRAM read latency**.

A zero-latency memory model is not sufficient because it can make data visible earlier than real synchronous BRAM and can allow an incorrect controller schedule to appear correct.

## 2. Assumptions

- Clock frequency for latency interpretation: 100 MHz.
- Clock period: 10 ns.
- Activation and weight memories are modeled as synchronous one-cycle-latency memories.
- The DUT requests word addresses 0, 1, and 2.
- The testbench returns the data associated with a request one clock later.
- The DUT uses four INT8 lanes per returned word.
- The final word has one useful product and three zero lanes.
- Reset is synchronous to `clk`, matching the DUT implementation.

## 3. Expected Controller Schedule

For the current registered-accumulator RTL:

| Rising edge | Expected DUT behavior |
|---|---|
| 1 | `start` accepted; request address 0 |
| 2 | request address 1; word 0 is now available |
| 3 | consume word 0; request address 2; word 1 is now available |
| 4 | consume word 1; word 2 is now available |
| 5 | consume word 2; register final result; assert `done` |

The start-to-done interval is therefore predicted to be four clock periods:

`4 x 10 ns = 40 ns`.

Five rising edges participate when counting the start edge and the final done edge.

## 4. Verification Strategy

### Test 1 — Reset

Confirm that reset returns the DUT to idle:

- `done = 0`
- `result = 0`
- no memory read request
- address/control state is idle.

### Test 2 — Address sequencing

After `start`, confirm the requested addresses are exactly:

`0 → 1 → 2`

and that no unexpected fourth memory request occurs.

### Test 3 — BRAM latency alignment

The behavioral memory must intentionally delay returned data by one clock. The scoreboard records each requested address and checks that the DUT's processing state consumes the corresponding delayed word.

This is the central verification test.

### Test 4 — Partial-sum accumulation

Use three words with distinct known partial sums. A convenient test is:

- Word 0 produces `S0 = 10`
- Word 1 produces `S1 = 20`
- Word 2 produces `S2 = 30`

Expected final result:

`0 + 10 + 20 + 30 = 60`.

### Test 5 — Sign handling

Exercise positive and negative INT8 values, including negative times positive and negative times negative products. Compare the DUT result against a software-style integer reference calculation in the testbench.

### Test 6 — Maximum product/accumulation boundary

Exercise `(-128) x (-128) = 16384` and combinations that reach the known nine-product positive bound of 147456. This checks signed multiplication, partial-sum width, sign extension, and INT32 accumulation.

### Test 7 — Final-word-only activity

Set the first two words to zero and make only the useful lane of word 2 non-zero. This detects an off-by-one-word error because the final contribution must appear only when word 2 is consumed.

### Test 8 — Busy/start behavior

Assert `start` while the controller is already processing a convolution. The test should document whether the interface intentionally ignores the new start or has another defined behavior. The current FSM has no explicit restart path while busy, so the expected behavior is that the active transaction continues.

## 5. Scoreboard Method

The testbench computes the expected mathematical result independently:

`expected = sum(input[i] * weight[i])` for `i = 0..8`.

The testbench does not infer correctness from `done` alone. It checks:

1. memory request sequence,
2. one-cycle memory response behavior,
3. final result,
4. exact completion timing.

## 6. Why the One-Cycle Memory Model Matters

With a combinational/zero-latency model, changing the address can immediately change `activation_data` and `weight_data`. A controller that incorrectly assumes data is available in the same edge can therefore pass.

With a synchronous model, address N is requested first and its data becomes valid only after the corresponding clock edge. The DUT must therefore have the correct FSM state and timing to consume the returned word.

The testbench deliberately models this latency so the simulation represents the architectural contract the controller was designed for.

## 7. Pass Criteria

The module passes only if all of the following are true:

- reset returns to idle;
- address sequence is exactly `0,1,2`;
- each returned word is consumed one cycle after its request;
- partial sums contribute in the correct order;
- signed arithmetic matches the reference model;
- final result matches the reference model;
- `done` occurs at the predicted completion edge;
- no extra memory request occurs after the final word;
- a start while busy does not corrupt the active transaction.

A passing result is not considered sufficient by itself. The waveform must show why each signal has the expected value at each relevant edge.

## 8. Measurement to Perform in Vivado XSim

Record:

- cycle number of `start` acceptance,
- cycle numbers and values of `activation_addr` and `weight_addr`,
- cycle in which each memory word becomes valid,
- cycle in which each partial sum is captured,
- accumulator progression,
- cycle of `done`,
- final `result`.

Then compare measured values against the predictions in `docs/analysis/memory_interface_dataflow.md`.

## 9. Verification Conclusion

The verification is specifically designed to catch the most important architectural risk: confusing a synchronous BRAM's **request timing** with its **data-availability timing**. The behavioral memory model therefore contains an explicit one-cycle delay. Simulation is still required before declaring the RTL correct.
