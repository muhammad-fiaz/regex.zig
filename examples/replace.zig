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

    // Sanitizing sensitive token patterns using single replace
    var secret_re = try regex.compile(allocator, "(?P<key>token|api_key|secret)=([a-zA-Z0-9]+)", .{});
    defer secret_re.deinit();

    const config_line = "auth_header: token=ghp_9876543210abcdef user=admin";
    const sanitized = try secret_re.replace(allocator, config_line, "${key}=[REDACTED]", .{});
    defer allocator.free(sanitized);

    std.debug.print("Secret before: {s}\n", .{config_line});
    std.debug.print("Secret after:  {s}\n", .{sanitized});
}
