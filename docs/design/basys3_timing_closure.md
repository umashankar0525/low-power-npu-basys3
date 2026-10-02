# Basys 3 Timing Closure — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure  
**Workflow stage:** Step 2 — /design basys3_timing_closure  
**Status:** DESIGN COMPLETE — Step 3 prediction analysis and understanding gate required before RTL modification.

---

## 1. Design objective

The current implemented top-level fails setup timing at 100 MHz:

~~~text
Requirement = 10.000 ns
WNS         = -3.453 ns
TNS         = -99.753 ns
Failing setup endpoints = 43
~~~

The worst routed path is:

~~~text
RAMB18E1 activation output
-> convolution arithmetic
-> accumulator_reg[31]
~~~

with:

~~~text
data-path delay = 13.433 ns
logic delay     = 8.067 ns
route delay     = 5.366 ns
logic levels    = 17
CARRY4          ≈ 10
~~~

The design goal is to preserve:

~~~text
100 MHz / 10 ns clock
BRAM inference
functional result = 34 = 0x22
existing external interface
existing three logical operand-word reads
~~~

while reducing the amount of combinational arithmetic between sequential boundaries.

---

## 2. Current dataflow structure

The current memory_interface_dataflow computes four packed products combinationally:

~~~text
p0 = a0 * w0
p1 = a1 * w1
p2 = a2 * w2
p3 = a3 * w3
~~~

Each product is signed INT16.

The four products are reduced using:

~~~text
sum01 = p0 + p1
sum23 = p2 + p3
partial_sum = sum01 + sum23
~~~

giving an 18-bit signed reduced result.

That partial sum is sign-extended to INT32 and the existing sequential logic performs:

~~~text
accumulator <= accumulator + partial_sum_ext
~~~

in the same BRAM-output cycle.

Thus the physical timing path includes both lane multiply/reduction and the 32-bit accumulation between the BRAM output and accumulator register.

---

## 3. Selected architectural fix

Insert one sequential pipeline register between the reduction tree and the accumulator.

Conceptually:

~~~text
OLD

BRAM
 -> lane unpack
 -> 4 multipliers
 -> reduction tree
 -> sign extension
 -> 32-bit accumulation
 -> accumulator register
~~~

becomes:

~~~text
NEW

Stage A
BRAM
 -> lane unpack
 -> 4 multipliers
 -> reduction tree
 -> sign extension
 -> partial_sum_pipe register

Stage B
partial_sum_pipe register
 -> 32-bit accumulation
 -> accumulator register
~~~

The new register stores one signed INT32 partial sum:

~~~text
partial_sum_pipe : signed [31:0]
~~~

The arithmetic result is not changed. Only its cycle placement changes.

---

## 4. Why this boundary is selected

The measured endpoint is the accumulator register.

The current arithmetic immediately before that endpoint contains a long carry-heavy path.

Registering the fully reduced partial sum creates a hard sequential boundary before the accumulator addition.

This has three advantages:

~~~text
1. BRAM-to-reduction logic no longer includes accumulator addition.
2. Accumulator stage begins from a flip-flop rather than directly from BRAM arithmetic.
3. Existing accumulator width and mathematical behavior remain unchanged.
~~~

This is a minimal architectural intervention compared with redesigning the complete MAC engine.

---

## 5. Why the BRAM RTL itself is not changed first

The physical memory has already been correctly inferred:

~~~text
2 x RAMB18E1
= 1 Block RAM Tile
~~~

Therefore BRAM inference is not the defect.

The timing problem occurs after the BRAM output.

The first redesign should therefore preserve operand_bram_dual_read, one-clock synchronous memory semantics, and the three logical activation/weight requests, while restructuring only the arithmetic/dataflow stage.

---

## 6. New cycle schedule

The existing memory requests are retained:

~~~text
word 0
word 1
word 2
~~~

One additional pipeline-fill cycle is introduced before the first accumulation.

The conceptual schedule becomes:

~~~text
E0:
start accepted by memory engine
request word 0

E1:
BRAM returns word 0 after edge
request word 1

E2:
partial_sum_pipe <= partial sum of word 0
BRAM returns word 1 after edge
request word 2

E3:
accumulator <= accumulator + partial_sum_pipe(word 0)
partial_sum_pipe <= partial sum of word 1
BRAM returns word 2 after edge

E4:
accumulator <= accumulator + partial_sum_pipe(word 1)
partial_sum_pipe <= partial sum of word 2

E5:
result <= accumulator + partial_sum_pipe(word 2)
done <= 1
~~~

The essential timing relationship is:

~~~text
word N appears from BRAM
-> Stage A computes during the following cycle
-> partial_sum_pipe captures it
-> Stage B consumes that registered partial sum on a later edge
~~~

