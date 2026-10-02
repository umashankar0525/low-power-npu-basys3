# Basys 3 Timing Closure — Prediction Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure  
**Workflow stage:** Step 3 — /analyze basys3_timing_closure  
**Status:** PREDICTION ONLY — RTL has not yet been modified.

---

## 1. Purpose

This analysis predicts the architectural and physical consequences of inserting one partial-sum pipeline register between the reduction tree and the INT32 accumulator.

The approved redesign is:

~~~text
Stage A:
BRAM
-> 4 x INT8 products
-> balanced reduction tree
-> sign extension
-> partial_sum_pipe

Stage B:
partial_sum_pipe
-> INT32 accumulator addition
-> accumulator register
~~~

The purpose is to predict, before RTL modification:

~~~text
new transaction latency
new initiation interval
machine transaction rate
MAC throughput
memory bandwidth impact
resource delta
likely new critical-path location
expected timing direction
acceptance criteria
~~~

No measured post-redesign result is claimed in this document.

---

## 2. Explicit assumptions

1. Target device remains XC7A35T-1CPG236C.
2. Board remains Basys 3.
3. Clock remains 100 MHz.
4. Therefore clock period remains 10 ns.
5. Existing routed setup result is WNS = -3.453 ns.
6. Existing TNS is -99.753 ns.
7. Existing critical data-path delay is 13.433 ns.
8. Current synthesized utilization is:
   - LUT = 465
   - FF = 138
   - CARRY4 = 96
   - DSP = 0
   - RAMB18E1 = 2
   - Bonded IOB = 12
   - BUFG = 1
9. BRAM read behavior remains one-clock synchronous.
10. Three paired operand requests remain sufficient.
11. Request order remains 0 -> 1 -> 2.
12. The redesign inserts one signed partial-sum pipeline register.
13. The memory-engine state count increases from five to six states.
14. The state register still needs only three binary bits because ceil(log2(6)) = 3.
15. Vivado may choose one-hot FSM encoding, so physical state-register FF count can differ from the RTL state width.
16. Output must remain 34 / 0x22 for the board demonstration vector.
17. Exact post-route slack cannot be known before implementation.

---

## 3. New memory-engine cycle schedule

The approved schedule is:

~~~text
E0:
start accepted
request word 0

E1:
receive word 0
request word 1

E2:
partial_sum_pipe <= S0
receive word 1
request word 2

E3:
accumulator <= S0
partial_sum_pipe <= S1
receive word 2

E4:
accumulator <= S0 + S1
partial_sum_pipe <= S2

E5:
result <= S0 + S1 + S2
engine_done <= 1
~~~

Compared with the previous engine, one pipeline-fill cycle has been added before the first accumulation.

---

## 4. Top-level latency derivation

The previously measured accepted-start-to-top-level-done latency was:

~~~text
7 cycles
~~~

At 100 MHz:

~~~text
7 x 10 ns
= 70 ns
~~~

The new memory engine completes one cycle later.

The surrounding supervisory controller waits for engine_done and therefore shifts its downstream capture/done sequence by one cycle without requiring a new supervisory state.

Therefore predicted new accepted-start-to-top-level-done latency is:

~~~text
7 + 1
= 8 cycles
~~~

At 100 MHz:

~~~text
8 x 10 ns
= 80 ns
~~~

Prediction:

~~~text
old latency = 70 ns
new latency = 80 ns
delta       = +10 ns
increase    = 10/70 x 100
            = 14.29%
~~~

The extra 10 ns is the direct cost of the added pipeline stage.

---

## 5. Initiation interval derivation

The old top-level machine initiation interval was predicted as:

~~~text
9 cycles
= 90 ns
~~~

The reason it exceeds the seven-cycle done latency is that the supervisory controller must pass through DONE and return to IDLE before a later start can be legally accepted.

With the new engine, completion moves one cycle later.

The same controller tail remains.

Therefore predicted new accepted-start separation is:

~~~text
old II = 9 cycles
+ one added engine cycle
= 10 cycles
~~~

At 100 MHz:

~~~text
10 x 10 ns
= 100 ns
~~~

Prediction:

~~~text
new machine initiation interval = 100 ns
~~~

This assumes the surrounding control behavior remains unchanged, as approved in Step 2.

