---
title: Inline Options & Limits
description: Overview of anonymous struct literal configurations, compilation flags, execution parameters, and memory safety limits.
keywords: zig, regex, options, limits, inline options, configuration, redos defense
---

# Inline Options & Safety Limits

In `regex.zig`, every configurable operation accepts its options as the final argument using Zig's anonymous struct literal syntax (`.{}`).

Omitted fields receive documented safe defaults through Zig struct field initializers.

---

## Compilation Options (`CompileOptions`)

```zig
pub const CompileOptions = struct {
    /// Case-insensitive matching ('i' flag).
    caseInsensitive: bool = false,

    /// Multiline mode ('m' flag): '^' and '$' match at line boundaries ('\n').
    multiline: bool = false,

    /// Dot-all mode ('s' flag): '.' matches any character including newline '\n'.
    dotAll: bool = false,

    /// Inverts the greediness of quantifiers ('U' flag).
    ungreedy: bool = false,

    /// Restrict shorthand classes (\d, \w, \s) and boundaries to ASCII.
    ascii: bool = false,

    /// Safety and memory resource limits.
    limits: Limits = .{},
};
```

### Usage Example

```zig
// Default options
var re = try regex.compile(allocator, "\\d+", .{});
defer re.deinit();

// Inline custom configuration
var custom_re = try regex.compile(allocator, "^[a-z]+$", .{
    .caseInsensitive = true,
    .multiline = true,
});
defer custom_re.deinit();
```

---

## Safety Limits (`Limits`)

To protect server processes against memory exhaustion or malicious patterns, `regex.zig` enforces strict compile-time limits:

```zig
pub const Limits = struct {
    /// Maximum allowed pattern length in bytes (default: 65,536).
    maxPatternLength: usize = 65536,

    /// Maximum group/parenthesis nesting depth (default: 256).
    maxNestingDepth: usize = 256,

    /// Maximum compiled instruction count in the bytecode program (default: 65,536).
    maxProgramSize: usize = 65536,

    /// Maximum number of capturing groups allowed (default: 128).
    maxCaptures: usize = 128,

    /// Maximum repetition count in bounded repetitions {min,max} (default: 1,000).
    maxRepetition: usize = 1000,
};
```

### Configuring Tight Limits

```zig
var restricted_re = try regex.compile(allocator, user_supplied_pattern, .{
    .limits = .{
        .maxPatternLength = 1024,
        .maxNestingDepth = 16,
        .maxRepetition = 100,
    },
});
defer restricted_re.deinit();
```

If user input exceeds any limit, compilation returns a typed error:
- `error.PatternTooLong`
- `error.NestingTooDeep`
- `error.ProgramTooLarge`
- `error.TooManyCaptures`
- `error.RepetitionLimitExceeded`

---

## Execution Options

| Operation | Option Type | Configurable Fields |
| :--- | :--- | :--- |
| `isMatch`, `find`, `captures` | `MatchOptions` | `startOffset: usize = 0` |
| `findAll`, `capturesAll` | `FindAllOptions` | `startOffset: usize = 0`, `maxMatches: ?usize = null` |
| `replace` | `ReplaceOptions` | `startOffset: usize = 0` |
| `replaceAll` | `ReplaceAllOptions` | `startOffset: usize = 0`, `maxReplacements: ?usize = null` |
| `split` | `SplitOptions` | `startOffset: usize = 0`, `maxSplits: ?usize = null` |
| `count` | `CountOptions` | `startOffset: usize = 0`, `maxMatches: ?usize = null` |
| `iterator`, `capturesIterator` | `IterateOptions` | `startOffset: usize = 0` |
