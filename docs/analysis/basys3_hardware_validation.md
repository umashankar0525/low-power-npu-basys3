# Basys 3 Hardware Validation — Prediction Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_hardware_validation`  
**Workflow stage:** Step 3 — /analyze basys3_hardware_validation  
**Status:** PREDICTION ONLY — board measurements not yet collected.

---

## 1. Purpose

Predict the observable behavior of the timing-closed Stage-2 bitstream on the physical Basys 3 board.

The board test should compare measured observations against these predictions.

---

## 2. Assumptions

1. The programmed bitstream is the latest Stage-2 bitstream.
2. `basys3_top_level` is the implemented top.
3. The verified `basys3_top_level.xdc` is active.
4. The 100 MHz onboard oscillator is functioning.
5. The board has been programmed successfully.
6. The hardware debounce value is 1,000,000 cycles.
7. The Stage-2 RTL is the timing-closed version.
8. The operand memories contain the fixed initialized activation and weight values.
9. The physical board test observes only LEDs and buttons.
10. No ILA or oscilloscope measurement is used in the initial validation.

---

## 3. Reset-state prediction

After a valid debounced reset:

```text
led_result = 8'b0000_0000
led_done   = 1'b0
```

Therefore:

```text
LED0..LED8 = OFF
```

This is the expected known-good starting state.

---

## 4. Start-state prediction

After one valid start press:

```text
convolution result = 45
requantized result = 34
hex result         = 0x22
binary result      = 0010_0010
```

Therefore:

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

---

## 5. Persistence prediction

The result register retains:

```text
0x22
```

and the completion latch retains:

```text
done = 1
```

Therefore after several seconds:

```text
LED1 remains ON
LED5 remains ON
LED8 remains ON
```

No spontaneous return to zero is expected.

---

## 6. Reset-after-completion prediction

After completion, a valid reset should force:

```text
0x22 -> 0x00
done 1 -> 0
```

Therefore:

```text
LED1 OFF
LED5 OFF
LED8 OFF
```

with all result LEDs cleared.

---

## 7. Repeatability prediction

Because the test uses:

```text
fixed activations
fixed weights
fixed control sequence
deterministic synchronous RTL
```

every valid trial should produce:

```text
0x00 after reset
0x22 after start
done ON after completion
0x00 after reset again
```

Predicted repeated trial table:

| Trial | After reset | After start | Done | Reset clears |
|---|---|---|---|---|
| 1 | 0x00 | 0x22 | ON | yes |
| 2 | 0x00 | 0x22 | ON | yes |
| 3 | 0x00 | 0x22 | ON | yes |

---

## 8. Held-start prediction

The physical start path is:

```text
btn_start
-> synchronizer
-> debounce
-> rising-edge detector
-> busy mask
-> core_start
```

Once the debounced level rises, one rising-edge event is produced.

If the button remains held:

```text
debounced level stays high
no second rising edge occurs
```

Therefore the accelerator should not repeatedly retrigger from a continuously held start button.

Expected visible behavior:

```text
one result
one latched done indication
stable LEDs
```

---

## 9. Release-and-press-again prediction

After releasing start long enough for the debounced level to return low, a later second press can create a new rising edge.

Therefore a second valid press may launch another transaction.

Because the operands are unchanged, the visible result remains:

```text
0x22
```

The board may appear unchanged because the same value is written again.

This means the initial LED-only test cannot count repeated same-result transactions directly.

---

## 10. Debounce timing prediction

Clock period:

```text
Tclk = 10 ns
```

Debounce cycles:

```text
1,000,000
```

Therefore:

```text
1,000,000 x 10 ns
= 10 ms
```

Predicted physical behavior:

```text
press shorter than about 10 ms:
may be ignored

stable press longer than about 10 ms:
should be accepted
```

---

## 11. Human-perceived response prediction

Accelerator transaction:

```text
90 ns
```

Debounce:

```text
10 ms
```

Ratio:

```text
10 ms / 90 ns
≈ 111,111
```

Therefore from a human perspective:

```text
button qualification dominates visible response time
```

Once the button is accepted, the LED change should appear essentially immediate.

---

## 12. Physical latency limitation

The board LED test cannot distinguish:

```text
80 ns
90 ns
100 ns
```

Therefore the measured board test should not attempt to validate transaction latency numerically.

The 90 ns latency remains established by XSim.

---

## 13. Expected configuration behavior

If programming succeeds and the correct bitstream is loaded, the FPGA should remain configured while powered.

The board-level test should not require repeated programming between reset/start trials.

If the configuration is lost, that is a board/power/programming issue rather than accelerator logic behavior.

---

## 14. Expected failure signatures

### Wrong result LEDs but correct done LED

Possible causes:

```text
result-bit mapping issue
stale/wrong bitstream
unexpected memory initialization
RTL/output integration issue
```

### No done LED and no result

Possible causes:

```text
start not accepted
button press too short
wrong button pin
clock/configuration issue
wrong bitstream
```

### Reset does not clear LEDs

Possible causes:

```text
reset press too short
wrong reset pin
wrong bitstream
reset path integration issue
```

### Wrong physical LEDs illuminate

Possible causes:

```text
XDC mapping mismatch
LED bit interpretation error
stale constraints
```

---

## 15. Prediction-versus-measurement table to fill later

| Observation | Prediction | Measured | Result |
|---|---|---|---|
| After reset | 0x00, done OFF | pending | pending |
| After start | 0x22, done ON | pending | pending |
| LED1 | ON | pending | pending |
| LED5 | ON | pending | pending |
| LED8 | ON | pending | pending |
| Persistence | stable | pending | pending |
| Reset after completion | clears all | pending | pending |
| Held start | no visible repeated retrigger | pending | pending |
| Repeat trial 1 | 0x22 | pending | pending |
| Repeat trial 2 | 0x22 | pending | pending |
| Repeat trial 3 | 0x22 | pending | pending |

---

## 16. Initial hardware PASS criteria

The initial board validation passes when:

```text
programming succeeds

after reset:
0x00
done OFF

after valid start:
0x22
done ON

expected ON LEDs:
LED1
LED5
LED8

persistence:
stable

reset after completion:
clears result and done

repeatability:
same result across repeated valid trials
```

---

## 17. Prediction conclusion

The expected real-board behavior is deterministic:

```text
reset
-> 0x00 / done OFF

start
-> 0x22 / done ON

wait
-> unchanged

reset
-> 0x00 / done OFF
```

If the physical observations match, the initial board-level integration test passes.

If they do not match, debugging should first isolate programming, button/debounce, and pin-mapping causes before changing RTL.

---

## 18. Understanding gate

Before physical board execution, explain in your own words:

1. What exact LED state is predicted after reset?
2. What exact LED state is predicted after start?
3. Why should the result remain stable?
4. Why can a held start button create only one rising-edge event?
5. Why might a second valid press be invisible on the LEDs even if it launches correctly?
6. Why is the human-visible response dominated by debounce rather than the 90 ns accelerator latency?
7. What observations would suggest a pin/XDC issue rather than an arithmetic issue?
8. What exact observations define an initial hardware PASS?
