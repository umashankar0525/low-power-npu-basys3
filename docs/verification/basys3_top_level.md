# Basys 3 Top-Level Integration — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 6 — `/verify basys3_top_level`  
**Status:** VERIFICATION PLAN COMPLETE — understanding gate required before Step 7 testbench generation.

---

## 1. Verification Objective

Verify that the Phase-8 board wrapper correctly converts asynchronous mechanical board controls into a legal accelerator transaction, supplies the existing `convolution_integration` core with the required one-clock synchronous operand-memory behavior, and converts the short core completion event into a persistent board-visible status.

The verification target is not only the final LED value. The simulation must prove the complete causal chain:

```text
btn_start
 -> synchronizer
 -> debounce
 -> one-cycle start event
 -> busy mask
 -> convolution_integration
 -> three synchronous activation/weight reads
 -> activation_out = 34
 -> raw core_done pulse
 -> persistent done_latched / led_done
```

A final `PASS` message alone is not sufficient. Every passing directed test must later be explained signal by signal.

---

## 2. RTL Under Verification

Primary DUT:

```text
rtl/top/basys3_top_level.v
```

Board-infrastructure child:

```text
rtl/infrastructure/button_conditioner.v
```

Operand-memory child:

```text
rtl/memory/operand_bram_dual_read.v
```

Existing accelerator child:

```text
rtl/top/convolution_integration.v
```

The accelerator mathematics and Phase-7 transaction controller are not reimplemented in Phase 8; the board top integrates them.

---

## 3. Explicit Assumptions

1. Target clock is 100 MHz.
2. Clock period is:

```text
Tclk = 1 / 100 MHz = 10 ns
```

3. Hardware debounce default is 1,000,000 cycles = 10 ms.
4. Behavioral verification will override the debounce count with a small value such as 4 cycles so simulation remains practical.
5. Reducing the debounce count changes only human-interface filtering latency; it does not change the accelerator's 7-cycle compute protocol.
6. The board bring-up core parameters are:

```text
M_INT     = 3
FRAC_BITS = 2
```

7. Operand memory initialization is fixed by RTL for the first board demonstration.
8. Activation vector is:

```text
[1,2,3,4,5,6,7,8,9]
```

9. Weight vector is:

```text
[1,1,1,1,1,1,1,1,1]
```

10. Expected accumulator is 45.
11. Expected requantized output is 34 (`8'b0010_0010`).
12. Operand memory must behave as a one-clock synchronous read memory.
13. `core_done` is a one-cycle protocol event.
14. `led_done` is driven by a board-side persistent latch.
15. Behavioral simulation does not prove BRAM inference, resource utilization, post-route timing, Fmax, or power.

---

## 4. Verification Configuration

For the main integration testbench, use:

```text
DEBOUNCE_CYCLES = 4
DEBOUNCE_WIDTH  = 2
```

because:

```text
2^2 = 4
```

so a 2-bit counter can represent the required threshold for the shortened verification configuration.

The 100 MHz clock remains unchanged. Therefore one simulated debounce count interval is:

```text
4 cycles x 10 ns = 40 ns
```

The synchronizer adds additional clocked latency before the debounce counter sees a changed input. The testbench should therefore verify the required ordering and minimum-stability behavior rather than treating an asynchronous button transition as an exactly timed synchronous input.

For the specific busy-mask stress test, a second DUT instance or a dedicated test configuration may use:

```text
DEBOUNCE_CYCLES = 1
DEBOUNCE_WIDTH  = 1
```

so a release-and-repress sequence can generate a second debounced rising event while the accelerator is still busy.

---

## 5. Verification Layers

### Layer A — Board-facing behavior

Observe:

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

Prove that the external board interface behaves deterministically.

### Layer B — Button-conditioning behavior

Hierarchical observation is permitted for:

