# Convolution Integration — Phase-8 Baseline Physical Characterization

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `convolution_integration` baseline characterization  
**Status:** Baseline synthesis + implementation evidence received; interpretation gate required before board-top design continues.

---

## 1. Evidence received

The user supplied:

- Vivado 2018.2 synthesis log for `convolution_integration`
- synthesized utilization report
- routed timing summary screenshots
- routed critical-path screenshots

Target device:

```text
XC7A35T-1CPG236C
```

Clock constraint:

```text
100 MHz
Tclk = 10 ns
```

---

## 2. Important configuration of this run

The synthesis log shows that the top-level parameters were bound as:

```text
M_INT     = 1
FRAC_BITS = 0
```

This is important because the requantization multiplication becomes multiplication by a compile-time constant of one.

Therefore Vivado is free to remove the physical multiplier entirely and replace the operation with wiring/logic simplification.

This means the measured DSP count from this run belongs specifically to the `M_INT=1, FRAC_BITS=0` configuration.

---

## 3. Synthesis result

Vivado reports:

```text
0 errors
0 critical warnings
16 warnings
```

The synthesized resource usage is:

```text
Slice LUTs       = 386
Slice Registers  = 88
CARRY4           = 75
DSP              = 0
Block RAM Tile   = 0
Bonded IOB       = 83
BUFGCTRL          = 1
```

Device-relative utilization reported by Vivado includes:

```text
LUTs = 386 / 20800 = 1.86%
FFs  = 88 / 41600 = 0.21%
DSPs = 0 / 90 = 0%
BRAM = 0 / 50 tiles = 0%
IOBs = 83 / 106 = 78.30%
```

These are **synthesis measurements**, not structural predictions.

---

## 4. Why the measured DSP count is zero

Earlier analysis structurally identified five logical multiplication operations:

```text
4 x INT8 convolution multipliers
1 x requantization multiplier
```

But logical multiplication operations do not force DSP primitives.

For this particular synthesis run:

```text
M_INT = 1
```

so the requantization expression is effectively multiplication by one. Vivado therefore does not need a DSP48E1 for that operation.

The synthesis report confirms:

```text
DSPs used = 0
```

This does **not** mean Vivado failed to infer the architecture. It means the compile-time parameter made the wide multiplier unnecessary after constant propagation/optimization.

Therefore the earlier prediction of one DSP48E1 is not validated by this run, because the physical configuration being synthesized is different from the representative nontrivial requantization configuration for which that prediction was made.

If the final accelerator uses a nontrivial fixed `M_INT`, that exact coefficient must be synthesized before the final DSP mapping is known. Because `M_INT` is a compile-time parameter, even a nontrivial constant may still be implemented in LUT/carry logic if Vivado judges that mapping cheaper than a DSP.

The physical mapping must always be read from the synthesis report rather than inferred from the `*` operator alone.

---

## 5. Why BRAM usage is zero

The Phase-7 `convolution_integration` core deliberately exposes activation and weight memory ports. It does not instantiate board memories internally.

Therefore:

```text
BRAM = 0
```

is exactly consistent with the current module boundary.

BRAM or another physical memory implementation should appear only after Phase-8 board/memory integration, if the selected memory architecture and synthesis mapping actually use block RAM.

---

## 6. Why the IOB count is very high

The core is being implemented as the synthesis top, so all of its abstract memory buses are treated as FPGA package pins.

Inputs are approximately:

```text
clk                 1
rst                 1
start               1
activation_data    32
weight_data        32
----------------------
total inputs        67
```

Outputs are:

```text
busy                 1
done                 1
activation_rd_en     1
activation_addr      2
weight_rd_en         1
weight_addr          2
activation_out       8
----------------------
total outputs       16
```

Therefore:

```text
67 inputs + 16 outputs = 83 I/O signals
```

which matches the synthesized report:

```text
Bonded IOB = 83
```

This is a useful sanity check.

It also demonstrates why `convolution_integration` is **not** the final Basys-3 top level. Once activation/weight memories become internal to `basys3_top_level`, those 64 external memory-data pins should disappear from the board-facing interface.

---

## 7. Synthesis optimizations observed

Vivado reports that equivalent activation/weight control registers were merged:

```text
weight_rd_en_reg -> activation_rd_en_reg
weight_addr_reg  -> activation_addr_reg
```

This is legal because the current engine drives the two interfaces identically.

Vivado also removed unused upper bits of the convolution result and the permanently zero sign bit of the ReLU output where they could not affect observable behavior under this synthesized configuration.

This explains why physical FF usage does not equal the earlier structural RTL-bit count.

Again:

```text
logical registered bits != final Slice FF count
```

because synthesis can merge, trim, constant-propagate, and map registers into other primitives.

---

## 8. FSM mapping result

Vivado kept the supervisory `control_fsm` in sequential encoding:

```text
ST_IDLE               000
ST_LAUNCH             001
ST_WAIT_ENGINE        010
ST_CAPTURE_ACTIVATION 011
ST_DONE               100
```

