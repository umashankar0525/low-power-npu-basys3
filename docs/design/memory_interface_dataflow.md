# Memory Interface and Dataflow — Design

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Design Engineer

## Design Goal

Feed the four MAC units with four activation/weight pairs per computation cycle while keeping the memory interface regular and easy to verify.

## Assumptions

- FPGA: XC7A35T-1CPG236C-1
- Clock: 100 MHz, therefore one clock period is 10 ns
- Signed INT8 activations and weights
- INT16 products
- Four MAC units
- 3x3 kernel, one input channel, one output channel
- Separate activation and weight memories
- 32-bit word width for each memory
- Synchronous BRAM read latency: 1 cycle
- Final accumulation: INT32

## Selected Architecture

Use two independent 32-bit memories:

1. Activation BRAM — supplies four packed INT8 activations.
2. Weight BRAM — supplies four packed INT8 weights.

Because the memories are separate, both 32-bit words can be accessed in parallel, giving 64 bits of operand data per memory-access cycle.

## Memory Layout

Activation BRAM:

- Address 0: A0 A1 A2 A3
- Address 1: A4 A5 A6 A7
- Address 2: A8 0 0 0

Weight BRAM:

- Address 0: W0 W1 W2 W3
- Address 1: W4 W5 W6 W7
- Address 2: W8 0 0 0

The zero-filled lanes in address 2 preserve a uniform four-lane datapath and avoid a special one-MAC hardware/control case.

## Datapath

For each fetched word, the lanes form:

- MAC0: A_lane0 * W_lane0
- MAC1: A_lane1 * W_lane1
- MAC2: A_lane2 * W_lane2
- MAC3: A_lane3 * W_lane3

The four products are reduced to an 18-bit partial sum. The partial sum is sign-extended to 32 bits before entering the final accumulation path.

The three partial sums are:

`S0 = P0 + P1 + P2 + P3`

`S1 = P4 + P5 + P6 + P7`

`S2 = P8`

Final result:

`Result = S0 + S1 + S2`

## Proposed Control/Data Interface

### External/control signals

- `clk`
- `reset`
- `start`
- `done`
- `result[31:0]`

### Activation memory interface

- activation read enable
- activation address
- activation data `[31:0]`

### Weight memory interface

- weight read enable
- weight address
- weight data `[31:0]`

The exact signal naming and registered boundaries will be finalized before RTL generation.

## Preliminary Cycle Schedule

With one-cycle synchronous BRAM latency:

| Cycle | Activation/weight memory | Compute |
|---|---|---|
| 1 | Request address 0 in both memories | Waiting for data |
| 2 | Request address 1 | Use Word 0 in four MAC lanes |
| 3 | Request address 2 | Use Word 1 |
| 4 | No further request | Use Word 2 |
| 5 | No request | Final accumulation available under the simplified one-cycle-stage model |

This schedule overlaps the next memory request with current computation.

## Architectural Principle

The FSM should control memory addresses and sequencing, while the datapath performs arithmetic. Separating control from datapath makes timing, verification, and future changes easier to reason about.

## Bandwidth Derivation

Each activation word supplies:

`4 * 8 = 32 bits`

Each weight word supplies:

`4 * 8 = 32 bits`

Parallel supply therefore provides:

`32 + 32 = 64 bits`

or eight INT8 operand values per memory-access cycle.

## Next Design Task

Before RTL generation, derive the exact FSM states and registered timing for BRAM request, BRAM response capture, MAC enable, partial-sum reduction, accumulator update, and `done` generation. The analysis phase must predict latency and resource behavior before simulation.
