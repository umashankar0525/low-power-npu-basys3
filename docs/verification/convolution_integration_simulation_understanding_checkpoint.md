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

### 2. Why LUT/FF/DSP usage and timing closure require different physical evidence

**Status: PASSED**

The learner correctly distinguished the measurement stages:

```text
Behavioral XSim
    -> functional correctness and cycle/timestamp measurements

Synthesis
    -> technology mapping and resource-utilization evidence
       such as LUT, Slice-FF, and DSP48E1 usage

Implementation + static timing analysis
    -> placed/routed setup and hold timing evidence
       including WNS/TNS and timing-closure status
```

The learner explicitly stated that resource usage requires synthesis results, while timing closure requires implementation results. This is the required distinction: synthesis can report mapped resources, but final routed timing closure cannot be established from behavioral simulation or resource reports alone.

## Gate result

**STEP-8 UNDERSTANDING GATE: PASSED**

The learner has correctly distinguished behavioral timing measurement, synthesis resource measurement, and implementation/static-timing evidence.

Step 8 is therefore complete, including its understanding gate.

The next mandatory workflow step is:

```text
Step 9: update docs/analysis/convolution_integration.md with measured-versus-predicted results
```

That step belongs to the Performance Analyst role and should be performed in a separate interaction/response so project roles are not mixed.