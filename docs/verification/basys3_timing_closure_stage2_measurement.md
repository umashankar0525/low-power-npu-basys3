# Basys 3 Timing Closure Stage 2 — Behavioral Measurement

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure_stage2`  
**Workflow stage:** Step 8 — simulation and measurement  
**Simulator:** Vivado XSim 2018.2  
**Status:** PASS — zero behavioral errors.

## 1. Simulation evidence

The updated Stage-2 RTL and integration testbench compiled and elaborated successfully.

The first automatic simulation command was:

```text
run 1000ns
```

At 1000 ns the testbench had reached:

```text
TEST 4B: clean reset_level abort while busy
```

This was not the end of the testbench.

After running:

```text
run all
```

XSim continued and reported:

```text
TEST 5: post-reset recovery transaction
PASS: tb_basys3_top_level Stage-2 timing-closure verification completed with zero errors
$finish called at time : 1250 ns
```

Therefore the complete Stage-2 behavioral simulation passed.

## 2. Meaning of the 1250 ns finish time

The reported:

```text
1250 ns
```

is the total duration of the complete testbench.

It is **not** the accelerator transaction latency.

The transaction latency is checked independently by an assertion measuring:

```text
accepted core_start
->
raw core_done
```

against:

```text
90 ns
```

Because the final testbench ended with zero errors, that 90 ns assertion passed.

Thus:

```text
Stage-2 transaction latency = 90 ns
                            = 9 cycles at 100 MHz
```

## 3. Product-pipeline verification

The Stage-2 testbench explicitly checks the four product registers.

Expected word-0 products:

```text
1,2,3,4
```

Expected word-1 products:

```text
5,6,7,8
```

Expected word-2 products:

```text
9,0,0,0
```

Because `error_count` remained zero through final completion, all three product-register observations passed.

Therefore the new product-register boundary is behaviorally aligned with the three BRAM words.

## 4. Partial-sum verification

The testbench explicitly checks:

```text
S0 = 10
S1 = 26
S2 = 9
```

The zero-error completion proves all three assertions passed.

Thus:

```text
product word 0 -> S0 = 10
product word 1 -> S1 = 26
product word 2 -> S2 = 9
```

is behaviorally confirmed.

## 5. Accumulator progression

The expected accumulation sequence is:

```text
0
-> 10
-> 36
-> 45
```

The testbench explicitly checks:

```text
accumulator = 10
accumulator = 36
final result = 45
```

All passed.

Therefore the second pipeline stage did not alter the convolution arithmetic.

## 6. Final activation result

The engine result remains:

```text
45
```

Requantization remains:

```text
45 x 3 = 135
135 + 2 = 137
137 >> 2 = 34
```

Therefore:

```text
activation_out = 34 = 0x22
```

The board-visible result check passed because the complete simulation ended with zero errors.

## 7. BRAM request protocol

The testbench checks:

```text
exactly 3 paired operand requests
request order 0 -> 1 -> 2
activation_rd_en == weight_rd_en
activation_addr == weight_addr
one-clock synchronous memory-return relationship
```

All passed.

Therefore adding the product pipeline did not add or remove memory traffic.

## 8. Completion behavior

The testbench requires:

```text
one accepted transaction
-> exactly one raw core_done event
```

The nominal transaction completed with no scoreboard error.

The latched LED completion behavior also remained valid.

## 9. Reset behavior

Both reset paths remained covered.

### Physical reset path

The physical reset button is synchronized and debounced.

The test verifies eventual architectural clear after the clean reset level reaches the core.

### Clean synchronous reset while busy

The testbench forces the already-clean `reset_level` during an active transaction.

The Stage-2 reset checks explicitly require:

```text
product_pipe0 = 0
product_pipe1 = 0
product_pipe2 = 0
product_pipe3 = 0
partial_sum_pipe = 0
accumulator = 0
result = 0
done = 0
```

and require no stale completion after reset release.

The zero-error final result confirms all these checks passed.

## 10. Post-reset recovery

TEST 5 completed:

```text
TEST 5: post-reset recovery transaction
```

and the testbench then printed the zero-error PASS.

Therefore a fresh transaction after reset again successfully produced:

```text
product words correctly aligned
S0 = 10
S1 = 26
S2 = 9
accumulator = 10 -> 36
result = 45
activation_out = 34
latency = 90 ns
```

## 11. Predicted versus measured behavioral results

| Quantity | Prediction | Measurement | Result |
|---|---:|---:|---|
| Word-0 products | 1,2,3,4 | assertion passed | MATCH |
| Word-1 products | 5,6,7,8 | assertion passed | MATCH |
| Word-2 products | 9,0,0,0 | assertion passed | MATCH |
| S0 | 10 | assertion passed | MATCH |
| S1 | 26 | assertion passed | MATCH |
| S2 | 9 | assertion passed | MATCH |
| Accumulator after S0 | 10 | assertion passed | MATCH |
| Accumulator after S1 | 36 | assertion passed | MATCH |
| Final engine result | 45 | assertion passed | MATCH |
| Activation output | 34 / 0x22 | assertion passed | MATCH |
| BRAM requests | 3 | assertion passed | MATCH |
| Request order | 0 -> 1 -> 2 | assertion passed | MATCH |
| Transaction latency | 90 ns | assertion passed | EXACT MATCH |
| Raw completion events | 1 | assertion passed | MATCH |
| Reset clears new registers | required | assertion passed | MATCH |
| Post-reset recovery | required | PASS | MATCH |
| Behavioral error count | 0 | 0 | MATCH |

## 12. What this proves

XSim now proves that the second timing-closure architecture is functionally and cycle-correct.

It proves:

```text
new product pipeline alignment
partial-sum alignment
accumulator alignment
three-request memory protocol
one-clock BRAM functional behavior
90 ns transaction latency
result = 45
activation_out = 34
reset clearing
post-reset recovery
one completion event
```

## 13. What this does not prove

Behavioral simulation does not prove the physical timing result.

It does not measure:

```text
new LUT count
new FF count
new CARRY4 count
new critical path
WNS
TNS
WHS
THS
WPWS
TPWS
physical route delay
physical logic delay
100 MHz timing closure
```

These require fresh synthesis and implementation of the Stage-2 RTL.

## 14. Step-8 conclusion

```text
Functional correctness       PASS
Product pipeline             PASS
Partial-sum pipeline         PASS
Accumulator progression      PASS
Memory protocol              PASS
Latency = 90 ns / 9 cycles  PASS
Reset behavior               PASS
Post-reset recovery          PASS
Behavioral error count       0

Fresh synthesis              PENDING
Fresh implementation         PENDING
100 MHz physical closure     NOT YET PROVEN
```

The next required measurement is a fresh synthesis followed by fresh implementation/post-route static timing analysis.
