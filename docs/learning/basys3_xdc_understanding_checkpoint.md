# Basys 3 XDC Constraints — Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_xdc`  
**Workflow stage:** Step 1 — `/teach basys3_xdc` understanding gate  
**Status:** PASSED — Step 2 `/design basys3_xdc` is unlocked.

## Assessment

### 1. Three main jobs of the XDC
**PASSED.**

The learner correctly identified:
- logical-port to FPGA package-pin mapping,
- electrical I/O-standard declaration,
- clock timing constraint definition.

### 2. 100 MHz to 10 ns derivation
**PASSED.**

The learner correctly derived:

```text
T = 1/f
  = 1/(100 x 10^6)
  = 10 ns
```

and correctly distinguished the 10 ns cycle requirement from the 70 ns seven-cycle accelerator latency.

### 3. Package-pin constraint versus clock constraint
**PASSED.**

The learner correctly distinguished:
- physical connectivity: where a logical port is connected,
- timing requirement: how fast synchronous logic must operate.

### 4. Board-signal count
**PASSED.**

The learner correctly derived:

```text
1 clock
+ 2 buttons
+ 8 result LEDs
+ 1 done LED
= 12 constrained board signals
```

### 5. Why button conditioning is still required
**PASSED.**

The learner correctly explained that XDC mapping does not make a mechanical button synchronous or remove bounce. The two-FF synchronizer, debounce, and edge detector remain necessary RTL functions.

### 6. LED bit-order significance
**PASSED.**

The learner correctly derived:

```text
34 decimal = 0x22 = 0010_0010
```

so logical result bits 5 and 1 are high. They correctly explained that incorrect logical-to-physical LED mapping can display the wrong visible pattern while the internal computation remains correct.

### 7. What XDC proves and does not prove
**PASSED.**

The learner correctly separated XDC responsibilities from evidence that still requires:
- simulation for RTL behavior,
- synthesis for resource mapping,
- implementation/STA for routed timing,
- hardware testing for actual board behavior.

### 8. Why package pins must come from an authoritative source
**PASSED.**

The learner correctly explained that guessed package pins or I/O standards can make an otherwise correct RTL design physically unusable or incorrectly connected.

## Additional synthesis of concepts

The learner also correctly summarized the evidence chain:

```text
RTL
-> what the circuit should do

XDC
-> where signals connect, electrical standards, and clock timing requirements

Synthesis / implementation
-> what resources are used and whether the routed design meets timing

Hardware
-> whether the physical buttons and LEDs behave as intended
```

## Gate result

**BASYS3 XDC TEACHING UNDERSTANDING GATE: PASSED**

The module may now proceed to:

```text
Step 2 — /design basys3_xdc
```

During design, exact Basys-3 package pins and I/O-standard values must be sourced from an authoritative board constraint source rather than inferred from memory.