---

## 6. Maximum machine-driven transaction rate

With:

~~~text
II = 100 ns
~~~

the maximum machine-driven transaction rate is:

~~~text
1 / 100 ns
= 1 / (100 x 10^-9)
= 10,000,000 transactions/s
= 10 Mtransactions/s
~~~

The previous prediction was approximately:

~~~text
11.11 Mtransactions/s
~~~

Therefore throughput reduction is:

~~~text
(11.11 - 10) / 11.11
≈ 0.0999
≈ 10%
~~~

This is the expected cost of adding one non-overlapped engine cycle.

---

## 7. MAC throughput prediction

Each transaction performs nine useful MAC operations.

Therefore:

~~~text
9 MAC/transaction
x 10 Mtransactions/s
= 90 MMAC/s
~~~

If one MAC is counted as two arithmetic operations:

~~~text
90 MMAC/s x 2
= 180 MOPS
~~~

Prediction:

~~~text
machine throughput ≈ 90 MMAC/s
or ≈ 180 MOPS by the 2-ops/MAC convention
~~~

This is a throughput prediction for machine-driven operation, not human pushbutton operation.

---

## 8. Memory traffic and bandwidth prediction

The operand count is unchanged.

Per transaction:

~~~text
3 activation words
+ 3 weight words
= 6 x 32-bit words
= 24 physical bytes
~~~

Useful operand payload remains:

~~~text
18 INT8 values
= 18 bytes
~~~

Because the initiation interval changes from 90 ns to 100 ns, sustained physical operand bandwidth becomes:

~~~text
24 bytes / 100 ns
= 240 MB/s
~~~

Useful operand bandwidth becomes:

~~~text
18 bytes / 100 ns
= 180 MB/s
~~~

Per logical operand memory:

~~~text
12 bytes / 100 ns
= 120 MB/s
~~~

The peak architectural memory-port capability remains unchanged:

~~~text
64 bits/cycle x 100 MHz
= 6.4 Gbit/s
= 800 MB/s
~~~

because the BRAM interface width and clock frequency are unchanged.

---

## 9. Functional arithmetic prediction

The three reduced sums remain:

~~~text
S0 = 1 + 2 + 3 + 4
   = 10

S1 = 5 + 6 + 7 + 8
   = 26

S2 = 9
~~~

Therefore:

~~~text
accumulator
= S0 + S1 + S2
= 10 + 26 + 9
= 45
~~~

Requantization:

~~~text
45 x 3 = 135

rounding bias
= 2^(FRAC_BITS-1)
= 2^(2-1)
= 2

135 + 2 = 137

137 >> 2 = 34
~~~

Therefore the predicted output remains:

~~~text
activation_out = 34
               = 0x22
               = 0010_0010
~~~

The timing optimization must not alter this result.

---

## 10. Flip-flop prediction

The approved design adds one signed 32-bit RTL register:

~~~text
partial_sum_pipe[31:0]
~~~

Naively:

~~~text
+32 FF
~~~

However, partial_sum_pipe stores a sign-extended 18-bit value.

Because the upper bits are redundant copies of the sign bit, synthesis may legally optimize the physical implementation to fewer than 32 independently stored bits.

A reasonable physical prediction range is therefore:

~~~text
+18 to +32 datapath FF
~~~

The FSM also changes from five states to six states.

The RTL state width remains:

~~~text
3 bits
~~~

but the previous synthesis encoded this FSM one-hot. If Vivado again chooses one-hot encoding:

~~~text
5 state FF -> 6 state FF
delta      -> +1 FF
~~~

Therefore total predicted FF delta is approximately:

~~~text
+19 to +33 FF
~~~

Using the measured baseline:

~~~text
138 FF
~~~

predicted new synthesized range is approximately:

~~~text
157 to 171 FF
~~~

This is a prediction only. The exact result must come from synthesis.

---

## 11. LUT prediction

The arithmetic operations themselves are not increased.

The design still performs:

~~~text
4 lane multiplications
same reduction tree
same INT32 accumulation
~~~

The primary structural change is sequential partitioning.

Therefore LUT count should remain in roughly the same order as the measured baseline:

~~~text
465 LUT
~~~

There may be modest changes due to:

