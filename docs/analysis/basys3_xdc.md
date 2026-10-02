# Basys 3 XDC Constraints — Prediction Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 3 — `/analyze basys3_xdc`  
**Status:** PREDICTION ONLY — XDC not yet generated/applied.

---

## 1. Purpose

This document predicts the measurable Vivado outcomes that should result once the dedicated Basys-3 XDC is generated and applied to `basys3_top_level`.

The analysis focuses on quantities that the XDC can directly influence or make measurable:

```text
constrained-port coverage
package-pin mapping
I/O standard application
clock recognition
10 ns timing requirement
expected bonded I/O count
expected unconstrained-port warnings
expected clock-resource interpretation
expected board-visible LED mapping
```

Resource mapping, routed timing closure, and physical board behavior are downstream measurements and remain separate from this XDC-only prediction step.

---

## 2. Explicit assumptions

1. Target board is Basys 3.
2. Target FPGA is `XC7A35T-1CPG236C`.
3. The current top-level interface remains:

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

4. The selected physical mapping remains the approved Step-2 design.
5. All selected I/O use `LVCMOS33`.
6. The input clock frequency is 100 MHz.
7. No generated clock is introduced.
8. Pushbuttons remain asynchronous human inputs.
9. LEDs remain human-visible outputs.
10. The XDC itself does not alter RTL functionality.

---

## 3. Predicted constrained-port count

The top-level board ports are:

```text
1 clock
+ 2 pushbuttons
+ 8 result LEDs
+ 1 done LED
= 12 ports
```

Therefore the XDC should constrain exactly:

```text
12 top-level ports
```

Expected coverage:

```text
12 constrained
0 intentionally unconstrained
```

This prediction is important because a missing single LED or button line would create a physical mapping gap even if the rest of the file were correct.

---

## 4. Predicted package-pin mapping

Expected mapping:

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

Prediction:

```text
all 12 logical ports should resolve to unique package pins
no duplicate PACKAGE_PIN assignments
no selected package pin should remain unassigned
```

A duplicate or missing package assignment would invalidate board readiness.

---

## 5. Predicted I/O standard result

All selected pins use:

```text
LVCMOS33
```

Therefore the physical-I/O report should show:

```text
12 selected ports
-> IOSTANDARD LVCMOS33
```

No selected port should retain an unspecified/default I/O standard.

If Vivado reports an unconstrained or unspecified I/O standard for any of these ports, the XDC application is incomplete.

---

## 6. Clock-period derivation

The board oscillator is:

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

Predicted clock object:

```text
period = 10.000 ns
```

Waveform:

```text
{0 5}
```

which means:

```text
rising edge  = 0 ns
falling edge = 5 ns
next rising  = 10 ns
```

Duty cycle:

```text
high time = 5 ns
low time  = 5 ns
duty      = 5/10 = 50%
```

---

## 7. Predicted Vivado clock recognition

Once the XDC is applied correctly, Vivado should recognize one primary input clock on:

```text
clk_100mhz
```

Expected clock characteristics:

```text
clock count       = 1 primary design clock
period            = 10.000 ns
frequency         = 100 MHz
waveform          = 0 ns / 5 ns
generated clocks  = 0
```

This clock should drive the timing analysis of the synchronous NPU and wrapper logic.

The exact clock-resource primitive usage, such as BUFG count, is a synthesis/implementation result rather than an XDC result, although the design still predicts one global clock buffer.

---

## 8. Predicted I/O utilization count

The top level physically exposes:

```text
3 inputs
9 outputs
= 12 package I/O signals
```

Therefore the predicted final bonded I/O count is:

```text
12 IOB / package I/O
```

This is consistent with the earlier Phase-8 top-level prediction.

The exact utilization report wording may differ between Vivado reports, but the physically exposed signal count should remain 12 unless tool optimization or top-level mismatch indicates a problem.

---

## 9. Expected constraint warnings

If the XDC is generated exactly according to the design, the expected board-critical constraint state is:

```text
no missing PACKAGE_PIN assignments for used top-level ports
no missing IOSTANDARD assignments for used top-level ports
no duplicate package pin assignments
no invalid get_ports references
clock object successfully created on clk_100mhz
```

