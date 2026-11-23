---
title: Basic Matching & Searching
description: Compile an email pattern, test strings, inspect byte spans, resume scanning, and escape literal text.
keywords: zig, regex, basic, isMatch, find, findAt, escape, byte offsets
---

# Basic Matching & Searching

This example compiles a practical email pattern once and reuses it for three common tasks: a fast boolean check, locating the first match with byte coordinates, and escaping free-form text before treating it as a literal pattern.

## Run it

```bash
zig build run-example-basic
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const pattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";

    // Compile the regular expression with inline .{} options
    var re = try regex.compile(allocator, pattern, .{});
    defer re.deinit();

    const email1 = "dev@example.com";
    const email2 = "not-an-email";

    std.debug.print("Pattern: {s}\n", .{pattern});
    std.debug.print("Testing '{s}': {}\n", .{ email1, re.isMatch(email1, .{}) });
    std.debug.print("Testing '{s}': {}\n", .{ email2, re.isMatch(email2, .{}) });

    const text = "Contact the engineering team at support@example.com or sales@example.org for help.";
    if (re.find(text, .{})) |match| {
        std.debug.print("Found match '{s}' from byte {} to {} ({} bytes, empty: {})\n", .{
            match.slice,
            match.start,
            match.end,
            match.len(),
            match.isEmpty(),
        });

        // Continue scanning after the first match using an explicit start offset.
        if (re.findAt(text, match.end, .{})) |next| {
            std.debug.print("Next match from offset {}: '{s}' at {}..{}\n", .{
                match.end,
                next.slice,
                next.start,
                next.end,
            });
        }
    }

    // Escape user-provided text before compiling it as a literal pattern.
    const user_input = "What's the cost? $12.50 (approx.)";
    const escaped = try regex.escape(allocator, user_input);
    defer allocator.free(escaped);

    var literal_re = try regex.compile(allocator, escaped, .{});
    defer literal_re.deinit();

    std.debug.print("Escaped literal: {s}\n", .{escaped});
    std.debug.print("Literal self-match: {}\n", .{literal_re.isMatch(user_input, .{})});
    std.debug.print("Capturing groups in pattern: {}\n", .{re.captureGroupCount()});
}
```

## Output

```text
Pattern: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}
Testing 'dev@example.com': true
Testing 'not-an-email': false
Found match 'support@example.com' from byte 32 to 51 (19 bytes, empty: false)
Next match from offset 51: 'sales@example.org' at 55..72
Escaped literal: What's the cost\? \$12\.50 \(approx\.\)
Literal self-match: true
Capturing groups in pattern: 0
```

## Compile once, match many times

`regex.compile` parses the pattern and builds the PikeVM program. The returned `Regex` owns its memory, so `defer re.deinit()` is the only cleanup required. `isMatch` stops at the first successful path, which makes it the cheapest way to validate input. The pattern has no capturing parentheses, so `captureGroupCount()` reports `0`.

## Byte offsets and resuming

`find` returns a `Match` containing the matched slice plus half-open byte offsets `start` and `end`. The offsets index the original string, so `text[m.start..m.end]` is always equivalent to `m.slice`. Passing `match.end` to `findAt` continues scanning after the first result. The example finds `support@example.com` and then `sales@example.org`.

## Escaping user input

Calling `regex.escape` turns metacharacters such as `?`, `$`, `.`, and parentheses into escaped literals. Compiling the escaped string and matching the original text proves the round trip. Use `regex.escapeBuffer` when you already have a buffer and want to avoid an allocation.

## API used

- [`compile`](/api/regex#compile)
- [`isMatch`](/api/regex#ismatch)
- [`find / findAt`](/api/regex#find)
- [`escape`](/api/regex#escaping-helpers)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
