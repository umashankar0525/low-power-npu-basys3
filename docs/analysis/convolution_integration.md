# Convolution Integration — Prediction and Measured Analysis

**Role:** Performance Analyst  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 9 — measured-versus-predicted analysis update  
**Status:** Behavioral performance predictions updated with Step-8 XSim measurements. Integrated synthesis/resource usage and post-route timing remain unmeasured.

---

## 1. Purpose of This Update

This document began as the pre-RTL prediction analysis for Phase 7. Step 8 has now produced behavioral XSim evidence for the integrated transaction, so Step 9 compares the original predictions against measured functional timing and transaction behavior.

The integrated path is:

```text
external start
 -> control_fsm
 -> memory_interface_dataflow
 -> signed INT32 convolution result
 -> requantize_relu_pipelined
 -> architectural INT8 activation_out register
 -> external done
```

The central question is not merely whether the final number is correct. The analysis must determine whether the implemented system preserves the predicted cycle structure, transaction spacing, memory activity, and arithmetic data association.

---

## 2. Explicit Assumptions

1. Target FPGA: XC7A35T-1CPG236C on Basys 3.
2. Behavioral simulation tool: Vivado XSim 2018.2.
3. Clock frequency: 100 MHz.
4. Clock period:

```text
Tclk = 1 / 100,000,000
     = 10 ns
```

5. Convolution size: 3 x 3.
6. Input channels: 1.
7. Output channels in the current transaction: 1.
8. Useful convolution terms per output: 9.
9. Four signed INT8 activation lanes and four signed INT8 weight lanes are packed into each 32-bit word pair.
10. Three activation words and three weight words are required per transaction.
11. The third packed word uses lane 0 for element 8 and zero-pads lanes 1..3.
12. The testbench memories model one-clock synchronous read latency.
13. Generated INT8 activation and weight range is `[-127,+127]`.
14. The maximum legal positive 3x3 accumulator remains:

```text
9 x 127 x 127 = 145161
```

15. The requantizer has one registered 42-bit product stage.
16. `activation_out` is the architectural transaction-result register.
17. The Phase-7 integration core intentionally contains no physical BRAM instance.
18. Behavioral XSim can measure functional/cycle timing but cannot measure technology-mapped LUT/FF/DSP usage or routed timing closure.
19. Resource predictions remain predictions until integrated synthesis is performed.
20. Setup/hold timing remains unmeasured until implementation and static timing analysis are performed on the integrated design.

---

## 3. Work Per Transaction

For one 3x3, one-channel convolution output:

```text
y = sum(i=0..8) a[i] x w[i]
```

Therefore:

```text
useful INT8 multiplications = 9
useful MAC contributions    = 9
```

Using the convention that one MAC is one multiply plus one accumulation contribution:

```text
9 useful MACs / transaction
```

If multiply and addition are counted as separate arithmetic operations:

```text
9 multiplies + 9 accumulation additions = 18 operations
```

The remainder of this document uses MAC/s because that convention is less ambiguous.

---

## 4. Packed-Lane Utilization

The four-lane engine processes three packed word pairs:

```text
4 lanes/word x 3 words = 12 multiplier slots
```

Only nine correspond to real 3x3 terms:

```text
useful lane utilization = 9 / 12
                        = 0.75
                        = 75%
```

The unused three slots are the zero-padded lanes in the final packed word.

This remains a structural property rather than a simulator-dependent measurement.

---

## 5. Pre-RTL Latency Prediction

The approved edge schedule was:

```text
E0: external start accepted
E1: engine accepts engine_start and requests word 0
E2: request word 1 / synchronous-memory pipeline advances
E3: consume word 0 and request word 2
E4: consume word 1
E5: consume word 2; register final INT32 result and engine_done
E6: controller enters capture interval; product_reg captures final product
E7: activation_out captures q_out; controller enters DONE
E8: controller returns to IDLE
E9: earliest next accepted external start
```

From E0 to E7:

```text
7 clock periods x 10 ns = 70 ns
```

Original prediction:

```text
accepted start -> valid activation_out with done = 70 ns
```

---

## 6. Measured Start-to-Done Latency

Step-8 XSim records the accepted external-start timestamp and the external-done timestamp.

For the maximum-width directed transaction, the captured values were:

```text
first_start_time   = 0x31B = 795 ns
measured_done_time = 0x361 = 865 ns
```

Therefore:

```text
865 ns - 795 ns = 70 ns
```

Equivalently:

```text
70 ns / 10 ns = 7 clock periods
```

### Result

```text
Predicted latency = 70 ns
Measured latency  = 70 ns
Error             = 0 ns
Relative error    = 0%
```

The central Phase-7 behavioral latency prediction is therefore confirmed for the exercised integration tests.

---

## 7. Why the 70 ns Measurement Is Architecturally Meaningful

The testbench does not obtain 70 ns from the simulation finish time. It measures edge-to-edge transaction timing.

It also checks the internal data association:

```text
E5:
    engine_result = final signed INT32 convolution result

E6:
    product_reg = product derived from that E5 result
    capture_activation = 1
    requantized_q = correct rounded/shifted/saturated value

E7:
    activation_out captures that q_out
    done becomes externally visible
```

Therefore the measured 70 ns is not merely a handshake delay. It corresponds to a correctly associated convolution result passing through the registered requantization stage and into the architectural output register.

---

## 8. Busy Duration

The controller definition gives:

```text
busy = 1 in LAUNCH
busy = 1 in WAIT_ENGINE
busy = 1 in CAPTURE_ACTIVATION
busy = 1 in DONE
busy = 0 only in IDLE
```

From E0 until the return to IDLE at E8:

```text
busy-high duration = 8 cycles
                   = 8 x 10 ns
                   = 80 ns
```

Step-8 checks confirmed that `busy=1` during the DONE interval and that it returns low after DONE -> IDLE. The testbench did not store a separate busy-rise/busy-fall timestamp as a dedicated 80 ns measurement, so 80 ns remains a protocol-derived value that is behaviorally consistent with the observed transaction sequence rather than an independently timestamped metric.

---

## 9. Pre-RTL Initiation-Interval Prediction

A new start is legal only while `busy=0`.

The first transaction is accepted at E0. The controller returns to IDLE at E8, after which the next legal one-cycle start can be presented and sampled at E9.

Therefore:

```text
minimum accepted-start spacing = E0 -> E9
                               = 9 cycles
                               = 90 ns
```

---

## 10. Measured Initiation Interval

The back-to-back directed test records two accepted-start timestamps and explicitly checks:

```text
second_start_time - first_start_time == 90 ns
```

The full integration simulation completed with zero detected errors, so this timing assertion passed.

### Result

```text
Predicted minimum initiation interval = 90 ns
Measured minimum initiation interval  = 90 ns
Error                                 = 0 ns
Relative error                        = 0%
```

This confirms that result latency and transaction initiation interval are different architectural quantities:

```text
result valid / done = 70 ns
next legal accepted start = 90 ns
```

---

## 11. Sustained Transaction Throughput Derived from Measured Initiation Interval

The measured minimum initiation interval is:

```text
90 ns
```

Therefore the maximum protocol-level repeated acceptance rate is:

```text
throughput = 1 / 90 ns
           = 1 / (90 x 10^-9)
           = 11,111,111.11 transactions/s
```

Equivalent clock-domain derivation:

```text
100,000,000 clocks/s / 9 clocks/transaction
= 11.11 million transactions/s
```

### Status

This is now **derived from a behaviorally measured 90 ns initiation interval**. It is not a long-duration physical FPGA benchmark.

---

## 12. Useful Sustained MAC Rate

Each transaction contains nine useful MAC contributions.

Using the measured initiation interval:

```text
9 MAC/transaction x 11,111,111.11 transactions/s
= 100,000,000 MAC/s
```

Therefore:

```text
sustained useful rate = 100 MMAC/s
```

If one chooses the convention `1 MAC = 2 arithmetic operations`:

```text
100 MMAC/s x 2 = 200 MOPS
```

This rate is derived from the measured protocol timing, not from direct FPGA performance counters.

For comparison, dividing one isolated transaction by the 70 ns result latency gives:

```text
9 MAC / 70 ns = 128.57 MMAC/s
```

but that is not sustainable because the interface cannot accept the next transaction at E7.

---

## 13. Memory Traffic Per Transaction

Each memory performs three 32-bit reads:

```text
activation traffic = 3 x 32 bits = 96 bits = 12 bytes
weight traffic     = 3 x 32 bits = 96 bits = 12 bytes
```

Combined physical traffic:

```text
12 + 12 = 24 bytes / transaction
```

Useful payload:

