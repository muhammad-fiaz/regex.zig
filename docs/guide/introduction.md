---
title: Introduction
description: Overview of architecture principles, linear-time guarantees, and capabilities of the pure Zig regex engine.
keywords: zig, regex, introduction, regular expression, pikevm, nfa, linear time, redos, submatch
---

# Introduction to regex.zig

**`regex.zig`** is a modern, high-performance, linear-time regular expression engine implemented natively in **Zig 0.17.0** from first principles.

It provides everything needed to build fast, secure, and reliable text-processing systems in Zig, including boolean matching, span coordinates, submatch captures, named groups, template replacement, string splitting, and streaming tokenization.

---

## Why regex.zig?

`regex.zig` delivers an industrial-strength, production-ready, blazing-fast regular expression engine engineered specifically for high-throughput, mission-critical systems in Zig:

1. **Guaranteed $O(M \times N)$ Linear Time & ReDoS Immunity**: Built on Rob Pike's Virtual Machine (**PikeVM**) and Thompson's NFA construction, candidate states advance in lockstep across dual thread queues. Pathological backtracking patterns reject in microseconds with zero catastrophic backtracking.
2. **100% Pure Zig 0.17.0**: Zero external dependencies, zero libc requirements, and seamless cross-compilation across Windows, Linux, and macOS on x86, x86_64, aarch64, and ARM architectures.
3. **Blazing-Fast Throughput**: SIMD-accelerated literal prefilters exceeding 2.8 GB/s bandwidth and ultra-fast boolean matching under 1.3 microseconds.
4. **Ergonomic Inline Options (`.{}`)**: Every configurable API accepts an explicit, uniform options struct with documented safe defaults.
5. **Zero Runtime Heap Allocation**: Boolean matching, span searching, and capture extraction utilize fixed, reusable scratch buffers without heap allocations during search.

---

## Core Capabilities

| Capability | Description |
| :--- | :--- |
| **Linear-Time PikeVM** | Guaranteed $O(M \times N)$ matching time. Threads advance in lockstep across dual queues with $O(1)$ state deduplication. |
| **Submatch & Named Captures** | Extract up to 32 inline capture slots with zero heap allocations during search, plus named groups `(?P&lt;name&gt;...)`. |
| **Literal Prefilter Acceleration** | Automatically extracts literal prefixes from patterns to perform fast substring searches, skipping NFA execution when the prefix does not match. |
| **Unicode & UTF-8 Support** | Multi-byte UTF-8 decoding, standard character classes (`\d`, `\w`, `\s`), POSIX bracket classes (`[:alnum:]`), and Unicode simple case-folding. |
| **Replacement Subsystem** | Replace first or all matches with template expansion supporting numbered groups (`$0`, `$1`) and named groups (`${name}`). |
| **Splitting & Tokenization** | Split input strings across arbitrary regular expression delimiters into allocated slices. |
| **Safe Streaming Iterators** | Advance past zero-length matches safely without entering infinite loops. |
| **Hardened Safety Limits** | Configurable limits (`Limits`) for pattern length, parenthesis nesting depth, repetition bounds, and bytecode instruction budgets. |

---

## High-Level Workflow

Using `regex.zig` follows a simple, robust workflow:

```
                  ┌────────────────────────┐
                  │ Pattern String: "a+b"  │
                  └───────────┬────────────┘
                              │ regex.compile(allocator, pattern, .{})
                              ▼
                  ┌────────────────────────┐
                  │ Compiled `Regex` Model │
                  │  (AST -> NFA Bytecode) │
                  └───────────┬────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
 re.isMatch(str, .{})   re.find(str, .{})   re.captures(str, .{})
  (Boolean result)       (Byte coordinates)  (Submatch & names)
```

To begin using `regex.zig` in your project, continue to the [Installation](/guide/installation) guide.
