const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Reformatting dates from MM/DD/YYYY to YYYY-MM-DD using numbered groups
    var date_re = try regex.compile(allocator, "(\\d{2})/(\\d{2})/(\\d{4})", .{});
    defer date_re.deinit();

    const text_dates = "Meeting dates: 10/26/2026, 11/04/2026, and 12/31/2026.";
    const iso_dates = try date_re.replaceAll(allocator, text_dates, "$3-$1-$2", .{});
    defer allocator.free(iso_dates);

    std.debug.print("Original:  {s}\n", .{text_dates});
    std.debug.print("Formatted: {s}\n\n", .{iso_dates});

    // `$&` inserts the whole match, while `$$` inserts a literal dollar sign.
    const wrapped = try date_re.replaceAll(allocator, text_dates, "[$&]", .{});
    defer allocator.free(wrapped);
    const wrapped_first = try date_re.replace(allocator, text_dates, "[$&]", .{});
    defer allocator.free(wrapped_first);
    std.debug.print("Wrapped all dates:       {s}\n", .{wrapped});
    std.debug.print("Wrapped first date only: {s}\n", .{wrapped_first});

    var price_re = try regex.compile(allocator, "(\\d+)\\.(\\d{2})", .{});
    defer price_re.deinit();
    const price = try price_re.replaceAll(allocator, "Total: 19.99", "$$$1.${2}", .{});
    defer allocator.free(price);
    std.debug.print("Literal dollar escape:   {s}\n\n", .{price});

    // Sanitizing sensitive token patterns using a named replacement.
    var secret_re = try regex.compile(allocator, "(?P<key>token|api_key|secret)=([a-zA-Z0-9_]+)", .{});
    defer secret_re.deinit();

    const config_line = "auth_header: token=ghp_9876543210abcdef user=admin";
    const sanitized = try secret_re.replace(allocator, config_line, "${key}=[REDACTED]", .{});
    defer allocator.free(sanitized);

    const sanitized_angle = try secret_re.replace(allocator, config_line, "$<key>=[MASKED]", .{});
    defer allocator.free(sanitized_angle);

    std.debug.print("Secret before: {s}\n", .{config_line});
    std.debug.print("Secret after:  {s}\n", .{sanitized});
    std.debug.print("Angle syntax:  {s}\n\n", .{sanitized_angle});

    // A bounded replacement updates only the first occurrence.
    const first_only = try date_re.replaceAll(allocator, text_dates, "$3-$1-$2", .{ .maxReplacements = 1 });
    defer allocator.free(first_only);
    std.debug.print("First date only: {s}\n", .{first_only});

    // Collapse arbitrary whitespace runs into a single space.
    var ws_re = try regex.compile(allocator, "\\s+", .{});
    defer ws_re.deinit();
    const normalized = try ws_re.replaceAll(allocator, "alpha   beta\n\tgamma", " ", .{});
    defer allocator.free(normalized);
    std.debug.print("Normalized: '{s}'\n", .{normalized});
}
