---
title: URL Parsing & Named Captures
description: Extract named and numbered capture groups, optional groups, spans, and all matches from a document.
keywords: zig, regex, captures, named groups, spans, capturesAll, URL
---

# URL Parsing & Named Captures

A URL pattern with named groups is used to parse a single URL, a URL without optional components, and every URL inside a longer document. The example highlights both text access and byte spans.

## Run it

```bash
zig build run-example-captures
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const url_pattern = "(?P<scheme>https?)://(?P<host>[a-zA-Z0-9.-]+)(?::(?P<port>\\d+))?(?P<path>/[a-zA-Z0-9._/~-]*)?";
    var re = try regex.compile(allocator, url_pattern, .{});
    defer re.deinit();

    const target_url = "Connecting to https://api.example.com:8443/v1/metrics for health check";
    std.debug.print("Input: {s}\n", .{target_url});
    std.debug.print("Pattern groups: {} (host index: {})\n", .{
        re.captureGroupCount(),
        re.captureGroupIndex("host") orelse 0,
    });

    if (re.captures(target_url, .{})) |caps| {
        std.debug.print("Full URL match: '{s}'\n", .{caps.slice()});
        std.debug.print("  Scheme: {s}\n", .{caps.name("scheme") orelse "none"});
        std.debug.print("  Host:   {s}\n", .{caps.name("host") orelse "none"});
        std.debug.print("  Port:   {s}\n", .{caps.name("port") orelse "default (443)"});
        std.debug.print("  Path:   {s}\n", .{caps.name("path") orelse "/"});

        std.debug.print("Numbered access:\n", .{});
        std.debug.print("  Group 1 (scheme): {s}\n", .{caps.get(1) orelse ""});
        std.debug.print("  Group 2 (host):   {s}\n", .{caps.get(2) orelse ""});
        std.debug.print("  Group 3 (port):   {s}\n", .{caps.get(3) orelse "unmatched"});
        std.debug.print("  Group 4 (path):   {s}\n", .{caps.get(4) orelse ""});

        // Exact byte index positions of the entire match and submatches
        const full_bounds = caps.bounds();
        std.debug.print("Match byte range: [{}..{}]\n", .{ full_bounds.start, full_bounds.end });

        if (caps.nameSpan("host")) |host_span| {
            std.debug.print("Host byte range:  [{}..{}] ('{s}')\n", .{
                host_span.start,
                host_span.end,
                target_url[host_span.start..host_span.end],
            });
        }
        if (caps.getSpan(1)) |scheme_span| {
            std.debug.print("Scheme byte range:[{}..{}] ('{s}')\n", .{
                scheme_span.start,
                scheme_span.end,
                target_url[scheme_span.start..scheme_span.end],
            });
        }
    }

    // Optional groups simply report null when the branch did not participate.
    if (re.captures("Mirror: http://example.org for details", .{})) |plain| {
        std.debug.print("\nPlain URL: '{s}'\n", .{plain.slice()});
        std.debug.print("  Port group: {s}\n", .{plain.get(3) orelse "none"});
        std.debug.print("  Path group: {s}\n", .{plain.get(4) orelse "none"});
    }

    // Extract captures from every URL in a longer document in one pass.
    const document = "See https://one.example.com/a and http://localhost:8080/health for status.";
    const all = try re.capturesAll(allocator, document, .{});
    defer allocator.free(all);

    std.debug.print("\nParsed {} URLs:\n", .{all.len});
    for (all, 1..) |caps, i| {
        std.debug.print("  [{}] {s}://{s} port={s} path={s}\n", .{
            i,
            caps.name("scheme") orelse "?",
            caps.name("host") orelse "?",
            caps.name("port") orelse "-",
            caps.name("path") orelse "-",
        });
    }
}
```

## Output

```text
Input: Connecting to https://api.example.com:8443/v1/metrics for health check
Pattern groups: 4 (host index: 2)
Full URL match: 'https://api.example.com:8443/v1/metrics'
  Scheme: https
  Host:   api.example.com
  Port:   8443
  Path:   /v1/metrics
Numbered access:
  Group 1 (scheme): https
  Group 2 (host):   api.example.com
  Group 3 (port):   8443
  Group 4 (path):   /v1/metrics
Match byte range: [14..53]
Host byte range:  [22..37] ('api.example.com')
Scheme byte range:[14..19] ('https')

Plain URL: 'http://example.org'
  Port group: none
  Path group: none

Parsed 2 URLs:
  [1] https://one.example.com port=- path=/a
  [2] http://localhost port=8080 path=/health
```

## Named and numbered access

Groups declared with `(?P<name>...)` are available through `caps.name("name")` and `caps.nameSpan("name")`, while numeric indices work through `caps.get(n)` and `caps.getSpan(n)`. Group `0` is the full match; `caps.slice()` and `caps.bounds()` return it directly. `captureGroupIndex("host")` reports `2`, and `captureGroupCount()` reports four groups.

## Optional groups

A group followed by `?` participates only when its text is present. For `http://example.org`, the port and path are absent, so `get(3)` and `get(4)` return `null`. Always handle `null` when a group is optional; `orelse` is a compact way to supply a fallback.

## All captures in one pass

`capturesAll` collects every non-overlapping match together with its capture slots. The example extracts the scheme, host, optional port, and optional path from two URLs and prints placeholders for absent values.

## API used

- [`captures`](/api/regex#captures)
- [`capturesAll`](/api/regex#capturesall)
- [`Captures`](/api/regex#captures-1)
- [`captureGroupCount`](/api/regex#capturegroupcount-capturegroupindex)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
