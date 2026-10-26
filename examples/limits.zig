const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // 1. Defending against adversarial input with non-backtracking PikeVM
    std.debug.print("--- ReDoS Immunity Verification ---\n", .{});
    const redos_pattern = "(a+)+$";
    var re = try regex.compile(allocator, redos_pattern, .{});
    defer re.deinit();

    // An adversarial string that causes exponential catastrophe (2^30 steps) in backtracking engines:
    const adversarial = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa!";

    var timer_io: std.Io.Threaded = .init_single_threaded;
    const io = timer_io.io();
    const t0 = std.Io.Clock.now(.real, io);

    const matched = re.isMatch(adversarial, .{});

    const t1 = std.Io.Clock.now(.real, io);
    const dur_ns = t0.durationTo(t1).toNanoseconds();

    std.debug.print("Pattern: '{s}' on input of {} characters\n", .{ redos_pattern, adversarial.len });
    std.debug.print("Match result: {}\n", .{matched});
    std.debug.print("Execution time: {} ns (O(N) linear time guarantee)\n\n", .{dur_ns});

    // 2. Custom safety limits to prevent memory exhaustion
    std.debug.print("--- Custom Resource Limits ---\n", .{});

    // Exceeding maximum pattern length
    const long_pattern = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const res_len = regex.compile(allocator, long_pattern, .{
        .limits = .{ .maxPatternLength = 32 },
    });
    std.debug.print("Exceeding maxPatternLength (32 bytes): {s}\n", .{
        if (res_len) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding maximum nesting depth
    const deep_pattern = "((((a))))";
    const res_nest = regex.compile(allocator, deep_pattern, .{
        .limits = .{ .maxNestingDepth = 3 },
    });
    std.debug.print("Exceeding maxNestingDepth (3 levels):   {s}\n", .{
        if (res_nest) |_| "accepted" else |err| @errorName(err),
    });

    // Exceeding repetition bound
    const big_rep = "a{100}";
    const res_rep = regex.compile(allocator, big_rep, .{
        .limits = .{ .maxRepetition = 50 },
    });
    std.debug.print("Exceeding maxRepetition (50 count):     {s}\n", .{
        if (res_rep) |_| "accepted" else |err| @errorName(err),
    });
}
