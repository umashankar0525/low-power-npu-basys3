# 4-MAC Scheduling — Learning Plan

## Role
Teaching Assistant.

## Active Phase
Phase 1 — Arithmetic Foundations and MAC Design.

## Project Phase Map

The project is organized into 8 architecture/build phases:

1. Arithmetic foundations and MAC design — IN PROGRESS
2. 4-MAC compute datapath and scheduling — NEXT
3. BRAM data movement and buffering
4. ReLU and output/quantization path
5. Control FSM and end-to-end sequencing
6. Convolution engine integration and verification
7. Basys 3 FPGA implementation, timing, resource, and power measurement
8. Final design review, optimization, and interview-oriented validation

Phase 1 is partially complete: the INT8 arithmetic primitive and INT32 accumulator have been functionally verified. The remaining Phase 1 work is to derive and design the 4-MAC schedule.

## What the 4-MAC Problem Means

A 3x3 single-channel convolution requires nine multiply operations:

S = a0*w0 + a1*w1 + ... + a8*w8

The architecture has four MAC units, so up to four products can be generated in parallel during a cycle.

The mathematical result does not change. Only the schedule changes.

## Lower-Bound Cycle Reasoning

There are 9 products and 4 MAC units.

A lower bound on multiplication groups is:

ceil(9 / 4) = 3 groups

A natural first schedule is therefore:

Cycle/group 1: products 0,1,2,3
Cycle/group 2: products 4,5,6,7
Cycle/group 3: product 8

This establishes that at least three product-generation groups are required if each MAC performs at most one multiplication per cycle.

It does NOT yet establish the final convolution latency, because we still must decide how the four products are reduced into partial sums and how the partial sums are accumulated.

## Architectural Question

There are several possible reduction organizations. For example:

Option A: generate four products, form a partial sum, then accumulate the partial sum.

Option B: feed products into independent accumulators and reduce later.

Option C: use an adder tree between the four MAC products and the main accumulator.

We will not choose among these until the arithmetic, register placement, and timing implications are derived.

## Learning Objective

Before RTL, understand the difference between:

- multiplication parallelism,
- addition/reduction parallelism,
- accumulator state,
- and control/scheduling.

The next teaching step is to derive a concrete schedule on paper and calculate its cycle count from first principles.
