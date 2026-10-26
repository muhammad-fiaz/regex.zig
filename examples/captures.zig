const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const url_pattern = "(?P<scheme>https?)://(?P<host>[a-zA-Z0-9.-]+)(?::(?P<port>\\d+))?(?P<path>/[a-zA-Z0-9._/~-]*)?";
    var re = try regex.compile(allocator, url_pattern, .{});
    defer re.deinit();

    const target_url = "Connecting to https://api.example.com:8443/v1/metrics for health check";
    std.debug.print("Input: {s}\n", .{target_url});

    if (re.captures(target_url, .{})) |caps| {
        std.debug.print("Full URL match: '{s}'\n", .{caps.slice()});
        std.debug.print("  Scheme: {s}\n", .{caps.name("scheme") orelse "none"});
        std.debug.print("  Host:   {s}\n", .{caps.name("host") orelse "none"});
        std.debug.print("  Port:   {s}\n", .{caps.name("port") orelse "default (443)"});
        std.debug.print("  Path:   {s}\n", .{caps.name("path") orelse "/"});

        std.debug.print("Numbered access:\n", .{});
        std.debug.print("  Group 1 (scheme): {s}\n", .{caps.get(1) orelse ""});
        std.debug.print("  Group 2 (host):   {s}\n", .{caps.get(2) orelse ""});
        std.debug.print("  Group 3 (port):   {s}\n", .{caps.get(3) orelse "unmatched"});
        std.debug.print("  Group 4 (path):   {s}\n", .{caps.get(4) orelse ""});
    }
}
