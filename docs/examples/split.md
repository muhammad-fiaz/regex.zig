---
title: String Splitting & Tokenization
description: Split on delimiter patterns, limit the number of splits, preserve empty fields, and strip HTML tags.
keywords: zig, regex, split, tokenize, maxSplits, CSV, HTML
---

# String Splitting & Tokenization

Splitting uses the same streaming matcher as iteration. The pattern is the delimiter, and every piece between delimiters becomes a field. The example covers flexible delimiters, split limits, empty fields, and tag stripping.

## Run it

```bash
zig build run-example-split
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Splitting by complex delimiters: commas, semicolons, and variable whitespace
    var delim_re = try regex.compile(allocator, "[,;\\s]+", .{});
    defer delim_re.deinit();

    const csv_data = "alpha, beta;  gamma   delta,epsilon";
    const tokens = try delim_re.split(allocator, csv_data, .{});
    defer allocator.free(tokens);

    std.debug.print("Splitting '{s}' into {} tokens:\n", .{ csv_data, tokens.len });
    for (tokens, 0..) |t, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, t });
    }

    // A split limit keeps the remainder in the final field.
    const limited = try delim_re.split(allocator, csv_data, .{ .maxSplits = 2 });
    defer allocator.free(limited);

    std.debug.print("\nWith maxSplits = 2 ({} fields):\n", .{limited.len});
    for (limited, 0..) |part, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, part });
    }

    // Empty fields are preserved instead of being silently dropped.
    var comma_re = try regex.compile(allocator, ",", .{});
    defer comma_re.deinit();
    const fields = try comma_re.split(allocator, "a,,b,", .{});
    defer allocator.free(fields);

    std.debug.print("\nEmpty fields preserved ({} fields):\n", .{fields.len});
    for (fields, 0..) |field, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, field });
    }

    // Splitting by HTML tag delimiters
    var tag_re = try regex.compile(allocator, "<[^>]+>", .{});
    defer tag_re.deinit();

    const html = "<p>First paragraph</p><div>Second paragraph</div>";
    const html_parts = try tag_re.split(allocator, html, .{});
    defer allocator.free(html_parts);

    std.debug.print("\nExtracted non-tag sections:\n", .{});
    for (html_parts, 0..) |part, i| {
        if (part.len > 0) {
            std.debug.print("  [{}] '{s}'\n", .{ i + 1, part });
        }
    }
}
```

## Output

```text
Splitting 'alpha, beta;  gamma   delta,epsilon' into 5 tokens:
  [1] 'alpha'
  [2] 'beta'
  [3] 'gamma'
  [4] 'delta'
  [5] 'epsilon'

With maxSplits = 2 (2 fields):
  [1] 'alpha'
  [2] 'beta;  gamma   delta,epsilon'

Empty fields preserved (4 fields):
  [1] 'a'
  [2] ''
  [3] 'b'
  [4] ''

Extracted non-tag sections:
  [2] 'First paragraph'
  [4] 'Second paragraph'
```

## Pattern delimiters

`[,;\s]+` treats a comma, a semicolon, or a run of whitespace as one delimiter. This normalizes `alpha, beta;  gamma   delta,epsilon` into five clean tokens without a separate trimming pass.

## Limits and empty fields

With `.maxSplits = 2`, only the first delimiter is consumed and the rest of the input stays in the final field. Splitting `a,,b,` on a literal comma keeps the empty fields, yielding four entries; empty fields are preserved rather than dropped.

## Tag stripping

Using `<[^>]+>` as the delimiter removes HTML tags and leaves the text sections. Empty sections appear when adjacent tags touch, so the example filters zero-length parts before printing.

## API used

- [`split`](/api/regex#split)
- [`SplitOptions`](/api/options#splitoptions)
- [`iterator`](/api/regex#iterator-capturesiterator)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
