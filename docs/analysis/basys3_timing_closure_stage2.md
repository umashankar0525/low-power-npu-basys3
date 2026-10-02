# Basys 3 Timing Closure Stage 2 — Prediction Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure_stage2  
**Workflow stage:** Step 3 — /analyze basys3_timing_closure_stage2  
**Status:** PREDICTION ONLY — Stage-2 RTL modification has not yet been made.

---

## 1. Purpose

This analysis predicts the architectural and physical consequences of adding four INT16 product pipeline registers between the BRAM outputs and the reduction tree.

Approved architecture:

~~~text
Stage A1:
BRAM
-> 4 x INT8 multipliers
-> 4 x INT16 product registers

Stage A2:
product registers
-> balanced reduction tree
-> partial_sum_pipe

Stage B:
partial_sum_pipe
-> INT32 accumulator add
-> accumulator register
~~~

The goal is to remove the current combined:

~~~text
BRAM
-> multiply
-> reduction
-> partial_sum_pipe
~~~

critical path.

---

## 2. Explicit assumptions

1. Target remains XC7A35T-1CPG236C.
2. Clock remains 100 MHz.
3. Clock period remains 10 ns.
4. Current measured post-pipeline timing is:
   - WNS = -1.260 ns
   - TNS = -9.347 ns
   - failing setup endpoints = 12
5. Current measured resource utilization is:
   - LUT = 487
   - FF = 154
   - CARRY4 = 96
   - DSP = 0
   - RAMB18E1 = 2
   - IOB = 12
   - BUFG = 1
6. Current worst path is:
   - BRAM activation output -> multiply/reduction -> partial_sum_pipe
7. Current critical data-path delay is 11.289 ns.
8. Current critical logic depth is 13 levels.
9. Current critical path contains 7 CARRY4 elements.
10. Three paired memory requests remain sufficient.
11. Request order remains 0 -> 1 -> 2.
12. Four signed INT16 product registers will be added.
13. One additional FSM state ST_PROD0 will be added.
14. Seven states still fit in a 3-bit RTL state register.
15. Functional result remains 45 -> 34 / 0x22.
16. Exact post-route slack cannot be known before implementation.

---

## 3. New cycle schedule

Approved Stage-2 schedule:

~~~text
E0:
start accepted
request word 0

E1:
BRAM returns word 0
request word 1

E2:
product_pipe <= products(word 0)
BRAM returns word 1
request word 2

E3:
partial_sum_pipe <= S0
product_pipe <= products(word 1)
BRAM returns word 2

E4:
accumulator <= S0
partial_sum_pipe <= S1
product_pipe <= products(word 2)

E5:
accumulator <= S0 + S1
partial_sum_pipe <= S2

E6:
result <= S0 + S1 + S2
done <= 1
~~~

Relative to the first timing-closure architecture, one additional product-pipeline cycle is introduced.

---

## 4. Top-level latency derivation

Current measured top-level latency after the first pipeline is:

~~~text
8 cycles
= 80 ns
~~~

Stage 2 adds one further internal pipeline cycle.

Therefore predicted new latency is:

~~~text
8 + 1
= 9 cycles
~~~

At 100 MHz:

~~~text
9 x 10 ns
= 90 ns
~~~

Prediction:

~~~text
old = 80 ns
new = 90 ns
delta = +10 ns
~~~

Percentage increase relative to the first timing-closure architecture:

~~~text
10 / 80 x 100
= 12.5%
~~~

Relative to the original pre-pipeline architecture:

~~~text
90 - 70 = 20 ns
20 / 70 x 100
≈ 28.57%
~~~

---

## 5. Initiation interval derivation

After the first timing-closure pipeline, the predicted machine initiation interval was:

~~~text
10 cycles
= 100 ns
~~~

The Stage-2 product pipeline adds one non-overlapped engine cycle.

Therefore predicted new initiation interval:

~~~text
11 cycles
= 110 ns
~~~

---

## 6. Machine transaction rate

With:

~~~text
II = 110 ns
~~~

transaction rate is:

~~~text
1 / 110 ns
= 1 / (110 x 10^-9)
≈ 9.0909 x 10^6 transactions/s
≈ 9.09 Mtransactions/s
~~~

---

## 7. MAC throughput

Each transaction performs nine useful MACs.

Therefore:

~~~text
9 MAC/transaction
x 9.09 Mtransactions/s
≈ 81.82 MMAC/s
~~~

