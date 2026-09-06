# Memory Interface and Dataflow — Learning

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Teaching Assistant

## Assumptions

- FPGA: XC7A35T-1CPG236C-1 (Basys 3 target)
- Clock: 100 MHz
- Activation and weight precision: signed INT8
- Product precision: signed INT16
- Four MAC units
- 3x3 kernel, one input channel, one output channel
- Separate activation and weight BRAMs
- 32-bit memory word
- Synchronous BRAM read latency: 1 cycle
- MAC/partial-sum stage assumed to take 1 cycle for the timing exercises below

## Core Concepts

### BRAM port vs. memory word

One BRAM port performs one addressed memory-word access per cycle. The word width determines how many packed INT8 values can be delivered by that access. A 32-bit word contains four INT8 values:

`32 / 8 = 4`

Therefore, it is incorrect to think of one BRAM port as supplying only one INT8 value.

### Separate activation and weight memories

A single 32-bit word cannot contain four activations and four weights because that requires 64 bits:

`4*8 + 4*8 = 64 bits`

Separate 32-bit activation and weight BRAMs can be read in parallel, supplying four activation values and four weight values to the four MACs.

### BRAM read latency

With one-cycle synchronous read latency, if Word 0 is requested in Cycle 1, it becomes available to the MACs in Cycle 2. If Word 1 is requested in Cycle 2, it becomes available in Cycle 3.

### Memory/computation overlap

The BRAM can request the next word while the MACs use the current word. For example:

- Cycle 1: request Word 0
- Cycle 2: use Word 0 and request Word 1
- Cycle 3: use Word 1 and request Word 2
- Cycle 4: use Word 2

This overlap improves throughput by avoiding unnecessary idle cycles.

### Latency vs. throughput

Latency is the number of cycles from an accepted request/input until its corresponding output is available. Throughput is how frequently new work can be accepted or processed once the pipeline is operating.

A pipeline can have several cycles of latency while still processing a new word every cycle after startup.

## Data Packing

Activation BRAM:

- Word 0: A0 A1 A2 A3
- Word 1: A4 A5 A6 A7
- Word 2: A8 0 0 0

Weight BRAM:

- Word 0: W0 W1 W2 W3
- Word 1: W4 W5 W6 W7
- Word 2: W8 0 0 0

Zero padding in Word 2 keeps the four MAC lanes uniform. The final word computes `A8*W8` because the other three products are zero.

## Arithmetic Dataflow

Each word produces four products in the four MAC lanes. The products are reduced into a partial sum:

`S0 = P0 + P1 + P2 + P3`

`S1 = P4 + P5 + P6 + P7`

`S2 = P8`

The final result is:

`Result = S0 + S1 + S2`

A four-product partial sum may reach:

`4 * 16384 = 65536`

A signed 17-bit value only reaches +65535, so at least 18 bits are required for the partial sum. The final 9-product result can reach:

`9 * 16384 = 147456`

which exceeds the +131071 maximum of signed 18-bit arithmetic, so the project uses an INT32 accumulator.

Negative partial sums and products must be sign-extended when moved to a wider signed representation. Sign extension preserves the numerical value by copying the sign bit into the newly added upper bits.

## Preliminary Pipeline Timing

Under the stated one-cycle BRAM latency and one-cycle MAC/partial-sum assumption:

| Cycle | BRAM request/data | MAC/accumulation activity |
|---|---|---|
| 1 | Request Word 0 | — |
| 2 | Word 0 available; request Word 1 | Compute Word 0 |
| 3 | Word 1 available; request Word 2 | Compute Word 1 / S0 available |
| 4 | Word 2 available | Compute Word 2 / S1 available |
| 5 | — | S2 and final accumulation available, under the simplified timing model |

The exact RTL timing must be derived from the final datapath and registered interfaces before code generation.

## Design Lesson

The four MACs are useful only if the memory system can supply four activation/weight pairs. If memory supplies fewer pairs, some MAC lanes remain idle. Therefore, memory organization and bandwidth are part of compute architecture, not an afterthought.

## Next Step

Move to the Design phase and derive the exact BRAM interface, address generation, register boundaries, accumulator timing, and FSM behavior before generating Verilog RTL.