```text
9 activation bytes + 9 weight bytes = 18 useful bytes
```

Packing efficiency:

```text
18 / 24 = 75%
```

Step-8 scoreboard evidence confirmed exactly three tracked request cycles with address order:

```text
0 -> 1 -> 2
```

for the activation and weight interfaces together.

Therefore the predicted three-word-per-memory transaction pattern is behaviorally confirmed.

---

## 14. Peak Memory-Port Bandwidth

Each memory interface is 32 bits wide.

At 100 MHz:

```text
32 bits/cycle x 100 MHz = 3.2 Gb/s
```

Per memory:

```text
3.2 Gb/s / 8 = 400 MB/s
```

For two independent ports operating in parallel:

```text
2 x 400 MB/s = 800 MB/s
```

### Status

`800 MB/s` is an architectural peak port-rate calculation. XSim confirms the 100 MHz timing model and simultaneous activation/weight request behavior, but it is not a physical FPGA memory-throughput benchmark.

---

## 15. Sustained Memory Bandwidth Derived from Measured Transaction Spacing

The behaviorally confirmed physical traffic is:

```text
24 bytes / transaction
```

and the measured minimum initiation interval is:

```text
90 ns / transaction
```

Therefore:

```text
24 bytes / 90 ns
= 266,666,666.67 bytes/s
= 266.67 MB/s
```

Useful operand bandwidth is:

```text
18 bytes / 90 ns
= 200 MB/s
```

Per-memory physical average:

```text
12 bytes / 90 ns = 133.33 MB/s
```

Per-memory useful average:

```text
9 bytes / 90 ns = 100 MB/s
```

These bandwidth figures are derived from behaviorally confirmed request count and initiation timing, not from a routed BRAM subsystem measurement.

---

## 16. Nominal End-to-End Arithmetic Measurement

For the primary nominal vector:

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

Independent convolution:

```text
engine_result = 1+2+3+4+5+6+7+8+9
              = 45
```

With:

```text
M_INT = 3
FRAC_BITS = 2
```

requantization is:

```text
product = 45 x 3 = 135
bias    = 2^(2-1) = 2
rounded = 135 + 2 = 137
q_out   = 137 >> 2 = 34
```

Step-8 completed with zero errors while checking:

```text
E5 engine_result  = 45
E6 product_reg    = 135
E6 requantized_q  = 34
E7 activation_out = 34
```

Thus the nominal datapath and timing prediction match exactly.

---

## 17. Boundary-Case Measurements

The directed integration run also confirmed the following exercised cases.

### Negative convolution through ReLU

```text
engine_result  = -45
product_reg    = 0
activation_out = 0
```

This proves that the final zero is produced after a valid negative signed convolution result rather than by accidental arithmetic cancellation.

### Maximum legal positive accumulator

```text
9 x 127 x 127 = 145161
```

Primary requantization:

```text
145161 x 3 = 435483
(435483 + 2) >> 2 = 108871
108871 > 127
```

Therefore:

```text
activation_out = 127
```

The directed saturation test passed.

### Rounding-visible case

```text
engine_result = 5
product_reg   = 15
q_out         = (15 + 2) >> 2 = 4
```

The directed test passed and the observed architectural output reached `0x04`.

### Maximum-width requantization case

For:

```text
M_INT = 16777215
FRAC_BITS = 42
engine_result = 145161
```

raw product:

```text
145161 x 16777215 = 2435397306615
```

rounding intermediate:

```text
2435397306615 + 2^41
= 4634420562167
```

then:

```text
4634420562167 >> 42 = 1
```

The integration test observed the expected final value:

```text
activation_out = 1
```

with the same measured 70 ns transaction latency.

---

## 18. Handshake and Recovery Measurements

Step-8 also exercised protocol behavior, not just arithmetic.

### Start while busy

The testbench injects an additional `start` while the current transaction is active and checks that the active transaction still has:

```text
engine_start count = 1
memory request count = 3
capture count = 1
done count = 1
```

The test passed with zero detected errors, so the illegal busy-time start did not create a second transaction.

### Reset during an active transaction

The testbench asserts synchronous reset after a transaction has started and checks that control, engine result, memory enables, output register, and requantizer product state return to their reset values.

A fresh post-reset transaction then produces:

```text
5 -> product 15 -> output 4
```

The recovery test passed.

---

## 19. Logical Multiplier Prediction — Still Awaiting Integrated Synthesis

