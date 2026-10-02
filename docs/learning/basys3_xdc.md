# Basys 3 XDC Constraints — Teaching Notes

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 1 — `/teach basys3_xdc`  
**Status:** TEACHING IN PROGRESS — understanding gate required before design.

---

## 1. Why this module exists

The RTL can be logically correct and still fail on a real FPGA if Vivado does not know:

```text
which package pin is the clock,
which package pins are the pushbuttons,
which package pins drive the LEDs,
what electrical I/O standard each pin uses,
what clock period timing analysis must enforce.
```

That information belongs in an **XDC file**.

XDC means:

```text
Xilinx Design Constraints
```

It is not part of the datapath algorithm.

It is the contract between:

```text
logical RTL ports
        ↓
FPGA package pins / board devices
        ↓
timing analysis requirements
```

---

## 2. Current top-level interface

The current `basys3_top_level` exposes:

```text
clk_100mhz       1 input
btn_start        1 input
btn_reset        1 input
led_result[7:0]  8 outputs
led_done         1 output
```

Therefore the total logical board signals are:

```text
1 + 1 + 1 + 8 + 1
= 12
```

So the XDC must eventually constrain **12 top-level I/O signals**.

This is the origin of the earlier prediction:

```text
approximately 12 bonded I/O signals
```

The exact physical pin names are not being assumed at the teaching stage. They must come from an authoritative Basys-3 board constraint source during the design step.

---

## 3. Three different jobs of the XDC

The XDC has three major responsibilities in this project.

### 3.1 Physical pin assignment

The RTL knows only names such as:

```text
clk_100mhz
btn_start
btn_reset
led_result[0]
...
led_result[7]
led_done
```

The FPGA package contains physical pins with device-specific package names.

The XDC must establish:

```text
logical port
-> FPGA package pin
-> physical Basys-3 component
```

For example, conceptually:

```text
clk_100mhz
-> package pin X
-> Basys-3 oscillator

btn_start
-> package pin Y
-> chosen Basys-3 pushbutton

led_result[0]
-> package pin Z
-> chosen Basys-3 LED
```

Without these assignments, the bitstream does not know which external board connection should carry each RTL signal.

---

### 3.2 Electrical I/O standard

A package pin is not defined only by location.

Vivado also needs the electrical interface standard used by the board.

Conceptually:

```text
set_property IOSTANDARD <board-compatible-standard> [get_ports ...]
```

This controls electrical assumptions such as voltage/interface behavior.

For this project, the exact standard must be copied from the authoritative Basys-3 constraints for the selected board pins rather than guessed.

A correct pin with an incorrect electrical standard is still an incorrectly constrained design.

---

### 3.3 Clock timing constraint

The top-level clock is:

```text
100 MHz
```

From first principles:

```text
f = 100,000,000 Hz

T = 1/f
  = 1 / 100,000,000 s
  = 10 ns
```

Therefore the timing analyzer must know that the clock period is:

```text
10 ns
```

Conceptually, the XDC must create a clock constraint on `clk_100mhz`.

That clock constraint is what allows Vivado to ask:

```text
Can every required register-to-register path complete within the allowed 10 ns timing budget?
```

Without a valid clock constraint, a timing report may exist but it would not prove the 100 MHz requirement we actually care about.

---

## 4. Why pin constraints and timing constraints are different

These two ideas must not be mixed.

### Physical location constraint

Answers:

```text
Where is this signal connected physically?
```

Example concept:

```text
led_result[0]
-> a particular FPGA package pin
-> a particular board LED
```

### Timing constraint

Answers:

```text
How quickly must synchronous logic operate?
```

For this project:

```text
clock period = 10 ns
```

A correct LED pin assignment does not prove timing.

A correct 10 ns clock constraint does not prove that the clock is connected to the correct board pin.

Both are required.

---

## 5. Why the 100 MHz constraint matters to WNS

Suppose a particular register-to-register path has:

```text
required time = 10.0 ns
actual arrival = 8.8 ns
```

Then the setup slack is:

```text
slack = required - arrival
      = 10.0 - 8.8
      = +1.2 ns
```

So:

```text
WNS = +1.2 ns
```

for that worst path would mean it still has 1.2 ns of setup margin.

If instead:

```text
actual arrival = 10.4 ns
```

then:

```text
slack = 10.0 - 10.4
      = -0.4 ns
```

That is a setup violation.

This demonstrates why the timing constraint is not merely administrative. The 10 ns number directly defines the timing requirement used to judge the physical implementation.

---

## 6. Clock constraint versus measured accelerator latency

The two 10 ns-related ideas are different.

### Clock period

```text
10 ns
```

This is a **physical timing requirement for one clock cycle**.

### Accelerator latency

The behavioral accelerator requires seven cycles:

```text
7 cycles x 10 ns/cycle
= 70 ns
```

So:

```text
clock constraint -> physical requirement per cycle
transaction latency -> architectural number of cycles x clock period
```

A routed timing pass at 100 MHz proves that the FPGA can safely execute each required synchronous cycle within the 10 ns constraint.

It does not change the architectural transaction count of seven cycles.

---

## 7. Inputs versus outputs in the board constraint

The board interface contains three input signals:

```text
clk_100mhz
btn_start
btn_reset
```

and nine output signals:

```text
led_result[7:0]
led_done
```

Therefore:

```text
inputs  = 3
outputs = 9
total   = 12
```

The direction is defined by the Verilog module.

The XDC does not change a Verilog input into an output or vice versa.

Instead, it connects each already-defined logical direction to the intended physical board pin and electrical standard.

---

## 8. Why buttons still need synchronizers even after pin assignment

An XDC package-pin assignment does **not** make a pushbutton synchronous.

The physical button transition remains asynchronous relative to the 100 MHz oscillator.

