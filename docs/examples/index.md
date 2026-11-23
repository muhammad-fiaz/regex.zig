---
title: Runnable Examples
description: 11 self-contained runnable Zig programs covering matching, captures, replacement, splitting, Unicode, diagnostics, and safety limits.
keywords: zig, regex, examples, code samples, runnable, tutorial, captures, search, replace, split, unicode
---

# Runnable Examples

`regex.zig` ships **11 executable examples** in the
[`examples/`](https://github.com/muhammad-fiaz/regex.zig/tree/main/examples)
directory. Every page below contains the complete source, the exact console
output, and an explanation of the APIs involved.

## Run all examples

```bash
zig build run-all-examples
```

## Run one example

```bash
zig build run-example-basic
zig build run-example-captures
zig build run-example-unicode
```

The build file imports the library as the `regex` module, so each program
starts with:

```zig
const std = @import("std");
const regex = @import("regex");
```

| Example | Focus | Core APIs |
| :--- | :--- | :--- |
| [Basic matching](./basic.md) | Email checks, byte spans, escaping | `compile`, `isMatch`, `find`, `findAt`, `escape` |
| [Log scanning](./search.md) | Counting and bounded collection | `count`, `findAll`, `maxMatches` |
| [URL captures](./captures.md) | Named, numbered, and optional groups | `captures`, `capturesAll`, `nameSpan` |
| [Input validation](./validation.md) | Anchored whole-string rules | `isMatch`, anchors, alternation |
| [Replacement](./replace.md) | Templates and redaction | `replace`, `replaceAll`, `$1`, `${name}` |
| [Splitting](./split.md) | Delimiters and field limits | `split`, `maxSplits` |
| [Iteration](./iteration.md) | Lazy matching and zero-length safety | `capturesIterator`, `startOffset` |
| [Options & flags](./options.md) | Caseless, multiline, dot-all, ungreedy, ASCII | `CompileOptions`, `(?i:...)` |
| [Unicode](./unicode.md) | UTF-8, properties, folding, boundaries | `\p{...}`, `\w`, `.ascii` |
| [Error diagnostics](./errors.md) | Parser failures and locations | `Parser`, `Diagnostic` |
| [Limits & ReDoS](./limits.md) | Linear time and compile guards | `Limits`, `maxProgramSize` |

## Shared conventions

- Each program uses `std.heap.page_allocator` and prints with
  `std.debug.print` (standard error).
- Matches expose **byte** offsets. Slice the original input with
  `input[m.start..m.end]` only when those bytes form the text you expect.
- Owned results from `findAll`, `capturesAll`, `split`, `replace`, and
  `replaceAll` must be freed by the caller.
- Outputs shown on each page are deterministic except for the elapsed
  nanoseconds in the limits example.
