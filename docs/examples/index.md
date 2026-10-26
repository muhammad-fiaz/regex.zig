---
title: Runnable Examples
description: Eleven self-contained runnable Zig programs covering basic matching, captures, replacements, Unicode, and safety limits.
keywords: zig, regex, examples, code samples, runnable, tutorial, captures, search, replace, split
---

# Runnable Examples

`regex.zig` includes **11 executable examples** located in the [`examples/`](https://github.com/muhammad-fiaz/regex.zig/tree/main/examples) directory.

You can run all examples sequentially with:

```bash
zig build run-all-examples
```

Or run any individual example by name:

```bash
zig build run-example-basic
zig build run-example-captures
zig build run-example-replace
zig build run-example-split
zig build run-example-limits
```

---

## 1. Basic Matching & Searching (`examples/basic.zig`)

Demonstrates compiling a pattern with inline `.{}` options, testing strings for boolean matches using `re.isMatch`, and extracting the first match with byte coordinate spans using `re.find`:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const pattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";

    // Compile with inline .{} options
    var re = try regex.compile(allocator, pattern, .{});
    defer re.deinit();

    // Fast boolean match check
    std.debug.print("dev@example.com: {}\n", .{re.isMatch("dev@example.com", .{})}); // true
    std.debug.print("not-an-email:    {}\n", .{re.isMatch("not-an-email", .{})});    // false

    // Find first match with span coordinates
    const text = "Contact the engineering team at support@example.com for help.";
    if (re.find(text, .{})) |match| {
        std.debug.print("Found '{s}' from byte {} to {}\n", .{
            match.slice,
            match.start,
            match.end,
        });
    }
}
```

---

## 2. Server Log Scanning (`examples/search.zig`)

Demonstrates match counting without allocations, batch match extraction with `re.findAll`, and extracting byte coordinate index positions (`m.start`, `m.end`) to directly slice the source string:

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

    var tag_regex = try regex.compile(allocator, "\\[(INFO|WARN|ERROR)\\]", .{});
    defer tag_regex.deinit();

    // 1. Counting matches without allocating memory
    const count_all = tag_regex.count(log_data, .{});
    const count_first_two = tag_regex.count(log_data, .{ .maxMatches = 2 });
    std.debug.print("Total tags: {} (limit 2: {})\n", .{ count_all, count_first_two });

    // 2. Extracting matches with start and end byte index positions
    const matches = try tag_regex.findAll(allocator, log_data, .{});
    defer allocator.free(matches);

    for (matches, 0..) |m, i| {
        std.debug.print("Tag [{}]: '{s}' at byte offset {}..{}\n", .{ i + 1, m.slice, m.start, m.end });
    }

    // 3. Search for IP address and slice directly using byte positions
    var ip_regex = try regex.compile(allocator, "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", .{});
    defer ip_regex.deinit();

    if (ip_regex.find(log_data, .{})) |ip| {
        std.debug.print("Peer IP: {s} at byte index [{}..{}]\n", .{ ip.slice, ip.start, ip.end });
        const sliced = log_data[ip.start..ip.end];
        std.debug.print("Direct slice verified: {}\n", .{std.mem.eql(u8, ip.slice, sliced)});
    }
}
```

---

## 3. URL Parsing & Named Captures (`examples/captures.zig`)

