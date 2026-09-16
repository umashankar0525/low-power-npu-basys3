# Phase 8 — Convolution Integration Baseline Physical Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `convolution_integration` baseline physical characterization

## Learner responses

### 1. Why the measured DSP count is zero

**Status: PASSED**

The learner correctly stated that this synthesis run used a compile-time requantization multiplier coefficient of `M_INT = 1`, allowing Vivado to optimize the multiplication away. Therefore the measured DSP count of zero does not contradict the existence of a structural multiplication in the RTL.

### 2. Why the core-only top uses many IOBs

**Status: PASSED**

The learner correctly identified that the two external 32-bit memory-data buses are treated as top-level FPGA I/O when `convolution_integration` itself is synthesized as the design top. This contributes heavily to the 83 bonded IOBs reported in the baseline run.

### 3. Meaning of positive WNS/WHS and zero TNS/THS

**Status: PASSED**

The learner correctly concluded that the routed implementation meets the current 100 MHz timing constraint for this exact core-only configuration. Positive setup and hold slack with zero total negative slack indicates no failing setup or hold endpoints in the reported timing analysis.

### 4. Why the accumulator is the important timing path

**Status: PASSED**

The learner correctly identified the worst setup path as the path from one accumulator register bit through the accumulator carry/addition chain back into another accumulator register bit. Therefore the accumulator carry chain is the current core-only critical path.

### 5. Why `basys3_top_level` still needs its own physical run

**Status: PASSED**

The learner correctly stated that the present result is only the baseline characterization of `convolution_integration`. The final Basys-3 top will add memories, input-conditioning logic, pulse-generation logic, status/LED logic, additional hierarchy, routing and fanout. These changes can alter both resource usage and timing, so the full top must be synthesized and implemented again with its own dedicated constraints.

## Gate result

**BASELINE PHYSICAL CHARACTERIZATION UNDERSTANDING GATE: PASSED**

The learner understands the meaning and limitations of the core-only synthesis and implementation results. Phase 8 may now continue to the Basys-3 top-level teaching/design workflow.