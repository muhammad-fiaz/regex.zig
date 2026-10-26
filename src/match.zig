const std = @import("std");

/// Half-open byte offset span [start, end) representing a matched region in the input.
pub const Span = struct {
    start: usize,
    end: usize,

    pub fn len(self: Span) usize {
        return self.end - self.start;
    }

    pub fn isEmpty(self: Span) bool {
        return self.start == self.end;
    }
};

/// A single match result containing byte offsets and a borrowed slice of the matched text.
pub const Match = struct {
    start: usize,
    end: usize,
    slice: []const u8,

    pub fn len(self: Match) usize {
        return self.end - self.start;
    }

    pub fn isEmpty(self: Match) bool {
        return self.start == self.end;
    }

    pub fn span(self: Match) Span {
        return .{ .start = self.start, .end = self.end };
    }
};

/// Captured submatch groups for a successful regular expression match.
pub const Captures = struct {
    /// Borrowed slice of original input string.
    input: []const u8,

    /// Number of capturing groups in the pattern (excluding group 0).
    capture_count: usize,

    /// Pre-allocated inline capture spans for up to 32 capture groups.
    /// Slot 0 is full match, Slot 1 is group 1, etc.
    spans: [32]?Span = @splat(null),

    /// Optional pointer to named capture lookup table.
    named_groups: ?*const std.StringHashMapUnmanaged(usize) = null,

    /// Return the matched text slice for capture group `index`.
    /// Index 0 corresponds to the entire match ($0 / $&).
    /// Returns null if the group index was not matched or does not exist.
    pub fn get(self: Captures, index: usize) ?[]const u8 {
        if (self.getSpan(index)) |sp| {
            return self.input[sp.start..sp.end];
        }
        return null;
    }

    /// Return the span [start, end) for capture group `index`.
    pub fn getSpan(self: Captures, index: usize) ?Span {
        if (index < self.spans.len) {
            return self.spans[index];
        }
        return null;
    }

    /// Return the matched text slice for named capture group `group_name`.
    pub fn name(self: Captures, group_name: []const u8) ?[]const u8 {
        if (self.nameSpan(group_name)) |sp| {
            return self.input[sp.start..sp.end];
        }
        return null;
    }

    /// Return the span for named capture group `group_name`.
    pub fn nameSpan(self: Captures, group_name: []const u8) ?Span {
        if (self.named_groups) |map| {
            if (map.get(group_name)) |idx| {
                return self.getSpan(idx);
            }
        }
        return null;
    }

    /// Total count of capturing groups in the pattern (excluding group 0).
    pub fn count(self: Captures) usize {
        return self.capture_count;
    }

    /// Span bounds of the entire match (group 0).
    pub fn bounds(self: Captures) Span {
        return self.spans[0] orelse .{ .start = 0, .end = 0 };
    }

    /// Text slice of the entire match (group 0).
    pub fn slice(self: Captures) []const u8 {
        const b = self.bounds();
        return self.input[b.start..b.end];
    }

    /// Return whether the entire match is zero-length.
    pub fn isEmpty(self: Captures) bool {
        return self.bounds().isEmpty();
    }
};

test "captures basic getters" {
    const input = "user@example.com";
    var caps = Captures{
        .input = input,
        .capture_count = 2,
    };
    caps.spans[0] = .{ .start = 0, .end = input.len };
    caps.spans[1] = .{ .start = 0, .end = 4 }; // "user"
    caps.spans[2] = .{ .start = 5, .end = 16 }; // "example.com"

    try std.testing.expectEqualStrings("user@example.com", caps.slice());
    try std.testing.expectEqualStrings("user", caps.get(1).?);
    try std.testing.expectEqualStrings("example.com", caps.get(2).?);
    try std.testing.expect(caps.get(3) == null);
}
