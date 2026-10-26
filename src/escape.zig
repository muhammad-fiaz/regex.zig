const std = @import("std");

/// Returns true if byte `b` is a regex metacharacter that requires escaping in literal context.
pub fn isSpecial(b: u8) bool {
    return switch (b) {
        '\\', '.', '+', '*', '?', '(', ')', '[', ']', '{', '}', '|', '^', '$' => true,
        else => false,
    };
}

/// Escape all regex metacharacters in `str`, returning a newly allocated escaped pattern.
pub fn escape(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    var count: usize = 0;
    for (str) |b| {
        if (isSpecial(b)) count += 1;
    }
    if (count == 0) {
        return allocator.dupe(u8, str);
    }

    const out = try allocator.alloc(u8, str.len + count);
    var out_idx: usize = 0;
    for (str) |b| {
        if (isSpecial(b)) {
            out[out_idx] = '\\';
            out_idx += 1;
        }
        out[out_idx] = b;
        out_idx += 1;
    }
    return out;
}

/// Escape all regex metacharacters in `str` into `buf`. Returns error.NoSpaceLeft if buffer is too small.
pub fn escapeBuffer(buf: []u8, str: []const u8) ![]const u8 {
    var out_idx: usize = 0;
    for (str) |b| {
        if (isSpecial(b)) {
            if (out_idx >= buf.len) return error.NoSpaceLeft;
            buf[out_idx] = '\\';
            out_idx += 1;
        }
        if (out_idx >= buf.len) return error.NoSpaceLeft;
        buf[out_idx] = b;
        out_idx += 1;
    }
    return buf[0..out_idx];
}

test "escape metacharacters" {
    const testing = std.testing;
    const raw = "https://example.com/path?arg=1&val=2*3+(4)";
    const escaped = try escape(testing.allocator, raw);
    defer testing.allocator.free(escaped);

    try testing.expectEqualStrings("https://example\\.com/path\\?arg=1&val=2\\*3\\+\\(4\\)", escaped);
}

test "escapeBuffer fit and overflow" {
    const testing = std.testing;
    var buf: [64]u8 = undefined;
    const res = try escapeBuffer(&buf, "a+b*c");
    try testing.expectEqualStrings("a\\+b\\*c", res);

    var small: [3]u8 = undefined;
    try testing.expectError(error.NoSpaceLeft, escapeBuffer(&small, "a+b*c"));
}
