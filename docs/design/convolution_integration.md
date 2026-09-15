# Convolution Integration — Design Specification

**Role:** Design Engineer  
**Active Phase:** Phase 7 — Convolution Integration and End-to-End Dataflow  
**Module:** `convolution_integration`  
**Workflow stage:** Step 2 — `/design convolution_integration`  
**Status:** Design proposed; understanding gate required before prediction analysis or RTL.

---

## 1. Design Objective

Create one integration module that turns the already-verified control, convolution, and requantization blocks into a single synchronous accelerator transaction.

The integrated path is:

```text
external start
    -> control_fsm
    -> memory_interface_dataflow
    -> signed INT32 convolution result
    -> requantize_relu_pipelined
    -> architectural INT8 activation register
    -> external done
```

The integration module must not duplicate functionality already owned by a child block. Its job is wiring, transaction-level coordination, output registration, and preservation of the established timing contracts.

The first target remains one 3x3, one-input-channel, one-output-channel convolution.

---

## 2. Explicit Assumptions

1. FPGA target: XC7A35T-1CPG236C on Basys 3.
2. Clock frequency: 100 MHz.
3. Clock period:

```text
Tclk = 1 / 100 MHz = 10 ns
```

4. Reset is synchronous and active high.
5. External `start` is a one-clock pulse and is legal only while `busy = 0`.
6. `control_fsm` remains the existing five-state Moore controller.
7. `memory_interface_dataflow` remains the existing local convolution engine.
8. Activation and weight memories behave as synchronous memories with one clock of read latency.
9. Activation and weight words are 32 bits wide and contain four packed signed INT8 lanes.
10. Packing contract:

```text
lane 0 -> bits [7:0]
lane 1 -> bits [15:8]
lane 2 -> bits [23:16]
lane 3 -> bits [31:24]
```

11. The third word contains element 8 in lane 0 and zeroes in lanes 1..3.
12. Generated INT8 activation and weight values use `[-127,+127]`.
13. The convolution engine's registered output is signed INT32.
14. Current 3x3 single-channel positive accumulator magnitude is bounded by 145161.
15. `requantize_relu_pipelined` uses a 24-bit unsigned `M_INT` and `FRAC_BITS` in the valid range 0..42.
16. The requantizer itself performs ReLU/sign gating; a separate `relu_activation` block must not be inserted in this integrated data path.
17. `q_out` from the requantizer is combinational from its registered 42-bit product.
18. The final architectural INT8 activation is stored in a register owned by the integration module.
19. The existing 70 ns start-to-done value remains an architectural prediction until integrated simulation measures it.
20. No board switches, buttons, LEDs, debouncers, pin constraints, or clock-generation logic are part of this module.

---

## 3. Chosen Module Boundary

The future RTL module will be named conceptually:

```text
convolution_integration
```

and will belong under:

```text
rtl/top/
```

This is an accelerator-core integration wrapper, not yet the Basys-3 board top.

The module owns:

- child-module instantiation,
- transaction-level control connectivity,
- the final INT8 activation register,
- requantization parameters,
- propagation of the child engine's memory interface to the outside.

The module does **not** own:

- physical BRAM instantiation,
- board I/O,
- host protocol logic,
- multi-layer scheduling,
- multi-output-channel scheduling,
- dynamic loading of requantization parameters,
- a second convolution controller,
- a second MAC datapath.

---

## 4. Why the Memories Stay Outside This Integration Module

The integration module will expose the activation and weight memory read interfaces rather than instantiate physical BRAMs internally.

This boundary is chosen for three reasons.

### 4.1 Verification flexibility

An integration testbench can provide a cycle-accurate one-clock-latency memory model without changing the accelerator core.

### 4.2 Board flexibility

A later Basys-3 wrapper can connect the same interface to inferred BRAM or explicit FPGA memory structures.

### 4.3 Separation of responsibilities

The existing engine already owns memory **sequencing**:

```text
read enable
address 0
address 1
address 2
```

but it should not also dictate how those words are physically stored at this integration level.

Therefore the core exposes the established child-engine memory ports unchanged.

---

## 5. Proposed Integration Interface

### 5.1 Parameters

```text
M_INT      : 24-bit unsigned compile-time requantization coefficient
FRAC_BITS  : integer compile-time fractional-bit count
```

These parameters are passed directly to `requantize_relu_pipelined`.

The integration wrapper does not recompute quantization parameters in hardware.

### 5.2 Clock and reset inputs

```text
clk
rst
```

Every sequential child block and the architectural activation register use the same clock and synchronous active-high reset.

### 5.3 Transaction input

```text
start
```

Contract:

- one clock wide,
- only asserted while `busy = 0`,
- sampled by the supervisory controller in `IDLE`.

