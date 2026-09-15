# INT8 Quantization — Pipelined Requantizer Testbench

**Role:** Verification Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** TIMING-REFINEMENT TESTBENCH GENERATION

## 1. Objective

Verify `rtl/activation/requantize_relu_pipelined.v` with a clock-aware unit testbench that checks both numerical correctness and cycle association.

Testbench file:

```text
tb/unit/tb_requantize_relu_pipelined.v
```

## 2. Clocking Model

The testbench generates a 100 MHz clock:

```text
T = 10 ns
```

Each directed input is driven on a falling edge so that `acc_in` is stable before the following rising edge.

At the next rising edge:

```text
product_reg <= acc_mag * M_INT
```

The testbench waits `#1` after that edge before checking Stage-2 combinational signals and `q_out`.

The `#1` delay is therefore only a post-edge settle delay. It is not being used as a substitute for the required product-capture clock edge.

## 3. Parameter Instances

Four DUT instances mirror the parameter partitions used by the original combinational verification:

```text
A: M_INT = 1,        FRAC_BITS = 0
B: M_INT = 1,        FRAC_BITS = 1
C: M_INT = 3,        FRAC_BITS = 2
D: M_INT = 0xFFFFFF, FRAC_BITS = 42
```

Using separate instances is required because these parameters are elaboration-time constants.

## 4. Directed Coverage

The testbench checks:

```text
synchronous reset
negative and zero ReLU behavior
identity scaling
normal positive values
saturation above 127
positive round-to-nearest
non-power-of-two multiplication
natural 127 versus saturation-to-127
maximum-width 42-bit product
43-bit rounded intermediate
back-to-back consecutive-edge samples
```

## 5. Internal Signal Checks

The testbench uses hierarchical checks on:

```text
product_reg
rounded_num
q_pre_wide
```

These checks prove that the new pipeline boundary preserves the exact raw product and that the Stage-2 arithmetic is still correct.

For the maximum-width case:

```text
acc = 145161
M_INT = 16777215

product_reg = 145161 * 16777215
            = 2435397306615

rounding bias for F=42 = 2^41
                         = 2199023255552

rounded_num = 2435397306615 + 2199023255552
            = 4634420562167

q_pre_wide = 1
q_out      = 1
```

## 6. Saturation Boundary Derivation

For `M_INT=3`, `FRAC_BITS=2`:

```text
acc=169:
169*3 = 507
507+2 = 509
509>>2 = 127
```

so the result is naturally 127.

For:

```text
acc=170:
170*3 = 510
510+2 = 512
512>>2 = 128
```

so the final 127 output must come from saturation.

Both cases are checked internally so identical final outputs cannot hide a broken saturation path.

## 7. Back-to-Back Sequencing

The testbench applies:

```text
acc=1
acc=3
acc=5
```

before three consecutive rising edges with no empty rising edge between them.

For `M_INT=3`, `FRAC_BITS=2`, the corresponding post-edge outputs must be:

```text
1
2
4
```

and the corresponding registered products must be:

```text
3
9
15
```

This proves sample-to-cycle association in addition to arithmetic correctness.

## 8. Pass/Fail Rule

All comparisons use four-state-safe inequality so X/Z values fail the test.

The testbench keeps a failure counter and prints:

```text
TB_REQUANTIZE_RELU_PIPELINED_PASS: all directed checks passed
```

only when the failure count is zero.

## 9. What Must Happen Next

The testbench has been generated but has not been executed by ChatGPT.

The next step is to run Vivado XSim locally with:

```text
requantize_relu_pipelined.v
tb_requantize_relu_pipelined.v
```

and inspect the transcript signal-by-signal.

Only after the behavioral simulation passes should the timing-refined wrapper be re-synthesized and re-implemented for new DSP-register and timing measurements.
