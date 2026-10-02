# Basys 3 Timing Closure Stage 2 — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure_stage2  
**Workflow stage:** Step 6 — /verify basys3_timing_closure_stage2  
**Status:** VERIFICATION PLAN COMPLETE — understanding gate required before Step 7 testbench modification.

---

## 1. Verification objective

Verify that the second timing-closure pipeline:

1. captures the four INT16 products for each BRAM word correctly,
2. preserves word ordering across the new product registers,
3. preserves the existing partial-sum pipeline,
4. preserves the accumulator sequence,
5. preserves exactly three paired BRAM requests,
6. preserves one-clock synchronous BRAM behavior,
7. produces exactly one completion event,
8. changes accepted-start-to-done latency from 80 ns to 90 ns,
9. resets all newly introduced product-pipeline state,
10. preserves the final output 34 / 0x22.

This step proves functional/cycle correctness only.

It does not prove 100 MHz physical timing closure.

---

## 2. RTL under verification

Primary modified module:

~~~text
rtl/compute/memory_interface_dataflow.v
~~~

Integration modules:

~~~text
rtl/top/convolution_integration.v
rtl/top/basys3_top_level.v
~~~

Supporting memory:

~~~text
rtl/memory/operand_bram_dual_read.v
~~~

---

## 3. Explicit assumptions

1. Clock remains 100 MHz.
2. Clock period remains 10 ns.
3. Operand BRAM remains one-clock synchronous.
4. Exactly three paired memory requests remain required.
5. Request order remains 0 -> 1 -> 2.
6. Product precision remains signed INT16.
7. Partial-sum precision remains signed INT18 before INT32 extension.
8. Accumulator precision remains signed INT32.
9. Expected Stage-2 latency is 9 cycles / 90 ns.
10. Functional result remains 45 -> 34 / 0x22.

---

## 4. Product-pipeline values

### Word 0

Activation lanes:

~~~text
1,2,3,4
~~~

Weight lanes:

~~~text
1,1,1,1
~~~

Expected registered products:

~~~text
product_pipe0 = 1
product_pipe1 = 2
product_pipe2 = 3
product_pipe3 = 4
~~~

Expected reduction:

~~~text
S0 = 10
~~~

### Word 1

Expected registered products:

~~~text
5,6,7,8
~~~

Expected reduction:

~~~text
S1 = 26
~~~

### Word 2

Expected registered products:

~~~text
9,0,0,0
~~~

Expected reduction:

~~~text
S2 = 9
~~~

---

## 5. Cycle-by-cycle expected sequence

### ST_PROD0

After the rising edge that captures word-0 products:

~~~text
product_pipe = {1,2,3,4}
partial_sum_pipe = 0
accumulator = 0
~~~

### ST_PIPE0

After the next rising edge:

~~~text
partial_sum_pipe = 10

product_pipe = {5,6,7,8}

accumulator = 0
~~~

### ST_WORD0

After the next rising edge:

~~~text
accumulator = 10
partial_sum_pipe = 26

product_pipe = {9,0,0,0}
~~~

### ST_WORD1

After the next rising edge:

~~~text
accumulator = 36
partial_sum_pipe = 9
~~~

### ST_WORD2

After the next rising edge:

~~~text
result = 45
done = 1
~~~

This is the central Stage-2 pipeline contract.

---

## 6. Directed Test 1 — Reset and idle

After reset:

~~~text
state = ST_IDLE

product_pipe0 = 0
product_pipe1 = 0
product_pipe2 = 0
product_pipe3 = 0

partial_sum_pipe = 0
accumulator = 0
result = 0
done = 0

activation_rd_en = 0
weight_rd_en = 0
~~~

This verifies deterministic startup for the new product-register state.

---

## 7. Directed Test 2 — Memory request protocol

Expected request sequence:

~~~text
0 -> 1 -> 2
~~~

Required continuous conditions:

~~~text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
~~~

Required request count:

~~~text
exactly 3
~~~

No fourth memory request may appear because the extra stage is a compute pipeline, not additional memory traffic.

---

## 8. Directed Test 3 — Word-0 products

When the engine reaches the first product-pipeline observation point, verify:

~~~text
product_pipe0 = 1
product_pipe1 = 2
product_pipe2 = 3
product_pipe3 = 4
~~~

At this point:

~~~text
partial_sum_pipe = 0
accumulator = 0
~~~

This proves the product registers exist as a real sequential boundary before the reduction tree.

---

## 9. Directed Test 4 — Word-1 products and S0

At the next stage verify:

~~~text
product_pipe0 = 5
product_pipe1 = 6
product_pipe2 = 7
product_pipe3 = 8

partial_sum_pipe = 10
accumulator = 0
~~~

This proves simultaneous:

~~~text
consume products(word 0) -> S0
refill product pipeline with word 1
~~~

---

## 10. Directed Test 5 — Word-2 products and S1 accumulation preparation

At the following stage verify:

~~~text
product_pipe0 = 9
product_pipe1 = 0
product_pipe2 = 0
product_pipe3 = 0

partial_sum_pipe = 26
accumulator = 10
~~~

This proves:

~~~text
S0 consumed by accumulator
S1 stored in partial_sum_pipe
word-2 products captured
~~~

---

## 11. Directed Test 6 — S2 and accumulator progression

At the next stage verify:

~~~text
partial_sum_pipe = 9
accumulator = 36
~~~

This proves:

~~~text
10 + 26 = 36
~~~

and that the final word contribution has propagated correctly through both pipeline boundaries.

---

## 12. Directed Test 7 — Final result