### 5.4 Transaction outputs

```text
busy
done
```

`busy` and `done` come directly from `control_fsm`.

`done = 1` means the architectural `activation_out` register already contains the completed activation for the transaction.

### 5.5 Activation-memory interface

```text
activation_rd_en      output
activation_addr[1:0]  output
activation_data[31:0] input
```

### 5.6 Weight-memory interface

```text
weight_rd_en      output
weight_addr[1:0]  output
weight_data[31:0] input
```

### 5.7 Architectural data output

```text
activation_out[7:0]
```

The output is conceptually signed INT8 for compatibility with the requantizer interface, but after ReLU/saturation its legal numerical range is:

```text
0..127
```

Thus bit 7 is expected to be zero for legal completed outputs under the current contract.

---

## 6. Internal Block Hierarchy

The integration structure is:

```text
                         +------------------+
 external start -------->|   control_fsm    |
                         |                  |
            engine_done -|<                 |
                         |                  |
                         | engine_start ----+------------------+
                         | capture_activation                  |
                         | busy / done                         |
                         +------------------+                  |
                                                               v
                                              +-----------------------------+
 activation memory interface <-------------->| memory_interface_dataflow   |
 weight memory interface <------------------>|                             |
                                              | 4-lane INT8 MAC/reduction   |
                                              | INT32 accumulation          |
                                              +-------------+---------------+
                                                            |
                                                     engine_result
                                                            |
                                                            v
                                              +-----------------------------+
                                              | requantize_relu_pipelined   |
                                              | ReLU/sign gate              |
                                              | 18x24 multiply              |
                                              | product_reg                 |
                                              | round/shift/saturate        |
                                              +-------------+---------------+
                                                            |
                                                     requantized_q
                                                            |
                                                            v
                                              +-----------------------------+
 capture_activation ------------------------>| architectural output reg    |
                                              +-------------+---------------+
                                                            |
                                                     activation_out
```

---

## 7. Internal Signals

The wrapper requires only a small set of internal transaction/data signals:

```text
engine_start
engine_done
capture_activation
engine_result[31:0] signed
requantized_q[7:0] signed
```

The controller owns the first three control relationships.

The datapath relationship is simply:

```text
memory_interface_dataflow.result
    -> requantize_relu_pipelined.acc_in

requantize_relu_pipelined.q_out
    -> activation output register D input
```

No combinational arithmetic should be added by the wrapper itself.

---

## 8. Architectural Output Register

The integration module adds exactly one architectural output register:

```text
activation_out
```

Its behavior is:

```text
if reset:
    activation_out <- 0
else if capture_activation:
    activation_out <- requantized_q
else:
    activation_out holds its previous value
```

This register has two purposes.

### 8.1 Transaction stability

The requantizer's internal `product_reg` is clocked every cycle, so its combinational `q_out` can conceptually change as its input history changes. The architectural output must not follow those internal changes continuously.

The explicit capture enable makes `activation_out` represent only a completed transaction.

### 8.2 Handshake meaning

When the controller subsequently asserts external `done`, the data contract becomes:

```text
done = 1  =>  activation_out is already the completed transaction result
```

This gives the external user a clean synchronous interface.

---

## 9. Why No Additional ReLU Block Is Used

`requantize_relu_pipelined` already contains:

```text
acc_positive = positive/nonzero test
acc_mag      = positive magnitude or zero
```

Therefore non-positive accumulators are converted to zero before the fixed-point multiply.

Adding the previously built standalone `relu_activation` in front of or after this block would duplicate activation behavior and would change the carefully verified Phase-6 arithmetic/timing path.

The integrated activation path is therefore exactly:

```text
INT32 convolution result
 -> requantize_relu_pipelined
 -> registered INT8 output
```

---

## 10. Why No Standalone `4mac_datapath` Is Added at This Level

The current `memory_interface_dataflow` implementation already contains the four signed INT8 multipliers, balanced reduction tree, and INT32 running accumulation required for the three packed words.

The integration wrapper must therefore treat `memory_interface_dataflow` as the convolution engine rather than instantiating another `4mac_datapath` in parallel.

Refactoring the engine to reuse the standalone `4mac_datapath` could be a future cleanup task, but it is not part of Phase-7 integration because it would change a previously verified child module at the same time as system integration.

---

## 11. Exact Control/Data Connectivity

The required connections are:

```text
external start
    -> control_fsm.start

control_fsm.engine_start
    -> memory_interface_dataflow.start

memory_interface_dataflow.done
    -> control_fsm.engine_done

memory_interface_dataflow.result
    -> requantize_relu_pipelined.acc_in

control_fsm.capture_activation
    -> activation_out register enable

control_fsm.busy
    -> external busy

control_fsm.done
    -> external done
```

