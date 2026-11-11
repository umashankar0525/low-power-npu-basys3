# Basys 3 Hardware Validation — Design Procedure

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_hardware_validation`  
**Workflow stage:** Step 2 — /design basys3_hardware_validation  
**Status:** DESIGN COMPLETE — Step 3 prediction required before physical test execution.

---

## 1. Objective

Define a repeatable board-level validation procedure for the generated Stage-2 bitstream.

The hardware test must verify:

```text
FPGA configuration
clock operation
reset behavior
start-button behavior
debounce behavior
result LED mapping
done-latch behavior
result persistence
repeatability
```

The test must not rely on internal signals that are invisible on the board.

---

## 2. Assumptions

1. The bitstream was generated from the latest Stage-2 RTL.
2. `basys3_top_level` is the implementation top.
3. The verified `basys3_top_level.xdc` is active.
4. Target FPGA is XC7A35T-1CPG236C.
5. Board clock is 100 MHz.
6. Hardware debounce threshold is 1,000,000 cycles.
7. Expected convolution sum is 45.
8. Expected requantized result is 34 / 0x22.
9. `led_done` is latched until reset.
10. Board-level validation does not directly measure the 90 ns internal latency.

---

## 3. Expected board outputs

After valid reset:

```text
led_result[7:0] = 0000_0000
led_done        = 0
```

After valid start and completion:

```text
led_result[7:0] = 0010_0010
led_done        = 1
```

Therefore:

```text
LED1 = ON
LED5 = ON
LED8 = ON
```

All other result LEDs must be OFF.

---

## 4. Board programming procedure

Use Vivado Hardware Manager:

```text
Open Hardware Manager
-> Open Target
-> Auto Connect
-> select xc7a35t device
-> Program Device
-> choose the latest basys3_top_level.bit
-> Program
```

Do not modify RTL or XDC between the timing-closed implementation and board test.

---

## 5. Known-good startup procedure

Immediately after programming:

```text
1. Do not evaluate result LEDs yet.
2. Press and hold reset clearly longer than 10 ms.
3. Release reset.
4. Wait briefly for the debounced release to propagate.
5. Observe LEDs.
```

Required state:

```text
LED0..LED7 = OFF
LED8       = OFF
```

This establishes a known architectural starting state.

---

## 6. Primary start test

From the reset-cleared state:

```text
1. Press btn_start.
2. Hold it clearly longer than 10 ms.
3. Release btn_start.
4. Wait briefly.
5. Observe result and done LEDs.
```

Expected:

```text
LED1 = ON
LED5 = ON
LED8 = ON
```

Expected OFF:

```text
LED0
LED2
LED3
LED4
LED6
LED7
```

This corresponds to:

```text
0x22 = 0010_0010
```

---

## 7. Persistence test

After successful completion:

```text
wait several seconds
```

Expected:

```text
LED1 remains ON
LED5 remains ON
LED8 remains ON
```

No LED should flicker or return to zero without reset.

This confirms:

```text
result register persistence
done_latched persistence
```

---

## 8. Reset-after-completion test

With:

```text
LED1 = ON
LED5 = ON
LED8 = ON
```

apply reset again:

```text
press reset
hold > 10 ms
release
wait briefly
```

Expected:

```text
LED0..LED7 = OFF
LED8 = OFF
```

This confirms the physical reset path clears board-visible architectural state.

---

## 9. Repeatability test

Run the complete sequence at least three times:

```text
reset
-> start
-> observe 0x22 + done
-> reset
```

Each trial must produce the same result.

Recommended evidence table:

| Trial | After reset | After start | Done latched | Reset clears |
|---|---|---|---|---|
| 1 | 0x00 | 0x22 | yes | yes |
| 2 | 0x00 | 0x22 | yes | yes |
| 3 | 0x00 | 0x22 | yes | yes |

---

## 10. Held-start test

Press and continue holding start after the transaction completes.

Expected:

```text
one visible result only
done remains latched
no repeated visible reset/restart behavior
```

Because the design generates a rising-edge event from the debounced button level, a continuously held button must not create repeated starts.

This validates the physical interpretation of the one-shot start conditioner.

---

## 11. Short-press observation

A deliberately very brief start tap may be rejected by the debounce logic.

This is acceptable.

The test should not classify a sub-10-ms press as a functional failure.

The meaningful validation is:

```text
stable press > debounce interval
-> exactly one accepted transaction
```

---

## 12. What to record

For each test, record:

```text
test name
button action
observed LED0..LED8 pattern
expected pattern
PASS / FAIL
notes
```

A photograph is useful but not mandatory.

The most important evidence is the exact observed LED pattern.

---

## 13. Failure classification

If the expected result does not appear, classify before changing RTL.

### Category A — configuration

Examples:

```text
FPGA not programmed
wrong bitstream
device not connected
programming failed
```

### Category B — constraints / pin mapping

Examples:

```text
wrong LED lights
wrong button triggers
clock not mapped correctly
```

### Category C — debounce / button interaction

Examples:

```text
press too short
reset too short
button held/released incorrectly
```

### Category D — architectural behavior

Examples:

```text
correct button accepted
but result != 0x22
done not latched
reset does not clear
```

Only Category D would justify investigating the RTL after the board/programming/XDC path is ruled out.

---

## 14. Why the board test is deterministic

The operand memories are initialized with fixed values.

The accelerator performs no external data loading during this test.

Therefore every valid transaction should produce exactly:

```text
45
-> requantized 34
-> 0x22
```

Any other stable result is evidence of an integration problem.

---

## 15. Expected human-perceived timing

Button qualification:

```text
approximately 10 ms
```

Accelerator transaction:

```text
90 ns
```

Since:

```text
10 ms >> 90 ns
```

the visible output should appear essentially immediately after the button becomes valid.

No attempt should be made to judge 90 ns latency by eye.

---

## 16. Hardware-validation pass criteria

The initial hardware validation passes only if all of the following are observed:

```text
programming succeeds

