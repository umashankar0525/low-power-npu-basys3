# Control FSM Verification — Understanding Clarification

**Role:** Verification Engineer  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** VERIFY understanding gate

## Confirmed Understanding

The learner correctly explained that:

1. `engine_start` must be a one-cycle launch event rather than remaining asserted throughout the transaction.
2. `capture_activation` must occur before `done`, because the final output must be stored before completion is reported externally.

## Point Requiring Correction

For the question "What should happen if `engine_done` remains 0 for many cycles?", the initial answer was "restart". That is not correct for the selected supervisory protocol.

The required behavior is:

- remain in `ST_WAIT_ENGINE`,
- keep `busy = 1`,
- keep `engine_start = 0`,
- keep `capture_activation = 0`,
- keep `done = 0`,
- continue waiting until `engine_done = 1` is observed.

The controller must not relaunch the engine while an existing transaction is incomplete. The purpose of `WAIT_ENGINE` is specifically to tolerate an engine whose completion latency may vary.

## Hard Gate

Before generating `tb/unit/tb_control_fsm.v`, the learner must restate the corrected `WAIT_ENGINE` behavior in their own words.
