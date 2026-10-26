const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Matching Japanese Hiragana text: range [\u{3040}-\u{309F}]
    const japanese_text = "Language: 日本語 (にほんご) and English";
    var hiragana_re = try regex.compile(allocator, "[\\u{3040}-\\u{309F}]+", .{});
    defer hiragana_re.deinit();

    if (hiragana_re.find(japanese_text, .{})) |m| {
        std.debug.print("Found Hiragana match: '{s}' at byte offset {}..{}\n", .{
            m.slice,
            m.start,
            m.end,
        });
    }

    // 2. Unicode currency symbols
    var currency_re = try regex.compile(allocator, "[$€£¥][0-9]+", .{});
    defer currency_re.deinit();

    const price_list = "Prices: $10, €25, £40, ¥3000";
    var it = currency_re.iterator(price_list, .{});
    std.debug.print("\nExtracted currency prices:\n", .{});
    while (it.next()) |m| {
        std.debug.print("  {s}\n", .{m.slice});
    }

    // 3. Unicode case folding (Latin-1 accented characters)
    var accented_re = try regex.compile(allocator, "café", .{
        .caseInsensitive = true,
    });
    defer accented_re.deinit();

    std.debug.print("\nUnicode Caseless Match ('café' on 'CAFÉ'): {}\n", .{
        accented_re.isMatch("CAFÉ", .{}),
    });
}
