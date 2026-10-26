---
title: Regex API
description: Comprehensive specifications for compile, isMatch, find, findAll, captures, replace, split, and streaming iterators.
keywords: zig, regex, api, regex api, compile, ismatch, find, findall, captures, replace, split
---

# `Regex` API Reference

The primary entry point for compiling and executing regular expressions.

```zig
const regex = @import("regex");
```

---

## Top-Level Functions

### `compile`

```zig
pub fn compile(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    options: CompileOptions,
) Error!Regex
```

Compiles a regular expression pattern into bytecode. Returns an initialized `Regex` object whose memory is managed by `allocator`.

```zig
var re = try regex.compile(allocator, "^[a-zA-Z0-9_]+$", .{});
defer re.deinit();
```

---

### `isMatch` (Convenience)

```zig
pub fn isMatch(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    input: []const u8,
    options: CompileOptions,
) !bool
```

One-shot compilation and matching helper.

---

## `Regex` Methods

### `deinit`

```zig
pub fn deinit(self: *Regex) void
```

Releases all allocated memory associated with the compiled regular expression and internal scratch buffer.

---

### `isMatch`

```zig
pub fn isMatch(self: *Regex, input: []const u8, options: MatchOptions) bool
```

Returns `true` if `input` contains at least one match for the pattern.

---

### `find`

```zig
pub fn find(self: *Regex, input: []const u8, options: MatchOptions) ?Match
```

Returns the first leftmost match in `input`, or `null` if no match exists.

---

### `findAll`

```zig
pub fn findAll(
    self: *Regex,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: FindAllOptions,
) ![]Match
```

Collects all non-overlapping matches into a slice owned by `allocator`.

---

### `captures`

```zig
pub fn captures(self: *Regex, input: []const u8, options: MatchOptions) ?Captures
```

Returns the first match and its captured submatch groups.

---

### `capturesAll`

```zig
pub fn capturesAll(
    self: *Regex,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: FindAllOptions,
) ![]Captures
```

Collects all non-overlapping matches with their captures into an owned slice.

---

### `replace`

```zig
pub fn replace(
    self: *Regex,
    allocator: std.mem.Allocator,
    input: []const u8,
    replacement: []const u8,
    options: ReplaceOptions,
) ![]u8
```

Replaces the first occurrence of the pattern in `input` with `replacement`. Expands numbered groups (`$1`) and named groups (`${name}`).

---

### `replaceAll`

```zig
pub fn replaceAll(
    self: *Regex,
    allocator: std.mem.Allocator,
    input: []const u8,
    replacement: []const u8,
    options: ReplaceAllOptions,
) ![]u8
```

Replaces all non-overlapping occurrences in `input` with `replacement`.

---

### `split`

```zig
pub fn split(
    self: *Regex,
    allocator: std.mem.Allocator,
    input: []const u8,
    options: SplitOptions,
) ![][]const u8
```

Splits `input` around non-overlapping matches of the regular expression.

---

### `count`

```zig
pub fn count(self: *Regex, input: []const u8, options: CountOptions) usize
```

Returns the total count of non-overlapping matches in `input`.

---

### `iterator` & `capturesIterator`

```zig
pub fn iterator(self: *Regex, input: []const u8, options: IterateOptions) Iterator
pub fn capturesIterator(self: *Regex, input: []const u8, options: IterateOptions) CapturesIterator
```

Returns streaming forward iterators that safely advance past zero-length matches.
