---
title: Structured Error Diagnostics
description: Inspect syntax and unsupported-construct errors with offsets, line/column data, categories, and messages.
keywords: zig, regex, errors, diagnostics, parser, line, column, unsupported
---

# Structured Error Diagnostics

Invalid patterns fail during parsing, before any matching occurs. This example drives the `Parser` directly so it can inspect the returned error and the populated `Diagnostic` for each failure.

## Run it

```bash
zig build run-example-errors
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

fn inspectPattern(allocator: std.mem.Allocator, pattern: []const u8) void {
    std.debug.print("Compiling: '{s}'\n", .{pattern});
    var p = regex.Parser.init(allocator, pattern, .{});
    defer p.deinit();

    var ast = p.parse() catch |err| {
        std.debug.print("  FAILED with error: {s}\n", .{@errorName(err)});
        if (p.diagnostic) |diag| {
            var buf: [256]u8 = undefined;
            const msg = diag.printBuf(&buf) catch "format error";
            std.debug.print("  Diagnostic: {s}\n", .{msg});
            std.debug.print("  Category:   {s}\n", .{@tagName(diag.category)});
            std.debug.print("  Location:   line {}, column {} (byte offset {})\n\n", .{
                diag.line,
                diag.column,
                diag.offset,
            });
        }
        return;
    };
    defer ast.deinit();

    std.debug.print("  SUCCESS (captures: {})\n\n", .{ast.capture_count});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Unclosed group
    inspectPattern(allocator, "abc(def|ghi");

    // 2. Unclosed character class
    inspectPattern(allocator, "[a-z0-9_");

    // 3. Invalid character range (z-a)
    inspectPattern(allocator, "[z-a]");

    // 4. Unsupported backreference
    inspectPattern(allocator, "(abc)\\1");

    // 5. Unsupported lookaround
    inspectPattern(allocator, "(?=prefix)value");

    // 6. Invalid bounded repetition (min greater than max)
    inspectPattern(allocator, "a{5,2}");

    // 7. Duplicate named capture group
    inspectPattern(allocator, "(?P<x>a)(?P<x>b)");

    // 8. Trailing backslash (unterminated escape)
    inspectPattern(allocator, "abc\\");

    // 9. Valid pattern
    inspectPattern(allocator, "^[a-zA-Z0-9_]+$");
}
```

## Output

```text
Compiling: 'abc(def|ghi'
  FAILED with error: UnterminatedGroup
  Diagnostic: syntax error at offset 3 (line 1, column 4): unclosed group parenthesis
  Category:   syntax
  Location:   line 1, column 4 (byte offset 3)

Compiling: '[a-z0-9_'
  FAILED with error: UnclosedCharacterClass
  Diagnostic: syntax error at offset 0 (line 1, column 1): unclosed character class bracket
  Category:   syntax
  Location:   line 1, column 1 (byte offset 0)

Compiling: '[z-a]'
  FAILED with error: InvalidCharacterRange
  Diagnostic: syntax error at offset 0 (line 1, column 1): character range start greater than end
  Category:   syntax
  Location:   line 1, column 1 (byte offset 0)

Compiling: '(abc)\1'
  FAILED with error: UnsupportedBackreference
  Diagnostic: unsupported error at offset 5 (line 1, column 6): backreferences are unsupported in linear-time v0.0.2 engine
  Category:   unsupported
  Location:   line 1, column 6 (byte offset 5)

Compiling: '(?=prefix)value'
  FAILED with error: UnsupportedLookaround
  Diagnostic: unsupported error at offset 0 (line 1, column 1): lookaround assertions are unsupported in v0.0.2
  Category:   unsupported
  Location:   line 1, column 1 (byte offset 0)

Compiling: 'a{5,2}'
  FAILED with error: InvalidRepetitionRange
  Diagnostic: syntax error at offset 1 (line 1, column 2): repetition min cannot exceed max
  Category:   syntax
  Location:   line 1, column 2 (byte offset 1)

Compiling: '(?P<x>a)(?P<x>b)'
  FAILED with error: DuplicateGroupName
  Diagnostic: syntax error at offset 8 (line 1, column 9): duplicate capture group name
  Category:   syntax
  Location:   line 1, column 9 (byte offset 8)

Compiling: 'abc\'
  FAILED with error: UnterminatedEscape
  Diagnostic: syntax error at offset 3 (line 1, column 4): dangling escape character at end of pattern
  Category:   syntax
  Location:   line 1, column 4 (byte offset 3)

Compiling: '^[a-zA-Z0-9_]+$'
  SUCCESS (captures: 0)

```

## Syntax errors

Unclosed groups, unclosed classes, reversed ranges, invalid repetition bounds, duplicate group names, and a trailing backslash all report `category = .syntax` with an offset, line, column, and message. The offset points at the byte where the parser detected the problem.

## Unsupported constructs

Backreferences and lookaround are rejected deliberately, with `category = .unsupported`. Supporting them would require backtracking and would forfeit the linear-time guarantee.

## Using diagnostics

`diag.printBuf` formats a one-line diagnostic without allocating. The raw fields are also public, so applications can build their own editor squiggles or JSON error payloads. A valid pattern parses successfully and reports its capture count.

## API used

- [`Parser`](/api/regex#top-level-functions)
- [`Diagnostic`](/api/errors#structured-diagnostic-diagnostic)
- [`Error set`](/api/errors#error-set-regexerror)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
