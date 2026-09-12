# Control FSM — Design Review

**Project:** Low-Power INT8 NPU on Basys 3  
**Role:** Design Reviewer  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** REVIEW  
**Review status:** **PASS for unit-level architecture and behavioral verification; synthesis/implementation characterization and full integration remain pending.**

## 1. Review Scope

This review evaluates whether the Control FSM is architecturally sound, consistent with the earlier design and analysis, correctly implemented in RTL, and adequately verified at unit level.

The reviewed artifacts are:

- `docs/learning/control_fsm.md`
- `docs/design/control_fsm.md`
- `docs/analysis/control_fsm.md`
- `rtl/control/control_fsm.v`
- `docs/verification/control_fsm.md`
- `tb/unit/tb_control_fsm.v`
- `docs/verification/control_fsm_xsim_measurement.md`

The review intentionally separates what has been **measured** from what is still only **predicted**.

## 2. Architectural Decision Reviewed

The main architectural decision is to use the new Control FSM as a **supervisory controller** rather than duplicating the BRAM/MAC sequencing already implemented inside `memory_interface_dataflow`.

The hierarchy is:

```text
external start
    |
    v
control_fsm
    |
    | engine_start
    v
memory_interface_dataflow
    |
    | engine_result + engine_done
    v
relu_activation
    |
    v
registered output
```

This is the correct ownership model for the current project because the inner engine already contains the local memory/MAC control states.

### Review conclusion

**Approved.** There is one clear owner for each level of control:

- local engine sequencing belongs to `memory_interface_dataflow`,
- transaction-level sequencing belongs to `control_fsm`.

This avoids two controllers attempting to manipulate the same BRAM/MAC schedule.

## 3. State-Machine Review

The implemented supervisory states are:

1. `IDLE`
2. `LAUNCH`
3. `WAIT_ENGINE`
4. `CAPTURE_ACTIVATION`
5. `DONE`

The intended sequence is:

```text
IDLE -> LAUNCH -> WAIT_ENGINE -> CAPTURE_ACTIVATION -> DONE -> IDLE
```

The transition conditions are simple and deterministic:

- `IDLE -> LAUNCH` only when external `start = 1`,
- `LAUNCH -> WAIT_ENGINE` unconditionally,
- `WAIT_ENGINE -> CAPTURE_ACTIVATION` only when `engine_done = 1`,
- `CAPTURE_ACTIVATION -> DONE` unconditionally,
- `DONE -> IDLE` unconditionally.

The default transition returns an illegal state to `IDLE`.

### Review conclusion

**Approved.** The FSM structure directly reflects the design specification and does not contain unnecessary control states for BRAM addressing or MAC iteration.

## 4. State-Width Review

Five states require a minimum binary state width satisfying:

`2^N >= 5`

For two bits:

`2^2 = 4 < 5`

For three bits:

`2^3 = 8 >= 5`

Therefore the logical minimum is:

`N = 3 bits`

The RTL uses a 3-bit state and next-state register.

### Review conclusion

**Correct.** The logical state width matches the first-principles derivation.

Vivado may still choose a different physical FSM encoding during synthesis; this remains a synthesis-measurement question rather than a functional design error.

## 5. Moore-Output Review

The FSM uses Moore-style output decoding.

Expected output table:

| State | `engine_start` | `capture_activation` | `busy` | `done` |
|---|---:|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 | 0 |
| `LAUNCH` | 1 | 0 | 1 | 0 |
| `WAIT_ENGINE` | 0 | 0 | 1 | 0 |
| `CAPTURE_ACTIVATION` | 0 | 1 | 1 | 0 |
| `DONE` | 0 | 0 | 1 | 1 |

The RTL matches this table.

### Review conclusion

**Approved.** The outputs are easy to reason about in waveforms and correspond directly to states.

## 6. Handshake Review

### `engine_start`

