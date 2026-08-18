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

## Reduction Architecture Comparison

Two candidate organizations were compared.

### A — Balanced adder tree plus shared partial-sum state

The four products can be reduced as:

sum01 = P0 + P1
sum23 = P2 + P3
partial = sum01 + sum23

A partial-sum register can then preserve the result between product-generation groups.

Expected characteristics:

- one shared partial-sum register rather than four independent accumulation registers;
- fewer state elements;
- simpler control because one partial-sum state is updated;
- a combinational reduction network is required;
- switching activity in the reduction network depends on operand activity.

### B — Four independent accumulators

Each MAC can maintain its own partial state:

acc0, acc1, acc2, acc3

and a later reduction computes:

final = acc0 + acc1 + acc2 + acc3

Expected characteristics:

- four accumulator registers instead of one shared partial-sum register;
- more state and more register storage;
- more state to control and reset;
- a final reduction network is still required;
- more accumulator state can introduce additional switching activity.

## Learning Conclusion

The learner correctly predicted:

1. Option B requires more accumulator registers.
2. Option A has fewer pieces of state.
3. Option A is expected to be simpler to control.
4. Option A is expected to have lower storage-related switching activity.

These are architectural predictions, not measured implementation results.

## Important Refinement

Option A is not automatically the final architecture. It may have a larger combinational reduction path than a sequential accumulation approach. Therefore the next step is to derive the timing and cycle implications before selecting the reduction architecture.

## Next Learning Question

For four signed INT16 products, determine the required width of:

- each product,
- each pairwise sum in a balanced tree,
- the four-product partial sum,
- and the final INT32 convolution accumulation.

Then determine whether a balanced tree can produce the four-product partial sum within one 100 MHz cycle as a prediction. No RTL should be generated until this derivation is complete.
