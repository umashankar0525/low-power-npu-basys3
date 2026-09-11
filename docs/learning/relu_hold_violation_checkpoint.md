# ReLU Timing — Hold Violation Checkpoint

## Role
Teaching Assistant

## Active Phase
Phase 4 — Activation and Output Processing

## Concept
A hold violation occurs when the receiving register's input data changes too soon after the active clock edge. To improve hold margin, the minimum-delay data path generally needs to be increased.

For the ReLU timing wrapper, the measured worst hold slack is +0.196 ns, so the current implementation passes hold timing but has a relatively small margin.

If implementation changes caused the slack to become negative, for example -0.050 ns, that would indicate a hold timing violation.

## Key distinction
- Setup timing is concerned with the maximum-delay path.
- Hold timing is concerned with the minimum-delay path.
- Fixing a hold violation generally requires adding delay to the data path, not removing delay.

## Assumptions
- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- Existing measured worst hold slack: +0.196 ns.
- This checkpoint discusses timing conceptually; no RTL change is implied.