`engine_start` is high only in `LAUNCH` and therefore lasts one clock interval.

This gives exactly one launch event per accepted transaction request.

### `engine_done`

The controller remains in `WAIT_ENGINE` for an arbitrary number of cycles until `engine_done` is observed.

Therefore the outer controller is not hard-coded to a specific inner-engine latency.

### `capture_activation`

Capture is asserted only after the engine has completed and before external `done` is reported.

This guarantees that the final activation is stored before completion is advertised.

### `done` and `busy`

The final policy is:

```text
busy = 1 in DONE
busy = 0 only in IDLE
```

This resolves the earlier ambiguity where `busy = 0` could have falsely implied readiness during `DONE`.

### Review conclusion

**Approved.** The finalized handshake has a clear external contract:

- `done = 1` means the completed output is valid,
- `busy = 0` means the controller is actually ready for another request.

## 7. Reset Review

Reset is synchronous and active high.

On the reset edge, the state register returns to `IDLE`.

Because outputs are Moore-decoded from state, the resulting control outputs become:

```text
engine_start       = 0
capture_activation = 0
busy               = 0
done               = 0
```

The unit test also applied reset during `WAIT_ENGINE` and observed immediate return to idle behavior after the reset edge.

### Review conclusion

**Approved.** Reset behavior is safe and deterministic for the supervisory controller.

## 8. Timing-Derivation Review

The existing convolution engine was previously measured as:

`engine start -> engine done = 4 clock periods`

At 100 MHz:

`Tclk = 10 ns`

so:

`4 x 10 ns = 40 ns`

The supervisory FSM adds three clock periods:

1. launch period,
2. one period for visibility of registered `engine_done`,
3. activation-capture period.

Therefore predicted external latency was:

`4 + 3 = 7 cycles`

and:

`7 x 10 ns = 70 ns`

XSim measured:

`70 ns`

### Review conclusion

**Strong match.** The prediction and behavioral measurement agree exactly for the tested timing scenario.

This confirms the clock-edge reasoning used for the supervisory protocol.

## 9. Behavioral Verification Review

The unit test covered:

- synchronous reset,
- stable idle behavior,
- one-cycle launch pulse,
- arbitrary waiting while `engine_done = 0`,
- capture-before-done ordering,
- one-cycle capture pulse,
- one-cycle done pulse,
- `busy = 1` through `DONE`,
- ignored `start` while busy,
- ignored `start` during `DONE`,
- legal restart after return to `IDLE`,
- reset during an incomplete transaction,
- pulse-count scoreboarding,
- the 70 ns timing scenario.

Measured final counters:

```text
engine_start_count = 4
capture_count      = 3
done_count         = 3
transaction_count  = 3
failures           = 0
```

The fourth launch was deliberately reset before completion, so the unequal launch/completion count is expected.

### Review conclusion

**PASS.** The unit-level testbench verifies the intended public control protocol rather than checking only final completion.

## 10. Prediction vs Measurement Review

| Metric | Predicted | Measured | Review |
|---|---:|---:|---|
| `engine_start` width | 1 cycle | 1 cycle | Match |
| Wait while `engine_done=0` | indefinite | observed | Match |
| `capture_activation` width | 1 cycle | 1 cycle | Match |
| Capture before `done` | yes | yes | Match |
| `done` width | 1 cycle | 1 cycle | Match |
| `busy` during `DONE` | 1 | 1 | Match |
| `busy` in `IDLE` | 0 | 0 | Match |
| Start while busy | ignored | ignored | Match |
| Reset during active transaction | return to idle | observed | Match |
| External start -> done | 70 ns | 70 ns | Match |
| Unit-test failures | 0 expected | 0 | Match |

The behavioral prediction is therefore validated for the exercised unit-level scenarios.

## 11. Resource Review

Predicted direct resources for the controller are:

- logical binary state storage: 3 FFs,
- DSP48: 0,
- BRAM: 0,
- first-order control logic: approximately 7 LUT6-equivalent Boolean functions before synthesis optimization or FSM re-encoding.

### Review conclusion

These values are still **predictions only**.

No post-synthesis utilization result for `control_fsm` has yet been recorded, so the review does not approve an exact LUT/FF resource claim.

## 12. Timing-Closure Review

The controller's logical paths are shallow compared with the arithmetic datapath:

```text
state FF -> decode -> state FF
```

and:

```text
start/engine_done -> next-state decode -> state FF
```

At a 100 MHz target, the design is expected to have substantial timing margin.

### Review conclusion

This remains a **prediction** until synthesis/implementation timing is measured.

Behavioral simulation proves sequencing, not physical propagation delay or Fmax.

## 13. Issues and Limitations

The unit-level Control FSM is approved, but the following items remain outside the completed evidence:

1. No synthesis utilization measurement has yet confirmed the predicted LUT/FF count.
2. No post-synthesis or post-implementation timing report has yet confirmed physical timing margin at 100 MHz.
3. The unit test drives `engine_done` explicitly; it does not yet instantiate the real `memory_interface_dataflow` block together with the controller.
4. The Control FSM does not itself register the INT8 activation; integration logic must implement the output register driven by `capture_activation`.
5. Full end-to-end correctness still requires integration of `control_fsm`, `memory_interface_dataflow`, and `relu_activation`.
6. The current handshake deliberately introduces a one-cycle `DONE` state and does not optimize back-to-back transaction throughput.

None of these are unit-level functional failures. They define the next integration and measurement work.

## 14. Possible Future Optimizations

After baseline integration is proven, future experiments may consider:

- accepting a new request directly from `DONE`,
- adding an explicit `ready` signal,
- reducing supervisory overhead,
- merging activation capture with another registered boundary,
- comparing binary versus one-hot FSM encoding,
- adding clock-enable-based low-power control.

These should not be introduced before the current baseline is integrated and measured because they would change the verified timing contract.

## 15. Design Review Verdict

### Functional architecture

**PASS**

The hierarchy is clean, the state machine matches the architectural responsibilities, and control ownership is unambiguous.

### RTL consistency with design

**PASS**

The implemented transitions and Moore outputs match the finalized specification.

### Behavioral verification

**PASS**

The directed XSim unit tests completed with zero failures and reproduced the predicted 70 ns timing.

### Resource/timing characterization

**PENDING**

Exact synthesis utilization and physical timing remain to be measured.

### Integration readiness

**READY FOR NEXT INTEGRATION STEP**

The Control FSM is sufficiently understood and unit-verified to proceed toward integration with the existing convolution engine and ReLU/output datapath.

## 16. Final Review Summary

The Control FSM successfully completed the architecture-first workflow:

```text
TEACH
 -> DESIGN
 -> ANALYZE/PREDICT
 -> USER UNDERSTANDING
 -> RTL
 -> VERIFY
 -> TESTBENCH
 -> SIMULATE
 -> MEASURE
 -> COMPARE
 -> REVIEW
```

The key engineering result is not simply that simulation passed. The important result is that the state sequence and 70 ns latency were derived before simulation and then reproduced exactly by XSim.

This demonstrates that the controller is being understood as a clocked hardware protocol rather than treated as code that merely happens to simulate.

## 17. Gate Before Final Knowledge Test

Before `/test control_fsm`, the learner should be able to explain:

1. why this FSM is supervisory instead of directly controlling BRAM/MAC iterations,
2. why the controller has five states and needs at least three binary state bits,
3. why `engine_start` is a one-cycle event,
4. why the outer FSM observes a newly registered `engine_done` on the following edge,
5. why `capture_activation` comes before `done`,
6. why `busy` remains high during `DONE`,
7. how the 70 ns latency is derived from seven 10 ns periods,
8. what XSim proved and what synthesis/implementation still need to prove.
