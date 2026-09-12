# Control FSM — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** DESIGN  
**Status:** Design finalized; understanding confirmed; RTL permitted.

## 1. Design Objective

Create a supervisory finite-state machine that coordinates the already-built 3x3 convolution engine and the ReLU/output stage without duplicating control that already exists inside the convolution engine.

The controller must:

- accept one external `start` request,
- launch exactly one convolution operation,
- remain busy while the convolution engine is active,
- wait until the convolution engine reports completion,
- allow the completed INT32 result to propagate through the combinational ReLU/saturation block,
- request capture of the resulting INT8 activation,
- assert a one-cycle `done` indication,
- remain non-ready throughout the `DONE` interval,
- return to `IDLE` before accepting another transaction.

## 2. Assumptions

- FPGA: XC7A35T-1CPG236C on Basys 3.
- Clock: 100 MHz.
- Reset: synchronous, active high.
- External `start` is a one-clock pulse and is only legal when `busy = 0`.
- `memory_interface_dataflow` is treated as the existing convolution engine.
- The convolution engine accepts `start` and returns `done` plus a stable signed INT32 `result`.
- The convolution engine already contains the BRAM/MAC/accumulation micro-sequencer for one 3x3 convolution.
- The convolution engine's `done` is a one-clock pulse.
- `relu_activation` is combinational and has zero architectural clock-cycle latency.
- The final INT8 activation is stored by surrounding integration logic when `capture_activation = 1`.
- `busy = 0` means the controller is truly ready to accept a new `start`.

## 3. Why Hierarchical Control Is Used

The existing `memory_interface_dataflow` RTL already contains the local states:

- `ST_IDLE`
- `ST_WAIT0`
- `ST_WORD0`
- `ST_WORD1`
- `ST_WORD2`

That local FSM already owns:

- synchronous-memory waiting,
- BRAM address sequencing,
- the three packed convolution words,
- four-lane MAC work,
- running accumulation,
- final INT32 result generation.

Therefore the B9 Control FSM must not create another BRAM-address or MAC-iteration controller. That would create duplicated control ownership.

The chosen hierarchy is:

```text
External start
     |
     v
+------------------+
|   control_fsm    |
+------------------+
     | engine_start
     v
+--------------------------+
| memory_interface_dataflow|
| local BRAM/MAC FSM       |
| INT32 accumulation       |
+--------------------------+
     | engine_result
     | engine_done
     v
+------------------+
| relu_activation  |
| combinational    |
+------------------+
     | relu_output
     v
 final output register
```

The memory-wait concept still exists physically; it is already implemented inside the convolution engine as `ST_WAIT0`.

## 4. Control FSM Interface

### Inputs

- `clk` — system clock.
- `rst` — synchronous active-high reset.
- `start` — one-cycle external transaction request.
- `engine_done` — one-cycle completion pulse from the convolution engine.

### Outputs

- `engine_start` — one-cycle pulse that launches the convolution engine.
- `capture_activation` — one-cycle pulse instructing integration logic to register the ReLU result.
- `busy` — high whenever a new external start must not be issued.
- `done` — one-cycle pulse indicating that the final registered INT8 activation is valid.

The FSM does not carry or modify arithmetic data. `engine_result` and the ReLU output remain datapath signals.

## 5. State Set

Five states are used.

### `IDLE`

Purpose:

- controller is ready,
- `busy = 0`,
- wait for `start`.

Transition:

- `start = 0` -> remain in `IDLE`.
- `start = 1` -> `LAUNCH`.

### `LAUNCH`

Purpose:

- assert `engine_start = 1` for exactly one clock interval,
- assert `busy = 1`.

Transition:

- unconditional -> `WAIT_ENGINE`.

### `WAIT_ENGINE`

Purpose:

- keep `busy = 1`,
- wait for convolution completion.

Transition:

- `engine_done = 0` -> remain in `WAIT_ENGINE`.
- `engine_done = 1` -> `CAPTURE_ACTIVATION`.

### `CAPTURE_ACTIVATION`

Purpose:

- keep `busy = 1`,
- assert `capture_activation = 1` for one clock interval.

The ReLU block is combinational, so once `engine_result` is stable, the INT8 activated result is available after propagation delay. This state creates a clean registered output boundary.

