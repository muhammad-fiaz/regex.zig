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

    // A split limit keeps the remainder in the final field.
    const limited = try delim_re.split(allocator, csv_data, .{ .maxSplits = 2 });
    defer allocator.free(limited);

    std.debug.print("\nWith maxSplits = 2 ({} fields):\n", .{limited.len});
    for (limited, 0..) |part, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, part });
    }

    // Empty fields are preserved instead of being silently dropped.
    var comma_re = try regex.compile(allocator, ",", .{});
    defer comma_re.deinit();
    const fields = try comma_re.split(allocator, "a,,b,", .{});
    defer allocator.free(fields);

    std.debug.print("\nEmpty fields preserved ({} fields):\n", .{fields.len});
    for (fields, 0..) |field, i| {
        std.debug.print("  [{}] '{s}'\n", .{ i + 1, field });
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
