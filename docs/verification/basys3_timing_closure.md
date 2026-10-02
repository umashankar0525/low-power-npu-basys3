# Basys 3 Timing Closure — Verification Plan

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure  
**Workflow stage:** Step 6 — /verify basys3_timing_closure  
**Status:** VERIFICATION PLAN COMPLETE — understanding gate required before Step 7 verification-artifact generation.

---

## 1. Verification objective

Verify that the newly pipelined memory/dataflow engine:

1. preserves the original numerical convolution result,
2. preserves the three-word memory transaction contract,
3. preserves one-clock synchronous BRAM behavior,
4. aligns partial sums with the correct word identity,
5. adds exactly one pipeline cycle,
6. produces exactly one completion event,
7. integrates correctly with the existing top-level controller,
8. changes latency from 70 ns to the predicted 80 ns,
9. introduces no unintended extra memory requests,
10. preserves reset and recovery behavior.

This verification is functional and cycle-accurate.

It does not yet prove post-route timing closure.

---

## 2. RTL under verification

Primary changed module:

~~~text
rtl/compute/memory_interface_dataflow.v
~~~

Integration path:

~~~text
rtl/top/convolution_integration.v
rtl/top/basys3_top_level.v
~~~

Unchanged supporting modules include:

~~~text
rtl/memory/operand_bram_dual_read.v
rtl/control/control_fsm.v
~~~

The verification must prove both:

~~~text
local engine correctness
and
top-level integration correctness
~~~

because the timing change propagates into transaction latency.

---

## 3. Explicit assumptions

1. Clock remains 100 MHz.
2. Therefore one clock cycle is 10 ns.
3. Operand BRAM remains one-clock synchronous.
4. Operand request order remains fixed at 0,1,2.
5. Exactly three paired operand requests are required.
6. The pipeline register is one stage deep.
7. Pipeline register width is signed INT32.
8. The arithmetic test vector remains:
   - activations = 1,2,3,4,5,6,7,8,9
   - weights = all ones
9. Therefore expected reduced sums are:
   - S0 = 10
   - S1 = 26
   - S2 = 9
10. Expected accumulator total is 45.
11. Requantized output remains 34 / 0x22.
12. Top-level accepted-start-to-done latency is predicted as 8 cycles / 80 ns.
13. No RTL module other than memory_interface_dataflow was intentionally modified for the timing-closure step.

---

## 4. Verification layers

### Layer A — Memory request protocol

Observe:

~~~text
activation_rd_en
activation_addr
weight_rd_en
weight_addr
~~~

Required invariants:

~~~text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
request order    = 0 -> 1 -> 2
paired request count = 3
~~~

No fourth request is allowed.

---

## 5. Pipeline-stage verification

Observe internal:

~~~text
partial_sum_pipe
state
~~~

The expected sequence is:

~~~text
ST_PIPE0:
partial_sum_pipe <= S0 = 10

ST_WORD0:
accumulator      <= 10
partial_sum_pipe <= S1 = 26

ST_WORD1:
accumulator      <= 36
partial_sum_pipe <= S2 = 9

ST_WORD2:
result <= 45
done   <= 1
~~~

This is the central new property introduced by the redesign.

---

## 6. Independent partial-sum derivation

Word 0:

~~~text
activations = 1,2,3,4
weights     = 1,1,1,1

S0
= 1*1 + 2*1 + 3*1 + 4*1
= 10
~~~

Word 1:

~~~text
activations = 5,6,7,8
weights     = 1,1,1,1

S1
= 5 + 6 + 7 + 8
= 26
~~~

Word 2:

~~~text
activations = 9,0,0,0
weights     = 1,0,0,0

S2
= 9
~~~

Therefore:

~~~text
S0 + S1 + S2
= 10 + 26 + 9
= 45
~~~

The scoreboard must compare against these independently derived values.

---

## 7. Directed Test 1 — Reset and idle state

After reset:

~~~text
state            = ST_IDLE
accumulator      = 0
partial_sum_pipe = 0
result           = 0
done             = 0
activation_rd_en = 0
weight_rd_en     = 0
~~~

No memory request should occur while idle.

This verifies deterministic startup after introducing the new pipeline state.

---

## 8. Directed Test 2 — First request

On a legal start:

~~~text
activation_addr  = 0
weight_addr      = 0
activation_rd_en = 1
weight_rd_en     = 1
~~~

Exactly one paired request for word 0 is issued.

Expected state transition:

