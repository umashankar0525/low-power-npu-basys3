# Basys 3 Timing Closure Stage 2 — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** basys3_timing_closure_stage2  
**Workflow stage:** Step 2 — /design basys3_timing_closure_stage2  
**Status:** DESIGN COMPLETE — Step 3 prediction analysis and understanding gate required before RTL modification.

---

## 1. Measured problem being addressed

After the first pipeline insertion, timing improved substantially:

~~~text
before:
WNS = -3.453 ns
TNS = -99.753 ns
43 failing setup endpoints

after first pipeline:
WNS = -1.260 ns
TNS = -9.347 ns
12 failing setup endpoints
~~~

The current measured worst path is:

~~~text
RAMB18E1 activation output
-> multiply/reduction arithmetic
-> partial_sum_pipe_reg[17]/D
~~~

Measured delay:

~~~text
data path delay = 11.289 ns
logic delay     = 6.813 ns
route delay     = 4.476 ns
logic levels    = 13
CARRY4          = 7
~~~

Therefore the next redesign must split Stage A.

---

## 2. Current Stage-A structure

The current Stage A is:

~~~text
BRAM
-> lane unpack
-> p0 = a0 * w0
-> p1 = a1 * w1
-> p2 = a2 * w2
-> p3 = a3 * w3
-> sum01 = p0 + p1
-> sum23 = p2 + p3
-> partial_sum = sum01 + sum23
-> sign extension
-> partial_sum_pipe
~~~

This still places multiplication and the entire reduction tree within one register-to-register path.

---

## 3. Selected Stage-2 timing-closure fix

Add four registered INT16 product pipeline registers:

~~~text
product_pipe0
product_pipe1
product_pipe2
product_pipe3
~~~

Each stores one signed INT16 multiplication result.

The new datapath becomes:

~~~text
Stage A1:
BRAM
-> lane unpack
-> four INT8 x INT8 multipliers
-> four INT16 product registers

Stage A2:
product registers
-> pairwise 17-bit sums
-> final 18-bit reduction
-> sign extension
-> existing partial_sum_pipe

Stage B:
partial_sum_pipe
-> INT32 accumulator addition
-> accumulator register
~~~

This converts one long Stage-A path into two shorter paths.

---

## 4. Why register the products

The current measured path includes both multiplication and reduction logic.

Registering the products creates a clean timing boundary immediately after the multipliers.

This gives:

~~~text
A1:
BRAM -> multiplier -> product register

A2:
product register -> reduction tree -> partial_sum_pipe
~~~

instead of:

~~~text
BRAM -> multiplier -> reduction tree -> partial_sum_pipe
~~~

The change directly targets the measured failing path.

---

## 5. Why not split only after the first pairwise sums

Another possible boundary would be:

~~~text
BRAM
-> multiply
-> pair sums
-> register
-> final sum
-> partial_sum_pipe
~~~

That would require fewer registers.

However, it would still force:

~~~text
BRAM -> multiplier -> pairwise adder
~~~

into one timing stage.

Because the current violation is still 1.260 ns and the measured path contains substantial carry logic, the product-register boundary is chosen as the more conservative timing-closure architecture.

The tradeoff is higher FF usage in exchange for a stronger reduction in combinational depth.

---

## 6. New registers

Add:

~~~text
reg signed [15:0] product_pipe0;
reg signed [15:0] product_pipe1;
reg signed [15:0] product_pipe2;
reg signed [15:0] product_pipe3;
~~~

Raw combinational products remain:

~~~text
p0 = a0 * w0
p1 = a1 * w1
p2 = a2 * w2
p3 = a3 * w3
~~~

but the reduction tree will consume:

~~~text
product_pipe0
product_pipe1
product_pipe2
product_pipe3
~~~

instead of the direct combinational products.

---

## 7. Reduction tree after the new product stage

Pair sums become:

~~~text
sum01 = sign_extend(product_pipe0)
      + sign_extend(product_pipe1)

sum23 = sign_extend(product_pipe2)
      + sign_extend(product_pipe3)
~~~

Final reduction remains:

~~~text
partial_sum = sum01 + sum23
~~~

Then:

~~~text
partial_sum_ext
-> partial_sum_pipe
~~~

The arithmetic precision remains unchanged:

~~~text
INT8 x INT8 -> INT16 product
pair sum     -> 17 bits
final sum    -> 18 bits
accumulator  -> INT32
~~~

---

## 8. Control consequence

A new product-pipeline fill cycle is required.

The current six-state engine is:

~~~text
ST_IDLE
ST_WAIT0
ST_PIPE0
ST_WORD0
ST_WORD1
ST_WORD2
~~~

The Stage-2 redesign adds one new state before partial-sum capture:

~~~text
ST_PROD0
~~~

Proposed sequence:

~~~text
ST_IDLE
ST_WAIT0
ST_PROD0
ST_PIPE0
ST_WORD0
ST_WORD1
ST_WORD2
~~~

Seven states still fit in three binary bits because:

~~~text
ceil(log2(7)) = 3
~~~

No RTL state-register width increase is required.

---

## 9. New cycle schedule

The pipeline now contains:

~~~text
BRAM return
-> product register
-> partial-sum register
-> accumulator
~~~

Conceptual schedule:

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
product_pipe     <= products(word 1)
BRAM returns word 2

E4:
accumulator      <= S0
partial_sum_pipe <= S1
product_pipe     <= products(word 2)

E5:
accumulator      <= S0 + S1
partial_sum_pipe <= S2

E6:
result <= S0 + S1 + S2
done   <= 1
~~~

Thus the memory request count remains exactly three.

The added product stage introduces one additional engine cycle relative to the first-pipeline architecture.

---

## 10. Word alignment

The schedule remains deterministic:

~~~text
word 0 -> products0 -> S0
word 1 -> products1 -> S1
word 2 -> products2 -> S2
~~~

State progression guarantees alignment.

For this fixed three-word engine, no explicit transaction tag is required.

The FSM state itself determines which registered product/partial sum is valid.

---

## 11. Numerical preservation

Word 0:

~~~text
products = 1,2,3,4
S0 = 10
~~~

Word 1:

~~~text
products = 5,6,7,8
S1 = 26
~~~

Word 2:

~~~text
products = 9,0,0,0
S2 = 9
~~~

Final accumulator:

~~~text
10 + 26 + 9 = 45
~~~

Requantization remains:

~~~text
45 x 3 = 135
135 + 2 = 137
137 >> 2 = 34
~~~

Therefore:

~~~text
activation_out = 34 = 0x22
~~~

must remain unchanged.

---

## 12. Latency consequence

The first timing-closure pipeline increased top-level latency from:

~~~text
70 ns -> 80 ns
~~~

The new product stage adds one more internal cycle.

Predicted new top-level accepted-start-to-done latency:

~~~text
8 cycles + 1 cycle
= 9 cycles
~~~

At 100 MHz:

~~~text
9 x 10 ns
= 90 ns
~~~

This must be verified after RTL modification.

---

## 13. Initiation-interval consequence

The current predicted machine initiation interval after the first pipeline is:

~~~text
10 cycles = 100 ns
~~~

Adding one non-overlapped engine stage increases the predicted initiation interval by one clock:

~~~text
11 cycles
= 110 ns
~~~

This will be derived formally in Step 3.

---

## 14. Register-cost estimate

Four signed INT16 product registers imply:

~~~text
4 x 16
= 64 RTL register bits
~~~

Unlike the sign-extended partial-sum register, these 16-bit product values do not contain simple duplicated upper sign-extension fields.

Therefore synthesis is expected to preserve substantially more of these bits physically.

Predicted physical FF increase:

~~~text
approximately +64 FF
~~~

subject to synthesis optimization and FSM encoding.

---

## 15. Expected resource stability

Architecturally unchanged:

~~~text
RAMB18E1 = 2 expected
Block RAM Tile = 1 expected
IOB = 12 expected
BUFG = 1 expected
DSP = 0 expected unless Vivado remaps the multipliers
~~~

LUT and CARRY4 counts may change because inserting registers changes optimization boundaries.

Exact resource values remain synthesis measurements.

---

## 16. Expected critical-path migration

The current worst path:

~~~text
BRAM
-> multiply/reduction
-> partial_sum_pipe
~~~

should disappear as one combined path.

Likely replacement candidates:

~~~text
Candidate A1:
BRAM
-> multiplier
-> product_pipe

Candidate A2:
product_pipe
-> reduction tree
-> partial_sum_pipe

Candidate B:
partial_sum_pipe
-> accumulator add
-> accumulator
~~~

The design intent is for all three to fit within the unchanged 10 ns requirement.

---

## 17. Timing expectation

Current measured:

~~~text
WNS = -1.260 ns
TNS = -9.347 ns
12 failing setup endpoints
~~~

The Stage-2 split should reduce combinational depth further.

Expected direction:

~~~text
WNS should improve
TNS should move toward zero
failing endpoints should decrease
critical Stage-A delay should decrease
~~~

Desired final result:

~~~text
WNS >= 0
TNS = 0
WHS >= 0
THS = 0
WPWS >= 0
TPWS = 0
~~~

Timing closure is not claimed until fresh post-route STA is measured.

---

## 18. Modules intended for modification

Primary RTL change:

~~~text
rtl/compute/memory_interface_dataflow.v
~~~

No functional modification is currently planned for:

~~~text
rtl/memory/operand_bram_dual_read.v
rtl/control/control_fsm.v
rtl/top/convolution_integration.v
rtl/top/basys3_top_level.v
vivado/constraints/basys3_top_level.xdc
~~~

The 100 MHz XDC must remain unchanged.

---

## 19. Verification consequences

The next verification artifact must prove:

~~~text
product_pipe word-0 values = 1,2,3,4
product_pipe word-1 values = 5,6,7,8
product_pipe word-2 values = 9,0,0,0

S0 = 10
S1 = 26
S2 = 9

accumulator:
0 -> 10 -> 36

result = 45
activation_out = 34 / 0x22

exactly 3 paired memory requests
exactly 1 completion event

new latency = 9 cycles / 90 ns
reset clears product registers
post-reset recovery works
~~~

---

## 20. Design decision

The selected Stage-2 timing-closure architecture is:

~~~text
BRAM
-> 4 x INT8 multipliers
-> 4 x INT16 product registers
-> balanced reduction tree
-> existing partial_sum_pipe
-> INT32 accumulator
~~~

The intended tradeoff is:

~~~text
+ approximately 64 FF
+ one additional cycle
- substantially shorter current Stage-A path
~~~

while preserving:

~~~text
100 MHz requirement
3 memory requests
2 RAMB18E1
INT32 accumulator precision
final output 34 / 0x22
external interfaces
~~~

---

## 21. Understanding gate

Before Step 3 /analyze basys3_timing_closure_stage2, explain in your own words:

1. Why is the new register boundary placed after the multipliers?
2. What three major timing stages exist after this redesign?
3. Why is ST_PROD0 required?
4. Derive the E0 through E6 schedule.
5. Why are there still only three BRAM requests?
6. Why are about 64 additional RTL register bits expected?
7. Why is this design more conservative than registering only pair sums?
8. Why should the new latency become 9 cycles / 90 ns?
9. Which resources should remain unchanged?
10. Why must fresh synthesis and post-route STA still decide whether this second split actually closes timing?
