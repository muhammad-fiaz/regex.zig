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

    // Stop early without allocating a result array.
    var early_it = kv_re.capturesIterator(text, .{});
    std.debug.print("\nFirst two assignments only:\n", .{});
    var taken: usize = 0;
    while (taken < 2) : (taken += 1) {
        const caps = early_it.next() orelse break;
        std.debug.print("  {s}={s}\n", .{ caps.get(1).?, caps.get(2).? });
    }

    // Resume iteration from a known byte offset.
    const z_offset = std.mem.indexOf(u8, text, "z=") orelse 0;
    var tail_it = kv_re.capturesIterator(text, .{ .startOffset = z_offset });
    std.debug.print("\nResuming at byte {}:\n", .{z_offset});
    while (tail_it.next()) |caps| {
        std.debug.print("  {s}={s}\n", .{ caps.get(1).?, caps.get(2).? });
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
