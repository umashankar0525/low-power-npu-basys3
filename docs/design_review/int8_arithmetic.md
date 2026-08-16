# INT8 Arithmetic — Design Review

## Role
Design Reviewer artifact.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Review Scope
Review the signed INT8 arithmetic primitive after exhaustive functional simulation.

## Evidence Reviewed

- `rtl/primitives/int8_arithmetic.v`
- `tb/unit/tb_int8_arithmetic.v`
- `docs/design/int8_arithmetic.md`
- `docs/verification/int8_arithmetic.md`
- `docs/analysis/int8_arithmetic.md`
- User-supplied Vivado 2018.2 XSim transcript

## Functional Result

The testbench executed:

`Tests performed : 65536`

`Errors found    : 0`

`RESULT          : PASS`

Therefore the defined functional arithmetic contract has been exhaustively verified over the complete signed INT8 input space.

## Review Findings

### 1. Signed arithmetic — PASS

The design treats both operands as signed INT8 values. The exhaustive test covers all signed combinations, including both asymmetric limits `-128` and `+127`.

### 2. Product width — PASS

The derived product range is:

`-16256 <= product <= +16384`

Signed INT16 supports:

`-32768 <= value <= +32767`

Therefore the selected INT16 product width is sufficient for every legal INT8 pair.

### 3. INT32 extension — PASS

The product is explicitly sign-extended from 16 to 32 bits. The testbench checks both the numerical result and the upper-half sign pattern.

### 4. Module boundary — PASS

The primitive does not combine multiplication with accumulation, memory, ReLU, or control. This gives a clean verification boundary and supports incremental architecture development.

### 5. Clocking — ACCEPT

The current primitive is combinational and therefore has no registered state or clock input. This is appropriate for the arithmetic foundation. The timing consequence must be evaluated when this multiplier is placed inside the MAC pipeline/datapath.

### 6. Resource usage — PENDING MEASUREMENT

The RTL expresses one signed 8x8 multiplication. Exact LUT/DSP mapping must not be assumed before synthesis. Vivado may infer FPGA DSP resources or LUT-based logic depending on implementation settings and constraints.

### 7. Timing — PENDING MEASUREMENT

The simulation proves functional behavior, not FPGA propagation delay. The target clock is 100 MHz, giving:

`Tclk = 1 / 100 MHz = 10 ns`

Actual post-synthesis/post-route timing must be measured before claiming the primitive meets the target frequency.

### 8. Power — PENDING MEASUREMENT

No numerical power claim is justified yet. Dynamic power depends on implementation and switching activity. The combinational multiplier can switch when operands change, so later system-level design should consider data movement and operand activity as part of the low-power analysis.

### 9. Simulation warning — MINOR CLEANUP

Vivado 2018.2 reported that the DUT has no explicit timescale while another module has one. This did not affect the exhaustive functional result. Adding a consistent `` `timescale 1ns/1ps `` to the DUT is a cleanup item, not a functional correction.

## Design Decision

**APPROVED — FUNCTIONAL FOUNDATION**

The arithmetic primitive is approved as the foundation for the next module because:

- its mathematical width derivation is sound,
- its signed behavior is exhaustively verified,
- its sign extension is verified,
- its module boundary is appropriate for incremental development.

However, this approval does **not** claim timing, resource, or power closure.

## Open Measurements

Before final project-level performance conclusions, measure:

1. LUT utilization
2. DSP utilization
3. FF utilization
4. post-synthesis timing / critical path
5. post-route timing / slack
6. power if the Vivado power flow is available

## Next Architectural Step

Proceed to the next arithmetic foundation: the **INT32 accumulator / MAC accumulation stage**. Its concept and derivation must be taught before design begins.

## Review Status

**APPROVED for progression — functional foundation complete; implementation metrics pending.**
