# Basys 3 Top-Level Integration — Teaching Note

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 1 — `/teach basys3_top_level`  
**Status:** TEACHING — understanding gate required before design.

---

## 1. Why Phase 8 Exists

Phase 7 proved that the accelerator core behaves correctly as an integrated transaction engine in behavioral simulation:

```text
external start
 -> control_fsm
 -> memory_interface_dataflow
 -> signed INT32 convolution result
 -> requantize_relu_pipelined
 -> architectural INT8 activation_out
 -> external done
```

But that core is not yet a complete Basys 3 design. It still exposes abstract memory ports and abstract transaction signals. A real FPGA bitstream needs a board-facing top level that connects the accelerator core to:

```text
100 MHz Basys 3 clock
physical or inferred FPGA memory
board-safe reset/start controls
visible output/status signals
pin constraints
```

The repository roadmap identifies the next building milestone after integration as `B12 Basys 3 top level`, followed by verification, measurement, low-power optimization, and final design review. Phase 8 therefore turns the already-verified accelerator core into an FPGA system and then performs physical sign-off.

---

## 2. Current Repository Boundary

At the start of Phase 8, `rtl/top/` contains only:

```text
convolution_integration.v
```

That module deliberately does **not** instantiate physical BRAM or board I/O. It exposes memory interfaces instead.

The current constraint directory contains timing-wrapper constraints used in earlier module characterization, but no Basys-3 board-level pin constraint file for the accelerator top.

Therefore Phase 8 is not merely "rename the module as top." It must introduce the missing board/system boundary deliberately.

---

## 3. The Core Versus the Board Top

A useful distinction is:

```text
convolution_integration
= accelerator core

basys3_top_level
= board/system wrapper around that core
```

The accelerator core should remain responsible for computation and transaction timing.

The board top should be responsible for infrastructure:

```text
clock entry
reset/start conditioning
memory instantiation or connection
memory initialization
board-visible result/status mapping
pin-level interface
```

This separation is important in hardware engineering. A compute block that depends directly on pushbuttons, LEDs, or a specific board is harder to reuse and harder to verify. Keeping board concerns outside the compute core preserves modularity.

---

## 4. Explicit Assumptions for Teaching

These are assumptions for the teaching stage, not yet final design decisions.

1. Target FPGA remains `XC7A35T-1CPG236C` on Basys 3.
2. Board clock is 100 MHz.
3. Therefore:

```text
Tclk = 1 / 100 MHz = 10 ns
```

4. The current accelerator core remains `convolution_integration`.
5. The current core requires one activation word and one weight word to be returned through independent 32-bit interfaces.
6. Each memory access is expected to behave as a one-clock synchronous read.
7. One 3x3 single-channel transaction reads three activation words and three weight words.
8. The address sequence is `0 -> 1 -> 2` for both memories.
9. Board-level start/reset inputs are treated as asynchronous external signals until synchronized.
10. The exact choice of board buttons, switches, LEDs, and exact XDC pin assignments is deferred to `/design basys3_top_level`.
11. The exact BRAM inference style is also deferred to the design step; this teaching note explains the architectural choices first.
12. No Phase-8 resource count or timing-closure result is assumed before synthesis/implementation.

---

## 5. What the Board Top Must Connect

The conceptual hierarchy is:

```text
                       Basys 3 board
                            |
                +-----------+-----------+
                |                       |
             100 MHz                  controls
              clock                  start/reset
                |                       |
                v                       v
        +---------------------------------------+
        |          basys3_top_level             |
        |                                       |
        |  input conditioning                   |
        |  activation memory                    |
        |  weight memory                        |
        |  result/status mapping                |
        |                                       |
        |       +-----------------------+       |
        |       | convolution_integration|       |
        |       +-----------------------+       |
        +---------------------------------------+
                |
                v
          LEDs / status outputs
```

The core itself should not need to know whether `start` came from a pushbutton, testbench, UART, or future host interface. It should only see a clean synchronous transaction pulse.

---

## 6. Clock Domain: Why the 100 MHz Board Clock Matters

