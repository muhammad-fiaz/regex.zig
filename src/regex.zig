const std = @import("std");

// Re-exported public modules and types
pub const error_mod = @import("error.zig");
pub const Error = error_mod.Error;
pub const Diagnostic = error_mod.Diagnostic;
pub const ErrorCategory = error_mod.ErrorCategory;

pub const options_mod = @import("options.zig");
pub const Options = options_mod.Options;
pub const CompileOptions = options_mod.CompileOptions;
pub const CompileFlags = options_mod.CompileFlags;
pub const Limits = options_mod.Limits;
pub const MatchOptions = options_mod.MatchOptions;
pub const FindAllOptions = options_mod.FindAllOptions;
pub const ReplaceOptions = options_mod.ReplaceOptions;
pub const ReplaceAllOptions = options_mod.ReplaceAllOptions;
pub const SplitOptions = options_mod.SplitOptions;
pub const CountOptions = options_mod.CountOptions;
pub const IterateOptions = options_mod.IterateOptions;

pub const match_mod = @import("match.zig");
pub const Match = match_mod.Match;
pub const Span = match_mod.Span;
pub const Captures = match_mod.Captures;

pub const iterator_mod = @import("iterator.zig");
pub const Iterator = iterator_mod.Iterator;
pub const CapturesIterator = iterator_mod.CapturesIterator;

pub const escape_mod = @import("escape.zig");
pub const escape = escape_mod.escape;
pub const escapeBuffer = escape_mod.escapeBuffer;
pub const isSpecial = escape_mod.isSpecial;

pub const automaton_mod = @import("automaton.zig");
pub const Prog = automaton_mod.Prog;

pub const engine_mod = @import("engine.zig");
pub const Engine = engine_mod.Engine;
pub const Scratch = engine_mod.Scratch;

pub const parser_mod = @import("parser.zig");
pub const Parser = parser_mod.Parser;

pub const compiler_mod = @import("compiler.zig");
pub const Compiler = compiler_mod.Compiler;

pub const replace_mod = @import("replace.zig");
pub const expandReplacement = replace_mod.expandReplacement;

pub const unicode = @import("unicode.zig");

/// Compile a regular expression pattern with explicit options (or inline `.{}`).
pub fn compile(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    options: CompileOptions,
) Error!Regex {
    var p = Parser.init(allocator, pattern, options);
    defer p.deinit();

    var ast = try p.parse();
    defer ast.deinit();

    var c = Compiler.init(allocator, options);
    defer c.deinit();

    var prog = try c.compile(&ast);
    errdefer prog.deinit();

    var scratch = Scratch.init(allocator, prog.insts.len) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer scratch.deinit();

    return Regex{
        .prog = prog,
        .scratch = scratch,
        .allocator = allocator,
    };
}

/// Convenience helper to compile and test if `pattern` matches `input`.
pub fn isMatch(
    allocator: std.mem.Allocator,
    pattern: []const u8,
    input: []const u8,
    options: CompileOptions,
) !bool {
    var re = try compile(allocator, pattern, options);
    defer re.deinit();
    return re.isMatch(input, .{});
}