Therefore the prediction is:

```text
board-critical unconstrained-I/O warnings = 0
clock-missing warnings                    = 0
invalid-port-name constraint errors       = 0
```

This does **not** mean Vivado will produce literally zero messages overall; informational or unrelated warnings may still appear.

The important prediction is that there should be no warning indicating that one of the 12 intended board ports lacks a location or I/O standard, and no error showing that the 100 MHz clock constraint failed to bind.

---

## 10. Why exact zero-warning prediction is not made

Vivado can emit warnings that are unrelated to the correctness of this XDC, for example:

```text
optimization notices
unused internal nets
inference messages
implementation heuristics
version-specific advisory messages
```

Therefore the acceptance prediction is not:

```text
Vivado warning count = exactly 0
```

Instead, it is:

```text
XDC-related critical warnings = 0
```

where the critical set is specifically:

```text
unconstrained required I/O
missing IOSTANDARD
duplicate pin placement
invalid port selection
missing primary clock
```

---

## 11. Predicted result-to-LED mapping

The nominal arithmetic result remains:

```text
34 decimal
= 0x22
= 0010_0010
```

Direct bit mapping gives:

```text
led_result[5] = 1 -> LED5 / U15
led_result[1] = 1 -> LED1 / E19
```

and:

```text
LED0,2,3,4,6,7 = 0
```

After completion:

```text
led_done = 1 -> LED8 / V13
```

Therefore the predicted final physical pattern is:

```text
LED1 ON
LED5 ON
LED8 ON
```

This is not yet measured physical behavior. It is the expected board manifestation if the XDC and bitstream are correct and the already-verified RTL behaves the same in hardware.

---

## 12. Predicted timing-analysis requirement

With a 10 ns primary clock, timing analysis should evaluate synchronous register-to-register paths against a 10 ns setup-cycle requirement.

For a generic path with:

```text
arrival = 8.8 ns
required = 10.0 ns
```

slack is:

```text
10.0 - 8.8
= +1.2 ns
```

For a path with:

```text
arrival = 10.4 ns
```

slack is:

```text
10.0 - 10.4
= -0.4 ns
```

Therefore the XDC defines the requirement against which post-route WNS/TNS are later measured.

The XDC does not itself prove that those slacks are positive.

---

## 13. Predicted relationship to the 70 ns core latency

The architectural transaction remains:

```text
7 cycles
```

With the XDC clock period:

```text
7 x 10 ns
= 70 ns
```

Therefore:

```text
predicted architectural transaction latency remains 70 ns
```

The XDC does not add cycles.

It only ensures that physical timing analysis judges each synchronous cycle against the required 10 ns period.

---

## 14. Predicted input/output-delay treatment

For the two human buttons:

```text
set_input_delay = not expected
```

because they are asynchronous human inputs and are deliberately synchronized internally.

For the LED outputs:

```text
set_output_delay = not expected
```

because there is no external synchronous receiver sampling them against a specified clock.

Therefore the predicted minimum board XDC includes:

```text
PACKAGE_PIN
IOSTANDARD
create_clock
configuration-voltage properties
```

but no external synchronous interface delay constraints.

---

## 15. Predicted configuration properties

The authoritative Digilent master XDC provides:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

If preserved in the dedicated board XDC, Vivado should accept these as board/device configuration properties.

They should not change accelerator functionality or cycle timing.

Their role is board-configuration correctness rather than datapath behavior.

---

## 16. What reports should prove the XDC was applied

After XDC generation, the following Vivado evidence should be collected.

### 16.1 I/O / package-pin evidence

Must confirm:

```text
12 expected ports
correct package pins
LVCMOS33 on each selected port
```

### 16.2 Clock evidence

Must confirm:

```text
clk_100mhz recognized
period = 10.000 ns
waveform = {0 5}
```

### 16.3 Constraint/message evidence

Must show no board-critical issues such as:

```text
unconstrained required I/O
missing IOSTANDARD
invalid get_ports target
duplicate package-pin assignment
missing clock constraint
```

### 16.4 Later synthesis evidence

Must separately confirm:

```text
IOB count
BRAM mapping
DSP mapping
LUT/FF/CARRY utilization
```

