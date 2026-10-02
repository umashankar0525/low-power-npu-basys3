# Basys 3 Hardware Validation

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_hardware_validation`  
**Workflow stage:** Step 1 — teaching

## Purpose

Hardware validation checks the real board after simulation, synthesis, implementation, STA, and bitstream generation.

The evidence chain is:

```text
RTL reasoning
-> XSim
-> synthesis
-> place and route
-> STA
-> bitstream
-> physical board validation
```

XSim proves cycle-level behavior. STA proves placed-and-routed timing. Board validation proves that the programmed FPGA, clock, buttons, reset path, LEDs, and pin constraints work together physically.

## Board interface

```text
clk_100mhz
btn_start
btn_reset
led_result[7:0]
led_done
```

The board uses the 100 MHz onboard clock.

The start and reset buttons are synchronized and debounced before they reach the accelerator logic.

## Expected arithmetic result

Input activations:

```text
1,2,3,4,5,6,7,8,9
```

Weights:

```text
all 1
```

Accumulation:

```text
1+2+3+4+5+6+7+8+9 = 45
```

Requantization:

```text
45 x 3 = 135
rounding bias = 2
135 + 2 = 137
137 >> 2 = 34
```

Therefore:

```text
decimal = 34
hex     = 0x22
binary  = 0010_0010
```

Expected result LEDs:

```text
LED1 = ON
LED5 = ON
all other result LEDs = OFF
```

and after completion:

```text
LED8 / led_done = ON
```

## Why led_done stays on

The raw internal completion pulse is only one clock wide:

```text
10 ns at 100 MHz
```

A human cannot see that pulse.

The top level therefore latches completion. After a successful transaction:

```text
led_done = 1
```

and it remains asserted until reset.

## Button debounce

Real pushbuttons are asynchronous and mechanically noisy.

The design uses synchronization plus debounce.

Hardware debounce setting:

```text
1,000,000 cycles
```

At 100 MHz:

```text
Tclk = 1 / 100,000,000
     = 10 ns
```

Therefore:

```text
1,000,000 x 10 ns
= 10,000,000 ns
= 10 ms
```

So start/reset must remain stable for about 10 ms before being accepted.

The accelerator itself takes only 90 ns, so once a valid start is accepted, the result appears effectively instantaneous to a person.

## Reset behavior

Expected board-visible state after a valid reset:

```text
led_result = 0x00
led_done   = 0
```

Reset should also clear internal pipeline and accumulator state.

A very short reset tap may be rejected by the debounce logic. For testing, hold reset clearly long enough to exceed the debounce interval.

## Initial physical test sequence

Use this board-level sequence:

```text
1. Program the FPGA with the latest Stage-2 bitstream.
2. Apply reset and hold it long enough to debounce.
3. Release reset.
4. Confirm led_result = 0x00 and led_done = 0.
5. Press start and hold it long enough to debounce.
6. Release start.
7. Confirm led_result = 0x22.
8. Confirm led_done = 1.
9. Wait and confirm both remain persistent.
10. Apply reset again.
11. Confirm led_result returns to 0x00 and led_done returns to 0.
```

## What this hardware test proves

A successful board test provides evidence that:

```text
the FPGA was configured correctly
the physical clock operates
button input conditioning works
reset reaches the architecture
the start transaction reaches the accelerator
the board-visible result path works
the done latch works
the XDC pin mapping is consistent with the hardware
```

## What it does not prove

A human LED test cannot directly measure:

```text
90 ns latency
internal product-pipeline timing
internal partial-sum timing
exact routed path delays
```

Those are already covered by XSim and STA.

## Assumption

The programmed bitstream must correspond to the latest Stage-2 RTL and the verified `basys3_top_level.xdc`.

If an older bitstream is programmed, board observations are not valid evidence for the current design.

## Initial hardware-validation PASS criteria

```text
After reset:
result = 0x00
done   = 0

After start:
result = 0x22
done   = 1

Persistence:
result remains 0x22
done remains 1

After reset again:
result = 0x00
done   = 0
```

## Understanding gate

Explain in your own words:

1. Why hardware validation is still needed after XSim and STA pass.
2. Which result LEDs should be ON for 0x22.
3. Why led_done must be latched.
4. Derive the 10 ms debounce interval.
5. What the board should show after reset.
6. What the board should show after start.
7. Why LEDs cannot prove the exact 90 ns latency.
8. What observations define an initial hardware PASS.
