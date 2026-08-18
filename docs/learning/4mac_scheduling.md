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

## Width Derivation

Each INT8 x INT8 product is represented as signed INT16.

Maximum positive product:

127 x 127 = 16129

The mathematical product range is actually:

-16256 <= product <= 16384

because (-128) x 127 = -16256 and (-128) x (-128) = 16384.

For two maximum positive products:

16384 + 16384 = 32768

Signed INT16 maximum:

32767

Therefore the pairwise sum cannot safely remain INT16 and requires INT17.

For four maximum positive products:

4 x 16384 = 65536

Signed INT17 maximum:

65535

Therefore the four-product partial sum cannot safely remain INT17 and requires INT18.

The signed INT18 maximum is:

131071

so 65536 is safely representable.

The final 3x3 convolution sum is bounded by:

9 x (-16256) = -146304
9 x 16384 = 147456

This fits easily within signed INT32, whose range is:

-2147483648 to 2147483647

Therefore an INT18 four-product partial sum can be sign-extended to INT32 before being added to the INT32 accumulator.

## Corrections to Learner Responses

The learner's second response had a small arithmetic wording error: the maximum four-product sum is 65536, not 65535. INT17 is insufficient because its maximum positive value is 65535.

The third response correctly recognized that INT32 can safely hold the convolution result, but the reason should be stated using the INT32 representable range as well as the derived convolution bound. The convolution bound (-146304 to 147456) is far inside the INT32 range (-2147483648 to 2147483647).

## Next Learning Question

For the balanced tree, derive the arithmetic depth from four INT16 products to one INT18 partial sum. Then predict whether this two-level addition tree can fit within one 100 MHz cycle. Do not claim timing closure without synthesis/place-and-route measurement.

No new RTL should be generated until this timing prediction and architecture selection are complete.