~~~text
new FSM decode
different optimization boundaries
changed arithmetic sharing
different placement-oriented synthesis decisions
~~~

Prediction:

~~~text
LUT count should remain approximately near the existing 465,
with a modest variation rather than a large architectural increase.
~~~

No exact LUT count is claimed before synthesis.

---

## 12. CARRY4 prediction

The arithmetic width is unchanged.

Therefore the design still requires carry structures for:

~~~text
reduction arithmetic
INT32 accumulation
requantization/debounce arithmetic
~~~

The new register changes where the carry chains are separated, not necessarily the total amount of arithmetic.

Prediction:

~~~text
CARRY4 count remains broadly near the existing 96
~~~

but the critical path should contain a shorter serial carry chain because the reduction and accumulation no longer belong to one register-to-register path.

Exact count remains a synthesis result.

---

## 13. DSP prediction

Measured baseline:

~~~text
DSP = 0
~~~

The redesign does not add new multiplication operations.

Therefore:

~~~text
predicted DSP = 0
~~~

unless Vivado independently changes mapping decisions after the structural change.

The intended architecture does not require additional DSP48 resources.

---

## 14. BRAM prediction

The memory organization is unchanged:

~~~text
activation logical memory -> one RAMB18E1
weight logical memory     -> one RAMB18E1
~~~

Therefore:

~~~text
predicted RAMB18E1 = 2
predicted Block RAM Tile = 1
~~~

The pipeline register does not require additional memory capacity.

---

## 15. I/O and clock-resource prediction

No top-level interface changes are approved.

Therefore:

~~~text
Bonded IOB = 12 expected
BUFG       = 1 expected
~~~

No additional clock is introduced.

Expected:

~~~text
MMCM = 0
PLL  = 0
~~~

The architecture remains single-clock.

---

## 16. Expected critical-path migration

Old measured critical path:

~~~text
BRAM output
-> multiply/reduction
-> accumulator addition
-> accumulator register
~~~

The new architecture removes that combined path.

Two candidate paths replace it:

~~~text
Candidate A:
BRAM output
-> multiplication
-> reduction
-> partial_sum_pipe

Candidate B:
partial_sum_pipe
-> INT32 accumulator addition
-> accumulator register
~~~

Prediction:

~~~text
the old BRAM-to-accumulator path should disappear
the new worst path is likely to be Candidate A
or another previously secondary arithmetic path
~~~

Candidate B should be much shorter because it contains only a registered partial sum feeding one INT32 addition.

---

## 17. Expected timing direction

Measured baseline:

~~~text
WNS = -3.453 ns
TNS = -99.753 ns
43 failing setup endpoints
critical data path = 13.433 ns
~~~

Because the redesign introduces a sequential boundary inside the measured failing path, the expected direction is:

~~~text
WNS should improve
TNS magnitude should decrease
number of failing endpoints should decrease
critical delay should decrease
~~~

The desired target is:

~~~text
WNS >= 0
TNS = 0
~~~

But no exact positive slack is predicted.

Why not?

Because post-route timing depends on:

~~~text
technology mapping
placement
routing
clock skew
uncertainty
new critical-path migration
physical optimization
~~~

Therefore the strongest valid pre-implementation prediction is:

~~~text
timing should improve materially,
but closure is not guaranteed.
~~~

---

## 18. Hold-timing prediction

Current hold result:

~~~text
WHS = +0.197 ns
THS = 0
~~~

Adding a pipeline register creates additional short register-to-register paths, so hold timing must be rechecked.

There is no basis to assume the exact WHS remains +0.197 ns.

Prediction:

~~~text
hold is expected to remain tool-fixable/passing,
but must be measured again.
~~~

Acceptance criterion remains:

~~~text
WHS >= 0
THS = 0
~~~

---

## 19. Pulse-width prediction

The clock itself is unchanged:

~~~text
period   = 10 ns
waveform = {0 5}
~~~

No generated clock is introduced.

Therefore no architectural reason exists for pulse-width behavior to worsen.

However it must still be rechecked after implementation.

Acceptance criterion:

~~~text
WPWS >= 0
TPWS = 0
~~~

---

## 20. Behavioral verification predictions

After the RTL change, simulation should measure:

~~~text
paired memory requests = 3
request order          = 0 -> 1 -> 2
accumulator            = 45
activation_out         = 34 / 0x22
raw completion events  = 1 per accepted transaction
top-level latency      = 8 cycles / 80 ns
~~~

The existing old latency assertion of 70 ns must be updated because the architecture intentionally adds one cycle.

A simulation still reporting 70 ns would indicate that the intended pipeline schedule was not actually inserted or that the measurement point is wrong.

---

## 21. Resource comparison table

| Resource | Current measured | Predicted after redesign |
|---|---:|---:|
| LUT | 465 | approximately similar, modest variation |
| FF | 138 | approximately 157..171 |
| CARRY4 | 96 | broadly similar |
| DSP | 0 | 0 expected |
| RAMB18E1 | 2 | 2 expected |
| Block RAM Tile | 1 | 1 expected |
| Bonded IOB | 12 | 12 expected |
| BUFG | 1 | 1 expected |

The FF range is derived from:

~~~text
+18..32 effective datapath FF
+ approximately 1 extra one-hot FSM FF
~~~

---

## 22. Performance comparison table

| Quantity | Before redesign | Predicted after redesign |
|---|---:|---:|
| Clock period | 10 ns | 10 ns |
| Clock frequency | 100 MHz | 100 MHz |
| Accepted-start-to-done latency | 70 ns | 80 ns |
| Latency cycles | 7 | 8 |
| Machine initiation interval | 90 ns | 100 ns |
| Machine transaction rate | 11.11 M/s | 10 M/s |
| Useful MAC throughput | ~100 MMAC/s | 90 MMAC/s |
| Physical operand BW | 266.67 MB/s | 240 MB/s |
| Useful operand BW | 200 MB/s | 180 MB/s |
| Peak port BW | 800 MB/s | 800 MB/s |

This is the deliberate performance tradeoff:

~~~text
slightly lower transaction throughput
in exchange for a realistic chance of meeting the required 100 MHz clock
~~~

---

## 23. Prediction success criteria

The timing-closure redesign will be considered successful only if all of the following eventually hold:

~~~text
functional result = 34 / 0x22
three paired memory requests remain
request order remains 0 -> 1 -> 2
BRAM remains inferred
RAMB18E1 remains 2 unless justified otherwise
100 MHz XDC remains unchanged
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

Resource growth must also be explainable by the added pipeline state.

---

## 24. Step-3 conclusion

The approved one-stage partial-sum pipeline is predicted to:

~~~text
increase latency:
70 ns -> 80 ns

increase initiation interval:
90 ns -> 100 ns

reduce machine transaction rate:
11.11 M/s -> 10 M/s

reduce machine MAC throughput:
~100 MMAC/s -> 90 MMAC/s

increase synthesized FF count:
138 -> approximately 157..171

preserve:
2 RAMB18E1
12 IOB
1 BUFG
0 DSP expected

eliminate the old combined:
BRAM -> reduction -> accumulation
critical path
~~~

The expected timing direction is strongly positive, but post-route closure cannot be claimed until implementation is rerun.

---

## 25. Understanding gate

Before Step 4 confirmation and any RTL modification, explain in your own words:

1. Derive why the new top-level latency is predicted as 8 cycles / 80 ns.
2. Derive why the new initiation interval is predicted as 10 cycles / 100 ns.
3. Derive the predicted 10 Mtransactions/s machine rate.
4. Derive the predicted 90 MMAC/s throughput.
5. Derive the new 240 MB/s physical and 180 MB/s useful sustained operand bandwidth.
6. Why is the FF increase predicted as a range rather than exactly +32?
7. Which physical resources are expected to remain unchanged?
8. What critical path is expected to disappear?
9. What are the two likely replacement timing paths?
10. Why do we predict better WNS/TNS but refuse to predict an exact new slack?
11. Why must hold timing be rechecked even though it currently passes?
12. What exact measured conditions will define successful 100 MHz timing closure?


---

## Step 9 Update — Behavioral Measured vs Predicted

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Evidence source:** completed XSim run of the modified pipelined RTL  
**Status:** BEHAVIORAL PREDICTIONS MATCH — fresh synthesis/resource and post-route timing measurements remain pending.

### A. Completed XSim evidence

