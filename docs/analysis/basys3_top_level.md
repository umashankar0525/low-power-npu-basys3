# Basys 3 Top-Level Integration — Prediction Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 3 — `/analyze basys3_top_level`  
**Status:** PREDICTION ONLY — no Phase-8 top-level RTL, synthesis, implementation, or board measurement has been performed yet.

---

## 1. Purpose of This Analysis

This document predicts the behavior and physical cost of the Phase-8 `basys3_top_level` **before RTL is generated**.

The purpose is to create measurable expectations for:

```text
button-conditioning latency
core transaction latency
machine initiation interval
memory traffic and bandwidth
wrapper register count
LUT/CARRY cost
BRAM mapping expectation
DSP expectation
final board I/O count
timing-risk locations
100 MHz closure expectation
```

After the RTL is built, simulated, synthesized, and implemented, these predictions must be compared against measurements. A later Vivado report is not allowed to silently replace the predictions; differences must be explained.

---

## 2. Explicit Assumptions

These assumptions are the basis of every prediction below.

1. Target device is `XC7A35T-1CPG236C` on Basys 3.
2. System clock remains 100 MHz.
3. Therefore:

```text
Tclk = 1 / 100,000,000
     = 10 ns
```

4. `convolution_integration` remains the compute core and its computational architecture is not duplicated.
5. Final board-bring-up parameters are:

```text
M_INT     = 3
FRAC_BITS = 2
```

6. The start and reset buttons each use:

```text
2-FF synchronizer
20-bit stable-time debounce counter
1 accepted stable-state bit
```

7. Start additionally uses one previous-state bit for rising-edge detection.
8. The debounce threshold is 1,000,000 consecutive 100 MHz cycles = 10 ms.
9. A busy-time start event is discarded, not queued.
10. Activation and weight memory reads remain one-clock synchronous.
11. Activation and weight are two logical memories and are read in parallel.
12. Each logical operand memory stores three 32-bit words.
13. Physical BRAM organization is intentionally not fixed yet. The final physical solution may be one shared block-memory structure with two read ports or two operand memories packed into block-memory resources, but **non-zero BRAM use is an acceptance requirement**.
14. Result LEDs connect directly to the already-registered `activation_out`; no second 8-bit result register is predicted.
15. `done_latched` is one wrapper register.
16. Exact LUT/FF/CARRY/DSP/BRAM mapping is a synthesis result; resource values in this document are predictions derived from logical structure and the measured Phase-8 core baseline.
17. Exact WNS/WHS cannot be known before placement/routing. Timing predictions therefore identify expected pass/fail status and likely critical-path candidates rather than fabricating exact slack values.

---

## 3. Measured Core Baseline Used for Comparison

The already-completed core-only implementation measured `convolution_integration` with:

```text
M_INT     = 1
FRAC_BITS = 0
```

and reported:

```text
LUTs   = 386
FFs    = 88
CARRY4 = 75
DSP    = 0
BRAM   = 0
IOB    = 83
BUFG   = 1

WNS  = +6.072 ns
TNS  =  0.000 ns
WHS  = +0.168 ns
THS  =  0.000 ns
```

The routed worst setup path was the accumulator feedback path with:

```text
data-path delay = 3.903 ns
logic levels    = 8
approximately 6 x CARRY4 + LUT logic
```

This baseline is useful, but it is **not identical to the final board configuration** because the final board uses `M_INT=3`, `FRAC_BITS=2`, adds memories and board infrastructure, and has a much smaller physical I/O interface.

---

## 4. Board Demonstration Arithmetic Prediction

The initialized activation values are:

```text
[1,2,3,4,5,6,7,8,9]
```

The weights are nine ones.

Therefore the convolution accumulator is:

```text
acc = 1+2+3+4+5+6+7+8+9
    = 45
```

ReLU leaves 45 unchanged because it is positive.

With:

```text
M_INT = 3
F     = 2
```

product:

