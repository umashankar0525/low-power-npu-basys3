# Low-Power INT8 NPU on Basys 3

## Final Project Status

**COMPLETED — 2026-11-18**
The project owner confirms all planned phases are complete, the final bitstream was programmed onto the physical Digilent Basys 3 board, and expected hardware output was observed. This supersedes the former Phase 8 active status.

### Final board demonstration
- Board: Digilent Basys 3 / XC7A35T-1CPG236C
- Clock target: 100 MHz (10 ns period)
- Single-channel 3×3 INT8 convolution; four parallel product lanes
- Signed INT16 products; signed INT32 accumulation
- Fixed-point requantization, ReLU and INT8 saturation
- Conditioned start/reset buttons; result and completion LEDs
- Demonstration: activations 1–9, all-one weights, M_INT=3, FRAC_BITS=2
- Expected arithmetic: accumulator 45 → rounded output 34 (0x22)
- Physical output observed: owner-confirmed

### Evidence qualification
The board photograph supplied on 2026-11-18 documents the physical Basys 3 setup. Successful programming and expected visible output are owner-reported evidence. No new Vivado implementation report, programming log, or raw measurement table was supplied.

**Historical timing caveat:** docs/analysis/basys3_top_level.md records WNS = -3.453 ns, TNS = -99.753 ns and 43 failing setup endpoints against the 10 ns clock requirement. Preserve this historical measured result. The newly reported board demonstration does not alter it. A newer timing report is required before claiming formal 100 MHz setup closure.
No new resource, power, latency or Fmax values are invented.

## Roadmap and workflow (completed)
Learning → architecture/design → prediction → RTL → unit/integration verification → simulation → synthesis/implementation → timing/resource analysis → bitstream generation → physical Basys 3 programming and demonstration → final documentation. The project owner reports all phases complete.

## Reference parameters
- Target FPGA: XC7A35T-1CPG236C; clock target: 100 MHz
- Convolution: 3×3; input channels: 1; output channels: 1
- Four parallel INT8 product lanes; INT16 products; INT32 accumulator
- ReLU; FPGA BRAM; FSM control

## Repository structure
```text
rtl/{primitives,compute,activation,memory,control,infrastructure,top}
tb/{unit,integration,scripts}
python/{quantization,reference,verification,weight_generation,visualization}
mem/
vivado/constraints/
docs/{learning,design,verification,analysis,design_review}
```

## Final handoff
- [x] All phases reported complete by project owner
- [x] Bitstream programmed on physical Basys 3 (owner-confirmed)
- [x] Expected board output observed (owner-confirmed)
- [x] README and learning-document status updated
- [ ] Add board photograph to repository as a tracked asset if desired
- [ ] Attach newer Vivado timing/utilization reports if formal measured sign-off is required
- [ ] Add raw repeated-trial observations and programming log if available
