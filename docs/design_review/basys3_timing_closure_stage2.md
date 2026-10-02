# Basys 3 Timing Closure Stage 2 — Design Review

**Role:** Design Reviewer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure_stage2  
**Workflow stage:** Step 10 — /review basys3_timing_closure_stage2  
**Status:** REVIEW COMPLETE — timing closure achieved at 100 MHz.

---

## 1. Review objective

Review the complete second timing-closure iteration against:

~~~text
functional correctness
pipeline alignment
memory protocol
latency prediction
resource prediction
synthesis outcome
post-route timing
architectural intent
reset/recovery behavior
100 MHz timing requirement
~~~

This review uses the measured results gathered through XSim, synthesis, implementation, and post-route timing analysis.

---

## 2. Original problem

The initial top-level implementation failed setup timing at 100 MHz.

Original worst path:

~~~text
BRAM
-> multiplication/reduction
-> accumulator
-> accumulator_reg
~~~

Measured:

~~~text
WNS = -3.453 ns
TNS = -99.753 ns
failing setup endpoints = 43
data path delay = 13.433 ns
logic levels = 17
CARRY4 ≈ 10
~~~

The design was functionally correct but physically unable to satisfy the 10 ns setup requirement.

---

## 3. First timing-closure iteration

The first redesign inserted:

~~~text
partial_sum_pipe
~~~

between the reduction tree and the accumulator.

Architecture:

~~~text
BRAM
-> multiply/reduction
-> partial_sum_pipe
-> accumulator
~~~

Behavioral consequence:

~~~text
latency:
70 ns -> 80 ns
~~~

Measured post-route timing:

~~~text
WNS = -1.260 ns
TNS = -9.347 ns
failing endpoints = 12
data path delay = 11.289 ns
logic levels = 13
CARRY4 = 7
~~~

This was a substantial improvement, but 100 MHz timing closure was not yet achieved.

---

## 4. Second timing-closure design decision

The measured remaining worst path was:

~~~text
BRAM
-> multiplier
-> reduction tree
-> partial_sum_pipe
~~~

The second redesign inserted four signed INT16 product registers:

~~~text
product_pipe0
product_pipe1
product_pipe2
product_pipe3
~~~

Architecture:

~~~text
Stage A1:
BRAM
-> multipliers
-> product_pipe

Stage A2:
product_pipe
-> reduction tree
-> partial_sum_pipe

Stage B:
partial_sum_pipe
-> accumulator
-> accumulator_reg
~~~

This directly split the measured failing Stage-A path.

---

## 5. Control design review

The memory-interface FSM changed from six states to seven:

~~~text
ST_IDLE
ST_WAIT0
ST_PROD0
ST_PIPE0
ST_WORD0
ST_WORD1
ST_WORD2
~~~

Seven states still require only:

~~~text
ceil(log2(7)) = 3 bits
~~~

so no RTL state-width increase was required.

The three-request memory protocol remained unchanged:

~~~text
0 -> 1 -> 2
~~~

No extra BRAM traffic was introduced by the additional compute pipeline stage.

---

## 6. Behavioral verification review

XSim completed with:

~~~text
PASS: tb_basys3_top_level Stage-2 timing-closure verification completed with zero errors
~~~

The behavioral testbench explicitly verified:

~~~text
word-0 products = 1,2,3,4
word-1 products = 5,6,7,8
word-2 products = 9,0,0,0

S0 = 10
S1 = 26
S2 = 9

accumulator:
0 -> 10 -> 36 -> 45

activation_out = 34 = 0x22

exactly 3 paired BRAM requests
request order 0 -> 1 -> 2

exactly one completion event

accepted-start -> raw-done = 90 ns
~~~

Reset verification also confirmed that:

~~~text
product_pipe0..3
partial_sum_pipe
accumulator
result
completion state
~~~

are cleared correctly.

Post-reset recovery also passed.

Therefore the RTL redesign is behaviorally correct.

---

## 7. Latency review

Predicted Stage-2 latency:

~~~text
9 cycles
~~~

At 100 MHz:

~~~text
9 x 10 ns = 90 ns
~~~

Measured XSim assertion:

~~~text
90 ns PASS
~~~

Therefore:

~~~text
predicted latency = measured latency
~~~

exactly.

Relative to the original design:

~~~text
70 ns -> 90 ns
~~~

Absolute increase:

~~~text
20 ns
~~~

Percentage increase:

~~~text
20 / 70 x 100
≈ 28.57%
~~~

This is the latency cost paid for timing closure.

---

## 8. Resource review

Final measured synthesis:

~~~text
LUT       = 525
FF        = 218
CARRY4    = 96
DSP       = 0
RAMB18E1  = 2
IOB       = 12
BUFG      = 1
~~~

Stage-1 baseline:

~~~text
LUT       = 487
FF        = 154
CARRY4    = 96
DSP       = 0
RAMB18E1  = 2
IOB       = 12
BUFG      = 1
~~~

Stage-2 delta:

~~~text
LUT:
525 - 487 = +38

FF:
218 - 154 = +64

CARRY4:
96 - 96 = 0

DSP:
0 - 0 = 0

RAMB18E1:
2 - 2 = 0
~~~

The +64 FF increase exactly matches:

~~~text
4 x 16-bit product registers
= 64 FF
~~~

This is a strong prediction-to-measurement match.

---

## 9. Resource-prediction review

Predicted:

~~~text
LUT ≈ 480..530
FF ≈ 210..225
CARRY4 broadly near 96
DSP = 0
RAMB18E1 = 2
IOB = 12
BUFG = 1
~~~

Measured:

~~~text
LUT = 525
FF = 218
CARRY4 = 96
DSP = 0
RAMB18E1 = 2
IOB = 12
BUFG = 1
~~~

All measured values matched the expected range or exact prediction.

---

## 10. Final timing review

Final post-route timing:

~~~text
WNS  = +0.913 ns
TNS  = 0.000 ns
setup failing endpoints = 0

WHS  = +0.122 ns
THS  = 0.000 ns
hold failing endpoints = 0

WPWS = +4.500 ns
TPWS = 0.000 ns
pulse-width failing endpoints = 0
~~~

Therefore:

~~~text
setup timing       PASS
hold timing        PASS
pulse-width timing PASS
100 MHz closure    PASS
~~~

Vivado reports all user-specified timing constraints are met.

---

## 11. Final worst-path review

The final worst setup path is:

~~~text
source:
u_operand_bram_dual_read/weight_data_reg/CLKBWRCLK

destination:
u_convolution_integration/
u_memory_interface_dataflow/
product_pipe3_reg[14]/D
~~~

Architecturally:

~~~text
weight BRAM
-> multiplier
-> product_pipe3
~~~

Measured:

~~~text
slack             = +0.913 ns
requirement       = 10.000 ns
data path delay   = 8.996 ns

logic delay       = 5.461 ns
route delay       = 3.535 ns

logic levels      = 9
CARRY4            = 4

clock skew        = -0.084 ns
clock uncertainty = 0.035 ns
~~~

The final critical path is therefore the predicted Stage-A1 path.

---

## 12. Timing progression review

The two pipeline boundaries produced the following measured progression:

~~~text
Original:
13.433 ns
17 logic levels
~10 CARRY4
WNS = -3.453 ns

After partial_sum_pipe:
11.289 ns
13 logic levels
7 CARRY4
WNS = -1.260 ns

After product_pipe:
8.996 ns
9 logic levels
4 CARRY4
WNS = +0.913 ns
~~~

Worst-path delay improvement:

~~~text
13.433 - 8.996
= 4.437 ns
~~~

Relative reduction:

~~~text
4.437 / 13.433 x 100
≈ 33.03%
~~~

Logic-level reduction:

~~~text
17 - 9
= 8 levels
~~~

Approximate CARRY4-depth reduction:

~~~text
10 - 4
≈ 6 stages
~~~

This clearly demonstrates the timing benefit of architectural pipelining.