All three sequential blocks share:

```text
clk
rst
```

---

## 12. Synchronous-Memory Contract

The integration module preserves the current engine assumption of one-clock memory read latency.

A request is represented by:

```text
rd_en = 1
addr  = requested word index
```

The memory model or later BRAM wrapper must return the corresponding 32-bit word according to the one-clock-latency behavior expected by `memory_interface_dataflow`.

The core does not insert additional memory wait states beyond those already present in the engine.

The address space used for one convolution is:

```text
0, 1, 2
```

for both activations and weights.

---

## 13. Exact Edge-Level Transaction Schedule

The design uses the following edge convention:

> `E0` is the rising edge on which the external `start` pulse is sampled while the controller is in `IDLE`.

The table describes the architectural state immediately after each edge and the important action associated with that edge/cycle.

| Edge | Controller after edge | Engine after edge | Important event |
|---|---|---|---|
| `E0` | `LAUNCH` | `IDLE` | External start accepted; `engine_start` becomes high for the E0->E1 interval |
| `E1` | `WAIT_ENGINE` | `ST_WAIT0` | Engine samples `engine_start`; requests memory word 0 |
| `E2` | `WAIT_ENGINE` | `ST_WORD0` | Synchronous memories return word 0 after the edge; engine requests word 1 |
| `E3` | `WAIT_ENGINE` | `ST_WORD1` | Engine accumulates word 0; memories return word 1; engine requests word 2 |
| `E4` | `WAIT_ENGINE` | `ST_WORD2` | Engine accumulates word 1; memories return word 2; reads are then disabled |
| `E5` | `WAIT_ENGINE` | `IDLE` | Engine consumes word 2 and registers final INT32 `result` plus `engine_done=1` |
| `E6` | `CAPTURE_ACTIVATION` | `IDLE` | Controller observes registered `engine_done`; requantizer captures product derived from final result into `product_reg` |
| `E7` | `DONE` | `IDLE` | Output register captures rounded/shifted/saturated `q_out`; external `done` becomes high |
| `E8` | `IDLE` | `IDLE` | `done` falls and `busy` falls; controller is ready for a later legal start pulse |

This schedule is a design derivation, not yet an integrated simulation measurement.

---

## 14. Why `E5`, `E6`, and `E7` Must Be Separate

### E5 — final convolution result registration

At E5 the engine executes its final nonblocking updates:

```text
result <= final convolution sum
engine_done <= 1
```

The requantizer cannot sample the newly written `result` on E5 because its own sequential block evaluates using the old pre-edge engine result.

### E6 — product pipeline registration

Between E5 and E6, the new engine result propagates through:

```text
sign/ReLU gate
 -> 18-bit magnitude
 -> fixed-point multiply
```

At E6 the requantizer captures the corresponding 42-bit product in `product_reg`.

### E6 to E7 — stage-2 combinational work

The registered product then propagates through:

```text
rounding bias addition
 -> right shift
 -> saturation
```

During this same interval the controller is in `CAPTURE_ACTIVATION`, so its capture request is high.

### E7 — architectural activation capture

At E7 the wrapper's activation register captures the now-valid `q_out`.

After E7 the controller is in `DONE`, so external `done = 1` and the completed activation is already registered.

---

## 15. Preliminary Start-to-Done Latency Derivation

From accepted start at E0 to external done becoming active after E7 there are seven clock intervals:

```text
E0 -> E1 : 1
E1 -> E2 : 2
E2 -> E3 : 3
E3 -> E4 : 4
E4 -> E5 : 5
E5 -> E6 : 6
E6 -> E7 : 7
```

Therefore:

```text
predicted latency = 7 cycles
```

At 100 MHz:

```text
Tclk = 10 ns
predicted latency = 7 * 10 ns = 70 ns
```

This number must remain labeled **predicted** until Step 8 integrated simulation measures it.

The next `/analyze convolution_integration` step will formalize all cycle, throughput, bandwidth, and resource predictions from first principles.

---

## 16. Why No Extra FSM State Is Currently Required

The existing controller already has the state:

```text
ST_CAPTURE_ACTIVATION
```

The requantizer's new product pipeline stage fits into the registered handshake delay that already exists between child-engine completion and architectural output capture:

```text
E5 final result registered
E6 product_reg captures final product / controller enters capture state
E7 output register captures q_out / controller enters done state
```

Therefore adding a separate `WAIT_REQUANT` state would add latency without being required by the present two-stage data path.

This conclusion depends on the exact current requantizer pipeline depth. If a future design inserts another sequential stage after `product_reg`, the control schedule must be re-derived.

---

## 17. Busy and Start Semantics

