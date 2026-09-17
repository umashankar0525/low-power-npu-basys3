# Basys 3 Top-Level Integration — RTL Implementation Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 5 — RTL generation  
**Status:** RTL GENERATED — verification planning is next; no simulation or physical sign-off has been performed.

---

## 1. Files generated

The approved board-top architecture is implemented in three RTL files:

```text
rtl/infrastructure/button_conditioner.v
rtl/memory/operand_bram_dual_read.v
rtl/top/basys3_top_level.v
```

The existing Phase-7 accelerator core remains unchanged:

```text
rtl/top/convolution_integration.v
```

This preserves the approved architecture: the board wrapper integrates the accelerator rather than duplicating its compute/control logic.

---

## 2. `button_conditioner`

The infrastructure helper implements:

```text
asynchronous button
  -> 2-FF synchronizer
  -> stable-time debounce counter
  -> accepted debounced level
  -> rising-edge detector
```

Default parameters are:

```text
STABLE_CYCLES = 1,000,000
COUNTER_WIDTH = 20
```

which corresponds to the previously derived 10 ms debounce interval at 100 MHz.

The counter increments only while the synchronized sample differs from the accepted level, so it does not free-run while the input is stable.

The two synchronizer registers carry the Xilinx `ASYNC_REG` implementation hint.

The module uses FPGA power-up initialization so the reset-button conditioner has a deterministic state even though the clean reset level is itself produced by that conditioner.

---

## 3. Operand memory implementation

`operand_bram_dual_read` implements one logical 512 x 32 memory array with two synchronous registered read ports.

Physical address organization is:

```text
activation logical 0..2 -> physical 0..2
weight logical 0..2     -> physical 256..258
```

The array therefore supports one activation read and one weight read in the same clock interval.

The source carries:

```text
(* ram_style = "block" *)
```

and is intentionally 16,384 bits deep in total so that block-memory inference is a realistic target rather than describing only a six-word physical array.

**Important:** this is still only an RTL intent. BRAM use is not considered proven until Vivado synthesis reports a non-zero block-memory primitive/tile count.

The initialized board-demo contents are:

```text
activation:
0 -> 0x04030201
1 -> 0x08070605
2 -> 0x00000009

weight:
0 -> 0x01010101
1 -> 0x01010101
2 -> 0x00000001
```

All unused memory locations are initialized to zero.

---

## 4. `basys3_top_level`

The board wrapper exposes only:

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

so the wide activation/weight memory buses that caused the core-only 83-IOB baseline are now internal FPGA connections.

The wrapper contains two button-conditioner instances:

```text
reset button -> debounced reset level
start button -> debounced rising pulse
```

The start event delivered to the core is:

```text
core_start = start_rise & ~core_busy
```

so a button event that occurs while the accelerator is busy is discarded rather than queued.

The core is instantiated with the approved board-bring-up parameters:

```text
M_INT     = 3
FRAC_BITS = 2
```

The expected nominal result therefore remains:

```text
activation_out = 34 = 8'b0010_0010
```

---

## 5. Completion observability

The core's raw `done` signal remains unchanged.

A separate board-level `done_latched` register implements:

```text
clean reset        -> clear
accepted new start -> clear
core done          -> set
otherwise          -> hold
```

The LED therefore records that a completion event occurred without changing the accelerator's transaction protocol or architectural output register.

`led_result[7:0]` directly reflects the already-registered `activation_out` from `convolution_integration`; no duplicate result register was added.

---

## 6. Structural prediction consistency

The RTL intentionally matches the earlier prediction model:

```text
single 100 MHz domain
20-bit activity-driven debounce counters
2-FF synchronizers
one-clock synchronous operand reads
M_INT = 3, FRAC_BITS = 2
board-visible binary result
latched completion status
no ordinary combinational clock gating
```

One implementation detail is worth tracking during synthesis: the reusable reset-button conditioner structurally contains a previous-level register for `rise_pulse`, even though the reset instance's pulse output is unused. Vivado is expected to trim that unused logic, so the prior 48-wrapper-FF estimate remains a prediction rather than a source-level exact register count.

---

## 7. Explicit assumptions and unresolved physical questions

1. Vivado 2018.2 accepts the Xilinx initialization/inference style used here.
2. The two-read-port initialized memory will be evaluated by synthesis for BRAM mapping.
3. `ram_style="block"` is an implementation request, not proof.
4. Exact RAMB18/RAMB36 packing is intentionally not claimed before synthesis.
5. The dedicated Basys-3 XDC has not yet been generated in this workflow step.
6. No RTL simulation has yet been run for these new modules.
7. No synthesis/implementation report exists yet for `basys3_top_level`.
8. No board programming or physical LED/button test has yet been performed.

---

## 8. Next mandatory workflow step

The next permitted step is:

```text
Step 6 — /verify basys3_top_level
```

That step must define the verification plan before the integration testbench is generated.

No simulation should be run before the verification plan and testbench-generation steps are completed.
