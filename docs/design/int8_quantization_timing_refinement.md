# INT8 Quantization — Timing-Refinement Design

**Role:** Design Engineer  
**Active Phase:** Phase 6 — Quantization and Test-Data Preparation  
**Module:** INT8 Quantization / Requantization  
**Workflow stage:** STEP 9 SUPPORT — TIMING-CLOSURE REDESIGN BEFORE RTL CHANGE  

## 1. Objective

Refine the current requantization datapath so that the measured 100 MHz setup-timing failure can be removed without unnecessarily increasing the externally observed transaction latency.

The measured baseline is functionally correct but fails the 10 ns setup requirement:

```text
WNS = -0.405 ns
TNS = -2.381 ns
7 / 7 implemented output endpoints fail setup
```

The worst routed path is:

```text
accumulator register
  -> pre-DSP LUT logic
  -> DSP48E1
  -> rounding carry-chain logic
  -> saturation/output LUT logic
  -> output activation register
```

The measured data-path delay is:

```text
10.362 ns total
  6.066 ns logic
  4.296 ns routing
```

Therefore the refinement must break the arithmetic path rather than treating the failure as a routing-only problem.

## 2. Assumptions

- Target FPGA: XC7A35T-1CPG236C.
- Target clock: 100 MHz.
- Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

- The convolution engine remains `memory_interface_dataflow`.
- The supervisory controller remains the existing five-state `control_fsm` unless a control change is proven necessary.
- The engine result and `done` are registered together in the child engine's final state.
- The existing outer FSM observes `engine_done` one clock later because both modules are synchronous and use registered state/output updates.
- `requantize_relu` currently performs ReLU/sign gating, constant-coefficient multiplication, rounding, right shift, and saturation combinationally.
- The current representative measurement parameters remain:

```text
M_INT     = 13,421,773
FRAC_BITS = 27
```

- The redesign must preserve the existing numerical contract and rounding rule.
- No timing result from the redesigned datapath will be considered proven until Vivado synthesis and implementation are rerun.

## 3. Existing Control Timing From the RTL

The child engine's final state performs, on the same rising clock edge:

```text
result <= accumulator + partial_sum_ext
done   <= 1
```

The outer controller is in `ST_WAIT_ENGINE` while the child finishes.

Because both state machines are clocked, the outer state register cannot react to the newly registered `engine_done` value on that same edge. It reacts on the following edge.

Use the following edge labels:

```text
S5: child engine registers final result and engine_done = 1
S6: outer FSM enters ST_CAPTURE_ACTIVATION
S7: activation capture register captures the final activation
    outer FSM enters ST_DONE
```

This timing comes directly from the existing registered handshake and Moore-style control structure.

The important architectural observation is that the engine result is already stable after S5, while the final activation register is not captured until S7.

Therefore one complete clock interval exists between S5 and S6 that can be used to register an intermediate requantization result.

## 4. Why the Pipeline Register Must Be Placed After the DSP

The measured worst path contains ten logic levels and includes:

```text
DSP48E1 = 1
CARRY4  = 3 on the worst path
LUT logic before and after the DSP
```

The DSP48E1 contributes the largest single logic increment in the measured path, while the rounding carry chain and saturation/output logic occur after it.

A useful split is therefore:

```text
Stage 1:
engine result register
  -> ReLU/sign magnitude preparation
  -> constant-coefficient DSP multiply/correction
  -> product pipeline register

Stage 2:
product pipeline register
  -> rounding-bias addition
  -> constant right shift
  -> saturation/output selection
  -> activation capture register
```

This split is preferred over placing the register after rounding because it removes the DSP and the rounding carry chain from the same single-cycle path.

It is also preferred over placing the register before the DSP because doing so would leave the dominant DSP plus carry-chain/output logic together in the second stage.

## 5. Width of the New Pipeline Register

The post-ReLU magnitude is 18 unsigned bits.

The coefficient is 24 unsigned bits.

Therefore the exact raw multiplication result requires:

```text
18 + 24 = 42 bits
```

