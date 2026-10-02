# Basys 3 Timing Closure — Step 8 Simulation Measurement

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 8 — behavioral simulation and measurement  
**Status:** COMPLETE — XSim behavioral verification PASS with zero errors.

## 1. Final simulation evidence

The initial XSim launch was configured for only:

```text
run 1000ns
```

so the first run stopped during TEST 4B before the testbench could terminate.

The simulation was then continued using:

```text
run all
```

Final transcript:

```text
TEST 5: post-reset recovery transaction
PASS: tb_basys3_top_level timing-closure verification completed with zero errors
$finish called at time : 1230 ns
```

Therefore the testbench reached its natural termination condition and completed every directed test.

---

## 2. Why the PASS is meaningful

The PASS line is emitted only when:

```text
error_count == 0
```

The testbench increments `error_count` whenever any protocol, pipeline, numerical, reset, or latency assertion fails.

Therefore the completed zero-error run means all implemented checks passed.

This does not mean “the final LED happened to be correct.” It means the complete assertion set completed without detecting a mismatch.

---

## 3. Pipeline sequence — measured verification result

The timing-closure testbench explicitly observes the internal pipelined engine after rising-edge sequential updates have settled.

Required sequence:

```text
after ST_PIPE0:
partial_sum_pipe = S0 = 10
accumulator      = 0

after ST_WORD0:
partial_sum_pipe = S1 = 26
accumulator      = 10

after ST_WORD1:
partial_sum_pipe = S2 = 9
accumulator      = 36

after ST_WORD2:
result = 45
```

Because the simulation completed with zero errors:

```text
S0 pipeline capture = PASS
S1 pipeline capture = PASS
S2 pipeline capture = PASS
accumulator 0 -> 10 = PASS
accumulator 10 -> 36 = PASS
final result 36 + 9 = 45 = PASS
```

This validates the new register boundary functionally and cycle-by-cycle.

---

## 4. Why the arithmetic is correct

Independent expected word contributions are:

```text
S0 = 1 + 2 + 3 + 4
   = 10

S1 = 5 + 6 + 7 + 8
   = 26

S2 = 9
```

Therefore:

```text
S0 + S1 + S2
= 10 + 26 + 9
= 45
```

The passing internal checks prove that the new pipeline did not drop, duplicate, or reorder a word contribution.

---

## 5. Memory request protocol

The testbench continuously checks:

```text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
```

and requires exactly:

```text
request 1 -> address 0
request 2 -> address 1
request 3 -> address 2
```

Any fourth request increments `error_count`.

Therefore the final zero-error PASS proves:

```text
paired request behavior = PASS
request order 0 -> 1 -> 2 = PASS
exactly three request cycles = PASS
no extra pipeline-induced BRAM request = PASS
```

The timing optimization changed arithmetic scheduling but did not alter operand traffic.

---

## 6. One-clock memory contract

The scoreboard records the expected activation and weight words for one request and checks the registered memory outputs against those expected words on the following clock relationship.

The final zero-error run therefore also preserves:

```text
one-clock synchronous operand-memory behavior = PASS
```

This is important because the new pipeline stage must operate on the correct returned BRAM word rather than assuming a combinational memory.

---

## 7. Engine result and requantized output

The testbench checks the internal engine result:

```text
engine result = 45
```

The existing requantization remains:

```text
M_INT     = 3
FRAC_BITS = 2
```

Therefore:

```text
45 x 3 = 135
rounding bias = 2
135 + 2 = 137
137 >> 2 = 34
```

Expected architectural output:

```text
activation_out = 34
               = 0x22
```

The zero-error PASS proves that the timing-closure modification preserved this end-to-end numerical result.

---

## 8. Latency measurement

The updated testbench measures from:

```text
accepted core_start
```

to:

```text
raw core_done
```

and requires:

```text
80 ns
```

At 100 MHz:

```text
Tclk = 10 ns

80 ns / 10 ns
= 8 cycles
```

The simulation ended with zero errors, so the explicit latency assertion passed:

```text
predicted latency = 8 cycles / 80 ns
measured assertion result = PASS
```

The old architecture measured 70 ns.

