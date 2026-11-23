---
title: Input Validation
description: Validate semantic versions, hex colors, identifiers, IPv4 addresses, and URL slugs with anchored patterns.
keywords: zig, regex, validation, semver, hex color, identifier, IPv4, slug
---

# Input Validation

Five validation rules demonstrate anchored matching, alternation, bounded repetition, non-capturing groups, and the importance of `^` and `$` when the whole input must match.

## Run it

```bash
zig build run-example-validation
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Semantic version validation (e.g. 1.2.3 or 0.0.2)
    var semver_re = try regex.compile(allocator, "^\\d+\\.\\d+\\.\\d+$", .{});
    defer semver_re.deinit();

    const versions = [_][]const u8{ "0.0.2", "1.2.3", "v1.0.0", "1.2", "1.2.3.4" };
    std.debug.print("--- Semantic Version Validation ---\n", .{});
    for (versions) |v| {
        std.debug.print("  {s:<10} => {}\n", .{ v, semver_re.isMatch(v, .{}) });
    }

    // Hex color code validation (#RGB or #RRGGBB)
    var hex_color_re = try regex.compile(allocator, "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$", .{});
    defer hex_color_re.deinit();

    const colors = [_][]const u8{ "#fff", "#FFAA00", "#123456", "#abcd", "123456" };
    std.debug.print("\n--- Hex Color Validation ---\n", .{});
    for (colors) |c| {
        std.debug.print("  {s:<10} => {}\n", .{ c, hex_color_re.isMatch(c, .{}) });
    }

    // C/Zig identifier validation
    var ident_re = try regex.compile(allocator, "^[a-zA-Z_][a-zA-Z0-9_]*$", .{});
    defer ident_re.deinit();

    const idents = [_][]const u8{ "my_variable", "_init123", "123invalid", "kebab-case" };
    std.debug.print("\n--- Identifier Validation ---\n", .{});
    for (idents) |id| {
        std.debug.print("  {s:<15} => {}\n", .{ id, ident_re.isMatch(id, .{}) });
    }

    // IPv4 addresses constrain each octet to 0-255 and reuse a non-capturing group.
    var ipv4_re = try regex.compile(allocator, "^(?:(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1\\d\\d|[1-9]?\\d)$", .{});
    defer ipv4_re.deinit();

    const addresses = [_][]const u8{ "192.168.1.50", "255.255.255.255", "10.0.0.256", "1.2.3" };
    std.debug.print("\n--- IPv4 Validation ---\n", .{});
    for (addresses) |addr| {
        std.debug.print("  {s:<18} => {}\n", .{ addr, ipv4_re.isMatch(addr, .{}) });
    }

    // URL slugs use repeated hyphen-separated alphanumeric segments.
    var slug_re = try regex.compile(allocator, "^[a-z0-9]+(?:-[a-z0-9]+)*$", .{});
    defer slug_re.deinit();

    const slugs = [_][]const u8{ "regex-engine", "v0-0-2", "Double--Dash", "-leading" };
    std.debug.print("\n--- URL Slug Validation ---\n", .{});
    for (slugs) |slug| {
        std.debug.print("  {s:<15} => {}\n", .{ slug, slug_re.isMatch(slug, .{}) });
    }
}
```

## Output

```text
--- Semantic Version Validation ---
  0.0.2      => true
  1.2.3      => true
  v1.0.0     => false
  1.2        => false
  1.2.3.4    => false

--- Hex Color Validation ---
  #fff       => true
  #FFAA00    => true
  #123456    => true
  #abcd      => false
  123456     => false

--- Identifier Validation ---
  my_variable     => true
  _init123        => true
  123invalid      => false
  kebab-case      => false

--- IPv4 Validation ---
  192.168.1.50       => true
  255.255.255.255    => true
  10.0.0.256         => false
  1.2.3              => false

--- URL Slug Validation ---
  regex-engine    => true
  v0-0-2          => true
  Double--Dash    => false
  -leading        => false
```

## Anchor the whole input

`\d+\.\d+\.\d+` alone would accept `1.2.3.4`. Adding `^` and `$` requires the match to cover the entire string. This distinction is why every validation pattern in the example is anchored; `isMatch` otherwise succeeds on any substring.

## Alternation and grouping

The hex color pattern uses `([0-9a-fA-F]{3}|[0-9a-fA-F]{6})` so the alternation is constrained by the anchors. The IPv4 pattern reuses a non-capturing `(?:...)` octet group with `{3}`, then appends one final octet without a trailing dot.

## Captures are optional for validation

Validation only needs a boolean, so the IPv4 and slug patterns use non-capturing groups and do not touch capture slots. Compile each rule once, then reuse it across the table of candidate strings.

## API used

- [`isMatch`](/api/regex#ismatch)
- [`compile`](/api/regex#compile)
- [`Syntax reference`](/guide/syntax)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/regex)
