# 4-MAC Scheduling — Learning Checkpoint

## Role
Teaching Assistant.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Understanding Check

The learner correctly identified:

1. Four MAC units can compute four products in parallel. Therefore nine products require at least ceil(9/4) = 3 product-generation cycles.
2. Three multiplication cycles do not automatically mean the convolution result is available after three cycles because the nine products must also be reduced into the final sum.
3. A partial-sum register is needed to preserve state across cycles. In addition, combinational addition/reduction logic is required to actually add the products.

## Important Refinement

The answer 'a register to store the partial sum' is only part of the required hardware. A register stores the partial sum, but an adder or reduction network performs the arithmetic that creates the partial sum.

For four products P0, P1, P2, P3, possible reductions include:

Sequential:

partial = P0 + P1 + P2 + P3

or a balanced tree:

sum01 = P0 + P1
sum23 = P2 + P3
partial = sum01 + sum23

The actual architecture must be derived from timing, resource, and power goals before RTL generation.

## Next Learning Question

Determine whether the four INT16 products should be added directly as a four-input reduction, through a balanced adder tree, or sequentially over multiple cycles. Compare the implications for latency, combinational depth, registers, and switching activity.

No RTL should be generated until this reduction architecture is understood and selected.
