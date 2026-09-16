# Basys 3 Top-Level Integration — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 2 — `/design basys3_top_level`  
**Status:** DESIGN COMPLETE — understanding gate required before Step 3 `/analyze basys3_top_level`.

---

## 1. Design Objective

The purpose of `basys3_top_level` is to convert the already-verified `convolution_integration` core into a real Basys-3 FPGA system **without changing the accelerator mathematics or transaction schedule**.

The board top must provide the physical/platform services that Phase 7 deliberately left outside the core:

```text
100 MHz board clock
physical pushbutton inputs
safe button conditioning
one-cycle transaction start
physical/inferred activation memory
physical/inferred weight memory
human-visible result/status
Basys-3 pin and timing constraints
```

The Phase-7 core remains the owner of:

```text
transaction control
memory request sequencing
four-lane INT8 multiply/reduction
INT32 accumulation
ReLU/requantization
architectural activation_out
busy/done protocol
```

The current core interface confirms that physical memories are external: it emits `activation_rd_en`, `activation_addr`, `weight_rd_en`, and `weight_addr`, while accepting `activation_data` and `weight_data` returned by the platform.

---

## 2. Explicit Assumptions

1. Target board: Basys 3.
2. Target device: `XC7A35T-1CPG236C`.
3. Board clock: 100 MHz.
4. Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

5. Core module: `convolution_integration`.
6. Core reset semantics remain synchronous active-high.
7. Core start contract remains a one-clock pulse accepted only when `busy == 0`.
8. Memory read latency remains exactly one clock.
9. Memory words remain 32 bits, packing four signed INT8 lanes in the Phase-7 little-lane order.
10. The first board demonstration uses the already-verified nominal convolution vector:

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

11. For board bring-up, the core uses:

```text
M_INT     = 3
FRAC_BITS = 2
```

so the expected visible result is 34.
12. Exact Basys-3 package pin names are assigned from the official board constraint source during implementation; this design document defines logical board functions rather than hard-coding package pins.
13. The design will attempt block-memory inference first, but BRAM use is an **acceptance requirement**, not an assumption. If synthesis does not map the memory subsystem to BRAM, implementation must be revised to an explicit Xilinx BRAM primitive or equivalent block-memory construction before physical sign-off.

---

## 3. Top-Level Architecture

The selected hierarchy is:

```text
Basys 3
  |
  |-- 100 MHz clock ------------------------------+
  |                                               |
  |-- START button -> synchronizer -> debounce -> rising-edge pulse
  |                                               |
  |-- RESET button -> synchronizer -> debounce ---+
  |                                               |
  v                                               v
+----------------------------------------------------------------+
|                       basys3_top_level                          |
|                                                                |
|  +--------------------+                                        |
|  | board input logic  |---- core_start -------------------+     |
|  +--------------------+                                   |     |
|                                                           v     |
|  +---------------------+       +------------------------------+ |
|  | activation memory   |<----->|                              | |
|  +---------------------+       |   convolution_integration    | |
|                                |                              | |
|  +---------------------+<----->|                              | |
|  | weight memory       |       +------------------------------+ |
|  +---------------------+                | activation_out         |
|                                         | busy / done             |
|                                         v                         |
|                               +----------------------+            |
|                               | board status logic   |            |
|                               | result LEDs          |            |
|                               | done_latched         |            |
|                               +----------------------+            |
+----------------------------------------------------------------+
```

The board top contains **no second convolution datapath, no second requantizer, and no duplicate transaction FSM**.

---

## 4. Proposed External Board Interface

Logical board ports are selected as:

```text
clk_100mhz      input   Basys-3 100 MHz oscillator
btn_start       input   physical start pushbutton
btn_reset       input   physical reset pushbutton
led_result[7:0] output  binary activation result
led_done        output  latched human-visible completion status
```

Recommended physical control assignment for implementation:

```text
center pushbutton -> start
up pushbutton     -> reset
```

