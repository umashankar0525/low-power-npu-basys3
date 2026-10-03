# Basys 3 Hardware Validation — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_hardware_validation`  
**Workflow stage:** Step 1 teaching understanding gate  
**Status:** PASSED — Step 2 design is unlocked.

## Assessment

The learner correctly explained why physical board validation remains necessary after XSim and static timing analysis.

The learner correctly identified:

```text
0x22 = 0010_0010
```

therefore:

```text
LED1 = ON
LED5 = ON
LED8 = ON after completion
```

The learner correctly explained that `led_done` must be latched because the raw completion pulse is too short for direct human observation.

The debounce interval was correctly derived:

```text
1,000,000 cycles x 10 ns/cycle
= 10,000,000 ns
= 10 ms
```

The learner correctly stated the expected board-visible reset condition:

```text
led_result = 0x00
led_done   = 0
```

and the expected post-start condition:

```text
led_result = 0x22
led_done   = 1
```

The learner also correctly explained that human-visible LEDs cannot directly verify the 90 ns internal transaction latency.

## Initial hardware PASS definition

The first board test passes when:

```text
reset -> result LEDs OFF, done OFF

start -> LED1 ON, LED5 ON, LED8 ON

result and done remain persistent

second reset -> result LEDs OFF, done OFF

repeat reset/start -> same deterministic result
```

## Gate result

**BASYS3 HARDWARE VALIDATION TEACHING GATE: PASSED**

Next workflow step:

```text
/design basys3_hardware_validation
```
