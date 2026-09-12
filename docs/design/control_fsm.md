# Control FSM — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** DESIGN

## 1. Design Objective

Create a supervisory finite-state machine that coordinates the already-built 3x3 convolution engine and the ReLU/output stage without duplicating control that already exists inside the convolution engine.

The controller must:

- accept one external `start` request,
- launch exactly one convolution operation,
- remain busy while the convolution engine is active,
- wait until the convolution engine reports completion,
- allow the completed INT32 result to propagate through the combinational ReLU/saturation block,
- capture the resulting INT8 activation,
- assert a one-cycle `done` indication,
- return to `IDLE` ready for the next transaction.

No RTL is generated in this step.

## 2. Assumptions

- FPGA: XC7A35T-1CPG236C on Basys 3.
- Clock: 100 MHz.
- Reset: synchronous, active high.
- External `start` is a one-clock pulse and is only meaningful while the controller is idle.
- `memory_interface_dataflow` is treated as the existing convolution engine.
- The convolution engine accepts `start` and returns `done` plus a stable signed INT32 `result`.
- The convolution engine already contains the BRAM/MAC/accumulation micro-sequencer for one 3x3 convolution.
- The convolution engine's `done` is a one-clock pulse.
- `relu_activation` is combinational and has zero architectural clock-cycle latency.
- The final INT8 activation is stored in a register controlled by the new FSM.
- Exact whole-system cycle latency is intentionally deferred to `/analyze control_fsm`.

## 3. Existing Architecture and Why Hierarchical Control Is Chosen

The current `memory_interface_dataflow` RTL already contains the local states:

- `ST_IDLE`
- `ST_WAIT0`
- `ST_WORD0`
- `ST_WORD1`
- `ST_WORD2`

That internal sequencer already performs the fixed-latency BRAM scheduling, partial-sum accumulation, and result generation for one convolution.

Therefore the new B9 controller must not create another BRAM-address FSM in parallel with it. Two separate controllers trying to own the same memory or accumulation signals would duplicate responsibility and create ambiguous control ownership.

The selected structure is hierarchical:

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
|                          |
| local BRAM/MAC FSM       |
| + four-lane arithmetic   |
| + INT32 accumulation     |
+--------------------------+
     | engine_result[31:0]
     | engine_done
     v
+------------------+
| relu_activation  |
| combinational    |
+------------------+
     | relu_output[7:0]
     v
 output register
     |
     v
 final INT8 activation
```

This gives two control levels:

1. **Local engine control** — already inside `memory_interface_dataflow`; handles BRAM wait and word-by-word MAC/accumulation scheduling.
2. **Supervisory control** — the new `control_fsm`; handles transaction launch, completion, activation capture, `busy`, and `done`.

The `MEM_WAIT` concept taught earlier still exists physically in the architecture; it is implemented inside the local convolution-engine FSM as `ST_WAIT0`. It should not be duplicated in the supervisory FSM.

## 4. Proposed Control FSM Interface

### Inputs

- `clk` — system clock.
- `rst` — synchronous active-high reset.
- `start` — one-cycle request to process one convolution transaction.
- `engine_done` — one-cycle completion pulse from `memory_interface_dataflow`.

### Outputs

- `engine_start` — one-cycle pulse that launches the convolution engine.
- `capture_activation` — one-cycle control pulse used by surrounding integration logic to register the ReLU output.
- `busy` — high while the transaction is in progress.
- `done` — one-cycle pulse indicating that the registered INT8 activation is valid.

### Data-path signals that do not pass through the FSM

The FSM should not manipulate arithmetic data. The following travel through the datapath/integration logic instead:

- `engine_result[31:0]` from the convolution engine,
- `relu_output[7:0]` from `relu_activation`,
- the registered final activation output.

This keeps the FSM control-only.

## 5. State Set

The selected supervisory FSM contains five conceptual states.

### `IDLE`

Purpose:

- wait for an external transaction request,
- report not busy,
- do not launch the engine,
- do not assert completion.

Transition:

- `start = 0` -> remain in `IDLE`.
- `start = 1` -> go to `LAUNCH`.

### `LAUNCH`

Purpose:

- assert `engine_start` for exactly one clock interval,
- report `busy = 1`.

Transition:

- unconditionally -> `WAIT_ENGINE`.

Why a separate launch state is used:

The engine expects `start` as a request event. A dedicated state makes the pulse duration explicit and prevents `engine_start` from remaining high throughout the calculation.

### `WAIT_ENGINE`

Purpose:

- keep `busy = 1`,
- wait for the internal convolution engine to finish.

Transition:

- `engine_done = 0` -> remain in `WAIT_ENGINE`.
- `engine_done = 1` -> go to `CAPTURE_ACTIVATION`.

The local BRAM wait, word sequencing, MAC execution, and accumulation all occur inside the convolution engine while the supervisory FSM stays in this state.

### `CAPTURE_ACTIVATION`

Purpose:

- keep `busy = 1`,
- assert `capture_activation = 1` so the surrounding output register stores the combinational ReLU result.

Transition:

- unconditionally -> `DONE`.

Why this state exists:

`relu_activation` is combinational. After the completed INT32 engine result is stable, the ReLU result is available after propagation delay. The explicit capture state creates a clean synchronous boundary for the final INT8 output.

### `DONE`

Purpose:

- assert `done = 1` for one clock interval,
- report `busy = 0`,
- indicate that the registered INT8 output is valid.

Transition:

- unconditionally -> `IDLE`.

## 6. State Transition Diagram

```text
                         start=1
              +--------------------------+
              |                          v
          +-------+                  +--------+
          | IDLE  |                  | LAUNCH |
          +---+---+                  +---+----+
              ^                          |
              |                          | unconditional
              |                          v
              |                     +-------------+
              |                     | WAIT_ENGINE |
              |                     +------+------+ 
              |                            |
              |           engine_done=0   |   engine_done=1
              |              +-------------+----------+
              |              |                        v
              |              |               +--------------------+
              |              +-------------->| CAPTURE_ACTIVATION |
              |                              +---------+----------+
              |                                        |
              |                                        | unconditional
              |                                        v
              |                                    +--------+
              +------------------------------------|  DONE  |
                                                   +--------+
