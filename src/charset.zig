const std = @import("std");

/// Inclusive Unicode codepoint range [min, max].
pub const Range = struct {
    min: u21,
    max: u21,

    pub fn contains(self: Range, cp: u21) bool {
        return cp >= self.min and cp <= self.max;
    }
};

/// 256-bit bitmap for O(1) ASCII byte membership checks.
pub const Bitmap256 = struct {
    bits: [4]u64 = .{ 0, 0, 0, 0 },

    pub fn initEmpty() Bitmap256 {
        return .{};
    }

    pub fn initFull() Bitmap256 {
        return .{ .bits = .{ ~@as(u64, 0), ~@as(u64, 0), ~@as(u64, 0), ~@as(u64, 0) } };
    }

    pub fn set(self: *Bitmap256, byte: u8) void {
        const word_idx = byte >> 6;
        const bit_idx: u6 = @intCast(byte & 63);
        self.bits[word_idx] |= (@as(u64, 1) << bit_idx);
    }

    pub fn clear(self: *Bitmap256, byte: u8) void {
        const word_idx = byte >> 6;
        const bit_idx: u6 = @intCast(byte & 63);
        self.bits[word_idx] &= ~(@as(u64, 1) << bit_idx);
    }

    pub fn isSet(self: Bitmap256, byte: u8) bool {
        const word_idx = byte >> 6;
        const bit_idx: u6 = @intCast(byte & 63);
        return (self.bits[word_idx] & (@as(u64, 1) << bit_idx)) != 0;
    }

    pub fn setRange(self: *Bitmap256, min: u8, max: u8) void {
        var b: usize = min;
        while (b <= max) : (b += 1) {
            self.set(@intCast(b));
        }
    }

    pub fn invert(self: *Bitmap256) void {
        self.bits[0] = ~self.bits[0];
        self.bits[1] = ~self.bits[1];
        self.bits[2] = ~self.bits[2];
        self.bits[3] = ~self.bits[3];
    }
};

/// Character class containing ranges and an accelerated ASCII bitmap.
pub const CharClass = struct {
    ranges: []const Range,
    is_negated: bool = false,
    ascii_bitmap: Bitmap256 = .{},
    has_non_ascii: bool = false,

    /// Build a character class from an array of ranges and negation flag.
    pub fn init(allocator: std.mem.Allocator, ranges: []const Range, is_negated: bool) !CharClass {
        var bitmap = Bitmap256.initEmpty();
        var non_ascii = false;

        for (ranges) |r| {
            if (r.max > 255) {
                non_ascii = true;
            }
            const low = @min(r.min, 255);
            const high = @min(r.max, 255);
            if (low <= high and r.min <= 255) {
                bitmap.setRange(@intCast(low), @intCast(high));
            }
        }

        if (is_negated) {
            bitmap.invert();
        }

        const owned_ranges = try allocator.dupe(Range, ranges);

        return CharClass{
            .ranges = owned_ranges,
            .is_negated = is_negated,
            .ascii_bitmap = bitmap,
            .has_non_ascii = non_ascii,
        };
    }

    pub fn deinit(self: *CharClass, allocator: std.mem.Allocator) void {
        allocator.free(self.ranges);
        self.* = undefined;
    }

    /// Check if a byte matches this character class.
    pub fn matchesByte(self: CharClass, byte: u8) bool {
        return self.ascii_bitmap.isSet(byte);
    }

    /// Check if a Unicode codepoint matches this character class.
    pub fn matches(self: CharClass, codepoint: u21) bool {
        if (codepoint <= 255) {
            return self.ascii_bitmap.isSet(@intCast(codepoint));
        }
        if (!self.has_non_ascii) {
            return self.is_negated;
        }

        var in_range = false;
        for (self.ranges) |r| {
            if (r.contains(codepoint)) {
                in_range = true;
                break;
            }
        }

        return if (self.is_negated) !in_range else in_range;
    }
};

