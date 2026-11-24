---
title: Streaming Iterators & Zero-Length Safety
description: Iterate captures without allocating, stop early, resume from an offset, and progress safely across zero-length matches.
keywords: zig, regex, iterator, capturesIterator, zero-length, word boundary, streaming
---

# Streaming Iterators & Zero-Length Safety

Iterators expose matches lazily, so callers can stop early or resume from a byte offset without building a result array. A separate word-boundary pattern demonstrates safe progression past zero-length matches.

## Run it

```bash
zig build run-example-iteration
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const text = "Coordinates: x=10, y=25, z=142, w=0";

    // Iterate over key-value pairs
    var kv_re = try regex.compile(allocator, "([a-z])=(\\d+)", .{});
    defer kv_re.deinit();

    std.debug.print("Total assignments: {}\n", .{kv_re.count(text, .{})});

    var it = kv_re.capturesIterator(text, .{});
    var count: usize = 0;
    while (it.next()) |caps| {
        count += 1;
        std.debug.print("  Assignment {}: key='{s}', value={s}\n", .{
            count,
            caps.get(1) orelse "",
            caps.get(2) orelse "",
        });
    }

    // Stop early without allocating a result array.
    var early_it = kv_re.capturesIterator(text, .{});
    std.debug.print("\nFirst two assignments only:\n", .{});
    var taken: usize = 0;
    while (taken < 2) : (taken += 1) {
        const caps = early_it.next() orelse break;
        std.debug.print("  {s}={s}\n", .{ caps.get(1).?, caps.get(2).? });
    }

    // Resume iteration from a known byte offset.
    const z_offset = std.mem.indexOf(u8, text, "z=") orelse 0;
    var tail_it = kv_re.capturesIterator(text, .{ .startOffset = z_offset });
    std.debug.print("\nResuming at byte {}:\n", .{z_offset});
    while (tail_it.next()) |caps| {
        std.debug.print("  {s}={s}\n", .{ caps.get(1).?, caps.get(2).? });
    }

    // Zero-length match progression example: finding word boundaries
    std.debug.print("\n--- Zero-Length Match Safe Progression ---\n", .{});
    var boundary_re = try regex.compile(allocator, "\\b", .{});
    defer boundary_re.deinit();

    const phrase = "Zig 0.17";
    var b_it = boundary_re.iterator(phrase, .{});
    var b_count: usize = 0;
    while (b_it.next()) |m| {
        b_count += 1;
        std.debug.print("  Boundary {} at offset {}\n", .{ b_count, m.start });
    }
}
```

## Output

```text
Total assignments: 4
  Assignment 1: key='x', value=10
  Assignment 2: key='y', value=25
  Assignment 3: key='z', value=142
  Assignment 4: key='w', value=0

First two assignments only:
  x=10
  y=25

Resuming at byte 25:
  z=142
  w=0

--- Zero-Length Match Safe Progression ---
  Boundary 1 at offset 0
  Boundary 2 at offset 3
  Boundary 3 at offset 4
  Boundary 4 at offset 5
  Boundary 5 at offset 6
  Boundary 6 at offset 8
```

## Lazy capture iteration

`capturesIterator` returns one `Captures` value per call to `next()`. The first loop reads all four assignments. The second loop stops after two, which is useful when only a prefix of the input matters.

## Resuming from an offset

`.startOffset` begins the next search at a byte position. Resuming at the `z=` key skips earlier matches without copying or slicing the input.

## Zero-length match progression

`\b` matches the empty string between a word character and a non-word character. The iterator advances by one UTF-8 character after a zero-length match so it cannot loop forever. For `Zig 0.17`, the six boundaries occur at offsets 0, 3, 4, 5, 6, and 8.

## API used

- [`capturesIterator`](/api/regex#iterator-capturesiterator)
- [`iterator`](/api/regex#iterator-capturesiterator)
- [`IterateOptions`](/api/options#iterateoptions)
- [`count`](/api/regex#count)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
