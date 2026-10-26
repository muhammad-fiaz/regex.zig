const std = @import("std");

/// Decoded Unicode codepoint and its UTF-8 byte length.
pub const DecodedChar = struct {
    cp: u21,
    len: u3,
};

/// Return expected UTF-8 sequence byte length from the initial lead byte.
pub fn utf8SequenceLength(lead: u8) u3 {
    return std.unicode.utf8ByteSequenceLength(lead) catch 1;
}

/// Decode the first UTF-8 codepoint from `bytes`. Returns null if empty or invalid.
pub fn decodeUtf8Char(bytes: []const u8) ?DecodedChar {
    if (bytes.len == 0) return null;
    const len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch return null;
    if (bytes.len < len) return null;
    const cp = std.unicode.utf8Decode(bytes[0..len]) catch return null;
    return .{ .cp = cp, .len = len };
}

/// Convert an ASCII byte to lowercase using std.ascii.toLower.
pub const toLowerAscii = std.ascii.toLower;

/// Convert an ASCII byte to uppercase using std.ascii.toUpper.
pub const toUpperAscii = std.ascii.toUpper;

/// Compare two bytes for case-insensitive equality using std.ascii.
pub fn eqlByteCaseless(a: u8, b: u8) bool {
    return std.ascii.toLower(a) == std.ascii.toLower(b);
}

/// Simple Unicode case fold mapping for codepoints.
pub fn simpleCaseFold(cp: u21) u21 {
    if (cp <= 127) {
        return std.ascii.toLower(@intCast(cp));
    }
    // Latin-1 Supplement common folding
    if (cp >= 0x00C0 and cp <= 0x00D6) return cp + 32;
    if (cp >= 0x00D8 and cp <= 0x00DE) return cp + 32;
    // Greek uppercase to lowercase
    if (cp >= 0x0391 and cp <= 0x03A1) return cp + 32;
    if (cp >= 0x03A3 and cp <= 0x03AB) return cp + 32;
    // Cyrillic uppercase to lowercase
    if (cp >= 0x0410 and cp <= 0x042F) return cp + 32;
    return cp;
}

/// Return the opposite case counterpart for codepoint `cp` if one exists.
pub fn toOtherCase(cp: u21) ?u21 {
    if (cp <= 127) {
        const b: u8 = @intCast(cp);
        if (std.ascii.isLower(b)) return std.ascii.toUpper(b);
        if (std.ascii.isUpper(b)) return std.ascii.toLower(b);
        return null;
    }
    // Latin-1 Supplement: uppercase to lowercase
    if (cp >= 0x00C0 and cp <= 0x00D6) return cp + 32;
    if (cp >= 0x00D8 and cp <= 0x00DE) return cp + 32;
    // Latin-1 Supplement: lowercase to uppercase
    if (cp >= 0x00E0 and cp <= 0x00F6) return cp - 32;
    if (cp >= 0x00F8 and cp <= 0x00FE) return cp - 32;
    // Greek
    if (cp >= 0x0391 and cp <= 0x03A1) return cp + 32;
    if (cp >= 0x03A3 and cp <= 0x03AB) return cp + 32;
    if (cp >= 0x03B1 and cp <= 0x03C1) return cp - 32;
    if (cp >= 0x03C3 and cp <= 0x03CB) return cp - 32;
    // Cyrillic
    if (cp >= 0x0410 and cp <= 0x042F) return cp + 32;
    if (cp >= 0x0430 and cp <= 0x044F) return cp - 32;
    return null;
}

/// Compare two codepoints with simple case folding.
pub fn eqlCodepointCaseless(a: u21, b: u21) bool {
    return simpleCaseFold(a) == simpleCaseFold(b);
}

test "utf8 decoding" {
    const s = "a\xC3\xA9\xE2\x82\xAC\xF0\x9F\x98\x80"; // 'a', 'é', '€', '😀'
    var off: usize = 0;

    const c1 = decodeUtf8Char(s[off..]).?;
    try std.testing.expectEqual(@as(u21, 'a'), c1.cp);
    try std.testing.expectEqual(@as(u3, 1), c1.len);
    off += c1.len;

    const c2 = decodeUtf8Char(s[off..]).?;
    try std.testing.expectEqual(@as(u21, 0x00E9), c2.cp);
    try std.testing.expectEqual(@as(u3, 2), c2.len);
    off += c2.len;

    const c3 = decodeUtf8Char(s[off..]).?;
    try std.testing.expectEqual(@as(u21, 0x20AC), c3.cp);
    try std.testing.expectEqual(@as(u3, 3), c3.len);
    off += c3.len;

    const c4 = decodeUtf8Char(s[off..]).?;
    try std.testing.expectEqual(@as(u21, 0x1F600), c4.cp);
    try std.testing.expectEqual(@as(u3, 4), c4.len);
    off += c4.len;

    try std.testing.expectEqual(s.len, off);
}

test "case folding" {
    try std.testing.expect(eqlByteCaseless('A', 'a'));
    try std.testing.expect(eqlByteCaseless('z', 'Z'));
    try std.testing.expect(!eqlByteCaseless('a', 'b'));
    try std.testing.expect(eqlCodepointCaseless(0x00C9, 0x00E9)); // 'É' == 'é'
}
