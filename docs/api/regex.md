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

---

### `findAt` & `capturesAt`

```zig
pub fn findAt(self: *Regex, input: []const u8, start_pos: usize, options: MatchOptions) ?Match
pub fn capturesAt(self: *Regex, input: []const u8, start_pos: usize, options: MatchOptions) ?Captures
```

Search starting at an explicit byte offset.

---

### `captureGroupCount` & `captureGroupIndex`

```zig
pub fn captureGroupCount(self: *const Regex) usize
pub fn captureGroupIndex(self: *const Regex, name: []const u8) ?usize
```

Inspect the number of capturing groups and resolve a named group to its index.

---

### `createScratch` & `searchWithScratch`

```zig
pub fn createScratch(self: *const Regex, allocator: std.mem.Allocator) !Scratch
pub fn searchWithScratch(self: *const Regex, scratch: *Scratch, input: []const u8, start_pos: usize) ?Captures
```

Create an independent scratch context for concurrent matching across threads, then
search with it. The scratch context must be sized for this program; deinitialize it
with `scratch.deinit()` when finished.

---

## Escaping Helpers

```zig
pub fn escape(allocator: std.mem.Allocator, str: []const u8) ![]u8
pub fn escapeBuffer(buf: []u8, str: []const u8) ![]const u8
pub fn isSpecial(b: u8) bool
```

Escape regex metacharacters in user input so it can be matched literally.

---

## Result Types

### `Match`

Represents a single matched substring with its exact start and end byte offsets in the input:

```zig
pub const Match = struct {
    start: usize,
    end: usize,
    slice: []const u8,

    pub fn len(self: Match) usize;
    pub fn isEmpty(self: Match) bool;
    pub fn span(self: Match) Span;
};
```

### `Span`

Byte coordinate bounds `[start, end)` representing a match or capture region:

```zig
pub const Span = struct {
    start: usize,
    end: usize,

    pub fn len(self: Span) usize;
    pub fn isEmpty(self: Span) bool;
};
```

### `Captures`

Provides zero-allocation access to full match and submatch group slices and byte indices.
Up to 31 capturing groups are addressable (32 inline slots including the full match).

```zig
pub const Captures = struct {
    pub fn slice(self: Captures) []const u8;
    pub fn bounds(self: Captures) Span;
    pub fn get(self: Captures, index: usize) ?[]const u8;
    pub fn getSpan(self: Captures, index: usize) ?Span;
    pub fn name(self: Captures, group_name: []const u8) ?[]const u8;
    pub fn nameSpan(self: Captures, group_name: []const u8) ?Span;
    pub fn count(self: Captures) usize;
};
```
