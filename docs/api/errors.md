---
title: Errors & Diagnostics
description: Error set definitions, structured syntax diagnostic fields, and error category classifications for debugging regexes.
keywords: zig, regex, api, errors, diagnostics, error set, errorcategory
---

# Errors & Diagnostics API Reference

`regex.zig` returns typed Zig error unions and provides structured syntax diagnostics including exact line, column, and byte offset locations.

---

## Error Set (`regex.Error`)

```zig
pub const Error = error{
    // Syntax errors
    UnexpectedEnd,
    UnterminatedGroup,
    UnclosedCharacterClass,
    InvalidCharacterRange,
    InvalidQuantifier,
    InvalidRepetitionRange,
    EmptyRepetition,
    InvalidEscapeSequence,
    UnterminatedEscape,
    InvalidGroupName,

    // Safety and resource limits
    PatternTooLong,
    NestingTooDeep,
    ProgramTooLarge,
    TooManyCaptures,
    RepetitionLimitExceeded,

    // Unsupported dialect constructs
    UnsupportedBackreference,
    UnsupportedLookaround,

    // Memory
    OutOfMemory,
};
```

---

## Structured Diagnostic (`Diagnostic`)

When parsing fails, `Parser.diagnostic` contains detailed diagnostic information:

```zig
pub const Diagnostic = struct {
    err: Error,
    category: ErrorCategory,
    offset: usize,
    line: usize,
    column: usize,
    message: []const u8,

    pub fn printBuf(self: Diagnostic, buf: []u8) ![]const u8
};
```

### `ErrorCategory`

```zig
pub const ErrorCategory = enum {
    syntax,
    limit,
    unsupported,
    internal,
};
```

### Example: Inspecting Diagnostics

```zig
var p = regex.Parser.init(allocator, "abc(def", .{});
defer p.deinit();

const ast = p.parse() catch |err| {
    if (p.diagnostic) |diag| {
        std.debug.print("Parse failed: {s} at line {}, col {}\n", .{
            diag.message,
            diag.line,
            diag.column,
        });
    }
    return err;
};
```
