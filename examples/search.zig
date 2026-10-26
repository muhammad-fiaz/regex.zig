const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const log_data =
        \\2026-10-26 12:00:01 [INFO] Server started on port 8080
        \\2026-10-26 12:00:05 [WARN] High memory usage: 85%
        \\2026-10-26 12:00:10 [ERROR] Connection reset by peer: 192.168.1.50
    ;

    // Find all log severity tags [INFO], [WARN], [ERROR]
    var tag_regex = try regex.compile(allocator, "\\[(INFO|WARN|ERROR)\\]", .{});
    defer tag_regex.deinit();

    const matches = try tag_regex.findAll(allocator, log_data, .{});
    defer allocator.free(matches);

    std.debug.print("Found {} severity tags:\n", .{matches.len});
    for (matches, 0..) |m, i| {
        std.debug.print("  [{}] '{s}' at byte offset {}..{}\n", .{
            i + 1,
            m.slice,
            m.start,
            m.end,
        });
    }

    // Search for IP address in the log
    var ip_regex = try regex.compile(allocator, "\\b\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\b", .{});
    defer ip_regex.deinit();

    if (ip_regex.find(log_data, .{})) |ip_match| {
        std.debug.print("Detected peer IP: {s} (offset: {})\n", .{
            ip_match.slice,
            ip_match.start,
        });
    }
}
