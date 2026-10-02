# Basys 3 XDC Constraints — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 6 — `/verify basys3_xdc`  
**Status:** VERIFICATION PLAN COMPLETE — Vivado execution evidence still pending.

---

## 1. Verification objective

The purpose of this verification step is to prove that the generated:

```text
vivado/constraints/basys3_top_level.xdc
```

correctly constrains the actual `basys3_top_level` interface and that Vivado later applies those constraints as intended.

This verification is divided into two evidence classes:

```text
A. Static source verification
   -> compare XDC text against the RTL interface and approved design

B. Vivado-applied verification
   -> prove Vivado recognized the pins, I/O standards, and 100 MHz clock
```

A static source review can prove that the file text is internally consistent.

It cannot prove that Vivado successfully applied every constraint.

---

## 2. Explicit assumptions

1. Target device remains `XC7A35T-1CPG236C`.
2. Target board remains Basys 3.
3. `basys3_top_level` remains the implementation top.
4. The current RTL top-level ports are unchanged.
5. The generated XDC currently has blob SHA `934ca78ce7b2c40461dd26bf83be1049c1b4aa78`.
6. The exact package-pin values come from the approved Digilent Basys-3 mapping established in the design step.
7. No Vivado synthesis/implementation run is claimed in this document.
8. No timing, BRAM, resource, or physical-board result is assumed until measured.

---

## 3. Interface inventory from RTL

The current top-level interface contains:

```text
input  clk_100mhz
input  btn_start
input  btn_reset
output led_result[7:0]
output led_done
```

Port-bit count:

```text
clk_100mhz       = 1
btn_start        = 1
btn_reset        = 1
led_result[7:0]  = 8
led_done         = 1
----------------------
total            = 12
```

Therefore the first verification invariant is:

```text
every one of these 12 port bits must receive
PACKAGE_PIN + IOSTANDARD constraints
```

---

## 4. Static source verification matrix

The generated XDC is expected to contain exactly the following physical mappings.

| RTL port | Expected package pin | Expected I/O standard | Static file status |
|---|---|---|---|
| `clk_100mhz` | W5 | LVCMOS33 | PRESENT |
| `btn_start` | U18 | LVCMOS33 | PRESENT |
| `btn_reset` | U17 | LVCMOS33 | PRESENT |
| `led_result[0]` | U16 | LVCMOS33 | PRESENT |
| `led_result[1]` | E19 | LVCMOS33 | PRESENT |
| `led_result[2]` | U19 | LVCMOS33 | PRESENT |
| `led_result[3]` | V19 | LVCMOS33 | PRESENT |
| `led_result[4]` | W18 | LVCMOS33 | PRESENT |
| `led_result[5]` | U15 | LVCMOS33 | PRESENT |
| `led_result[6]` | U14 | LVCMOS33 | PRESENT |
| `led_result[7]` | V14 | LVCMOS33 | PRESENT |
| `led_done` | V13 | LVCMOS33 | PRESENT |

Static source result:

```text
12 / 12 expected logical port bits are represented in the XDC
```

This is source-level evidence only.

---

## 5. Unique-package-pin verification

The package pins used are:

```text
W5
U18
U17
U16
E19
U19
V19
W18
U15
U14
V14
V13
```

Count:

```text
12 listed package pins
```

All 12 are unique in the generated XDC.

Therefore the source-level prediction is:

```text
duplicate PACKAGE_PIN assignments = 0
```

Vivado must later confirm that no placement conflict exists.

---

## 6. Port-name binding verification

The XDC uses:

```text
clk_100mhz
btn_start
btn_reset
led_result[0]
led_result[1]
led_result[2]
led_result[3]
led_result[4]
led_result[5]
led_result[6]
led_result[7]
led_done
```

These names match the current RTL top-level interface.

The verification requirement in Vivado is:

```text
every get_ports expression must resolve to exactly the intended port object
```

Evidence of failure would include messages such as:

```text
no ports matched
invalid get_ports target
constraint not applied
```

Acceptance criterion:

