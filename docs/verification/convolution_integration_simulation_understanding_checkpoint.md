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

**Status: PARTIAL**

The learner correctly stated that physical resource usage requires synthesis results. Behavioral XSim does not technology-map the RTL, so it cannot measure final LUT, Slice-FF, or DSP48E1 utilization.

One additional distinction is still required for timing closure: synthesis alone is not enough to prove final routed timing. Setup/hold closure, WNS/TNS, and routing-delay evidence require implementation (placement and routing) followed by static timing analysis for the integrated `convolution_integration` design.

Therefore the measurement boundaries are:

```text
Behavioral XSim
    -> functional correctness and cycle/timestamp measurements

Synthesis
    -> technology mapping and resource-utilization evidence

Implementation + static timing analysis
    -> routed setup/hold timing, WNS/TNS, and timing-closure evidence
```

## Gate result

**STEP-8 UNDERSTANDING GATE: NOT YET PASSED**

The latency-measurement concept is passed, and the learner understands that resource usage requires synthesis. The remaining point is to explicitly distinguish synthesis/resource measurement from implementation/static-timing evidence required to prove timing closure.
