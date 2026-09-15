# Convolution Integration — XSim Measurement Record

**Role:** Verification Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 8 — simulation + measurement  
**Status:** Behavioral XSim run completed successfully from user-provided Vivado 2018.2 console output and waveform screenshots.

---

## 1. Evidence Source

The measurement record is based on the user's Vivado 2018.2 behavioral-simulation console output and screenshots from the completed `tb_convolution_integration` run.

The console shows:

```text
Built simulation snapshot tb_convolution_integration_behav
...
PASS: convolution integration testbench completed with 0 detected errors.
$finish called at time : 876 ns
```

The simulator reports a 1 ps time resolution and runs the behavioral testbench for the configured 1000 ns window, with the testbench itself terminating at 876 ns.

A separate earlier `tb_requantize_relu_pipelined` unit run in the same console log also passed all directed checks, but this document records only the Phase-7 integration evidence.

---

## 2. Compile and Elaboration Result

XSim successfully completed both compile and elaboration for the integration hierarchy.

The log shows the following modules compiled/elaborated as part of the integration snapshot:

```text
control_fsm
memory_interface_dataflow
requantize_relu_pipelined
convolution_integration
tb_convolution_integration
```

Therefore Step 8 has direct evidence that the generated integration RTL and testbench are syntactically valid and can be elaborated together in Vivado 2018.2.

The Webtalk message:

```text
couldn't read file "C:/Users/UMA": no such file or directory
```

occurs after snapshot construction and does not prevent XSim compilation, elaboration, or simulation. The behavioral simulation proceeds and reaches the final PASS report.

---

## 3. Directed Tests Executed

The console reports execution of all planned integration scenarios:

```text
TEST: reset and idle state
TEST: positive unsaturated convolution: 45 -> product 135 -> q_out 34
TEST: negative convolution: engine_result -45 then ReLU/requantization to 0
TEST: maximum legal accumulator: 145161 -> saturation to 127
TEST: rounding visibility: 5 -> product 15 -> q_out 4
TEST: start while busy is ignored
TEST: earliest legal restart and stale-data rejection
TEST: synchronous reset during active transaction and recovery
TEST: post-reset recovery transaction: 5 -> product 15 -> q_out 4
TEST: maximum-width requantization integration
```

No error line was reported, and the final testbench report was:

```text
PASS: convolution integration testbench completed with 0 detected errors.
```

---

## 4. Why the PASS Is Meaningful

The testbench does not decide pass/fail from `activation_out` alone.

For every normal tracked transaction, its `run_primary_transaction` task checks the following sequence:

```text
E5:
    engine_result == independently expected INT32 convolution result
    activation_out still holds the previous architectural value

E6:
    capture_activation == 1
    product_reg == expected product derived from E5 engine_result
    requantized_q == expected rounded/shifted/saturated result
    activation_out still has not changed

E7:
    activation_out == expected INT8 result
    busy == 1 during DONE
    accepted-start to done latency == 70 ns
```

The same task additionally checks:

```text
memory request count      == 3
engine_start pulse count  == 1
engine_done pulse count   == 1
capture pulse count       == 1
done pulse count          == 1
```

Therefore a zero-error final result implies that these signal-level conditions were satisfied for the directed primary transactions.

---

## 5. Nominal 45 -> 34 Transaction

The nominal vector is:

```text
activations = [1,2,3,4,5,6,7,8,9]
weights     = [1,1,1,1,1,1,1,1,1]
```

Independent arithmetic:

```text
engine_result = 1+2+3+4+5+6+7+8+9
              = 45
```

With:

```text
M_INT     = 3
FRAC_BITS = 2
```

requantization is:

```text
product_reg = 45 x 3 = 135
rounded     = 135 + 2 = 137
q_out       = 137 >> 2 = 34
```

Because the testbench finished with `error_count = 0`, the directed checks establish the intended association:

```text
E5 engine_result = 45
E6 product_reg   = 135
E6 requantized_q = 34
E7 activation_out= 34
E7 done          = 1 with busy still high
```

The output was also checked not to change before the E7 architectural capture edge.

---

## 6. Memory Sequencing Measurement

For tracked primary transactions, the scoreboard checks each activation and weight memory request pair.

Expected and therefore measured-without-error sequence:

```text
request 1 -> address 0
request 2 -> address 1
request 3 -> address 2
```

The testbench additionally requires:

```text
activation_rd_en == weight_rd_en
activation_addr  == weight_addr
```

and rejects a fourth request.

The provided final waveform screenshot shows, at the end of the final primary tracked transaction:

```text
primary_req_count          = 3
primary_engine_start_count = 1
primary_engine_done_count  = 1
primary_capture_count      = 1
primary_done_count         = 1
primary_capture_seen       = 1
error_count                = 0
```

This is consistent with the intended one-transaction handshake and exactly three packed memory reads.

---

## 7. 70 ns Latency Measurement

The testbench stores the accepted external start time and the external done assertion time and checks:

```text
local_done_time - local_start_time == 70 ns
```

The provided final waveform screenshot for the maximum-width case shows:

```text
first_start_time    = 0x31B = 795 ns
measured_done_time  = 0x361 = 865 ns
```

Therefore:

```text
865 ns - 795 ns = 70 ns
```

This exactly matches the pre-RTL prediction:

```text
7 clock periods x 10 ns = 70 ns
```

The integration latency prediction is therefore behaviorally confirmed for the exercised directed transactions.

---

## 8. 90 ns Earliest Legal Restart

The back-to-back directed test records two accepted-start timestamps and explicitly checks:

```text
second_start_time - first_start_time == 90 ns
```