The timing-closure verification completed with:

```text
TEST 5: post-reset recovery transaction
PASS: tb_basys3_top_level timing-closure verification completed with zero errors
$finish called at time : 1230 ns
```

The final PASS is meaningful because every protocol, pipeline, arithmetic, reset, recovery, and latency assertion increments `error_count` on failure.

Therefore:

```text
error_count = 0
```

means all implemented behavioral checks passed.

---

### B. Partial-sum prediction comparison

Step-3 prediction:

```text
S0 = 10
S1 = 26
S2 = 9
```

The testbench explicitly checked the registered pipeline values.

Measured assertion result:

```text
S0 = 10 -> PASS
S1 = 26 -> PASS
S2 = 9  -> PASS
```

Comparison:

```text
PREDICTED = exact sequence 10,26,9
MEASURED  = all assertions passed
MATCH     = yes
```

---

### C. Accumulator progression

Step-3 prediction:

```text
after S0:
accumulator = 10

after S1:
accumulator = 36

final:
result = 45
```

Measured assertion result:

```text
accumulator 10 -> PASS
accumulator 36 -> PASS
final result 45 -> PASS
```

Therefore:

```text
0 -> 10 -> 36 -> 45
```

is behaviorally confirmed.

---

### D. Memory request count and order

Prediction:

```text
paired request count = 3
request order        = 0 -> 1 -> 2
```

The testbench continuously checked:

```text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
```

and rejected any fourth request.

Measured result:

```text
3 paired requests = PASS
order 0 -> 1 -> 2 = PASS
activation/weight alignment = PASS
```

Therefore the pipeline changed arithmetic timing but did not alter operand traffic.

---

### E. One-clock synchronous memory behavior

Prediction:

```text
request at one edge
-> corresponding registered BRAM word visible according to one-clock synchronous behavior
```

The scoreboard checked expected activation/weight words against the previous request relationship.

Measured result:

```text
one-clock memory contract = PASS
```

Thus the new pipeline did not accidentally assume combinational BRAM behavior.

---

### F. Numerical result

Prediction:

```text
engine result = 45
activation_out = 34 = 0x22
```

Derivation:

```text
45 x 3 = 135
rounding bias = 2
135 + 2 = 137
137 >> 2 = 34
```

Measured result:

```text
engine result assertion = PASS
board-visible output assertion = PASS
```

Comparison:

```text
PREDICTED engine result = 45
MEASURED assertion      = PASS

PREDICTED output = 34 / 0x22
MEASURED assertion = PASS
```

The pipeline changed timing only, not arithmetic.

---

### G. Latency prediction comparison

Old architecture measured:

```text
7 cycles = 70 ns
```

Step-3 timing-closure prediction:

```text
new latency = 8 cycles
            = 8 x 10 ns
            = 80 ns
```

The modified testbench explicitly checks:

```text
raw_done_time - accepted_start_time == 80 ns
```

The completed zero-error run therefore confirms:

```text
PREDICTED = 80 ns
MEASURED  = 80 ns assertion passed
ERROR     = 0 ns
MATCH     = exact
```

Latency increase:

```text
80 ns - 70 ns
= 10 ns
= one clock cycle
```

Percentage latency increase:

```text
10 / 70 x 100
= 14.2857...%
≈ 14.29%
```

This matches the predicted cost of the added pipeline boundary.

---

### H. Completion-event behavior

Prediction:

```text
one accepted transaction
-> exactly one raw completion event
```

The full zero-error testbench run confirms:

```text
exactly one raw done event = PASS
persistent board done behavior = PASS
```

Therefore the additional pipeline state did not duplicate completion signaling.

---

### I. Reset and recovery behavior

Prediction:

```text
reset clears:
partial_sum_pipe
accumulator
result/completion state
```

and after reset:

```text
new transaction completes normally
```

Measured testbench result:

```text
pipeline reset checks = PASS
clean-reset abort checks = PASS
no stale completion after reset = PASS
post-reset recovery transaction = PASS
```

This confirms that the new pipeline register behaves as proper architectural state.

---

### J. Behavioral prediction summary