reset:
0x00
done OFF

start:
0x22
done ON

persistence:
0x22 remains
done remains ON

second reset:
0x00
done OFF

repeatability:
same result across repeated trials
```

---

## 17. Evidence hierarchy

Board LEDs prove board-visible end-to-end integration.

They do not replace:

```text
XSim
post-route STA
```

Instead the combined evidence is:

```text
XSim:
internal sequencing correct

STA:
physical timing correct

Board:
physical end-to-end integration correct
```

All three are required for strong signoff.

---

## 18. No RTL modification in this step

No RTL modification is required for the initial board validation procedure.

No XDC modification is required.

No new clock or debug core is required.

The existing timing-closed bitstream is the artifact under test.

---

## 19. Step-3 prediction targets

Before board execution, the next analysis step should predict:

```text
expected LED state after reset
expected LED state after start
expected persistence
expected held-button behavior
expected reset-after-completion behavior
expected repeatability
expected debounce-scale human response
```

These predictions will then be compared against the real board observations.

---

## 20. Understanding gate

Before Step 3, explain in your own words:

1. Why must reset be applied before the first observation?
2. What exact LED pattern should appear after start?
3. Why should the result remain persistent?
4. Why should a held start button not repeatedly retrigger?
5. Why is a very short start press not a meaningful failure?
6. Why should the same result appear on every trial?
7. What failure categories should be ruled out before changing RTL?
8. Why is no RTL/XDC modification needed before this first board test?


---

## 21. Vivado operator walkthrough

### A. Connect to the board

1. Connect the Basys 3 USB cable to the board's **PROG USB** connector.
2. Power the board on. Confirm the board power LED is lit.
3. Open the existing Vivado NPU project.
4. Open **Hardware Manager**.
5. Select **Open Target → Auto Connect**.

Expected target: the Basys 3 Artix-7 device, typically displayed as `xc7a35t_0`.

If no target appears, stop here. Check board power, USB cable/connector, and Vivado cable-driver detection before proceeding.

### B. Program the already-generated bitstream

1. In Hardware Manager, select the detected FPGA.
2. Choose **Program Device**.
3. Browse to the latest Stage-2 bitstream generated by the current implementation run. In a standard Vivado project named `npu`, this is commonly under:

   ```text
   npu.runs/impl_1/basys3_top_level.bit
   ```

4. Confirm the selected file is `basys3_top_level.bit` from the latest successful Stage-2 implementation.
5. Leave the debug probes file blank if no ILA/debug core was added.
6. Click **Program** and wait for Vivado to report successful programming.

Do not regenerate the bitstream or change RTL/XDC during this first test.

### C. Use the physical buttons

The verified XDC maps:

```text
btn_start = Basys 3 center button (btnC, U18)
btn_reset = Basys 3 down button   (btnD, U17)
```

Hold each button for about 0.5 seconds to comfortably exceed the 10 ms debounce threshold.

### D. First board test

1. Press and hold **btnD** for about 0.5 seconds, then release.
2. Confirm LED0..LED7 and LED8 are OFF.
3. Press and hold **btnC** for about 0.5 seconds, then release.
4. Wait briefly.
5. Confirm LED1, LED5, and LED8 are ON. Other result LEDs should be OFF.
6. Wait several seconds and confirm the same pattern remains.
7. Press and hold **btnD** again for about 0.5 seconds, then release.
8. Confirm all result LEDs and LED8 turn OFF.

The expected result is fixed in this current bitstream: `0x22`. No slide switch selects a second input set in the current top-level interface.

### E. Stop conditions

If Auto Connect does not show the FPGA, do not attempt to program a device that is not detected.

If programming fails, preserve the Vivado error text and stop.

If programming succeeds but the LED pattern differs, record the exact LEDs that are ON/OFF before changing anything. Do not edit RTL or XDC until the observed failure is classified.