/// A compiled regular expression object.
pub const Regex = struct {
    prog: Prog,
    scratch: Scratch,
    allocator: std.mem.Allocator,

    /// Release all allocated memory associated with this compiled regular expression.
    pub fn deinit(self: *Regex) void {
        self.scratch.deinit();
        self.prog.deinit();
        self.* = undefined;
    }

    /// Test whether the regular expression matches anywhere in `input`.
    pub fn isMatch(self: *Regex, input: []const u8, options: MatchOptions) bool {
        return Engine.matchExists(&self.prog, &self.scratch, input, options.startOffset);
    }

    /// Return the first leftmost match in `input`, or null if not found.
    pub fn find(self: *Regex, input: []const u8, options: MatchOptions) ?Match {
        return self.findAt(input, options.startOffset, options);
    }

    /// Return the first leftmost match in `input` starting at byte offset `start_pos`.
    pub fn findAt(self: *Regex, input: []const u8, start_pos: usize, options: MatchOptions) ?Match {
        _ = options;
        if (Engine.search(&self.prog, &self.scratch, input, start_pos)) |caps| {
            const b = caps.bounds();
            return Match{
                .start = b.start,
                .end = b.end,
                .slice = caps.slice(),
            };
        }
        return null;
    }

    /// Collect all non-overlapping matches in `input` into an owned slice.
    pub fn findAll(self: *Regex, allocator: std.mem.Allocator, input: []const u8, options: FindAllOptions) ![]Match {
        var list: std.ArrayList(Match) = .empty;
        defer list.deinit(allocator);

        var it = self.iterator(input, .{ .startOffset = options.startOffset });
        while (it.next()) |m| {
            if (options.maxMatches) |limit| {
                if (list.items.len >= limit) break;
            }
            try list.append(allocator, m);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Obtain the first match and its captured submatch groups in `input`.
    pub fn captures(self: *Regex, input: []const u8, options: MatchOptions) ?Captures {
        return self.capturesAt(input, options.startOffset, options);
    }

    /// Obtain the first match and its captures in `input` starting at `start_pos`.
    pub fn capturesAt(self: *Regex, input: []const u8, start_pos: usize, options: MatchOptions) ?Captures {
        _ = options;
        return Engine.search(&self.prog, &self.scratch, input, start_pos);
    }

    /// Collect all matches with their captured groups into an owned slice.
    pub fn capturesAll(self: *Regex, allocator: std.mem.Allocator, input: []const u8, options: FindAllOptions) ![]Captures {
        var list: std.ArrayList(Captures) = .empty;
        defer list.deinit(allocator);

        var it = self.capturesIterator(input, .{ .startOffset = options.startOffset });
        while (it.next()) |c| {
            if (options.maxMatches) |limit| {
                if (list.items.len >= limit) break;
            }
            try list.append(allocator, c);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Count all non-overlapping matches in `input`.
    pub fn count(self: *Regex, input: []const u8, options: CountOptions) usize {
        var total: usize = 0;
        var it = self.iterator(input, .{ .startOffset = options.startOffset });
        while (it.next()) |_| {
            if (options.maxMatches) |limit| {
                if (total >= limit) break;
            }
            total += 1;
        }
        return total;
    }

    /// Replace the first match in `input` with `replacement`, expanding `$0`, `$1`, `${name}`.
    pub fn replace(
        self: *Regex,
        allocator: std.mem.Allocator,
        input: []const u8,
        replacement: []const u8,
        options: ReplaceOptions,
    ) ![]u8 {
        if (std.mem.indexOfScalar(u8, replacement, '$') == null) {
            const m_opt = self.find(input, .{ .startOffset = options.startOffset });
            if (m_opt == null) {
                return allocator.dupe(u8, input);
            }
            const m = m_opt.?;
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(allocator);
            try out.ensureTotalCapacity(allocator, input.len + replacement.len);
            try out.appendSlice(allocator, input[0..m.start]);
            try out.appendSlice(allocator, replacement);
            try out.appendSlice(allocator, input[m.end..]);
            return out.toOwnedSlice(allocator);
        }

        const caps_opt = self.captures(input, .{ .startOffset = options.startOffset });
        if (caps_opt == null) {
            return allocator.dupe(u8, input);
        }

        const caps = caps_opt.?;
        const b = caps.bounds();

        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.ensureTotalCapacity(allocator, input.len + replacement.len);

        try out.appendSlice(allocator, input[0..b.start]);
        try expandReplacement(allocator, replacement, caps, &out);
        try out.appendSlice(allocator, input[b.end..]);

        return out.toOwnedSlice(allocator);
    }

    /// Replace all non-overlapping matches in `input` with `replacement`.
    pub fn replaceAll(
        self: *Regex,
        allocator: std.mem.Allocator,
        input: []const u8,
        replacement: []const u8,
        options: ReplaceAllOptions,
    ) ![]u8 {
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.ensureTotalCapacity(allocator, input.len);

        if (std.mem.indexOfScalar(u8, replacement, '$') == null) {
            var it = self.iterator(input, .{ .startOffset = options.startOffset });
            var last_idx: usize = 0;
            var replaced_count: usize = 0;

            while (it.next()) |m| {
                if (options.maxReplacements) |limit| {
                    if (replaced_count >= limit) break;
                }
                try out.appendSlice(allocator, input[last_idx..m.start]);
                try out.appendSlice(allocator, replacement);
                last_idx = m.end;
                replaced_count += 1;
            }

            try out.appendSlice(allocator, input[last_idx..]);
            return out.toOwnedSlice(allocator);
        }

        var it = self.capturesIterator(input, .{ .startOffset = options.startOffset });
        var last_idx: usize = 0;
        var replaced_count: usize = 0;

        while (it.next()) |caps| {
            if (options.maxReplacements) |limit| {
                if (replaced_count >= limit) {
                    break;
                }
            }
            const b = caps.bounds();
            try out.appendSlice(allocator, input[last_idx..b.start]);
            try expandReplacement(allocator, replacement, caps, &out);
            last_idx = b.end;
            replaced_count += 1;
        }

        try out.appendSlice(allocator, input[last_idx..]);
        return out.toOwnedSlice(allocator);
    }

    /// Split `input` around all non-overlapping matches of the regular expression.
    pub fn split(self: *Regex, allocator: std.mem.Allocator, input: []const u8, options: SplitOptions) ![][]const u8 {
        var list: std.ArrayList([]const u8) = .empty;
        defer list.deinit(allocator);

        var it = self.iterator(input, .{ .startOffset = options.startOffset });
        var last_idx: usize = 0;
        var split_count: usize = 0;

        while (it.next()) |m| {
            if (options.maxSplits) |limit| {
                if (split_count + 1 >= limit) {
                    break;
                }
            }
            try list.append(allocator, input[last_idx..m.start]);
            last_idx = m.end;
            split_count += 1;
        }

        try list.append(allocator, input[last_idx..]);
        return list.toOwnedSlice(allocator);
    }

    /// Return an iterator over non-overlapping matches in `input`.
    pub fn iterator(self: *Regex, input: []const u8, options: IterateOptions) Iterator {
        const wrapper = struct {
            pub fn matchFn(ctx: *anyopaque, in: []const u8, start_pos: usize) ?Captures {
                const self_ptr: *Regex = @ptrCast(@alignCast(ctx));
                return self_ptr.captures(in, .{ .startOffset = start_pos });
            }
        };
        return Iterator.init(self, wrapper.matchFn, input, options.startOffset);
    }

    /// Return an iterator over non-overlapping matches and captures in `input`.
    pub fn capturesIterator(self: *Regex, input: []const u8, options: IterateOptions) CapturesIterator {
        const wrapper = struct {
            pub fn matchFn(ctx: *anyopaque, in: []const u8, start_pos: usize) ?Captures {
                const self_ptr: *Regex = @ptrCast(@alignCast(ctx));
                return self_ptr.captures(in, .{ .startOffset = start_pos });
            }
        };
        return CapturesIterator.init(self, wrapper.matchFn, input, options.startOffset);
    }

    /// Return the count of capturing groups in this pattern.
    pub fn captureGroupCount(self: *const Regex) usize {
        return self.prog.capture_count;
    }

    /// Return the index for a named capture group, or null if not found.
    pub fn captureGroupIndex(self: *const Regex, name: []const u8) ?usize {
        return self.prog.named_groups.get(name);
    }

    /// Create an independent scratch context for concurrent matching on this regex across threads.
    pub fn createScratch(self: *const Regex, allocator: std.mem.Allocator) !Scratch {
        return Scratch.init(allocator, self.prog.insts.len);
    }

    /// Match using an explicit Scratch context (safe for concurrent use across multiple threads).
    pub fn searchWithScratch(
        self: *const Regex,
        scratch: *Scratch,
        input: []const u8,
        start_pos: usize,
    ) ?Captures {
        return Engine.search(&self.prog, scratch, input, start_pos);
    }
};

test "public api compile and isMatch" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "[a-z]+@[a-z]+\\.com", .{});
    defer re.deinit();

    try testing.expect(re.isMatch("dev@example.com", .{}));
    try testing.expect(!re.isMatch("invalid-email", .{}));
}

test "public api find and findAll" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "[0-9]+", .{});
    defer re.deinit();

    const m = re.find("items: 12, 34, 56", .{});
    try testing.expect(m != null);
    try testing.expectEqualStrings("12", m.?.slice);
    try testing.expectEqual(@as(usize, 7), m.?.start);
    try testing.expectEqual(@as(usize, 9), m.?.end);

    const all = try re.findAll(testing.allocator, "items: 12, 34, 56", .{});
    defer testing.allocator.free(all);

    try testing.expectEqual(@as(usize, 3), all.len);
    try testing.expectEqualStrings("12", all[0].slice);
    try testing.expectEqualStrings("34", all[1].slice);
    try testing.expectEqualStrings("56", all[2].slice);

    // With limits
    const limited = try re.findAll(testing.allocator, "items: 12, 34, 56", .{ .maxMatches = 2 });
    defer testing.allocator.free(limited);
    try testing.expectEqual(@as(usize, 2), limited.len);
}