Transition:

- unconditional -> `DONE`.

### `DONE`

Purpose:

- assert `done = 1` for exactly one clock interval,
- keep `busy = 1` during the completion pulse.

Transition:

- unconditional -> `IDLE`.

The important finalized handshake decision is that `busy` remains high in `DONE`. This prevents external logic from seeing `busy = 0` while the controller is still in a state that cannot accept `start`.

## 6. State Transition Diagram

```text
                         start=1
              +--------------------------+
              |                          v
          +-------+                  +--------+
          | IDLE  |                  | LAUNCH |
          +---+---+                  +---+----+
              ^                          |
              |                          v
              |                     +-------------+
              |                     | WAIT_ENGINE |
              |                     +------+------+ 
              |                            |
              |           engine_done=0   | engine_done=1
              |              +-------------+----------+
              |              |                        v
              |              |               +--------------------+
              |              +-------------->| CAPTURE_ACTIVATION |
              |                              +---------+----------+
              |                                        |
              |                                        v
              |                                    +--------+
              +------------------------------------|  DONE  |
                                                   +--------+
```

## 7. Moore-Style Output Definition

| State | `engine_start` | `capture_activation` | `busy` | `done` |
|---|---:|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 | 0 |
| `LAUNCH` | 1 | 0 | 1 | 0 |
| `WAIT_ENGINE` | 0 | 0 | 1 | 0 |
| `CAPTURE_ACTIVATION` | 0 | 1 | 1 | 0 |
| `DONE` | 0 | 0 | 1 | 1 |

Thus:

`busy = 0` if and only if the controller is in `IDLE`.

## 8. Handshake Semantics

### External `start`

`start` is sampled only in `IDLE` and is assumed to be a one-clock pulse. Requests while `busy = 1` are not legal and are ignored by the controller.

For a physical Basys 3 push button, synchronization, debouncing, and one-shot generation belong outside this FSM.

### Internal `engine_start`

`engine_start` is asserted only in `LAUNCH`, so one accepted external request produces exactly one engine launch pulse.

### `engine_done`

The supervisory controller does not hard-code the engine's internal cycle count. It waits for `engine_done`. This preserves modularity if the engine is later optimized internally.

### External `done`

`done` is asserted only in `DONE`. The output has already been captured before this pulse is presented.

`busy` remains high while `done` is high. The next transaction may be issued only after the controller returns to `IDLE` and `busy` becomes low.

## 9. Reset Behavior

On synchronous reset:

- state becomes `IDLE`,
- `engine_start = 0`,
- `capture_activation = 0`,
- `busy = 0`,
- `done = 0`.

Reset must never launch the engine.

## 10. Why No MAC Counter Exists Here

The supervisory controller sees the convolution engine as one transaction:

```text
launch -> wait -> completed
```

The three-word BRAM/MAC sequence is already owned by the inner engine. A second word/MAC counter in this FSM would duplicate that responsibility.

## 11. Control Invariants

The implementation must satisfy all of the following:

1. `engine_start` is high only in `LAUNCH`.
2. `capture_activation` is high only in `CAPTURE_ACTIVATION`.
3. `done` is high only in `DONE`.
4. `busy` is low only in `IDLE`.
5. One accepted external `start` causes exactly one `engine_start` pulse.
6. `capture_activation` cannot occur before `engine_done` has been observed.
7. `done` cannot occur before activation capture.
8. Reset returns the controller to a non-launching `IDLE` condition.
9. The controller never directly performs arithmetic or controls internal BRAM addresses.
10. A new transaction is not issued during the `DONE` pulse.

## 12. Final Design Decision

Use a five-state Moore-style supervisory FSM with hierarchical control:

```text
IDLE -> LAUNCH -> WAIT_ENGINE -> CAPTURE_ACTIVATION -> DONE -> IDLE
```

The final handshake policy is:

```text
busy = 0 only in IDLE
busy = 1 in LAUNCH, WAIT_ENGINE, CAPTURE_ACTIVATION, and DONE
```

This removes the earlier ambiguity between `busy = 0` and actual readiness.

The user confirmed understanding of the hierarchical-control rationale and explicitly agreed with keeping `busy` high during `DONE`.