At ST_WORD2:

~~~text
result
= accumulator + partial_sum_pipe
= 36 + 9
= 45
~~~

Required:

~~~text
result = 45
done = 1
~~~

On the next cycle:

~~~text
done = 0
~~~

Exactly one completion pulse is required.

---

## 13. Directed Test 8 — Requantized output

The existing requantization remains:

~~~text
45 x 3 = 135
rounding bias = 2
137 >> 2 = 34
~~~

Therefore:

~~~text
activation_out = 34 = 0x22
~~~

The product pipeline must not alter arithmetic meaning.

---

## 14. Directed Test 9 — Top-level latency

Previous measured latency:

~~~text
80 ns
= 8 cycles
~~~

Stage-2 predicted latency:

~~~text
90 ns
= 9 cycles
~~~

Measurement origin:

~~~text
accepted core_start
~~~

Measurement endpoint:

~~~text
raw core_done
~~~

Acceptance criterion:

~~~text
raw_done_time - accepted_start_time = 90 ns
~~~

Do not measure from physical btn_start.

---

## 15. Directed Test 10 — Reset clears product pipeline

The new product registers must be cleared by reset:

~~~text
product_pipe0 = 0
product_pipe1 = 0
product_pipe2 = 0
product_pipe3 = 0
~~~

Also require:

~~~text
partial_sum_pipe = 0
accumulator = 0
result = 0
done = 0
~~~

A stale product must never survive reset into a later transaction.

---

## 16. Directed Test 11 — Reset during active product pipeline

Assert clean synchronous reset while the transaction is active after product capture.

Expected after reset is sampled:

~~~text
state = ST_IDLE
all product_pipe registers = 0
partial_sum_pipe = 0
accumulator = 0
result = 0
done = 0
~~~

No stale completion event may appear after reset release.

---

## 17. Directed Test 12 — Post-reset recovery

After reset release, a fresh transaction must again produce:

~~~text
products word0 = 1,2,3,4
S0 = 10

products word1 = 5,6,7,8
S1 = 26

products word2 = 9,0,0,0
S2 = 9

result = 45
activation_out = 34
latency = 90 ns
one completion event
~~~

---

## 18. Continuous invariants

The testbench should enforce:

~~~text
activation_rd_en == weight_rd_en

if activation_rd_en:
    activation_addr == weight_addr

request count per transaction <= 3

done is one cycle wide

product word order:
word0 -> word1 -> word2

partial sums:
10 -> 26 -> 9

accumulator:
0 -> 10 -> 36

one accepted transaction
-> exactly one completion event
~~~

---

## 19. Scoreboard counters

Recommended counters:

~~~text
accepted_start_count
request_count
product_capture_count
partial_sum_capture_count
raw_done_count
error_count
~~~

Expected nominal transaction:

~~~text
accepted_start_count = 1
request_count = 3
product_capture_count = 3
partial_sum_capture_count = 3
raw_done_count = 1
error_count = 0
~~~

---

## 20. Why internal observation is required

Checking only:

~~~text
activation_out = 34
~~~

would not prove the new Stage-2 timing contract.

The testbench must observe:

~~~text
product_pipe0..3
partial_sum_pipe
accumulator
state
~~~

to catch:

~~~text
wrong product word
wrong cycle alignment
off-by-one state transition
partial-sum computed from wrong product set
stale product data
premature accumulation
premature done
~~~

---

## 21. What behavioral simulation cannot prove

Even a perfect zero-error run cannot prove:

~~~text
new LUT count
new FF count
new CARRY4 count
BRAM mapping
new critical path
WNS
TNS
WHS
THS
WPWS
TPWS
100 MHz timing closure
~~~

These require fresh synthesis and implementation.

---

## 22. Physical flow after behavioral PASS

After simulation:

~~~text
fresh synthesis
-> fresh utilization report
-> fresh implementation
-> fresh timing summary
~~~

Compare against the current Stage-1 physical baseline:

~~~text
LUT = 487
FF = 154
CARRY4 = 96
RAMB18E1 = 2

WNS = -1.260 ns
TNS = -9.347 ns
WHS = +0.131 ns
THS = 0
~~~

Stage-2 succeeds physically only when:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

---

## 23. Verification pass criteria

Behavioral verification passes only when:

~~~text
[ ] reset clears product_pipe0..3
[ ] exactly 3 paired BRAM requests
[ ] request order 0 -> 1 -> 2

[ ] word-0 products = 1,2,3,4
[ ] word-1 products = 5,6,7,8
[ ] word-2 products = 9,0,0,0

[ ] S0 = 10
[ ] S1 = 26
[ ] S2 = 9

[ ] accumulator reaches 10
[ ] accumulator reaches 36
[ ] result = 45

[ ] exactly one engine_done
[ ] activation_out = 34 / 0x22
[ ] latency = 9 cycles / 90 ns

[ ] reset abort clears all new pipeline state
[ ] post-reset recovery passes
[ ] error_count = 0
~~~

---

## 24. Understanding gate

Before Step 7 testbench modification, explain in your own words:

1. Why must we verify product_pipe values separately from partial_sum_pipe?
2. What are the exact expected product-register values for words 0, 1, and 2?
3. Why must request count remain exactly three?
4. What partial-sum sequence must follow those products?
5. What accumulator values must follow?
6. Why is the final result still 45?
7. Why is latency expected to become 90 ns?
8. Why must product_pipe registers be explicitly checked after reset?
9. Why can simulation prove product/partial-sum alignment but not timing closure?
10. What post-route conditions define successful Stage-2 timing closure?
