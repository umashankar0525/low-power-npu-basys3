# Basys 3 XDC Constraints — Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 3 — `/analyze basys3_xdc` understanding gate  
**Status:** PASSED — Step 4 understanding confirmation is complete and Step 5 XDC generation is unlocked.

## Assessment

### 1. Why 12 constrained ports and 0 required unconstrained ports
**PASSED.**

The learner correctly derived:

```text
3 inputs + 9 outputs = 12 top-level board signals
```

and correctly explained that every one is intended to connect to a physical Basys-3 resource, so none should remain unconstrained.

### 2. Why one 100 MHz primary clock is expected
**PASSED.**

The learner correctly derived:

```text
T = 1 / (100 x 10^6)
  = 10 ns
```

and correctly explained that the design has one external system clock and no MMCM/PLL/generated-clock structure.

### 3. Why 12 bonded I/O is reasonable but still needs confirmation
**PASSED.**

The learner correctly separated the architectural/package-pin prediction from the actual utilization evidence that must come from Vivado reports.

### 4. Why zero XDC-critical warnings, not zero total warnings
**PASSED.**

The learner correctly explained that Vivado may emit unrelated synthesis/implementation warnings, while the prediction is specifically that the constraint set should produce no critical issues such as:

```text
missing PACKAGE_PIN
missing IOSTANDARD
invalid get_ports
duplicate package pin
missing primary clock
```

### 5. Evidence for package pins and LVCMOS33
**PASSED.**

The learner correctly identified the Vivado I/O/package-pin report as the evidence that the intended constraints were actually recognized and applied.

### 6. Evidence for the 10 ns primary clock
**PASSED.**

The learner correctly identified the clock/timing report as the evidence that `clk_100mhz` is recognized with a 10.000 ns period and 100 MHz frequency.

### 7. Why XDC does not prove positive slack or BRAM inference
**PASSED.**

The learner correctly separated:

```text
XDC -> timing requirement
STA -> timing result

RTL / synthesis -> memory/resource inference
utilization report -> actual BRAM/LUT/FF/DSP mapping
```

### 8. Why input/output delays are intentionally absent
**PASSED.**

The learner correctly explained that the pushbuttons and LEDs are not synchronous external interfaces with a defined source/receiver clock relationship, so `set_input_delay` and `set_output_delay` would not model the real interface.

## Gate result

**BASYS3 XDC ANALYSIS UNDERSTANDING GATE: PASSED**

The module may now proceed to:

```text
Step 5 — generate vivado/constraints/basys3_top_level.xdc
```

The generated file must match the approved mapping and prediction exactly, and its correctness must later be verified in Vivado reports.
