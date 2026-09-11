# ReLU Timing Concept Checkpoint

## Role
Teaching Assistant

## Active Phase
Phase 4 — Activation and Output Processing

## Concept Confirmed
The user correctly identified that the implemented timing path must include routing delay, not only the ReLU logic delay.

## Key distinction
For the 100 MHz clock:

\[
T_{clk}=\frac{1}{100\,MHz}=10\,ns
\]

The setup-path budget is governed by:

\[
T_{clk} \ge T_{clk\to Q}+T_{logic}+T_{routing}+T_{setup}
\]

The measured worst setup data path was 3.750 ns:

- Logic delay = 0.828 ns
- Routing delay = 2.922 ns
- Total data-path delay = 3.750 ns

Therefore, the small ReLU logic does not imply that the implemented path has negligible delay. Physical placement and routing contribute significantly to the total delay. In this implementation, routing accounts for:

\[
\frac{2.922}{3.750}\times100 \approx 77.9\%
\]

of the reported worst setup data-path delay.

## Architectural latency vs timing delay
Registers create the one-cycle architectural latency. The combinational ReLU logic and routing consume part of that cycle's 10 ns timing budget. Setup and hold checks determine whether the implementation can reliably operate at the target clock frequency.

## Assumptions
- Clock frequency: 100 MHz
- Clock period: 10 ns
- Target device: XC7A35T-1CPG236C-1
- Timing values are from the user's Vivado 2018.2 implementation timing report.

## Next checkpoint
Before moving to final design review, the user should be able to distinguish:
1. architectural latency,
2. combinational/data-path delay,
3. routing delay,
4. setup slack, and
5. hold slack.
