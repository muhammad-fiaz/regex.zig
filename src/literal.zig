const std = @import("std");

/// Find the first occurrence of `needle` in `haystack` starting at `start_pos`.
///
/// Case-sensitive search uses the standard library's SIMD scalar scan to locate
/// the first byte, then verifies the remainder with `std.mem.startsWith`. This
/// avoids per-call Boyer-Moore table construction for the common short-prefix
/// case. Case-insensitive search uses `std.ascii.findIgnoreCasePos`.
pub fn findLiteralPos(haystack: []const u8, needle: []const u8, start_pos: usize, caseless: bool) ?usize {
    if (start_pos > haystack.len) return null;
    if (needle.len == 0) return start_pos;
    if (haystack.len - start_pos < needle.len) return null;

    if (!caseless) {
        const first = needle[0];
        const rest = needle[1..];
        const max_pos = haystack.len - needle.len;
        var pos = start_pos;
        while (pos <= max_pos) {
            const match_idx = std.mem.findScalarPos(u8, haystack[0 .. max_pos + 1], pos, first) orelse return null;
            if (rest.len == 0 or std.mem.startsWith(u8, haystack[match_idx + 1 ..], rest)) {
                return match_idx;
            }
            pos = match_idx + 1;
        }
        return null;
    }

    return std.ascii.findIgnoreCasePos(haystack, start_pos, needle);
}

/// Checks if `haystack` starts with `prefix`, respecting case-insensitivity.
pub fn startsWith(haystack: []const u8, prefix: []const u8, caseless: bool) bool {
    if (haystack.len < prefix.len) return false;
    if (!caseless) {
        return std.mem.startsWith(u8, haystack, prefix);
    }
    return std.ascii.startsWithIgnoreCase(haystack, prefix);
}

test "find literal pos case sensitive and caseless" {
    const s = "Hello World!";
    try std.testing.expectEqual(@as(?usize, 6), findLiteralPos(s, "World", 0, false));
    try std.testing.expectEqual(@as(?usize, null), findLiteralPos(s, "world", 0, false));
    try std.testing.expectEqual(@as(?usize, 6), findLiteralPos(s, "world", 0, true));
    try std.testing.expectEqual(@as(?usize, 6), findLiteralPos(s, "WORLD", 0, true));
    try std.testing.expectEqual(@as(?usize, 4), findLiteralPos(s, "o", 0, false));
    try std.testing.expect(startsWith(s, "Hello", false));
    try std.testing.expect(startsWith(s, "hello", true));
}
