# Basys 3 XDC Generation — Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 5 — XDC generation understanding checkpoint  
**Status:** PASSED — Step 6 `/verify basys3_xdc` is unlocked.

## Assessment

### Clock mapping and timing requirement
**PASSED.**

The learner correctly explained that the generated XDC establishes:

```text
clk_100mhz -> W5
IOSTANDARD -> LVCMOS33
period      -> 10 ns
waveform    -> {0 5}
```

and correctly distinguished the timing requirement from actual timing closure.

### Start/reset button mapping
**PASSED.**

The learner correctly explained:

```text
btn_start -> U18
btn_reset -> U17
```

and correctly stated that the XDC only establishes physical/electrical connectivity. Synchronization, debounce, and event generation remain RTL responsibilities.

### Result LED mapping
**PASSED.**

The learner correctly explained the direct physical mapping from `led_result[7:0]` to board LEDs 0 through 7 and correctly derived that:

```text
0x22 = 0010_0010
```

corresponds to LED5 and LED1 being asserted.

### Done LED mapping
**PASSED.**

The learner correctly separated:

```text
core_done
-> done_latched
-> led_done
-> physical LED8 / V13
```

and correctly identified that the XDC only establishes the final physical connection.

### Evidence boundary
**PASSED.**

The learner correctly distinguished:

```text
XDC
-> pin / IOSTANDARD / clock requirement

Synthesis
-> LUT / FF / BRAM / DSP / I/O mapping

Implementation / STA
-> WNS / TNS / WHS / THS and physical timing closure

Hardware bring-up
-> real button and LED behavior
```

They also correctly stated that XDC correctness does not itself prove:
- convolution result correctness,
- BRAM inference,
- resource counts,
- timing closure,
- physical button behavior,
- physical LED illumination.

## Gate result

**BASYS3 XDC GENERATION UNDERSTANDING GATE: PASSED**

The module may now proceed to:

```text
Step 6 — /verify basys3_xdc
```
