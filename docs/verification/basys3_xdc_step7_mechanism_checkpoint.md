# Basys 3 XDC Step-7 Mechanism Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 7 — verification-artifact mechanism gate  
**Status:** PASSED — Vivado/Tcl constraint-verification artifact generation authorized.

## Assessment

The learner correctly explained that a Verilog testbench can verify logical signal behavior but cannot observe FPGA implementation properties such as:

```text
PACKAGE_PIN
IOSTANDARD
Vivado clock objects
```

They correctly distinguished:

```text
simulation clock stimulus
!=
Vivado create_clock timing object
```

and correctly identified the Vivado constraint database as the proper Step-7 verification target.

The approved Step-7 mechanism is therefore a Tcl verification script that must run with the design and XDC loaded in Vivado and explicitly check:

```text
12 expected top-level port objects
PACKAGE_PIN for each port
IOSTANDARD for each port
unique package pins
sys_clk_pin clock existence
10.000 ns period
{0 5} waveform
CONFIG_VOLTAGE
CFGBVS
```

## Gate result

**STEP-7 VERIFICATION-MECHANISM UNDERSTANDING: PASSED**