```

## 7. Moore-Style Output Definition

The controller is designed so outputs depend primarily on the current state.

| State | `engine_start` | `capture_activation` | `busy` | `done` |
|---|---:|---:|---:|---:|
| `IDLE` | 0 | 0 | 0 | 0 |
| `LAUNCH` | 1 | 0 | 1 | 0 |
| `WAIT_ENGINE` | 0 | 0 | 1 | 0 |
| `CAPTURE_ACTIVATION` | 0 | 1 | 1 | 0 |
| `DONE` | 0 | 0 | 0 | 1 |

This style makes waveform inspection straightforward because each control output has an obvious state association.

## 8. Handshake Semantics

### External `start`

The first version assumes `start` is a one-cycle pulse.

The controller samples it only in `IDLE`. Requests arriving while `busy = 1` are ignored.

This is intentional for the first architecture. If the final Basys 3 interface uses a push button, a separate synchronizer/debouncer/one-shot circuit should convert the physical button input into this one-cycle `start` event.

### Internal `engine_start`

`engine_start` is asserted only in `LAUNCH`.

This guarantees one launch event per accepted external request.

### `engine_done`

The controller does not assume the exact internal engine cycle count. It waits until `engine_done` is observed.

This decouples the supervisory controller from the internal BRAM/MAC schedule. If the convolution engine is later optimized, the outer controller does not need to be redesigned as long as the `start`/`done` contract remains unchanged.

### External `done`

`done` is asserted only in the `DONE` state, making it a one-cycle pulse.

The final INT8 activation has already been captured before this pulse is presented.

## 9. Reset Behavior

On synchronous reset:

- state returns to `IDLE`,
- `engine_start = 0`,
- `capture_activation = 0`,
- `busy = 0`,
- `done = 0`.

The surrounding final-output register must also reset to a known value in the integration module.

Reset must never launch the convolution engine.

## 10. Why the FSM Does Not Contain a MAC Counter

The teaching example discussed using a counter instead of creating many nearly identical states.

For this supervisory controller, no MAC-iteration counter is required because the existing convolution engine already owns the three-word schedule internally. The new FSM sees the convolution engine as a single transaction:

```text
launch engine -> wait -> engine done
```

If the architecture is later refactored so the controller directly owns BRAM/MAC iterations, then an operation or word counter would become appropriate. It is deliberately not duplicated here.

## 11. Control Invariants

The following properties must remain true in the implementation:

1. `engine_start` is never high outside `LAUNCH`.
2. `capture_activation` is never high before `engine_done` has been observed.
3. `done` is never high before the final activation has been captured.
4. `busy` is high throughout launch, engine execution, and activation capture.
5. Only one engine launch occurs for one accepted external `start` pulse.
6. A reset returns the controller to an idle, non-launching condition.
7. The controller never directly performs arithmetic or controls internal BRAM addresses.

These become verification targets later.

## 12. Architectural Rationale

The main design decision is **hierarchical control rather than duplicated control**.

The existing convolution block is already a self-contained transaction engine with a `start`/`done` interface. The supervisory FSM therefore controls that interface rather than reaching inside the engine and reimplementing its local sequencing.

Advantages:

- one clear owner for BRAM/MAC sequencing,
- simpler top-level control,
- easier waveform interpretation,
- less coupling between controller and internal datapath timing,
- easier future optimization of the convolution engine,
- preserves the already-verified local memory/dataflow behavior.

## 13. What Is Deferred to `/analyze control_fsm`

The DESIGN step intentionally does not claim final performance numbers.

The next `/analyze control_fsm` step must derive from first principles:

- minimum state-register width,
- supervisory state-cycle overhead,
- total transaction latency when combined with the existing engine,
- latency contribution of final activation capture,
- expected flip-flop/LUT/control resource cost,
- expected switching behavior of `busy`, `done`, and pulse outputs,
- whether the 100 MHz target creates any meaningful timing concern for the control path.

No RTL or simulation is permitted before that prediction step is complete.
