# Low-Power INT8 NPU on Basys 3

## Project Roadmap

This project is an architecture-first hardware/software co-design of a low-power INT8 neural processing accelerator for the Basys 3 / Artix-7 FPGA.

### Reference Parameters

- Target FPGA: XC7A35T-1CPG236C
- Clock: 100 MHz
- Convolution: 3x3
- Input channels: 1
- Output channels: 1
- MAC units: 4
- Weight precision: INT8
- Activation precision: INT8
- Product precision: INT16
- Accumulator precision: INT32
- Activation: ReLU
- Memory: FPGA BRAM
- Control: FSM

## Learning Phase

1. INT8 signed arithmetic and two's complement
2. INT8 x INT8 multiplication and INT16 product range
3. INT32 accumulation and overflow bounds
4. Single MAC datapath
5. Four-MAC parallel architecture and scheduling
6. ReLU
7. 3x3 convolution and sliding-window scheduling
8. BRAM organization, addressing, and latency
9. FSM control and cycle sequencing
10. FP32-to-INT8 quantization
11. Python golden-model verification
12. FPGA resource, timing, and low-power fundamentals

Each learning topic produces a note in `docs/learning/` and requires the learner to restate the concept before RTL proceeds.

## Building Phase

B1 Arithmetic primitives -> B2 multiplier -> B3 accumulator -> B4 MAC -> B5 four-MAC datapath -> B6 ReLU -> B7 BRAM interface -> B8 convolution engine -> B9 FSM controller -> B10 quantized data generation -> B11 integration -> B12 Basys 3 top level -> B13 verification -> B14 measurement -> B15 low-power optimization -> B16 final design review.

## Mandatory Module Workflow

TEACH -> DESIGN -> ANALYZE/PREDICT -> USER CONFIRMS UNDERSTANDING -> RTL -> VERIFY -> TESTBENCH -> SIMULATE -> MEASURE -> COMPARE MEASURED VS PREDICTED -> REVIEW -> SELF-TEST.

## Hard Gates

- No complete RTL before concept and derivation.
- No simulation before prediction.
- A passing testbench must be explained signal-by-signal.
- All assumptions must be explicitly labeled.
- The learner must explain the concept back before advancing.

## Repository Structure

```text
rtl/{primitives,compute,activation,memory,control,infrastructure,top}
tb/{unit,integration,scripts}
python/{quantization,reference,verification,weight_generation,visualization}
mem/
vivado/constraints/
docs/{learning,design,verification,analysis,design_review}
```

## Success Criteria

The completed accelerator must have explainable arithmetic widths, scheduling, memory traffic, cycle count, FPGA resource usage, timing behavior, and low-power decisions. Predictions must be validated against Vivado/XSim measurements.