---

## 7. Required state-machine change inside memory_interface_dataflow

Current engine states:

~~~text
ST_IDLE
ST_WAIT0
ST_WORD0
ST_WORD1
ST_WORD2
~~~

The redesigned engine adds one explicit pipeline-fill state:

~~~text
ST_IDLE
ST_WAIT0
ST_PIPE0
ST_WORD0
ST_WORD1
ST_WORD2
~~~

Six states require at least:

~~~text
ceil(log2(6)) = 3 bits
~~~

Therefore the existing three-bit state register remains sufficient.

State intent:

~~~text
ST_IDLE
-> accept start and request word 0

ST_WAIT0
-> wait for first synchronous BRAM return
-> request word 1

ST_PIPE0
-> capture word-0 reduced partial sum into pipeline register
-> request word 2

ST_WORD0
-> accumulate registered word-0 partial
-> simultaneously pipeline word-1 partial

ST_WORD1
-> accumulate registered word-1 partial
-> simultaneously pipeline word-2 partial

ST_WORD2
-> form final result from accumulator + registered word-2 partial
-> pulse done
~~~

This keeps the memory request count at three.

---

## 8. Data/control alignment

The new pipeline stage changes when a word's arithmetic becomes eligible for accumulation.

For this fixed three-word engine, the state itself provides the valid/identity contract:

~~~text
ST_PIPE0 -> capture partial for word 0
ST_WORD0 -> consume word 0 / capture word 1
ST_WORD1 -> consume word 1 / capture word 2
ST_WORD2 -> consume word 2 as final
~~~

No separate address-tag register is required because request order is fixed at 0 -> 1 -> 2 and the pipeline depth is fixed at one partial-sum stage.

If this engine is later generalized to variable-length or out-of-order traffic, explicit valid/tag pipelines would be preferable.

---

## 9. Pipeline-register behavior

The new register is:

~~~text
reg signed [31:0] partial_sum_pipe;
~~~

Reset behavior:

~~~text
rst -> partial_sum_pipe = 0
~~~

Capture behavior:

~~~text
ST_PIPE0
ST_WORD0
ST_WORD1
~~~

each capture the current sign-extended reduced partial sum.

ST_WORD2 does not need to capture another useful operand because word 2 is already stored in the pipeline register and is consumed to produce the final result.

---

## 10. Accumulator behavior

Accumulator semantics remain mathematically identical.

For three reduced word sums:

~~~text
S0
S1
S2
~~~

the old engine computes:

~~~text
acc <- S0
acc <- S0 + S1
result <- S0 + S1 + S2
~~~

The new engine computes the same sequence one stage later:

~~~text
partial_pipe <- S0
acc          <- S0

partial_pipe <- S1
acc          <- S0 + S1

partial_pipe <- S2
result       <- S0 + S1 + S2
~~~

Only the cycle placement changes.

---

## 11. Numerical preservation for the board vector

The three physical words represent:

~~~text
word 0 activation lanes = 1,2,3,4
word 1 activation lanes = 5,6,7,8
word 2 activation lanes = 9,0,0,0
weights = all ones for useful lanes
~~~

Therefore:

~~~text
S0 = 1+2+3+4 = 10
S1 = 5+6+7+8 = 26
S2 = 9         = 9
~~~

Then:

~~~text
10 + 26 + 9 = 45
~~~

Requantization remains:

~~~text
45 x 3 = 135
bias   = 2
137 >> 2 = 34
~~~

Thus:

~~~text
activation_out = 34
               = 0x22
~~~

must remain unchanged.

---

## 12. Latency consequence

This redesign adds one internal memory-engine pipeline cycle.

Therefore the engine completion event moves one clock later.

At 100 MHz:

~~~text
one added cycle = 10 ns
~~~

The existing integration path waits on engine_done, so the supervisory controller does not require a new state merely because the engine is one cycle longer.

The predicted top-level accepted-start-to-done latency therefore changes from:

~~~text
7 cycles
~~~

to:

~~~text
8 cycles
~~~

At 100 MHz:

~~~text
8 x 10 ns = 80 ns
~~~

This is a design prediction and must be verified after the RTL change.

---

## 13. Initiation-interval consequence

The current engine is not a fully overlapped streaming pipeline.

It accepts one transaction, processes all three words, completes, and returns idle.

Adding one internal cycle therefore also increases the earliest engine-completion time.

The exact new top-level initiation interval must be derived in Step 3 from the controller schedule rather than assumed from latency alone.

---

## 14. Expected resource consequences

The new architectural state requires approximately:

~~~text
32 FF for partial_sum_pipe
~~~

