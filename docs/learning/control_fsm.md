# Control FSM — Teaching Notes

**Role:** Teaching Assistant  
**Active Phase:** Phase 1 — Arithmetic Foundations and MAC Design  
**Module:** Control FSM  
**Workflow stage:** TEACH

## Assumptions

- Target FPGA: Basys 3 / XC7A35T-1CPG236C.
- Clock frequency: 100 MHz.
- Datapath arithmetic: INT8 activations and weights, INT16 products, INT32 accumulation.
- Compute organization: four MAC units.
- Activation: ReLU.
- Memory: FPGA BRAM or an interface with synchronous-memory-like latency.
- Earlier modules already provide the arithmetic and data-movement capability; the Control FSM coordinates when those modules act.

## 1. Purpose of the Control FSM

An FSM, or Finite State Machine, is a sequential control circuit that remembers which stage of an operation the hardware is currently performing.

The datapath blocks know **how** to perform their individual jobs:

- Memory supplies operands.
- MAC units multiply and accumulate.
- The accumulator stores the running INT32 sum.
- ReLU applies the activation function to the finished result.

Those blocks do not automatically know **when** they should act relative to one another. The Control FSM provides that sequencing.

Conceptually:

```text
                 CONTROL FSM
                     |
        +------------+-------------+
        |            |             |
        v            v             v
      Memory      MAC units    Accumulator
                                    |
                                    v
                                   ReLU
                                    |
                                    v
                                  Output
```

The FSM therefore generates control actions such as memory requests, MAC enables, accumulator clear/enable control, activation control, busy status, and done status. The exact signal names are intentionally deferred until the DESIGN step.

## 2. Why sequencing is necessary

If all datapath blocks were enabled immediately after reset or start, the design could use operands before memory has returned valid data, accumulate invalid values, or apply ReLU before the final convolution sum is complete.

The intended high-level sequence is:

```text
START
  |
  v
prepare hardware
  |
  v
request operands
  |
  v
wait for memory
  |
  v
perform MAC work
  |
  v
accumulate
  |
  v
repeat until complete
  |
  v
final accumulation ready
  |
  v
ReLU
  |
  v
output valid
  |
  v
DONE
```

The FSM exists to guarantee this order cycle by cycle.

## 3. Current state, inputs, and next state

The fundamental FSM relationship is:

```text
Current State
      |
      +---- Inputs / conditions
      v
Next State
```

For example, if the controller is in a conceptual `WAIT_MEMORY` state:

```text
WAIT_MEMORY
    |
    | data_valid = 1
    v
COMPUTE
```

If the data is not ready, the controller remains in `WAIT_MEMORY`.

At each active clock edge, the state register advances from the current state to the computed next state.

## 4. First conceptual state set

A useful first conceptual state set for this NPU is:

| State | Purpose |
|---|---|
| `IDLE` | Wait for a new operation |
| `INIT` | Clear counters and initialize accumulation/control state |
| `MEM_REQ` | Present/request the required operand access |
| `MEM_WAIT` | Wait for the requested memory data to become usable |
| `MAC_EXEC` | Perform the current MAC operation or MAC group |
| `CHECK` | Determine whether additional MAC work remains |
| `ACTIVATE` | Apply ReLU to the final accumulated result |
| `DONE` | Indicate that the output is valid and the operation has completed |

This is not yet the final architecture. The final state set is derived in the DESIGN step from the actual interfaces and timing contracts of the implemented modules.

Conceptually:

```text
                   start
                     |
                     v
             +---------------+
             |     IDLE      |
             +-------+-------+
                     |
                     v
             +---------------+
             |     INIT      |
             +-------+-------+
                     |
                     v
             +---------------+
             |    MEM_REQ    |
             +-------+-------+
                     |
                     v
             +---------------+
             |   MEM_WAIT    |
             +-------+-------+
                     | data ready
                     v
             +---------------+
             |   MAC_EXEC    |
             +-------+-------+
                     |
                     v
             +---------------+
             |     CHECK     |
             +---+-------+---+
                 |       |
          more   |       | finished
          work   |       v
                 |   +-----------+
                 |   | ACTIVATE  |
                 |   +-----+-----+
                 |         |
                 |         v
                 |   +-----------+
                 |   |   DONE    |
                 |   +-----+-----+
                 |         |
                 +---------+-----> IDLE
                   ^
                   |
                   +---- MEM_REQ
```

## 5. Why `MEM_REQ` and `MEM_WAIT` may be separate states

Synchronous FPGA memory does not necessarily behave as `address -> data instantly`.

A typical timing model is:

```text
Cycle N:
controller presents/request address

Cycle N+1:
requested data becomes usable
```

If the controller assumes zero latency, the MAC datapath may consume the previous data word instead of the word associated with the new address.

Therefore the controller must explicitly understand the memory-latency contract. A dedicated wait state is one clean way to encode that behavior.

## 6. State versus counter

An FSM state describes **what the machine is doing**.

A counter describes **which iteration or how many repetitions have occurred**.

If the accelerator must perform multiple similar MAC groups, it is usually undesirable to create one state per iteration:

```text
MAC_0
MAC_1
MAC_2
MAC_3
...
```

A cleaner structure is:

```text
state = MAC_EXEC
operation_count = 0, 1, 2, ...
```

This keeps the controller compact and separates control mode from loop progress.

## 7. Moore-style versus Mealy-style control

A Moore-style FSM derives outputs mainly from the current state. Example:

```text
state = MAC_EXEC
        |
        v
mac_enable = 1
```

A Mealy-style FSM may derive outputs from both the current state and current inputs.

For this project, a Moore-style controller is preferred where practical because control signals are easier to reason about, observe in Vivado waveforms, and verify state by state. Input conditions still determine state transitions.

## 8. Reset behavior

Reset must put the controller into a known safe state, normally `IDLE`.

Conceptually after reset:

```text
busy = 0
done = 0
MAC disabled
memory request disabled
accumulator control returned to a known safe condition
```

The controller must not accidentally begin computation immediately after reset.

## 9. `start`, `busy`, and `done`

A simple top-level transaction handshake is:

```text
start ---> NPU

          NPU processing

busy  ---> 1 while operation is active

done  ---> 1 when the result is complete/valid
```

Conceptually:

```text
IDLE
 |
 | start = 1
 v
PROCESSING / BUSY
 |
 | computation complete
 v
DONE
 |
 v
IDLE
```

The exact pulse/level semantics of `start`, `busy`, and `done` will be defined during DESIGN and verified later.

## 10. Control path versus datapath

The most important architectural distinction is:

```text
              NPU
        +-------------+
        |             |
     CONTROL       DATAPATH
        |             |
       FSM          Memory
                    MACs
                 Accumulator
                    ReLU
```

The datapath answers:

> What computation happens?

The FSM answers:

> When does each computation happen?

The Control FSM does not perform convolution arithmetic itself. It coordinates the blocks that perform the arithmetic.

## Teaching hard gate

Before moving to `/design control_fsm`, the user must explain the following in their own words:

1. What is the purpose of the Control FSM in this NPU?
2. Why might a `MEM_WAIT` state be needed after providing a memory address?
3. What is the difference between an FSM state and an operation counter?

No RTL is generated until this understanding check is completed.