~~~text
ST_IDLE -> ST_WAIT0
~~~

---

## 9. Directed Test 3 — Request stream remains 0 -> 1 -> 2

Expected request sequence:

~~~text
request 1: address 0
request 2: address 1
request 3: address 2
~~~

Required invariants:

~~~text
activation_addr == weight_addr
activation_rd_en == weight_rd_en
~~~

Request count:

~~~text
3
~~~

No extra request is permitted because the pipeline changes arithmetic timing, not memory demand.

---

## 10. Directed Test 4 — S0 pipeline capture

When word 0 is valid at the arithmetic input:

~~~text
partial_sum = 10
~~~

At the ST_PIPE0 capture edge:

~~~text
partial_sum_pipe <= 10
~~~

Accumulator must still be:

~~~text
0
~~~

This proves that the new stage delays accumulation rather than accidentally performing the old same-cycle update.

---

## 11. Directed Test 5 — S0 accumulation and S1 pipeline capture

At the next edge:

~~~text
accumulator      <= 0 + 10
                 = 10

partial_sum_pipe <= 26
~~~

After the edge:

~~~text
accumulator      = 10
partial_sum_pipe = 26
~~~

This proves simultaneous consume-and-refill behavior of the one-stage pipeline.

---

## 12. Directed Test 6 — S1 accumulation and S2 pipeline capture

At the following edge:

~~~text
accumulator      <= 10 + 26
                 = 36

partial_sum_pipe <= 9
~~~

After the edge:

~~~text
accumulator      = 36
partial_sum_pipe = 9
~~~

This proves that word 2 remains aligned with the final pipeline stage.

---

## 13. Directed Test 7 — Final result and engine_done

At ST_WORD2:

~~~text
result
<= accumulator + partial_sum_pipe
= 36 + 9
= 45
~~~

Required:

~~~text
result = 45
done   = 1
~~~

The done pulse must occur exactly once.

On the following cycle:

~~~text
done = 0
~~~

This verifies one-cycle completion semantics.

---

## 14. Directed Test 8 — Requantized architectural result

The integration path must still produce:

~~~text
engine_result = 45
~~~

With:

~~~text
M_INT = 3
FRAC_BITS = 2
~~~

the expected result is:

~~~text
45 x 3 = 135
bias   = 2
137 >> 2 = 34
~~~

Therefore:

~~~text
activation_out = 34
               = 0x22
~~~

At board level:

~~~text
LED1 = ON
LED5 = ON
~~~

No numerical behavior may change because of the pipeline.

---

## 15. Directed Test 9 — Top-level latency

The old measured latency was:

~~~text
accepted core_start
-> raw core_done
= 7 cycles
= 70 ns
~~~

The redesigned prediction is:

~~~text
8 cycles
= 80 ns
~~~

Measurement points:

~~~text
start:
rising edge where core_start is legally accepted

end:
raw core_done event
~~~

Do not measure from the physical button transition because debounce latency is unrelated to accelerator compute latency.

Acceptance criterion:

~~~text
measured latency = 80 ns
~~~

for the directed board configuration.

---

## 16. Directed Test 10 — Persistent done behavior

The existing board wrapper converts raw core_done into a persistent completion indication.

After the raw completion event:

~~~text
done_latched -> 1
led_done     -> 1
~~~

The pipeline redesign must not alter the meaning of the persistent board indication.

The only intended behavioral change is that completion occurs one core cycle later.

---

## 17. Directed Test 11 — Reset during pipeline activity

Assert clean synchronous reset while the engine is active.

Expected after reset is sampled:

~~~text
state            = ST_IDLE
accumulator      = 0
partial_sum_pipe = 0
result           = 0
done             = 0
~~~

No stale pipelined partial sum may survive reset.

This is especially important because the redesign introduced new state that must be explicitly cleared.

---

## 18. Directed Test 12 — Post-reset recovery

After reset:

1. release reset,
2. issue a new legal start,
3. observe the full three-request sequence,
4. observe S0/S1/S2 progression,
5. observe result 45,
6. observe activation_out 34,
7. observe one completion event.

This proves the new pipeline does not create stale transaction state.

---

## 19. Continuous invariants

The verification artifact should enforce continuously:

~~~text
activation_rd_en == weight_rd_en

if activation_rd_en:
    activation_addr == weight_addr

request count per accepted transaction <= 3

done is one cycle wide

partial_sum_pipe progression follows:
S0 -> S1 -> S2

