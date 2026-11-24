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
                const first_idx: usize = next_c - '0';
                // Prefer a two-digit group when it exists, otherwise keep the
                // second digit as literal text (`$10` → group 1 + "0").
                if (i + 2 < replacement.len and std.ascii.isDigit(replacement[i + 2])) {
                    const two_idx = first_idx * 10 + (replacement[i + 2] - '0');
                    if (captures.get(two_idx)) |text| {
                        try out.appendSlice(allocator, text);
                        i += 3;
                        seg_start = i;
                        continue;
                    }
                }
                if (captures.get(first_idx)) |text| {
                    try out.appendSlice(allocator, text);
                }
                i += 2;
                seg_start = i;
                continue;
            } else if (next_c == '{' or next_c == '<') {
                const close_char: u8 = if (next_c == '{') '}' else '>';
                const start = i + 2;
                var end = start;
                while (end < replacement.len and replacement[end] != close_char) : (end += 1) {}
                if (end < replacement.len) {
                    const name = replacement[start..end];
                    if (name.len == 0) {
                        // `${}` / `$<>` are not valid references; keep them literal.
                        try out.appendSlice(allocator, replacement[i .. end + 1]);
                    } else if (std.ascii.isDigit(name[0])) {
                        // ${1} numeric form: use the leading digits and keep
                        // any trailing text literal (e.g. `${1}x`).
                        var idx: usize = 0;
                        var digit_count: usize = 0;
                        while (digit_count < name.len and std.ascii.isDigit(name[digit_count])) : (digit_count += 1) {
                            idx = idx * 10 + (name[digit_count] - '0');
                        }
                        if (captures.get(idx)) |text| {
                            try out.appendSlice(allocator, text);
                        }
                        try out.appendSlice(allocator, name[digit_count..]);
                    } else if (captures.name(name)) |text| {
                        try out.appendSlice(allocator, text);
                    }
                    i = end + 1;
                    seg_start = i;
                    continue;
                }
            } else if (next_c == '`' or next_c == '\'') {
                // Perl-style pre-match / post-match tokens.
                const bounds = captures.bounds();
                if (next_c == '`') {
                    try out.appendSlice(allocator, captures.input[0..bounds.start]);
                } else {
                    try out.appendSlice(allocator, captures.input[bounds.end..]);
                }
                i += 2;
                seg_start = i;
                continue;
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

test "expand replacement fallbacks and literals" {
    const testing = std.testing;
    const input = "abc";
    var caps = Captures{ .input = input, .capture_count = 1 };
    caps.spans[0] = .{ .start = 0, .end = 1 };
    caps.spans[1] = .{ .start = 0, .end = 1 }; // "a"

    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(testing.allocator);

    // Two-digit reference falls back to one digit plus literal text.
    try expandReplacement(testing.allocator, "$10", caps, &out);
    try testing.expectEqualStrings("a0", out.items);

    out.clearRetainingCapacity();
    try expandReplacement(testing.allocator, "${1}x${}&", caps, &out);
    try testing.expectEqualStrings("ax${}&", out.items);

    out.clearRetainingCapacity();
    try expandReplacement(testing.allocator, "$`|$'", caps, &out);
    try testing.expectEqualStrings("|bc", out.items);

    out.clearRetainingCapacity();
    try expandReplacement(testing.allocator, "price: $$1", caps, &out);
    try testing.expectEqualStrings("price: $1", out.items);
}
