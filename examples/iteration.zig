const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const text = "Coordinates: x=10, y=25, z=142, w=0";

    // Iterate over key-value pairs
    var kv_re = try regex.compile(allocator, "([a-z])=(\\d+)", .{});
    defer kv_re.deinit();

    std.debug.print("Total assignments: {}\n", .{kv_re.count(text, .{})});

    var it = kv_re.capturesIterator(text, .{});
    var count: usize = 0;
    while (it.next()) |caps| {
        count += 1;
        std.debug.print("  Assignment {}: key='{s}', value={s}\n", .{
            count,
            caps.get(1) orelse "",
            caps.get(2) orelse "",
        });
    }

    // Zero-length match progression example: finding word boundaries
    std.debug.print("\n--- Zero-Length Match Safe Progression ---\n", .{});
    var boundary_re = try regex.compile(allocator, "\\b", .{});
    defer boundary_re.deinit();

    const phrase = "Zig 0.17";
    var b_it = boundary_re.iterator(phrase, .{});
    var b_count: usize = 0;
    while (b_it.next()) |m| {
        b_count += 1;
        std.debug.print("  Boundary {} at offset {}\n", .{ b_count, m.start });
    }
}