Therefore the intended pipeline cost is confirmed behaviorally:

```text
70 ns -> 80 ns
delta = +10 ns
      = +1 cycle
```

The overall testbench end time of 1230 ns is not the accelerator latency. It includes all reset, bounce, busy-mask, abort, and recovery tests.

---

## 9. Completion-event behavior

The testbench requires:

```text
one accepted transaction
-> exactly one raw core_done event
```

and also verifies persistent board completion separately through `done_latched`.

The final zero-error result therefore confirms:

```text
raw completion event count = correct
done remains protocol-style one-cycle event
board led_done persistence remains correct
```

The additional pipeline cycle did not duplicate the completion event.

---

## 10. Reset behavior with new pipeline state

The timing-closure redesign introduced:

```text
partial_sum_pipe
```

as new sequential state.

The updated testbench explicitly checks that reset clears:

```text
partial_sum_pipe = 0
accumulator      = 0
result / architectural output = 0
completion state = 0
```

It also exercises a clean synchronous reset while the transaction is active.

Because the full simulation passed:

```text
pipeline state reset = PASS
no stale partial sum after reset = PASS
clean transaction abort = PASS
no stale completion after abort = PASS
```

---

## 11. Post-reset recovery

The continued run explicitly reached:

```text
TEST 5: post-reset recovery transaction
```

and then printed the final PASS.

Therefore a fresh transaction after reset successfully repeated:

```text
three operand requests
S0 -> S1 -> S2 pipeline sequence
accumulator progression
result = 45
output = 34 / 0x22
80 ns transaction latency
completion indication
```

This demonstrates that reset does not leave the new pipeline in an unrecoverable or stale state.

---

## 12. Busy-mask and button behavior

The full testbench also retains the earlier Phase-8 checks for:

```text
physical button bounce rejection
held-button non-retrigger behavior
start_rise while core_busy -> core_start remains 0
physical reset -> eventual synchronized/debounced reset
persistent done LED behavior
```

Because the final run ended with zero errors, these wrapper behaviors remain compatible with the new one-cycle-longer accelerator.

---

## 13. Predicted versus measured behavioral results

| Quantity | Prediction | Step-8 behavioral result |
|---|---:|---:|
| Paired memory requests | 3 | PASS: exactly 3 |
| Request order | 0 -> 1 -> 2 | PASS |
| S0 | 10 | PASS |
| S1 | 26 | PASS |
| S2 | 9 | PASS |
| Accumulator after S0 | 10 | PASS |
| Accumulator after S1 | 36 | PASS |
| Final engine result | 45 | PASS |
| Requantized output | 34 / 0x22 | PASS |
| Added pipeline latency | +1 cycle | PASS |
| Accepted-start-to-done | 80 ns | PASS |
| Raw completion events | 1 | PASS |
| Reset clears new pipeline state | required | PASS |
| Post-reset recovery | required | PASS |
| Behavioral error count | 0 | 0 |

All behavioral predictions directly checked by the updated testbench match.

---

## 14. What this simulation proves

The completed XSim run proves the behavioral/cycle contract of the timing-closure redesign:

```text
functional arithmetic preserved
pipeline ordering correct
data/control sequencing aligned
memory traffic unchanged
latency changed exactly as predicted
reset/recovery preserved
wrapper protocol preserved
```

---

## 15. What this simulation does not prove

Behavioral simulation still does not prove:

```text
new synthesized FF count
new LUT count
new CARRY4 count
BRAM remains two RAMB18E1 after synthesis
new critical path
WNS
TNS
WHS
THS
WPWS
TPWS
100 MHz post-route timing closure
```

These require a new synthesis and implementation of the modified RTL.

---

## 16. Step-8 conclusion

**BASYS3 TIMING CLOSURE BEHAVIORAL VERIFICATION: PASS**

Final evidence:

```text
PASS: tb_basys3_top_level timing-closure verification completed with zero errors
$finish at 1230 ns
```

The timing-closure RTL is functionally validated.

The next workflow step is Step 9: update the measured-vs-predicted analysis with these behavioral measurements, followed by fresh synthesis/resource and implementation/timing measurements before physical timing sign-off.