The wrapper does not invent a new busy policy. It inherits the controller's established Moore behavior:

```text
IDLE               busy=0
LAUNCH             busy=1
WAIT_ENGINE        busy=1
CAPTURE_ACTIVATION busy=1
DONE               busy=1
```

Therefore:

```text
busy = 0  <=>  controller is in IDLE
```

A `start` pulse while `busy = 1` is outside the legal interface contract and is ignored by the current controller state logic.

The `DONE` interval remains busy intentionally, ensuring that an external source cannot treat the completion pulse itself as a new-request window.

---

## 18. Reset Contract

On a rising edge with `rst = 1`:

- `control_fsm` returns to `IDLE`,
- the convolution engine returns to `ST_IDLE`,
- convolution accumulator/result/control outputs return to their defined reset values,
- requantizer `product_reg` becomes zero,
- integration `activation_out` becomes zero.

After reset settles:

```text
busy = 0
done = 0
activation_rd_en = 0
weight_rd_en = 0
activation_out = 0
```

No transaction survives reset.

---

## 19. Transaction Association and Stale Internal Values

The engine's `result` register is not required to clear immediately after a completed transaction. Likewise, the requantizer pipeline register can continuously sample its input every clock.

This is safe because validity is not inferred from the raw datapath value.

Validity is controlled by the transaction protocol:

```text
capture_activation = 1
```

is the only event that updates the architectural output register.

Therefore stale or repeated internal values cannot become a new architectural result unless the controller reaches the legitimate capture state for a transaction.

This separation between **data value** and **data validity** is an important integration principle.

---

## 20. Quantization Parameter Contract

For the Phase-7 single-output-channel integration, `M_INT` and `FRAC_BITS` are compile-time parameters.

That means one synthesized instance corresponds to one selected output scaling configuration.

This is appropriate for the current architectural-learning target.

A future multi-output-channel accelerator may require:

```text
per-channel coefficient storage
coefficient addressing
coefficient muxing
possibly dynamic FRAC_BITS handling
```

Those features are explicitly out of scope for this module.

---

## 21. Design Invariants

The eventual RTL must preserve these invariants:

1. One legal external start produces at most one engine start pulse.
2. One engine completion produces at most one activation capture.
3. External `done` is one clock wide.
4. `done = 1` only after `activation_out` has been registered.
5. `busy = 0` only in controller `IDLE`.
6. The wrapper adds no arithmetic truncation.
7. The wrapper adds no alternate ReLU operation.
8. Memory address sequencing remains owned solely by the child engine.
9. `activation_out` changes only on reset or `capture_activation`.
10. The same clock drives controller, engine, requantizer, and output register.
11. No combinational path is introduced from external `start` directly to data outputs.
12. Requantization parameters remain constant for the duration of a transaction.

---

## 22. What This Design Does Not Yet Prove

This document establishes the architecture but does not prove implementation behavior.

It does **not** yet prove:

- that integrated XSim latency is exactly 70 ns,
- that memory words are observed on the predicted edges in the final testbench model,
- that the final INT8 value matches the Python reference end to end,
- that back-to-back legal transactions have no stale-data contamination,
- that the integrated routed design meets 100 MHz,
- final LUT/FF/DSP/BRAM utilization,
- final dynamic/static power.

Those are later workflow steps.

---

## 23. Design Decision Summary

The Phase-7 integration design is intentionally small:

```text
control_fsm
    + existing convolution engine
    + existing pipelined requantizer
    + one enabled INT8 architectural output register
```

Memories remain outside the core and connect through the existing one-clock-latency read interface.

No additional control state is planned because the registered child-engine handshake naturally aligns the requantizer's product stage with the controller's existing `CAPTURE_ACTIVATION` interval.

The expected external ordering is:

```text
start accepted
 -> engine launch
 -> 3 packed-word convolution
 -> final INT32 result registered
 -> fixed-point product registered
 -> round/shift/saturate
 -> INT8 activation registered
 -> done
```

The next mandatory workflow step, after the design understanding gate, is:

```text
Step 3: /analyze convolution_integration
```

No Phase-7 RTL may be generated before that prediction analysis and the following user understanding confirmation are complete.

---

## 24. Design Understanding Gate

Before proceeding to `/analyze convolution_integration`, the learner must explain in their own words:

1. Why activation and weight memories are exposed through the integration wrapper instead of being hard-wired into this core.
2. Why `activation_out` needs its own capture register even though the requantizer already contains `product_reg`.
3. Why the existing `CAPTURE_ACTIVATION` state is sufficient for the current one-stage internal requantizer pipeline and no extra FSM state is required.
4. Using E5, E6, and E7, explain exactly where the final convolution result, fixed-point product, and final INT8 activation are registered.
