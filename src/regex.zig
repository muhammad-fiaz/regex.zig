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
        while (true) {
            if (options.maxMatches) |limit| {
                if (list.items.len >= limit) break;
            }
            const m = it.next() orelse break;
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
        while (true) {
            if (options.maxMatches) |limit| {
                if (list.items.len >= limit) break;
            }
            const c = it.next() orelse break;
            try list.append(allocator, c);
        }

        return list.toOwnedSlice(allocator);
    }

    /// Count all non-overlapping matches in `input`.
    pub fn count(self: *Regex, input: []const u8, options: CountOptions) usize {
        var total: usize = 0;
        var it = self.iterator(input, .{ .startOffset = options.startOffset });
        while (true) {
            if (options.maxMatches) |limit| {
                if (total >= limit) break;
            }
            _ = it.next() orelse break;
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

            while (true) {
                if (options.maxReplacements) |limit| {
                    if (replaced_count >= limit) break;
                }
                const m = it.next() orelse break;
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

        while (true) {
            if (options.maxReplacements) |limit| {
                if (replaced_count >= limit) break;
            }
            const caps = it.next() orelse break;
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

        while (true) {
            if (options.maxSplits) |limit| {
                if (split_count + 1 >= limit) break;
            }
            const m = it.next() orelse break;
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

test "dot matches complete UTF-8 characters" {
    const testing = std.testing;
    var re = try compile(testing.allocator, ".", .{});
    defer re.deinit();

    // Regression: '.' must consume the full two-byte encoding of 'é' as one match.
    var it = re.capturesIterator("\xC3\xA9", .{});
    const single = it.next().?;
    try testing.expectEqual(@as(usize, 0), single.bounds().start);
    try testing.expectEqual(@as(usize, 2), single.bounds().end);
    try testing.expect(it.next() == null);

    // Ensure 1-, 2-, 3-, and 4-byte UTF-8 sequences each count as one character.
    const text = "a\xC3\xA9\xE2\x82\xAC\xF0\x9F\x98\x80";
    const expected = [_][]const u8{ "a", "\xC3\xA9", "\xE2\x82\xAC", "\xF0\x9F\x98\x80" };
    var chars = re.capturesIterator(text, .{});
    for (expected) |want| {
        const caps = chars.next().?;
        try testing.expectEqualStrings(want, caps.slice());
    }
    try testing.expect(chars.next() == null);

    try testing.expectEqual(@as(usize, 4), re.count(text, .{}));

    // Anchored patterns and matchExists must also observe character boundaries.
    var anchored = try compile(testing.allocator, "^.$", .{});
    defer anchored.deinit();
    try testing.expect(anchored.isMatch("\xC3\xA9", .{}));
    try testing.expect(!anchored.isMatch("\xC3\xA9\xC3\xA9", .{}));

    var anchored_two = try compile(testing.allocator, "^..$", .{});
    defer anchored_two.deinit();
    try testing.expect(!anchored_two.isMatch("\xC3\xA9", .{}));
    try testing.expect(anchored_two.isMatch("\xC3\xA9\xC3\xA9", .{}));

    // Quantifiers and captures must advance across the complete character too.
    var star = try compile(testing.allocator, ".*", .{});
    defer star.deinit();
    const star_match = star.find("\xC3\xA9", .{}).?;
    try testing.expectEqualStrings("\xC3\xA9", star_match.slice);

    var grouped = try compile(testing.allocator, "(.+)", .{});
    defer grouped.deinit();
    const group_caps = grouped.captures("\xC3\xA9", .{}).?;
    try testing.expectEqualStrings("\xC3\xA9", group_caps.slice());
    try testing.expectEqualStrings("\xC3\xA9", group_caps.get(1).?);

    // The ASCII option restricts shorthand classes, not dot's character semantics.
    var ascii_re = try compile(testing.allocator, ".", .{ .ascii = true });
    defer ascii_re.deinit();
    var ascii_it = ascii_re.capturesIterator("\xC3\xA9", .{});
    const ascii_caps = ascii_it.next().?;
    try testing.expectEqual(@as(usize, 2), ascii_caps.bounds().end);
    try testing.expect(ascii_it.next() == null);
}

test "dot preserves newline semantics for multi-byte text" {
    const testing = std.testing;
    var re = try compile(testing.allocator, ".", .{});
    defer re.deinit();

    try testing.expect(!re.isMatch("\n", .{}));
    try testing.expect(re.isMatch("\xC3\xA9", .{}));

    var dot_all = try compile(testing.allocator, ".", .{ .dotAll = true });
    defer dot_all.deinit();
    try testing.expect(dot_all.isMatch("\n", .{}));
}

test "inline flags are honored and scoped" {
    const testing = std.testing;

    var caseless = try compile(testing.allocator, "(?i)abc", .{});
    defer caseless.deinit();
    try testing.expect(caseless.isMatch("ABC", .{}));

    var scoped = try compile(testing.allocator, "(?i:abc)def", .{});
    defer scoped.deinit();
    try testing.expect(scoped.isMatch("ABCdef", .{}));
    try testing.expect(!scoped.isMatch("ABCDEF", .{}));

    var mid = try compile(testing.allocator, "a(?i)bc", .{});
    defer mid.deinit();
    try testing.expect(mid.isMatch("aBC", .{}));
    try testing.expect(!mid.isMatch("ABC", .{}));

    var dot_on = try compile(testing.allocator, "(?s).", .{});
    defer dot_on.deinit();
    try testing.expect(dot_on.isMatch("\n", .{}));

    var dot_off = try compile(testing.allocator, "(?-s).", .{ .dotAll = true });
    defer dot_off.deinit();
    try testing.expect(!dot_off.isMatch("\n", .{}));

    var case_off = try compile(testing.allocator, "(?-i)abc", .{ .caseInsensitive = true });
    defer case_off.deinit();
    try testing.expect(!case_off.isMatch("ABC", .{}));
}

test "unicode character classes decode complete codepoints" {
    const testing = std.testing;

    var hiragana = try compile(testing.allocator, "[\\u{3040}-\\u{309F}]", .{});
    defer hiragana.deinit();
    try testing.expect(hiragana.isMatch("\xE3\x81\x82", .{})); // あ
    try testing.expect(!hiragana.isMatch("\xE3\x82\xA2", .{})); // ア (Katakana)

    var negated = try compile(testing.allocator, "[^\\u{3040}-\\u{309F}]", .{});
    defer negated.deinit();
    try testing.expect(!negated.isMatch("\xE3\x81\x82", .{}));
    try testing.expect(negated.isMatch("a", .{}));

    var mixed = try compile(testing.allocator, "[a-z\\u{3040}-\\u{309F}]+", .{});
    defer mixed.deinit();
    const m = mixed.find("\xE3\x81\x82", .{}).?;
    try testing.expectEqual(@as(usize, 3), m.end);

    var raw = try compile(testing.allocator, "[\xC3\xA9-\xC3\xAA]", .{});
    defer raw.deinit();
    try testing.expect(raw.isMatch("\xC3\xA9", .{})); // é
    try testing.expect(raw.isMatch("\xC3\xAA", .{})); // ê
    try testing.expect(!raw.isMatch("\xC3\xA8", .{})); // è

    var fold = try compile(testing.allocator, "[\xC3\xA9]", .{ .caseInsensitive = true });
    defer fold.deinit();
    try testing.expect(fold.isMatch("\xC3\x89", .{})); // É
}

test "unicode shorthands, properties, and boundaries" {
    const testing = std.testing;

    var word = try compile(testing.allocator, "\\w+", .{});
    defer word.deinit();
    try testing.expect(word.isMatch("\xC3\xA9", .{})); // é
    try testing.expect(word.isMatch("\xE3\x81\x82", .{})); // あ
    try testing.expect(!word.isMatch(" ", .{}));

    var digit = try compile(testing.allocator, "\\d", .{});
    defer digit.deinit();
    try testing.expect(digit.isMatch("\xD9\xA0", .{})); // arabic-indic 0
    try testing.expect(!digit.isMatch("a", .{}));

    var space = try compile(testing.allocator, "\\s", .{});
    defer space.deinit();
    try testing.expect(space.isMatch("\xC2\xA0", .{})); // no-break space

    var letter = try compile(testing.allocator, "\\p{L}", .{});
    defer letter.deinit();
    try testing.expect(letter.isMatch("\xE3\x81\x82", .{}));
    try testing.expect(!letter.isMatch("1", .{}));

    var not_letter = try compile(testing.allocator, "\\P{L}", .{});
    defer not_letter.deinit();
    try testing.expect(not_letter.isMatch("1", .{}));
    try testing.expect(!not_letter.isMatch("a", .{}));

    var in_class = try compile(testing.allocator, "[\\p{L}]+", .{});
    defer in_class.deinit();
    try testing.expect(in_class.isMatch("\xE3\x81\x82", .{}));

    var non_word_class = try compile(testing.allocator, "[\\W]", .{});
    defer non_word_class.deinit();
    try testing.expect(non_word_class.isMatch(" ", .{}));
    try testing.expect(!non_word_class.isMatch("\xE3\x81\x82", .{}));

    var boundary = try compile(testing.allocator, "\\b\\w+\\b", .{});
    defer boundary.deinit();
    try testing.expect(boundary.isMatch("caf\xC3\xA9", .{}));

    // The ascii option restricts shorthands and boundaries to ASCII.
    var ascii_word = try compile(testing.allocator, "\\w", .{ .ascii = true });
    defer ascii_word.deinit();
    try testing.expect(ascii_word.isMatch("a", .{}));
    try testing.expect(!ascii_word.isMatch("\xC3\xA9", .{}));

    try testing.expectError(error.InvalidEscapeSequence, compile(testing.allocator, "\\p{Nope}", .{}));
}

test "pure literal shortcut preserves capturing groups" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "(abc)", .{});
    defer re.deinit();

    const caps = re.captures("abc", .{}).?;
    try testing.expectEqual(@as(usize, 1), caps.count());
    try testing.expectEqualStrings("abc", caps.get(1).?);

    var named = try compile(testing.allocator, "(?P<word>abc)", .{});
    defer named.deinit();
    const ncaps = named.captures("abc", .{}).?;
    try testing.expectEqualStrings("abc", ncaps.name("word").?);
}

test "unicode escape bounds and lookbehind diagnostics" {
    const testing = std.testing;
    try testing.expectError(error.InvalidEscapeSequence, compile(testing.allocator, "\\u{FFFFFF}", .{}));
    try testing.expectError(error.InvalidEscapeSequence, compile(testing.allocator, "\\u{}", .{}));
    try testing.expectError(error.UnsupportedLookaround, compile(testing.allocator, "(?<=a)b", .{}));
    try testing.expectError(error.UnsupportedLookaround, compile(testing.allocator, "(?<!a)b", .{}));
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

test "extended escape forms and quoting" {
    const testing = std.testing;

    var short_u = try compile(testing.allocator, "\\u00E9", .{});
    defer short_u.deinit();
    try testing.expectEqualStrings("\xC3\xA9", short_u.find("\xC3\xA9", .{}).?.slice);

    var braced_x = try compile(testing.allocator, "\\x{1F600}", .{});
    defer braced_x.deinit();
    try testing.expectEqualStrings("\xF0\x9F\x98\x80", braced_x.find("\xF0\x9F\x98\x80", .{}).?.slice);

    var surrogate = try compile(testing.allocator, "\\uD83D\\uDE00", .{});
    defer surrogate.deinit();
    try testing.expectEqualStrings("\xF0\x9F\x98\x80", surrogate.find("\xF0\x9F\x98\x80", .{}).?.slice);

    var surrogate_class = try compile(testing.allocator, "[\\uD83D\\uDE00]", .{});
    defer surrogate_class.deinit();
    try testing.expect(surrogate_class.isMatch("\xF0\x9F\x98\x80", .{}));

    var quoted = try compile(testing.allocator, "\\Qa+b*c\\E", .{});
    defer quoted.deinit();
    try testing.expectEqualStrings("a+b*c", quoted.find("a+b*c", .{}).?.slice);
    try testing.expect(!quoted.isMatch("aaabc", .{}));

    var quoted_class = try compile(testing.allocator, "[\\Qa-d\\E]+", .{});
    defer quoted_class.deinit();
    try testing.expectEqualStrings("a-d", quoted_class.find("a-d", .{}).?.slice);
    try testing.expect(!quoted_class.isMatch("b", .{}));

    var comment = try compile(testing.allocator, "(?#ignore this)abc", .{});
    defer comment.deinit();
    try testing.expect(comment.isMatch("abc", .{}));

    var control = try compile(testing.allocator, "\\cA\\012\\o{101}", .{});
    defer control.deinit();
    try testing.expect(control.isMatch("\x01\nA", .{}));
}

test "simple case folding uses full equivalence classes" {
    const testing = std.testing;
    const pairs = [_]struct { pattern: []const u8, input: []const u8 }{
        .{ .pattern = "(?i)\xC3\x9F", .input = "\xE1\xBA\x9E" }, // ß / ẞ
        .{ .pattern = "(?i)\xCF\x82", .input = "\xCE\xA3" }, // ς / Σ
        .{ .pattern = "(?i)k", .input = "\xE2\x84\xAA" }, // k / KELVIN SIGN
        .{ .pattern = "(?i)s", .input = "\xC5\xBF" }, // s / LONG S
        .{ .pattern = "(?i)\xCF\x85", .input = "\xCE\xA5" }, // υ / Υ
    };
    for (pairs) |case| {
        var re = try compile(testing.allocator, case.pattern, .{});
        defer re.deinit();
        try testing.expect(re.isMatch(case.input, .{}));
    }

    var class = try compile(testing.allocator, "(?i)[\xC3\x9F]", .{});
    defer class.deinit();
    try testing.expect(class.isMatch("\xE1\xBA\x9E", .{}));

    var class_cp = try compile(testing.allocator, "(?i)\\u{212A}", .{});
    defer class_cp.deinit();
    try testing.expect(class_cp.isMatch("k", .{}));
}

test "extended mode ignores whitespace and comments" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "(?x) a b # trailing comment\n c", .{});
    defer re.deinit();
    try testing.expectEqualStrings("abc", re.find("abc", .{}).?.slice);
    try testing.expect(!re.isMatch("a b c", .{}));

    // Whitespace inside a bracket expression stays significant.
    var class = try compile(testing.allocator, "(?x)[ ]", .{});
    defer class.deinit();
    try testing.expect(class.isMatch(" ", .{}));
    try testing.expect(!class.isMatch("a", .{}));

    // Scoped verbose flag restores the previous mode.
    var scoped = try compile(testing.allocator, "(?x: a b )c", .{});
    defer scoped.deinit();
    try testing.expectEqualStrings("abc", scoped.find("abc", .{}).?.slice);
    try testing.expect(!scoped.isMatch("ab", .{}));

    // Escaped whitespace and \Q...\E stay literal.
    var escaped_space = try compile(testing.allocator, "(?x)a\\ b", .{});
    defer escaped_space.deinit();
    try testing.expectEqualStrings("a b", escaped_space.find("a b", .{}).?.slice);

    var quoted = try compile(testing.allocator, "(?x)\\Q a b \\E", .{});
    defer quoted.deinit();
    try testing.expectEqualStrings(" a b ", quoted.find(" a b ", .{}).?.slice);

    // The same behavior is available through CompileOptions.
    var via_options = try compile(testing.allocator, "a  b # note\n c", .{ .extended = true });
    defer via_options.deinit();
    try testing.expectEqualStrings("abc", via_options.find("abc", .{}).?.slice);
    try testing.expect(!via_options.isMatch("a  b", .{}));
}

test "text end assertions, posix negation, and prefix safety" {
    const testing = std.testing;

    var z_final = try compile(testing.allocator, "a\\Z", .{});
    defer z_final.deinit();
    try testing.expect(z_final.isMatch("a\n", .{}));
    try testing.expect(!z_final.isMatch("a\nb", .{}));

    var z_plain = try compile(testing.allocator, "\\Z", .{});
    defer z_plain.deinit();
    try testing.expectEqual(@as(usize, 2), z_plain.find("ab\n", .{}).?.start);

    var negated_posix = try compile(testing.allocator, "[[:^lower:]]+", .{});
    defer negated_posix.deinit();
    try testing.expectEqualStrings("ABC", negated_posix.find("ABC", .{}).?.slice);
    try testing.expect(negated_posix.isMatch("\xC3\xA9", .{})); // é
    try testing.expect(!negated_posix.isMatch("abc", .{}));

    // Regression: a scoped group must not truncate the literal fast path.
    var scoped = try compile(testing.allocator, "(?s:ab)c", .{});
    defer scoped.deinit();
    try testing.expectEqualStrings("abc", scoped.find("abc", .{}).?.slice);
    try testing.expect(!scoped.isMatch("abx", .{}));

    // Multiline `$` only recognizes `\n` as a line terminator.
    var ml = try compile(testing.allocator, "(?m)a$", .{});
    defer ml.deinit();
    try testing.expect(ml.isMatch("a\nb", .{}));
    try testing.expect(!ml.isMatch("a\r\nb", .{}));
}

test "invalid constructs are rejected" {
    const testing = std.testing;
    try testing.expectError(error.UnexpectedCharacter, compile(testing.allocator, "(?)", .{}));
    try testing.expectError(error.UnexpectedCharacter, compile(testing.allocator, "(?-)", .{}));
    try testing.expectError(error.InvalidQuantifier, compile(testing.allocator, "^*", .{}));
    try testing.expectError(error.InvalidGroupName, compile(testing.allocator, "(?P<1a>x)", .{}));
    try testing.expectError(error.UnsupportedBackreference, compile(testing.allocator, "(?P=a)", .{}));
    try testing.expectError(error.UnsupportedConstruct, compile(testing.allocator, "\\G", .{}));
    try testing.expectError(error.InvalidEscapeSequence, compile(testing.allocator, "\\uD800", .{}));
    try testing.expectError(error.InvalidEscapeSequence, compile(testing.allocator, "\\x{110000}", .{}));
}

test "braced numeric replacement tokens" {
    const testing = std.testing;
    var re = try compile(testing.allocator, "(\\w+)@(\\w+)", .{});
    defer re.deinit();

    const out = try re.replace(testing.allocator, "bob@mail", "${1}-${2}", .{});
    defer testing.allocator.free(out);
    try testing.expectEqualStrings("bob-mail", out);
}