The new pipeline register should therefore preserve the full raw product:

```text
product_pipe : 42 bits
```

No truncation is allowed at this boundary.

The existing 43-bit rounding intermediate remains after the pipeline register:

```text
product_pipe
 -> zero extend to 43 bits
 -> add rounding bias
 -> right shift
 -> saturate
```

## 6. ReLU / Negative-Input Behavior Across the New Boundary

The current datapath converts every non-positive accumulator to:

```text
acc_mag = 0
```

before multiplication.

Therefore a negative or zero accumulator produces:

```text
product = 0
```

The new product pipeline register can simply capture that zero.

No separate sign flag has to cross the pipeline boundary because the ReLU decision has already been encoded into the multiplier input magnitude.

This keeps the second stage purely unsigned and positive.

## 7. Exact Cycle Schedule With the New Register

The key question is whether the new register adds external latency.

### S5 edge

The child engine executes its final registered update:

```text
result <= final convolution accumulator
engine_done <= 1
```

Immediately after S5, the new result is stable at the child engine output.

The pipeline register does **not** yet contain the new product because both registers update on the same edge and the product logic saw the pre-S5 value before the edge.

### S5 -> S6 cycle

The newly registered engine result propagates through:

```text
sign/ReLU gating
 -> magnitude preparation
 -> constant-coefficient DSP multiply
```

During this interval the outer FSM is still effectively completing its wait for the registered `engine_done` handshake.

### S6 edge

Two things happen together:

```text
1. outer FSM enters ST_CAPTURE_ACTIVATION
2. product pipeline register captures the product derived from the S5 result
```

This is the hidden pipeline opportunity.

The pipeline register can be clocked every cycle; no new FSM state is required. Because the engine `result` register changes only when a convolution completes, unconditional sampling does not alter the transaction protocol.

### S6 -> S7 cycle

The registered product propagates through:

```text
rounding bias addition
 -> constant right shift
 -> saturation/output logic
```

During this same cycle, the outer FSM is in `ST_CAPTURE_ACTIVATION`, so `capture_activation = 1`.

### S7 edge

The final activation register captures the completed INT8 value.

The outer controller moves to `ST_DONE` exactly as before.

Therefore the external state sequence does not require an additional state.

## 8. External Latency Result

The original control sequence already captures the activation at S7.

The new product register uses S6, which was already present because of the registered `engine_done` visibility delay.

Therefore, if the implementation behaves as designed:

```text
old final activation capture edge = S7
new final activation capture edge = S7
```

Hence:

```text
added externally visible cycles = 0
```

and the previously derived start-to-done latency can remain:

```text
7 clock periods
= 7 x 10 ns
= 70 ns
```

This is a design derivation, not yet a measured post-redesign result.

## 9. Why No New FSM State Is Preferred

Adding a dedicated extra pipeline state would produce a schedule such as:

```text
... -> REQUANTIZE_WAIT -> CAPTURE_ACTIVATION -> DONE
```

which would add at least one externally visible clock period:

```text
70 ns + 10 ns = 80 ns
```

That is unnecessary if the existing S5-to-S6 handshake gap can safely host the new product register.

The preferred architecture therefore keeps the current five-state outer FSM unchanged.

## 10. Register Enable Decision

Three possible register-enable strategies exist.

### Option A — unconditional product register update

```text
product_pipe <= current combinational product every clock
```

Advantages:

- no new control signal;
- no FSM modification;
- simplest timing structure;
- the child `result` register changes only at transaction completion, so repeated captures of the same product are harmless.

Disadvantage:

- the register is clocked every cycle.

### Option B — enable from `engine_done`

The product register would update only when the child engine indicates completion.

This can reduce unnecessary register toggling, but it couples the requantization stage to the child-engine handshake and must be timed carefully because `engine_done` is itself registered.

### Option C — add a new FSM-controlled capture state

This is rejected as the first choice because a Moore-style new state would likely move the product capture later and can add latency unless the controller is restructured more aggressively.

### Selected baseline