Using 2 arithmetic operations per MAC:

~~~text
81.82 MMAC/s x 2
≈ 163.64 MOPS
~~~

Prediction:

~~~text
useful MAC throughput ≈ 81.82 MMAC/s
~~~

---

## 8. Sustained memory bandwidth

Physical operand traffic per transaction remains:

~~~text
24 bytes
~~~

Useful operand payload remains:

~~~text
18 bytes
~~~

At 110 ns initiation interval:

~~~text
physical operand bandwidth
= 24 / 110 ns
≈ 218.18 MB/s
~~~

Useful operand bandwidth:

~~~text
18 / 110 ns
≈ 163.64 MB/s
~~~

Per logical operand memory:

~~~text
12 / 110 ns
≈ 109.09 MB/s
~~~

Peak port bandwidth remains unchanged:

~~~text
64 bits/cycle x 100 MHz
= 800 MB/s
~~~

because bus width and clock frequency are unchanged.

---

## 9. Functional arithmetic prediction

Product registers for word 0:

~~~text
1,2,3,4
~~~

Reduction:

~~~text
S0 = 1+2+3+4 = 10
~~~

Word 1 products:

~~~text
5,6,7,8
~~~

Reduction:

~~~text
S1 = 5+6+7+8 = 26
~~~

Word 2 products:

~~~text
9,0,0,0
~~~

Reduction:

~~~text
S2 = 9
~~~

Final:

~~~text
10 + 26 + 9 = 45
~~~

Requantization:

~~~text
45 x 3 = 135
+2 rounding bias = 137
137 >> 2 = 34
~~~

Therefore:

~~~text
activation_out = 34 = 0x22
~~~

must remain unchanged.

---

## 10. FF prediction

Four product registers:

~~~text
4 x 16 bits
= 64 RTL bits
~~~

Current physical FF count:

~~~text
154
~~~

A first-order estimate is therefore:

~~~text
154 + 64
= 218 FF
~~~

However physical FF count can differ because:

~~~text
FSM encoding may change
some product bits may optimize under constant/padding conditions
synthesis can merge or remove unused state
~~~

Reasonable prediction range:

~~~text
approximately 210..225 FF
~~~

Exact count must come from synthesis.

---

## 11. LUT prediction

The arithmetic operations themselves are unchanged:

~~~text
same four multiplications
same pairwise reduction
same final reduction
same accumulator
~~~

The register boundaries may alter synthesis sharing and muxing.

Current:

~~~text
487 LUT
~~~

Prediction:

~~~text
LUT count remains in the same general range,
with modest change rather than architectural explosion.
~~~

A rough pre-synthesis expectation:

~~~text
approximately 480..530 LUT
~~~

This is intentionally a range because placement-independent synthesis optimization can shift LUT count.

---

## 12. CARRY4 prediction

Current:

~~~text
96 CARRY4
~~~

The amount of arithmetic is unchanged.

Prediction:

~~~text
total CARRY4 count remains broadly near 96
~~~

The important expected change is not total CARRY4 usage, but reduced serial carry depth on the worst timing path.

---

## 13. DSP prediction

Current:

~~~text
DSP = 0
~~~

The RTL still uses the same multiplications.

The new product registers do not require DSP resources.

Prediction:

~~~text
DSP = 0 expected
~~~

unless Vivado independently changes multiplication mapping.

---

## 14. BRAM prediction

Memory organization is unchanged.

Prediction:

~~~text
RAMB18E1 = 2
Block RAM Tile = 1
~~~

No additional BRAM is required.

---

## 15. I/O and clock prediction

No top-level interface change.

Prediction:

~~~text
Bonded IOB = 12
BUFG = 1
MMCM = 0
PLL = 0
~~~

The design remains single-clock.

---

## 16. Expected critical-path migration

Current worst path:

~~~text
BRAM
-> multiplier
-> reduction tree
-> partial_sum_pipe
~~~

After product registers, that combined path should disappear.

Likely new candidates:

~~~text
A1:
BRAM
-> multiplier
-> product_pipe

A2:
product_pipe
-> reduction tree
-> partial_sum_pipe

B:
partial_sum_pipe
-> accumulator add
-> accumulator
~~~

The longest of these three will become the new critical path.

---

## 17. Timing-direction prediction

Current measured:

~~~text
WNS = -1.260 ns
TNS = -9.347 ns
12 failing setup endpoints
~~~