```text
45 x 3 = 135
```

rounding bias:

```text
2^(F-1) = 2^(2-1) = 2
```

rounded value:

```text
135 + 2 = 137
```

right shift:

```text
137 >> 2 = floor(137 / 4)
         = 34
```

No saturation is required because 34 is inside the legal ReLU INT8 range 0..127.

Predicted architectural output:

```text
activation_out = 34 decimal
               = 0b0010_0010
```

Predicted board result LEDs:

```text
LED[5] = 1
LED[1] = 1
all other result LEDs = 0
```

---

## 5. Machine-Level Core Timing Prediction

The board wrapper does not alter the internal Phase-7 transaction schedule.

Once a legal `core_start` is accepted:

```text
core_start -> core_done = 7 cycles
```

At 100 MHz:

```text
7 cycles x 10 ns/cycle = 70 ns
```

Therefore the predicted compute latency remains:

```text
70 ns
```

The earliest next legal accepted core start remains separated by nine cycles:

```text
9 x 10 ns = 90 ns
```

Predicted machine initiation interval:

```text
II = 90 ns
```

Predicted maximum machine-level transaction rate, assuming an automated source rather than a human button:

```text
transaction rate
= 1 / 90 ns
= 1 / (90 x 10^-9)
= 11.111... x 10^6 transactions/s
= 11.11 Mtransactions/s
```

Each transaction performs nine useful MAC operations.

Therefore:

```text
9 MAC/transaction x 11.11 Mtransaction/s
= approximately 100 MMAC/s
```

Using the convention `1 MAC = 2 arithmetic operations`:

```text
approximately 200 MOPS
```

These are machine-level accelerator figures. A human pushbutton cannot exercise the accelerator at this rate.

---

## 6. Button-to-Core-Start Latency Prediction

### 6.1 Synchronizer contribution

A physical button transition is asynchronous to the clock.

The selected input chain uses two synchronizer stages. From the first clock edge that samples the changed physical input, two sequential sampling stages are required before the synchronized level is available to ordinary logic.

At 100 MHz, two clock intervals correspond to:

```text
2 x 10 ns = 20 ns
```

Because the physical transition can occur anywhere relative to the clock edge, wall-clock synchronization delay from the actual mechanical transition is phase-dependent. The deterministic architectural point is that the debouncer does not act on the raw button; it acts on the two-stage synchronized level.

### 6.2 Debounce contribution

Required stable interval:

```text
10 ms
```

At 100 MHz:

```text
100,000,000 cycles/s x 0.010 s
= 1,000,000 cycles
```

Therefore the synchronized input must disagree with the currently accepted debounced state for 1,000,000 consecutive cycles before the new state is accepted.

### 6.3 Counter width derivation

The counter must represent at least the range needed for one million consecutive cycles.

```text
2^19 =   524,288 < 1,000,000
2^20 = 1,048,576 >= 1,000,000
```

Therefore:

```text
minimum debounce counter width = 20 bits
```

### 6.4 Edge-detection/acceptance contribution

After the debounced start state changes from 0 to 1, the edge detector produces one 100 MHz-cycle event.

Pulse width:

```text
1 cycle x 10 ns = 10 ns
```

The exact edge on which the core samples this pulse depends on the eventual sequential implementation, but the wrapper contributes only approximately one additional cycle after the 10 ms stability decision.

Therefore the expected button-conditioning latency is approximately:

```text
10 ms debounce
+ approximately 2 synchronization cycles
+ approximately 1 pulse/acceptance cycle
```

or roughly:

```text
10 ms + approximately 30 ns
```

The 30 ns-scale digital overhead is negligible compared with the 10 ms mechanical debounce interval.

### 6.5 Total button-to-result scale

After a valid `core_start`, the compute core requires another 70 ns.

Therefore a human-observed press-to-result event is expected on the scale of:

```text
approximately 10 ms + tens of nanoseconds
```

The key distinction is:

```text
human-interface latency ≈ 10 ms
compute latency         = 70 ns
```

The 10 ms interval must never be reported as NPU compute latency.

---

## 7. Maximum Repeated Button-Press Rate

To produce repeated rising edges through a debouncer, the input must normally be stably high long enough to accept a press and stably low long enough to accept a release.

Minimum idealized stable time per full high-low cycle:

```text
10 ms high + 10 ms low = 20 ms
```

Therefore the theoretical button-interface event ceiling is approximately:

```text
1 / 20 ms = 50 start events/s
```

This is still much faster than realistic deliberate human presses, but it is enormously slower than the core's machine initiation rate:

```text
button path: <= approximately 50 starts/s
core path:      approximately 11.11 million starts/s
```

This difference is intentional. The button exists for demonstration, not throughput benchmarking.

---

## 8. Memory Request Count and Address Prediction

The Phase-7 engine reads four INT8 lanes per 32-bit word.

Nine values require:

```text
ceil(9/4) = 3 words
```

Therefore the activation memory sees three requests:

```text
address 0
address 1
address 2
```

and the weight memory sees the same three logical addresses.

Predicted per transaction:

```text
activation reads = 3
weight reads     = 3
total word reads = 6
```

Because activation and weight are requested in parallel, there are three request cycles, not six serialized request cycles.

---

## 9. Memory Traffic Derivation

Each physical word is 32 bits = 4 bytes.

Activation traffic:

```text
3 words x 4 bytes = 12 bytes
```

Weight traffic:

```text
3 words x 4 bytes = 12 bytes
```

Total physical traffic per transaction:

```text
12 + 12 = 24 bytes
```

Useful operands are eighteen INT8 values:

```text
18 x 1 byte = 18 useful bytes
```

Packing efficiency:

```text
18 / 24 = 0.75 = 75%
```

Padding overhead:

```text
24 - 18 = 6 bytes
```

or:

```text
25% of transferred operand capacity
```

---

## 10. Internal Memory Bandwidth Prediction

Each request cycle reads in parallel:

```text
32 activation bits + 32 weight bits = 64 bits
```

At 100 MHz, the architectural peak read-port rate is:

```text
64 bits/cycle x 100,000,000 cycles/s
= 6.4 x 10^9 bits/s
= 800,000,000 bytes/s
= 800 MB/s
```

This is the peak capability of the two logical read paths when active every cycle.

Using the machine initiation interval of 90 ns and 24 physical bytes per completed transaction:

```text
24 bytes / 90 ns
= 266.67 MB/s sustained physical operand traffic
```

Useful payload bandwidth:

```text
18 bytes / 90 ns
= 200 MB/s useful operand bandwidth
```

Each operand memory contributes half the physical traffic:

```text
12 bytes / 90 ns
= 133.33 MB/s per operand memory
```

These sustained figures assume machine-driven back-to-back transactions. The pushbutton demonstration will operate far below them.

---

## 11. `done_latched` Timing Prediction

The core raw `done` signal remains a one-cycle protocol event:

```text
10 ns at 100 MHz
```

`activation_out` becomes valid according to the established Phase-7 schedule when the controller enters the DONE state.

A conventional synchronous wrapper register samples `core_done` on a clock edge. Since `core_done` becomes high after the edge that enters the core DONE state, the wrapper is expected to latch that high level on the following rising edge.

Therefore:

```text
activation_out valid / raw done asserted : E7
persistent done_latched becomes set       : approximately E8
```

Predicted visible-status delay relative to raw done onset:

```text
1 cycle = 10 ns
```

This extra board-status cycle does **not** change:

```text
core start -> activation_out valid = 70 ns
core start -> raw done              = 70 ns
```

It changes only the human-visible completion indicator.

---

## 12. Final Board I/O Count Prediction

The core-only baseline used 83 bonded I/O because its abstract memory buses were top-level pins.

The final Basys-3 wrapper exposes only:

```text
clk_100mhz       1 input
btn_start        1 input
btn_reset        1 input
led_result[7:0]  8 outputs
led_done         1 output
--------------------------
total           12 I/O
```

Therefore the predicted bonded IOB count is:

```text
12
```

The expected reduction from the core-only baseline is:

```text
83 - 12 = 71 fewer package I/O signals
```

This large reduction occurs because the 64 activation/weight data bits and their control/address lines become internal nets inside the board top instead of physical package pins.

---

## 13. Clocking Resource Prediction

The design uses one direct 100 MHz system clock and deliberately avoids PLL/MMCM-generated secondary clocks.

Predicted clocking resources:

```text
BUFG   = 1
MMCM   = 0
PLL    = 0
BUFR   = 0
```

The exact BUFG primitive count is expected to remain one, matching the existing core baseline.

---

## 14. DSP Prediction for `M_INT = 3`

The four INT8 convolution multipliers were already present in the baseline run and Vivado mapped the full baseline to:

```text
DSP = 0
```

Therefore the four small INT8 multiplies are expected to remain LUT/carry logic.

The board configuration changes the requantization coefficient from:

```text
M_INT = 1
```

to:

```text
M_INT = 3
```

Multiplication by a compile-time constant three can be algebraically expressed as:

```text
x x 3 = (x << 1) + x
```

so a dedicated DSP is not architecturally required.

The maximum positive convolution magnitude is:

```text
9 x 127 x 127
= 9 x 16129
= 145161
```

With `M_INT=3`:

```text
145161 x 3 = 435483
```

Bit-width check:

```text
2^18 = 262144 < 435483
2^19 = 524288 > 435483
```

so only 19 significant unsigned product bits are required for the mathematically reachable positive result under this fixed coefficient.

Prediction:

```text
DSP48E1 = 0 likely
```

because a 19-bit constant-times-three operation can be implemented efficiently as shift-plus-add logic.

This is a prediction, not a guarantee. The synthesis utilization report decides the actual physical mapping.

---

## 15. Wrapper Flip-Flop Prediction

The wrapper requires logical sequential state for button conditioning and status.

### Start path

```text
2 synchronizer FF
20 debounce-counter FF
1 debounced stable-state FF
1 previous-state FF for edge detection
--------------------------------------
24 FF
```

### Reset path

```text
2 synchronizer FF
20 debounce-counter FF
1 debounced stable-state FF
--------------------------------------
23 FF
```

### Board status

```text
1 done_latched FF
```

Total predicted explicit wrapper state:

```text
24 + 23 + 1 = 48 FF
```

The result LEDs do not add eight result FF because they use the existing registered `activation_out` from the core.

### Parameter-change effect inside requantization

For `M_INT=1`, the maximum positive product is 145161, which requires 18 significant bits:

```text
2^17 = 131072 < 145161 < 2^18
```

For `M_INT=3`, the maximum positive product is 435483, which requires 19 significant bits.

Therefore synthesis may retain approximately one additional significant product-register bit compared with the measured `M_INT=1` baseline.

Starting from the measured baseline:

```text
88 core Slice FF
+ approximately 1 extra significant requantization bit
+ 48 wrapper state bits
= approximately 137 Slice FF
```

Prediction center:

```text
approximately 137 Slice FF
```

Expected practical range after synthesis optimization:

```text
approximately 130 to 150 Slice FF
```

This range assumes the synchronous BRAM read behavior maps into block-memory resources rather than creating two additional 32-bit fabric output-register banks.

If synthesis instead implements memory output registers in Slice FFs, the final FF number could be approximately 64 higher. The utilization report will distinguish the cases.

---

## 16. LUT Prediction

The measured core baseline is:

```text
386 LUT
```

We now estimate additional logic from first principles.

### 16.1 Two debounce counters

A 20-bit binary incrementer requires approximately one bit-slice of logic per count bit. On a 7-series FPGA, carry propagation is efficiently implemented through CARRY4 resources while LUTs generate carry/select terms.

