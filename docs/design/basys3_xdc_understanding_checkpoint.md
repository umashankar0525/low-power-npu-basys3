# Basys 3 XDC Constraints — Design Understanding Checkpoint

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 2 — `/design basys3_xdc` understanding gate  
**Status:** PASSED — Step 3 `/analyze basys3_xdc` is unlocked.

## Assessment

### 1. Start/reset button mapping
**PASSED.**

The learner correctly explained that:
- `btn_start` is mapped to Basys-3 `btnC` on package pin `U18`,
- `btn_reset` is mapped to Basys-3 `btnD` on package pin `U17`.

They correctly distinguished the board-level mapping decision from the asynchronous-input handling that remains in RTL.

### 2. 100 MHz / 10 ns clock and `{0 5}`
**PASSED.**

The learner correctly derived:

```text
T = 1/f
  = 1/(100 x 10^6)
  = 10 ns
```

and correctly interpreted:

```text
{0 5}
```

as a rising edge at 0 ns and falling edge at 5 ns, giving a 50% duty-cycle 100 MHz clock.

### 3. Direct LED mapping
**PASSED.**

The learner correctly explained why:

```text
led_result[n] -> LEDn
```

is useful for bring-up and debugging: the physical board pattern directly represents the binary result without a permutation or decoder layer.

### 4. Expected physical LED pattern
**PASSED.**

The learner correctly derived:

```text
0x22 = 0010_0010
```

therefore:

```text
LED5 = ON
LED1 = ON
LED0,2,3,4,6,7 = OFF
LED8 = done indicator
```

### 5. Why no `set_input_delay` for pushbuttons
**PASSED.**

The learner correctly explained that the pushbuttons are asynchronous human inputs, not synchronous external data referenced to a known source clock. Their metastability and bounce behavior is handled by the synchronizer/debounce RTL.

### 6. Why no `set_output_delay` for LEDs
**PASSED.**

The learner correctly explained that the LEDs are human-visible outputs, not data sampled by an external synchronous receiver with setup/hold requirements relative to a clock.

### 7. Why exactly 12 ports are constrained
**PASSED.**

The learner correctly derived:

```text
1 clock
+ 1 start button
+ 1 reset button
+ 8 result LEDs
+ 1 done LED
= 12 ports
```

### 8. What the XDC still does not prove
**PASSED.**

The learner correctly separated XDC intent from the evidence domains that remain:

```text
RTL behavior
-> simulation

resource mapping
-> synthesis

routed timing
-> implementation / STA

real board behavior
-> bitstream + hardware test
```

The learner also correctly stated that a correct XDC does not itself prove convolution correctness, BRAM inference, LUT/FF/DSP counts, timing closure, or physical button/LED operation.

## Gate result

**BASYS3 XDC DESIGN UNDERSTANDING GATE: PASSED**

The module may now proceed to:

```text
Step 3 — /analyze basys3_xdc
```

The next analysis must predict measurable XDC/physical-flow outcomes before generating the actual constraint file.
