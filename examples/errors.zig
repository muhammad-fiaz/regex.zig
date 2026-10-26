const std = @import("std");
const regex = @import("regex");

fn inspectPattern(allocator: std.mem.Allocator, pattern: []const u8) void {
    std.debug.print("Compiling: '{s}'\n", .{pattern});
    var p = regex.Parser.init(allocator, pattern, .{});
    defer p.deinit();

    var ast = p.parse() catch |err| {
        std.debug.print("  FAILED with error: {s}\n", .{@errorName(err)});
        if (p.diagnostic) |diag| {
            var buf: [256]u8 = undefined;
            const msg = diag.printBuf(&buf) catch "format error";
            std.debug.print("  Diagnostic: {s}\n", .{msg});
            std.debug.print("  Category:   {s}\n", .{@tagName(diag.category)});
            std.debug.print("  Location:   line {}, column {} (byte offset {})\n\n", .{
                diag.line,
                diag.column,
                diag.offset,
            });
        }
        return;
    };
    defer ast.deinit();

    std.debug.print("  SUCCESS (captures: {})\n\n", .{ast.capture_count});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Unclosed group
    inspectPattern(allocator, "abc(def|ghi");

    // 2. Unclosed character class
    inspectPattern(allocator, "[a-z0-9_");

    // 3. Invalid character range (z-a)
    inspectPattern(allocator, "[z-a]");

    // 4. Unsupported backreference
    inspectPattern(allocator, "(abc)\\1");

    // 5. Unsupported lookaround
    inspectPattern(allocator, "(?=prefix)value");

    // 6. Valid pattern
    inspectPattern(allocator, "^[a-zA-Z0-9_]+$");
}