---

## 13. Architectural quality review

The successful fix was architectural rather than constraint-based.

The clock specification remained:

~~~text
100 MHz
10 ns
~~~

The XDC was not weakened.

No false path or multicycle exception was introduced to hide the failure.

Instead, the datapath was physically restructured so each combinational stage fits within the original timing contract.

This is the correct timing-closure methodology.

---

## 14. Memory architecture review

Operand storage remained:

~~~text
2 x RAMB18E1
1 Block RAM Tile
~~~

The two 512x32 operand memories remained mapped to Block RAM.

The additional compute pipeline did not increase BRAM consumption.

Memory request count also remained:

~~~text
3 paired reads/transaction
~~~

Therefore the timing fix did not alter memory traffic or memory capacity.

---

## 15. DSP mapping review

DSP usage remains:

~~~text
0
~~~

The INT8 multipliers continue to be implemented in LUT/carry logic.

This means the timing result demonstrates a LUT-based arithmetic implementation meeting 100 MHz on XC7A35T.

A future optimization could deliberately explore DSP48 mapping, but it is not required for the present architecture to meet timing.

---

## 16. Functional correctness review

The timing changes preserved all original arithmetic behavior:

~~~text
activation input:
1..9

weights:
all 1

convolution sum:
45

requantized output:
34 / 0x22
~~~

No functional compromise was introduced to achieve timing closure.

---

## 17. Reset/recovery review

The new architectural registers are all reset:

~~~text
product_pipe0
product_pipe1
product_pipe2
product_pipe3
partial_sum_pipe
accumulator
~~~

The verification suite proved:

~~~text
clean-reset abort
no stale completion
post-reset transaction recovery
~~~

This is essential because every newly introduced pipeline register is architectural state.

---

## 18. Final tradeoff

The final design pays:

~~~text
+20 ns latency versus original
+64 FF versus Stage 1
+38 LUT versus Stage 1
~~~

and gains:

~~~text
WNS:
-3.453 ns -> +0.913 ns

TNS:
-99.753 ns -> 0

setup failing endpoints:
43 -> 0

100 MHz timing closure:
FAIL -> PASS
~~~

For this project, that is a justified tradeoff because the design objective is correct synchronous operation at the target board clock.

---

## 19. Review findings

No unresolved functional issue is present in the measured evidence.

No unresolved setup violation remains.

No hold violation remains.

No pulse-width violation remains.

No unexpected BRAM increase occurred.

No DSP dependency was introduced.

The remaining synthesis BRAM-output-register advisory may still appear, but the implemented design already meets the required timing constraint, so it is not a blocking issue for this module.

---

## 20. Final review status

~~~text
RTL architecture              ACCEPTED
Behavioral verification       PASS
Pipeline alignment            PASS
Memory protocol               PASS
Arithmetic correctness        PASS
Reset/recovery                PASS
Latency measurement           PASS

Synthesis                     PASS
Resource prediction           PASS
BRAM inference                PASS
Implementation                PASS
Setup timing                  PASS
Hold timing                   PASS
Pulse-width timing            PASS
100 MHz timing closure        PASS
~~~

**DESIGN REVIEW RESULT: COMPLETE**

The Stage-2 timing-closure module has achieved its technical objective.

---

## 21. Lessons captured

The principal architectural lesson is:

~~~text
Timing closure is not achieved by changing what the clock claims.

Timing closure is achieved by changing how much combinational work is required between sequential boundaries.
~~~

This module demonstrated that principle experimentally:

~~~text
13.433 ns
-> 11.289 ns
-> 8.996 ns
~~~

by adding two explicit pipeline boundaries.

---

## 22. Next workflow step

The remaining mandatory module step is:

~~~text
Step 11 — /test basys3_timing_closure_stage2
~~~

That knowledge test should verify understanding of:

~~~text
setup timing
pipeline boundaries
latency/resource tradeoffs
critical-path migration
behavioral versus physical verification
resource prediction versus measurement
final 100 MHz closure evidence
~~~
