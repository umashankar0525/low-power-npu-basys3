# Basys 3 Timing Closure — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 1 — teaching understanding gate  
**Status:** PASSED — Step 2 `/design basys3_timing_closure` is unlocked.

## Assessment

The learner correctly explained all required timing-closure concepts.

### 1. Cause of the 100 MHz failure

Correctly identified:

```text
clock requirement = 10.000 ns
critical data path = 13.433 ns
WNS               = -3.453 ns
```

The learner understands that the current BRAM-to-accumulator path cannot complete within one 100 MHz clock period.

### 2. Why the XDC must remain unchanged

Correctly stated that the 10 ns XDC defines the required 100 MHz specification and must not be relaxed merely to hide the architecture problem.

### 3. Purpose of pipelining

Correctly explained that a pipeline register divides one long combinational path into shorter register-to-register paths.

### 4. Latency consequence

Correctly explained that an additional sequential boundary can increase transaction latency by one or more clock cycles.

### 5. Data/control alignment

Correctly identified that pipelined data must remain aligned with:

```text
valid
control
address/word identity
accumulator enable
final-word indication
done sequencing
```

### 6. BRAM-output register limitation

Correctly explained that registering the BRAM output may improve timing but may still leave too much arithmetic in the following stage.

### 7. CARRY4 interpretation

Correctly interpreted the approximately ten CARRY4 elements and seventeen logic levels as evidence of a deep arithmetic/carry-propagation path and a likely datapath split opportunity.

### 8. Functional requirement

Correctly preserved:

```text
accumulator = 45
M_INT       = 3
FRAC_BITS   = 2
output      = 34
            = 0x22
```

with:

```text
LED1 = ON
LED5 = ON
```

### 9. Required rerun flow

Correctly identified:

```text
RTL simulation
-> synthesis
-> utilization/resource comparison
-> implementation
-> post-route STA
-> bitstream
-> hardware test
```

### 10. Timing closure criteria

Correctly stated:

```text
Setup:
WNS >= 0
TNS = 0

Hold:
WHS >= 0
THS = 0

Pulse width:
WPWS >= 0
TPWS = 0
```

## Gate result

**BASYS3 TIMING CLOSURE STEP-1 UNDERSTANDING GATE: PASSED**

The next workflow step is:

```text
Step 2 — /design basys3_timing_closure
```

No RTL modification is authorized until the design architecture and Step-3 prediction are completed and understood.