```text
u_start_conditioner.sync_ff1
u_start_conditioner.sync_ff2
u_start_conditioner.stable_count
u_start_conditioner.level
u_start_conditioner.rise_pulse

u_reset_conditioner.sync_ff1
u_reset_conditioner.sync_ff2
u_reset_conditioner.stable_count
u_reset_conditioner.level
```

These are verification/debug signals, not public interface requirements.

### Layer C — Core transaction behavior

Observe through the top hierarchy:

```text
core_start
core_busy
core_done
activation_rd_en
activation_addr
activation_data
weight_rd_en
weight_addr
weight_data
core_activation_out
```

Prove that the wrapper generates exactly one legal accelerator transaction for one accepted button event.

### Layer D — Internal memory behavior

Observe the registered memory outputs and request addresses to prove:

```text
request at edge N
 -> corresponding data visible after edge N
 -> accelerator consumes it on the later scheduled edge
```

### Layer E — Human-visible completion behavior

Observe:

```text
core_done
done_latched
led_done
```

Prove that the one-cycle protocol event is converted into a persistent board indication without changing core timing.

---

## 6. Independent Numerical Reference

The board image uses:

```text
activation words:
0x04030201
0x08070605
0x00000009

weight words:
0x01010101
0x01010101
0x00000001
```

Independent convolution calculation:

```text
1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 = 45
```

Requantization:

```text
product = 45 x 3 = 135
bias    = 2^(2-1) = 2
rounded = 135 + 2 = 137
q       = 137 >> 2 = 34
```

Expected board result:

```text
led_result = 8'b0010_0010
```

The testbench must derive or hard-code this documented independent expectation; it must not compute the expected result by copying the DUT implementation expression.

---

## 7. Directed Test 1 — Power-Up and Idle

### Stimulus

- Start with both buttons low.
- Run several 100 MHz cycles before any press.

### Expected behavior

```text
led_done            = 0
core_start          = 0
core_busy           = 0
core_done           = 0
core_activation_out = 0
led_result          = 0
```

No memory read request should occur.

### Why this matters

The reset-button conditioner cannot be reset by its own cleaned output, so deterministic FPGA-style initialization is part of the implementation strategy. This test checks that the simulated power-up state is known before a physical reset press is used.

---

## 8. Directed Test 2 — Reset Button Conditioning

### Stimulus

Generate a reset-button waveform containing short toggles shorter than the configured debounce threshold, followed by a stable high interval long enough to qualify, then a stable release.

### Required evidence

Short bounce intervals must not assert the clean reset level.

After sufficient stable-high time:

```text
reset_level = 1
```

Because the accelerator reset is synchronous, the core's sequential state is cleared on the following active clock edge that samples `reset_level = 1`.

Expected cleared behavior:

```text
core_busy           = 0
core_done           = 0
core_activation_out = 0
led_done            = 0
```

After a sufficiently debounced release, normal operation must resume.

### Important timing distinction

The edge that changes `reset_level` and the edge that resets all core sequential state are not conceptually the same event. The clean reset level is generated by clocked wrapper logic; the core then samples that synchronous level on a clock edge.

---

## 9. Directed Test 3 — Start Bounce Rejection

### Stimulus

Apply several start-button pulses/toggles shorter than the shortened verification debounce threshold.

### Expected behavior

```text
start_rise = 0
core_start = 0
```

and therefore:

```text
no memory requests
no core busy interval
no core done event
led_done remains unchanged
```

### Pass condition

Mechanical-like bounce must not accidentally launch the accelerator.

---

## 10. Directed Test 4 — One Stable Press Generates Exactly One Start

### Stimulus

After reset is released and the system is idle, hold `btn_start` high long enough to pass synchronization and debounce.

### Expected behavior

The accepted debounced level rises once, producing exactly one one-clock `start_rise` pulse.

Since the core is idle:

```text
core_start = 1 for exactly one clock interval
```

Required transaction counts:

```text
core_start pulses        = 1
activation request cycles = 3
weight request cycles     = 3
core_done pulses          = 1
```

### Long-hold requirement