The current architecture was derived around a 100 MHz clock.

From first principles:

```text
fclk = 100,000,000 Hz
Tclk = 1 / fclk
     = 1 / 100,000,000 s
     = 10 ns
```

Phase-7 behavioral measurements established:

```text
accepted start -> done = 7 cycles
minimum accepted-start spacing = 9 cycles
```

If the board top runs the same core directly from the 100 MHz board clock, the protocol-level times remain:

```text
7 x 10 ns = 70 ns
9 x 10 ns = 90 ns
```

However, there is a crucial distinction:

```text
behavioral schedule at 100 MHz
!=
physical proof of 100 MHz timing closure
```

Only post-route static timing analysis can prove that every register-to-register path in the placed/routed Phase-8 design satisfies the 10 ns period and hold requirements.

---

## 7. Why Pushbuttons Cannot Be Connected Naively

A board pushbutton is not synchronized to the FPGA clock.

If the user presses a button at an arbitrary real-world time, its transition can occur close to a clock edge. A receiving flip-flop can violate setup/hold requirements and enter a metastable state.

The basic mitigation is a synchronizer, commonly two cascaded flip-flops in the destination clock domain:

```text
asynchronous button
      |
      v
sync FF1
      |
      v
sync FF2
      |
      v
synchronized level
```

The first stage may become metastable, but it is given almost a full clock period to settle before the second stage samples it. This does not mathematically eliminate metastability; it reduces the probability that metastability propagates into the logic.

The key concept is:

> A physical board input is an asynchronous signal until it has crossed into the FPGA clock domain safely.

---

## 8. Synchronization Is Not the Same as Debouncing

A mechanical button can physically bounce. One press may create several rapid 0/1 transitions.

A synchronizer solves the clock-domain-crossing problem.

A debouncer solves the mechanical-bounce problem.

They are different problems:

```text
synchronizer
 -> protects sequential logic from asynchronous timing

debouncer
 -> prevents one physical press from appearing as many logical presses
```

For `start`, the accelerator contract requires one accepted pulse, not a long held level and not many bounce-generated pulses.

A typical conceptual chain is:

```text
button
 -> synchronizer
 -> debounce/filter
 -> edge detector
 -> one-clock start pulse
```

The exact implementation and whether both reset and start require full debouncing will be decided in the design step.

---

## 9. Why a One-Cycle Start Pulse Is Needed

Phase 7 assumes external `start` is a one-clock pulse presented while `busy=0`.

At 100 MHz, one clock pulse lasts:

```text
10 ns
```

A human button press is enormously longer than 10 ns—typically millions of clock cycles.

Therefore the board top cannot simply wire a button level directly to `start`.

Instead it must convert a clean button transition into:

```text
start = 1 for exactly one rising-edge interval
```

Conceptually, after synchronization/debounce, an edge detector compares the current and previous stable button states:

```text
start_pulse = current_button & ~previous_button
```

The exact RTL belongs to the design/implementation workflow later; the important teaching concept is that a level and a pulse are different interface contracts.

---

## 10. Reset Semantics Must Match the Existing Core

The current accelerator modules use synchronous active-high reset.

That means reset is acted upon at a clock edge:

```text
if rst is high at rising edge:
    registers take reset values
```

This differs from an asynchronous reset, which can change register state immediately independent of a clock edge.

The board wrapper must therefore preserve the existing reset contract rather than silently changing the entire system to a different reset style.

An external reset button may still be asynchronous as a physical input, so its board-facing handling must be considered separately from the core's synchronous reset behavior.

---

## 11. The Most Important Memory Requirement: Two Words per Read Cycle

The Phase-7 engine exposes independent interfaces:

```text
activation_rd_en
activation_addr[1:0]
activation_data[31:0]

weight_rd_en
weight_addr[1:0]
weight_data[31:0]
```

During active memory cycles, activation and weight words are requested together.

That means the system requires the logical ability to obtain:

```text
one 32-bit activation word
+
one 32-bit weight word
```

for the same engine cycle.

This can be implemented physically in more than one way:

```text
Option A: two independent memories
          one activation memory + one weight memory

Option B: one true dual-port memory
          one port dedicated to activations
          one port dedicated to weights
```

The design step must choose an implementation that preserves the one-clock read behavior expected by the core.

---

## 12. Logical Memory Capacity Derivation

For one 3x3 single-channel convolution:

```text
9 activation INT8 values
9 weight INT8 values
```

Four INT8 values are packed per 32-bit word.

Number of words required for nine elements:

```text
ceil(9 / 4) = 3 words
```

Each word is 32 bits, so one logical memory contains:

```text
3 x 32 bits = 96 bits
```

Therefore:

```text
activation memory logical contents = 96 bits
weight memory logical contents     = 96 bits
combined logical contents          = 192 bits
```

The useful data is only:

```text
9 x 8 = 72 bits per operand set
```

because the last word contains:

```text
[element 8, 0, 0, 0]
```

So each 96-bit packed memory contains 72 useful bits and 24 padding bits.

Packing efficiency:

```text
72 / 96 = 75%
```

and combined memory packing efficiency remains 75%.

---

## 13. Why "192 Bits of Data" Does Not Mean "192 Bits of BRAM Resource"

FPGA block RAMs are coarse-grained physical resources. The accelerator's current logical test memory is tiny.

Therefore there is a major distinction between:

```text
logical memory bits required by the algorithm
```

and:

```text
physical BRAM block allocation on the FPGA
```

A tiny `3 x 32` memory may be implemented by synthesis as:

```text
registers
LUT RAM
or BRAM
```

depending on coding style, attributes, synthesis heuristics, and architecture.

So if the Phase-8 goal is specifically to demonstrate **BRAM-backed storage**, we cannot assume that declaring a small array automatically proves BRAM usage. The synthesis report must confirm the actual primitive/resource mapping.

This is the same principle learned earlier with multipliers:

```text
RTL structure != guaranteed physical resource mapping
```

---

## 14. One-Clock Synchronous Read Must Be Preserved

The Phase-7 testbench used the memory behavior:

```text
clock N:
    rd_en = 1
    addr = A

clock N+1:
    data corresponding to A is available to the engine
```

If the board memory were implemented as an asynchronous combinational array instead, the temporal contract would change.

That could make behavioral and hardware schedules disagree.

Therefore the board memory must be designed and verified around the already-established one-clock synchronous read contract.

This is not merely a style preference. The engine's state machine and accumulation schedule were derived around that exact latency.

---

## 15. Memory Initialization: How the FPGA Gets Known Test Data

For a first board demonstration, the simplest concept is to initialize activation and weight memories with known test vectors before configuration completes.

Conceptually:

```text
mem/activation file
        |
        v
activation memory initialization

mem/weight file
        |
        v
weight memory initialization
```

Then pressing start executes a deterministic convolution whose expected result was already computed in Python/reference arithmetic.

This provides a powerful board-level verification chain:

```text
known quantized memory contents
 -> FPGA computation
 -> visible activation_out
 -> compare with known golden result
```

The exact `.mem` format and initialization mechanism will be fixed in the design step.

---

## 16. What Should Be Visible on the Board?

A board demonstration needs observability.

The core provides:

```text
activation_out[7:0]
busy
done
```

A natural conceptual mapping is:

```text
8 LEDs <- activation_out[7:0]
1 LED  <- busy or done/status
```

But this is a **design choice**, not yet final.

The important principle is that the physical demo should expose enough state to distinguish:

```text
idle
transaction active
transaction complete
final output value
```

without changing the accelerator arithmetic.

---

## 17. Why `done` May Be Too Short for a Human to See

The controller's `done` signal is only one clock-state interval.

At 100 MHz:

```text
one cycle = 10 ns
```

A 10 ns LED flash is invisible to a human.

Therefore a board-level observable "done" indicator cannot simply rely on visually observing the raw pulse.

Possible board-infrastructure concepts include:

```text
latched done flag
pulse stretcher
status register
```

The accelerator's internal `done` timing should remain unchanged. Any human-visible extension belongs in the board wrapper.