result is not declared final before S2 is consumed

one accepted transaction
-> exactly one engine_done

one accepted transaction
-> exactly three paired memory requests
~~~

Unexpected request activity outside a legal transaction is an error.

---

## 20. Scoreboard counters

Maintain counters for:

~~~text
accepted_start_count
request_count
engine_done_count
pipeline_capture_count
error_count
~~~

Expected for one nominal transaction:

~~~text
accepted_start_count = 1
request_count        = 3
engine_done_count    = 1
pipeline_capture_count = 3
error_count          = 0
~~~

These counts prove that pipelining did not duplicate or drop a transaction stage.

---

## 21. Why internal observation is justified

For this timing-closure verification, hierarchical observation of:

~~~text
state
partial_sum_pipe
accumulator
result
~~~

is justified because the redesign specifically changes internal sequential timing.

Checking only the final output 34 would not prove that the pipeline is correctly aligned.

A wrong pipeline implementation could accidentally produce 34 for one directed vector while still violating the intended scheduling contract.

---

## 22. What simulation cannot prove

Even if every functional test passes, simulation still cannot prove:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

It also cannot prove final:

~~~text
LUT count
FF count
CARRY4 count
BRAM mapping after modification
new critical path
routing delay
~~~

Those require synthesis and implementation.

---

## 23. Post-simulation physical flow

After functional verification passes:

~~~text
simulation
-> synthesis
-> compare resources against prediction
-> confirm BRAM remains inferred
-> implementation
-> post-route STA
~~~

New timing must be compared against the old baseline:

~~~text
old WNS = -3.453 ns
old TNS = -99.753 ns
old critical path delay = 13.433 ns
~~~

The redesign succeeds physically only if:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

---

## 24. Verification pass criteria

Functional verification passes only when all of the following hold:

~~~text
[ ] reset clears partial_sum_pipe
[ ] exactly 3 paired BRAM requests
[ ] request order = 0 -> 1 -> 2
[ ] S0 = 10 captured correctly
[ ] S1 = 26 captured correctly
[ ] S2 = 9 captured correctly
[ ] accumulator reaches 10
[ ] accumulator reaches 36
[ ] final result = 45
[ ] exactly one engine_done pulse
[ ] activation_out = 34 / 0x22
[ ] accepted-start-to-done latency = 8 cycles / 80 ns
[ ] reset during pipeline activity clears all new state
[ ] post-reset recovery works
[ ] error_count = 0
~~~

Only then should synthesis and implementation be rerun.

---

## 25. Understanding gate

Before Step 7 verification-artifact generation, explain in your own words:

1. Why is checking only output 0x22 insufficient?
2. What exact S0/S1/S2 values must be observed?
3. What accumulator values must appear before the final result?
4. Why must request count remain exactly three?
5. Why must partial_sum_pipe be reset explicitly?
6. Why should done still be one cycle wide?
7. Why is the expected latency now 80 ns?
8. Why do we measure from accepted core_start rather than the physical button?
9. Why can simulation prove pipeline correctness but not timing closure?
10. What exact post-route conditions must later prove successful 100 MHz closure?


---

## Step 7 Verification Artifact Record

**Status:** COMPLETE — integration testbench updated for the pipelined timing-closure architecture.

Updated artifact:

```text
tb/integration/tb_basys3_top_level.v
```

The updated testbench now explicitly verifies:

```text
partial_sum_pipe captures S0 = 10
accumulator remains 0 before S0 consumption

partial_sum_pipe captures S1 = 26
accumulator becomes 10

partial_sum_pipe captures S2 = 9
accumulator becomes 36

engine result becomes 45
activation_out becomes 34 / 0x22

exactly three paired memory requests
request order 0 -> 1 -> 2
exactly one raw completion event

accepted core_start -> raw core_done
= 80 ns predicted

reset clears partial_sum_pipe
reset clears accumulator
post-reset recovery repeats the full pipeline sequence
```

The monitor samples the internal pipeline on the falling edge after the relevant rising-edge nonblocking assignments have settled. This avoids treating pre-update values as post-update state.

Internal state encoding used by the verification monitor:

```text
ST_PIPE0 = 3'd2
ST_WORD0 = 3'd3
ST_WORD1 = 3'd4
ST_WORD2 = 3'd5
```

The testbench does not claim physical timing closure. A zero-error behavioral run proves only the intended functional/cycle contract. Synthesis and implementation must still be rerun afterward.
