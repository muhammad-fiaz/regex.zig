---
title: Options & Limits API
description: Type declarations and default parameter values for CompileOptions, MatchOptions, Limits, and iteration settings.
keywords: zig, regex, api, options, limits, matchoptions, compileoptions, splitoptions
---

# `Options` & `Limits` API Reference

Reference for configuration types accepted across the public `regex.zig` API.

---

## `CompileOptions`

Passed to `regex.compile(allocator, pattern, options)`.

```zig
pub const CompileOptions = struct {
    caseInsensitive: bool = false,
    multiline: bool = false,
    dotAll: bool = false,
    ungreedy: bool = false,
    ascii: bool = false,
    limits: Limits = .{},
};
```

---

## `Limits`

Enforces safety boundaries to protect against memory exhaustion or ReDoS attacks.

```zig
pub const Limits = struct {
    maxPatternLength: usize = 65536,
    maxNestingDepth: usize = 256,
    maxProgramSize: usize = 65536,
    maxCaptures: usize = 128,
    maxRepetition: usize = 1000,
};
```

---

## `MatchOptions`

Passed to `re.isMatch(input, options)`, `re.find(input, options)`, `re.captures(input, options)`.

```zig
pub const MatchOptions = struct {
    startOffset: usize = 0,
};
```

---

## `FindAllOptions`

Passed to `re.findAll(allocator, input, options)` and `re.capturesAll(allocator, input, options)`.

```zig
pub const FindAllOptions = struct {
    startOffset: usize = 0,
    maxMatches: ?usize = null,
};
```

---

## `ReplaceOptions` & `ReplaceAllOptions`

```zig
pub const ReplaceOptions = struct {
    startOffset: usize = 0,
};

pub const ReplaceAllOptions = struct {
    startOffset: usize = 0,
    maxReplacements: ?usize = null,
};
```

---

## `SplitOptions`

```zig
pub const SplitOptions = struct {
    startOffset: usize = 0,
    maxSplits: ?usize = null,
};
```

---

## `CountOptions`

```zig
pub const CountOptions = struct {
    startOffset: usize = 0,
    maxMatches: ?usize = null,
};
```

---

## `IterateOptions`

```zig
pub const IterateOptions = struct {
    startOffset: usize = 0,
};
```