### 16.5 Later implementation evidence

Must separately confirm:

```text
WNS/TNS
WHS/THS
critical path
100 MHz physical closure
```

---

## 17. Prediction summary

```text
Required top-level constrained ports     = 12
Predicted unconstrained required ports   = 0
Selected I/O standard                    = LVCMOS33
Primary design clock count               = 1
Primary clock period                     = 10.000 ns
Primary clock frequency                  = 100 MHz
Clock waveform                           = {0 5}
Generated clocks                         = 0
Predicted bonded I/O count               = 12
Expected XDC-critical warnings           = 0
Expected invalid get_ports references    = 0
Expected duplicate pin assignments       = 0
Expected input-delay constraints         = 0
Expected output-delay constraints        = 0
Expected result LEDs                     = LED1 + LED5
Expected done LED                        = LED8
```

These are predictions to be checked after the actual XDC is generated and used by Vivado.

---

## 18. What remains outside the prediction

This analysis does not claim actual measured values for:

```text
LUT count
FF count
CARRY4 count
DSP count
BRAM count
WNS
TNS
WHS
THS
critical path
power
hardware LED operation
hardware pushbutton operation
```

Those must come from the later physical flow.

---

## 19. Acceptance criteria after XDC generation

The generated constraint file will be considered consistent with the Step-3 prediction if:

```text
1. all 12 top-level ports are constrained
2. all mappings match the approved design table
3. all selected ports use LVCMOS33
4. one 10 ns primary clock exists on clk_100mhz
5. no required port remains unconstrained
6. no selected port uses a duplicate package pin
7. no get_ports name fails to match the current top-level RTL
8. no set_input_delay is present for btn_start / btn_reset
9. no set_output_delay is present for LED outputs
10. expected physical result mapping remains LED1 + LED5, with LED8 as done
```

---

## 20. Understanding gate

Before Step 4 and XDC generation, explain in your own words:

1. Why do we predict exactly 12 constrained ports and 0 required unconstrained ports?
2. Why should Vivado recognize exactly one 100 MHz primary clock with a 10 ns period?
3. Why is `12 bonded I/O` a reasonable prediction, but still something to confirm in utilization?
4. Why do we predict zero **XDC-critical** warnings rather than zero total Vivado warnings?
5. What specific evidence would prove that package pins and LVCMOS33 were applied correctly?
6. What specific evidence would prove the 10 ns clock constraint was actually recognized?
7. Why does this XDC still not prove positive WNS/TNS or BRAM inference?
8. Why are `set_input_delay` and `set_output_delay` still intentionally absent?

---

## Step 9 Update — Measured vs Predicted

**Status:** MEASURED XDC RESULTS ADDED — Vivado constraint application matches the Step-3 predictions. Resource mapping, routed timing, and hardware behavior remain outside this XDC-only measurement.

### 1. Measurement source

The Step-7 Vivado/Tcl verification artifact was executed against the loaded design:

```text
tb/scripts/verify_basys3_xdc.tcl
```

Vivado reported:

```text
Checks executed: 59
Errors found:    0

PASS: basys3_xdc constraint database matches the approved design.
```

This is direct tool-applied evidence, not source inspection alone.

---

### 2. Predicted versus measured table

| Quantity | Step-3 prediction | Vivado measurement | Comparison |
|---|---:|---:|---|
| Required constrained ports | 12 | 12 resolved | MATCH |
| Required unconstrained ports | 0 | 0 observed in checked set | MATCH |
| Unique package pins | 12 | 12 | MATCH |
| I/O standard | LVCMOS33 | LVCMOS33 on all 12 | MATCH |
| Primary clock count | 1 | 1 | MATCH |
| Clock name | `sys_clk_pin` | `sys_clk_pin` | MATCH |
| Clock period | 10.000 ns | 10.000 ns | MATCH |
| Clock rising edge | 0 ns | 0.000 ns | MATCH |
| Clock falling edge | 5 ns | 5.000 ns | MATCH |
| Total design clocks | 1 | 1 | MATCH |
| Expected XDC verification errors | 0 | 0 | MATCH |
| CONFIG_VOLTAGE | 3.3 | 3.3 | MATCH |
| CFGBVS | VCCO | VCCO | MATCH |