The exact package pins are intentionally deferred to the dedicated Basys-3 XDC step so they are copied from the board's authoritative constraint definition rather than recalled from memory.

Only nine LEDs are required for the minimal demonstration:

```text
LED[7:0] -> activation_out[7:0]
LED[8]   -> done_latched
```

No seven-segment decoder is included because decimal display logic does not contribute to validating the NPU architecture.

---

## 5. Start-Button Conditioning

A physical button cannot satisfy the core start contract directly. The selected chain is:

```text
physical start button
    -> two-flop synchronizer
    -> stable-time debouncer
    -> rising-edge detector
    -> busy mask
    -> core_start
```

### 5.1 Synchronizer

Two flip-flops clocked at 100 MHz bring the asynchronous button into the system clock domain.

The synchronizer registers should be marked as asynchronous-register stages during implementation so Vivado can place them appropriately.

### 5.2 Debounce interval derivation

Selected debounce interval:

```text
10 ms
```

At 100 MHz:

```text
100,000,000 cycles/s x 0.010 s = 1,000,000 cycles
```

The counter must represent values through at least 999,999.

Since:

```text
2^19 =   524,288  < 1,000,000
2^20 = 1,048,576 >= 1,000,000
```

minimum counter width is:

```text
20 bits
```

The debouncer counter increments only while the synchronized input disagrees with the accepted stable state; otherwise it holds. This reduces unnecessary switching compared with a continuously free-running counter.

### 5.3 One-cycle pulse

After the debounced button becomes high, a rising-edge detector generates one 100 MHz cycle of `start_pulse`.

Therefore pulse width is:

```text
1 cycle x 10 ns/cycle = 10 ns
```

The signal delivered to the core is:

```text
core_start = start_pulse only when busy == 0
```

A press occurring while the accelerator is busy is intentionally discarded rather than queued. This keeps the board wrapper consistent with the Phase-7 legal-start contract.

---

## 6. Reset-Button Conditioning

The board reset button is also asynchronous and mechanical.

Selected chain:

```text
physical reset button
    -> two-flop synchronizer
    -> stable-time debouncer
    -> core_rst level
```

The same 10 ms stability criterion may be reused.

The final reset seen by `convolution_integration` remains **synchronous active-high** because the cleaned level is sampled by the existing core registers only on the 100 MHz rising edge.

The wrapper must not convert the established core reset into an asynchronous-reset architecture.

---

## 7. Memory Subsystem Requirements

The current core has two logically independent synchronous read interfaces:

```text
activation_rd_en
activation_addr[1:0]
activation_data[31:0]

weight_rd_en
weight_addr[1:0]
weight_data[31:0]
```

During a convolution transaction, both operands are requested in parallel.

Therefore the physical memory subsystem must support, in the same clock interval:

```text
one 32-bit activation read
+
one 32-bit weight read
```

with both values returned one clock later.

---

## 8. Packed Memory Capacity

Each operand contains nine INT8 values:

```text
9 x 8 bits = 72 useful bits
```

Four INT8 values fit in each 32-bit memory word:

```text
ceil(9 / 4) = 3 words
```

Therefore per operand:

```text
3 words x 32 bits = 96 packed bits
```

For activation + weight:

```text
96 + 96 = 192 packed logical bits
```

Useful data is:

```text
72 + 72 = 144 useful bits
```

Packing efficiency is:

```text
144 / 192 = 0.75 = 75%
```

The last three byte lanes in each operand's third word are padding.

---

## 9. Selected Memory Organization

The architectural design uses two logical operand memories:

```text
activation memory
weight memory
```

Both are read-only during the initial board demonstration and initialized when the FPGA is configured.

Each exposes:

```text
clock
read enable
2-bit logical address
32-bit registered read data
```

The required behavior is:

```text
edge N:
    rd_en = 1
    addr  = A

edge N+1:
    data = memory[A]
```

This is the same one-clock contract used during Phase-7 verification.

### Physical mapping requirement

The project target requires FPGA BRAM storage. Because each logical memory is extremely small, Vivado may otherwise prefer LUTs or registers.

