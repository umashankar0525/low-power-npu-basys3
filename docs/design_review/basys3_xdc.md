# Basys 3 XDC Constraints — Design Review

**Role:** Design Reviewer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 10 — `/review basys3_xdc`  
**Status:** APPROVED — XDC source and Vivado-applied constraint verification passed. Broader FPGA physical sign-off remains pending.

---

## 1. Review scope

This review covers the dedicated Basys-3 constraint module:

```text
vivado/constraints/basys3_top_level.xdc
```

The review checks:

```text
top-level port coverage
package-pin mapping
I/O standards
clock definition
clock waveform
configuration properties
Vivado constraint-object application
verification evidence
prediction-versus-measurement agreement
```

This review does **not** claim:

```text
BRAM/resource sign-off
post-route timing closure
bitstream success
physical board functionality
```

Those are later Phase-8 physical-validation items.

---

## 2. Requirement traceability

The approved top-level interface contains:

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

Total physical board-signal count:

```text
1 clock
+ 2 buttons
+ 8 result LEDs
+ 1 done LED
= 12 signals
```

The XDC contains one approved mapping for each of those 12 signals.

**Review result: PASS**

---

## 3. Clock mapping review

Approved mapping:

```text
clk_100mhz
-> W5
-> LVCMOS33
```

Clock derivation:

```text
f = 100 MHz

T = 1/f
  = 1/(100 x 10^6)
  = 10 ns
```

Generated constraint intent:

```text
clock name = sys_clk_pin
period     = 10.000 ns
waveform   = {0 5}
```

Measured Vivado evidence:

```text
clock objects on clk_100mhz = 1
primary clock name          = sys_clk_pin
primary clock period        = 10.000 ns
rising edge                 = 0.000 ns
falling edge                = 5.000 ns
total design clock count    = 1
```

**Review result: PASS**

Important boundary:

```text
clock constraint recognized
!=
100 MHz timing closure
```

Timing closure still requires post-route STA.

---

## 4. Pushbutton mapping review

Approved mapping:

```text
btn_start -> btnC -> U18 -> LVCMOS33
btn_reset -> btnD -> U17 -> LVCMOS33
```

Vivado measured:

```text
btn_start object count = 1
btn_start PACKAGE_PIN  = U18
btn_start IOSTANDARD   = LVCMOS33

btn_reset object count = 1
btn_reset PACKAGE_PIN  = U17
btn_reset IOSTANDARD   = LVCMOS33
```

The XDC correctly handles only the physical/electrical connection.

The following remain RTL responsibilities:

```text
synchronization
debouncing
edge detection
reset behavior
```

**Review result: PASS**

---

## 5. Result-LED mapping review

The XDC preserves direct bit ordering:

```text
led_result[n]
-> physical LEDn
```

Measured mappings:

```text
led_result[0] -> U16
led_result[1] -> E19
led_result[2] -> U19
led_result[3] -> V19
led_result[4] -> W18
led_result[5] -> U15
led_result[6] -> U14
led_result[7] -> V14
```

All eight use:

```text
LVCMOS33
```

For the verified behavioral result:

```text
34 decimal
= 0x22
= 0010_0010
```

the intended physical result remains:

```text
LED5 = ON
LED1 = ON
```

The XDC proves the physical bit mapping.

It does not itself prove the arithmetic result or physical illumination.

**Review result: PASS**

---

## 6. Done-LED mapping review

Approved mapping:

```text
led_done
-> LED8
-> V13
-> LVCMOS33
```

Measured Vivado evidence:

```text
led_done object count = 1
led_done PACKAGE_PIN  = V13
led_done IOSTANDARD   = LVCMOS33
```

The already-verified RTL path is:

```text
core_done
-> done_latched
-> led_done
```

This XDC module verifies only:

```text
led_done
-> V13 / LED8
```

**Review result: PASS**

---

## 7. I/O-standard review

Prediction:

```text
12 / 12 selected ports
-> LVCMOS33
```

Measured result:

```text
12 / 12 selected ports
-> LVCMOS33
```

**Review result: PASS**

---

## 8. Package-pin uniqueness review

Expected:

```text
12 logical board ports
-> 12 unique package pins
```

Measured:

```text
unique PACKAGE_PIN count = 12
```

Therefore:

```text
duplicate selected PACKAGE_PIN assignments = 0
```

**Review result: PASS**

---

## 9. Configuration-property review

Generated XDC contains:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

Vivado measured:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

**Review result: PASS**

---

## 10. Verification methodology review

A normal Verilog testbench was correctly rejected as insufficient for this constraint artifact.

Reason:

```text
Verilog simulation
-> logical behavior

Vivado constraint database
-> PACKAGE_PIN
-> IOSTANDARD
-> clock objects
-> configuration properties
```

The Step-7 Tcl verification artifact queried Vivado directly.

Measured outcome:

```text
Checks executed: 59
Errors found:    0
```

This is stronger than static source inspection because it proves the constraints were applied to the actual loaded design objects.

**Review result: PASS**

---

## 11. Prediction-versus-measurement review

Step-3 predictions included:

```text
12 required ports
12 unique package pins
LVCMOS33 on all selected ports
1 primary clock
10.000 ns period
{0 5} waveform
0 constraint-verification errors
```

Step-8 measurements matched those predictions.

For every directly tested constraint property:

```text
prediction -> measurement = MATCH
```

**Review result: PASS**

---

## 12. Evidence boundary review

### Proven for this XDC module

```text
12/12 port-object resolution
12/12 package-pin mappings
12/12 LVCMOS33 application
12 unique package pins
1 primary clock object
clock name = sys_clk_pin
period = 10.000 ns
waveform = {0 5}
CONFIG_VOLTAGE = 3.3
CFGBVS = VCCO
59 verification checks
0 verification errors
```

### Not proven by this XDC module

```text
final LUT count
final FF count
final CARRY4 count
final DSP count
final BRAM count
final IOB/BUFG utilization
WNS
TNS
WHS
THS
critical path
power
bitstream generation
physical button operation
physical LED operation
```

These are intentionally outside this module's proof boundary.

---

## 13. Remaining Phase-8 physical work

After this XDC review, the broader Phase-8 physical-validation path still requires:

```text
1. final top-level synthesis utilization
2. BRAM/DSP/LUT/FF/CARRY4/IOB/BUFG measurements
3. implementation/place-and-route
4. post-route timing summary
5. critical-path inspection
6. bitstream generation
7. Basys-3 programming
8. physical start/reset tests
9. physical result/done LED tests
10. optional power measurement/analysis
```

These are not defects in the XDC module; they are subsequent physical-validation stages.

---

## 14. Review decision

**BASYS3 XDC DESIGN REVIEW: APPROVED**

Reason:

```text
design intent is complete
source mapping is complete
Vivado applies all expected constraints
prediction and measurement agree
verification reports 59 checks / 0 errors
no XDC-specific blocker remains
```

The module may proceed to:

```text
Step 11 — /test basys3_xdc
```

after the learner passes the Step-10 review-understanding gate.

---

## 15. Step-10 understanding gate

Before Step 11, explain in your own words:

1. Why can this XDC module be approved even though overall FPGA physical sign-off is still incomplete?
2. What evidence makes the XDC stronger than merely saying the file "looks correct"?
3. What exactly did the 59-check Vivado verification prove?
4. Why does the measured 10.000 ns clock still not prove 100 MHz timing closure?
5. Which report must prove BRAM/resource mapping?
6. Which report must prove WNS/TNS/WHS/THS?
7. Which Phase-8 physical tasks remain after the XDC module itself is approved?
