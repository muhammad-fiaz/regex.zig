const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Case-insensitive matching ('i' flag) configured inline with .{}
    var case_re = try regex.compile(allocator, "zig language", .{
        .caseInsensitive = true,
    });
    defer case_re.deinit();

    std.debug.print("Caseless Match: {}\n", .{case_re.isMatch("ZIG LANGUAGE", .{})});

    // 2. Multiline matching ('m' flag) configured inline with .{}
    var line_re = try regex.compile(allocator, "^error: .+$", .{
        .multiline = true,
    });
    defer line_re.deinit();

    const log =
        \\info: compilation started
        \\error: file not found
        \\info: exiting with code 1
    ;

    var it = line_re.iterator(log, .{});
    std.debug.print("\nMultiline Errors:\n", .{});
    while (it.next()) |m| {
        std.debug.print("  {s}\n", .{m.slice});
    }

    // 3. Dot-all matching ('s' flag) configured inline with .{}
    var doc_re = try regex.compile(allocator, "/\\*.*?\\*/", .{
        .dotAll = true,
    });
    defer doc_re.deinit();

    const code =
        \\/*
        \\ * Multi-line header block
        \\ * Author: Muhammad Fiaz
        \\ */
        \\pub fn init() void {}
    ;

    if (doc_re.find(code, .{})) |doc_match| {
        std.debug.print("\nDotAll matched comment block:\n{s}\n", .{doc_match.slice});
    }
}
