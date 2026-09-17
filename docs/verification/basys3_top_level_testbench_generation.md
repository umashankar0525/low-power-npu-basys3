# Basys 3 Top-Level Integration — Testbench Generation Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 7 — testbench generation  
**Status:** TESTBENCH GENERATED — simulation has not yet been run.

---

## 1. Generated Testbench

The Phase-8 integration testbench is:

```text
tb/integration/tb_basys3_top_level.v
```

The testbench instantiates `basys3_top_level` with:

```text
DEBOUNCE_CYCLES = 4
DEBOUNCE_WIDTH  = 3
```

while keeping the hardware clock unchanged at:

```text
100 MHz
10 ns period
```

Only the human-interface debounce waiting time is shortened. The accelerator timing contract is not changed.

---

## 2. Verification Scope Implemented

The generated testbench contains directed checks for:

```text
physical reset conditioning
button bounce rejection
single-start behavior for a held button
accepted core_start generation
busy-mask behavior while core_busy = 1
operand request sequence 0 -> 1 -> 2
paired activation/weight read enables
one-clock synchronous memory response
70 ns accepted-start-to-core_done latency
board result = 34
raw core_done pulse count
done_latched / led_done persistence
reset during an active transaction
post-reset recovery
```

The testbench therefore checks the board wrapper, memory contract, core transaction boundary, and human-visible status behavior together.

---

## 3. Latency Measurement Boundary

The testbench does not measure accelerator latency from the physical `btn_start` transition.

Instead it records the rising clock edge at which:

```text
core_start == 1
```

is already present in the active region and is therefore sampled by `convolution_integration`.

The expected raw completion interval is:

```text
7 cycles x 10 ns = 70 ns
```

This separates board-interface delay from accelerator compute latency.

---

## 4. Memory-Latency Monitor

The memory monitor explicitly distinguishes current requests from returned data.

At a rising edge:

```text
current rd_en/address
```

causes the operand BRAM outputs to update after that edge through nonblocking assignment semantics.

Therefore, before the NBA update at the next relevant edge, the visible memory data must correspond to the previous request.

The scoreboard records the current expected activation and weight words, then checks them on the following clock edge.

This verifies the same one-clock synchronous-read contract used by the Phase-7 convolution schedule.

---

## 5. Busy-Mask Test

A physical second button press is not sufficient to guarantee that the internal start event occurs while the core is busy because synchronization and debouncing delay the event.

The testbench therefore directly exercises the internal verification point:

```text
start_rise = 1
core_busy  = 1
```

and checks:

```text
core_start = 0
```

The hierarchical `force/release` is limited to the internal `start_rise` test point. It does not alter `core_busy` or the accelerator state.

This isolates the exact combinational busy-mask property under test.

---

## 6. Completion-Latch Timing

The testbench distinguishes:

```text
raw core_done
```

from:

```text
done_latched / led_done
```

At the edge where the controller enters DONE, `core_done` becomes visible after the edge.

The board-level `done_latched` register can only sample that high value at the following rising edge.

Therefore the expected sequence is:

```text
raw core_done rises
led_done still 0 in that cycle
next rising edge
led_done becomes 1 and remains high
```

This is board observability latency, not accelerator compute latency.

---

## 7. Reset-During-Transaction Test

With the shortened four-cycle debounce threshold, the physical reset button is asserted immediately after an accepted transaction start.

The intended sequence allows the clean reset level to become active while the accelerator transaction is still in progress.

The test then checks that synchronous reset clears:

```text
core_busy
core_done
activation_out / led_result
done_latched / led_done
```

and that the abandoned transaction does not later emit a completion pulse.

A subsequent clean transaction must complete normally to prove recovery.

---

## 8. Expected Numerical Result

The board memory contents remain:

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

so:

```text
accumulator = 45
M_INT       = 3
FRAC_BITS   = 2
result      = 34
```

The testbench therefore expects:

```text
led_result = 8'd34
           = 8'b0010_0010
```

for each completed nominal transaction.

---

## 9. What Has Not Yet Been Proven

This Step-7 checkpoint does **not** claim that the testbench compiles or passes in XSim.

It also does not prove:

```text
BRAM inference
DSP mapping
LUT/FF/CARRY utilization
post-route WNS/TNS/WHS/THS
100 MHz physical timing closure
board-level pin correctness
physical button/LED behavior
```

Those require later simulation, synthesis, implementation, constraints, and board evidence.

---

## 10. Next Mandatory Step

The next workflow step is:

```text
Step 8 — simulation + measurement
```

The user must run the generated testbench in Vivado XSim and provide the transcript and/or waveform evidence.

A simulation `PASS` message alone will not be accepted. The resulting behavior must be explained signal by signal against this verification plan.