The structural RTL contains:

```text
4 signed INT8 x INT8 convolution multipliers
1 unsigned 18 x 24 requantization multiplier
```

Therefore:

```text
logical multipliers = 5
```

The pre-RTL resource prediction remains:

```text
4 INT8 multipliers -> expected LUT/carry implementation
1 requantization multiplier -> expected DSP48E1
expected DSP48E1 total = 1
```

### Measurement status

Behavioral XSim does not technology-map these multipliers.

Therefore:

```text
Integrated DSP48E1 count = NOT YET MEASURED
Integrated LUT multiplier mapping = NOT YET MEASURED
```

A synthesis utilization report is required before converting this prediction into a measured result.

---

## 20. Logical Registered-State Prediction — Still Awaiting Synthesis Mapping

Pre-synthesis RTL-visible registered storage is:

### `memory_interface_dataflow`

```text
state              = 3
accumulator        = 32
result             = 32
done               = 1
activation_rd_en   = 1
activation_addr    = 2
weight_rd_en       = 1
weight_addr        = 2
--------------------------------
total              = 74 bits
```

### `control_fsm`

```text
state = 3 bits
```

### `requantize_relu_pipelined`

```text
product_reg = 42 bits
```

### Integration wrapper

```text
activation_out = 8 bits
```

Total logical registered storage:

```text
74 + 3 + 42 + 8 = 127 bits
```

This does not imply 127 Slice FFs. Synthesis may place product storage inside DSP `PREG`, optimize constant bits, trim redundant bits, or change state implementation.

Therefore:

```text
127 logical registered bits = structural RTL count
physical Slice FF count     = NOT YET MEASURED
```

---

## 21. BRAM Prediction — Integration Core

The Phase-7 core exposes memory interfaces but does not instantiate physical memories.

Architectural prediction:

```text
internal BRAM in convolution_integration = 0
```

This is evident from the architecture and RTL structure, but a synthesis utilization report is still required if we want a technology-mapped resource report for the complete integrated core.

The eventual board-level NPU is expected to use FPGA memory outside this core, so this statement must not be generalized to the final accelerator.

---

## 22. Timing-Closure Prediction — Still Unmeasured

Candidate critical regions remain:

```text
A. INT8 multiply -> reduction tree -> accumulator input

B. engine_result register
   -> sign/ReLU magnitude preparation
   -> requantization multiplier
   -> product PREG

C. product PREG
   -> rounding
   -> right shift
   -> saturation
   -> activation_out register
```

The successful 100 MHz behavioral simulation proves the intended cycle semantics at a 10 ns modeled clock. It does **not** prove that the FPGA implementation can physically route all register-to-register paths within 10 ns.

To prove timing closure we still require:

```text
implementation / place-and-route
+ static timing analysis
+ setup/hold reports
+ WNS/TNS evidence
```

Therefore:

```text
100 MHz behavioral operation = CONFIRMED FUNCTIONALLY
100 MHz routed timing closure = NOT YET MEASURED
```

---

## 23. Predicted vs Measured Summary

| Metric | Pre-RTL prediction | Step-8 evidence | Status |
|---|---:|---:|---|
| Clock period | 10 ns | 10 ns testbench clock | Match |
| Useful MACs / transaction | 9 | structural arithmetic contract | Unchanged |
| Packed multiplier slots | 12 | structural packing contract | Unchanged |
| Useful lane utilization | 75% | structural `9/12` | Unchanged |
| Start-to-done latency | 70 ns | 70 ns | **Measured match** |
| Busy duration | 80 ns | protocol behavior consistent; not separately timestamped | Consistent |
| Minimum initiation interval | 90 ns | 90 ns assertion passed | **Measured match** |
| Max protocol transaction rate | 11.11 M/s | derived from measured 90 ns | Derived match |
| Sustained useful MAC rate | 100 MMAC/s | derived from measured 90 ns | Derived match |
| Memory request cycles / transaction | 3 | 3 | **Measured match** |
| Address order | `0 -> 1 -> 2` | scoreboard passed | **Measured match** |
| Physical memory traffic / transaction | 24 B | 3 x 32-bit reads from each of 2 memories | Confirmed by request pattern |
| Useful payload / transaction | 18 B | structural packing | Unchanged |
| Peak combined port rate | 800 MB/s | architectural calculation at 100 MHz | Not a physical benchmark |
| Sustained physical bandwidth | 266.67 MB/s | derived from 24 B / measured 90 ns | Derived match |
| Sustained useful bandwidth | 200 MB/s | derived from 18 B / measured 90 ns | Derived match |
| Nominal output | 34 | 34 | **Measured match** |
| Negative/ReLU output | 0 | 0 | **Measured match** |
| Maximum saturation output | 127 | 127 | **Measured match** |
| Rounding-visible output | 4 | 4 | **Measured match** |
| Maximum-width output | 1 | 1 | **Measured match** |
| Logical multipliers | 5 | structural RTL count | Unchanged |
| DSP48E1 count | 1 expected | no integrated synthesis report yet | **Pending** |
| Logical registered bits | 127 | structural RTL count | Unchanged |
| Physical Slice FF count | not exactly predictable | no integrated synthesis report yet | **Pending** |
| Internal BRAM | 0 expected | no integrated utilization report yet | Pending technology report |
| 100 MHz setup/hold closure | plausible | no integrated post-route STA yet | **Pending** |

