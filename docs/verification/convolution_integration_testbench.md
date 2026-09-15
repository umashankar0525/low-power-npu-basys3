# Convolution Integration — Testbench Implementation Record

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 7 — integration testbench generation  
**Status:** Testbench generated; XSim has not yet been run.

---

## 1. Generated Testbench

The Phase-7 integration testbench has been created at:

```text
tb/integration/tb_convolution_integration.v
```

The testbench instantiates the completed integration RTL and deliberately models activation and weight memories as synchronous one-clock-latency memories.

This is required because the convolution engine was designed for synchronous BRAM-like behavior. A zero-latency combinational memory model would verify a different architecture.

---

## 2. Primary DUT Configuration

The main integration instance uses:

```text
M_INT     = 3
FRAC_BITS = 2
```

Therefore:

```text
M_hat = 3 / 4 = 0.75
```

For positive accumulators:

```text
product = accumulator x 3
q_pre   = (product + 2) >> 2
q_out   = min(q_pre, 127)
```

This configuration makes the requantization stage visible in end-to-end testing rather than allowing the raw accumulator to pass through unchanged.

---

## 3. Secondary Maximum-Width DUT

A second integration instance is included with:

```text
M_INT     = 16777215 = 2^24 - 1
FRAC_BITS = 42
```

This instance exists only to exercise the previously derived maximum-width requantization path through the complete integration wrapper.

The expected maximum-width case is:

```text
accumulator = 145161
product     = 145161 x 16777215
            = 2435397306615
round bias  = 2^41
q_pre       = 1
activation_out = 1
```

No synthesis or DSP-mapping claim is made from this behavioral test.

---

## 4. Synchronous Memory Model

The testbench memory behavior is conceptually:

```text
on rising edge:
    if read_enable:
        data_out <= memory[address]
```

Because the memory model uses nonblocking assignments, the convolution engine evaluates the current edge using the old `data_out` value. The newly requested word becomes visible only after the edge and can be consumed on a later edge.

This reproduces the timing contract already verified for `memory_interface_dataflow`.

---

## 5. Request-Sequence Scoreboard

For each tracked primary transaction, the testbench checks that activation and weight memories:

```text
- assert read enable together,
- use the same address,
- issue exactly three request cycles,
- issue addresses in order 0 -> 1 -> 2,
- return the word corresponding to the requested address after the synchronous memory edge.
```

The scoreboard rejects any fourth request.

This means a numerically correct final output is not enough to pass if the memory sequencing is wrong.

---

## 6. E5 / E6 / E7 Pipeline Checks

The primary transaction checker explicitly verifies the sequential data association:

```text
E5:
    engine_result = independently expected signed INT32 convolution result
    activation_out must still hold its old architectural value

E6:
    capture_activation = 1
    product_reg = product derived from the E5 engine_result
    requantized_q = independently expected rounded/shifted/saturated value
    activation_out must still hold its old value

E7:
    done rises
    activation_out captures the expected INT8 result
```

This is the key protection against off-by-one pipeline errors and stale-data capture.

---

## 7. Directed Cases Implemented

### Case 1 — Reset and idle

Checks:

```text
busy = 0
done = 0
activation_out = 0
read enables = 0
addresses = 0
product_reg = 0
```

### Case 2 — Positive unsaturated convolution

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

Independent expectation:

```text
engine_result = 45
product_reg   = 135
q_out         = 34
activation_out= 34
```

### Case 3 — Negative convolution through ReLU

```text
engine_result = -45
product_reg   = 0
activation_out= 0
```

This distinguishes correct signed convolution from an accidental arithmetic zero.

### Case 4 — Maximum legal positive accumulator with saturation

```text
9 x 127 x 127 = 145161
product = 435483
q_pre   = 108871
activation_out = 127
```

### Case 5 — Small rounding-visible case

```text
engine_result = 5
product_reg   = 15
q_out         = 4
```

### Case 6 — Start while busy

A second external `start` pulse is injected while the current transaction is active.

Expected:

```text
engine_start count = 1
memory request count = 3
capture count = 1
done count = 1
```

### Case 7 — Earliest legal back-to-back transactions

Transaction 1 produces:

```text
34
```

Transaction 2 produces:

```text
4
```

The accepted-start timestamps must be:

```text
90 ns apart
```

Using different results proves the second completion corresponds to fresh transaction data.

### Case 8 — Reset during active transaction and recovery

A synchronous reset is applied after the transaction has started.

The test checks that control, engine result, output register, read enables, and requantizer pipeline state return to their reset values. A new legal transaction is then run to prove recovery.

### Case 9 — Maximum-width requantization integration

The secondary DUT checks:

```text
engine_result = 145161
product_reg   = 2435397306615
q_out         = 1
activation_out= 1
```

---

## 8. Latency Measurement

The testbench records the rising edge at which a legal external `start` is accepted and the rising transition of external `done`.

Predicted interval:

```text
7 clock periods
```

At 100 MHz:

```text
7 x 10 ns = 70 ns
```

The testbench compares the measured edge-to-edge interval against 70 ns.

This is still only a testbench expectation until XSim is actually run.

---

## 9. Pulse-Level Checks

For a successful tracked transaction, the expected counts are:

```text
engine_start       = 1
engine_done        = 1
capture_activation = 1
done               = 1
memory requests    = 3
```

The testbench also checks that `done` is not observed before a capture event and that `done=1` never coincides with `busy=0`.

---

## 10. What Has Not Yet Been Proven

Generation of the testbench does **not** prove that it compiles or passes.

At this point no claim is made about:

```text
XSim compile success
XSim elaboration success
behavioral PASS/FAIL
measured 70 ns latency
measured 90 ns initiation spacing
waveform correctness
integrated resource usage
DSP mapping
timing closure
power
```

Those require Step 8 simulation and later synthesis/implementation measurement.

---

## 11. Step-8 Evidence Required

When XSim is run, the result must be reviewed signal by signal. A final `PASS` message alone will not be accepted.

For the nominal 45 -> 34 case, the review must show at minimum:

```text
memory requests: 0 -> 1 -> 2
engine_result: 45 at E5
product_reg: 135 at E6
capture_activation: high during E6 -> E7
requantized_q: 34 before E7
activation_out: 34 at E7
done: high with activation_out already valid
accepted-start-to-done latency: 70 ns
```

The measured results must then be compared against the predictions in:

```text
docs/analysis/convolution_integration.md
```

---

## 12. Next Workflow Step

The mandatory workflow now moves to:

```text
Step 8: simulation + measurement
```

The testbench is ready for XSim execution, but simulation has not been performed through the available ChatGPT tool trace.