Because the new register boundary directly splits the current failing path, expected direction is:

~~~text
WNS should improve toward or above zero
TNS should move toward zero
failing endpoints should decrease
critical data-path delay should fall below 11.289 ns
~~~

However, exact values are not predicted.

Desired closure:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

---

## 18. Why closure is more plausible this iteration

The current violation magnitude is:

~~~text
1.260 ns
~~~

The first pipeline improved WNS by:

~~~text
+2.193 ns
~~~

The Stage-2 split is placed directly inside the remaining failing path.

This does not guarantee closure, but it provides a reasonable architectural basis to expect that removing the reduction tree from the BRAM-to-multiplier stage may recover more than the remaining 1.260 ns deficit.

This is a qualitative expectation only.

---

## 19. Hold-timing prediction

Current:

~~~text
WHS = +0.131 ns
THS = 0
~~~

Adding four product-register banks creates new short register-to-register paths.

Therefore hold must be rechecked.

Prediction:

~~~text
hold is expected to remain fixable/passing,
but exact WHS is unknown before implementation.
~~~

---

## 20. Pulse-width prediction

Clock waveform remains:

~~~text
10 ns period
50% duty cycle
~~~

No new clock is introduced.

Prediction:

~~~text
WPWS should remain non-negative
TPWS should remain zero
~~~

but must still be measured.

---

## 21. Resource prediction table

| Resource | Current measured | Stage-2 prediction |
|---|---:|---:|
| LUT | 487 | approximately 480..530 |
| FF | 154 | approximately 210..225 |
| CARRY4 | 96 | broadly similar |
| DSP | 0 | 0 expected |
| RAMB18E1 | 2 | 2 expected |
| Block RAM Tile | 1 | 1 expected |
| IOB | 12 | 12 expected |
| BUFG | 1 | 1 expected |

---

## 22. Performance prediction table

| Quantity | Current first-pipeline design | Stage-2 prediction |
|---|---:|---:|
| Clock | 100 MHz | 100 MHz |
| Period | 10 ns | 10 ns |
| Latency | 80 ns | 90 ns |
| Latency cycles | 8 | 9 |
| Initiation interval | 100 ns | 110 ns |
| Transaction rate | 10 M/s | 9.09 M/s |
| MAC throughput | 90 MMAC/s | 81.82 MMAC/s |
| Physical operand BW | 240 MB/s | 218.18 MB/s |
| Useful operand BW | 180 MB/s | 163.64 MB/s |
| Peak port BW | 800 MB/s | 800 MB/s |

---

## 23. Prediction success criteria

Functional success:

~~~text
exactly 3 paired memory requests
request order 0 -> 1 -> 2
word-0 product registers = 1,2,3,4
word-1 product registers = 5,6,7,8
word-2 product registers = 9,0,0,0
S0 = 10
S1 = 26
S2 = 9
final result = 45
activation_out = 34 / 0x22
latency = 9 cycles / 90 ns
one completion event
reset clears all product registers
~~~

Physical success:

~~~text
RAMB18E1 remains 2
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

---

## 24. Step-3 conclusion

The Stage-2 timing-closure redesign is predicted to:

~~~text
increase latency:
80 ns -> 90 ns

increase initiation interval:
100 ns -> 110 ns

reduce transaction rate:
10 M/s -> 9.09 M/s

reduce MAC throughput:
90 MMAC/s -> 81.82 MMAC/s

increase FF usage:
154 -> approximately 210..225

preserve:
2 RAMB18E1
12 IOB
1 BUFG
0 DSP expected

split the current:
BRAM -> multiplier -> reduction -> partial_sum_pipe
path into two stages
~~~

The expected timing direction is positive, and full 100 MHz closure is more plausible, but only fresh implementation can prove it.

---

## 25. Understanding gate

Before RTL modification, explain in your own words:

1. Why does latency become 9 cycles / 90 ns?
2. Why does initiation interval become 11 cycles / 110 ns?
3. Derive 9.09 Mtransactions/s.
4. Derive 81.82 MMAC/s.
5. Derive 218.18 MB/s physical bandwidth.
6. Why is FF prediction approximately 210..225 rather than exactly 218?
7. Which resources are expected to remain unchanged?
8. Which old critical path should disappear?
9. What are the three likely replacement timing paths?
10. Why is timing closure more plausible but still not guaranteed?
11. Why must hold timing be rechecked?
12. What exact values define successful 100 MHz closure?
