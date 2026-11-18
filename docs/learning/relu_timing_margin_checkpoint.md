# ReLU Timing Margin — Teaching Checkpoint

## Active Phase
Phase 4 — Activation and Output Processing

## Concept Confirmed
The user identified the **+0.196 ns hold slack** as the bigger timing concern compared with the **+6.213 ns setup slack**, because the hold margin is much smaller.

## Important distinction
Both values are positive, so both setup and hold timing currently meet the implemented 100 MHz constraint. However, the smaller hold margin provides less tolerance to implementation changes that could alter minimum-delay behavior, such as routing or placement changes.

## Measured values
- Worst setup slack (WNS): +6.213 ns
- Worst hold slack (WHS): +0.196 ns
- Clock period: 10 ns at 100 MHz
- Worst setup data-path delay: 3.750 ns
- Worst hold data-path delay: 0.288 ns

## Interpretation
Setup and hold are different checks:
- Setup asks whether data arrives early enough for the next capture edge.
- Hold asks whether newly launched data avoids changing the destination too soon after the capture edge.

A positive hold slack of only +0.196 ns means the minimum-delay path is close to the hold boundary even though it currently passes.

## Assumptions
- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- Timing values are from the implemented ReLU timing wrapper.
- No claim is made here that +0.196 ns is a functional failure; it is a small positive margin.

## Next learning checkpoint
The next step is to understand how implementation changes can affect setup and hold differently, and why a design with positive timing slack can still deserve optimization attention.


---

## Project completion status update — 2026-11-18

**Project lifecycle status: COMPLETED (owner-confirmed).** The project owner confirms all phases are complete, the bitstream was programmed onto the physical Basys 3 FPGA, and expected output was observed. This supersedes earlier active-phase, pending, and pre-board-test status wording; original learning content and historical checkpoints remain preserved.

**Evidence boundary:** the owner supplied a Basys 3 board photograph in the project conversation. It documents the physical setup and illuminated indicators but does not independently establish exact latency, power, resource counts, or post-route timing. The historical docs/analysis/basys3_top_level.md report records WNS = -3.453 ns at the 100 MHz constraint; no newer timing report was supplied. Do not reinterpret the historical STA result as a pass without updated Vivado evidence.

The documented fixed demonstration vector produces accumulator 45 and requantized INT8 output 34 (0x22); LED1 and LED5 are result bits and LED8 is the latched completion indicator. The owner reports that the expected board output was observed.
