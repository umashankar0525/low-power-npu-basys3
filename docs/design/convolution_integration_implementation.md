# Convolution Integration — RTL Implementation Record

**Role:** Design Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 5 — RTL generation  
**Status:** RTL generated; verification has not yet been performed.

---

## 1. Implemented RTL

The Phase-7 integration core has been created at:

```text
rtl/top/convolution_integration.v
```

The module integrates four architectural pieces:

```text
control_fsm
memory_interface_dataflow
requantize_relu_pipelined
architectural activation_out register
```

The module intentionally contains no additional convolution datapath, no duplicate ReLU block, no physical BRAM instance, and no Basys-3-specific board I/O.

---

## 2. Interface Implemented

### Parameters

```text
M_INT      : 24-bit unsigned requantization multiplier
FRAC_BITS  : integer fractional-bit count
```

These are passed directly into `requantize_relu_pipelined`.

### Transaction interface

```text
clk
rst
start
busy
done
```

### Activation-memory interface

```text
activation_rd_en
activation_addr[1:0]
activation_data[31:0]
```

### Weight-memory interface

```text
weight_rd_en
weight_addr[1:0]
weight_data[31:0]
```

### Architectural output

```text
activation_out[7:0] signed
```

Under the verified ReLU/saturation contract, completed legal outputs are in the numerical range `0..127`.

---

## 3. Control Connectivity

The implemented control path is:

```text
external start
    -> control_fsm.start

control_fsm.engine_start
    -> memory_interface_dataflow.start

memory_interface_dataflow.done
    -> control_fsm.engine_done

control_fsm.capture_activation
    -> activation_out register enable

control_fsm.busy
    -> external busy

control_fsm.done
    -> external done
```

The integration wrapper adds no new controller state.

---

## 4. Datapath Connectivity

The implemented datapath is:

```text
activation_data + weight_data
    -> memory_interface_dataflow
    -> engine_result : signed INT32
    -> requantize_relu_pipelined.acc_in
    -> requantized_q : signed INT8
    -> activation_out register
```

No combinational arithmetic is added in the wrapper itself.

---

## 5. Architectural Output Register

The wrapper owns one explicit transaction-result register:

```text
activation_out
```

Behavior:

```text
if rst:
    activation_out <- 0
else if capture_activation:
    activation_out <- requantized_q
else:
    activation_out holds its previous value
```

This separates the internal free-running requantizer pipeline from the externally visible architectural result.

The intended interface meaning is:

```text
done = 1  =>  activation_out already contains the completed transaction result
```

This statement is part of the design contract and must be verified in Step 6/7/8 rather than assumed from code inspection alone.

---

## 6. Preserved Edge Schedule

The RTL was written to preserve the previously derived Phase-7 sequence:

```text
E5:
    engine registers final signed INT32 result
    engine_done becomes active after the edge

E6:
    control_fsm enters CAPTURE_ACTIVATION
    requantizer product_reg captures the product derived from the final result

E6 -> E7:
    rounding + right shift + saturation produce valid q_out

E7:
    activation_out captures q_out
    control_fsm enters DONE
    external done is asserted for the DONE interval
```

The predicted accepted-start-to-done latency therefore remains:

```text
7 cycles x 10 ns = 70 ns
```

This is still a prediction until integrated XSim measurement is performed.

---

## 7. Memory Boundary Preserved

Physical memory remains outside `convolution_integration`.

The core exposes the existing read-enable/address/data interfaces so that:

```text
verification -> can use a one-cycle-latency memory model
later board integration -> can connect inferred or explicit BRAM
```

This preserves separation between compute/control architecture and physical memory implementation.

---

## 8. No New Arithmetic Assumptions Introduced

The wrapper does not alter the established Phase-6 numerical contract.

Relevant assumptions remain:

```text
activation/weight generated range : [-127,+127]
3x3 single-channel positive accumulation bound : 145161
requantizer magnitude width : 18 bits
M_INT width : 24 bits
product width : 42 bits
rounding intermediate : 43 bits
final post-ReLU range : 0..127
```

The wrapper simply connects existing blocks according to the approved architecture.

---

## 9. What Has Not Yet Been Proven

At this workflow point, the following must **not** be claimed as measured:

- integrated functional correctness,
- 70 ns integrated latency,
- exact address/read-enable waveform at the integration level,
- back-to-back transaction correctness,
- reset behavior across all child blocks as one system,
- integrated resource utilization,
- integrated DSP mapping,
- integrated timing closure at 100 MHz,
- final Slice FF/LUT counts,
- BRAM inference,
- power.

Those belong to the later verification, simulation, analysis-update, and review steps.

---

## 10. Next Workflow Step

The mandatory sequence now moves to:

```text
Step 6: /verify convolution_integration
```

The verification step must define what signals and invariants prove the integration is correct before the testbench is generated.
