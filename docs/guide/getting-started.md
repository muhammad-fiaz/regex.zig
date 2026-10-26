---
title: Quick Start
description: Essential regex.zig workflows for compiling patterns, checking matches, extracting captures, and string transformations.
keywords: zig, regex, quickstart, tutorial, getting started, usage, examples
---

# Quick Start

This guide demonstrates the core workflows of `regex.zig`. If you haven't installed the library yet, see the [Installation Guide](./installation.html).

---

## 1. Compile & Boolean Match

Compile a regular expression pattern and test whether an input string matches:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var re = try regex.compile(allocator, "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", .{});
    defer re.deinit();

    const is_valid = re.isMatch("contact@example.com", .{});
    std.debug.print("Is valid: {}\n", .{is_valid}); // true
}
```

---

## 2. Find Match with Byte Coordinates

Locate the first match in a string and retrieve its slice alongside starting and ending byte offsets:

```zig
const text = "Server listening on 192.168.1.100:8080";
var ip_re = try regex.compile(allocator, "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", .{});
defer ip_re.deinit();

if (ip_re.find(text, .{})) |m| {
    std.debug.print("Found IP: '{s}' at bytes {}..{}\n", .{ m.slice, m.start, m.end });
}
```

---

## 3. Extract Named Captures

Extract submatches using numbered groups or Perl-compatible named groups `(?P<name>...)`:

```zig
var url_re = try regex.compile(allocator, "(?P<host>[a-zA-Z0-9.-]+):(?P<port>\\d+)", .{});
defer url_re.deinit();

if (url_re.captures("Connect to service.internal:9092", .{})) |caps| {
    std.debug.print("Host: {s}\n", .{caps.name("host") orelse ""});
    std.debug.print("Port: {s}\n", .{caps.name("port") orelse ""});
}
```

---

## 4. Count & Replace Matches

Count occurrences without allocations, or replace occurrences using template expansion:

```zig
var tag_re = try regex.compile(allocator, "\\b\\d+\\b", .{});
defer tag_re.deinit();

// Zero-allocation match count
const total_numbers = tag_re.count("Items: 10, 20, 30", .{});
std.debug.print("Count: {}\n", .{total_numbers}); // 3

// Replace all occurrences
const masked = try tag_re.replaceAll(allocator, "Code 123 and 456", "#", .{});
defer allocator.free(masked);
std.debug.print("Masked: {s}\n", .{masked}); // "Code # and #"
```

---

## Next Steps

- Explore [All Runnable Examples](../examples/index.html) for eleven self-contained programs.
- Read the [API Reference](../api/regex.html) for detailed method signatures.
- Learn about [Architecture & PikeVM](./architecture.html) linear-time execution guarantees.