The `memory_interface_dataflow` FSM was re-encoded to one-hot:

```text
ST_IDLE   00001
ST_WAIT0  00010
ST_WORD0  00100
ST_WORD1  01000
ST_WORD2  10000
```

This is a good example of the distinction between RTL state encoding and physical synthesis choices. Unless encoding is constrained, the synthesis tool may choose another representation that preserves behavior while improving timing/area.

---

## 9. Routed timing result

The routed timing summary shows:

```text
WNS  = +6.072 ns
TNS  =  0.000 ns
WHS  = +0.168 ns
THS  =  0.000 ns
WPWS = +4.500 ns
TPWS =  0.000 ns
```

Failing endpoints:

```text
setup = 0
hold  = 0
pulse width = 0
```

Vivado states:

```text
All user specified timing constraints are met.
```

Therefore the implemented `convolution_integration` **for this exact synthesized configuration and this physical placement/routing run** meets the 100 MHz timing constraint.

This is now real post-route timing evidence rather than behavioral timing.

---

## 10. Critical setup path

The worst setup path lies inside `memory_interface_dataflow`, specifically the accumulator feedback path.

Observed source/destination relationship:

```text
accumulator_reg[9]
 -> accumulator carry/addition logic
 -> accumulator_reg[29]
```

The path report shows:

```text
requirement      = 10.000 ns
data path delay  = 3.903 ns
logic delay      = 2.285 ns
net delay        = 1.618 ns
logic levels     = 8
```

The eight logic levels are reported as approximately:

```text
6 x CARRY4
1 x LUT2
1 x LUT3
```

and the resulting setup slack is:

```text
+6.072 ns
```

This tells us the current routed critical path is not the control FSM and not the requantizer. It is the accumulator carry chain in the convolution engine.

That is architecturally useful information because any future timing optimization should first investigate the accumulation path rather than optimizing unrelated logic.

---

## 11. Why WNS does not directly give Fmax

It may be tempting to calculate an exact maximum frequency directly from:

```text
10 ns - 6.072 ns
```

but that is not a rigorous Fmax measurement.

The timing report includes:

```text
clock insertion delay
clock skew
clock uncertainty
clock pessimism removal
routing effects
```

and the identity of the worst path may change when the clock period is tightened.

Therefore this run proves:

```text
100 MHz closes
```

but does not by itself prove the exact maximum achievable frequency.

A true Fmax characterization would require progressively tighter timing constraints and re-running implementation/timing analysis until the design approaches failure.

---

## 12. Constraint-file observation

The synthesis log shows that Vivado parsed:

```text
requantize_timing_wrapper.xdc
```

The repository version of that file creates only a 10 ns clock on `clk`, so the timing constraint itself is suitable for a 100 MHz baseline clock check.

However, its filename/comments describe the earlier requantization timing wrapper rather than this integrated core.

For Phase-8 project clarity, a dedicated `convolution_integration` baseline constraint file should be created during the appropriate design step instead of continuing to reuse a constraint file whose name describes another module.

---

## 13. Why this still is not final Basys-3 timing sign-off

This run is valuable baseline physical evidence, but it is not final board-level sign-off.

The future `basys3_top_level` will change the physical design by adding:

```text
activation/weight memories
button synchronization/debounce/pulse logic
board-status logic
LED/output routing
real Basys-3 package pin constraints
additional fanout and placement constraints
```

The current standalone implementation also treats the abstract core ports as physical I/O, which produces the 83-IOB result.

Therefore the full Phase-8 board top must still be synthesized and implemented again.

---

## 14. Baseline conclusion

For the current baseline configuration:

```text
M_INT     = 1
FRAC_BITS = 0
```

we now have measured physical evidence:

```text
LUTs   = 386
FFs    = 88
CARRY4 = 75
DSP    = 0
BRAM   = 0
IOB    = 83
BUFG   = 1

WNS  = +6.072 ns
TNS  =  0.000 ns
WHS  = +0.168 ns
THS  =  0.000 ns
```

and the routed critical setup path is the accumulator carry/addition feedback path inside `memory_interface_dataflow` with a 3.903 ns data-path delay.

The 100 MHz constraint is met for this baseline implementation.

The two most important caveats are:

1. `DSP=0` is strongly influenced by `M_INT=1`, which lets Vivado optimize away the requantization multiplication.
2. this is core-only timing/resource evidence, not final `basys3_top_level` evidence.

---

## 15. Understanding gate

Before we decide whether to rerun the core using a representative nontrivial requantization coefficient or continue into board-top design, explain in your own words:

1. Why does this run report `DSP=0` even though the RTL structurally contains a requantization multiplication?
2. Why is `83 IOB` expected when `convolution_integration` itself is treated as the FPGA top?
3. What does `WNS=+6.072 ns`, `TNS=0`, `WHS=+0.168 ns`, and `THS=0` prove?
4. Why is the accumulator path now more important for timing optimization than the controller in this implementation?
5. Why must the final `basys3_top_level` still be synthesized and implemented again?