The implementation strategy is therefore:

```text
first attempt:
  synchronous inferred memory with explicit block-memory intent

accept only if synthesis confirms BRAM mapping

if BRAM is not inferred:
  replace the implementation with an explicit Xilinx BRAM construction
  while preserving exactly the same logical interface and one-cycle latency
```

The architectural contract is independent of whether the final physical solution uses one shared dual-port BRAM block or two BRAM-backed operand memories. The physical selection will be confirmed by synthesis evidence, not assumed from source syntax.

---

## 10. Board Demonstration Memory Contents

The selected test vector is packed using the established lane mapping:

```text
lane0 -> bits [7:0]
lane1 -> bits [15:8]
lane2 -> bits [23:16]
lane3 -> bits [31:24]
```

Activations:

```text
[1,2,3,4] -> word 0 = 0x04030201
[5,6,7,8] -> word 1 = 0x08070605
[9,0,0,0] -> word 2 = 0x00000009
```

Weights:

```text
[1,1,1,1] -> word 0 = 0x01010101
[1,1,1,1] -> word 1 = 0x01010101
[1,0,0,0] -> word 2 = 0x00000001
```

Independent convolution derivation:

```text
1+2+3+4+5+6+7+8+9 = 45
```

Selected board requantization:

```text
M_INT = 3
F     = 2
```

Product:

```text
45 x 3 = 135
```

Rounding bias:

```text
2^(F-1) = 2
```

Rounded value:

```text
135 + 2 = 137
```

Shift:

```text
137 >> 2 = 34
```

Expected board result:

```text
activation_out = 34 decimal
               = 0b0010_0010
```

So the direct binary result display should illuminate result bits 5 and 1.

---

## 11. `done_latched` Board Status

The core's raw `done` event lasts one 100 MHz clock-state interval:

```text
1 x 10 ns = 10 ns
```

That is far too short to observe directly on an LED.

The board wrapper therefore contains a latched status bit:

```text
reset or accepted new start -> done_latched = 0
core done event              -> done_latched = 1
otherwise                    -> hold
```

Because `core_done` becomes high after the core enters its DONE state, a conventional board-side status register will observe and latch that event on the following system edge. The visible status may therefore become persistent one clock after raw `done`; this does not change the accelerator transaction latency or `activation_out` timing.

`activation_out` itself is already an architectural holding register, so the result LEDs do not require a second result register.

---

## 12. Clock Architecture

The Basys-3 100 MHz oscillator drives the design directly.

No clock divider, PLL, or MMCM is required for the accelerator core.

Therefore there is a single primary synchronous domain:

```text
100 MHz
10 ns period
```

Using one clock domain avoids unnecessary CDC complexity and preserves the timing model already verified in Phase 7.

The human interface is made slower through debounce/state logic, **not by creating a second slow fabric clock**.

---

## 13. Constraint Strategy

A dedicated Phase-8 XDC will be created during implementation.

It must contain at least:

```text
100 MHz create_clock constraint
package pin + I/O standard for clk_100mhz
package pin + I/O standard for btn_start
package pin + I/O standard for btn_reset
package pins + I/O standard for result LEDs
package pin + I/O standard for done LED
```

The earlier `requantize_timing_wrapper.xdc` is not reused as the final board constraint file even though its 10 ns clock happened to be sufficient for the core-only baseline.

Asynchronous button paths terminate at synchronizer stages and must be handled as CDC inputs rather than treated as externally synchronous data interfaces.

---

## 14. Timing Contract After Board Integration

The 10 ms debouncer introduces human-interface latency **before** a core transaction is accepted. It is not part of the accelerator's compute latency.

Once `core_start` is accepted, the Phase-7 protocol remains:

```text
start -> done = 7 cycles
```

At 100 MHz:

```text
7 x 10 ns = 70 ns
```

Minimum accepted core-start spacing remains:

```text
9 cycles x 10 ns = 90 ns
```

