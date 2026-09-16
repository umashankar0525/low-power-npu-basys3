# Phase 8 — Basys 3 Top-Level Teaching Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 1 — `/teach basys3_top_level` understanding gate  
**Status:** PASSED — Step 2 `/design basys3_top_level` is unlocked.

The core-only synthesis/implementation baseline has already been completed and understood. This checkpoint records the learner's final board-wrapper understanding.

## 1. `convolution_integration` versus the Basys-3 top

**PASSED**

The learner correctly distinguished the reusable accelerator core from the physical board wrapper. Board-specific clock entry, controls, LEDs/status and pin-level integration belong outside the compute core.

## 2. Memory ownership boundary

**PASSED**

The learner correctly restated the final ownership boundary:

```text
convolution_integration
  -> memory request sequencing
  -> read enables / addresses
  -> consumes returned activation and weight data
  -> convolution compute + requantization

basys3_top_level
  -> physical/inferred activation memory
  -> physical/inferred weight memory
  -> connects memory outputs back to convolution_integration
  -> board infrastructure
```

The important distinction is that `memory_interface_dataflow` controls **how** memory is accessed, but the actual FPGA memories are platform-side resources outside `convolution_integration`.

## 3. Physical input handling

**PASSED**

The learner correctly explained that board pushbuttons are asynchronous and mechanically noisy, so synchronization, debouncing and one-cycle pulse generation are distinct required concepts.

## 4. One-clock memory-read contract

**PASSED**

The learner correctly preserved the Phase-7 assumption that a read request at one edge produces the corresponding memory data one clock later.

## 5. Packed memory sizing

**PASSED**

```text
9 INT8 values = 72 useful bits
ceil(72/32) = 3 x 32-bit words
96 packed bits per operand memory
192 packed bits combined
```

## 6. BRAM inference understanding

**PASSED**

The learner correctly understands that a small RTL array may map to registers, LUT RAM or BRAM; synthesis evidence is required to prove the physical mapping.

## 7. Human-visible done indication

**PASSED**

A one-cycle `done` event at 100 MHz lasts 10 ns and is not directly visible to a human, so any LED indication must use board-wrapper observability logic such as a latched flag or stretcher without changing the core protocol.

## 8. Final board-top physical validation

**PASSED**

The learner correctly understands that `basys3_top_level` must be synthesized and implemented independently because memories, board I/O, synchronization logic, routing and fanout can change both resource usage and timing.

## 9. Low-power board-top concept

**PASSED**

The learner correctly emphasized reducing unnecessary switching and using clock-enable/activity-control techniques rather than ordinary combinational clock gating.

## Gate result

**BASYS3 TOP-LEVEL TEACHING GATE: PASSED**

Step 1 `/teach basys3_top_level` is complete. Step 2 `/design basys3_top_level` is now permitted.