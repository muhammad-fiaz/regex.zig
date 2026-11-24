const std = @import("std");
const ucd = @import("ucd.zig");

/// Decoded Unicode codepoint and its UTF-8 byte length.
pub const DecodedChar = struct {
    cp: u21,
    len: u3,
};

/// Return expected UTF-8 sequence byte length from the initial lead byte.
pub fn utf8SequenceLength(lead: u8) u3 {
    return std.unicode.utf8ByteSequenceLength(lead) catch 1;
}

/// True when `b` is a UTF-8 continuation byte (10xxxxxx).
pub fn isUtf8Continuation(b: u8) bool {
    return (b & 0xC0) == 0x80;
}

/// Decode the first UTF-8 codepoint from `bytes`. Returns null if empty or invalid.
pub fn decodeUtf8Char(bytes: []const u8) ?DecodedChar {
    if (bytes.len == 0) return null;
    const len = std.unicode.utf8ByteSequenceLength(bytes[0]) catch return null;
    if (bytes.len < len) return null;
    const cp = std.unicode.utf8Decode(bytes[0..len]) catch return null;
    return .{ .cp = cp, .len = len };
}

/// Return the UTF-8 encoded length of the character starting at `pos`.
/// Invalid or truncated sequences are treated as a single byte so callers can
/// continue scanning without getting stuck.
pub fn charLengthAt(bytes: []const u8, pos: usize) u3 {
    if (pos >= bytes.len) return 0;
    if (decodeUtf8Char(bytes[pos..])) |dec| return dec.len;
    return 1;
}

/// Convert an ASCII byte to lowercase using std.ascii.toLower.
pub const toLowerAscii = std.ascii.toLower;

/// Convert an ASCII byte to uppercase using std.ascii.toUpper.
pub const toUpperAscii = std.ascii.toUpper;

/// Compare two bytes for case-insensitive equality using std.ascii.
pub fn eqlByteCaseless(a: u8, b: u8) bool {
    return std.ascii.toLower(a) == std.ascii.toLower(b);
}

/// Simple Unicode case fold mapping for codepoints (full Unicode coverage).
pub fn simpleCaseFold(cp: u21) u21 {
    return ucd.simpleCaseFold(cp);
}

/// Static case-fold equivalence class of `cp`, or null when it folds to itself.
pub fn caselessEquivalents(cp: u21) ?[]const u21 {
    return ucd.caselessEquivalents(cp);
}

/// Return a case counterpart for codepoint `cp` if one exists, using the full
/// simple-case-fold equivalence tables. Uppercase and titlecase inputs map to
/// their folded (lowercase) form; a lowercase/titlecase-only input maps to
/// another member of its fold class when available.
pub fn toOtherCase(cp: u21) ?u21 {
    const eq = caselessEquivalents(cp) orelse return null;
    const folded = simpleCaseFold(cp);
    if (cp != folded) return folded;
    for (eq) |other| {
        if (other != cp) return other;
    }
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

    try std.testing.expectEqual(@as(u3, 1), charLengthAt(s, 0));
    try std.testing.expectEqual(@as(u3, 2), charLengthAt(s, 1));
    try std.testing.expectEqual(@as(u3, 3), charLengthAt(s, 3));
    try std.testing.expectEqual(@as(u3, 4), charLengthAt(s, 6));
    try std.testing.expectEqual(@as(u3, 0), charLengthAt(s, s.len));
}

test "case folding" {
    try std.testing.expect(eqlByteCaseless('A', 'a'));
    try std.testing.expect(eqlByteCaseless('z', 'Z'));
    try std.testing.expect(!eqlByteCaseless('a', 'b'));
    try std.testing.expect(eqlCodepointCaseless(0x00C9, 0x00E9)); // 'É' == 'é'
}

test "toOtherCase covers full fold classes" {
    const t = std.testing;
    try t.expectEqual(@as(u21, 'a'), toOtherCase('A').?);
    try t.expectEqual(@as(u21, 'A'), toOtherCase('a').?);
    try t.expectEqual(@as(u21, 0x00E9), toOtherCase(0x00C9).?); // É -> é
    try t.expectEqual(@as(u21, 0x03C3), toOtherCase(0x03A3).?); // Σ -> σ
    try t.expectEqual(@as(u21, 0x00DF), toOtherCase(0x1E9E).?); // ẞ -> ß
    try t.expectEqual(@as(u21, 0x10400), toOtherCase(0x10428).?); // Deseret
    try t.expect(toOtherCase(0x3042) == null); // あ
}
