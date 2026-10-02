# Basys 3 Timing Closure — Teaching Notes

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 1 — `/teach basys3_timing_closure`  
**Status:** TEACHING COMPLETE — understanding gate required before design or RTL changes.

---

## 1. Why this is a new module/work item

The existing `basys3_top_level` is functionally correct:

```text
behavioral simulation = PASS
XDC verification      = PASS
synthesis             = PASS
BRAM inference        = PASS
implementation        = COMPLETE
```

but the routed design fails setup timing at 100 MHz:

```text
WNS = -3.453 ns
TNS = -99.753 ns
43 setup endpoints fail
```

The worst setup path has:

```text
requirement      = 10.000 ns
data-path delay  = 13.433 ns
logic delay      = 8.067 ns
route delay      = 5.366 ns
logic levels     = 17
CARRY4 count     ≈ 10
```

The path begins at the block-RAM activation output and ends at the accumulator register.

Therefore this is not an XDC problem. It is an architectural timing problem.

---

## 2. Timing equation from first principles

For a register-to-register setup path, the essential requirement is:

```text
Tclk >= Tcq + Tcomb + Troute + Tsetup + Tskew/uncertainty effects
```

Vivado summarizes these details into the final required and arrival times and reports slack:

```text
Slack = Required Time - Arrival Time
```

For the current critical path:

```text
WNS = -3.453 ns
```

Negative slack means the destination register receives valid data too late for the next active edge.

The 100 MHz period is:

```text
Tclk = 1 / 100 MHz
     = 10 ns
```

The current implementation therefore cannot reliably complete this path in one 10 ns cycle.

---

## 3. Why the critical path became longer after BRAM integration

The earlier core-only implementation did not contain the final physical operand BRAM path.

The final top-level now contains:

```text
RAMB18E1
-> operand word
-> lane extraction / signed arithmetic
-> partial-product / reduction logic
-> accumulation
-> accumulator register
```

The synthesized final design also uses:

```text
2 x RAMB18E1
96 x CARRY4
465 LUT
138 FF
```

The critical path specifically starts at the BRAM output and crosses a long carry-heavy arithmetic network.

This means the architecture is asking one clock cycle to perform too much useful work.

---

## 4. Why the XDC must not be changed to hide the violation

The clock constraint:

```text
period = 10.000 ns
```

is the design requirement.

Changing it to a slower period would only change the requirement seen by STA.

It would not improve the actual datapath.

For example:

```text
current path ≈ 13.433 ns
```

If the constraint were changed to 15 ns, the report might pass, but the architecture would no longer be proven at the intended 100 MHz target.

The project target is 100 MHz, so timing closure should first be attempted architecturally.

---

## 5. Core timing-closure principle: reduce combinational work per cycle

The current failing cycle is conceptually:

```text
Cycle N:
BRAM registered output
     ↓
large arithmetic network
     ↓
accumulator register
```

To improve timing, place another sequential boundary inside that work:

```text
Cycle N:
BRAM output
     ↓
smaller arithmetic stage
     ↓
PIPELINE REGISTER

Cycle N+1:
pipeline register
     ↓
remaining arithmetic / accumulation
     ↓
accumulator register
```

The total arithmetic may remain approximately the same.

What changes is the maximum combinational depth between registers.

This is the central idea of pipelining.

---

## 6. Throughput versus latency

Pipelining normally trades latency for clock frequency.

Suppose the current computation requires one arithmetic stage between memory output and accumulation.

If one pipeline stage is inserted:

```text
old:
BRAM -> arithmetic -> accumulator
1 cycle

new:
BRAM -> partial arithmetic -> register
register -> remaining arithmetic -> accumulator
2 cycles
```

The transaction latency increases by at least one cycle unless the control schedule overlaps work.

At 100 MHz:

```text
1 extra cycle = 10 ns
```

That is acceptable if the original 70 ns accelerator latency becomes, for example, 80 ns, provided we derive and verify the new schedule.

Timing closure is more important than preserving an arbitrary earlier cycle count.

---

## 7. Why simply adding a register somewhere is not enough

A pipeline register must preserve functional alignment.

The engine consumes:

```text
activation word
weight word
address / word identity
valid/read-enable timing
accumulator state
final-word indication
```

If arithmetic data is delayed by one cycle, related control information must be delayed consistently.

Otherwise the design can accidentally combine:

```text
activation word N
with
control state for word N+1
```

or assert `done` before the final accumulated value is actually registered.

Therefore every timing fix must answer:

```text
What data is registered?
What valid/control bit follows it?
When is accumulator updated?
When is final result declared valid?
When does engine_done occur?
```

---

## 8. Where the most useful pipeline boundary is likely to be

The measured path begins at the BRAM output and ends at `accumulator_reg[31]`.

That tells us the problem is inside the memory-to-accumulator datapath.

A useful conceptual split is:

```text
Stage A:
BRAM word
-> unpack lanes
-> signed multiply / lane products
-> partial reduction
-> pipeline register

Stage B:
registered partial sum
-> accumulate with previous accumulator
-> accumulator register
```

This separates:

```text
lane arithmetic / reduction
```

from:

```text
accumulation carry chain
```

