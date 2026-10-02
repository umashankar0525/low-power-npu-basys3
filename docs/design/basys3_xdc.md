# Basys 3 XDC Constraints — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 2 — `/design basys3_xdc`  
**Status:** DESIGN COMPLETE — understanding gate required before Step 3 `/analyze basys3_xdc`.

---

## 1. Design Objective

The purpose of `basys3_xdc` is to create the physical constraint specification that connects the already-verified `basys3_top_level` RTL interface to the Basys-3 board.

The XDC must establish three independent contracts:

```text
logical RTL port
-> correct FPGA package pin

package pin
-> correct electrical I/O standard

clk_100mhz
-> 100 MHz / 10 ns timing requirement
```

The XDC does **not** change the accelerator architecture or transaction schedule.

---

## 2. Authoritative Source

Exact board pin mappings are taken from Digilent's official Basys-3 master XDC:

```text
Digilent/digilent-xdc
Basys-3-Master.xdc
```

The official source identifies:

```text
100 MHz clock  -> W5
IOSTANDARD     -> LVCMOS33
btnC           -> U18
btnU           -> T18
btnL           -> W19
btnR           -> T17
btnD           -> U17
```

and the first nine LEDs as:

```text
LED0 -> U16
LED1 -> E19
LED2 -> U19
LED3 -> V19
LED4 -> W18
LED5 -> U15
LED6 -> U14
LED7 -> V14
LED8 -> V13
```

The official clock constraint uses a 10 ns period with a 50% duty-cycle waveform.

No package pin in this design is guessed from memory.

---

## 3. Current RTL Interface

The existing `basys3_top_level` interface is:

```verilog
input  clk_100mhz
input  btn_start
input  btn_reset

output [7:0] led_result
output       led_done
```

Therefore:

```text
inputs  = 3
outputs = 9
total   = 12 constrained board signals
```

The XDC names must exactly match these RTL port names.

---

## 4. Selected Physical Human-Interface Mapping

### 4.1 Start button

Selected board control:

```text
Basys-3 btnC
```

Mapping:

```text
btn_start
-> btnC
-> package pin U18
-> LVCMOS33
```

### Why btnC is chosen

The center button is the most natural primary action button for a simple board demonstration.

The action is:

```text
press center
-> request one NPU transaction
```

The existing RTL then performs:

```text
synchronize
-> debounce
-> rising-edge pulse
-> busy mask
-> core_start
```

The XDC only establishes the physical entry point.

---

### 4.2 Reset button

Selected board control:

```text
Basys-3 btnD
```

Mapping:

```text
btn_reset
-> btnD
-> package pin U17
-> LVCMOS33
```

### Why btnD is chosen

Reset is intentionally assigned to a button separate from the primary center/start control.

This avoids using the same physical location for both the normal transaction action and reset.

The choice is a user-interface design decision; the electrical correctness comes from the official Digilent pin mapping.

---

## 5. Clock Mapping

The Basys-3 100 MHz board clock maps to:

```text
clk_100mhz
-> package pin W5
-> LVCMOS33
```

The system frequency is:

```text
f = 100 MHz
  = 100 x 10^6 Hz
```

Therefore:

```text
T = 1/f
  = 1/(100 x 10^6)
  = 10 ns
```

The design constraint must therefore create a clock with:

```text
period   = 10.000 ns
waveform = rising at 0 ns, falling at 5 ns
```

This describes a 50% duty-cycle 100 MHz input clock for timing analysis.

---

## 6. Result LED Mapping

The eight result bits are mapped directly in order to the first eight Basys-3 LEDs.

| RTL signal | Board LED | Package pin | I/O standard |
|---|---:|---|---|
| `led_result[0]` | LED0 | U16 | LVCMOS33 |
| `led_result[1]` | LED1 | E19 | LVCMOS33 |
| `led_result[2]` | LED2 | U19 | LVCMOS33 |
| `led_result[3]` | LED3 | V19 | LVCMOS33 |
| `led_result[4]` | LED4 | W18 | LVCMOS33 |
| `led_result[5]` | LED5 | U15 | LVCMOS33 |
| `led_result[6]` | LED6 | U14 | LVCMOS33 |
| `led_result[7]` | LED7 | V14 | LVCMOS33 |

This preserves the logical bit ordering:

```text
led_result[n]
-> board LED n
```

No bit permutation is introduced by the XDC.