test "public api captures and named captures" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "(?P<host>[a-z]+):(?P<port>[0-9]+)", .{});
    defer re.deinit();

    const caps = re.captures("server localhost:8080 running", .{});
    try testing.expect(caps != null);
    try testing.expectEqualStrings("localhost:8080", caps.?.slice());
    try testing.expectEqualStrings("localhost", caps.?.name("host").?);
    try testing.expectEqualStrings("8080", caps.?.name("port").?);
    try testing.expectEqualStrings("localhost", caps.?.get(1).?);
    try testing.expectEqualStrings("8080", caps.?.get(2).?);
}

test "public api replace and replaceAll" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "([a-zA-Z]+) ([a-zA-Z]+)", .{});
    defer re.deinit();

    const rep = try re.replace(testing.allocator, "hello world again", "$2, $1", .{});
    defer testing.allocator.free(rep);
    try testing.expectEqualStrings("world, hello again", rep);

    var re_digits = try compile(testing.allocator, "\\d+", .{});
    defer re_digits.deinit();

    const rep_all = try re_digits.replaceAll(testing.allocator, "x=10, y=20, z=30", "#", .{});
    defer testing.allocator.free(rep_all);
    try testing.expectEqualStrings("x=#, y=#, z=#", rep_all);

    const rep_limited = try re_digits.replaceAll(testing.allocator, "x=10, y=20, z=30", "#", .{ .maxReplacements = 2 });
    defer testing.allocator.free(rep_limited);
    try testing.expectEqualStrings("x=#, y=#, z=30", rep_limited);
}

