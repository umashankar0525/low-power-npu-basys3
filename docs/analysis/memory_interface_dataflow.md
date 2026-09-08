# Memory Interface and Dataflow — Performance Analysis

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Performance Analyst  
**Status:** Prediction; corrected RTL-level timing interpretation; no simulation measurements yet.

## 1. Scope

This analysis predicts latency, bandwidth, throughput, and resource usage for the selected memory/dataflow architecture and records the corrected timing interpretation needed for verification.

## 2. Assumptions

- FPGA: XC7A35T-1CPG236C-1.
- Clock: 100 MHz, so one clock period is 10 ns.
- Synchronous BRAM read latency: 1 clock cycle.
- Activation memory: one 32-bit word per address.
- Weight memory: one 32-bit word per address.
- Activation and weight memories operate independently and are read in parallel.
- Four INT8 x INT8 MAC lanes are active for every fetched word.
- Each 4-product group is reduced to an 18-bit signed partial sum.
- The partial sum is sign-extended to INT32 before accumulation.
- The running accumulator is INT32.
- The current RTL uses a registered accumulator and a registered result.
- `done` is asserted for one clock in the final processing state.

## 3. Work Per Convolution

A 3x3, single-channel convolution contains:

`3 x 3 x 1 = 9` INT8 multiplications.

With four MAC lanes:

- Word 0: P0, P1, P2, P3
- Word 1: P4, P5, P6, P7
- Word 2: P8, 0, 0, 0

Therefore three memory words are required. The zero-filled final word keeps the datapath uniform.

## 4. BRAM Bandwidth Derivation

Each memory access returns:

`32 / 8 = 4` INT8 values.

With independent activation and weight memories, one request pair supplies:

`4 + 4 = 8` INT8 operands per request cycle.

For one convolution, useful payload is 72 bits per memory:

`9 x 8 = 72 bits`.

Three physical 32-bit words require:

`3 x 32 = 96 bits` per memory.

Therefore packing efficiency is:

`72 / 96 = 75%`.

The final word contains one useful lane and three padding lanes.

## 5. Corrected Synchronous-BRAM Timing

The critical distinction is between **requesting** a BRAM address and **using** the returned data. A synchronous BRAM does not make the newly requested data available to the controller in the same sequential edge.

For the current RTL's registered accumulator:

| Edge | Controller action | Data available for computation after edge |
|---|---|---|
| 1 | Accept `start`; request word 0 | No newly requested word yet |
| 2 | Request word 1 | Word 0 |
| 3 | Capture result of word 0; request word 2 | Word 1 |
| 4 | Capture result of word 1 | Word 2 |
| 5 | Capture final result from word 2; assert `done` | Final result |

Thus there are **five active clock edges including the start edge**, but only **four clock periods elapse from the start sampling edge to the done sampling edge**.

At 100 MHz:

`4 periods x 10 ns = 40 ns`

So the correct current-RTL prediction is:

**start edge → done edge = 40 ns**.

The previous 30 ns estimate incorrectly treated the BRAM response as consumable at the same edge at which the response becomes registered. That timing assumption is not valid for the current synchronous-memory interface.

## 6. Running Accumulator

The controller computes:

`ACC0 = 0`

`ACC1 = ACC0 + S0`

`ACC2 = ACC1 + S1`

`ACC3 = ACC2 + S2`

Therefore:

`ACC3 = S0 + S1 + S2`.

The running accumulator avoids storing three partial sums and then performing a separate final accumulation structure. It does not inherently reduce clock latency; it mainly simplifies hardware and control. The 32-bit accumulator adder remains a likely timing-critical path.

## 7. Arithmetic Width Derivation

Maximum positive INT8 product:

`(-128) x (-128) = 16384`.

Four products:

`4 x 16384 = 65536`.

An 18-bit signed value ranges from `-131072` to `+131071`, so 18 bits are sufficient for one four-product partial sum.

Nine products can reach:

`9 x 16384 = 147456`,

which exceeds signed 18-bit positive range. Therefore the final accumulator is INT32.

## 8. Resource Prediction

### BRAM

Prediction: two independent memories, one activation memory and one weight memory. Whether Vivado implements these small memories as BRAM or LUT RAM must be measured after synthesis.

### Multipliers

There are four parallel INT8 multipliers. Prior project synthesis mapped the existing 4-MAC arithmetic into LUT/carry resources rather than DSP48 slices, so the current project prediction is 0 DSP48 slices unless synthesis settings or RTL changes alter inference.

### Registers

At minimum, the current architecture contains state for the 32-bit accumulator, 32-bit result, FSM, and addresses/handshake signals. Exact FF usage must be measured.

## 9. Throughput Prediction

Three packed words are needed per convolution. Ignoring startup and completion overhead, the idealized steady-state work rate is:

`1 convolution / 3 processing cycles`.

At 100 MHz:

`100,000,000 / 3 = 33,333,333.33 convolutions/s`.

This is a theoretical steady-state bound, not the standalone latency of one convolution.

## 10. Critical-Path Prediction

Likely critical paths are:

1. 32-bit signed accumulator addition.
2. Four INT8 multipliers if implemented in LUT/carry fabric.
3. Partial-sum reduction.
4. Control/address logic.

Timing reports must determine which path actually limits Fmax.

## 11. Prediction Summary

| Metric | Prediction |
|---|---:|
| Clock | 100 MHz |
| Clock period | 10 ns |
| Convolution products | 9 |
| Packed words / convolution | 3 |
| MAC lanes | 4 |
| Activation memory width | 32 bits |
| Weight memory width | 32 bits |
| Parallel operand bandwidth | 64 bits/request cycle |
| Packing efficiency | 75% |
| Partial sum width | 18 bits |
| Final accumulator width | 32 bits |
| BRAM prediction | 2 memories; implementation to be measured |
| DSP prediction | 0 based on prior project synthesis behavior |
| Steady-state convolution throughput | 1 / 3 processing cycles |
| Ideal throughput @100 MHz | ~33.33 Mconv/s |
| Start edge → done edge | 40 ns predicted for current RTL |
| Active edges including start and done | 5 |

## 12. Verification Targets

Simulation must measure and compare:

- address sequence `0 → 1 → 2`,
- one-cycle BRAM response latency,
- which data word is consumed in each processing state,
- accumulator values after S0 and S1,
- final result after S2,
- exact `start` to `done` edge count,
- rejection/handling of `start` while busy,
- reset behavior.

No measured values are claimed until XSim simulation is run.