So even after the XDC correctly maps:

```text
physical button
-> btn_start package pin
```

the RTL still needs:

```text
2-FF synchronizer
-> debounce
-> edge detection
```

The XDC solves the physical connection problem.

The `button_conditioner` solves the asynchronous-input and mechanical-bounce problem.

These are separate responsibilities.

---

## 9. Why LED constraints do not need a new timing protocol

The LED outputs are human-visible signals.

For this design:

```text
led_result = registered activation_out
led_done   = done_latched
```

The XDC must map those signals to physical LED package pins and set the correct I/O standard.

We are not designing an external high-speed source-synchronous interface here.

Therefore the important board-level constraint questions for the LEDs are primarily:

```text
correct package pin?
correct I/O standard?
correct logical bit ordering?
```

The internal paths that produce those registered values are already analyzed by the system clock timing constraint.

---

## 10. Why logical bit ordering matters

The expected board result is:

```text
34 decimal
= 0x22
= 8'b0010_0010
```

Bit positions are:

```text
bit 7 6 5 4 3 2 1 0
    0 0 1 0 0 0 1 0
```

Therefore the expected asserted result bits are:

```text
led_result[5] = 1
led_result[1] = 1
```

all other result bits are zero.

If the XDC accidentally swaps LED bit assignments, the arithmetic can be correct internally while the visible pattern is misleading.

So board validation must check not only that some LEDs light, but that the physical LED mapping preserves the intended logical bit order.

---

## 11. Why the XDC must match the actual top-level port names

Vivado constraints select ports by name.

The current RTL names are:

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

If the XDC instead referred to stale names such as:

```text
clk
reset
start
led[7:0]
```

those constraints would not correctly apply to the actual top-level interface.

Therefore the XDC must be generated from the **current RTL interface**, not copied blindly from an unrelated example.

---

## 12. Why a master board XDC should not be enabled blindly

Board vendors often provide a master constraint file containing many board resources.

Our top level uses only:

```text
1 clock
2 buttons
9 LEDs
```

Enabling unrelated constraints can create confusion and unnecessary warnings.

The preferred approach for this project is:

```text
start from authoritative Basys-3 pin information
-> select only the ports actually used
-> rename/select them to match basys3_top_level
-> preserve the correct I/O standard
-> add the 100 MHz clock constraint
```

This keeps the physical interface auditable.

---

## 13. What an XDC can prove

Once the correct XDC is attached and Vivado successfully implements the design, it can establish evidence for:

```text
logical-to-package-pin mapping
correct board I/O standard declarations
recognized 100 MHz clock requirement
timing analysis against a 10 ns period
implemented I/O placement
```

Combined with implementation reports, this moves the design from purely logical integration toward physical FPGA validation.

---

## 14. What an XDC cannot prove

An XDC alone does not prove:

```text
the datapath result is correct
the core takes seven cycles
the memory returns correct words
BRAM was actually inferred
DSP count
LUT/FF utilization
timing closure
the real LED visibly works
the real pushbutton electrically works
```

Those require other evidence:

```text
functional behavior
-> simulation

resource mapping
-> synthesis

routed timing
-> implementation / STA

real board operation
-> bitstream + hardware test
```

---

## 15. Physical-validation evidence chain

The physical-validation sequence should be understood as:

```text
RTL already behaviorally verified
        ↓
correct Basys-3 XDC
        ↓
synthesis
        ↓
resource utilization / BRAM / DSP evidence
        ↓
implementation
        ↓
post-route timing
        ↓
bitstream
        ↓
program Basys 3
        ↓
physical button / result LED / done LED validation
```

Skipping directly from simulation to board programming would make failures much harder to diagnose because pin mapping, resource inference, and timing would not have been checked independently.

---

## 16. Explicit assumptions

1. The target remains `XC7A35T-1CPG236C`.
2. The board remains Basys 3.
3. The board oscillator supplied to `clk_100mhz` is intended to be used as the 100 MHz system clock.
4. The current `basys3_top_level` port list is the interface that will be constrained.
5. Only two physical pushbuttons are required: one start and one reset.
6. Nine physical LEDs are required: eight result bits plus one done indication.
7. The exact Basys-3 package pin names and board I/O standard values are **not assumed in this teaching document**; they must be taken from an authoritative Basys-3 constraint source in the design step.
8. No extra generated clock is required because the architecture remains one 100 MHz clock domain.
9. No numerical physical timing result is assumed before implementation.
10. No BRAM inference claim is made by the XDC itself.

---

## 17. Key derivations

### Board signal count

```text
1 clock
+ 2 buttons
+ 8 result LEDs
+ 1 done LED
= 12 board signals
```

### Clock period

```text
T = 1 / 100 MHz
  = 10 ns
```

### Expected visible result

```text
34 decimal
= 0x22
= 0010_0010

logical result bits high:
led_result[5]
led_result[1]
```

### Hardware debounce

```text
1,000,000 cycles x 10 ns
= 10 ms
```

These values connect the already-understood Phase-8 RTL to the upcoming physical board constraints.

---

## 18. Understanding gate

Before `/design basys3_xdc`, explain in your own words:

1. What are the three main jobs of the XDC in this project?
2. Why does a 100 MHz clock require a 10 ns timing constraint?
3. What is the difference between a package-pin constraint and a clock timing constraint?
4. Derive why the current top level requires 12 constrained board signals.
5. Why does mapping `btn_start` to a physical package pin not remove the need for the two-FF synchronizer and debounce logic?
6. Why must the logical-to-physical LED bit ordering be correct for the expected result `0x22`?
7. What can an XDC prove, and what still requires synthesis, implementation, or hardware testing?
8. Why should exact Basys-3 package pins be taken from an authoritative board constraint source instead of guessed?
