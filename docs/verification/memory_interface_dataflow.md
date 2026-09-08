# Memory Interface and Dataflow — Verification Report

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Verification Engineer  
**Status:** **XSim behavioral simulation passed**

## 1. Verification Objective

The primary objective was to prove that `memory_interface_dataflow` correctly handles a **one-cycle synchronous BRAM read latency**.

The testbench intentionally models synchronous memory behavior instead of zero-latency combinational reads. This prevents an incorrect controller from appearing correct merely because memory data arrives unrealistically early.

## 2. Assumptions

- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- Activation and weight memories have one-cycle synchronous read latency.
- The DUT requests addresses 0, 1, and 2.
- The final word contains one useful lane and three zero lanes.
- Reset is synchronous to `clk`.

## 3. Expected Timing Derivation

For the current registered-accumulator RTL:

| Rising edge | Expected behavior |
|---|---|
| 1 | `start` accepted; request word 0 |
| 2 | request word 1; word 0 becomes valid after the edge |
| 3 | consume word 0; request word 2; word 1 becomes valid after the edge |
| 4 | consume word 1; word 2 becomes valid after the edge |
| 5 | consume word 2; register final result; assert `done` |

There are five participating rising edges, but the elapsed interval from the start-accepting edge to the done edge is four clock periods:

`4 x 10 ns = 40 ns`.

## 4. Testbench Stimulus

The three packed memory words were deliberately chosen to produce distinct partial sums:

- Word 0: `S0 = 10`
- Word 1: `S1 = 20`
- Word 2: `S2 = 30`

Therefore the independent expected result is:

`0 + 10 + 20 + 30 = 60`.

The testbench also asserted `start` while the DUT was busy to check that the active transaction was not corrupted.

## 5. Measured XSim Results

Vivado XSim reported:

`PASS: memory latency, address sequencing, accumulation, and completion timing verified.`

The simulation completed at approximately **76 ns** because the testbench performs its final checks one clock after completion before calling `$finish`.

The waveform shows:

- `activation_addr`: 0 → 1 → 2
- `weight_addr`: 0 → 1 → 2
- `request_count`: 3
- `error_count`: 0
- final `result`: `0x0000003C` = 60 decimal
- `done`: asserted only for the completion pulse

The observed final result of 60 agrees with the independently derived reference result.

## 6. Signal-by-Signal Interpretation

### `start`

`start` is accepted only while the FSM is in `ST_IDLE`. The testbench also asserted `start` while busy; the active computation continued without being restarted or corrupted.

### `activation_rd_en` and `weight_rd_en`

Both enables are asserted for exactly the three required memory request cycles. The measured `request_count = 3` confirms there was no fourth request.

### `activation_addr` and `weight_addr`

Both memories follow the required sequence:

`0 → 1 → 2`.

The testbench also checks that their addresses agree during every request.

### `activation_data` and `weight_data`

The behavioral memories update their outputs with nonblocking assignments on the rising edge. Therefore the requested word becomes visible after that edge rather than before it. This models the one-cycle synchronous-read contract.

The waveform/testbench checks confirm that word 0 is available after the request for address 0, word 1 after the request for address 1, and word 2 after the request for address 2.

### `accumulator`

Measured progression:

`0 → 10 → 30`

The third partial sum is incorporated directly into the registered `result`, giving:

`30 + 30 = 60`.

This demonstrates that the controller did not consume the memory words one cycle too early.

### `done`

`done` is low before completion, high on the final-word completion edge, and low again on the following clock. The testbench therefore verifies that it behaves as a one-cycle completion pulse.

### `result`

The final registered result is:

`60 decimal = 0x0000003C`.

It remains 60 after `done` returns low.

## 7. Why This Proves BRAM-Latency Handling

The strongest evidence is not simply the final value of 60. The testbench uses a synchronous memory model and checks the temporal relationship between:

1. memory request,
2. delayed memory response,
3. accumulator update.

For example, after the first request, the returned word is visible at the next edge/cycle, while the accumulator remains zero until the following processing edge. This demonstrates that the controller does not treat the BRAM response as immediately available in the request edge.

If the controller had consumed the data one cycle too early, the accumulator checks would fail and the final result would not reliably be 60 under this memory model.

## 8. Observed vs Predicted

| Metric | Predicted | Measured |
|---|---:|---:|
| Clock period | 10 ns | 10 ns |
| Memory requests | 3 | 3 |
| Address sequence | 0, 1, 2 | 0, 1, 2 |
| Partial sum 0 | 10 | 10 |
| Partial sum 1 | 20 | 20 |
| Partial sum 2 | 30 | 30 |
| Final result | 60 | 60 (`0x3C`) |
| Start → done | 40 ns | 40 ns by edge-to-edge schedule |
| Error count | 0 | 0 |
| Simulation status | Pass required | **PASS** |

## 9. Important Note About the 76 ns `$finish` Time

The waveform cursor is near 76 ns when the simulation ends. This should **not** be interpreted as the controller latency.

The testbench accepts `start` on an earlier clock edge, reaches `done` on the fifth participating edge, then waits one additional clock to verify that `done` returns low and `result` remains stable before calling `$finish`.

Therefore the relevant controller measurement is **start edge → done edge = 40 ns**, not 76 ns.

## 10. Non-Fatal Vivado Message

Vivado 2018.2 printed a Webtalk message indicating that it could not read a path beginning with `C:/Users/UMA`. This occurred during the Webtalk/elaboration reporting step and did **not** prevent Verilog compilation, elaboration, or XSim execution.

The simulation itself compiled, elaborated, ran, printed the PASS message, and called `$finish` normally.

## 11. Verification Conclusion

**PASS.** The current `memory_interface_dataflow` controller correctly handles the modeled one-cycle synchronous memory latency for the verified transaction.

The verification demonstrates:

- correct request sequencing,
- correct delayed-data alignment,
- correct running accumulation,
- correct final result,
- correct completion timing,
- no extra memory request,
- no corruption from `start` while busy.

This establishes functional confidence for the current memory/dataflow schedule. It does not yet replace broader signed-arithmetic stress testing or post-synthesis timing/resource verification.

## 12. Next Required Step

Update the performance analysis with these measured simulation results, then proceed to design review. Additional randomized and boundary-value tests should be added before considering the verification suite complete.