Architecture-level estimate per 20-bit counter:

```text
approximately 20 LUT-equivalents for increment/count logic
```

Two counters:

```text
2 x 20 = approximately 40 LUT
```

### 16.2 Threshold comparisons

Each counter must detect a fixed threshold near one million. A fixed-width equality/terminal-count test can require up to roughly one LUT contribution per bit before synthesis factoring.

Estimate:

```text
approximately 20 LUT per threshold test
x 2 buttons
= approximately 40 LUT
```

### 16.3 Debounce/control/edge/status glue

Stable-state control, counter clear/hold selection, start edge detection, busy masking, and done-latched control are small compared with the counters.

Estimate:

```text
approximately 10 to 15 LUT
```

### 16.4 Constant-times-three requantization delta

Compared with `M_INT=1`, multiplication by three can be implemented as one roughly 19-bit addition:

```text
(x << 1) + x
```

Estimate:

```text
up to approximately 19 LUT-equivalents plus carry-chain logic
```

### 16.5 Total

Centered pre-synthesis estimate:

```text
386 baseline
+ 40 counter logic
+ 40 threshold logic
+ approximately 12 wrapper glue
+ approximately 19 x3 requantization logic
= approximately 497 LUT
```

Because Vivado may merge comparisons, exploit dedicated carry logic, trim unreachable bits, and absorb simple equations into existing LUTs, an exact 497 count is not expected.

Prediction:

```text
center: approximately 500 LUT
reasonable pre-synthesis band: approximately 450 to 550 LUT
```

The measured post-synthesis value must later replace the uncertainty band in the measured-analysis update.

---

## 17. CARRY4 Prediction

The measured baseline uses:

```text
75 CARRY4
```

### Debounce incrementers

A 20-bit carry chain requires:

```text
ceil(20 / 4) = 5 CARRY4
```

Two counters:

```text
2 x 5 = 10 CARRY4
```

### Threshold comparisons

If Vivado maps each 20-bit terminal-count comparison into carry-chain compare logic, each could use up to approximately:

```text
ceil(20 / 4) = 5 CARRY4
```

Two comparisons could therefore contribute up to another:

```text
10 CARRY4
```

However, equality to a constant can also be synthesized primarily as LUT logic, so this is not guaranteed.

### Constant-times-three addition

A 19-bit add can require:

```text
ceil(19 / 4) = 5 CARRY4
```

### Resulting prediction

Guaranteed architecture-driven addition from the counters is approximately +10 CARRY4. Comparison and constant-multiply mapping may add up to roughly another +15.

Therefore:

```text
predicted CARRY4 range = approximately 85 to 100
```

with a centered expectation around the low-to-mid 90s.

---

## 18. BRAM Prediction

Logical memory required is extremely small:

```text
activation memory = 3 x 32 = 96 bits
weight memory     = 3 x 32 = 96 bits
combined          = 192 bits
```

The project intentionally requires physical block-memory use even though this capacity is much smaller than one Artix-7 block RAM resource.

Two viable physical organizations remain consistent with the design:

### Scenario A — shared block memory with two independent read ports

Activation and weight regions are stored in one physical block-memory structure and read through independent ports.

Predicted block-memory consumption:

```text
approximately one 36-Kb block-RAM tile equivalent
```

### Scenario B — two separate 32-bit operand memories

Each logical operand is given an independent block-memory primitive/resource.

Because each memory is only 32 bits wide and very shallow, the implementation may use two half-block resources that can occupy one physical block-RAM tile, or an equivalent primitive arrangement depending on inference/instantiation.

Again, the expected tile-level consumption is approximately:

```text
one block-RAM tile equivalent
```

but the primitive report might show, for example, two RAMB18-class resources rather than one RAMB36-class resource.

### Acceptance prediction

The important prediction is not the exact primitive spelling. It is:

```text
Block RAM Tile > 0
```

with a strong expectation of:

```text
approximately 1 tile equivalent
```

because the design explicitly requires BRAM-backed storage.

If synthesis reports zero BRAM, the implementation has failed the chosen Phase-8 memory-mapping acceptance criterion even if functionality is correct.

---

## 19. Final Resource Prediction Summary

The prediction is intentionally separated into exact architectural counts and synthesis-dependent ranges.

```text
Clock                     : 100 MHz, 10 ns
Board I/O                  : 12 bonded signals predicted
BUFG                       : 1 predicted
MMCM / PLL                 : 0 / 0 predicted
Explicit wrapper state     : 48 logical FF
Final Slice FF             : approximately 137 center, roughly 130..150 expected
Final LUT                  : approximately 500 center, roughly 450..550 expected
Final CARRY4               : roughly 85..100 expected
DSP48E1                    : 0 likely for constant M_INT=3
Block RAM Tile             : >0 required; approximately 1 tile equivalent expected
```

All LUT/FF/CARRY/DSP/BRAM values remain predictions until synthesis.

---

## 20. Timing-Risk Analysis

### 20.1 Existing core path

The measured baseline critical path is the accumulator feedback path:

```text
approximately 6 CARRY4 stages + LUT logic
3.903 ns data-path delay
```

against a 10 ns requirement.

### 20.2 New debounce paths

A 20-bit incrementer spans approximately:

```text
ceil(20/4) = 5 CARRY4 stages
```

which is structurally slightly shorter in carry depth than the existing six-CARRY4 accumulator critical path.

The threshold comparison is to a fixed constant. Depending on synthesis it may be a LUT tree, a carry compare, or a combination.

Because the counter, comparison, and state update are local wrapper paths rather than being inserted into the convolution accumulator feedback loop, they do not lengthen the existing compute path in series.

### 20.3 `M_INT=3` requantization path

The constant-times-three operation can be reduced to one approximately 19-bit add, corresponding to roughly five CARRY4 stages if mapped as an adder.

Again, this is not inserted into the accumulator feedback path; it feeds the requantizer's registered product stage.

### 20.4 Prediction

The 100 MHz target is expected to close because:

```text
existing routed critical data path = 3.903 ns
clock requirement                  = 10.000 ns
existing setup margin              = about 6.1 ns
new largest arithmetic chains      = about 5 CARRY4 deep
existing critical carry depth      = about 6 CARRY4 + LUTs
```

Therefore the likely critical-path candidates are:

```text
1. existing accumulator feedback path
2. one of the 20-bit debounce counter/terminal-count paths
3. constant-times-three requantization add path
```

The accumulator is predicted to remain the leading candidate, but placement/routing can change path ordering.

Predicted final timing status:

```text
100 MHz setup closure : expected PASS
100 MHz hold closure  : expected PASS
TNS / THS             : expected 0 if closure succeeds
```

No exact WNS or WHS is predicted because those values depend on physical placement, routing, clock skew, and hold fixing.

---

## 21. Throughput Impact of the Wrapper

The board wrapper is outside the compute schedule.

Once a legal `core_start` exists:

```text
compute latency = 70 ns
II              = 90 ns
```

The wrapper does not insert a pipeline stage into the activation/weight-to-compute transaction path beyond the already-required one-clock synchronous memory behavior.

Therefore predicted machine throughput remains:

```text
11.11 Mtransactions/s
100 MMAC/s
```

The pushbutton interface limits manual demonstration rate, not accelerator capability.

---

## 22. Low-Power Activity Prediction

No exact power in milliwatts is predicted before implementation and activity-based power analysis.

However, the expected activity behavior is:

```text
debounce counters hold while button inputs are stable
memory enables are active only for three request cycles per transaction
done_latched toggles only on reset/start/done events
no second fabric clock is generated
no continuously multiplexed seven-segment display is present
```

At continuous machine-level traffic, each operand memory is requested during three cycles of a nine-cycle initiation interval:

```text
3 / 9 = 33.3% request-cycle duty ratio
```

During ordinary human demonstration, the accelerator and memories are idle for almost all wall-clock time, so dynamic switching from the NPU datapath is expected to be very low between button events.

This is a qualitative activity prediction only. Final power claims require Vivado implementation/power evidence and, ideally, representative switching activity.

---

## 23. What Must Be Measured Later

After RTL, verification, synthesis, and implementation, the measured analysis must compare at least:

```text
Predicted output                34
Predicted core latency          70 ns
Predicted core II               90 ns
Predicted read addresses        0 -> 1 -> 2
Predicted total word reads      6
Predicted physical bytes/tx     24
Predicted useful bytes/tx       18
Predicted packing efficiency    75%
Predicted peak internal BW      800 MB/s
Predicted sustained physical BW 266.67 MB/s
Predicted useful BW             200 MB/s
Predicted board IOB             12
Predicted wrapper state         48 logical FF
Predicted final FF              approximately 130..150
Predicted final LUT             approximately 450..550
Predicted final CARRY4          approximately 85..100
Predicted DSP                   0 likely
Predicted BRAM                  >0, approximately 1 tile equivalent
Predicted 100 MHz timing        PASS
Predicted likely critical path  accumulator feedback, with debounce path as a new candidate
```

Any large deviation must be explained from the synthesized or routed netlist rather than dismissed as tool behavior.

---

## 24. Analysis Summary

The important predictions are:

```text
Human button conditioning  : approximately 10 ms
Core compute latency        : 70 ns
Core initiation interval    : 90 ns
Machine transaction rate    : 11.11 M/s
Useful compute rate          : 100 MMAC/s
Board result                 : 34 = 0010_0010
Memory requests              : 3 activation + 3 weight
Physical operand traffic     : 24 bytes/transaction
Useful operand traffic       : 18 bytes/transaction
Packing efficiency           : 75%
Peak internal read bandwidth : 800 MB/s
Sustained physical bandwidth : 266.67 MB/s
Final board I/O              : 12 predicted
Wrapper logical state        : 48 FF
Final FF                     : approximately 130..150 predicted
Final LUT                    : approximately 450..550 predicted
Final CARRY4                 : approximately 85..100 predicted
DSP                          : 0 likely
BRAM                         : non-zero required; approximately 1 tile equivalent expected
100 MHz closure              : expected PASS
Likely timing bottleneck     : accumulator carry feedback; debounce counter is a new candidate
```

The most important architectural distinction is that the approximately 10 ms button delay is a **human-interface conditioning delay**, while the accelerator itself still performs the transaction in 70 ns once `core_start` is accepted.

---

## 25. Understanding Gate

Before Step 4 and any Phase-8 RTL generation, explain the following in your own words:

1. Why does a 10 ms button debounce not mean the NPU has 10 ms compute latency?
2. Derive the predicted 70 ns compute latency and 90 ns initiation interval from the 100 MHz clock.
3. Derive the 24 physical bytes and 18 useful bytes transferred per transaction, and therefore the 75% packing efficiency.
4. Derive the 800 MB/s peak internal read bandwidth and 266.67 MB/s sustained physical bandwidth.
5. Why does the final board top predict only 12 IOBs when the core-only baseline used 83?
6. Derive the 48 explicit wrapper flip-flops from the start path, reset path, and `done_latched` state.
7. Why is `DSP=0` a reasonable prediction for `M_INT=3` even though the RTL uses multiplication?
8. Why is the BRAM prediction stated as non-zero / approximately one tile equivalent instead of claiming an exact RAMB18/RAMB36 primitive count now?
9. Why do we expect 100 MHz timing to pass, and which paths are the leading critical-path candidates?
10. Why must the predicted LUT/FF/CARRY ranges be compared against synthesis measurements instead of treated as exact facts?

**Hard gate:** do not generate `basys3_top_level` RTL until the learner restates the prediction logic correctly.