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


---

## Project completion status update — 2026-11-18

**Project lifecycle status: COMPLETED (owner-confirmed).** The project owner confirms all phases are complete, the bitstream was programmed onto the physical Basys 3 FPGA, and expected output was observed. This supersedes earlier active-phase, pending, and pre-board-test status wording; the original learning content and historical checkpoints remain preserved.

**Evidence boundary:** the owner supplied a Basys 3 board photograph in the project conversation. It documents the physical setup and illuminated indicators but does not independently establish exact latency, power, resource counts, or post-route timing. The historical docs/analysis/basys3_top_level.md report records WNS = -3.453 ns at the 100 MHz constraint; no newer timing report was supplied. Do not reinterpret the historical STA result as a pass without updated Vivado evidence.

The documented fixed demonstration vector produces accumulator 45 and requantized INT8 output 34 (0x22); LED1 and LED5 are the result bits and LED8 is the latched completion indicator. The owner reports that the expected board output was observed.
