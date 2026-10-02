# Basys 3 XDC Constraints — Vivado Measurement Result

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 8 — Vivado measurement  
**Status:** PASSED — XDC is tool-verified in Vivado. Resource/timing/hardware sign-off remains pending.

---

## 1. Measurement source

The user executed:

```tcl
source {C:/Users/UMA SHANKAR/OneDrive/Documents/low-power-npu-basys3/tb/scripts/verify_basys3_xdc.tcl}
```

inside Vivado with the design loaded.

The verification artifact queried Vivado's live constraint database.

---

## 2. Overall result

Vivado reported:

```text
Checks executed: 59
Errors found:    0

PASS: basys3_xdc constraint database matches the approved design.
NOTE: This is not synthesis-resource, routed-timing, or hardware sign-off.
```

Therefore:

```text
XDC source verification  = PASS
XDC Vivado tool verification = PASS
```

---

## 3. Port-object resolution

Every required top-level port object resolved exactly once.

Measured examples include:

```text
clk_100mhz object count = 1
btn_start object count  = 1
btn_reset object count  = 1

led_result[0] object count = 1
...
led_result[7] object count = 1

led_done object count = 1
```

This proves that the XDC `get_ports` expressions bind to the intended current top-level interface.

---

## 4. Measured PACKAGE_PIN mappings

Vivado confirmed:

```text
clk_100mhz    -> W5
btn_start     -> U18
btn_reset     -> U17

led_result[0] -> U16
led_result[1] -> E19
led_result[2] -> U19
led_result[3] -> V19
led_result[4] -> W18
led_result[5] -> U15
led_result[6] -> U14
led_result[7] -> V14

led_done      -> V13
```

All measured values match the approved design.

---

## 5. Measured I/O standards

For every required board port, Vivado reported:

```text
IOSTANDARD = LVCMOS33
```

Therefore:

```text
12 / 12 required port bits
-> LVCMOS33
```

No required selected port was missing its intended I/O standard.

---

## 6. Unique-package-pin result

Each port was measured on a unique package pin.

The script reported:

```text
PASS: unique PACKAGE_PIN count = 12
```

Therefore:

```text
duplicate selected package-pin assignments = 0
```

for the approved 12-port interface.

---

## 7. Clock-object measurement

Vivado reported:

```text
clock objects on clk_100mhz = 1
primary clock name          = sys_clk_pin
primary clock period        = 10.000 ns
clock waveform edge count   = 2
clock rising edge           = 0.000 ns
clock falling edge          = 5.000 ns
total design clock count    = 1
```

The derived frequency is:

```text
f = 1 / 10 ns
  = 100 MHz
```

Therefore the intended primary clock was successfully recognized.

---

## 8. Configuration-property measurement

Vivado reported:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

These match the intended Basys-3 configuration properties.

---

## 9. Measured versus predicted summary

| Quantity | Predicted | Measured | Result |
|---|---:|---:|---|
| Required port mappings | 12 | 12 resolved | PASS |
| Unique package pins | 12 | 12 | PASS |
| Selected I/O standard | LVCMOS33 | LVCMOS33 on all 12 | PASS |
| Primary clock count | 1 | 1 | PASS |
| Clock name | sys_clk_pin | sys_clk_pin | PASS |
| Clock period | 10.000 ns | 10.000 ns | PASS |
| Rising edge | 0 ns | 0.000 ns | PASS |
| Falling edge | 5 ns | 5.000 ns | PASS |
| Total design clocks | 1 | 1 | PASS |
| CONFIG_VOLTAGE | 3.3 | 3.3 | PASS |
| CFGBVS | VCCO | VCCO | PASS |
| Verification errors | 0 expected | 0 | PASS |

---

## 10. What this measurement proves

This measurement proves that Vivado successfully applied the approved XDC to the actual loaded design:

```text
top-level ports resolve correctly
PACKAGE_PIN assignments match
IOSTANDARD assignments match
all selected package pins are unique
the intended 100 MHz clock object exists
the intended 10 ns period is recognized
the intended {0 5} waveform is recognized
configuration properties are applied
```

This moves the module status from:

```text
XDC source verified
```

to:

```text
XDC tool-verified
```

---

## 11. What this measurement does not prove

The script itself explicitly states:

```text
This is not synthesis-resource, routed-timing, or hardware sign-off.
```

Therefore this result does not yet prove:

```text
BRAM count
DSP count
LUT count
FF count
CARRY4 count
final IOB/BUFG utilization report
WNS
TNS
WHS
THS
critical path
bitstream generation
physical Basys-3 LED operation
physical Basys-3 pushbutton operation
```

Those remain later Phase-8 physical-validation tasks.

---

## 12. Step-8 conclusion

**BASYS3 XDC VIVADO MEASUREMENT: PASSED**

Measured evidence:

```text
59 checks
0 errors
12/12 ports resolved
12 unique package pins
12/12 LVCMOS33
1 primary clock
10.000 ns period
0/5 ns waveform
CONFIG_VOLTAGE = 3.3
CFGBVS = VCCO
```

The next workflow step is:

```text
Step 9 — update docs/analysis/basys3_xdc.md
          with measured-versus-predicted results
```