Continue holding the button high after the first transaction. No second `start_rise` or `core_start` may be generated merely because the button remains pressed.

This proves that a level input is converted into an event.

---

## 11. Directed Test 5 — Memory Request Order and One-Clock Read Contract

For the nominal transaction, monitor both memory interfaces.

Expected request sequence:

```text
activation_addr : 0 -> 1 -> 2
weight_addr     : 0 -> 1 -> 2
```

Expected request symmetry:

```text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
```

for each of the three request cycles.

Expected returned data:

```text
addr 0:
activation_data = 0x04030201
weight_data     = 0x01010101

addr 1:
activation_data = 0x08070605
weight_data     = 0x01010101

addr 2:
activation_data = 0x00000009
weight_data     = 0x00000001
```

The testbench must explicitly demonstrate that the requested word becomes visible only after the requesting rising edge because the memory uses registered nonblocking read outputs.

A combinational same-cycle interpretation is a failure because it would violate the Phase-7 memory contract.

---

## 12. Directed Test 6 — Nominal End-to-End Result

For one clean start event, independently expect:

```text
engine accumulator = 45
requantized result = 34
```

Required final board outputs:

```text
led_result = 8'b0010_0010
```

The LED result must remain stable after completion because `activation_out` is already the architectural holding register in the accelerator core.

A passing result must be accompanied later by the memory sequence and core protocol evidence; checking only decimal 34 is insufficient.

---

## 13. Directed Test 7 — Core Latency Is Still 70 ns

Measure from the rising edge where internal `core_start` is legally sampled by the accelerator while idle to the rising edge/event where `core_done` becomes asserted.

Predicted periods:

```text
7 cycles
```

At 100 MHz:

```text
7 x 10 ns = 70 ns
```

### Important distinction

Do **not** measure from the physical `btn_start` transition. That interval includes synchronization and debounce latency and therefore measures the human-interface path, not accelerator compute latency.

The board wrapper passes this test only if adding button/memory/status logic did not alter the Phase-7 core transaction schedule.

---

## 14. Directed Test 8 — `done_latched` Timing and Persistence

Expected raw core behavior:

```text
core_done = 1 for one controller DONE interval
```

Expected board behavior:

- On the clock edge where the controller first enters DONE, `core_done` becomes high after the edge.
- `done_latched` therefore still contains its previous value immediately after that edge.
- On the following rising edge, the board status register samples the high `core_done` and sets:

```text
done_latched = 1
led_done     = 1
```

The LED must then remain high after raw `core_done` returns low.

It remains high until either:

```text
clean reset
or
a newly accepted core_start
```

### Why this matters

This proves that board observability is intentionally one registered event behind the raw protocol signal while leaving core latency unchanged.

---

## 15. Directed Test 9 — Release Is Required Before Another Press Event

After one successful transaction, keep `btn_start` high.

Expected:

```text
no second start event
```

Then drive the physical button low long enough for the debouncer to accept the released state.

Only after that accepted low state should a later stable-high press be able to generate another `start_rise`.

This verifies the complete press-release-press human-interface behavior rather than only the first rising event.

---

## 16. Directed Test 10 — New Accepted Start Clears Completion LED

After `led_done = 1`, release the start button fully and issue another legal press while the core is idle.

At the edge where the new `core_start` is sampled:

```text
done_latched -> 0
led_done     -> 0
```

The second transaction then runs normally and, after its raw `core_done` event is sampled by the board status register, `led_done` returns to 1.

The nominal memory image is fixed, so the expected result remains 34 for both transactions. Transaction counts, not output difference, prove that a second independent transaction occurred.

---

## 17. Directed Test 11 — Busy-Mask Stress Test

This test must verify the implemented condition:

```text
core_start = start_rise & ~core_busy
```

The important event is **not merely that the physical button was pressed while busy**. Because synchronization and debounce add latency, a physical press that begins while busy could produce its debounced `start_rise` only after the core has returned idle.