---

## 7. Done LED Mapping

The persistent completion indicator uses the next available board LED:

```text
led_done
-> board LED8
-> package pin V13
-> LVCMOS33
```

Therefore the board display is divided cleanly into:

```text
LED0..LED7
-> result byte

LED8
-> persistent done status
```

This makes the board demonstration easy to interpret visually.

---

## 8. Expected Physical LED Pattern

The verified nominal board result is:

```text
34 decimal
= 0x22
= 8'b0010_0010
```

Thus:

```text
led_result[5] = 1
led_result[1] = 1
all other result bits = 0
```

Because result bit n maps directly to board LED n, the expected physical result is:

```text
LED5 = ON
LED1 = ON
LED0,2,3,4,6,7 = OFF
```

After completion:

```text
LED8 = ON
```

So the expected final board pattern is conceptually:

```text
result LEDs 7..0 = 0010_0010
done LED8        = 1
```

This direct mapping minimizes ambiguity during hardware bring-up.

---

## 9. Complete Constraint Mapping Table

| Logical RTL port | Physical Basys-3 resource | Package pin | I/O standard | Timing role |
|---|---|---|---|---|
| `clk_100mhz` | CLK100MHZ | W5 | LVCMOS33 | 10 ns clock |
| `btn_start` | btnC | U18 | LVCMOS33 | asynchronous board input |
| `btn_reset` | btnD | U17 | LVCMOS33 | asynchronous board input |
| `led_result[0]` | LED0 | U16 | LVCMOS33 | output |
| `led_result[1]` | LED1 | E19 | LVCMOS33 | output |
| `led_result[2]` | LED2 | U19 | LVCMOS33 | output |
| `led_result[3]` | LED3 | V19 | LVCMOS33 | output |
| `led_result[4]` | LED4 | W18 | LVCMOS33 | output |
| `led_result[5]` | LED5 | U15 | LVCMOS33 | output |
| `led_result[6]` | LED6 | U14 | LVCMOS33 | output |
| `led_result[7]` | LED7 | V14 | LVCMOS33 | output |
| `led_done` | LED8 | V13 | LVCMOS33 | output |

Count check:

```text
1 clock
+ 2 buttons
+ 8 result LEDs
+ 1 done LED
= 12 constrained ports
```

All 12 current top-level ports are accounted for.

---

## 10. Clock Constraint Design

The conceptual timing constraint is:

```text
create a clock on clk_100mhz
period = 10 ns
waveform = {0 ns, 5 ns}
```

This means the timing engine analyzes the synchronous system against:

```text
one cycle = 10 ns
```

The existing accelerator behavior remains:

```text
7 architectural cycles
x 10 ns/cycle
= 70 ns transaction latency
```

The XDC does not change the seven-cycle schedule.

It makes the physical implementation prove that each required cycle can safely complete at 100 MHz.

---

## 11. Button Timing Treatment

The pushbuttons are asynchronous physical inputs.

Their package-pin constraints do not make them synchronous.

The RTL handles them using:

```text
ASYNC button
-> 2-FF synchronizer
-> debounce
-> clean level / rising pulse
```

For this first board bring-up, no external input-delay constraint is defined for the pushbuttons because they are not synchronous source interfaces relative to `clk_100mhz`.

The design instead treats them as asynchronous human inputs and resolves metastability risk in RTL through the synchronizer chain.

This is distinct from a high-speed synchronous interface where `set_input_delay` would be defined relative to an external clock.

---

## 12. LED Timing Treatment

The LEDs are human-visible outputs, not synchronous data sent to an external sampling device with a defined setup/hold requirement.

Therefore the design does not introduce a `set_output_delay` requirement for the LEDs.

The internal synchronous paths that generate:

```text
core_activation_out
done_latched
```

are already analyzed under the 100 MHz system clock.

The XDC responsibilities for the LEDs are:

```text
PACKAGE_PIN
IOSTANDARD
correct bit ordering
```

---

## 13. Configuration-Level Properties

The official Digilent master XDC also provides general configuration properties:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

These are board/device configuration properties rather than algorithm behavior.

The implementation XDC may preserve these general Basys-3 settings because they come from the authoritative board source.

Bitstream compression/configuration-rate settings are not required for the functional pin/timing objective and are not part of the minimum constraint set for this module.

---

## 14. Constraint Scope

The dedicated project XDC should contain only the board resources used by `basys3_top_level`:

```text
clock
btnC as btn_start
btnD as btn_reset
LED0..LED7 as led_result[0..7]
LED8 as led_done
100 MHz create_clock
required board configuration voltage properties
```

Unused switches, seven-segment pins, VGA, UART, Pmod pins, and other Basys-3 resources should not be enabled.

This avoids stale or unrelated constraints.

---

## 15. Port-Name Consistency Requirement

The constraint file must reference the exact RTL names:

```text
clk_100mhz
btn_start
btn_reset
led_result[0]
led_result[1]
...
led_result[7]
led_done
```

A copied master XDC cannot be used unchanged because its original logical names are generic board names such as:

```text
clk
btnC
btnD
led[0]
...
```

The physical package data is retained, but the `get_ports` names must be adapted to the actual NPU top-level interface.

---

## 16. Expected Physical Validation Sequence

After the XDC is generated, the physical flow is:

```text
basys3_top_level RTL
+
basys3_top_level XDC
        ↓
synthesis
        ↓
verify:
  no unconstrained top-level I/O
  resource utilization
  BRAM > 0
  DSP mapping
        ↓
implementation
        ↓
verify:
  WNS / TNS
  WHS / THS
  clock recognized as 10 ns
  physical I/O placement
        ↓
bitstream
        ↓
program Basys 3
        ↓
press btnC
        ↓
LED5 + LED1 show result 34
LED8 latches done
        ↓
press btnD
        ↓
board-visible state eventually clears
```

---

## 17. Acceptance Criteria for the XDC Module

The XDC design will be considered logically correct only if all of the following hold:

```text
1. exactly the 12 required top-level board ports are constrained
2. clk_100mhz maps to W5
3. btn_start maps to btnC / U18
4. btn_reset maps to btnD / U17
5. led_result[0..7] map directly to LED0..LED7
6. led_done maps to LED8
7. all selected pins use LVCMOS33
8. clk_100mhz has a 10 ns timing constraint
9. logical port names exactly match basys3_top_level
10. no unrelated board resources are unnecessarily enabled
```

Physical implementation must subsequently prove that Vivado accepts and applies the constraints without board-critical errors.

---

## 18. Explicit Assumptions

1. Board: Basys 3, revision compatible with Digilent's published Basys-3 master XDC.
2. FPGA: `XC7A35T-1CPG236C`.
3. System oscillator: Basys-3 100 MHz clock on package pin W5.
4. Electrical standard for selected clock, pushbutton, and LED resources: LVCMOS33, as specified by Digilent's master XDC.
5. Center button is selected for start.
6. Down button is selected for reset.
7. Board LEDs 0 through 7 directly represent result bits 0 through 7.
8. Board LED8 is the persistent done indicator.
9. Buttons remain asynchronous to the system clock and are handled by the existing synchronizer/debounce RTL.
10. LEDs are human-visible outputs and do not require external synchronous output-delay constraints.
11. No generated clock is introduced.
12. No exact physical timing result is assumed before implementation.
13. BRAM inference remains outside the XDC's proof domain.

---

## 19. Design Review Against the Teaching Requirements

### Pin mapping

Resolved from authoritative board data.

### I/O standard

Resolved as LVCMOS33 for every selected board signal.

### Clock constraint

Derived from first principles:

```text
100 MHz -> 10 ns
```

### Button conditioning

Still remains an RTL responsibility.

### Visible result mapping

Direct bit-to-LED mapping removes permutation ambiguity.

### Evidence boundary

The XDC defines physical/timing intent but does not itself prove resource mapping, timing closure, or real board operation.

---

## 20. Understanding Gate

Before Step 3 `/analyze basys3_xdc`, explain in your own words:

1. Why was btnC selected for `btn_start` and btnD for `btn_reset`, and which exact package pins do they map to?
2. Derive the 10 ns clock period and explain what the `{0 5}` waveform means.
3. Why is `led_result[n] -> board LED n` preferable to an arbitrary LED permutation?
4. For result `0x22`, which physical result LEDs should be on, and which LED indicates done?
5. Why are `set_input_delay` constraints not being added for the human pushbuttons in this first bring-up?
6. Why are `set_output_delay` constraints not being added for the LEDs?
7. Why does this XDC constrain exactly 12 board ports?
8. What does the XDC still fail to prove even after all pins and the 10 ns clock are correctly constrained?
