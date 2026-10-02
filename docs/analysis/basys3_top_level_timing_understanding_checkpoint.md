# Basys 3 Top-Level Timing — Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Post-route timing-understanding gate  
**Status:** PASSED — timing-closure redesign work is unlocked.

## Assessment

The learner correctly explained the central timing distinction:

```text
XDC
-> defines the timing requirement

STA
-> measures whether the implemented architecture meets that requirement
```

The learner correctly identified the measured critical path as:

```text
BRAM output
-> combinational arithmetic
-> long CARRY4-heavy path
-> accumulator register
```

and correctly explained that the path is required to fit within:

```text
10.000 ns
```

but currently measures approximately:

```text
13.433 ns data-path delay
```

with Vivado reporting:

```text
WNS = -3.453 ns
```

The learner also correctly noted that the small difference between:

```text
13.433 ns - 10.000 ns = 3.433 ns
```

and the reported:

```text
3.453 ns setup violation
```

comes from timing-analysis effects such as clock skew, uncertainty, and endpoint setup requirements.

## Key conceptual conclusions

```text
correct 10 ns XDC
!=
10 ns physical datapath

recognized clock constraint
!=
timing closure

WNS < 0
-> setup timing failure

WHS > 0
-> hold timing passes
```

The learner also correctly explained that hold timing passing does not contradict setup timing failing because setup and hold test different timing requirements.

## Architectural interpretation

The learner correctly identified the current problem as too much work being performed between sequential boundaries:

```text
BRAM
-> deep combinational arithmetic
-> accumulator
```

and correctly identified pipelining / repartitioning the arithmetic across cycles as a legitimate architectural timing-closure direction.

No RTL modification is authorized yet. Any redesign must first follow the required concept, design, prediction, and understanding workflow.

## Gate result

**BASYS3 TOP-LEVEL POST-ROUTE TIMING UNDERSTANDING GATE: PASSED**

The next required project action is a dedicated timing-closure module/work item beginning with:

```text
/teach basys3_timing_closure
```

before any RTL restructuring is attempted.
