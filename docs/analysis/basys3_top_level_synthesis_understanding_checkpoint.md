# Basys 3 Top-Level Synthesis — Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Final physical validation — synthesis understanding gate  
**Status:** PASSED — implementation/post-route timing measurement is unlocked.

## Confirmed understanding

The learner correctly summarized the current physical-validation state:

```text
Behavioral simulation       PASS
XDC verification            PASS
Synthesis                    PASS
Resource utilization         MEASURED
BRAM inference               CONFIRMED
IOB count                    CONFIRMED
BUFG count                   CONFIRMED

Implementation / P&R         PENDING
Post-route STA               PENDING
Bitstream                    PENDING
Hardware validation          PENDING
```

## Evidence boundary

Synthesis has now proven:

```text
successful synthesis
LUT/FF/CARRY4/DSP utilization
BRAM inference and primitive mapping
IOB utilization
BUFG utilization
```

Post-route timing must still prove:

```text
WNS
TNS
WHS
THS
critical path
100 MHz timing closure
```

## Gate result

**BASYS3 TOP-LEVEL SYNTHESIS UNDERSTANDING GATE: PASSED**

Next required evidence:

```text
implemented design
-> post-route timing summary
-> critical path
```
