# Phase 8 — Basys 3 Top-Level Teaching Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 1 — `/teach basys3_top_level` understanding gate  
**Status:** PARTIAL — one architectural boundary must be corrected before `/design basys3_top_level`.

The core-only synthesis/implementation baseline has already been completed and understood. This checkpoint evaluates the learner's board-wrapper restatement.

## 1. Why `convolution_integration` is not a complete Basys-3 top level

**Status: PASSED**

The learner correctly distinguished the accelerator integration module from a physical Basys-3 top level. The existing core does not yet own board-specific pushbutton/switch/LED connections or board pin constraints.

## 2. Responsibilities of `basys3_top_level` versus the accelerator core

**Status: PARTIAL**

The learner correctly assigned the following board-wrapper responsibilities:

```text
100 MHz board clock entry
button/switch handling
clean start generation
LED/status mapping
instantiation of convolution_integration
```

However, the learner stated that the accelerator core should retain the memories. That is not the current Phase-7/Phase-8 architecture.

The intended boundary is:

```text
convolution_integration
  owns:
    control_fsm
    memory request sequencing
    convolution arithmetic
    requantization
    architectural activation_out
    busy/done protocol

basys3_top_level / platform side
  owns:
    physical or inferred activation memory
    physical or inferred weight memory
    board input conditioning
    start pulse generation
    board-visible status/result logic
    board clock/pin constraints
```

`memory_interface_dataflow` inside the accelerator core generates `rd_en` and addresses and consumes returned memory data, but the physical memories themselves remain outside `convolution_integration` at this architecture boundary.

## 3. Why a physical button cannot directly drive `start`

**Status: PASSED**

The learner correctly identified both asynchronous clock-domain behavior and mechanical bounce. Direct use could create metastability risk and multiple unintended transaction launches.

## 4. Synchronization, debouncing, and one-cycle pulse generation

**Status: PASSED**

The learner correctly distinguished:

```text
synchronization -> safe clock-domain crossing
debouncing      -> remove mechanical bounce transitions
one-cycle pulse -> convert one stable event into one core start pulse
```

and correctly gave the conceptual sequence:

```text
button -> synchronizer -> debouncer -> one-cycle pulse -> start
```

## 5. One-clock synchronous memory-read contract

**Status: PASSED**

The learner correctly stated that the Phase-7 state/data schedule was derived around one-clock read latency, so changing to a different memory timing contract would invalidate the established sequencing assumptions.

## 6. Packed memory capacity derivation

**Status: PASSED**

The learner correctly derived:

```text
9 INT8 values = 9 x 8 = 72 useful bits
ceil(72 / 32) = 3 words
3 x 32 = 96 packed bits per operand memory
2 x 96 = 192 packed bits combined
```

Each operand memory therefore has 24 padding bits in the final packed capacity.

## 7. Why RTL memory declaration does not prove BRAM inference

**Status: PASSED**

The learner correctly stated that Vivado may map a memory into BRAM, distributed RAM, or registers depending on size, coding style, ports, read behavior, and synthesis heuristics. Physical BRAM use must be confirmed in the synthesis utilization/netlist evidence.

## 8. Why raw `done` is not directly human-visible

**Status: PASSED**

At 100 MHz:

```text
Tclk = 10 ns
```

The learner correctly explained that a one-cycle `done` event is too short to observe visually and should be converted into a latched or otherwise human-visible board status without changing the internal core protocol.

## 9. Why the final board top needs its own synthesis/implementation

**Status: PASSED**

The learner correctly stated that added board logic, I/O, memories, routing, fanout, and hierarchy change both physical resource use and timing. Therefore the final `basys3_top_level` requires its own resource and post-route timing evidence.

## 10. Low-power meaning at board-top level

**Status: PASSED**

The learner correctly emphasized reducing unnecessary switching/activity and using clock-enable style control rather than ordinary combinational logic to gate FPGA clocks, which could introduce clock-quality and timing problems.

## Gate result

**BASYS3 TOP-LEVEL TEACHING GATE: NOT YET PASSED**

Items 1 and 3 through 10 are passed. Item 2 remains partial only because the physical activation/weight memories were assigned to the accelerator core instead of the Phase-8 platform/top-level side.

The learner must restate the ownership boundary between:

```text
convolution_integration: memory sequencing + compute
basys3_top_level: physical/inferred activation and weight memories + board infrastructure
```

before Step 2 `/design basys3_top_level` is permitted.