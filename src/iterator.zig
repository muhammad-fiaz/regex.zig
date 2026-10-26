const std = @import("std");
const match_mod = @import("match.zig");
const Match = match_mod.Match;
const Captures = match_mod.Captures;
const unicode = @import("unicode.zig");

// Forward declaration of Regex interface to avoid circular dependency
pub const MatcherFn = *const fn (ctx: *anyopaque, input: []const u8, start_pos: usize) ?Captures;

/// Streaming iterator over all successive non-overlapping matches in an input string.
pub const Iterator = struct {
    ctx: *anyopaque,
    matcher: MatcherFn,
    input: []const u8,
    pos: usize = 0,
    last_zero_len: bool = false,

    pub fn init(ctx: *anyopaque, matcher: MatcherFn, input: []const u8, start_pos: usize) Iterator {
        return .{
            .ctx = ctx,
            .matcher = matcher,
            .input = input,
            .pos = start_pos,
            .last_zero_len = false,
        };
    }

    /// Advance to the next match. Correctly progresses past zero-length matches
    /// without entering an infinite loop.
    pub fn next(self: *Iterator) ?Match {
        if (self.pos > self.input.len) return null;

        if (self.last_zero_len) {
            if (self.pos >= self.input.len) return null;
            const seq_len = unicode.utf8SequenceLength(self.input[self.pos]);
            self.pos += @min(seq_len, self.input.len - self.pos);
            self.last_zero_len = false;
            if (self.pos > self.input.len) return null;
        }

        const caps_opt = self.matcher(self.ctx, self.input, self.pos);
        if (caps_opt) |caps| {
            const b = caps.bounds();
            const m = Match{
                .start = b.start,
                .end = b.end,
                .slice = caps.slice(),
            };

            if (m.isEmpty()) {
                self.last_zero_len = true;
                self.pos = m.end;
            } else {
                self.pos = m.end;
                self.last_zero_len = false;
            }
            return m;
        }

        self.pos = self.input.len + 1;
        return null;
    }
};

/// Streaming iterator over all successive matches and their capture groups.
pub const CapturesIterator = struct {
    ctx: *anyopaque,
    matcher: MatcherFn,
    input: []const u8,
    pos: usize = 0,
    last_zero_len: bool = false,

    pub fn init(ctx: *anyopaque, matcher: MatcherFn, input: []const u8, start_pos: usize) CapturesIterator {
        return .{
            .ctx = ctx,
            .matcher = matcher,
            .input = input,
            .pos = start_pos,
            .last_zero_len = false,
        };
    }

    pub fn next(self: *CapturesIterator) ?Captures {
        if (self.pos > self.input.len) return null;

        if (self.last_zero_len) {
            if (self.pos >= self.input.len) return null;
            const seq_len = unicode.utf8SequenceLength(self.input[self.pos]);
            self.pos += @min(seq_len, self.input.len - self.pos);
            self.last_zero_len = false;
            if (self.pos > self.input.len) return null;
        }

        const caps_opt = self.matcher(self.ctx, self.input, self.pos);
        if (caps_opt) |caps| {
            if (caps.isEmpty()) {
                self.last_zero_len = true;
                self.pos = caps.bounds().end;
            } else {
                self.pos = caps.bounds().end;
                self.last_zero_len = false;
            }
            return caps;
        }

        self.pos = self.input.len + 1;
        return null;
    }
};

test "iterator dummy progression" {
    const Dummy = struct {
        pub fn matchFn(ctx: *anyopaque, input: []const u8, start_pos: usize) ?Captures {
            _ = ctx;
            if (start_pos < input.len) {
                var c = Captures{ .input = input, .capture_count = 0 };
                c.spans[0] = .{ .start = start_pos, .end = start_pos + 1 };
                return c;
            }
            return null;
        }
    };

    var dummy_val: u8 = 0;
    var it = Iterator.init(&dummy_val, Dummy.matchFn, "abc", 0);
    const m1 = it.next().?;
    try std.testing.expectEqualStrings("a", m1.slice);
    const m2 = it.next().?;
    try std.testing.expectEqualStrings("b", m2.slice);
    const m3 = it.next().?;
    try std.testing.expectEqualStrings("c", m3.slice);
    try std.testing.expect(it.next() == null);
}
