---
title: Getting Started
description: Compile expressions, verify boolean matches, and extract byte coordinate spans in minutes.
keywords: zig, regex, getting started, installation, quickstart, tutorial, usage
---

# Overview & Installation

## Key Features

- **Linear-Time Guarantee**: $O(M \times N)$ worst-case matching time, where $M$ is the compiled program size and $N$ is input length.
- **Pure Zig**: Relies strictly on the Zig standard library (`std.ascii`, `std.unicode`, `std.math`). No libc or C compiler required.
- **Explicit Ownership**: Zero hidden allocations. Matching operations reuse a lightweight thread scratch buffer.
- **Inline Options**: Standardized `.{}` inline options pattern across all configurable operations.
- **Captures & Named Groups**: Efficient extraction of submatches, including `(?P<name>...)` syntax.
- **Unicode Support**: Complete UTF-8 decoding and multi-byte case folding.

---

## Installation

Add `regex.zig` to your project's `build.zig.zon`:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .regex = .{
            .url = "https://github.com/muhammad-fiaz/regex.zig/archive/refs/tags/0.0.1.tar.gz",
            .hash = "...", // run zig build to obtain the exact package hash
        },
    },
    .paths = .{ "" },
}
```

In your `build.zig`, expose the module dependency to your executable or library:

```zig
const regex_dep = b.dependency("regex", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("regex", regex_dep.module("regex"));
```

---

## Quickstart

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Compile pattern with inline .{} options
    var re = try regex.compile(allocator, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", .{});
    defer re.deinit();

    // Fast boolean match check
    const is_valid = re.isMatch("contact@example.com", .{});
    std.debug.print("Is valid: {}\n", .{is_valid});

    // Find first match with span coordinates
    if (re.find("Send inquiries to hello@ziglang.org today.", .{})) |m| {
        std.debug.print("Found '{s}' from offset {} to {}\n", .{ m.slice, m.start, m.end });
    }
}
```