| Quantity | Step-3 prediction | Step-8 measurement | Result |
|---|---:|---:|---|
| S0 | 10 | assertion passed | MATCH |
| S1 | 26 | assertion passed | MATCH |
| S2 | 9 | assertion passed | MATCH |
| accumulator after S0 | 10 | assertion passed | MATCH |
| accumulator after S1 | 36 | assertion passed | MATCH |
| final engine result | 45 | assertion passed | MATCH |
| paired memory requests | 3 | assertion passed | MATCH |
| request order | 0 -> 1 -> 2 | assertion passed | MATCH |
| one-clock BRAM behavior | required | assertion passed | MATCH |
| activation output | 34 / 0x22 | assertion passed | MATCH |
| top-level latency | 80 ns | assertion passed | EXACT MATCH |
| added latency | +10 ns | +10 ns | EXACT MATCH |
| raw completion events | 1 | assertion passed | MATCH |
| reset/recovery | required | assertion passed | MATCH |
| behavioral error count | 0 | 0 | MATCH |

All behavioral predictions directly checked by XSim match.

---

### K. What remains prediction-only

The following Step-3 values have **not yet been re-measured after the RTL change**:

```text
FF count ≈ 157..171
LUT count ≈ near previous 465
CARRY4 ≈ broadly near previous 96
DSP = 0 expected
RAMB18E1 = 2 expected
Block RAM Tile = 1 expected
IOB = 12 expected
BUFG = 1 expected
```

Likewise, these timing expectations remain unmeasured:

```text
old BRAM->reduction->accumulator path should disappear
new critical path should migrate
WNS should improve
TNS magnitude should reduce
failing setup endpoints should reduce
100 MHz closure may or may not be achieved
```

No fresh synthesis/implementation report has yet been supplied for the pipelined RTL.

Therefore the old pre-pipeline physical reports must not be reused as evidence for the modified design.

---

### L. Performance quantities still derived, not independently measured

Based on the predicted 10-cycle initiation interval:

```text
II = 100 ns
transaction rate = 10 Mtransactions/s
MAC throughput = 90 MMAC/s
physical operand BW = 240 MB/s
useful operand BW = 180 MB/s
```

These remain architectural derivations.

The completed behavioral testbench directly measured transaction latency, not sustained back-to-back machine throughput.

Therefore these values remain mathematically predicted until a dedicated throughput measurement is performed.

---

### M. Step-9 behavioral conclusion

The timing-closure redesign achieved exactly the intended behavioral tradeoff:

```text
old latency = 70 ns
new latency = 80 ns

functional result unchanged:
45 -> 34 / 0x22

memory traffic unchanged:
3 paired requests

pipeline sequencing:
correct

reset/recovery:
correct
```

So the architectural redesign is behaviorally validated.

The physical question remains open:

```text
Did the added register actually remove enough combinational delay to meet 100 MHz after place and route?
```

That requires a **fresh synthesis and fresh implementation** of the modified RTL.

---

### N. Next physical measurements required

Fresh synthesis must provide:

```text
LUT
FF
CARRY4
DSP
RAMB18E1 / Block RAM Tile
IOB
BUFG
```

Fresh implementation/post-route STA must provide:

```text
WNS
TNS
WHS
THS
WPWS
TPWS
failing setup endpoints
new critical path
logic delay
route delay
logic levels
```

The success condition remains:

```text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
```

at the unchanged:

```text
100 MHz
10 ns period
```


---

## Step 9 Update — Fresh Post-Pipeline Physical Measurements

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Evidence:** fresh synthesis and fresh implemented timing report for the modified pipelined RTL  
**Status:** PHYSICAL TIMING IMPROVED SUBSTANTIALLY, BUT 100 MHz SETUP CLOSURE STILL FAILS.

### A. Fresh synthesis utilization

Measured post-pipeline synthesis:

```text
Slice LUTs      = 487
Slice Registers = 154
CARRY4          = 96
DSP             = 0
RAMB18E1        = 2
Block RAM Tile  = 1
Bonded IOB      = 12
BUFG            = 1
```

Previous pre-pipeline baseline:

```text
LUT       = 465
FF        = 138
CARRY4    = 96
DSP       = 0
RAMB18E1  = 2
IOB       = 12
BUFG      = 1
```

Measured deltas:

```text
LUT:
487 - 465 = +22
percentage increase = 22 / 465 x 100
                    ≈ 4.73%

FF:
154 - 138 = +16
percentage increase = 16 / 138 x 100
                    ≈ 11.59%

CARRY4:
96 - 96 = 0

DSP:
0 - 0 = 0

RAMB18E1:
2 - 2 = 0

IOB:
12 - 12 = 0

BUFG:
1 - 1 = 0
```

### B. Why FF increased by only 16 rather than exactly 32

The RTL added a signed 32-bit `partial_sum_pipe`.

However, only 18 bits of the reduced partial sum are independent.

The upper sign-extension bits are copies of the sign bit.

Vivado merged:

```text
partial_sum_pipe[18]
through
partial_sum_pipe[31]
```

into the physical storage for bit 17.

Thus approximately:

```text
32 RTL bits
- 14 redundant sign-extension bits
= 18 unique datapath bits
```

The memory-interface FSM also changed physical encoding.

Before the redesign, the five-state memory FSM had been synthesized one-hot.

After the redesign, Vivado reports the six-state FSM using sequential encoding:

```text
ST_IDLE  = 000
ST_WAIT0 = 001
ST_PIPE0 = 010
ST_WORD0 = 011
ST_WORD1 = 100
ST_WORD2 = 101
```

Therefore the physical state storage changed approximately from:

```text
5 one-hot FF
to
3 binary FF
```

saving roughly two FF.

Combining:

```text
+18 effective pipeline FF
- 2 FSM FF
≈ +16 net FF
```

which exactly matches:

```text
154 - 138 = +16
```

This is a strong example of why RTL register width and synthesized FF count are not always identical.

### C. Fresh post-route timing summary

Measured implemented timing:

```text
WNS  = -1.260 ns
TNS  = -9.347 ns
setup failing endpoints = 12
total setup endpoints   = 397

WHS  = +0.131 ns
THS  = 0.000 ns
hold failing endpoints = 0

WPWS = +4.500 ns
TPWS = 0.000 ns
pulse-width failing endpoints = 0
```

Therefore:

```text
setup timing       = FAIL
hold timing        = PASS
pulse-width timing = PASS
```

### D. Before-versus-after setup timing

Pre-pipeline:

```text
WNS = -3.453 ns
TNS = -99.753 ns
failing endpoints = 43
```

Post-pipeline:

```text
WNS = -1.260 ns
TNS = -9.347 ns
failing endpoints = 12
```

WNS improvement:

```text
-1.260 - (-3.453)
= +2.193 ns
```

The setup deficit magnitude reduced from:

```text
3.453 ns
to
1.260 ns
```

Reduction:

```text
(3.453 - 1.260) / 3.453 x 100
≈ 63.51%
```

TNS magnitude reduced from:

```text
99.753 ns
to
9.347 ns
```

Improvement in TNS magnitude:

```text
99.753 - 9.347
= 90.406 ns
```

Relative reduction:

```text
90.406 / 99.753 x 100
≈ 90.63%
```

Failing endpoints reduced:

```text
43 -> 12
delta = -31
```

Relative reduction:

```text
31 / 43 x 100
≈ 72.09%
```

Therefore the pipeline materially improved timing, exactly as predicted, but did not completely close the 100 MHz requirement.

### E. Critical-path migration

The old worst path was:

```text
BRAM activation output
-> multiply/reduction
-> accumulator addition
-> accumulator_reg
```

The new worst path is:

```text
u_operand_bram_dual_read/activation_data_reg
->
u_convolution_integration/
u_memory_interface_dataflow/
partial_sum_pipe_reg[17]/D
```

This is precisely the predicted **Stage A** candidate:

```text
BRAM
-> multiply/reduce
-> partial_sum_pipe
```

Therefore the architectural split worked as intended:

```text
the old BRAM-to-accumulator path disappeared
```

and the new bottleneck is now the first pipeline stage itself.

### F. New critical-path delay

Measured new critical path:

```text
requirement      = 10.000 ns
data path delay  = 11.289 ns
logic delay      = 6.813 ns
route delay      = 4.476 ns
logic levels     = 13
CARRY4           = 7
LUT2             = 2
LUT3             = 2
LUT6             = 2
```

Check:

```text
6.813 + 4.476
= 11.289 ns
```

Delay percentages:

```text
logic:
6.813 / 11.289 x 100
≈ 60.35%

route:
4.476 / 11.289 x 100
≈ 39.65%
```

These match the implemented timing report.

### G. Critical-path improvement from the pipeline

Old path:

```text
data delay   = 13.433 ns
logic levels = 17
CARRY4       ≈ 10
```

New path:

```text
data delay   = 11.289 ns
logic levels = 13
CARRY4       = 7
```

Data-delay reduction:

```text
13.433 - 11.289
= 2.144 ns
```

Relative reduction:

```text
2.144 / 13.433 x 100
≈ 15.96%
```

Logic-level reduction:

```text
17 - 13
= 4 levels
```

CARRY4 reduction on the worst path:

```text
10 - 7
= 3 CARRY4 stages
```

The register split therefore shortened the critical arithmetic chain, but the Stage-A multiply/reduction path is still too long for 10 ns.

### H. Logic-delay and route-delay changes

Old:

```text
logic delay = 8.067 ns
route delay = 5.366 ns
```

New:

```text
logic delay = 6.813 ns
route delay = 4.476 ns
```

Logic-delay improvement:

```text
8.067 - 6.813
= 1.254 ns
```

Route-delay improvement:

```text
5.366 - 4.476
= 0.890 ns
```

Both logic and routing improved.

The ratio remains roughly:

```text
60% logic
40% route
```

so the remaining failure is still primarily architectural/logic-depth related rather than purely a routing accident.

### I. Approximate current frequency scale

Using the current 10 ns requirement and WNS:

```text
approximate effective minimum period
≈ 10 ns + 1.260 ns
≈ 11.260 ns
```

Approximate frequency:

```text
1 / 11.260 ns
≈ 88.81 MHz
```

This is only an approximate interpretation of the current routed result.

It is not a guaranteed Fmax and it does not replace a dedicated maximum-frequency analysis.

### J. Resource prediction comparison

Step-3 FF prediction:

```text
157..171 FF
```

Measured:

```text
154 FF
```

The prediction was slightly high by:

```text
157 - 154 = 3 FF
```

The reason is now understood:

```text
sign-extension register merging
+
more compact sequential FSM encoding
```

Other resource predictions:

```text
DSP = 0 expected       -> measured 0
RAMB18E1 = 2 expected -> measured 2
IOB = 12 expected     -> measured 12
BUFG = 1 expected     -> measured 1
CARRY4 broadly similar -> measured exactly 96
```

These all matched.

LUT prediction was “similar with modest variation.”

Measured:

```text
465 -> 487
delta +22
+4.73%
```

This qualifies as a modest change.

### K. Timing prediction comparison

Predicted:

```text
old combined BRAM-to-accumulator path should disappear
new worst path likely Stage A or another secondary arithmetic path
WNS should improve
TNS magnitude should decrease
failing endpoints should decrease
closure not guaranteed
```

Measured:

```text
old combined path disappeared        MATCH
new worst path = Stage A             MATCH
WNS improved                         MATCH
TNS magnitude decreased strongly     MATCH
failing endpoints decreased          MATCH
100 MHz still fails                  allowed by prediction
```

The timing prediction was therefore qualitatively accurate.

### L. Current physical status

```text
Behavioral pipeline verification  PASS
Fresh synthesis                  PASS
Fresh utilization                MEASURED
BRAM inference                   CONFIRMED
Fresh implementation             COMPLETE
Post-route hold                  PASS
Post-route pulse width           PASS
Post-route setup                 FAIL
100 MHz timing closure           NOT ACHIEVED
```

### M. Engineering conclusion

The first pipeline stage was beneficial but insufficient.

The old bottleneck:

```text
BRAM
-> multiply/reduction
-> accumulator
```

has been successfully split.

The remaining bottleneck is now:

```text
BRAM
-> multiply/reduction
-> partial_sum_pipe
```

with:

```text
WNS = -1.260 ns
13 logic levels
7 CARRY4 on the worst path
```

Therefore the next timing-closure iteration should target **Stage A**, likely by introducing another justified sequential boundary within the multiply/reduction path, rather than changing the XDC or accumulator stage.

No RTL change should be made until that second timing-closure iteration goes through teaching/design/prediction again.
