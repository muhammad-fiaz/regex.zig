const std = @import("std");
const builtin = @import("builtin");
const regex = @import("regex");

// Configure Windows console code page to UTF-8 (CP 65001) for proper Unicode glyph rendering
extern "kernel32" fn SetConsoleOutputCP(wCodePageID: std.os.windows.UINT) callconv(.winapi) std.os.windows.BOOL;

pub fn main() !void {
    if (builtin.os.tag == .windows) {
        _ = SetConsoleOutputCP(65001);
    }
    const allocator = std.heap.page_allocator;

    // 1. Matching Japanese multi-byte UTF-8 text (byte offsets, not char offsets)
    const japanese_text = "Language: 日本語 (にほんご) and English";
    var jp_re = try regex.compile(allocator, "にほんご", .{});
    defer jp_re.deinit();
    if (jp_re.find(japanese_text, .{})) |m| {
        std.debug.print("1. Japanese literal: '{s}' at bytes {}..{}\n", .{ m.slice, m.start, m.end });
    }

    // 2. '.' consumes one complete UTF-8 character, not one byte
    var dot_re = try regex.compile(allocator, ".", .{});
    defer dot_re.deinit();
    std.debug.print("2. Dot matches 'é' as one character: {} (count over 'é€😀' = {})\n", .{
        dot_re.isMatch("é", .{}),
        dot_re.count("é€😀", .{}),
    });

    // 3. Unicode currency symbols via multi-byte alternation (\$|€|£|¥)
    var currency_re = try regex.compile(allocator, "(\\$|€|£|¥)[0-9]+", .{});
    defer currency_re.deinit();
    var it = currency_re.iterator("Prices: $10, €25, £40, ¥3000", .{});
    std.debug.print("3. Currency prices:", .{});
    while (it.next()) |m| std.debug.print(" {s}", .{m.slice});
    std.debug.print("\n", .{});

    // 4. Full Unicode simple case folding (Latin-1, Greek, Cyrillic)
    var accented_re = try regex.compile(allocator, "café", .{ .caseInsensitive = true });
    defer accented_re.deinit();
    var cyrillic_re = try regex.compile(allocator, "ПРИВЕТ", .{ .caseInsensitive = true });
    defer cyrillic_re.deinit();
    std.debug.print("4. Caseless 'café'~'CAFÉ': {}, 'ПРИВЕТ'~'привет': {}\n", .{
        accented_re.isMatch("CAFÉ", .{}),
        cyrillic_re.isMatch("привет", .{}),
    });

    // 5. Unicode codepoint ranges in character classes
    var hiragana_re = try regex.compile(allocator, "[\\u{3040}-\\u{309F}]+", .{});
    defer hiragana_re.deinit();
    if (hiragana_re.find("にほんご", .{})) |m| {
        std.debug.print("5. Hiragana range: '{s}' ({} bytes)\n", .{ m.slice, m.len() });
    }

    // 6. Unicode property classes: \p{...} and negated \P{...}
    var letter_re = try regex.compile(allocator, "\\p{L}+", .{});
    defer letter_re.deinit();
    var digit_re = try regex.compile(allocator, "\\p{Nd}+", .{});
    defer digit_re.deinit();
    if (letter_re.find("abc 123", .{})) |m| {
        std.debug.print("6. \\p{{L}}+ letters: '{s}'\n", .{m.slice});
    }
    if (digit_re.find("١٢٣", .{})) |m| { // Arabic-Indic digits
        std.debug.print("   \\p{{Nd}}+ digits: '{s}'\n", .{m.slice});
    }

    // 7. Unicode-aware shorthands \w \d \s (default) vs ASCII mode.
    // Anchoring with ^...$ forces the whole word to match, exposing the difference.
    var word_uni = try regex.compile(allocator, "^\\w+$", .{});
    defer word_uni.deinit();
    var word_ascii = try regex.compile(allocator, "^\\w+$", .{ .ascii = true });
    defer word_ascii.deinit();
    std.debug.print("7. ^\\w+$ on 'café': Unicode={}, ASCII={}\n", .{
        word_uni.isMatch("café", .{}),
        word_ascii.isMatch("café", .{}), // false: 'é' is not an ASCII word byte
    });

    // 8. Unicode word boundary \b around a multi-byte word
    var boundary_re = try regex.compile(allocator, "\\b\\w+\\b", .{});
    defer boundary_re.deinit();
    std.debug.print("8. \\b\\w+\\b matches 'café': {}\n", .{boundary_re.isMatch("café", .{})});

    // 9. Escaped codepoints reach characters outside the BMP (astral plane).
    var emoji_re = try regex.compile(allocator, "\\u{1F600}", .{});
    defer emoji_re.deinit();
    if (emoji_re.find("smile 😀 here", .{})) |m| {
        std.debug.print("9. Astral codepoint \\u{{1F600}}: '{s}' at bytes {}..{}\n", .{
            m.slice,
            m.start,
            m.end,
        });
    }

    // 10. Negated properties match runs of characters outside a category.
    var non_letter_re = try regex.compile(allocator, "\\P{L}+", .{});
    defer non_letter_re.deinit();
    if (non_letter_re.find("abc 123!", .{})) |m| {
        std.debug.print("10. \\P{{L}}+ after letters: '{s}'\n", .{m.slice});
    }

    // 11. Unicode-aware \d accepts non-ASCII decimal digits unless ASCII mode is on.
    var digit_shorthand = try regex.compile(allocator, "^\\d+$", .{});
    defer digit_shorthand.deinit();
    var ascii_digit_shorthand = try regex.compile(allocator, "^\\d+$", .{ .ascii = true });
    defer ascii_digit_shorthand.deinit();
    std.debug.print("11. ^\\d+$ on '١٢٣': Unicode={}, ASCII={}\n", .{
        digit_shorthand.isMatch("١٢٣", .{}),
        ascii_digit_shorthand.isMatch("١٢٣", .{}),
    });

    // 12. Unicode whitespace includes no-break spaces (U+00A0).
    var space_re = try regex.compile(allocator, "^\\s+$", .{});
    defer space_re.deinit();
    std.debug.print("12. ^\\s+$ matches U+00A0: {}\n", .{space_re.isMatch("\u{00A0}", .{})});
}
