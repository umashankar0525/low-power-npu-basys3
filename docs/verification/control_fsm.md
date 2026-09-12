# Control FSM — Verification Plan

**Project:** Low-Power INT8 NPU on Basys 3  
**Role:** Verification Engineer  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** VERIFY  
**Status:** Verification plan complete; testbench not yet generated or simulated.

## 1. Verification Objective

Verify that `rtl/control/control_fsm.v` implements the derived five-state supervisory protocol exactly:

`IDLE -> LAUNCH -> WAIT_ENGINE -> CAPTURE_ACTIVATION -> DONE -> IDLE`

The verification must prove not merely that the FSM eventually reaches `DONE`, but that every control signal is asserted in the correct state, for the correct duration, and in the correct order.

The controller under test does not perform arithmetic. Therefore verification focuses on transaction sequencing and handshake correctness.

## 2. Assumptions

- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- Reset is synchronous and active high.
- External `start` is a one-cycle pulse and is legal only when `busy = 0`.
- `engine_done` is modeled as a one-cycle pulse from the convolution engine.
- The testbench verifies the control FSM in isolation; it does not instantiate the BRAM/MAC engine in this unit test.
- The previously measured convolution-engine latency is four clock periods from its accepted start edge to its own done-generation edge.
- `busy` must remain high in `DONE` and become low only in `IDLE`.
- `done`, `engine_start`, and `capture_activation` are each expected to be one-cycle Moore-style pulses.
- No simulation result is claimed in this document. All behavior below is expected behavior to be tested.

## 3. Signals Under Verification

### Inputs

- `clk`
- `rst`
- `start`
- `engine_done`

### Outputs

- `engine_start`
- `capture_activation`
- `busy`
- `done`

The internal state register may be observed hierarchically in the unit test if useful for debug, but pass/fail criteria should primarily be based on the public interface behavior.

## 4. State/Output Truth Table

The RTL is Moore-style, so outputs are determined by current state.

| State | `engine_start` | `capture_activation` | `busy` | `done` |
|---|---:|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 | 0 |
| `LAUNCH` | 1 | 0 | 1 | 0 |
| `WAIT_ENGINE` | 0 | 0 | 1 | 0 |
| `CAPTURE_ACTIVATION` | 0 | 1 | 1 | 0 |
| `DONE` | 0 | 0 | 1 | 1 |

This table is the primary output-decoding reference for the testbench.

## 5. Nominal Transaction Derivation

Let edge `S0` be the edge where external `start = 1` is sampled while the FSM is in `IDLE`.

Expected sequence:

| Edge / interval | Expected FSM behavior | Expected outputs |
|---|---|---|
| Before S0 | `IDLE` | `busy=0`, all pulses 0 |
| S0 | accept `start`, transition toward `LAUNCH` | Moore outputs change after state update |
| S0 -> S1 | `LAUNCH` | `engine_start=1`, `busy=1` |
| S1 | transition to `WAIT_ENGINE` | `engine_start` must deassert |
| S1 -> S6 | remain `WAIT_ENGINE` while `engine_done=0` | `busy=1`, other outputs 0 |
| S6 | sample `engine_done=1`, transition toward capture | no early `done` allowed |
| S6 -> S7 | `CAPTURE_ACTIVATION` | `capture_activation=1`, `busy=1` |
| S7 | transition to `DONE` | capture pulse ends |
| S7 -> S8 | `DONE` | `done=1`, `busy=1` |
| S8 | return to `IDLE` | `done` deasserts |
| after S8 | `IDLE` | `busy=0`, all pulses 0 |

For an isolated FSM unit test, the testbench does not need to wait exactly four engine cycles before driving `engine_done`; however, one directed test should model the real wrapped-engine timing so the expected 70 ns supervisory transaction can be checked.

## 6. Required Directed Tests

### Test 1 — Reset behavior

Stimulus:

- Assert `rst = 1` across a rising edge.
- Keep `start = 0`, `engine_done = 0`.

Expected:

- FSM returns to `IDLE`.
- `busy = 0`.
- `engine_start = 0`.
- `capture_activation = 0`.
- `done = 0`.

Why it matters:

A controller must never launch the engine or claim completion after reset.

### Test 2 — Idle hold

Stimulus:

- Release reset.
- Keep `start = 0` for several clocks.

Expected:

- Controller remains idle indefinitely.
- No output pulse appears spontaneously.
- `busy` remains 0.

Why it matters:

This checks that no uncontrolled transition occurs without a transaction request.

### Test 3 — Single accepted start

Stimulus:

- Pulse `start = 1` for one clock while idle.

Expected:

- `engine_start` becomes high for exactly one clock interval.
- `busy` becomes high.
- The controller then enters `WAIT_ENGINE`.
- `engine_start` must return low even if the engine has not completed.

Why it matters:

The convolution engine must receive one launch event, not a level that remains asserted throughout the calculation.

### Test 4 — Wait behavior

Stimulus:

- After launch, hold `engine_done = 0` for multiple cycles.

Expected:

- Controller stays in `WAIT_ENGINE`.
- `busy = 1` continuously.
- `engine_start = 0`.
- `capture_activation = 0`.
- `done = 0`.

Why it matters:

The controller must tolerate arbitrary engine latency rather than assuming a hard-coded completion cycle.

### Test 5 — Engine completion handshake

Stimulus:

- While in `WAIT_ENGINE`, pulse `engine_done = 1` for one cycle.

Expected:

- The controller transitions to `CAPTURE_ACTIVATION`.
- `capture_activation = 1` for exactly one clock interval.
- `done` must remain 0 during capture.
- `busy` remains 1.

Why it matters:

Completion of the convolution must cause activation capture before external completion is reported.

### Test 6 — Done behavior

Stimulus:

- Allow the FSM to advance from `CAPTURE_ACTIVATION` to `DONE`.

Expected:

- `done = 1` for exactly one clock interval.
- `busy = 1` during that same `DONE` interval.
- `engine_start = 0`.
- `capture_activation = 0`.
- Next state is `IDLE`.

Why it matters:

This directly verifies the handshake decision made during analysis: `done` does not imply immediate readiness.

### Test 7 — Busy drops only in IDLE

Expected invariant across the transaction:

- `busy = 0` only in `IDLE`.
- `busy = 1` in `LAUNCH`, `WAIT_ENGINE`, `CAPTURE_ACTIVATION`, and `DONE`.

Why it matters:

External logic is allowed to use `busy = 0` as the readiness condition for issuing a new start.

### Test 8 — Start while busy is ignored

Stimulus:

- Begin a valid transaction.
- Pulse external `start` again while the controller is in `WAIT_ENGINE`.

Expected:

- No second `engine_start` pulse is generated.
- Current transaction remains unaffected.
- State remains in the normal path toward the original completion.

Why it matters:

The controller samples `start` only in `IDLE`.

### Test 9 — Start during DONE is ignored

Stimulus:

- Pulse `start` while the controller is in `DONE`.

Expected:

- No engine launch occurs.
- Controller returns to `IDLE` normally.
- A new start must be presented once idle.

Why it matters:

This verifies that the `busy=1` decision correctly warns the external source not to issue a request in `DONE`.

### Test 10 — Back-to-back legal transactions

Stimulus:

- Complete one transaction.
- Wait until `busy = 0` in `IDLE`.
- Issue a second one-cycle `start`.

Expected:

- A second independent `engine_start` pulse occurs.
- The full state sequence repeats correctly.
- No stale `done`, capture, or launch pulse leaks from the first transaction.

Why it matters:

Reset should not be required between transactions.

### Test 11 — Reset during an active transaction

Stimulus:

- Start a transaction.
- Assert synchronous reset while in `WAIT_ENGINE`.

Expected after the reset edge:

- Controller returns to `IDLE`.
- `busy = 0`.
- All pulses deassert.
- Any previous transaction is abandoned at the supervisory level.

Why it matters:

Reset must dominate normal state progression and put the control interface into a known safe condition.

## 7. Real-Timing Scenario

One directed test should model the actual existing engine timing.

At 100 MHz:

- external `start` is accepted at S0,
- `engine_start` is presented during S0 -> S1,
- the modeled engine accepts it at S1,
- four engine periods later it generates `engine_done` at S5,
- outer FSM observes the registered completion at S6,
- activation capture occurs during S6 -> S7,
- `done` is high after S7.

Therefore expected external start-to-output-valid/done latency remains:

`7 clock periods x 10 ns = 70 ns`.

This unit test should measure edge-to-edge latency rather than simulation `$finish` time.

## 8. Verification Invariants

The testbench should continuously check these properties:

1. `engine_start` and `capture_activation` are never high simultaneously.
2. `engine_start` and `done` are never high simultaneously.
3. `capture_activation` and `done` are never high simultaneously.
4. `done = 1` implies `busy = 1` under the finalized handshake policy.
5. `busy = 0` implies all pulse outputs are 0 and the controller is ready for `start`.
6. One accepted external start produces exactly one `engine_start` pulse.
7. One valid `engine_done` event during a transaction produces exactly one capture pulse and exactly one done pulse.
8. `done` never occurs before `capture_activation` has occurred.
9. While waiting with `engine_done=0`, no completion-related pulse may appear.
10. Reset forces the controller back to the safe idle behavior on the reset edge.

## 9. Expected Pulse Counts Per Successful Transaction

For one transaction:

- accepted external `start`: 1
- `engine_start` pulse: 1
- modeled `engine_done` pulse: 1
- `capture_activation` pulse: 1
- `done` pulse: 1

A useful testbench scoreboard should count these pulses and fail if any count is duplicated or missing.

## 10. What This Unit Test Does Not Prove

Passing this unit test will prove the supervisory state/handshake behavior of `control_fsm` in isolation.

It will not yet prove:

- arithmetic correctness of the convolution engine,
- BRAM address correctness inside `memory_interface_dataflow`,
- ReLU numeric correctness,
- correct wiring between all three modules,
- final end-to-end INT8 result correctness,
- post-synthesis resource usage or timing closure.

Those require integration verification and later measurement steps.

## 11. Pass Criteria

The Control FSM unit test passes only if all directed scenarios complete with zero errors and the signal-level checks confirm:

- correct reset/idle behavior,
- exactly one launch pulse per legal request,
- stable waiting behavior,
- correct response to `engine_done`,
- capture before done,
- one-cycle capture pulse,
- one-cycle done pulse,
- `busy` high through `DONE`,
- `busy` low only in `IDLE`,
- illegal starts while busy do not create extra launches,
- legal restart from idle works,
- predicted 70 ns real-timing scenario is reproduced.

A final numeric `error_count = 0` alone will not be accepted without explaining the observed waveforms signal by signal.

## 12. Next Workflow Step

After the user confirms understanding of this verification plan, generate the unit testbench at:

`tb/unit/tb_control_fsm.v`

Simulation must then be run in XSim, and the measured behavior must be compared against this plan and the earlier performance prediction.
