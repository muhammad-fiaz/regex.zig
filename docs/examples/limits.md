---
title: ReDoS Defense & Custom Limits
description: Verify linear-time behavior on a pathological pattern and enforce pattern, nesting, repetition, capture, and program-size limits.
keywords: zig, regex, ReDoS, limits, PikeVM, linear time, safety, maxPatternLength
---

# ReDoS Defense & Custom Limits

The PikeVM simulates all NFA states simultaneously, so nested quantifiers cannot trigger exponential backtracking. The example measures a classic catastrophic pattern, then exercises every configurable resource limit.

## Run it

```bash
zig build run-example-limits
```

## Full example

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Defending against adversarial input with non-backtracking PikeVM
    std.debug.print("--- ReDoS Immunity Verification ---\n", .{});
    const redos_pattern = "(a+)+$";
    var re = try regex.compile(allocator, redos_pattern, .{});
    defer re.deinit();

    // An adversarial string that causes exponential catastrophe (2^30 steps) in backtracking engines:
    const adversarial = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!";

    var timer_io: std.Io.Threaded = .init_single_threaded;
    const io = timer_io.io();
    const t0 = std.Io.Clock.now(.real, io);

    const matched = re.isMatch(adversarial, .{});

    const t1 = std.Io.Clock.now(.real, io);
    const dur_ns = t0.durationTo(t1).toNanoseconds();

    std.debug.print("Pattern: '{s}' on input of {} characters\n", .{ redos_pattern, adversarial.len });
    std.debug.print("Match result: {}\n", .{matched});
    std.debug.print("Execution time: {} ns (O(N) linear time guarantee)\n\n", .{dur_ns});

    // 2. Custom safety limits to prevent memory exhaustion
    std.debug.print("--- Custom Resource Limits ---\n", .{});

    // Exceeding maximum pattern length
    const long_pattern = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const res_len = regex.compile(allocator, long_pattern, .{
        .limits = .{ .maxPatternLength = 32 },
    });
    std.debug.print("Exceeding maxPatternLength (32 bytes): {s}\n", .{
        if (res_len) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding maximum nesting depth
    const deep_pattern = "((((a))))";
    const res_nest = regex.compile(allocator, deep_pattern, .{
        .limits = .{ .maxNestingDepth = 3 },
    });
    std.debug.print("Exceeding maxNestingDepth (3 levels):   {s}\n", .{
        if (res_nest) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding repetition bound
    const big_rep = "a{100}";
    const res_rep = regex.compile(allocator, big_rep, .{
        .limits = .{ .maxRepetition = 50 },
    });
    std.debug.print("Exceeding maxRepetition (50 count):     {s}\n", .{
        if (res_rep) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding the capture-group quota
    const many_caps = "(a)(b)(c)";
    const res_caps = regex.compile(allocator, many_caps, .{
        .limits = .{ .maxCaptures = 2 },
    });
    std.debug.print("Exceeding maxCaptures (2 groups):       {s}\n", .{
        if (res_caps) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding the compiled instruction budget
    const long_literal = "abcdefghij";
    const res_prog = regex.compile(allocator, long_literal, .{
        .limits = .{ .maxProgramSize = 5 },
    });
    std.debug.print("Exceeding maxProgramSize (5 insts):     {s}\n", .{
        if (res_prog) |_| "accepted" else |err| @errorName(err),
    });

    // A generous budget accepts the same pattern.
    var ok = try regex.compile(allocator, long_literal, .{
        .limits = .{ .maxPatternLength = 64, .maxProgramSize = 128 },
    });
    defer ok.deinit();
    std.debug.print("Within generous limits:                 accepted ({})\n", .{
        ok.isMatch("xxabcdefghijyy", .{}),
    });
}
```

## Output

```text
--- ReDoS Immunity Verification ---
Pattern: '(a+)+$' on input of 31 characters
Match result: false
Execution time: 47500 ns (O(N) linear time guarantee)

--- Custom Resource Limits ---
Exceeding maxPatternLength (32 bytes): PatternTooLong
Exceeding maxNestingDepth (3 levels):   NestingTooDeep
Exceeding maxRepetition (50 count):     RepetitionLimitExceeded
Exceeding maxCaptures (2 groups):       TooManyCaptures
Exceeding maxProgramSize (5 insts):     ProgramTooLarge
Within generous limits:                 accepted (true)
```

## Linear-time pathological input

`(a+)+$` against thirty `a` characters followed by `!` is a standard backtracking catastrophe. Here the scan is bounded by the input and program sizes. The reported nanoseconds vary by machine, but the result and complexity class do not.

## Resource limits

`Limits` caps pattern length, nesting depth, compiled program size, capture-group count, and repetition bounds. Each probe uses a deliberately small limit and prints the resulting error name: `PatternTooLong`, `NestingTooDeep`, `RepetitionLimitExceeded`, `TooManyCaptures`, and `ProgramTooLarge`.

## Within budget

The final compile raises the limits and succeeds. Limits are compile-time guards: they prevent oversized programs from being built, while the PikeVM itself guarantees linear-time execution for accepted patterns.

## API used

- [`Limits`](/api/options#limits)
- [`Errors`](/api/errors)
- [`Architecture`](/guide/architecture)

## See also

- [All runnable examples](./index.md)
- [API reference](/api/options)
