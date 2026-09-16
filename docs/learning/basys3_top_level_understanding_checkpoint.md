# Phase 8 — Basys 3 Top-Level Teaching Understanding Checkpoint

**Role:** Teaching Assistant  
**Active Phase:** Phase 8 — Basys 3 Top-Level Integration, Physical Validation, and Final Optimization  
**Module:** `basys3_top_level`  
**Workflow stage:** Step 1 — `/teach basys3_top_level` understanding gate  
**Status:** AWAITING LEARNER RESTATEMENT

The core-only synthesis/implementation baseline has already been completed and understood. This checkpoint is now focused on the board-wrapper concepts required before `/design basys3_top_level` is allowed.

The learner must explain, in their own words:

1. Why `convolution_integration` is not yet a complete Basys-3 top-level design.
2. Which responsibilities belong to `basys3_top_level` and which must remain inside the accelerator core.
3. Why a physical pushbutton cannot be wired directly to the core `start` input.
4. The difference between synchronization, debouncing, and one-cycle pulse generation.
5. Why Phase-8 memory must preserve the one-clock synchronous-read behavior established in Phase 7.
6. Why each operand memory requires three 32-bit words for nine INT8 values, giving 96 bits per operand memory and 192 packed logical bits combined.
7. Why a small RTL memory declaration does not by itself prove Vivado mapped the memory into BRAM.
8. Why a raw one-cycle `done` signal at 100 MHz is not suitable as a directly visible LED indication.
9. Why the final `basys3_top_level` must undergo its own synthesis and post-route timing analysis even though the accelerator core already has a baseline physical characterization.
10. What low-power design means at the board-top level, and why clock enables/activity reduction are preferred over manually gating the FPGA clock with ordinary combinational logic.

**Gate:** Do not proceed to `/design basys3_top_level` until these concepts are restated correctly.