Use **Option A: unconditional product-register update** for the first timing-closure implementation.

Reason:

The architectural goal of this refinement is to prove that one register can close timing without changing the existing control protocol. Unconditional sampling gives the cleanest proof and the fewest new control interactions.

Power gating or a clock-enable optimization can be considered only after timing correctness is re-established and measured.

## 11. DSP Register Inference Goal

The current synthesis report showed the inferred DSP with:

```text
PREG = 0
```

The new raw-product register is placed directly after the DSP result.

A desirable synthesis outcome is that Vivado absorbs this register into the DSP48E1 output register:

```text
PREG = 1
```

If this occurs, the pipeline register is implemented inside the DSP slice rather than consuming a 42-bit bank of ordinary slice flip-flops.

This is a synthesis target, not an assumption. The post-change synthesis report must verify whether Vivado actually infers `PREG = 1`.

## 12. Why a Multicycle Constraint Is Not the First Refinement

Functionally, the existing control schedule gives the engine result more than one edge before final activation capture.

It would therefore be possible to investigate a justified multicycle timing exception in a final integrated design.

However, the first Phase 6 refinement will use an explicit pipeline register instead because:

- the timing boundary becomes explicit in RTL;
- each stage can be checked as an ordinary single-cycle 100 MHz path;
- the design does not depend on a fragile timing exception;
- the measured critical path already shows a natural split at the DSP output;
- the extra cycle can be hidden in the existing handshake schedule.

A multicycle exception must never be used merely to hide a violation; it is valid only when the functional protocol truly guarantees the extra cycle.

## 13. Expected Verification Changes

The existing combinational `requantize_relu` testbench cannot by itself verify the new clocked timing behavior.

The refined design will need verification of:

```text
1. product pipeline register captures the correct full-width product
2. negative / zero accumulators still produce zero
3. rounding behavior remains identical after one pipeline stage
4. saturation boundary remains unchanged
5. maximum-width arithmetic remains untruncated
6. final activation appears on the expected S7 capture edge
7. no extra externally visible control cycle is introduced
```

The existing combinational reference arithmetic remains valuable as the numerical oracle.

## 14. Timing Re-Measurement Requirements

After the RTL refinement is implemented, the physical flow must be repeated:

```text
synthesis
 -> utilization / DSP mapping
 -> implementation
 -> post-route timing
```

The redesign is successful only if the implemented result shows:

```text
setup WNS >= 0 ns
setup TNS = 0 ns
hold WHS >= 0 ns
hold THS = 0 ns
```

at the same 10 ns clock period.

The critical paths for both new stages must be inspected separately.

## 15. Resource Accounting After the Change

The redesign should be interpreted carefully.

Expected architectural changes:

```text
DSP count:
  target remains 1 DSP48E1

new pipeline storage:
  logical width = 42 bits

preferred physical mapping:
  DSP48E1 PREG = 1
```

If Vivado instead implements the product register in fabric, the slice-register count can increase substantially. That would still be functionally valid, but the resource tradeoff must be measured and documented.

## 16. Selected Timing-Refinement Architecture

The selected architecture is:

```text
ENGINE RESULT REGISTER  (S5)
        |
        v
ReLU/sign + 18-bit magnitude
        |
        v
24 x magnitude fixed coefficient multiply
        |
        v
42-bit PRODUCT PIPELINE REGISTER  (S6)
        |
        v
43-bit rounding addition
        |
        v
constant right shift
        |
        v
0...127 saturation / output select
        |
        v
ACTIVATION CAPTURE REGISTER  (S7)
```

The outer `control_fsm` state sequence remains unchanged.

The intended external latency therefore remains 70 ns at 100 MHz.

## 17. Design Gate

No timing-refinement RTL should be generated until the learner can explain all three points below in their own words:

1. Why the product register belongs after the DSP rather than before it or after the entire requantization path.
2. Why the product register can capture the completed S5 engine result at S6 even though the child result and `done` are registered together at S5.
3. Why inserting this register does not require an additional outer-FSM state or increase the S7 final activation-capture edge.
