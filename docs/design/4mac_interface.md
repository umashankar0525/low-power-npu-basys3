# 4-MAC Datapath — RTL Interface Derivation

## Role
Design Engineer.

## Active Phase
Phase 2 — 4-MAC Compute Datapath + Scheduling.

## Purpose
Define the external interface and cycle-level register behavior before Verilog RTL generation.

## Assumptions

- Verilog-2001, not SystemVerilog.
- Signed two's-complement INT8 activation and weight inputs.
- 100 MHz target clock; 10 ns period.
- One 3x3, single-channel convolution produces nine products.
- Four multiplication lanes are available.
- Selected initial schedule is the lower-risk 4-cycle architecture.
- No input/output BRAM interface is included yet; this module is a compute datapath, not the full NPU.

## Proposed Interface

Inputs:
- `clk`: clock.
- `rst`: synchronous reset for datapath state.
- `start`: starts a new 3x3 operation when the datapath is idle.
- `valid_in`: indicates the current activation/weight group is valid.
- Four signed INT8 activation inputs: `act0..act3`.
- Four signed INT8 weight inputs: `wgt0..wgt3`.
- `act8`: signed INT8 activation for the ninth product.
- `wgt8`: signed INT8 weight for the ninth product.

Outputs:
- `result`: signed INT32 final convolution result.
- `done`: one-cycle indication that `result` is valid.
- `busy`: indicates the datapath is processing a convolution.

The exact input handshaking can later be adapted when the BRAM/address-generation interface is designed. The key point is that the datapath must receive four product pairs for cycles 1 and 2 and the ninth pair for cycle 3.

## Internal Register Plan

At minimum, the selected architecture requires state for:

- `S0`: INT18 partial sum from P0..P3.
- `S1`: INT18 partial sum from P4..P7.
- `T`: INT18 sum of S0 and S1.
- `P8`: INT16 ninth product.
- `ACC`: INT32 final accumulator/result state as required by the chosen implementation.
- Control state for the four-cycle schedule.

Intermediate products need not all be stored if the multiplier outputs feed the reduction tree directly within a cycle.

## Cycle Contract

Cycle 1:
- Compute P0..P3 from four signed INT8 pairs.
- Reduce them through a balanced tree.
- Register S0 as INT18.

Cycle 2:
- Compute P4..P7.
- Reduce them through the balanced tree.
- Register S1 as INT18.

Cycle 3:
- Compute P8 as INT16.
- In parallel, compute T = S0 + S1.
- Register T as INT18 and P8 as INT16.

Cycle 4:
- Sign-extend P8 to INT18/INT32 as required by the addition implementation.
- Compute T + P8.
- Register the final INT32 result.
- Assert `done` for one cycle.

## Width Rules

- Product: signed INT16.
- Pairwise sums: signed INT17.
- Four-product sums S0/S1: signed INT18.
- T: signed INT19 if mathematically treated as the sum of two full four-product partial sums, or INT18 only if the implementation proves the actual range is bounded accordingly. This width must be resolved before RTL generation.
- Final convolution accumulator/result: signed INT32.

## Critical Design Issue to Resolve Before RTL

The earlier analysis treated `T = S0 + S1` as INT18. That is not sufficient for the mathematical maximum because S0 and S1 can each reach 65536, giving 131072. Signed INT18 maximum is 131071. Therefore the correct width for T is INT19.

This correction must be reflected in the final RTL and verification plan.

## RTL Gate

No RTL should be generated until the user confirms understanding of the corrected T width and the four-cycle register schedule.