test "public api split" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "[,;\\s]+", .{});
    defer re.deinit();

    const parts = try re.split(testing.allocator, "one, two; three   four", .{});
    defer testing.allocator.free(parts);

    try testing.expectEqual(@as(usize, 4), parts.len);
    try testing.expectEqualStrings("one", parts[0]);
    try testing.expectEqualStrings("two", parts[1]);
    try testing.expectEqualStrings("three", parts[2]);
    try testing.expectEqualStrings("four", parts[3]);

    const parts_limited = try re.split(testing.allocator, "one, two; three   four", .{ .maxSplits = 2 });
    defer testing.allocator.free(parts_limited);
    try testing.expectEqual(@as(usize, 2), parts_limited.len);
}

test "public api count and iterator" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "\\b[a-z]{3}\\b", .{});
    defer re.deinit();

    const c = re.count("the quick red fox jumps", .{});
    try testing.expectEqual(@as(usize, 3), c); // "the", "red", "fox"

    const c_limited = re.count("the quick red fox jumps", .{ .maxMatches = 2 });
    try testing.expectEqual(@as(usize, 2), c_limited);

    var it = re.iterator("the quick red fox jumps", .{});
    const m1 = it.next().?;
    try testing.expectEqualStrings("the", m1.slice);
    const m2 = it.next().?;
    try testing.expectEqualStrings("red", m2.slice);
    const m3 = it.next().?;
    try testing.expectEqualStrings("fox", m3.slice);
    try testing.expect(it.next() == null);
}