The board button interface obviously cannot generate useful human presses every 90 ns; the 90 ns figure remains the machine-level accelerator initiation interval.

The final 100 MHz physical guarantee must be re-proven after placement and routing of the complete board top.

---

## 15. Low-Power Design Decisions

The Phase-8 wrapper follows these activity-reduction rules:

```text
no ordinary combinational clock gating
single 100 MHz global clock
memory read enables active only when requested
button debounce counters hold when inputs are stable
done status register toggles only on reset/start/done events
no continuously multiplexed seven-segment display
no free-running decorative counters
```

This reduces avoidable switching without compromising FPGA clock integrity.

Actual power improvement is not claimed from RTL structure alone; later analysis must use implementation/power evidence where available.

---

## 16. Verification Hooks Required by the Design

The board top must remain simulation-friendly.

The debounce threshold should be parameterized so that:

```text
hardware default = 1,000,000 cycles (10 ms at 100 MHz)
verification override = small count such as 4 or 8 cycles
```

The testbench will eventually need to verify at least:

```text
button bounce produces one core start
one stable press produces exactly one transaction
press while busy does not create a second transaction
reset clears core/result/status state
memory address sequence remains 0 -> 1 -> 2
memory data has one-cycle latency
nominal test produces activation_out = 34
done_latched remains visible until reset or next accepted start
```

These are verification requirements, not claims that the tests have already been run.

---

## 17. Physical Sign-Off Requirements

The final Phase-8 system is not physically complete until synthesis/implementation measure the complete board top.

Required final evidence includes:

```text
LUT utilization
FF utilization
CARRY4 utilization
DSP utilization
BRAM utilization
IO utilization
WNS / TNS
WHS / THS
critical setup path
critical hold path where relevant
100 MHz timing-closure status
```

The board-top results must then be compared against the measured `convolution_integration` baseline so that wrapper/memory overhead is visible.

---

## 18. Design Decisions Summary

```text
Board clock          : direct 100 MHz, one clock domain
Start input          : 2-FF sync -> 10 ms debounce -> rising pulse -> busy mask
Reset input          : 2-FF sync -> 10 ms debounce -> synchronous core reset level
Core                 : existing convolution_integration, unchanged computation
Memory               : two logical 32-bit synchronous operand memories
Memory latency       : exactly one clock
Memory mapping goal  : FPGA BRAM; synthesis must prove it
Test activations     : [1,2,3,4,5,6,7,8,9]
Test weights         : nine 1s
M_INT / FRAC_BITS    : 3 / 2 for board bring-up
Expected output      : 34 = 0b0010_0010
Result display       : 8 binary LEDs
Completion display   : latched done LED
Seven-segment logic  : intentionally omitted
Clock gating         : prohibited in ordinary fabric logic
Final timing target  : 100 MHz / 10 ns, re-proven post-route
```

---

## 19. Understanding Gate

Before Step 3 `/analyze basys3_top_level`, the learner must explain in their own words:

1. Why the board top must preserve `convolution_integration` rather than duplicate computation.
2. Why the start path is ordered as synchronizer -> debouncer -> one-cycle pulse -> busy mask.
3. Derive the 20-bit debounce counter requirement for a 10 ms interval at 100 MHz.
4. Why the board memories must return data one clock after a read request.
5. Why the 9-element operand becomes the exact words `0x04030201`, `0x08070605`, `0x00000009` for the selected activation vector.
6. Derive the expected board result of 34 from accumulator 45, `M_INT=3`, and `FRAC_BITS=2`.
7. Why BRAM use remains an acceptance criterion that must be confirmed after synthesis rather than assumed from RTL.
8. Why `done_latched` is board infrastructure and why it does not change the core's 70 ns transaction latency.
9. Why a single 100 MHz clock domain is preferred over generating a slow fabric clock for buttons/LEDs.
10. Which physical results must be re-measured after final board-top implementation.

**Hard gate:** do not proceed to `/analyze basys3_top_level` until the design is restated correctly.