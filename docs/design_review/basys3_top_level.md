# Basys 3 Top-Level Integration — Design Review

**Role:** Design Reviewer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 10 — `/review basys3_top_level`  
**Status:** BEHAVIORALLY APPROVED — physical FPGA sign-off remains pending.

---

## 1. Review Objective

This review evaluates whether the Phase-8 Basys-3 integration preserves the previously verified accelerator architecture and whether the available verification evidence supports the intended board-wrapper behavior.

The review separates two evidence domains:

```text
Behavioral / architectural evidence
-> RTL structure
-> XSim protocol behavior
-> measured latency
-> memory sequencing
-> board-visible result/status behavior

Physical FPGA evidence
-> synthesis resource mapping
-> BRAM/DSP primitive use
-> implemented timing
-> board pin constraints
-> hardware demonstration
-> power
```

The first domain now has substantial evidence.

The second domain is still incomplete and therefore cannot be signed off.

---

## 2. Reviewed Implementation

The Phase-8 implementation is divided into:

```text
rtl/infrastructure/button_conditioner.v
rtl/memory/operand_bram_dual_read.v
rtl/top/basys3_top_level.v
```

with the existing accelerator core retained as:

```text
rtl/top/convolution_integration.v
```

This module separation is consistent with the design objective established earlier:

```text
board wrapper
-> physical/platform responsibilities

convolution_integration
-> accelerator transaction/control/computation responsibilities
```

No second convolution datapath, second requantizer, or duplicate accelerator FSM was added to the board top.

---

## 3. Architectural Boundary Review

### 3.1 Core responsibilities

The existing core retains ownership of:

```text
transaction sequencing
memory request generation
activation/weight logical addresses
four-lane INT8 multiply/reduction
INT32 accumulation
requantization / ReLU
architectural activation_out
busy / done protocol
```

### 3.2 Board-wrapper responsibilities

The Phase-8 top owns:

```text
100 MHz board clock entry
physical start/reset button conditioning
start pulse generation
busy-time start masking
physical/inferred operand memory
connection of core request/data buses
board-visible result LEDs
persistent done indication
eventual board constraints / pin mapping
```

### Review conclusion

**PASS — architectural ownership is clean.**

The Phase-8 top integrates the existing accelerator rather than reimplementing it.

---

## 4. Button-Conditioning Review

The reusable `button_conditioner` contains:

```text
2-FF synchronizer
stable-time debounce counter
accepted stable level
previous-level register
rising-edge pulse
```

The default hardware parameters are:

```text
STABLE_CYCLES = 1,000,000
COUNTER_WIDTH = 20
```

At 100 MHz:

```text
1,000,000 cycles x 10 ns
= 10,000,000 ns
= 10 ms
```

and:

```text
2^19 = 524,288   < 1,000,000
2^20 = 1,048,576 >= 1,000,000
```

so the 20-bit counter width remains correctly derived.

The counter is activity-driven: it resets to zero while the synchronized input agrees with the accepted level. It therefore does not free-run continuously when the button state is stable.

The synchronizer registers carry the Xilinx:

```text
ASYNC_REG = "TRUE"
```

attribute.

### Review conclusion

**PASS behaviorally.**

XSim verified bounce rejection, stable-press acceptance, held-button single-start behavior, and the cleaned reset path.

### Physical caveat

The reset conditioner relies on FPGA register initialization for deterministic startup because its clean reset level cannot reset itself.

That is an intentional FPGA-specific design choice and must be confirmed under the final Vivado implementation/board flow rather than treated as portable generic RTL behavior.

---

## 5. Start Protocol and Busy-Mask Review

The wrapper implements:

```text
core_start = start_rise & ~core_busy
```

This means:

```text
start event while idle
-> accepted

start event while busy
-> discarded
```

The behavior matches the approved Phase-7 legal-start contract; no queue is introduced.

The testbench explicitly verified the internal condition:

```text
start_rise = 1
core_busy  = 1
=> core_start = 0
```

rather than depending only on the timing of a physical button press.

### Review conclusion

**PASS.**

The busy mask is both architecturally appropriate and behaviorally verified.

---

## 6. Operand-Memory Architecture Review

The memory module declares one shared logical array:

```text
512 x 32 bits
= 16,384 bits
```

Activation and weight regions are separated by address:

```text
activation physical region: 0..2
weight physical region:     256..258
```

The wrapper presents these as two logical interfaces to the accelerator.

The memory has two registered read processes, allowing activation and weight data to be requested during the same transaction cycle.