```text
invalid get_ports references = 0
```

---

## 7. Clock-constraint verification

The XDC defines:

```text
create_clock
name     = sys_clk_pin
period   = 10.000 ns
waveform = {0 5}
port     = clk_100mhz
```

From first principles:

```text
f = 100 MHz

T = 1/f
  = 1/(100 x 10^6)
  = 10 ns
```

and:

```text
high time = 5 ns
low time  = 5 ns

duty cycle
= 5 / 10
= 0.5
= 50%
```

Expected Vivado clock evidence:

```text
primary clock count = 1
clock name          = sys_clk_pin
clock period        = 10.000 ns
clock frequency     = 100 MHz
waveform            = rising 0 ns, falling 5 ns
```

A source-level `create_clock` line is not sufficient physical evidence.

The clock/timing report must show that the clock object exists.

---

## 8. I/O-standard verification

Every selected physical board signal is declared:

```text
IOSTANDARD LVCMOS33
```

Expected Vivado I/O evidence:

```text
12 / 12 selected top-level port bits
-> LVCMOS33
```

Acceptance criterion:

```text
missing IOSTANDARD on required ports = 0
```

A single port showing an unspecified/default standard is a verification failure.

---

## 9. Configuration-property verification

The generated XDC includes:

```text
CONFIG_VOLTAGE 3.3
CFGBVS VCCO
```

These should be accepted by Vivado for the current design/device.

Verification requirement:

```text
no constraint error related to CONFIG_VOLTAGE or CFGBVS
```

These properties do not prove datapath correctness.

---

## 10. Expected I/O utilization

The top-level physically exposes:

```text
3 inputs + 9 outputs = 12 signals
```

Therefore the expected bonded-I/O utilization is:

```text
IOB/package I/O approximately 12
```

This is a prediction, not yet a measured fact.

The post-synthesis or implementation utilization report must confirm the actual final I/O count.

If the report shows a different number, the reason must be investigated rather than automatically accepted.

---

## 11. Expected XDC-critical message checks

The verification run must explicitly inspect Vivado messages for these failure classes:

```text
1. missing PACKAGE_PIN
2. missing IOSTANDARD
3. invalid get_ports
4. duplicate PACKAGE_PIN
5. missing / absent primary clock
6. malformed clock constraint
7. incompatible I/O placement
8. configuration-property error
```

Expected result:

```text
XDC-critical errors          = 0
XDC-critical critical warnings = 0
```

This is not equivalent to requiring the total Vivado warning count to be zero.

---

## 12. Constraint-coverage verification

The verification question is not merely:

```text
"Does the XDC file contain 12 set_property statements?"
```

It is:

```text
"Did Vivado apply a valid physical location and I/O standard
to every required top-level port bit?"
```

The clock additionally requires:

```text
"Did Vivado create the intended 10 ns primary clock?"
```

So constraint coverage requires both source inspection and tool-applied evidence.

---

## 13. Result-LED mapping verification

The intended result is:

```text
34 decimal
= 0x22
= 0010_0010
```

Therefore:

```text
led_result[5] = 1 -> U15 -> LED5
led_result[1] = 1 -> E19 -> LED1
```

Expected board pattern after successful transaction:

```text
LED5 = ON
LED1 = ON
LED0,2,3,4,6,7 = OFF
```

This verification has three distinct layers:

```text
XDC verification
-> prove led_result bits map to intended package pins

RTL verification
-> prove result is 0x22

hardware verification
-> prove physical LEDs visibly match the expected pattern
```

The first two do not substitute for the third.

---

## 14. Done-LED mapping verification

The intended path is:

```text
core_done
-> done_latched
-> led_done
-> V13
-> LED8
```

For the XDC module, only this segment is under direct verification:

```text
led_done
-> V13 / LED8
```

Behavioral correctness of `done_latched` has already been verified separately.

Physical illumination of LED8 remains a later hardware measurement.

---

## 15. Button mapping verification

The intended physical controls are:

```text
btnC / U18 -> btn_start
btnD / U17 -> btn_reset
```

