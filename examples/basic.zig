const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const pattern = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";

    // Compile the regular expression with inline .{} options
    var re = try regex.compile(allocator, pattern, .{});
    defer re.deinit();

    const email1 = "dev@example.com";
    const email2 = "not-an-email";

    std.debug.print("Pattern: {s}\n", .{pattern});
    std.debug.print("Testing '{s}': {}\n", .{ email1, re.isMatch(email1, .{}) });
    std.debug.print("Testing '{s}': {}\n", .{ email2, re.isMatch(email2, .{}) });

    const text = "Contact the engineering team at support@example.com for help.";
    if (re.find(text, .{})) |match| {
        std.debug.print("Found match '{s}' from byte {} to {}\n", .{
            match.slice,
            match.start,
            match.end,
        });
    }
}