This is an important system-design lesson:

> Machine-visible protocol timing and human-visible interface timing are different requirements.

---

## 18. Architectural Output Versus Displayed Output

`activation_out` is an 8-bit signed interface, but after ReLU its legal completed result range is:

```text
0..127
```

Therefore the sign bit should be zero for legal completed outputs under the current architecture.

If the board uses eight LEDs to display the result directly, the LEDs represent the binary value, not decimal notation.

For the nominal Phase-7 example:

```text
activation_out = 34 decimal
               = 0b0010_0010
```

So a direct binary LED display would show bits 5 and 1 high.

This is different from displaying the decimal characters "34" on seven-segment displays, which would require extra decoding/multiplexing logic. Such display logic is not required to prove the NPU datapath and may unnecessarily expand Phase 8 unless explicitly chosen.

---

## 19. Board-Level Timing Closure: What Must Eventually Be Proven

Once the board top, memories, and infrastructure are integrated, synthesis and implementation must answer questions that behavioral simulation cannot:

```text
How many LUTs?
How many Slice FFs?
How many DSP48E1s?
Was BRAM actually inferred?
What is the worst setup slack?
What is the worst hold slack?
Does 100 MHz close after routing?
What is the critical path?
```

For a 100 MHz constraint:

```text
Trequired = 10 ns
```

For setup timing, conceptually:

```text
slack = required arrival time - actual data arrival time
```

A non-negative worst setup slack means the constrained setup requirement is met.

For hold timing, the tool separately checks that data does not change too soon after the capturing edge.

Therefore both setup and hold evidence are needed for physical sign-off.

---

## 20. Why Phase-6 Timing Cannot Sign Off the Board Top

Earlier phases physically characterized individual blocks such as the requantizer.

Those results are valuable evidence about the child module, but integration changes:

```text
placement
routing
fanout
hierarchy optimization
clock/control routing
memory placement
```

Therefore Phase 8 must obtain its own synthesis and post-route timing reports.

A unit-level positive WNS cannot be copied forward as proof for a larger integrated hierarchy.

---

## 21. Resource Accounting Must Be Re-Measured at the Top Level

The Phase-7 structural expectation contains:

```text
4 small INT8 multipliers
1 wider requantization multiplier
```

But the board top also introduces infrastructure and memory.

Therefore the final resource report must distinguish at least conceptually:

```text
compute resources
control resources
memory resources
board-interface/infrastructure resources
```

This allows us to answer the engineering question:

> How much FPGA cost is caused by the accelerator itself, and how much is caused by making it usable on the board?

---

## 22. Low-Power Thinking at the Board-Top Level

The project goal includes low-power design, but "low power" must not be reduced to a slogan.

Dynamic power is conceptually related to:

```text
Pdynamic proportional to activity x capacitance x voltage^2 x frequency
```

At this phase, the design can influence activity by avoiding unnecessary switching.

Examples of architectural questions include:

```text
Should compute registers toggle while idle?
Should memory enables be active only during requests?
Should display/infrastructure logic toggle continuously?
Can clock-enable behavior reduce datapath switching without adding unsafe gated clocks?
```

The important principle is:

> Prefer clock enables and controlled data activity over manually gating the FPGA clock with ordinary logic.

Actual power reduction must later be supported by implementation/power evidence where practical; it should not be claimed solely from RTL appearance.

---

## 23. Phase-8 Verification Layers

A credible final FPGA design must be checked at several layers.

### Layer A — functional board-top simulation

Prove:

```text
start conditioning launches one transaction
memory data reaches the core with correct one-cycle latency
result appears correctly
status logic behaves correctly
```

### Layer B — synthesis/resource measurement

Measure:

```text
LUT
FF
CARRY
DSP
BRAM
```

### Layer C — implementation/static timing

Measure:

```text
WNS
TNS
hold slack
critical path
```

### Layer D — board demonstration

Confirm that the programmed Basys 3 produces the expected visible result for known initialized vectors.

A success at one layer does not automatically prove the others.

---

