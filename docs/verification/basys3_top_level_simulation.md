# Basys 3 Top-Level Integration — Behavioral Simulation Results

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 8 — simulation + measurement  
**Status:** BEHAVIORAL SIMULATION PASSED — functional/protocol verification complete; synthesis/implementation evidence still pending.

---

## 1. Simulation Environment

The user ran the generated Phase-8 integration testbench in Vivado XSim 2018.2.

Testbench:

```text
tb/integration/tb_basys3_top_level.v
```

Simulation configuration:

```text
clock                 = 100 MHz
clock period          = 10 ns
SIM_DEBOUNCE_CYCLES   = 4
SIM_DEBOUNCE_WIDTH    = 3
```

The shortened debounce value is simulation-only. The accelerator timing itself remains tied to the real 100 MHz clock.

---

## 2. First Run and Debug Correction

The first run produced one error in the original reset-during-transaction test:

```text
ERROR: aborted transaction incorrectly produced a raw core_done pulse
```

Analysis showed that this was a **testbench timing-assumption error**, not a datapath failure.

A physical reset button must pass through synchronization and debounce before producing `reset_level`. With a 7-cycle / 70 ns accelerator transaction, the cleaned physical reset can arrive too late to prevent normal completion. On hardware, the full 10 ms debounce interval is vastly longer than the 70 ns compute transaction.

The testbench was therefore corrected to separate two independent requirements:

```text
physical reset button
-> verify eventual synchronized/debounced reset and state clear

clean internal reset_level while busy
-> verify deterministic synchronous transaction abort before completion
```

No accelerator RTL was changed for this correction.

---

## 3. Final XSim Result

After correcting the testbench, XSim completed the full directed sequence:

```text
TEST 1: physical reset path
TEST 2: bounce rejection
TEST 3: full board transaction and protocol checks
TEST 4A: physical reset during active transaction - eventual clear
TEST 4B: clean reset_level abort while busy
TEST 5: post-reset recovery transaction
```

The final simulator output was:

```text
PASS: tb_basys3_top_level completed with zero errors
$finish called at time : 1210 ns
```

Therefore:

```text
error_count = 0
```

for the completed testbench run.

---

## 4. Final Measured Waveform State

At the completed simulation state, the user-provided waveform showed:

```text
clk_100mhz            = 0
btn_start             = 0
btn_reset             = 0
led_result            = 0x22
led_done              = 1
error_count           = 0
accepted_start_count  = 1
raw_done_count        = 1
request_count         = 3
track_transaction     = 0
pending_read          = 0
pending_activation    = 0x00000009
pending_weight        = 0x00000001
accepted_start_time   = 0x429
raw_done_time         = 0x46F
```

Converting the two time values:

```text
0x429 = 1065 ns
0x46F = 1135 ns
```

Therefore measured accepted-start-to-raw-done latency is:

```text
1135 ns - 1065 ns = 70 ns
```

which exactly matches the prediction:

```text
7 cycles x 10 ns = 70 ns
```

---

## 5. Signal-by-Signal Verification Explanation

A final PASS line is not treated as sufficient by itself. The passing result is justified by the following checked relationships.

### 5.1 `btn_start` -> conditioner -> `core_start`

The bounce test drove rapid button changes shorter than the debounce interval.

Required result:

```text
bounce-only stimulus
-> no debounced rising event
-> accepted_start_count remains 0
-> core does not become busy
```

Because the completed run contains zero errors, all bounce-rejection assertions passed.

A stable press later generated exactly one accepted transaction. Holding the button did not generate additional accepted starts.

### 5.2 Busy mask

The testbench explicitly created the verification condition:

```text
start_rise = 1
core_busy  = 1
```

and required:

```text
core_start = 0
```

This check occurred during TEST 3. The final per-test scoreboard is reset later, so the end-of-simulation `busy_mask_checks` value is not used as standalone evidence. The zero-error final result confirms that the TEST-3 busy-mask assertions did not fail.

### 5.3 Operand request count and order

For a completed nominal transaction, the scoreboard required exactly three paired activation/weight request cycles:

```text
request 0
request 1
request 2
```

The final recovery transaction shows:

```text
request_count = 3
```

which matches the three-word packing model.

The testbench also asserts the exact address order `0 -> 1 -> 2`; because the final run ended with zero errors, the address-order checks passed.

### 5.4 One-clock synchronous memory return