---

## 24. Performance Interpretation

The most important result of Step 9 is that the cycle-level architecture behaved exactly as predicted for the exercised integration tests.

The key measured values are:

```text
start -> valid output + done = 70 ns
minimum next accepted start  = 90 ns
memory request sequence      = 0 -> 1 -> 2
requests per transaction     = 3 paired activation/weight requests
```

This means the supervisory overhead is now quantifiable.

A result is available after seven cycles, but the architecture accepts a new transaction only every nine cycles. Therefore two cycles per repeated transaction are unavailable for accepting new work after the output-valid edge sequence is considered.

The current architecture prioritizes simple, deterministic control over maximal overlap. That is appropriate for this learning phase because every transaction boundary is explicit and easy to verify.

---

## 25. Prediction Accuracy

For the two primary timing predictions that Step 8 directly measured:

### Start-to-done latency

```text
prediction = 70 ns
measurement = 70 ns
absolute error = 0 ns
percentage error = 0%
```

### Initiation interval

```text
prediction = 90 ns
measurement = 90 ns
absolute error = 0 ns
percentage error = 0%
```

Therefore the pre-RTL nonblocking-assignment and FSM timing analysis correctly predicted the behavioral transaction schedule.

This is important because it shows that the design was not tuned after simulation to explain an unexpected waveform. The expected cycle behavior was derived before the RTL integration test and later matched by measurement.

---

## 26. Remaining Measurements Before Phase-7 Review

Behavioral integration is successful, but the following physical implementation questions remain unanswered:

```text
1. Integrated LUT count
2. Integrated Slice FF count
3. Integrated CARRY4 count
4. Integrated DSP48E1 count
5. Whether the expected requantization DSP uses PREG in the integrated design
6. Post-synthesis hierarchy/resource distribution
7. Post-route setup WNS/TNS at 100 MHz
8. Post-route hold slack
9. Routed critical path and logic/routing split
10. Power
```

These values must not be inferred from XSim.

If Phase 7 review is intended to include physical FPGA evidence, synthesis and implementation reports should be collected before Step 10. If Step 10 is restricted to the functional convolution-integration module, the review must explicitly mark physical metrics as pending rather than presenting predictions as measurements.

---

## 27. Step-9 Conclusion

The Phase-7 behavioral performance predictions are strongly validated by the XSim integration run.

The core functional timing results are:

```text
70 ns accepted-start-to-done latency: PREDICTED -> MEASURED MATCH
90 ns minimum initiation interval:     PREDICTED -> MEASURED MATCH
3 paired memory requests:              PREDICTED -> MEASURED MATCH
address sequence 0 -> 1 -> 2:          PREDICTED -> MEASURED MATCH
```

From the measured 90 ns initiation interval, the protocol-level sustained rate remains:

```text
11.11 M transactions/s
100 MMAC/s useful sustained arithmetic rate
266.67 MB/s physical operand traffic
200 MB/s useful operand traffic
```

These are derived behavioral architecture rates, not post-route board measurements.

Resource utilization and timing closure remain deliberately unresolved until the appropriate synthesis and implementation evidence exists.

The mandatory workflow now moves to:

```text
Step 10: /review convolution_integration
```

Before Step 10 begins, the learner must be able to distinguish which Phase-7 results are now directly measured, which are derived from measured timing, and which still require synthesis or implementation evidence.