Every quantity directly exercised by the verification script matched its prediction.

---

### 3. Port-resolution result

The prediction was:

```text
12 required top-level port bits
-> all must resolve exactly once
```

Measured result:

```text
clk_100mhz      object count = 1
btn_start       object count = 1
btn_reset       object count = 1
led_result[0]   object count = 1
...
led_result[7]   object count = 1
led_done        object count = 1
```

Therefore:

```text
12 / 12 expected port objects resolved
```

This closes the gap between XDC text intent and actual Vivado object binding.

---

### 4. PACKAGE_PIN result

Predicted physical mapping:

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

Vivado measured exactly the same mapping.

Therefore:

```text
PACKAGE_PIN prediction accuracy = 12 / 12
```

---

### 5. IOSTANDARD result

Prediction:

```text
all selected board ports -> LVCMOS33
```

Measurement:

```text
12 / 12 selected ports -> LVCMOS33
```

Therefore:

```text
IOSTANDARD prediction accuracy = 12 / 12
```

No selected board port failed the intended electrical-standard check.

---

### 6. Unique-pin result

Prediction:

```text
duplicate PACKAGE_PIN assignments = 0
```

Measurement:

```text
unique PACKAGE_PIN count = 12
```

with 12 expected mapped ports.

Therefore:

```text
duplicate selected pin assignments = 0
```

This matches the Step-3 expectation.

---

### 7. Clock-object result

Prediction:

```text
primary clock count = 1
clock name          = sys_clk_pin
period              = 10.000 ns
waveform            = {0 5}
generated clocks    = 0 expected
```

Measured:

```text
clock objects on clk_100mhz = 1
primary clock name          = sys_clk_pin
period                      = 10.000 ns
rising edge                 = 0.000 ns
falling edge                = 5.000 ns
total design clock count    = 1
```

The frequency implied by the measured period is:

```text
f = 1 / 10 ns
  = 100 MHz
```

Therefore the clock prediction is fully matched.

---

### 8. Configuration-property result

Prediction:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

Measured:

```text
CONFIG_VOLTAGE = 3.3
CFGBVS         = VCCO
```

Therefore both configuration-property predictions matched.

---

### 9. Error-count result

Prediction:

```text
XDC-critical verification errors = 0
```

Measured by the verification artifact:

```text
Checks executed = 59
Errors found    = 0
```

Therefore the tested XDC constraint properties all passed.

Important qualification:

```text
0 verification-script errors
!=
0 possible Vivado warnings of every kind
```

The measured result proves that the explicit properties queried by the script matched the approved design.

---

### 10. What Step 9 now establishes

The following are no longer merely predictions:

```text
12 expected ports resolve
12 approved package-pin mappings are applied
12 selected ports use LVCMOS33
12 package pins are unique
one primary clock exists
clock name = sys_clk_pin
clock period = 10.000 ns
clock waveform = 0 / 5 ns
CONFIG_VOLTAGE = 3.3
CFGBVS = VCCO
constraint verification script reports 0 errors
```

These are now measured Vivado-applied results.

---

### 11. What remains unmeasured in this analysis

The following Step-3/Phase-8 physical quantities remain outside the XDC measurement:

```text
final bonded-I/O utilization report value
BRAM count
DSP count
LUT count
FF count
CARRY4 count
BUFG count
WNS
TNS
WHS
THS
critical path
power
bitstream success
physical button operation
physical LED operation
```

These must be collected from synthesis, implementation, bitstream generation, and board testing.

---

### 12. Prediction accuracy conclusion

For every quantity directly checked by the Step-7 script:

```text
prediction -> measurement = MATCH
```

The measured evidence is:

```text
59 checks
0 errors
```

So the XDC prediction model was accurate for the tested constraint properties.

---

### 13. Step-9 status

**BASYS3 XDC MEASURED-VS-PREDICTED ANALYSIS: COMPLETE**

The module may proceed to:

```text
Step 10 — /review basys3_xdc
```

provided the learner can explain the distinction between:

```text
measured XDC application
vs
still-unmeasured synthesis/implementation/hardware evidence
```
