# ReLU Register Timing Checkpoint

## Role
Teaching Assistant

## Active Phase
Phase 4 — Activation and Output Processing

## Concept
The ReLU logic itself is combinational and does not require a clock. Registers were added around it in the timing wrapper to create a measurable synchronous register-to-register timing path.

The intended path is:

`accumulator_reg -> relu_activation -> output_activation_reg`

At a rising edge, the accumulator register launches the completed INT32 value. During the following clock period, the combinational ReLU+saturation logic and its routing delay must settle. At the next rising edge, the output register captures the result.

## Key distinction
- Registers create the **one-cycle architectural latency**.
- Combinational logic and routing create **propagation delay within that cycle**.
- Setup and hold checks determine whether the timing relationship is safe.

For the implemented wrapper, the measured worst setup data path was 3.750 ns and the measured worst hold data path was 0.288 ns. These are implementation timing measurements, not architectural latency.

## Assumptions
- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- ReLU module remains combinational.
- The wrapper registers represent the completed accumulator and output activation.
- Target device: XC7A35T-1CPG236C-1.

## Learning checkpoint
The user correctly identified that the registers allow the combinational circuit's propagation delay to be evaluated between clock edges through a register-to-register timing path.

## Next focus
Proceed to design-review interpretation of the ReLU timing implementation, including why setup has a large positive margin while hold has a much smaller positive margin.


---

## Project completion status update — 2026-11-18

**Project lifecycle status: COMPLETED (owner-confirmed).** The project owner confirms all phases are complete, the bitstream was programmed onto the physical Basys 3 FPGA, and expected output was observed. This supersedes earlier active-phase, pending, and pre-board-test status wording; original learning content and historical checkpoints remain preserved.

**Evidence boundary:** the owner supplied a Basys 3 board photograph in the project conversation. It documents the physical setup and illuminated indicators but does not independently establish exact latency, power, resource counts, or post-route timing. The historical docs/analysis/basys3_top_level.md report records WNS = -3.453 ns at the 100 MHz constraint; no newer timing report was supplied. Do not reinterpret the historical STA result as a pass without updated Vivado evidence.

The documented fixed demonstration vector produces accumulator 45 and requantized INT8 output 34 (0x22); LED1 and LED5 are result bits and LED8 is the latched completion indicator. The owner reports that the expected board output was observed.
