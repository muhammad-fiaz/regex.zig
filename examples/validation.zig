const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Semantic version validation (e.g. 1.2.3 or 0.0.1)
    var semver_re = try regex.compile(allocator, "^\\d+\\.\\d+\\.\\d+$", .{});
    defer semver_re.deinit();

    const versions = [_][]const u8{ "0.0.1", "1.2.3", "v1.0.0", "1.2", "1.2.3.4" };
    std.debug.print("--- Semantic Version Validation ---\n", .{});
    for (versions) |v| {
        std.debug.print("  {s:<10} => {}\n", .{ v, semver_re.isMatch(v, .{}) });
    }

    // Hex color code validation (#RGB or #RRGGBB)
    var hex_color_re = try regex.compile(allocator, "^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$", .{});
    defer hex_color_re.deinit();

    const colors = [_][]const u8{ "#fff", "#FFAA00", "#123456", "#abcd", "123456" };
    std.debug.print("\n--- Hex Color Validation ---\n", .{});
    for (colors) |c| {
        std.debug.print("  {s:<10} => {}\n", .{ c, hex_color_re.isMatch(c, .{}) });
    }

    // C/Zig identifier validation
    var ident_re = try regex.compile(allocator, "^[a-zA-Z_][a-zA-Z0-9_]*$", .{});
    defer ident_re.deinit();

    const idents = [_][]const u8{ "my_variable", "_init123", "123invalid", "kebab-case" };
    std.debug.print("\n--- Identifier Validation ---\n", .{});
    for (idents) |id| {
        std.debug.print("  {s:<15} => {}\n", .{ id, ident_re.isMatch(id, .{}) });
    }
}
