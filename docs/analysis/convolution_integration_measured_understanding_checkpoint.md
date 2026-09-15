# Phase 7 — Convolution Integration Measured-Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 9 — measured-vs-predicted analysis understanding gate

## Learner response

### 1. Directly measured

**Status: PASSED**

The learner correctly stated that directly measured quantities are values observed from the completed behavioral simulation evidence itself.

For this Phase-7 integration, examples include:

```text
accepted-start to done latency = 70 ns
accepted-start spacing in the directed restart test = 90 ns
memory request count = 3
address order = 0 -> 1 -> 2
directed output values observed without testbench errors
```

### 2. Derived from measured timing

**Status: PASSED**

The learner correctly stated that these values are calculated from quantities that were directly measured in simulation rather than directly read as standalone simulator outputs.

Examples are:

```text
transaction rate = 1 / 90 ns = 11.11 M transactions/s
useful MAC rate  = 9 x 11.11 M = 100 MMAC/s
physical memory traffic rate = 24 B / 90 ns = 266.67 MB/s
useful operand traffic rate   = 18 B / 90 ns = 200 MB/s
```

These are behaviorally grounded derived rates, not physical board-throughput measurements.

### 3. Still requiring synthesis / implementation evidence

**Status: PASSED**

The learner correctly distinguished results that behavioral XSim cannot establish.

Resource usage requires synthesis / technology mapping evidence, including:

```text
LUT count
Slice FF count
CARRY4 count
DSP48E1 count
DSP register mapping such as PREG
```

Timing closure requires implementation and static timing evidence, including:

```text
placement/routing delays
setup and hold checks
WNS
TNS
routed critical path
```

Behavioral simulation does not prove these physical FPGA properties.

## Gate result

**STEP-9 MEASURED-ANALYSIS UNDERSTANDING GATE: PASSED**

The learner correctly understands the distinction between directly measured behavioral quantities, rates derived from those measurements, and physical implementation quantities that still require synthesis and/or routed timing analysis.

The next mandatory workflow step is:

```text
Step 10: /review convolution_integration
```

The Design Reviewer role must be entered in a separate interaction/response; roles are not mixed within one response.
