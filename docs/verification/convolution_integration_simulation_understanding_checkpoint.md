# Phase 7 — Convolution Integration Simulation Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 8 — simulation/measurement understanding gate

## Learner response

### 1. Why the 70 ns latency can now be called measured

**Status: PASSED**

The learner correctly identified that the behavioral XSim run recorded the accepted-start and external-done timestamps and that the measured interval is:

```text
0x361 - 0x31B
= 865 ns - 795 ns
= 70 ns
```

Therefore the previously predicted 7-cycle start-to-done latency has now been directly observed in behavioral simulation for the exercised integration test.

### 2. Why LUT/FF/DSP usage and timing closure cannot yet be called measured

**Status: NOT YET PASSED**

Behavioral XSim verifies logical and cycle-level behavior, but it does not perform synthesis, technology mapping, placement, routing, or static timing analysis for the integrated `convolution_integration` design.

Therefore the following still require integrated synthesis/implementation reports:

```text
LUT usage
Slice FF usage
DSP48E1 usage/mapping
post-synthesis or post-route setup timing
hold timing
WNS/TNS
routing delay
power
```

The integration testbench passing does not establish those physical implementation quantities.

## Gate result

**STEP-8 UNDERSTANDING GATE: NOT YET PASSED**

The latency-measurement concept is passed. The learner must still restate why behavioral simulation cannot measure physical resource utilization or prove timing closure before the workflow proceeds to Step 9 measured-versus-predicted analysis.
