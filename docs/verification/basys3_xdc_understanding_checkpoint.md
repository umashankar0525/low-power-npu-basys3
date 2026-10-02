# Basys 3 XDC Verification — Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 6 — `/verify basys3_xdc` understanding gate  
**Status:** PASSED — Step 7 verification-artifact generation is unlocked.

## Assessment

### 1. Why static inspection is not enough
**PASSED.**

The learner correctly explained that source inspection proves only intended constraint text. Vivado-applied verification is required to prove that `get_ports` expressions resolve against the actual top-level design and that the constraints are truly applied.

### 2. Required Vivado I/O evidence
**PASSED.**

The learner correctly identified that the I/O report must demonstrate the expected:

```text
port -> package pin -> I/O standard
```

relationship for all 12 top-level board signals.

### 3. Required Vivado clock evidence
**PASSED.**

The learner correctly identified that Vivado must recognize:

```text
1 primary clock
100 MHz
10.000 ns period
waveform {0 5}
generated clocks = 0
```

### 4. Why clock recognition does not prove timing closure
**PASSED.**

The learner correctly explained that the XDC defines a timing requirement, while implementation/STA measures actual path delays and determines WNS/TNS/WHS/THS.

### 5. Why 12 bonded I/O is predicted but must be confirmed
**PASSED.**

The learner correctly derived:

```text
3 inputs + 9 outputs = 12 board signals
```

and correctly distinguished this design prediction from the final utilization report.

### 6. XDC-critical failure classes
**PASSED.**

The learner correctly identified the important failure classes:

```text
missing PACKAGE_PIN
missing IOSTANDARD
invalid get_ports
duplicate package pin
missing/incorrect primary clock
required unconstrained ports
```

### 7. Why BRAM/DSP/LUT/FF are outside XDC verification
**PASSED.**

The learner correctly separated physical interface/timing constraints from synthesis resource inference.

### 8. Source-verified versus tool-verified
**PASSED.**

The learner correctly defined:

```text
XDC source verified
-> file text matches approved design intent

XDC tool-verified
-> Vivado successfully resolves and applies the constraints to the actual design
```

## Gate result

**BASYS3 XDC VERIFICATION UNDERSTANDING GATE: PASSED**

The module may now proceed to the next verification artifact.

Because XDC is a constraint artifact rather than executable RTL, a normal Verilog unit testbench cannot prove package-pin, IOSTANDARD, or clock-object application. The Step-7 verification artifact for this module must therefore exercise Vivado's constraint database directly and collect the required evidence, while preserving the same workflow purpose: an independently checkable verification artifact before measurement.

The next artifact should check:

```text
all 12 ports resolve
PACKAGE_PIN values
IOSTANDARD values
primary clock existence
10.000 ns period
expected waveform
duplicate/missing constraints
constraint-critical messages
```

No physical sign-off is claimed until that artifact is run in Vivado and its output is inspected.