For each request, the scoreboard saves the expected activation and weight word and checks the memory outputs on the following clock relationship rather than treating the RAM as combinational.

The final stored expected words are:

```text
activation final word = 0x00000009
weight final word     = 0x00000001
```

which are the expected third packed activation and weight words.

The zero-error run therefore confirms that the one-clock synchronous-read checks passed for all three request cycles.

### 5.5 Core compute latency

The final recovery transaction measured:

```text
accepted core_start edge = 1065 ns
raw core_done edge       = 1135 ns
```

Therefore:

```text
latency = 1135 - 1065
        = 70 ns
        = 7 cycles at 100 MHz
```

This is measured from the accelerator transaction boundary, not from the asynchronous physical button transition.

### 5.6 Result value

The final board-visible result is:

```text
led_result = 0x22
           = 34 decimal
           = 8'b0010_0010
```

This matches the independent arithmetic prediction:

```text
accumulator = 1+2+3+4+5+6+7+8+9
            = 45

M_INT       = 3
FRAC_BITS   = 2

product     = 45 x 3 = 135
round bias  = 2
rounded     = 137
137 >> 2    = 34
```

Therefore the board wrapper, memory contents, convolution core, requantization path, and result exposure agree end-to-end.

### 5.7 Raw completion pulse

The final transaction shows:

```text
accepted_start_count = 1
raw_done_count       = 1
```

so exactly one accepted transaction produced exactly one raw completion event in the final recovery case.

### 5.8 Persistent completion LED

At the end of simulation:

```text
led_done = 1
```

while:

```text
track_transaction = 0
btn_start         = 0
btn_reset         = 0
```

This confirms that the board-side `done_latched` indication remains asserted after the raw one-cycle completion event and after the physical start button has been released.

### 5.9 Reset behavior

TEST 1 verified the normal physical reset path.

TEST 4A verified that a physical reset button press eventually produces the cleaned reset behavior and clears board/core state, without making the invalid requirement that it must interrupt a 70 ns transaction before normal completion.

TEST 4B separately forced the already-clean `reset_level` while the core was busy and verified synchronous abort behavior with no stale later completion from the abandoned transaction.

TEST 5 then proved recovery by completing a fresh transaction normally after reset.

---

## 6. Prediction vs Behavioral Measurement

| Quantity | Prediction | Behavioral measurement | Result |
|---|---:|---:|---|
| Clock period | 10 ns | 10 ns | MATCH |
| Accelerator latency | 70 ns | 70 ns | MATCH |
| Memory request count | 3 paired reads | 3 | MATCH |
| Request order | 0 -> 1 -> 2 | assertions passed | MATCH |
| Memory response model | 1-clock synchronous | assertions passed | MATCH |
| Nominal result | 34 / 0x22 | 34 / 0x22 | MATCH |
| Accepted starts in final recovery transaction | 1 | 1 | MATCH |
| Raw done events in final recovery transaction | 1 | 1 | MATCH |
| Persistent completion indication | asserted after completion | `led_done=1` at end | MATCH |
| Behavioral error count | 0 expected | 0 | MATCH |

---

## 7. What This Simulation Proves

The completed XSim run proves the RTL behavior of:

```text
button synchronization/debounce behavior
single-start behavior
busy masking
operand request sequencing
one-clock synchronous operand-return contract
70 ns core transaction latency
end-to-end result = 34
raw completion behavior
persistent done LED behavior
physical-reset eventual clear behavior
clean synchronous reset abort behavior
post-reset transaction recovery
```

---

## 8. What This Simulation Does Not Prove

Behavioral XSim does **not** prove:

```text
actual BRAM inference
actual DSP mapping
final LUT/FF/CARRY utilization
post-route setup/hold timing
100 MHz physical timing closure
Basys-3 package-pin constraints
physical button/LED operation on the board
power consumption
```

Those require synthesis, implementation, timing analysis, constraints, and board-level evidence.

---

## 9. Step-8 Result

**BEHAVIORAL SIMULATION + MEASUREMENT: PASSED**

Measured behavioral evidence agrees with the major Step-3 predictions for transaction latency, request count, synchronous memory behavior, and nominal result.

The next mandatory workflow step is:

```text
Step 9 — update docs/analysis/basys3_top_level.md with measured-vs-predicted behavioral results
```

Physical resource/timing predictions remain unmeasured until final synthesis and implementation of the board top are performed.