/// Check if a byte is an ASCII word character [a-zA-Z0-9_].
pub fn isWordByte(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '_';
}

/// Check if a byte is ASCII whitespace [ \t\r\n\x0c\x0b].
pub fn isSpaceByte(b: u8) bool {
    return std.ascii.isWhitespace(b) or b == 0x0c or b == 0x0b;
}

/// Check if a byte is ASCII digit [0-9].
pub fn isDigitByte(b: u8) bool {
    return std.ascii.isDigit(b);
}

/// POSIX character class name matching.
pub const PosixClass = enum {
    alnum,
    alpha,
    ascii,
    blank,
    cntrl,
    digit,
    graph,
    lower,
    print,
    punct,
    space,
    upper,
    word,
    xdigit,

    pub fn fromName(name: []const u8) ?PosixClass {
        const map = std.StaticStringMap(PosixClass).initComptime(.{
            .{ "alnum", .alnum },
            .{ "alpha", .alpha },
            .{ "ascii", .ascii },
            .{ "blank", .blank },
            .{ "cntrl", .cntrl },
            .{ "digit", .digit },
            .{ "graph", .graph },
            .{ "lower", .lower },
            .{ "print", .print },
            .{ "punct", .punct },
            .{ "space", .space },
            .{ "upper", .upper },
            .{ "word", .word },
            .{ "xdigit", .xdigit },
        });
        return map.get(name);
    }

    pub fn populateBitmap(self: PosixClass, bitmap: *Bitmap256) void {
        var b: usize = 0;
        while (b < 256) : (b += 1) {
            const byte: u8 = @intCast(b);
            const matches = switch (self) {
                .alnum => std.ascii.isAlphanumeric(byte),
                .alpha => std.ascii.isAlphabetic(byte),
                .ascii => std.ascii.isAscii(byte),
                .blank => byte == ' ' or byte == '\t',
                .cntrl => std.ascii.isControl(byte),
                .digit => std.ascii.isDigit(byte),
                .graph => std.ascii.isGraphical(byte),
                .lower => std.ascii.isLower(byte),
                .print => std.ascii.isPrint(byte),
                .punct => std.ascii.isPunctuation(byte),
                .space => std.ascii.isWhitespace(byte),
                .upper => std.ascii.isUpper(byte),
                .word => isWordByte(byte),
                .xdigit => std.ascii.isHex(byte),
            };
            if (matches) {
                bitmap.set(byte);
            }
        }
    }
};

test "bitmap256 set, clear, isSet, invert" {
    var bm = Bitmap256.initEmpty();
    try std.testing.expect(!bm.isSet('a'));
    bm.set('a');
    try std.testing.expect(bm.isSet('a'));
    bm.clear('a');
    try std.testing.expect(!bm.isSet('a'));

    bm.setRange('0', '9');
    try std.testing.expect(bm.isSet('0'));
    try std.testing.expect(bm.isSet('5'));
    try std.testing.expect(bm.isSet('9'));
    try std.testing.expect(!bm.isSet('a'));

    bm.invert();
    try std.testing.expect(!bm.isSet('0'));
    try std.testing.expect(!bm.isSet('9'));
    try std.testing.expect(bm.isSet('a'));
}

test "char class matching" {
    const testing = std.testing;
    const ranges = [_]Range{
        .{ .min = 'a', .max = 'z' },
        .{ .min = '0', .max = '9' },
        .{ .min = 0x3040, .max = 0x309F }, // Hiragana
    };
    var cc = try CharClass.init(testing.allocator, &ranges, false);
    defer cc.deinit(testing.allocator);

    try testing.expect(cc.matches('a'));
    try testing.expect(cc.matches('z'));
    try testing.expect(cc.matches('5'));
    try testing.expect(!cc.matches('A'));
    try testing.expect(!cc.matches(' '));
    try testing.expect(cc.matches(0x3042)); // Japanese 'a'
    try testing.expect(!cc.matches(0x30A2)); // Katakana 'a'
}
