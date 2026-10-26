const std = @import("std");
const regex = @import("regex");

pub const BenchmarkResult = struct {
    name: []const u8,
    iterations: usize,
    total_time_ns: u64,
    ns_per_op: f64,
    ops_per_sec: f64,
    throughput_mb_s: f64,

    pub fn print(self: BenchmarkResult) void {
        std.debug.print("{s:<32} | {d:>8} iters | {d:>10.1} ns/op | {d:>12.0} ops/s | {d:>8.2} MB/s\n", .{
            self.name,
            self.iterations,
            self.ns_per_op,
            self.ops_per_sec,
            self.throughput_mb_s,
        });
    }
};

fn measure(
    name: []const u8,
    iterations: usize,
    bytes_per_op: usize,
    comptime func: anytype,
    args: anytype,
) BenchmarkResult {
    var io_threaded: std.Io.Threaded = .init_single_threaded;
    const io = io_threaded.io();

    // 1. Warmup phase to prime instruction caches and branch predictors
    const warmup_iters = @max(50, iterations / 10);
    var w: usize = 0;
    while (w < warmup_iters) : (w += 1) {
        _ = @call(.auto, func, args);
    }

    // 2. Multi-round measurement (5 rounds of iterations each)
    const rounds: usize = 5;
    var total_ns_sum: u64 = 0;
    var r: usize = 0;
    while (r < rounds) : (r += 1) {
        const t_start = std.Io.Clock.now(.real, io);
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            _ = @call(.auto, func, args);
        }
        const t_end = std.Io.Clock.now(.real, io);
        const dur = t_start.durationTo(t_end);
        const round_ns: u64 = @intCast(@max(0, dur.toNanoseconds()));
        total_ns_sum += round_ns;
    }

    // 3. Compute statistical average across all rounds
    const total_ops: usize = rounds * iterations;
    const avg_ns_per_op = if (total_ops > 0) @as(f64, @floatFromInt(total_ns_sum)) / @as(f64, @floatFromInt(total_ops)) else 0;
    const ops_per_sec = if (avg_ns_per_op > 0) (1_000_000_000.0 / avg_ns_per_op) else 0;
    const bytes_total = @as(f64, @floatFromInt(bytes_per_op * total_ops));
    const sec_total = @as(f64, @floatFromInt(total_ns_sum)) / 1_000_000_000.0;
    const mb_per_sec = if (sec_total > 0) (bytes_total / (1024.0 * 1024.0)) / sec_total else 0;

    return BenchmarkResult{
        .name = name,
        .iterations = iterations,
        .total_time_ns = total_ns_sum / rounds,
        .ns_per_op = avg_ns_per_op,
        .ops_per_sec = ops_per_sec,
        .throughput_mb_s = mb_per_sec,
    };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    std.debug.print("========================================================================================\n", .{});
    std.debug.print("                         regex.zig v0.0.1 Client-Side Benchmarks                         \n", .{});
    std.debug.print("========================================================================================\n", .{});

    // 1. Literal matching benchmark
    {
        var re = try regex.compile(allocator, "needle", .{});
        defer re.deinit();
        const haystack: [2006]u8 = comptime blk: {
            var buf: [2006]u8 = undefined;
            @memset(buf[0..1000], 'a');
            @memcpy(buf[1000..1006], "needle");
            @memset(buf[1006..2006], 'b');
            break :blk buf;
        };
        const bench_fn = struct {
            pub fn run(r: *regex.Regex, s: []const u8) bool {
                return r.isMatch(s, .{});
            }
        }.run;

        const res = measure("Literal search (2KB haystack)", 10000, haystack.len, bench_fn, .{ &re, &haystack });
        res.print();
    }

    // 2. Email pattern compilation
    {
        const email_pat = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";
        const bench_fn = struct {
            pub fn run(alloc: std.mem.Allocator, pat: []const u8) void {
                var re = regex.compile(alloc, pat, .{}) catch return;
                re.deinit();
            }
        }.run;

        const res = measure("Email regex compilation", 5000, email_pat.len, bench_fn, .{ allocator, email_pat });
        res.print();
    }

    // 3. Email matching throughput
    {
        const email_pat = "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}";
        var re = try regex.compile(allocator, email_pat, .{});
        defer re.deinit();

        const input = "Contact team at support.service@company.domain.com for urgent inquiries.";
        const bench_fn = struct {
            pub fn run(r: *regex.Regex, s: []const u8) bool {
                return r.isMatch(s, .{});
            }
        }.run;

        const res = measure("Email matching", 20000, input.len, bench_fn, .{ &re, input });
        res.print();
    }

    // 4. Captures extraction
    {
        var re = try regex.compile(allocator, "(?P<host>[a-zA-Z0-9.-]+):(?P<port>\\d+)", .{});
        defer re.deinit();

        const input = "Connecting to api.service.internal:9092";
        const bench_fn = struct {
            pub fn run(r: *regex.Regex, s: []const u8) ?regex.Captures {
                return r.captures(s, .{});
            }
        }.run;

        const res = measure("Named captures extraction", 20000, input.len, bench_fn, .{ &re, input });
        res.print();
    }

    // 5. ReplaceAll benchmark
    {
        var re = try regex.compile(allocator, "\\b\\d+\\b", .{});
        defer re.deinit();

        const input = "Values: 10, 20, 30, 40, 50, 60, 70, 80, 90, 100";
        const bench_fn = struct {
            pub fn run(r: *regex.Regex, alloc: std.mem.Allocator, s: []const u8) void {
                const rep = r.replaceAll(alloc, s, "#", .{}) catch return;
                alloc.free(rep);
            }
        }.run;

        const res = measure("ReplaceAll 10 numbers", 10000, input.len, bench_fn, .{ &re, allocator, input });
        res.print();
    }

    // 6. Pathological ReDoS pattern
    {
        var re = try regex.compile(allocator, "(a+)+$", .{});
        defer re.deinit();

        const adversarial: [31]u8 = comptime blk: {
            var buf: [31]u8 = undefined;
            @memset(buf[0..30], 'a');
            buf[30] = '!';
            break :blk buf;
        };
        const bench_fn = struct {
            pub fn run(r: *regex.Regex, s: []const u8) bool {
                return r.isMatch(s, .{});
            }
        }.run;

        const res = measure("ReDoS pattern (a+)+$ (31 chars)", 1000, adversarial.len, bench_fn, .{ &re, &adversarial });
        res.print();
    }

    std.debug.print("========================================================================================\n", .{});
}
