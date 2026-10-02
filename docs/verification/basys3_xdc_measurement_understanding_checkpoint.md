# Basys 3 XDC Measurement — Understanding Checkpoint

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 8 — measurement understanding gate  
**Status:** PARTIAL — timing evidence understood; BRAM proof source needs correction.

## Assessment

The learner correctly stated that XDC verification does not prove final 100 MHz timing closure.

The required distinction is:

```text
XDC verification
-> proves constraints were applied

Synthesis / utilization
-> proves BRAM/resource mapping

Implementation / post-route STA
-> proves WNS/TNS/WHS/THS timing closure
```

Therefore:

```text
59 checks, 0 errors
```

proves that Vivado applied the approved XDC correctly, but it does not prove either resource mapping or routed timing.

## Gate result

**PARTIAL**

The learner must restate which evidence proves BRAM inference and which evidence proves 100 MHz timing closure before Step 9 can proceed.
