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

    // 4. Inline flags embedded in the pattern itself
    var inline_re = try regex.compile(allocator, "(?i)zig (?-i)LANGUAGE", .{});
    defer inline_re.deinit();
    std.debug.print("\nInline (?i)zig (?-i)LANGUAGE on 'ZIG LANGUAGE': {}\n", .{
        inline_re.isMatch("ZIG LANGUAGE", .{}),
    });

    // Scoped flag group: (?i:...) applies only inside the group
    var scoped_re = try regex.compile(allocator, "(?i:abc)def", .{});
    defer scoped_re.deinit();
    std.debug.print("Scoped (?i:abc)def on 'ABCdef': {} / on 'ABCDEF': {}\n", .{
        scoped_re.isMatch("ABCdef", .{}),
        scoped_re.isMatch("ABCDEF", .{}),
    });

    // 5. Greedy vs ungreedy quantifiers.
    const markup = "<b>bold</b> and <i>italic</i>";
    var greedy_re = try regex.compile(allocator, "<.+>", .{});
    defer greedy_re.deinit();
    var ungreedy_re = try regex.compile(allocator, "<.+>", .{ .ungreedy = true });
    defer ungreedy_re.deinit();

    const greedy = greedy_re.find(markup, .{}).?;
    const ungreedy = ungreedy_re.find(markup, .{}).?;
    std.debug.print("\nGreedy '<.+>':    '{s}'\n", .{greedy.slice});
    std.debug.print("Ungreedy '<.+>':  '{s}'\n", .{ungreedy.slice});

    // The same inversion can be requested inline with (?U).
    var inline_ungreedy = try regex.compile(allocator, "(?U)<.+>", .{});
    defer inline_ungreedy.deinit();
    std.debug.print("Inline (?U)<.+>:  '{s}'\n", .{inline_ungreedy.find(markup, .{}).?.slice});

    // 6. ASCII mode restricts \w and \b to ASCII characters.
    // Anchoring forces the whole word to match, exposing the difference.
    var uni_word = try regex.compile(allocator, "^\\w+$", .{});
    defer uni_word.deinit();
    var ascii_word = try regex.compile(allocator, "^\\w+$", .{ .ascii = true });
    defer ascii_word.deinit();
    std.debug.print("\n^\\w+$ matches 'naïve': Unicode={} / ASCII={}\n", .{
        uni_word.isMatch("naïve", .{}),
        ascii_word.isMatch("naïve", .{}),
    });
}
