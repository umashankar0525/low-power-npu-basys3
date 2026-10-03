# Basys 3 Hardware Validation — Prediction Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_hardware_validation`  
**Workflow stage:** Step 3 prediction understanding gate  
**Status:** PASSED — Step 4 confirmation is satisfied and physical board execution is unlocked.

## Assessment

The learner correctly identified the expected reset state:

```text
led_result = 0x00
led_done   = 0
```

The learner correctly identified the expected successful start state:

```text
0x22 = 0010_0010

LED1 = ON
LED5 = ON
LED8 = ON
```

The learner correctly explained persistence:

```text
registered result remains stored
done_latched remains asserted
```

The held-button behavior was correctly tied to debounced rising-edge detection:

```text
button already high
-> no second rising edge
-> no repeated start event
```

The learner correctly explained why a later second transaction may be visually invisible: the same fixed result and already-latched done state produce no visible LED change.

The response-time derivation was also correctly understood:

```text
debounce ≈ 10 ms
compute  = 90 ns
```

so human-visible behavior is dominated by debounce.

The learner correctly identified likely XDC/pin issues as cases where the logical computation is known-good but the wrong physical LEDs or buttons respond.

## Initial hardware PASS definition

```text
reset:
all result LEDs OFF
LED8 OFF

valid start:
LED1 ON
LED5 ON
LED8 ON

persistence:
stable after waiting

reset again:
all LEDs OFF

repeat trials:
same deterministic behavior
```

## Gate result

**BASYS3 HARDWARE VALIDATION STEP-3 UNDERSTANDING GATE: PASSED**

Step 4 user confirmation is satisfied.

The workflow may now proceed to physical board execution and measurement.