Demonstrates extracting submatch groups using named syntax `(?P<name>...)`, positional capture indexes, and group index spans (`caps.bounds()`, `caps.getSpan()`, `caps.nameSpan()`):

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const url_pattern = "(?P<scheme>https?)://(?P<host>[a-zA-Z0-9.-]+)(?::(?P<port>\\d+))?(?P<path>/[a-zA-Z0-9._/~-]*)?";

    var re = try regex.compile(allocator, url_pattern, .{});
    defer re.deinit();

    const target_url = "Connecting to https://api.example.com:8443/v1/metrics for health check";
    if (re.captures(target_url, .{})) |caps| {
        std.debug.print("Full URL: {s}\n", .{caps.slice()});
        std.debug.print("  Scheme: {s}\n", .{caps.name("scheme") orelse "none"});
        std.debug.print("  Host:   {s}\n", .{caps.name("host") orelse "none"});
        std.debug.print("  Port:   {s}\n", .{caps.name("port") orelse "default (443)"});
        std.debug.print("  Path:   {s}\n", .{caps.name("path") orelse "/"});

        // Group byte range positions
        const full_range = caps.bounds();
        std.debug.print("Match byte range: [{}..{}]\n", .{ full_range.start, full_range.end });

        if (caps.nameSpan("host")) |host_span| {
            std.debug.print("Host byte range:  [{}..{}]\n", .{ host_span.start, host_span.end });
        }
    }
}
```

---

## 4. Input Validation (`examples/validation.zig`)

Demonstrates validating semantic version strings, hex colors, and programming language identifiers:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var semver_re = try regex.compile(allocator, "^\\d+\\.\\d+\\.\\d+$", .{});
    defer semver_re.deinit();

    std.debug.print("0.0.1:  {}\n", .{semver_re.isMatch("0.0.1", .{})});  // true
    std.debug.print("v1.0.0: {}\n", .{semver_re.isMatch("v1.0.0", .{})}); // false

    var hex_color_re = try regex.compile(allocator, "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$", .{});
    defer hex_color_re.deinit();

    std.debug.print("#FFAA00: {}\n", .{hex_color_re.isMatch("#FFAA00", .{})}); // true
}
```

---

## 5. String Replacement & Formatting (`examples/replace.zig`)

Demonstrates reformatting dates from `MM/DD/YYYY` to `YYYY-MM-DD` using numbered backreferences `$3-$1-$2` and redacting sensitive token secrets with named backreference `${key}`:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Date reformatting
    var date_re = try regex.compile(allocator, "(\\d{2})/(\\d{2})/(\\d{4})", .{});
    defer date_re.deinit();

    const text_dates = "Meeting dates: 10/26/2026, 11/04/2026, and 12/31/2026.";
    const iso_dates = try date_re.replaceAll(allocator, text_dates, "$3-$1-$2", .{});
    defer allocator.free(iso_dates);
    std.debug.print("ISO Dates: {s}\n", .{iso_dates});

    // Redacting secrets
    var secret_re = try regex.compile(allocator, "(?P<key>token|api_key|secret)=([a-zA-Z0-9_]+)", .{});
    defer secret_re.deinit();

    const config = "auth_header: token=ghp_9876543210 user=admin";
    const redacted = try secret_re.replace(allocator, config, "${key}=[REDACTED]", .{});
    defer allocator.free(redacted);
    std.debug.print("Redacted: {s}\n", .{redacted});
}
```

---

## 6. String Splitting & Tokenization (`examples/split.zig`)

Demonstrates splitting strings across complex delimiters (commas, semicolons, variable whitespace) and extracting content between HTML tags:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var delim_re = try regex.compile(allocator, "[,;\\s]+", .{});
    defer delim_re.deinit();

    const csv_data = "alpha, beta;  gamma   delta,epsilon";
    const tokens = try delim_re.split(allocator, csv_data, .{});
    defer allocator.free(tokens);

    for (tokens, 0..) |t, i| {
        std.debug.print("Token [{}]: '{s}'\n", .{ i + 1, t });
    }
}
```

---

## 7. Streaming Iterators & Zero-Length Safety (`examples/iteration.zig`)

