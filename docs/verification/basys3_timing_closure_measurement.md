# Basys 3 Timing Closure — Step 8 Simulation Measurement

**Role:** Verification Engineer  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_timing_closure`  
**Workflow stage:** Step 8 — behavioral simulation and measurement  
**Status:** INCOMPLETE RUN — simulation stopped at the configured 1000 ns runtime before the testbench reached its final PASS/FAIL.

## 1. Tool evidence

Vivado/XSim successfully:

```text
compiled the RTL and testbench
elaborated tb_basys3_top_level
built the simulation snapshot
loaded XSim
started behavioral simulation
```

The simulator command file executed:

```text
run 1000ns
```

and XSim reported:

```text
XSim simulation ran for 1000ns
```

Therefore the simulator did not run until the testbench's `$finish`.

## 2. Progress reached before timeout

Transcript reached:

```text
TEST 1: physical reset path
TEST 2: bounce rejection
TEST 3: full board transaction and protocol checks
TEST 4A: physical reset during active transaction - eventual clear
TEST 4B: clean reset_level abort while busy
```

It did not yet show:

```text
TEST 5: post-reset recovery transaction
PASS
FAIL
$finish
```

Therefore no final Step-8 pass/fail judgment is valid yet.

## 3. Visible waveform/scoreboard state near 1000 ns

The supplied waveform screenshot shows approximately:

```text
error_count          = 0
accepted_start_count = 1
raw_done_count       = 0
request_count        = 1
busy_mask_checks     = 0
pipeline_capture_count = 0
track_transaction    = 1
```

This state is consistent with a transaction being tracked during the clean-reset-abort test.

It must not be interpreted as the nominal transaction's final expected counts because the simulation stopped in the middle of TEST 4B.

## 4. Current evidence that is valid

So far, the run demonstrates:

```text
RTL compilation          PASS
testbench compilation    PASS
elaboration              PASS
simulation launch         PASS
no error_count increment visible at 1000 ns
TEST 1..4B were reached
```

## 5. Evidence still required

The run must continue until the testbench terminates naturally and prints its final status.

Required final evidence remains:

```text
TEST 5 executes
pipeline S0/S1/S2 checks complete
three-request invariant completes
80 ns nominal latency check completes
post-reset recovery completes
final error_count = 0
PASS line is printed
$finish is reached
```

## 6. Webtalk message

The separate message:

```text
couldn't read file "C:/Users/UMA"
```

appears in the Webtalk process because the Windows user path contains a space.

It did not prevent XSim compilation, elaboration, or behavioral simulation.

It is not evidence of a DUT or testbench failure.

## 7. Next action

Continue the loaded simulation until completion rather than stopping at 1000 ns.

In the XSim Tcl console:

```tcl
run all
```

Alternatively, increase the configured simulation runtime beyond the point where the testbench reaches `$finish`.

Do not begin synthesis or post-route timing measurement from this partial run. Step 8 remains incomplete until the full behavioral testbench produces a final zero-error PASS.
