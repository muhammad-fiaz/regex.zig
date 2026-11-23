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

    const text = "Contact the engineering team at support@example.com or sales@example.org for help.";
    if (re.find(text, .{})) |match| {
        std.debug.print("Found match '{s}' from byte {} to {} ({} bytes, empty: {})\n", .{
            match.slice,
            match.start,
            match.end,
            match.len(),
            match.isEmpty(),
        });

        // Continue scanning after the first match using an explicit start offset.
        if (re.findAt(text, match.end, .{})) |next| {
            std.debug.print("Next match from offset {}: '{s}' at {}..{}\n", .{
                match.end,
                next.slice,
                next.start,
                next.end,
            });
        }
    }

    // Escape user-provided text before compiling it as a literal pattern.
    const user_input = "What's the cost? $12.50 (approx.)";
    const escaped = try regex.escape(allocator, user_input);
    defer allocator.free(escaped);

    var literal_re = try regex.compile(allocator, escaped, .{});
    defer literal_re.deinit();

    std.debug.print("Escaped literal: {s}\n", .{escaped});
    std.debug.print("Literal self-match: {}\n", .{literal_re.isMatch(user_input, .{})});
    std.debug.print("Capturing groups in pattern: {}\n", .{re.captureGroupCount()});
}
