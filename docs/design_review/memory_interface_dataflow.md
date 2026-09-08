# Memory Interface and Dataflow — Design Review

**Project:** Low-Power INT8 NPU on Basys 3  
**Phase:** Phase 3 — Memory Interface and Dataflow  
**Role:** Design Reviewer  
**Status:** Reviewed against RTL and XSim verification evidence

## 1. Review Scope

Reviewed the current `memory_interface_dataflow` RTL and its synchronous-memory verification evidence. The review focuses on correctness of the memory/compute schedule, interface assumptions, arithmetic integration, control behavior, and whether the implementation is ready to become the foundation for later NPU stages.

## 2. Assumptions

- Clock frequency: 100 MHz.
- Clock period: 10 ns.
- Activation and weight memories have one-cycle synchronous read latency.
- One 32-bit word contains four packed INT8 values.
- Activation and weight memories are independent, allowing parallel requests.
- One 3x3 single-channel convolution requires 9 products, packed into three words.
- The final word uses one useful lane and three zero lanes.
- Reset is synchronous.

## 3. Functional Architecture Review

The RTL uses five FSM states: `ST_IDLE`, `ST_WAIT0`, `ST_WORD0`, `ST_WORD1`, and `ST_WORD2`. The sequence matches the synchronous-memory contract:

1. Accept `start` and request word 0.
2. Request word 1 while word 0 becomes available.
3. Capture word 0 partial sum and request word 2.
4. Capture word 1 partial sum.
5. Capture word 2 contribution, register the final result, and pulse `done`.

This is the correct conceptual separation between a memory request and consumption of the returned data.

## 4. Timing Review

At 100 MHz, each clock period is 10 ns. The measured XSim transaction has a start-edge to done-edge interval of four clock periods:

`4 x 10 ns = 40 ns`.

Five active rising edges participate if the start edge and done edge are both counted. This distinction should remain explicit in documentation to avoid calling the latency either 4 or 5 cycles without defining the counting convention.

## 5. Arithmetic Review

The datapath extracts four signed INT8 lanes from each 32-bit word and forms four signed INT16 products. The products are reduced through a balanced tree:

- 16-bit products
- 17-bit pairwise sums
- 18-bit four-product partial sum
- sign-extension to INT32
- running INT32 accumulation

The width derivation is sound. Four maximum-magnitude positive products give `4 x 16384 = 65536`, which fits in signed 18 bits. Nine such products can reach `147456`, so INT32 accumulation remains appropriate.

## 6. Verification Evidence

XSim successfully compiled and elaborated the DUT and testbench. The simulation reported:

`PASS: memory latency, address sequencing, accumulation, and completion timing verified.`

Observed evidence included:

- request sequence `0 -> 1 -> 2`,
- request count = 3,
- error count = 0,
- accumulator progression corresponding to partial sums 10 and 20,
- final result = 60,
- completion pulse after the final word.

The testbench intentionally models one-cycle synchronous memory latency, so this result is meaningful for the stated BRAM interface assumption.

## 7. Findings

### Finding 1 — Memory latency handling: PASS

The FSM provides a dedicated wait state and consumes returned data only after the synchronous memory response is available. This directly addresses the principal architectural risk for this module.

### Finding 2 — Address sequencing: PASS

The controller generates exactly three request addresses: 0, 1, and 2. The three requests correspond to the three packed words needed for nine products.

### Finding 3 — Running accumulator: PASS

The architecture accumulates each returned partial sum directly into the INT32 accumulator. The final word is added directly to the registered result, avoiding an unnecessary separate final accumulation register stage.

### Finding 4 — `done` behavior: PASS for tested transaction

`done` is implemented as a one-cycle pulse and the verification test confirms it is asserted at completion and deasserted on the following clock.

### Finding 5 — Busy `start` behavior: DOCUMENTED, LIMITED COVERAGE

The current FSM does not explicitly restart an active transaction when `start` is asserted outside `ST_IDLE`. This means the active transaction is preserved in the current implementation. The behavior should be treated as an interface contract and later made explicit if a higher-level controller can issue overlapping starts.

### Finding 6 — Arithmetic reuse: IMPROVEMENT OPPORTUNITY

The current memory-interface RTL duplicates the four-lane multiplication and reduction logic instead of instantiating the existing `four_mac_datapath` module. This is functionally acceptable for the current learning stage, but reuse should be considered in a later cleanup so there is one authoritative implementation of the four-MAC arithmetic.

## 8. Performance Review

The three-word packing requirement is derived from:

`ceil(9 / 4) = 3 words`.

Each memory word carries four INT8 values, so three activation words and three weight words are required. Because activation and weight memories are independent, the controller can request both in parallel.

The measured single-transaction latency is 40 ns from the start sampling edge to the done sampling edge. This should not be confused with steady-state throughput. Once a stream of convolutions is supported, startup, completion, and address-reuse overhead must be analyzed separately.

## 9. Review Decision

**Decision: ACCEPT WITH FOLLOW-UP ITEMS.**

The current memory-interface/dataflow controller is suitable to proceed to the next architectural stage because its primary synchronous-BRAM timing assumption has been explicitly modeled and verified in XSim.

Before finalizing this module for broader integration, the following should be completed:

1. Run signed boundary and randomized arithmetic tests.
2. Verify reset behavior and busy-start behavior across additional scenarios.
3. Measure synthesis resource usage and timing on XC7A35T-1CPG236C-1.
4. Decide whether to reuse the existing `four_mac_datapath` module rather than duplicate its arithmetic.
5. Integrate actual inferred/instantiated BRAM and verify that its latency matches the simulation contract.

## 10. Final Assessment

The most important design claim is supported: the controller distinguishes **memory request timing** from **memory data consumption timing**. The XSim test demonstrates that the three requested words arrive with the modeled one-cycle delay and are accumulated in the intended order.

This is a meaningful verification milestone, but it is not yet complete verification of all arithmetic corner cases or FPGA implementation timing.
