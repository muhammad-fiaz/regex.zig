---
title: Architecture & PikeVM
description: Understand the internal matching pipeline, compact instruction set, and lockstep dual-queue thread execution model.
keywords: zig, regex, architecture, pikevm, nfa, bytecode, virtual machine, non-backtracking
---

# Architecture & PikeVM Engine

`regex.zig` is structured as a pipeline of modular components designed for high throughput, memory safety, and deterministic linear-time execution:

```
Pattern String
     │
     ▼
[ Parser (AST) ] ── (Validates limits: length, nesting depth, repetitions)
     │
     ▼
[ Compiler (NFA Bytecode) ] ── (Extracts literal prefixes, compiles Thompson instructions)
     │
     ▼
[ PikeVM Engine (Dual Queues) ] ── (Zero-alloc scratch buffer, lockstep byte stepping)
     │
     ▼
[ Match & Captures Result ]
```

---

## The Non-Backtracking PikeVM

Traditional backtracking engines (Perl, PCRE2, Python `re`) use recursive depth-first search. On pathological inputs, backtracking explodes exponentially: $O(2^N)$ steps.

In contrast, `regex.zig` implements Rob Pike's Virtual Machine (**PikeVM**):

1. **Breadth-First Exploration**: At each byte position in the input string, the engine steps all active NFA threads in parallel across two flat queues: `curr_queue` and `next_queue`.
2. **Duplicate Thread Pruning**: A bitset/visited array deduplicates threads reaching identical NFA states at the same byte position.
3. **Deterministic Bounds**: Each input byte is inspected at most $M$ times, where $M$ is the number of instructions in the compiled program. Total runtime is strictly bounded by $O(M \times N)$.
4. **Leftmost-First Priority**: Threads are ordered by syntactic priority. When an alternation `(a|b)` is encountered, thread `a` precedes thread `b`, matching standard Perl/POSIX regex precedence.

---

## Instruction Set Architecture

The bytecode program (`Prog`) consists of 32-bit compact instructions:

- `byte`: Matches a single ASCII or literal byte (with optional caseless flag).
- `byte_range`: Matches a contiguous byte interval `[min, max]`.
- `any_byte`: Matches any byte unconditionally.
- `any_non_nl`: Matches any byte except newline `\n`.
- `char_class`: Evaluates membership against an accelerated 256-bit bitmap or Unicode range array.
- `alt`: Forks execution into two branches (`out1`, `out2`).
- `capture_start` / `capture_end`: Records submatch span offsets into inline capture slots.
- `empty_width`: Asserts zero-width conditions (`^`, `$`, `\A`, `\z`, `\b`, `\B`).
- `match`: Signals a successful match terminal.

---

## Zero Runtime Allocation

During regex search (`re.isMatch`, `re.find`, `re.captures`), **zero heap allocations** take place:

- Thread state is maintained in a pre-allocated `Scratch` buffer sized at compile time.
- Submatch spans are recorded into an inline array of 32 capture slots (`[32]?Span`).
- Multi-threaded applications can safely match concurrently across worker threads by creating an independent scratch context via `re.createScratch(allocator)`.
