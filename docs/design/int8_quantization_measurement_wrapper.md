# INT8 Quantization — Registered Measurement Wrapper

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 SUPPORT — PHYSICAL MEASUREMENT SETUP

## 1. Objective

Create a measurement-only synchronous wrapper around the combinational `requantize_relu` block so Vivado static timing analysis sees a meaningful register-to-register path.

The wrapper is:

```text
rtl/activation/requantize_timing_wrapper.v
```

The matching 100 MHz timing constraint is:

```text
vivado/constraints/requantize_timing_wrapper.xdc
```

This wrapper does not replace the final integrated NPU architecture. It exists only to characterize the current combinational requantization implementation under a representative nontrivial fixed-point coefficient.

## 2. Assumptions

- Target FPGA: XC7A35T-1CPG236C.
- Target board: Basys 3.
- Target frequency: 100 MHz.
- Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

- Reset is synchronous and active high.
- `requantize_relu` itself remains combinational.
- Valid architectural accumulator values still obey the Phase 6 generated-data bound.
- The representative coefficient is not claimed to be a final trained-layer coefficient.

## 3. Representative Requantization Parameters

The earlier analysis used the representative real multiplier:

```text
M = 0.1
```

With a 24-bit unsigned coefficient, the largest fitting useful fractional precision is:

```text
FRAC_BITS = 27
```

because:

```text
M_INT = round(0.1 × 2^27)
      = 13,421,773
```

and:

```text
13,421,773 < 2^24 = 16,777,216
```

The represented multiplier is:

```text
M_hat = 13,421,773 / 2^27
      ≈ 0.10000000149
```

These values exercise a real multiply-plus-round-plus-shift datapath. They intentionally avoid the trivial default `M_INT=1, FRAC_BITS=0`, which synthesis could reduce to wiring and simple saturation logic.

## 4. Registered Timing Structure

The measurement path is:

```text
accumulator_input
      |
      v
accumulator_reg
      |
      v
requantize_relu
      |
      v
output_activation register
```

The source register launches the accumulator value. The destination register captures the final INT8 activation one clock later.

Static timing can therefore evaluate the actual combinational requantization path against the 10 ns setup requirement.

## 5. Why the Wrapper Is Necessary

A standalone combinational `requantize_relu` block has no internal launch/capture registers. Synthesis can estimate its logic area, but register-to-register setup slack is not defined by the block alone.

The wrapper supplies the missing synchronous context so the physical question becomes:

```text
Can data launched from accumulator_reg propagate through requantize_relu
and arrive at output_activation before the next 100 MHz capture edge?
```

For a 10 ns period, setup timing is acceptable only if the reported worst setup slack satisfies:

```text
WNS >= 0 ns
```

The implemented routed result will later be treated as the strongest timing measurement.

## 6. Resource-Accounting Rule

The wrapper adds measurement registers around the combinational DUT. Those registers are not internal pipeline registers of `requantize_relu`.

Therefore resource interpretation must separate:

```text
A. requantize_relu arithmetic resources
B. wrapper launch/capture register overhead
```

If Vivado reports only top-level totals, the flip-flop total must not be compared directly with the earlier prediction:

```text
internal pipeline FFs in baseline requantize_relu = 0
```

The wrapper intentionally creates registers for timing measurement.

For DSP/LUT comparison, use the hierarchy report for `u_requantize` when available, or clearly state that a top-level wrapper total includes measurement scaffolding.

## 7. Constraint Rule

The measurement XDC contains:

```text
create_clock -name clk_100MHz -period 10.000 [get_ports clk]
```

Only one active XDC should create the clock on this wrapper's `clk` port during the measurement run.

The repository also contains an older `relu_timing_wrapper.xdc` that creates the same 100 MHz clock for a different measurement wrapper. Do not enable both clock-creation files simultaneously for this top-level run.

## 8. Measurement Procedure

For the requantization measurement run:

```text
1. Add requantize_relu.v to Design Sources.
2. Add requantize_timing_wrapper.v to Design Sources.
3. Set requantize_timing_wrapper as the synthesis top.
4. Add/enable requantize_timing_wrapper.xdc.
5. Disable any other XDC that creates a clock on the same top-level clk port.
6. Run synthesis.
7. Record utilization: DSP, LUT, FF, BRAM.
8. Record post-synthesis timing as an early estimate.
9. Run implementation.
10. Record post-route WNS, TNS, critical-path startpoint, endpoint, and logic/DSP involvement.
```

## 9. Measurements Required for Step 9 Completion

The physical measured-vs-predicted comparison is not complete until the following are recorded:

```text
DSP48E1 usage
LUT usage
FF usage, with wrapper overhead identified
BRAM usage
post-synthesis WNS/TNS if available
post-route WNS/TNS
critical-path startpoint
critical-path endpoint
whether the critical path passes through DSP48E1
setup pass/fail at 10 ns
hold pass/fail
```

## 10. Interpretation Boundaries

A result from this wrapper characterizes the current combinational requantization datapath for the representative `M≈0.1` coefficient.

It does not by itself prove:

- every possible future layer coefficient has identical mapping;
- the final integrated NPU has exactly the same routing delay;
- the wrapper registers are architectural pipeline registers;
- the current coefficient is the final network coefficient.

Its purpose is to test the earlier resource and timing predictions with a meaningful nontrivial configuration before final integration.

## 11. Constraint-File Handling Clarification

Do **not** delete `vivado/constraints/relu_timing_wrapper.xdc` from the repository. That file belongs to the earlier standalone ReLU timing characterization and should be preserved as project evidence.

For the current `requantize_timing_wrapper` measurement, only `requantize_timing_wrapper.xdc` should be active for synthesis/implementation timing. The older ReLU timing XDC may remain in the Vivado project, but it should be disabled for this run, or removed from the current project file set without deleting the repository file.

The reason is that both timing-wrapper XDC files create a clock on a top-level port named `clk`. Activating both during the same run can create duplicate or conflicting clock constraints and make timing interpretation ambiguous.
