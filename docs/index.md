---
layout: home
title: A Blazing-Fast, Native Regular Expression Engine for Zig | regex.zig
titleTemplate: false
description: Industrial-strength regular expression engine for Zig 0.17.0 delivering guaranteed linear-time PikeVM NFA execution, submatch extraction, UTF-8 case folding, and algorithmic ReDoS immunity without libc or external dependencies.
keywords: zig, regex, regular expressions, pikevm, nfa, linear time, redos, unicode, captures
hero:
  name: regex.zig
  text: A Blazing-Fast, Native Regular Expression Engine for Zig
  tagline: Pure Zig 0.17.0 regex engine with PikeVM non-backtracking NFA, submatch captures, streaming iteration, and ReDoS immunity.
  actions:
    - theme: brand
      text: Quick Start
      link: /guide/getting-started
    - theme: alt
      text: Installation
      link: /guide/installation
    - theme: alt
      text: Examples
      link: /examples/
    - theme: alt
      text: API Reference
      link: /api/regex
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/regex.zig

features:
  - title: Non-Backtracking PikeVM
    details: Linear-time O(M * N) worst-case execution guarantee. Immune to catastrophic backtracking and algorithmic denial-of-service (ReDoS) exploits.
  - title: Pure Zig 0.17.0
    details: Implemented entirely in native Zig using only the standard library. Zero external dependencies, no libc, and no C/C++ runtime required.
  - title: Idiomatic Inline .{} Options
    details: Clean and ergonomic Zig API where every configurable operation accepts inline .{} options with documented safe defaults.
  - title: Submatch & Named Captures
    details: Fast capture group extraction with up to 32 inline capture slots, named groups (?P&lt;name&gt;...), and zero heap allocation during search.
  - title: Literal Prefilter Acceleration
    details: Automatic literal prefix extraction and substring search acceleration bypassing full NFA exploration when possible.
  - title: Safe Streaming Iteration
    details: Streaming Iterator and CapturesIterator that safely advance past zero-length matches without getting trapped in infinite loops.
  - title: Replacement & String Splitting
    details: Replace single or all matches expanding numbered ($1) and named (${name}) groups, and split strings across custom delimiter patterns.
  - title: Unicode & Case Folding
    details: Full UTF-8 sequence decoding, ASCII character classes, POSIX classes, and Unicode simple case folding across multi-byte codepoints.
  - title: Safety & Resource Limits
    details: Configurable limits for pattern length, parenthesis nesting depth, compiled instruction count, and repetition bounds to prevent memory exhaustion.
  - title: Cross-Platform Portability
    details: Verified across Windows, Linux, and macOS on x86_64, aarch64, x86 (32-bit), and ARM architectures.
---