plus potentially minor FSM/control differences.

No additional BRAM is architecturally required.

Expected unchanged resource classes:

~~~text
BRAM = 2 x RAMB18E1
DSP  = 0 unless synthesis chooses a different arithmetic mapping
IOB  = 12
BUFG = 1
~~~

Exact LUT/FF/CARRY counts remain synthesis measurements.

---

## 15. Expected timing effect

After the pipeline boundary, the two main candidate timing stages become:

~~~text
Stage A:
BRAM output
-> multipliers
-> reduction
-> partial_sum_pipe

Stage B:
partial_sum_pipe
-> 32-bit accumulator addition
-> accumulator register
~~~

The old combined path no longer exists as one register-to-register path.

This should substantially reduce the maximum combinational depth.

However, Step 2 does not claim timing closure.

Only post-route STA can prove:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
~~~

---

## 16. Modules affected by the redesign

RTL modification expected:

~~~text
rtl/compute/memory_interface_dataflow.v
~~~

No functional redesign expected:

~~~text
rtl/memory/operand_bram_dual_read.v
rtl/control/control_fsm.v
rtl/top/convolution_integration.v
rtl/top/basys3_top_level.v
vivado/constraints/basys3_top_level.xdc
~~~

The surrounding modules already use handshake-style completion through engine_done, so a one-cycle increase inside the memory engine should naturally propagate through the supervisory wait state.

Testbench expectations for latency must be updated after the new schedule is approved.

---

## 17. Verification consequences

Behavioral verification must re-prove:

~~~text
request count = 3 paired memory requests
request order = 0 -> 1 -> 2
one-clock BRAM read behavior
S0 = 10
S1 = 26
S2 = 9
final accumulator = 45
activation_out = 34 / 0x22
exactly one done event
new latency = predicted schedule
reset behavior remains correct
busy-mask behavior remains correct
~~~

Timing verification must then re-run synthesis, implementation, and post-route timing and compare the new critical path against:

~~~text
old WNS = -3.453 ns
old TNS = -99.753 ns
old critical delay = 13.433 ns
~~~

---

## 18. Why a deeper pipeline is not selected yet

A second pipeline stage could split the arithmetic further.

However, the project goal is architectural mastery with minimal justified changes.

The first redesign therefore introduces one boundary at the most directly measured timing bottleneck.

If post-route STA still fails after this change, the next iteration can split Stage A further, for example between products and the reduction tree, or redesign the MAC schedule.

We should not add unnecessary latency and control complexity before measurement demonstrates the need.

---

## 19. Explicit assumptions

1. Target remains XC7A35T-1CPG236C / Basys 3.
2. Clock remains exactly 100 MHz / 10 ns.
3. Current WNS is -3.453 ns.
4. Current critical data-path delay is 13.433 ns.
5. BRAM implementation remains two RAMB18E1 primitives.
6. Operand memory read behavior remains one-clock synchronous.
7. Exactly three logical operand words are consumed per transaction.
8. Request order remains fixed at 0,1,2.
9. A single signed 32-bit partial-sum pipeline register is sufficient for the first timing-closure attempt.
10. Mathematical accumulator precision remains INT32.
11. Output must remain 34 / 0x22 for the board demonstration vector.
12. Timing closure is not assumed until post-route STA is rerun.

---

## 20. Design decision

The selected timing-closure architecture is:

~~~text
BRAM
-> 4 lane products
-> balanced reduction
-> INT32 partial_sum_pipe register
-> INT32 accumulator add
-> accumulator register
~~~

with one additional FSM pipeline-fill state:

~~~text
ST_PIPE0
~~~

The intended tradeoff is:

~~~text
+ one internal cycle
+ approximately 32 FF
- substantially shorter BRAM-to-accumulator combinational path
~~~

while preserving:

~~~text
100 MHz target
BRAM use
three operand reads
INT32 accumulation
output 0x22
external interfaces
~~~

---

## 21. Understanding gate

Before Step 3 /analyze basys3_timing_closure, explain in your own words:

1. Why is the pipeline register placed after the reduction tree and before the accumulator?
2. What two timing stages replace the old BRAM-to-accumulator path?
3. Why is ST_PIPE0 required?
4. Derive the new word schedule from E0 through E5.
5. Why do we still make only three memory requests?
6. Why does the FSM state itself provide sufficient word-valid alignment in this fixed three-word engine?
7. Derive S0, S1, S2 and show that the result remains 45 before requantization.
8. Why is the expected top-level latency now 8 cycles / 80 ns?
9. Which resources are expected to change, and which should remain unchanged?
10. Why can we predict timing improvement but still not claim closure before implementation?