Demonstrates zero-allocation streaming iteration over key-value pairs and safe progression past zero-length word boundaries (`\b`):

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const text = "Coordinates: x=10, y=25, z=142, w=0";

    var kv_re = try regex.compile(allocator, "([a-z])=(\\d+)", .{});
    defer kv_re.deinit();

    var it = kv_re.capturesIterator(text, .{});
    while (it.next()) |caps| {
        std.debug.print("Key: '{s}', Value: {s}\n", .{
            caps.get(1).?,
            caps.get(2).?,
        });
    }

    // Zero-length boundary progression
    var boundary_re = try regex.compile(allocator, "\\b", .{});
    defer boundary_re.deinit();

    var b_it = boundary_re.iterator("Zig 0.17", .{});
    while (b_it.next()) |m| {
        std.debug.print("Boundary at offset {}\n", .{m.start});
    }
}
```

---

## 8. Inline Options Configuration (`examples/options.zig`)

Demonstrates configuring regex compilation flags inline with `.{}`: case-insensitivity (`.caseInsensitive`), multiline matching (`.multiline`), and dot-all mode (`.dotAll`):

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Case-insensitive
    var case_re = try regex.compile(allocator, "zig language", .{
        .caseInsensitive = true,
    });
    defer case_re.deinit();
    std.debug.print("Caseless: {}\n", .{case_re.isMatch("ZIG LANGUAGE", .{})});

    // Multiline matching
    var line_re = try regex.compile(allocator, "^error: .+$", .{
        .multiline = true,
    });
    defer line_re.deinit();

    // Dot-all matching
    var doc_re = try regex.compile(allocator, "/\\*.*?\\*/", .{
        .dotAll = true,
    });
    defer doc_re.deinit();
}
```

---

## 9. Unicode & Japanese Text (`examples/unicode.zig`)

Demonstrates UTF-8 multi-byte decoding on Japanese text, currency symbols (`$`, `€`, `£`, `¥`), and Latin-1 accented characters (`café` on `CAFÉ`):

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Japanese multi-byte UTF-8 matching
    const japanese = "Language: 日本語 (にほんご) and English";
    var jp_re = try regex.compile(allocator, "にほんご", .{});
    defer jp_re.deinit();

    if (jp_re.find(japanese, .{})) |m| {
        std.debug.print("Japanese: '{s}' at {}..{}\n", .{ m.slice, m.start, m.end });
    }

    // 2. Multi-byte currency symbols
    var currency_re = try regex.compile(allocator, "(\\$|€|£|¥)[0-9]+", .{});
    defer currency_re.deinit();

    // 3. Unicode case-folding
    var accented_re = try regex.compile(allocator, "café", .{
        .caseInsensitive = true,
    });
    defer accented_re.deinit();
    std.debug.print("Accented caseless: {}\n", .{accented_re.isMatch("CAFÉ", .{})}); // true
}
```

---

## 10. Structured Error Diagnostics (`examples/errors.zig`)

Demonstrates compile-time error diagnostics with line, column, and byte offset inspection:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const invalid_pattern = "abc(def|ghi";

    var p = regex.Parser.init(allocator, invalid_pattern, .{});
    defer p.deinit();

    if (p.parse()) |_| {} else |err| {
        std.debug.print("Compilation error: {s}\n", .{@errorName(err)});
        if (p.diagnostic) |diag| {
            std.debug.print("Diagnostic at line {}, col {}: {s}\n", .{
                diag.line,
                diag.column,
                diag.message,
            });
        }
    }
}
```

---

## 11. ReDoS Defense & Custom Limits (`examples/limits.zig`)

Demonstrates linear-time ReDoS immunity on pathological patterns `(a+)+$` and enforcing custom safety limits:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Pathological nested repetition
    var re = try regex.compile(allocator, "(a+)+$", .{});
    defer re.deinit();

    const adversarial = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!";
    // Evaluates in microseconds with O(N) PikeVM execution:
    const matched = re.isMatch(adversarial, .{});
    std.debug.print("ReDoS input matched: {}\n", .{matched}); // false

    // Enforcing strict safety limits
    const compile_result = regex.compile(allocator, "((((a))))", .{
        .limits = .{ .maxNestingDepth = 3 },
    });
    // Returns error.PatternTooDeep
    if (compile_result) |_| {} else |err| {
        std.debug.print("Enforced limit error: {s}\n", .{@errorName(err)});
    }
}
```
