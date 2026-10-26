const std = @import("std");
const match_mod = @import("match.zig");
const Match = match_mod.Match;
const Captures = match_mod.Captures;

pub fn expandReplacement(
    allocator: std.mem.Allocator,
    replacement: []const u8,
    captures: Captures,
    out: *std.ArrayList(u8),
) !void {
    // Fast-path: no template dollar sign in replacement string
    if (std.mem.indexOfScalar(u8, replacement, '$') == null) {
        try out.appendSlice(allocator, replacement);
        return;
    }

    var i: usize = 0;
    var seg_start: usize = 0;

    while (i < replacement.len) {
        if (replacement[i] == '$' and i + 1 < replacement.len) {
            // Flush preceding literal segment
            if (i > seg_start) {
                try out.appendSlice(allocator, replacement[seg_start..i]);
            }

            const next_c = replacement[i + 1];
            if (next_c == '$') {
                try out.append(allocator, '$');
                i += 2;
                seg_start = i;
                continue;
            } else if (next_c == '0' or next_c == '&') {
                try out.appendSlice(allocator, captures.slice());
                i += 2;
                seg_start = i;
                continue;
            } else if (std.ascii.isDigit(next_c)) {
                var group_idx: usize = next_c - '0';
                i += 2;
                if (i < replacement.len and std.ascii.isDigit(replacement[i])) {
                    group_idx = group_idx * 10 + (replacement[i] - '0');
                    i += 1;
                }
                if (captures.get(group_idx)) |text| {
                    try out.appendSlice(allocator, text);
                }
                seg_start = i;
                continue;
            } else if (next_c == '{' or next_c == '<') {
                const close_char: u8 = if (next_c == '{') '}' else '>';
                const start = i + 2;
                var end = start;
                while (end < replacement.len and replacement[end] != close_char) : (end += 1) {}
                if (end < replacement.len) {
                    const name = replacement[start..end];
                    if (captures.name(name)) |text| {
                        try out.appendSlice(allocator, text);
                    }
                    i = end + 1;
                    seg_start = i;
                    continue;
                }
            }
        }

        i += 1;
    }

    // Flush any trailing segment
    if (i > seg_start) {
        try out.appendSlice(allocator, replacement[seg_start..i]);
    }
}

test "expand replacement numbered and named" {
    const testing = std.testing;
    const input = "user=admin;id=42";
    var caps = Captures{
        .input = input,
        .capture_count = 2,
    };
    caps.spans[0] = .{ .start = 0, .end = input.len };
    caps.spans[1] = .{ .start = 5, .end = 10 }; // "admin"
    caps.spans[2] = .{ .start = 14, .end = 16 }; // "42"

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);

    try expandReplacement(testing.allocator, "Name: $1 (ID: $2, Price: $$100)", caps, &out);
    try testing.expectEqualStrings("Name: admin (ID: 42, Price: $100)", out.items);
}

test "expand replacement literal fast-path" {
    const testing = std.testing;
    const input = "test";
    var caps = Captures{ .input = input, .capture_count = 0 };
    caps.spans[0] = .{ .start = 0, .end = 4 };

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);

    try expandReplacement(testing.allocator, "replaced", caps, &out);
    try testing.expectEqualStrings("replaced", out.items);
}
