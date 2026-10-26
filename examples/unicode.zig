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

    // 1. Matching Japanese multi-byte UTF-8 text
    const japanese_text = "Language: 日本語 (にほんご) and English";
    var jp_re = try regex.compile(allocator, "にほんご", .{});
    defer jp_re.deinit();

    if (jp_re.find(japanese_text, .{})) |m| {
        std.debug.print("Found Japanese match: '{s}' at byte offset {}..{}\n", .{
            m.slice,
            m.start,
            m.end,
        });
    }

    // 2. Unicode currency symbols via multi-byte UTF-8 alternation (\$|€|£|¥)
    var currency_re = try regex.compile(allocator, "(\\$|€|£|¥)[0-9]+", .{});
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