instead of forcing both into one cycle.

The exact RTL location must be chosen only after the dataflow is inspected and the cycle schedule is redesigned.

---

## 9. Another possible boundary: register BRAM outputs

Vivado reported that no optional output register could be merged into the BRAM.

A possible timing technique is to introduce an explicit pipeline register immediately after the BRAM output:

```text
RAMB18E1
-> operand register
-> arithmetic
-> accumulator
```

This can reduce BRAM-to-logic routing pressure and give implementation more freedom.

However, if the downstream arithmetic alone still exceeds 10 ns, one BRAM-output register may not be enough.

The measured logic depth is 17 levels and includes roughly ten CARRY4 elements, so the arithmetic itself must be considered.

---

## 10. Why the long CARRY4 chain matters

A `CARRY4` primitive implements fast carry propagation across four bits.

Carry logic is efficient, but a long serial carry chain still has delay.

The critical path includes roughly:

```text
10 x CARRY4
```

which represents substantial carry propagation.

This suggests the path contains wide addition or accumulation logic.

Therefore the timing fix should aim to avoid forcing a wide reduction plus a wide accumulator addition into the same cycle.

---

## 11. The schedule consequence

The original memory engine was behaviorally verified with three operand-word requests:

```text
word 0
word 1
word 2
```

and one-clock synchronous memory behavior.

If a new pipeline stage is introduced, the schedule may conceptually become:

```text
request word 0
receive word 0
compute partial 0
accumulate partial 0

request word 1
receive word 1
compute partial 1
accumulate partial 1

request word 2
receive word 2
compute partial 2
accumulate partial 2
done
```

but the exact number of states/cycles depends on where the register is inserted.

The old seven-cycle latency must not be assumed after redesign.

It must be re-derived.

---

## 12. Prediction target before RTL modification

Before editing RTL, Step 3 must predict:

```text
new number of pipeline stages
new memory-to-accumulator schedule
new core latency
new initiation interval
expected critical-path location
expected WNS direction
expected FF increase
expected LUT/CARRY impact
expected BRAM count
expected DSP count
```

Example of the kind of prediction required:

```text
one added 32-bit/partial-sum pipeline register
-> approximately +N flip-flops

one extra dataflow cycle
-> latency increases by 10 ns at 100 MHz

BRAM count
-> expected unchanged

DSP count
-> expected unchanged unless arithmetic mapping changes
```

Exact numbers must come from the actual selected architecture, not guesswork.

---

## 13. Why implementation must be re-run after the change

A successful simulation after pipelining proves functional scheduling.

It does not prove timing closure.

The new flow must again be:

```text
RTL change
-> simulation
-> synthesis
-> utilization comparison
-> implementation
-> post-route STA
```

The success condition is not merely:

```text
WNS improved
```

It is:

```text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
```

at the intended 10 ns period.

---

## 14. What must remain unchanged functionally

Timing optimization must preserve the accelerator's architectural result.

For the board test vector:

```text
activations = 1..9
weights     = all 1
accumulator = 45
M_INT       = 3
FRAC_BITS   = 2
output      = 34 = 0x22
```

Therefore after redesign:

```text
LED1 = ON
LED5 = ON
LED8 = done indication
```

must still hold.

The architecture may take more cycles, but it may not change the numerical result or transaction semantics.

---

## 15. Explicit assumptions

1. The target remains Basys 3 / XC7A35T-1CPG236C.
2. The target clock remains 100 MHz.
3. The clock requirement remains 10 ns.
4. Current measured WNS is -3.453 ns.
5. Current measured TNS is -99.753 ns.
6. Hold timing already passes with WHS +0.197 ns.
7. Current critical path begins at the activation BRAM and ends at the accumulator.
8. Current data-path delay is 13.433 ns.
9. Current critical path contains 17 logic levels.
10. BRAM inference is correct and should be preserved.
11. Functional output 0x22 must remain unchanged.
12. No RTL modification is permitted until the design and prediction steps are completed and understood.

---

## 16. Teaching conclusion

The timing failure exists because the current design performs too much combinational arithmetic between the BRAM output and accumulator register in one 10 ns cycle.

The timing-closure strategy is therefore:

```text
preserve 100 MHz constraint
preserve BRAM inference
preserve arithmetic result
reduce combinational depth per cycle
add/register an appropriate pipeline boundary
update control/data alignment
accept and derive any latency increase
re-verify function
re-measure post-route timing
```

The timing fix is an architectural redesign, not an XDC workaround.

---

## 17. Understanding gate

Before Step 2 `/design basys3_timing_closure`, explain in your own words:

1. Why does the BRAM-to-accumulator path fail at 100 MHz?
2. Why must the 10 ns XDC remain unchanged?
3. What is the purpose of adding a pipeline register?
4. Why can a pipeline register change transaction latency?
5. Why must control/valid information be delayed together with pipelined data?
6. Why might a register immediately after BRAM help but still not be sufficient?
7. Why does a long CARRY4 chain indicate a useful place to split arithmetic?
8. What functional result must remain unchanged after timing optimization?
9. Which reports must be rerun after the RTL change?
10. What exact timing conditions constitute closure at 100 MHz?
