# Basys 3 XDC — Knowledge Test Result

**Role:** Knowledge Tester  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 11 — `/test basys3_xdc`  
**Status:** PASSED

## Result

The learner answered all 18 knowledge-check items correctly.

### Confirmed understanding

```text
12 constrained board signals
clk_100mhz -> W5 / LVCMOS33
btn_start -> btnC / U18
btn_reset -> btnD / U17
100 MHz -> 10 ns
waveform {0 5} -> 50% duty cycle
led_result[0..7] -> LED0..LED7
led_done -> LED8
0x22 -> LED1 + LED5
no set_input_delay for asynchronous human buttons
no set_output_delay for human-visible LEDs
59 checks / 0 errors -> XDC verification scope only
10 ns clock constraint != timing closure
BRAM/resources -> synthesis utilization
WNS/TNS/WHS/THS -> post-implementation timing
source-verified != tool-verified
CONFIG_VOLTAGE / CFGBVS understood
unique package pins required
negative WNS -> timing failure, not XDC declaration failure
RAMB18/RAMB36 utilization proves BRAM mapping
remaining Phase-8 physical-validation flow understood
```

## Score

```text
18 / 18
```

## Module workflow status

```text
Step 1  /teach basys3_xdc       COMPLETE
Step 2  /design basys3_xdc      COMPLETE
Step 3  /analyze basys3_xdc     COMPLETE
Step 4  understanding gate      COMPLETE
Step 5  XDC generation          COMPLETE
Step 6  /verify basys3_xdc      COMPLETE
Step 7  verification artifact   COMPLETE
Step 8  Vivado measurement      COMPLETE
Step 9  measured analysis       COMPLETE
Step 10 /review basys3_xdc      COMPLETE
Step 11 /test basys3_xdc        COMPLETE
```

## Final module result

**BASYS3 XDC MODULE WORKFLOW: COMPLETE**

This does not complete overall Phase 8.

Remaining Phase-8 physical validation still includes:

```text
final top-level synthesis utilization
BRAM/DSP/LUT/FF/CARRY4/IOB/BUFG measurement
implementation/place-and-route
post-route STA
critical-path inspection
bitstream generation
Basys-3 programming
physical start/reset/result/done validation
optional power analysis
```