The intended read contract remains:

```text
request at cycle N
-> returned word associated with that synchronous request
-> consumed according to the existing Phase-7 schedule
```

The array carries:

```text
ram_style = "block"
```

to request block-memory implementation.

### Review conclusion

**PASS at the architectural/behavioral level.**

The one-clock synchronous memory behavior was checked in XSim and the logical request sequencing was verified.

### Physical caveat

The attribute is **not proof** of BRAM inference.

The acceptance criterion remains:

```text
final synthesis must report non-zero block RAM use
```

The expected physical organization is approximately one BRAM tile equivalent, but exact RAMB18/RAMB36 mapping is still unmeasured.

---

## 7. Board Demonstration Arithmetic Review

The initialized demonstration vectors are:

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

The independent accumulator is:

```text
1+2+3+4+5+6+7+8+9
= 45
```

For:

```text
M_INT     = 3
FRAC_BITS = 2
```

requantization is:

```text
product = 45 x 3 = 135
bias    = 2^(2-1) = 2
rounded = 135 + 2 = 137
result  = 137 >> 2 = 34
```

Therefore:

```text
expected = 34 decimal
         = 0x22
         = 0010_0010
```

The final XSim waveform reported:

```text
led_result = 0x22
```

### Review conclusion

**PASS — exact numerical match.**

---

## 8. Accelerator Latency Review

The pre-RTL prediction was:

```text
7 cycles x 10 ns = 70 ns
```

The measured final recovery transaction recorded:

```text
accepted_start_time = 1065 ns
raw_done_time       = 1135 ns
```

Therefore:

```text
1135 ns - 1065 ns
= 70 ns
```

Measured error relative to prediction:

```text
70 ns - 70 ns = 0 ns
```

### Review conclusion

**PASS — exact quantitative match.**

The board wrapper did not alter the established seven-cycle core latency after `core_start` was accepted.

---

## 9. Memory-Transaction Review

Each operand consists of nine INT8 values.

Useful bytes per operand:

```text
9 x 1 byte = 9 bytes
```

Useful bytes for activation + weight:

```text
9 + 9 = 18 bytes
```

Packing four INT8 values per 32-bit word requires:

```text
ceil(9 / 4) = 3 words per operand
```

Physical bytes:

```text
3 activation words x 4 bytes = 12 bytes
3 weight words     x 4 bytes = 12 bytes

total = 24 bytes
```

Packing efficiency:

```text
18 / 24 = 75%
```

The testbench measured:

```text
request_count = 3 paired request cycles
```

which corresponds to:

```text
3 activation reads
+
3 weight reads
=
6 total 32-bit word reads
```

The assertions additionally required logical address order:

```text
0 -> 1 -> 2
```

and verified the previous-request data association required by the one-clock synchronous contract.

### Review conclusion

**PASS behaviorally.**

---

## 10. Completion Observability Review

The raw core `done` signal remains a one-cycle protocol event.

The board top adds:

```text
done_latched
```

with the policy:

```text
reset        -> clear
new core_start -> clear
core_done    -> set
otherwise    -> hold
```

This preserves the accelerator protocol while giving a human-visible board indication.

The completed simulation ended with:

```text
led_done  = 1
btn_start = 0
btn_reset = 0
```

showing that the completion indication remains visible after the transaction and after release of the start button.

### Review conclusion

**PASS.**

The observability logic is correctly kept outside the core transaction semantics.

---

## 11. Reset Verification Review

The first reset-abort test initially failed because it incorrectly required a physical, synchronized, debounced pushbutton reset to abort a 70 ns accelerator transaction before normal completion.

That assumption was invalid.

For the hardware debounce interval:

```text
10 ms = 10,000,000 ns
```

Compared with:

```text
compute latency = 70 ns
```

the ratio is approximately:

```text
10,000,000 / 70
≈ 142,857
```

Therefore the physical human-interface reset is vastly slower than the accelerator transaction.

The corrected verification separated:

```text
physical reset button
-> verify synchronization/debounce/eventual clear

clean internal reset_level while busy
-> verify synchronous transaction abort
```

The corrected testbench passed with zero errors without requiring an accelerator RTL change.

### Review conclusion

**PASS after verification-model correction.**

This debug episode improved the verification model rather than hiding an RTL defect.

---

## 12. Behavioral Verification Coverage Review

The completed XSim sequence checked:

```text
TEST 1  physical reset path
TEST 2  bounce rejection
TEST 3  full transaction + protocol checks
TEST 4A physical reset during active transaction -> eventual clear
TEST 4B clean reset_level abort while busy
TEST 5  post-reset recovery
```

Final result:

```text
PASS: tb_basys3_top_level completed with zero errors
$finish at 1210 ns
```

Measured final recovery state included:

```text
led_result            = 0x22
led_done              = 1
error_count           = 0
accepted_start_count  = 1
raw_done_count        = 1
request_count         = 3
```

### Review conclusion

**PASS — sufficient behavioral evidence for the directed board-demo configuration.**

This does not imply exhaustive formal verification of every possible button timing or all parameter combinations.

---

## 13. Prediction-vs-Measurement Review

Behavioral quantities directly measured in XSim agree with the pre-RTL predictions:

| Quantity | Prediction | Measurement | Review |
|---|---:|---:|---|
| Clock period | 10 ns | 10 ns | PASS |
| Core latency | 70 ns | 70 ns | PASS |
| Paired request cycles | 3 | 3 | PASS |
| Address order | 0 -> 1 -> 2 | assertions passed | PASS |
| Memory behavior | one-clock synchronous | assertions passed | PASS |
| Result | 34 / 0x22 | 34 / 0x22 | PASS |
| Final accepted starts | 1 | 1 | PASS |
| Final raw done events | 1 | 1 | PASS |
| Persistent done LED | expected | asserted | PASS |
| Behavioral errors | 0 | 0 | PASS |

The review therefore finds no unexplained behavioral divergence between the approved design, the Step-3 prediction model, and the Step-8 simulation evidence.

---

## 14. Physical-Implementation Review — Pending Items

The following predictions remain **unverified** for `basys3_top_level`:

```text
bonded IOB count               predicted about 12
Slice FF                       predicted about 130..150
LUT                            predicted about 450..550
CARRY4                         predicted about 85..100
DSP48E1                        predicted 0 likely
Block RAM                      required > 0
BRAM tile equivalent           expected about 1
100 MHz routed setup closure   expected pass
100 MHz routed hold closure    expected pass
final critical path            predicted accumulator / debounce candidates
power                          unmeasured
```

These cannot be upgraded from predictions to measured facts until final top-level synthesis and implementation reports are supplied.

### Required evidence

Physical sign-off must include at least:

```text
post-synthesis utilization report
BRAM primitive / block RAM tile usage
DSP usage
LUT / FF / CARRY4 usage
bonded I/O utilization
clock resource utilization
post-route timing summary
WNS / TNS
WHS / THS
critical-path report
```

---

## 15. Constraints Review

The repository's `vivado/constraints` directory currently contains only:

```text
relu_timing_wrapper.xdc
requantize_timing_wrapper.xdc
```

A dedicated Basys-3 board XDC for `basys3_top_level` is not yet present.

Therefore the following remain unresolved:

```text
clk_100mhz package pin
btn_start package pin
btn_reset package pin
led_result[7:0] package pins
led_done package pin
IOSTANDARD declarations
board-level create_clock constraint
```

### Review conclusion

**PHYSICAL SIGN-OFF BLOCKER.**

The design cannot be considered board-ready until a correct Basys-3 XDC is created and used for implementation.

---

## 16. Clocking and CDC Review

The top uses one 100 MHz clock domain.

No secondary fabric clock is generated for button handling.

Asynchronous board buttons enter through two-stage synchronizers before ordinary control logic.

This avoids unnecessary internal clock-domain crossings and avoids manually gating the normal fabric clock.

### Review conclusion

**PASS architecturally.**

Final timing/CDC implementation evidence remains to be inspected after synthesis/implementation.

---

## 17. Low-Power Review

The wrapper follows several low-activity design choices:

```text
single 100 MHz clock domain
no secondary slow fabric clock
debounce counters hold when inputs are stable
operand memory read enables active only during transaction requests
done_latched toggles only on event boundaries
no continuously multiplexed seven-segment display
```

These are architecturally consistent with the low-power project objective.

However, no numeric power result is available.

### Review conclusion

**PASS as an architectural low-switching strategy; numeric power claim pending.**

Power cannot be signed off until implementation and activity-based estimation or measurement is available.

---

## 18. Review Findings

### Finding R1 — Behavioral integration

**Status: PASS**

The board wrapper integrates the existing accelerator without duplicating compute/control logic.

### Finding R2 — Human input conditioning

**Status: PASS behaviorally**

Synchronization, debounce, single-pulse generation, and busy masking are verified in XSim.