The XDC verification must prove the package-pin mapping.

It does not prove:

```text
2-FF synchronization
debounce duration
start pulse generation
reset semantics
```

Those are RTL concerns.

Later board testing must prove that pressing the intended physical buttons produces the expected visible behavior.

---

## 16. Timing-boundary verification

The XDC establishes:

```text
required clock period = 10 ns
```

It does not establish:

```text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
```

Those are implementation/STA outcomes.

Therefore a successful XDC verification means:

```text
Vivado is analyzing the design against the correct 10 ns requirement
```

not:

```text
the design has already met 100 MHz timing
```

---

## 17. BRAM/resource boundary verification

The XDC contains no resource-inference requirement for:

```text
BRAM
DSP
LUT
FF
CARRY4
```

Therefore XDC verification cannot establish any of those final utilization numbers.

The next physical-flow evidence must later prove:

```text
BRAM > 0 or explain why not
DSP count
LUT count
FF count
CARRY4 count
IOB count
BUFG count
```

through synthesis/utilization reports.

---

## 18. Required Vivado evidence set

Before the XDC can be called tool-verified, capture at least:

```text
A. I/O port/package report
   -> port name
   -> package pin
   -> I/O standard

B. clock report
   -> sys_clk_pin
   -> period 10.000 ns
   -> waveform 0 / 5 ns

C. Vivado messages / DRC
   -> no XDC-critical errors or critical warnings

D. utilization report
   -> confirms final I/O count
   -> later also used for BRAM/DSP/LUT/FF evidence
```

Implementation timing reports belong to the broader physical sign-off step, although they will also depend on this XDC being correct.

---

## 19. Verification pass/fail criteria

The `basys3_xdc` verification stage passes only when all of the following are demonstrated:

```text
[ ] all 12 required port bits resolve in Vivado
[ ] all 12 have the approved PACKAGE_PIN values
[ ] all 12 use LVCMOS33
[ ] no duplicate package-pin assignment exists
[ ] sys_clk_pin exists on clk_100mhz
[ ] clock period = 10.000 ns
[ ] waveform = {0 5}
[ ] no required board port remains unconstrained
[ ] no invalid get_ports reference exists
[ ] CONFIG_VOLTAGE / CFGBVS constraints are accepted
[ ] no XDC-critical error/critical warning remains
[ ] final I/O utilization is consistent with the 12-signal interface
```

Until those Vivado measurements are captured, the correct status is:

```text
XDC source verified by inspection
Vivado-applied XDC verification pending
```

---

## 20. Current verification status

### Already established from repository inspection

```text
PASS: RTL exposes exactly the expected 12 board port bits
PASS: XDC contains mappings for all 12
PASS: XDC pin values match the approved design
PASS: all selected XDC entries specify LVCMOS33
PASS: package pins are unique in the XDC source
PASS: create_clock specifies 10.000 ns and {0 5}
PASS: configuration properties are present
PASS: no set_input_delay / set_output_delay constraints are intentionally present
```

### Still unproven

```text
Vivado successfully resolves every get_ports expression
Vivado reports all intended PACKAGE_PIN assignments
Vivado reports LVCMOS33 on all selected I/O
Vivado recognizes sys_clk_pin as one 10 ns primary clock
Vivado reports zero XDC-critical issues
final bonded-I/O utilization
physical board behavior
```

---

## 21. Understanding gate

Before proceeding to the next verification action, explain in your own words:

1. Why is source inspection of the XDC not enough to prove the constraints were applied?
2. What exact evidence should the Vivado I/O report provide?
3. What exact evidence should the Vivado clock report provide?
4. Why does a 10 ns recognized clock still not prove timing closure?
5. Why do we expect 12 bonded I/O, and why must the utilization report still confirm it?
6. Which XDC-critical failure classes must be explicitly checked?
7. Why are BRAM/DSP/LUT/FF counts outside the proof scope of XDC verification?
8. What is the difference between "XDC source verified" and "XDC tool-verified"?
