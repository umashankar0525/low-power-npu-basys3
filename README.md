# Low-Power INT8 NPU on Basys 3

Architecture-first FPGA NPU project using Verilog RTL, Python, Vivado XSim, and a Basys 3 / Artix-7 target.

## Objective

Design and understand a low-power INT8 3x3 convolution accelerator with four parallel MAC units, INT32 accumulation, ReLU, BRAM storage, and FSM control.

## Method

Every module follows:

**Teach -> Design -> Predict -> Confirm understanding -> RTL -> Verify -> Simulate -> Measure -> Review**

No RTL is generated before the concept and mathematical derivation are understood.

See [`PROJECT_PLAN.md`](PROJECT_PLAN.md) for the complete learning and building roadmap.

## Target

XC7A35T-1CPG236C, Basys 3, 100 MHz.