The overall run completed with zero detected errors, so this assertion passed.

This behavior matches the derived protocol:

```text
E0 accepted start
E7 done
E8 return to IDLE / busy falls
E9 earliest next accepted start
```

Thus:

```text
E0 -> E9 = 9 cycles = 90 ns
```

This confirms the distinction between 70 ns result latency and 90 ns initiation interval.

---

## 9. Negative Convolution / ReLU Measurement

The directed negative case expects:

```text
engine_result = -45
product_reg   = 0
activation_out= 0
```

A zero-error run means the testbench observed the signed negative convolution result before the requantizer suppressed it through the ReLU/sign gate.

This is stronger than observing a final zero alone because it proves the zero is produced by the activation stage rather than by an incorrect convolution result.

---

## 10. Maximum Legal Accumulator and Saturation

The directed maximum primary case uses:

```text
9 x 127 x 127 = 145161
```

With the primary requantization parameters:

```text
product = 145161 x 3 = 435483
q_pre   = (435483 + 2) >> 2
        = 108871
```

Since the result exceeds the legal positive INT8 range:

```text
activation_out = 127
```

The zero-error run therefore confirms the integrated signed accumulation, product formation, and output saturation for the maximum legal positive 3x3 accumulator under the current generated-data contract.

---

## 11. Rounding-Visible Case

For the small directed case:

```text
engine_result = 5
product_reg   = 15
q_out         = (15 + 2) >> 2 = 4
```

The final waveform screenshot after the post-reset recovery transaction shows:

```text
activation_out = 0x04
```

and the scoreboard is still at zero errors.

This confirms that the end-to-end path is performing fixed-point rounding/scaling rather than forwarding the raw accumulator.

---

## 12. Start-While-Busy Behavior

The testbench injects an illegal second `start` while the current transaction is active and then checks that the transaction still has:

```text
engine_start_count = 1
memory requests    = 3
capture_count      = 1
done_count         = 1
```

Because the final integration run reports zero errors, the injected busy-time start did not restart the engine or create duplicate requests/completions.

---

## 13. Reset During Active Transaction and Recovery

The reset-directed test starts a transaction and then asserts synchronous reset while the system is active.

The testbench checks that the following reset to zero/safe state:

```text
busy
external done
activation_out
activation_rd_en
weight_rd_en
engine_done
engine_result
product_reg
```

It then executes a fresh post-reset `5 -> 15 -> 4` transaction.

The final screenshot shows the recovered primary architectural output as:

```text
activation_out = 0x04
```

and the run ends with zero errors, so both active-transaction reset and subsequent recovery were successful for the exercised case.

---

## 14. Maximum-Width Requantization Integration

The secondary DUT uses:

```text
M_INT     = 16777215
FRAC_BITS = 42
engine_result = 145161
```

Expected product:

```text
145161 x 16777215 = 2435397306615
```

Expected rounded result:

```text
(2435397306615 + 2^41) >> 42 = 1
```

The testbench checks at E5/E6/E7 that:

```text
engine_result  = 145161
product_reg    = 2435397306615
requantized_q  = 1
activation_out = 1
latency        = 70 ns
```

The provided waveform screenshot shows:

```text
max_activation_out = 0x01
```

at the end of simulation, and `error_count = 0`.

This confirms that the upper product bits and 43-bit rounded intermediate survive the complete integration path for the maximum-width directed configuration.

---

## 15. Measured Versus Predicted Functional Timing Summary

| Metric | Prediction | Step-8 XSim result | Status |
|---|---:|---:|---|
| Clock period | 10 ns | 10 ns testbench clock | Match |
| Memory requests / transaction | 3 | 3 in tracked scoreboard | Match |
| Address order | 0 -> 1 -> 2 | no scoreboard error | Match |
| `engine_start` / transaction | 1 pulse | 1 | Match |
| `engine_done` / transaction | 1 pulse | 1 | Match |
| capture pulse / transaction | 1 | 1 | Match |
| external `done` / transaction | 1 | 1 | Match |
| Start-to-done latency | 70 ns | 70 ns | Match |
| Earliest accepted-start spacing | 90 ns | 90 ns assertion passed | Match |
| Nominal output | 34 | 34 | Match |
| Negative/ReLU output | 0 | 0 | Match |
| Maximum primary saturation | 127 | 127 | Match |
| Rounding-visible output | 4 | 4 | Match |
| Maximum-width output | 1 | 1 | Match |
| Detected verification errors | 0 expected | 0 | Match |

---

## 16. What Step 8 Does Not Prove

This successful behavioral simulation does **not** prove:

```text
integrated LUT count
integrated Slice FF count
actual integrated DSP48E1 mapping
BRAM inference
post-synthesis setup timing
post-route timing closure
Fmax
power
```

Those require synthesis/implementation measurement rather than behavioral XSim.

---

## 17. Step-8 Conclusion

The Phase-7 integration behavioral verification is successful for the implemented directed test set.

The evidence shows that the child blocks are not merely producing correct isolated values; the complete integration transaction maintains the required timing/data association:

```text
memory request sequence
 -> signed convolution result
 -> registered requantization product
 -> rounding/shift/saturation
 -> architectural output capture
 -> external done
```

The central architectural prediction is confirmed behaviorally:

```text
accepted start -> valid activation_out with done = 70 ns
```

and the supervisory protocol prediction is also confirmed:

```text
earliest legal accepted-start spacing = 90 ns
```

The next workflow step is Step 9: update `docs/analysis/convolution_integration.md` with measured-versus-predicted results. That update belongs to the Performance Analyst role and must be done in a separate interaction/response.