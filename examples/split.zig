const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Splitting by complex delimiters: commas, semicolons, and variable whitespace
    var delim_re = try regex.compile(allocator, "[,;\\s]+", .{});
    defer delim_re.deinit();

    const csv_data = "alpha, beta;  gamma   delta,epsilon";
    const tokens = try delim_re.split(allocator, csv_data, .{});
    defer allocator.free(tokens);

    std.debug.print("Splitting '{s}' into {} tokens:\n", .{ csv_data, tokens.len });
    for (tokens, 0..) |t, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, t });
    }

    // Splitting by HTML tag delimiters
    var tag_re = try regex.compile(allocator, "<[^>]+>", .{});
    defer tag_re.deinit();

    const html = "<p>First paragraph</p><div>Second paragraph</div>";
    const html_parts = try tag_re.split(allocator, html, .{});
    defer allocator.free(html_parts);

    std.debug.print("\nExtracted non-tag sections:\n", .{});
    for (html_parts, 0..) |part, i| {
        if (part.len > 0) {
            std.debug.print("  [{}] '{s}'\n", .{ i + 1, part });
        }
    }
}
