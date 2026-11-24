---
title: Server Log Scanning
description: Count matches without allocating, collect bounded results, slice source text by byte offsets, and resume scanning.
keywords: zig, regex, search, count, findAll, maxMatches, startOffset, logs
---

# Server Log Scanning

A small server log is scanned for severity tags and an IPv4 address. The example shows the trade-off between allocation-free counting, bounded result collection, and offset-based scanning.

## Run it

```bash
zig build run-example-search
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const log_data =
        \\2026-10-26 12:00:01 [INFO] Server started on port 8080
        \\2026-10-26 12:00:05 [WARN] High memory usage: 85%
        \\2026-10-26 12:00:10 [ERROR] Connection reset by peer: 192.168.1.50
    ;

    // Find all log severity tags [INFO], [WARN], [ERROR]
    var tag_regex = try regex.compile(allocator, "\\[(INFO|WARN|ERROR)\\]", .{});
    defer tag_regex.deinit();

    // 1. Count occurrences without allocating heap memory
    const total_tags = tag_regex.count(log_data, .{});
    const first_two_tags = tag_regex.count(log_data, .{ .maxMatches = 2 });
    std.debug.print("Counted severity tags: {} (limit 2: {})\n", .{ total_tags, first_two_tags });

    // 2. Extract every match with start and end byte index positions
    const matches = try tag_regex.findAll(allocator, log_data, .{});
    defer allocator.free(matches);

    std.debug.print("Found {} severity tags:\n", .{matches.len});
    for (matches, 0..) |m, i| {
        std.debug.print("  [{}] '{s}' at byte offset {}..{}\n", .{
            i + 1,
            m.slice,
            m.start,
            m.end,
        });
    }

    // 3. Collect only the first two matches with a bounded query
    const limited = try tag_regex.findAll(allocator, log_data, .{ .maxMatches = 2 });
    defer allocator.free(limited);

    std.debug.print("Limited query returned {} tags:", .{limited.len});
    for (limited) |m| std.debug.print(" {s}", .{m.slice});
    std.debug.print("\n", .{});

    // 4. Search for an IP address and verify byte indices by slicing the source directly
    var ip_regex = try regex.compile(allocator, "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", .{});
    defer ip_regex.deinit();

    if (ip_regex.find(log_data, .{})) |ip_match| {
        std.debug.print("Detected peer IP: {s} at byte index [{}..{}]\n", .{
            ip_match.slice,
            ip_match.start,
            ip_match.end,
        });
        // Direct source slicing using returned index positions
        const sliced = log_data[ip_match.start..ip_match.end];
        std.debug.print("Direct slice from indices: '{s}' (verified: {})\n", .{
            sliced,
            std.mem.eql(u8, ip_match.slice, sliced),
        });
    }

    // 5. Resume scanning from a byte offset (useful for paginated chunks)
    const second_half_offset = (log_data.len / 2);
    if (tag_regex.find(log_data, .{ .startOffset = second_half_offset })) |tail_match| {
        std.debug.print("First tag after byte {}: '{s}'\n", .{
            second_half_offset,
            tail_match.slice,
        });
    }
}
```

## Output

```text
Counted severity tags: 3 (limit 2: 2)
Found 3 severity tags:
  [1] '[INFO]' at byte offset 20..26
  [2] '[WARN]' at byte offset 75..81
  [3] '[ERROR]' at byte offset 125..132
Limited query returned 2 tags: [INFO] [WARN]
Detected peer IP: 192.168.1.50 at byte index [159..171]
Direct slice from indices: '192.168.1.50' (verified: true)
First tag after byte 85: '[ERROR]'
```

## Counting without allocations

`count` advances the same streaming iterator used by `findAll`, but never stores matches. `maxMatches` turns it into an early-exit probe: the second count stops after two tags.

## Collecting matches and bounding work

`findAll` returns an owned slice of `Match` values. Free it with the allocator that produced it. Passing `.maxMatches = 2` returns only the first two tags, which is useful for previews or quota-limited jobs.

## Byte offsets are source indices

Every match carries `start` and `end` byte offsets. The example slices the log directly and compares the result with `m.slice`, then uses `.startOffset` to start a new search halfway through the log. Offsets are byte-based, not character-based, so they remain correct for UTF-8 input.

## API used

- [`count`](/api/regex#count)
- [`findAll`](/api/regex#findall)
- [`find`](/api/regex#find)
- [`FindAllOptions`](/api/options#findalloptions)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