test "public api options caseless and multiline" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "^[a-z]+$", .{
        .caseInsensitive = true,
        .multiline = true,
    });
    defer re.deinit();

    try testing.expect(re.isMatch("HELLO", .{}));
    try testing.expect(re.isMatch("world", .{}));
    try testing.expect(re.isMatch("first\nSECOND\nthird", .{}));
}

test "public api escape" {
    const testing = std.testing;
    const s = try escape(testing.allocator, "1.5 + 2.5 = 4.0");
    defer testing.allocator.free(s);
    try testing.expectEqualStrings("1\\.5 \\+ 2\\.5 = 4\\.0", s);
}

test "greedy vs lazy quantifiers" {
    const testing = std.testing;
    var re_greedy = try compile(testing.allocator, "<.+>", .{});
    defer re_greedy.deinit();
    const mg = re_greedy.find("<div><span>content</span></div>", .{});
    try testing.expect(mg != null);
    try testing.expectEqualStrings("<div><span>content</span></div>", mg.?.slice);

    var re_lazy = try compile(testing.allocator, "<.+?>", .{});
    defer re_lazy.deinit();
    const ml = re_lazy.find("<div><span>content</span></div>", .{});
    try testing.expect(ml != null);
    try testing.expectEqualStrings("<div>", ml.?.slice);
}

test "zero length match iteration progress" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "a*", .{});
    defer re.deinit();

    var it = re.iterator("ba", .{});
    // 'ba': at 0: empty match before 'b', then at 1: 'a', then at 2: empty match after 'a'
    const m1 = it.next().?;
    try testing.expectEqual(@as(usize, 0), m1.len());
    const m2 = it.next().?;
    try testing.expectEqualStrings("a", m2.slice);
}

test "unmatched optional capture groups" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "(a)?(b)", .{});
    defer re.deinit();

    const caps = re.captures("b", .{});
    try testing.expect(caps != null);
    try testing.expectEqualStrings("b", caps.?.slice());
    try testing.expect(caps.?.get(1) == null); // Optional 'a' not matched
    try testing.expectEqualStrings("b", caps.?.get(2).?);
}

test "resource limits enforcement" {
    const testing = std.testing;
    // Pattern length limit
    try testing.expectError(error.PatternTooLong, compile(testing.allocator, "abcdefgh", .{
        .limits = .{ .maxPatternLength = 5 },
    }));

    // Nesting depth limit
    try testing.expectError(error.NestingTooDeep, compile(testing.allocator, "(((a)))", .{
        .limits = .{ .maxNestingDepth = 2 },
    }));

    // Repetition limit
    try testing.expectError(error.RepetitionLimitExceeded, compile(testing.allocator, "a{100}", .{
        .limits = .{ .maxRepetition = 10 },
    }));
}

test "linear time ReDoS resistance" {
    const testing = std.testing;
    // Classic ReDoS pattern that causes catastrophic backtracking in PCRE2/Perl:
    // (a+)+$ against 25 'a's followed by '!'
    var re = try compile(testing.allocator, "(a+)+$", .{});
    defer re.deinit();

    const adversarial_input = "aaaaaaaaaaaaaaaaaaaaaaaaa!";
    // In a backtracking engine, this takes 2^25 steps (seconds or minutes).
    // In our linear-time engine, this executes in a few microseconds!
    const matched = re.isMatch(adversarial_input, .{});
    try testing.expect(!matched);
}

test "word boundary assertions" {
    const testing = std.testing;
    var re_word = try compile(testing.allocator, "\\bcat\\b", .{});
    defer re_word.deinit();

    try testing.expect(re_word.isMatch("the cat sat", .{}));
    try testing.expect(!re_word.isMatch("the category", .{}));
    try testing.expect(!re_word.isMatch("bobcat", .{}));

    var re_non_word = try compile(testing.allocator, "\\Bcat\\B", .{});
    defer re_non_word.deinit();
    try testing.expect(re_non_word.isMatch("bobcatfish", .{}));
    try testing.expect(!re_non_word.isMatch("cat", .{}));
}

test "top level convenience isMatch" {
    const testing = std.testing;
    try testing.expect(try isMatch(testing.allocator, "^[0-9]+$", "12345", .{}));
    try testing.expect(!try isMatch(testing.allocator, "^[0-9]+$", "123a45", .{}));
}
