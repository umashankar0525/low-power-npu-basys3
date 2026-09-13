# INT8 Quantization — Analysis Understanding Checkpoint

**Role:** Performance Analyst  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization  
**Workflow stage:** ANALYZE / UNDERSTANDING CHECK

## Current status

The learner correctly understood the 42-bit product-width derivation, but two analysis concepts still require a more precise restatement before the Step 4 understanding gate is passed.

## 1. Why the requantization product needs 42 bits

**Status: PASSED**

The learner correctly used the worst-case values:

```text
acc_max   = 145161
M_int_max = 16777215
```

so:

```text
145161 × 16777215 = 2435397306615
```

and:

```text
2^41 < 2435397306615 < 2^42
```

Therefore the exact raw unsigned product requires 42 bits.

## 2. Why DSP usage is predicted as 1 to 2 slices rather than automatically 1

**Status: NEEDS PRECISION RESTATEMENT**

The important issue is not merely that a generic unsigned multiply may map unpredictably. The relevant DSP48E1 multiplier is a two's-complement signed multiplier with native operand widths of 25 bits and 18 bits.

The 24-bit unsigned coefficient can be represented as a positive signed value by adding a leading zero, so it becomes a 25-bit positive operand and fits the 25-bit side.

The accumulator magnitude is 18-bit unsigned and can reach:

```text
145161
```

but an 18-bit signed positive value reaches only:

```text
+131071
```

Therefore the complete positive accumulator range requires 19 signed bits after zero extension, which does not directly fit the DSP's native signed 18-bit input.

Hence a direct generic multiply is not guaranteed to map to one DSP. Vivado may use one DSP plus correction/decomposition logic, or it may use two DSP slices. Exact mapping must be measured in synthesis.

## 3. Why one pipeline register may not increase the current 70 ns external latency

**Status: NEEDS PRECISION RESTATEMENT**

The reason is not simply that the arithmetic must be below 10 ns.

The current outer-control timing already contains two sequential intervals between the child result becoming valid and the final activation capture:

```text
S5: child engine registers result and engine_done
S6: outer FSM reaches CAPTURE_ACTIVATION
S7: final output register captures the activation
```

Without an internal requantization register, the result can propagate combinationally from S5 toward the final capture at S7 according to the selected integration structure.

A single requantization pipeline register can instead be placed on the already available intermediate edge:

```text
S5 -> S6:
engine result -> requantization arithmetic -> requantization register

S6 -> S7:
requantization register -> final activation capture
```

Because S6 already exists in the transaction schedule, this register can potentially use an edge that was already present rather than inserting a new external state/cycle. Therefore the existing 70 ns start-to-done latency can potentially remain unchanged.

Each register-to-register combinational segment must still satisfy the 100 MHz setup requirement, meaning its physical timing must fit the 10 ns clock period after implementation. But meeting 10 ns is a timing requirement, not the fundamental reason the extra register can be hidden without an extra transaction cycle.

## Hard gate

Before RTL generation, the learner must restate in their own words:

1. why the full 18-bit unsigned accumulator magnitude does not directly fit the DSP48E1's 18-bit signed-positive input range, and
2. why the existing S5 -> S6 -> S7 control sequence can provide an already-existing edge for one requantization pipeline register without necessarily adding another external cycle.