## 24. What the Board Top Should Not Do

The top level should not quietly rewrite the accelerator architecture.

It should not introduce:

```text
a second convolution datapath
a second requantizer
a duplicate FSM
new arithmetic inside the board wrapper
an unrelated processor/soft CPU
```

Its purpose is infrastructure and physical integration.

If the board wrapper changes the computation itself, verification from Phase 7 no longer transfers cleanly.

---

## 25. Conceptual Transaction on the Real Board

A clean first board demonstration can be thought of as:

```text
1. FPGA configures.
2. Activation/weight memories contain known packed test data.
3. Accelerator is idle.
4. User produces one clean start event.
5. Core requests addresses 0, 1, 2.
6. Board memories return matching activation/weight words synchronously.
7. Engine forms signed INT32 result.
8. Requantizer performs ReLU, multiply, rounding, shift, saturation.
9. activation_out captures final INT8 value.
10. done event occurs.
11. Board-visible output/status holds long enough to inspect.
```

For the already-used nominal test vector, the expected architectural result is:

```text
45 -> product 135 -> q_out 34
```

The board should therefore make the final value 34 observable without modifying the core arithmetic.

---

## 26. Key Distinction: Core Correctness Versus Platform Correctness

Phase 7 answered:

> Does the integrated accelerator transaction behave correctly under its abstract interfaces?

Phase 8 must answer:

> Does the actual Basys-3 platform provide those interfaces correctly and does the complete placed/routed design meet physical constraints?

The core can be correct while the platform wrapper is wrong.

Examples:

```text
wrong memory latency
wrong pin constraint
unsynchronized button
wrong memory initialization
incorrect clock constraint
insufficient timing slack
```

None of those faults require the convolution mathematics itself to be wrong.

This is why top-level integration is a distinct engineering phase rather than a trivial wrapper task.

---

## 27. Teaching Summary

The central concepts are:

1. `convolution_integration` remains the reusable compute core.
2. `basys3_top_level` is a platform wrapper, not another compute engine.
3. The 100 MHz clock corresponds to a 10 ns period.
4. External pushbuttons are asynchronous and require safe clock-domain handling.
5. Synchronization and debouncing solve different problems.
6. The core needs a clean one-cycle `start` pulse.
7. Physical memory must preserve the one-clock synchronous-read contract.
8. The transaction logically requires three 32-bit activation words plus three 32-bit weight words.
9. Logical memory size is 96 bits per operand memory, 192 bits total, but physical BRAM usage must be measured after synthesis.
10. A raw 10 ns `done` indication is not human-visible, so board observability may require separate wrapper logic.
11. Phase-8 synthesis must re-measure LUT/FF/DSP/BRAM usage.
12. Phase-8 implementation must independently prove setup/hold timing at 100 MHz.
13. Low-power improvements should reduce unnecessary switching using FPGA-safe techniques such as clock enables rather than casual combinational clock gating.
14. Board-level correctness is distinct from core arithmetic correctness.

---

## 28. Understanding Gate

Before `/design basys3_top_level`, explain the following in your own words:

1. Why is `convolution_integration` not already a complete Basys 3 top-level design?
2. What responsibilities belong to `basys3_top_level`, and what responsibilities must remain inside the accelerator core?
3. Why can a physical pushbutton not be connected directly to the core's `start` input?
4. What is the difference between synchronization, debouncing, and one-pulse generation?
5. Why must Phase-8 memory preserve one-clock synchronous-read behavior?
6. Derive why each operand memory needs three 32-bit words and why the combined packed logical storage is 192 bits.
7. Why does declaring a tiny memory array not automatically prove that Vivado used BRAM?
8. Why is the raw `done` pulse unsuitable as a directly visible LED indication at 100 MHz?
9. Why must Phase 8 perform its own synthesis and post-route timing analysis even though child blocks were already characterized earlier?
10. What does "low power" mean at this level, and why should we prefer clock enables/activity reduction over manually gating the FPGA clock?

**Hard gate:** do not proceed to `/design basys3_top_level` until these concepts are restated correctly.