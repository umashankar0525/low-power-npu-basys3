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
