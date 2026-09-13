# INT8 Quantization — Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** ANALYZE / UNDERSTANDING CHECK

## Current status

**Status: PASSED — STEP 4 UNDERSTANDING GATE CLEARED**

The learner has now correctly restated all three required analysis concepts.

## 1. Why the requantization product needs 42 bits

**Status: PASSED**

Worst-case values:

```text
acc_max   = 145161
M_int_max = 16777215
```

Therefore:

```text
145161 × 16777215 = 2435397306615
```

and:

```text
2^41 < 2435397306615 < 2^42
```

So the exact raw unsigned product requires 42 bits.

## 2. Why DSP usage is predicted as 1 to 2 slices rather than automatically 1

**Status: PASSED**

The learner correctly restated that the full accumulator magnitude requires 19 signed-positive bits, while the DSP48E1 multiplier's narrow signed input is 18 bits.

The 24-bit unsigned requantization coefficient can be zero-extended into a 25-bit signed-positive operand and fit the wide DSP input. However, the accumulator magnitude can reach 145161, while the maximum positive value of an 18-bit signed operand is only 131071.

Therefore the full unsigned accumulator range does not directly fit the 18-bit signed multiplier input. Synthesis may use one DSP plus correction/decomposition logic or two DSP slices. Exact mapping remains a synthesis measurement.

## 3. Why one pipeline register may not increase the current 70 ns external latency

**Status: PASSED**

The learner correctly identified that the existing control sequence already contains the intermediate S6 edge:

```text
S5: child engine registers result and engine_done
S6: outer FSM reaches CAPTURE_ACTIVATION
S7: final output register captures the activation
```

A requantization pipeline register can potentially be placed at S6:

```text
S5 -> S6:
engine result -> requantization arithmetic -> requantization register

S6 -> S7:
requantization register -> final activation capture
```

Because S6 is already part of the existing transaction schedule, using that edge does not necessarily insert another external state or clock cycle. Therefore the current 70 ns start-to-done latency can potentially remain unchanged.

Each register-to-register combinational segment must still satisfy the 100 MHz timing requirement of 10 ns after implementation.

## Gate result

The mandatory pre-RTL sequence is now complete for `int8_quantization`:

```text
TEACH   -> complete
DESIGN  -> complete
ANALYZE -> complete
USER UNDERSTANDING CONFIRMATION -> complete
```

RTL/Python implementation is now permitted by the project workflow. No simulation should be performed until the implementation and verification-plan steps are completed in sequence.