### Finding R3 — Memory protocol

**Status: PASS behaviorally**

Three paired logical requests, address order 0 -> 1 -> 2, and the one-clock synchronous memory contract are verified.

### Finding R4 — End-to-end arithmetic

**Status: PASS**

Predicted result 34 exactly matches measured `0x22`.

### Finding R5 — Core latency

**Status: PASS**

Predicted 70 ns exactly matches measured 70 ns.

### Finding R6 — Completion observability

**Status: PASS**

The persistent done LED is separated correctly from raw core protocol timing.

### Finding R7 — Reset model

**Status: PASS after test correction**

The verification model now correctly separates physical reset latency from the clean synchronous-reset contract.

### Finding R8 — BRAM mapping

**Status: OPEN / BLOCKED ON SYNTHESIS**

`ram_style="block"` requests BRAM but does not prove it.

### Finding R9 — Final resource utilization

**Status: OPEN / BLOCKED ON SYNTHESIS**

The predicted LUT/FF/CARRY/DSP/IOB counts remain unmeasured.

### Finding R10 — Final routed timing

**Status: OPEN / BLOCKED ON IMPLEMENTATION**

No board-top WNS/TNS/WHS/THS evidence exists yet.

### Finding R11 — Board constraints

**Status: OPEN / BLOCKER**

No dedicated `basys3_top_level` Basys-3 XDC currently exists in the repository.

### Finding R12 — Physical board operation

**Status: OPEN**

No bitstream/programmed-board demonstration evidence has yet been reviewed.

---

## 19. Review Decision

### Behavioral decision

```text
BEHAVIORAL DESIGN REVIEW: APPROVED
```

The evidence supports the Phase-8 top-level architecture and directed RTL behavior.

### Physical decision

```text
PHYSICAL FPGA SIGN-OFF: NOT YET APPROVED
```

The unresolved blockers are:

```text
dedicated Basys-3 XDC
final top synthesis
confirmed non-zero BRAM mapping
final utilization
final implementation
post-route timing closure
hardware board demonstration
```

This distinction is mandatory.

A passing behavioral simulation must not be described as proof that the design is physically ready for the FPGA.

---

## 20. Required Next Physical Actions

Before Phase 8 can be called physically complete:

```text
1. Create dedicated basys3_top_level XDC
2. Synthesize basys3_top_level with hardware parameters
3. Inspect resource utilization
4. Confirm BRAM > 0
5. Confirm actual DSP mapping
6. Implement/place/route
7. Inspect WNS/TNS/WHS/THS
8. Inspect critical path
9. Generate bitstream
10. Program Basys 3
11. Verify reset/start/result/done behavior on hardware
12. Update measured analysis with physical results
13. Revisit this review for final physical closure
```

These steps are physical-validation work, not additional proof of the already-passed behavioral transaction logic.

---

## 21. Step-10 Review Summary

The Phase-8 Basys-3 wrapper has successfully crossed the behavioral integration boundary.

What is now supported by evidence:

```text
architectural separation        verified
button protocol                 verified behaviorally
busy masking                    verified behaviorally
memory request sequencing       verified behaviorally
one-clock memory contract       verified behaviorally
core latency                    70 ns measured
nominal result                  34 measured
persistent completion status    verified behaviorally
reset/recovery protocol         verified behaviorally
prediction-vs-XSim consistency  verified
```

What remains open:

```text
Basys-3 XDC                     missing
BRAM mapping                    unmeasured
resource utilization            unmeasured
DSP mapping                     unmeasured
post-route timing               unmeasured
critical path                   unmeasured for final top
power                           unmeasured
physical board operation        unmeasured
```

Therefore the appropriate review status is:

```text
Behavioral architecture: APPROVED
Physical implementation: PENDING
Phase-8 physical completion: NOT YET CLAIMED
```

---

## 22. Understanding Gate Before Step 11

Before the final knowledge-test step, the learner must be able to explain:

1. Why behavioral approval does not equal physical FPGA sign-off.
2. Which evidence proves the 70 ns latency and result 34.
3. Why `ram_style="block"` is not enough to claim BRAM use.
4. Why the lack of a dedicated Basys-3 XDC blocks board readiness.
5. Which final Vivado reports are needed to prove resources and 100 MHz timing.
6. Why the original physical-reset-abort test was invalid and why the corrected split is better.
7. Which parts of Phase 8 are already proven and which remain open.

**Review gate:** Step 11 may proceed only after these distinctions are restated correctly.
