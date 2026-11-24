const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const url_pattern = "(?P<scheme>https?)://(?P<host>[a-zA-Z0-9.-]+)(?::(?P<port>\\d+))?(?P<path>/[a-zA-Z0-9._/~-]*)?";
    var re = try regex.compile(allocator, url_pattern, .{});
    defer re.deinit();

    const target_url = "Connecting to https://api.example.com:8443/v1/metrics for health check";
    std.debug.print("Input: {s}\n", .{target_url});
    std.debug.print("Pattern groups: {} (host index: {})\n", .{
        re.captureGroupCount(),
        re.captureGroupIndex("host") orelse 0,
    });

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

        // Exact byte index positions of the entire match and submatches
        const full_bounds = caps.bounds();
        std.debug.print("Match byte range: [{}..{}]\n", .{ full_bounds.start, full_bounds.end });

        if (caps.nameSpan("host")) |host_span| {
            std.debug.print("Host byte range:  [{}..{}] ('{s}')\n", .{
                host_span.start,
                host_span.end,
                target_url[host_span.start..host_span.end],
            });
        }
        if (caps.getSpan(1)) |scheme_span| {
            std.debug.print("Scheme byte range:[{}..{}] ('{s}')\n", .{
                scheme_span.start,
                scheme_span.end,
                target_url[scheme_span.start..scheme_span.end],
            });
        }
    }

    // Optional groups simply report null when the branch did not participate.
    if (re.captures("Mirror: http://example.org for details", .{})) |plain| {
        std.debug.print("\nPlain URL: '{s}'\n", .{plain.slice()});
        std.debug.print("  Port group: {s}\n", .{plain.get(3) orelse "none"});
        std.debug.print("  Path group: {s}\n", .{plain.get(4) orelse "none"});
    }

    // Extract captures from every URL in a longer document in one pass.
    const document = "See https://one.example.com/a and http://localhost:8080/health for status.";
    const all = try re.capturesAll(allocator, document, .{});
    defer allocator.free(all);

    std.debug.print("\nParsed {} URLs:\n", .{all.len});
    for (all, 1..) |caps, i| {
        std.debug.print("  [{}] {s}://{s} port={s} path={s}\n", .{
            i,
            caps.name("scheme") orelse "?",
            caps.name("host") orelse "?",
            caps.name("port") orelse "-",
            caps.name("path") orelse "-",
        });
    }
}