Therefore the test must deliberately arrange for:

```text
start_rise = 1
and
core_busy  = 1
```

in the same cycle.

A shortened debounce configuration such as one cycle may be used to make a release-and-repress sequence fit inside the existing busy interval.

Expected:

```text
core_start = 0
```

and the in-flight transaction must not restart.

Required invariants for that transaction:

```text
exactly 3 activation requests
exactly 3 weight requests
exactly 1 core_done pulse
```

No queued retry is expected. If the debounced rise event occurs while busy, that event is discarded.

---

## 18. Directed Test 12 — Reset Clears Board Status

First complete a normal transaction so:

```text
led_result = 34
led_done   = 1
```

Then apply a valid debounced reset press.

After the synchronous core-reset effect is observed:

```text
core_busy           = 0
core_done           = 0
core_activation_out = 0
led_result          = 0
led_done            = 0
```

Then release reset and perform another transaction to prove recovery without re-elaboration.

Because the production debounce interval is much longer than the 70 ns accelerator transaction, this is primarily a board-state reset/recovery test rather than a claim that a human reset press can abort the NPU before a 70 ns transaction naturally completes.

---

## 19. Continuous Invariants / Scoreboard Requirements

The future testbench should continuously enforce at least these invariants:

```text
core_start -> one clock wide
start_rise -> one clock wide
activation_rd_en == weight_rd_en
activation_addr == weight_addr on valid reads
one accepted core_start -> exactly 3 paired memory request cycles
one accepted core_start -> exactly 1 core_done event
led_result == core_activation_out
led_done == done_latched
```

When no legal transaction is running, unexpected memory-read activity is an error.

The scoreboard should count button events, accepted core starts, memory request cycles, raw done events, and persistent done-latch transitions separately. These counts prove that one physical interaction does not accidentally create multiple accelerator transactions.

---

## 20. What Behavioral Simulation Cannot Prove

Even if every directed test passes, behavioral simulation still does **not** prove:

```text
BRAM inference
RAMB18/RAMB36 primitive count
LUT/FF/CARRY/DSP utilization
IOB count after synthesis
100 MHz post-route timing closure
critical setup/hold path
actual Basys-3 package-pin correctness
real mechanical bounce behavior on one physical switch
power consumption
```

Those require later synthesis, implementation, timing reports, constraints, and physical-board evidence.

In particular:

```text
(* ram_style = "block" *)
```

must not be treated as proof of BRAM use.

---

## 21. Expected Verification Evidence at Step 8

When simulation is eventually run, collect:

```text
XSim transcript
waveform around reset qualification
waveform around bounced start input
waveform around accepted start
memory request/address/data waveforms
core_start / core_busy / core_done timing
led_result transition to 34
core_done -> done_latched timing
second-transaction evidence
busy-mask stress-test evidence
error_count / PASS summary
```

The measured results must then be explained signal by signal and compared with the predictions from `docs/analysis/basys3_top_level.md`.

---

## 22. Verification Understanding Gate

Before Step 7 testbench generation, the learner must explain in their own words:

1. Why the testbench shortens the debounce threshold without changing the 100 MHz clock or NPU compute schedule.
2. Why a bouncing physical start input must produce zero `core_start` events until it is stable long enough.
3. Why one held button press must produce exactly one start event.
4. Why the memory test must prove request order `0 -> 1 -> 2` and one-clock read latency.
5. Why the 70 ns measurement starts at internal accepted `core_start`, not at the physical button transition.
6. Why `done_latched` is expected to become persistent one clock after the raw `core_done` event becomes visible.
7. Why a busy-mask test must align the **debounced `start_rise` event** with `core_busy=1`, rather than merely pressing the raw button sometime during busy.
8. Why behavioral simulation can validate function/protocol but cannot prove BRAM mapping or post-route timing.

**Hard gate:** do not generate `tb/integration/tb_basys3_top_level.v` until these verification concepts are restated correctly.