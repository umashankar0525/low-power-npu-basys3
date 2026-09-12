# Control FSM — XSim Verification Measurement

**Project:** Low-Power INT8 NPU on Basys 3  
**Role:** Verification Engineer  
**Module:** Control FSM  
**Workflow stage:** SIMULATE / MEASURE  
**Simulator:** Vivado XSim 2018.2  
**Clock:** 100 MHz, 10 ns period

## 1. Result

The uploaded XSim console log shows a functional PASS for the Control FSM unit test.

Final simulator message:

`PASS: control FSM sequencing, handshake, reset, pulse counts, and 70 ns timing verified.`

The test completed with `failures = 0`.

## 2. Signal-by-Signal Measured Behavior

### Reset and IDLE

At the reset/idle checks, the measured outputs were:

- `engine_start = 0`
- `capture_activation = 0`
- `busy = 0`
- `done = 0`

The controller remained in the idle behavior for multiple clocks while `start = 0`.

### LAUNCH

At the first accepted request, the measured outputs were:

- `engine_start = 1`
- `capture_activation = 0`
- `busy = 1`
- `done = 0`

On the following cycle, `engine_start` returned to 0 while `busy` remained high. This confirms that the launch pulse lasts exactly one clock interval.

### WAIT_ENGINE

For several consecutive cycles with `engine_done = 0`, the measured outputs remained:

- `engine_start = 0`
- `capture_activation = 0`
- `busy = 1`
- `done = 0`

This confirms that the controller does not assume a hard-coded engine completion time; it waits for the completion handshake.

### CAPTURE_ACTIVATION

After the modeled engine completion event, the measured outputs were:

- `engine_start = 0`
- `capture_activation = 1`
- `busy = 1`
- `done = 0`

Therefore activation capture occurs before external completion is reported.

### DONE

On the next cycle, the measured outputs were:

- `engine_start = 0`
- `capture_activation = 0`
- `busy = 1`
- `done = 1`

This confirms the finalized handshake rule: the result may be complete, but the controller is still not ready for a new request during `DONE`.

### Return to IDLE

On the following cycle, the measured outputs returned to:

- `engine_start = 0`
- `capture_activation = 0`
- `busy = 0`
- `done = 0`

Only at this point is a new external `start` legal.

## 3. Illegal Start Requests

The simulation explicitly tested two illegal request timings.

### Start during DONE

The log reported:

`PASS: start during DONE was ignored`

No additional engine launch occurred.

### Start while WAIT_ENGINE / busy

The log reported:

`PASS: start while busy was ignored`

The active transaction continued normally and no duplicate `engine_start` pulse was generated.

## 4. Repeated Transaction Behavior

A later legal transaction issued after return to IDLE repeated the expected sequence successfully.

This demonstrates that reset is not required between valid transactions.

## 5. Reset During an Active Transaction

The fourth launch entered the active wait state and was then interrupted by synchronous reset.

After the reset edge the measured outputs became:

- `engine_start = 0`
- `capture_activation = 0`
- `busy = 0`
- `done = 0`

This confirms that reset returns the supervisory controller directly to safe IDLE behavior and abandons the incomplete supervisory transaction.

## 6. Pulse Counts

At the end of simulation the waveform showed:

- `failures = 0`
- `engine_start_count = 4`
- `capture_count = 3`
- `done_count = 3`
- `transaction_count = 3`

The count interpretation is correct:

- Three transactions completed successfully, so there are three capture pulses and three done pulses.
- A fourth transaction was launched and then reset before completion, so there are four launch pulses but only three completed transactions.

## 7. Latency Measurement

The predicted complete supervisory latency was seven clock periods.

At 100 MHz:

`Tclk = 1 / 100 MHz = 10 ns`

Therefore:

`7 x 10 ns = 70 ns`

The testbench comparison itself checks:

`observed_done_time - accepted_start_time == 70`

and the check passed.

The original console print displayed:

`PASS latency: external start -> done = 70000 ns`

This label was misleading. XSim formatted `%t` using the simulation precision, so the displayed numeric value represented 70,000 ps, which equals 70 ns. The comparison in the testbench was still correctly performed against 70 timescale units, so the functional latency check was valid.

The testbench print formatting has been corrected to use a raw numeric nanosecond display (`%0d ns`) so future runs should report:

`PASS latency: external start -> done = 70 ns`

This was a display-only correction and did not change DUT behavior or the latency comparison.

## 8. Prediction Versus Measurement

| Item | Prediction | XSim measurement | Result |
|---|---:|---:|---|
| Clock period | 10 ns | 10 ns | Match |
| `engine_start` duration | 1 cycle | 1 cycle | Match |
| Wait while `engine_done=0` | indefinite | held correctly | Match |
| `capture_activation` duration | 1 cycle | 1 cycle | Match |
| Capture before `done` | required | observed | Match |
| `done` duration | 1 cycle | 1 cycle | Match |
| `busy` during DONE | 1 | 1 | Match |
| `busy` in IDLE | 0 | 0 | Match |
| Start during busy | ignored | ignored | Match |
| Start during DONE | ignored | ignored | Match |
| Reset during active transaction | return to IDLE | observed | Match |
| External start to DONE | 70 ns | 70 ns | Match |
| Verification failures | 0 expected | 0 | Match |

## 9. Non-Fatal Vivado Message

Vivado printed the familiar Webtalk path message:

`source C:/Users/UMA -notrace`

followed by a file-not-found message caused by the space in the Windows user path.

This did not prevent Verilog compilation, elaboration, XSim execution, or completion of the testbench. It is therefore not evidence of a Control FSM functional failure.

## 10. Verification Conclusion

**Functional unit verification PASS.**

The measured XSim behavior agrees with the derived supervisory protocol and the 70 ns latency prediction for the exercised tests.

The verification proves the Control FSM's unit-level sequencing, handshake behavior, pulse ordering, illegal-start handling, restart behavior, and synchronous reset behavior. It does not yet prove full NPU integration, arithmetic correctness, or post-synthesis timing/resource behavior.

## 11. Next Required Workflow Step

Update `docs/analysis/control_fsm.md` with measured-versus-predicted results, then proceed to `/review control_fsm` only after the measurement update is understood.
