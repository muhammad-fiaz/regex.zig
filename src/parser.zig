const std = @import("std");
const ast_mod = @import("ast.zig");
const Node = ast_mod.Node;
const Ast = ast_mod.Ast;
const Repetition = ast_mod.Repetition;
const AnchorType = ast_mod.AnchorType;
const charset_mod = @import("charset.zig");
const Range = charset_mod.Range;
const CharClass = charset_mod.CharClass;
const Bitmap256 = charset_mod.Bitmap256;
const PosixClass = charset_mod.PosixClass;
const unicode_mod = @import("unicode.zig");
const ucd = @import("ucd.zig");
const options_mod = @import("options.zig");
const Options = options_mod.Options;
const CompileFlags = options_mod.CompileFlags;
const Limits = options_mod.Limits;
const error_mod = @import("error.zig");
const Error = error_mod.Error;
const Diagnostic = error_mod.Diagnostic;
const ErrorCategory = error_mod.ErrorCategory;

pub const Parser = struct {
    pattern: []const u8,
    pos: usize = 0,
    options: Options,
    current_flags: CompileFlags,
    arena: std.heap.ArenaAllocator,
    capture_count: usize = 0,
    named_groups: std.StringHashMapUnmanaged(usize) = .empty,
    nesting_depth: usize = 0,
    diagnostic: ?Diagnostic = null,

    pub fn init(allocator: std.mem.Allocator, pattern: []const u8, options: Options) Parser {
        return .{
            .pattern = pattern,
            .pos = 0,
            .options = options,
            .current_flags = CompileFlags.fromCompileOptions(options),
            .arena = std.heap.ArenaAllocator.init(allocator),
            .capture_count = 0,
            .named_groups = .empty,
            .nesting_depth = 0,
            .diagnostic = null,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.named_groups.deinit(self.arena.allocator());
        self.arena.deinit();
        self.* = undefined;
    }

    fn fail(self: *Parser, err: Error, category: ErrorCategory, offset: usize, message: []const u8) Error {
        var line: usize = 1;
        var col: usize = 1;
        var i: usize = 0;
        const target_offset = @min(offset, self.pattern.len);
        while (i < target_offset) : (i += 1) {
            if (self.pattern[i] == '\n') {
                line += 1;
                col = 1;
            } else {
                col += 1;
            }
        }

        self.diagnostic = .{
            .err = err,
            .category = category,
            .offset = target_offset,
            .line = line,
            .column = col,
            .message = message,
        };
        return err;
    }

    fn peek(self: *Parser) ?u8 {
        if (self.pos < self.pattern.len) return self.pattern[self.pos];
        return null;
    }

    fn advance(self: *Parser) ?u8 {
        if (self.pos < self.pattern.len) {
            const b = self.pattern[self.pos];
            self.pos += 1;
            return b;
        }
        return null;
    }

    fn match(self: *Parser, expected: u8) bool {
        if (self.peek() == expected) {
            self.pos += 1;
            return true;
        }
        return false;
    }

    pub fn parse(self: *Parser) Error!Ast {
        if (self.pattern.len > self.options.limits.maxPatternLength) {
            return self.fail(error.PatternTooLong, .limit, 0, "pattern exceeds maximum allowed length");
        }

        const root = try self.parseAlternation();
        if (self.pos < self.pattern.len) {
            return self.fail(error.UnexpectedCharacter, .syntax, self.pos, "unexpected character in pattern");
        }

        const ast = Ast{
            .arena = self.arena,
            .root = root,
            .capture_count = self.capture_count,
            .named_groups = self.named_groups,
        };
        // Hand over ownership of arena to Ast
        self.arena = std.heap.ArenaAllocator.init(self.arena.child_allocator);
        self.named_groups = .empty;
        return ast;
    }

    fn parseAlternation(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        var branches: std.ArrayList(Node) = .empty;
        defer branches.deinit(alloc);

        const first = try self.parseConcat();
        try branches.append(alloc, first.*);

        while (self.match('|')) {
            const next_node = try self.parseConcat();
            try branches.append(alloc, next_node.*);
        }

        if (branches.items.len == 1) {
            const result = try alloc.create(Node);
            result.* = branches.items[0];
            return result;
        }

        const nodes_slice = try alloc.alloc(*Node, branches.items.len);
        for (branches.items, 0..) |item, i| {
            nodes_slice[i] = try alloc.create(Node);
            nodes_slice[i].* = item;
        }

        const alt_node = try alloc.create(Node);
        alt_node.* = .{ .alt = nodes_slice };
        return alt_node;
    }

    fn parseConcat(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        var list: std.ArrayList(Node) = .empty;
        defer list.deinit(alloc);

        while (self.pos < self.pattern.len) {
            const b = self.peek().?;
            if (b == '|' or b == ')') break;
            const quantified = try self.parseQuantified();
            try list.append(alloc, quantified.*);
        }

        if (list.items.len == 0) {
            const empty_node = try alloc.create(Node);
            empty_node.* = .{ .empty = {} };
            return empty_node;
        }

        if (list.items.len == 1) {
            const result = try alloc.create(Node);
            result.* = list.items[0];
            return result;
        }

        const nodes_slice = try alloc.alloc(*Node, list.items.len);
        for (list.items, 0..) |item, i| {
            nodes_slice[i] = try alloc.create(Node);
            nodes_slice[i].* = item;
        }

        const concat_node = try alloc.create(Node);
        concat_node.* = .{ .concat = nodes_slice };
        return concat_node;
    }

    fn parseQuantified(self: *Parser) Error!*Node {
        const atom = try self.parseAtom();

        if (self.pos >= self.pattern.len) return atom;

        const b = self.peek().?;
        var rep: ?Repetition = null;

        if (b == '*') {
            self.pos += 1;
            const greedy = if (self.match('?')) self.current_flags.ungreedy else !self.current_flags.ungreedy;
            rep = .{ .min = 0, .max = null, .greedy = greedy };
        } else if (b == '+') {
            self.pos += 1;
            const greedy = if (self.match('?')) self.current_flags.ungreedy else !self.current_flags.ungreedy;
            rep = .{ .min = 1, .max = null, .greedy = greedy };
        } else if (b == '?') {
            self.pos += 1;
            const greedy = if (self.match('?')) self.current_flags.ungreedy else !self.current_flags.ungreedy;
            rep = .{ .min = 0, .max = 1, .greedy = greedy };
        } else if (b == '{') {
            rep = try self.parseBraceRepetition();
        }

        if (rep) |r| {
            const alloc = self.arena.allocator();
            const qnode = try alloc.create(Node);
            qnode.* = .{
                .quantifier = .{
                    .child = atom,
                    .rep = r,
                },
            };
            return qnode;
        }

        return atom;
    }

    fn parseBraceRepetition(self: *Parser) Error!Repetition {
        const brace_start = self.pos;
        self.pos += 1; // consume '{'

        var min_val: usize = 0;
        var has_min = false;

        while (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
            has_min = true;
            const d = std.fmt.charToDigit(self.pattern[self.pos], 10) catch unreachable;
            const mul = std.math.mul(usize, min_val, 10) catch return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition count overflow");
            min_val = std.math.add(usize, mul, d) catch return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition count overflow");
            self.pos += 1;
        }

        if (!has_min) {
            return self.fail(error.EmptyRepetition, .syntax, brace_start, "empty repetition quantifier");
        }

        if (min_val > self.options.limits.maxRepetition) {
            return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition count exceeds safety limit");
        }

        var max_val: ?usize = min_val;

        if (self.match(',')) {
            if (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
                var val: usize = 0;
                while (self.pos < self.pattern.len and std.ascii.isDigit(self.pattern[self.pos])) {
                    const d = std.fmt.charToDigit(self.pattern[self.pos], 10) catch unreachable;
                    const mul = std.math.mul(usize, val, 10) catch return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition count overflow");
                    val = std.math.add(usize, mul, d) catch return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition count overflow");
                    self.pos += 1;
                }
                if (val > self.options.limits.maxRepetition) {
                    return self.fail(error.RepetitionLimitExceeded, .limit, brace_start, "repetition upper bound exceeds limit");
                }
                if (val < min_val) {
                    return self.fail(error.InvalidRepetitionRange, .syntax, brace_start, "repetition min cannot exceed max");
                }
                max_val = val;
            } else {
                max_val = null; // {n,} unbounded
            }
        }

        if (!self.match('}')) {
            return self.fail(error.InvalidRepetitionRange, .syntax, brace_start, "unclosed repetition brace");
        }

        const greedy = if (self.match('?')) self.current_flags.ungreedy else !self.current_flags.ungreedy;
        return Repetition{
            .min = min_val,
            .max = max_val,
            .greedy = greedy,
        };
    }

    fn parseAtom(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        if (self.pos >= self.pattern.len) {
            const empty_node = try alloc.create(Node);
            empty_node.* = .{ .empty = {} };
            return empty_node;
        }

        const start_pos = self.pos;
        const b = self.peek().?;

        switch (b) {
            '*', '+', '?' => {
                return self.fail(error.InvalidQuantifier, .syntax, start_pos, "quantifier without preceding token");
            },
            '^' => {
                self.pos += 1;
                const node = try alloc.create(Node);
                node.* = .{
                    .anchor = if (self.current_flags.multiline) .start_line else .start_text,
                };
                return node;
            },
            '$' => {
                self.pos += 1;
                const node = try alloc.create(Node);
                node.* = .{
                    .anchor = if (self.current_flags.multiline) .end_line else .end_text,
                };
                return node;
            },
            '.' => {
                self.pos += 1;
                const node = try alloc.create(Node);
                node.* = .{ .any_char = self.current_flags.dotAll };
                return node;
            },
            '(' => {
                return self.parseGroup();
            },
            '[' => {
                return self.parseCharClass();
            },
            '\\' => {
                return self.parseEscape();
            },
            else => {
                // Literal character/UTF-8 sequence
                const seq_len = unicode_mod.utf8SequenceLength(b);
                const actual_len = @min(seq_len, self.pattern.len - start_pos);
                self.pos += actual_len;
                const lit_slice = try alloc.dupe(u8, self.pattern[start_pos..self.pos]);
                const node = try alloc.create(Node);
                node.* = .{ .literal = .{
                    .bytes = lit_slice,
                    .caseless = self.current_flags.caseless,
                } };
                return node;
            },
        }
    }

    fn parseGroup(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        const group_start = self.pos;
        self.pos += 1; // consume '('

        self.nesting_depth += 1;
        defer self.nesting_depth -= 1;
        if (self.nesting_depth > self.options.limits.maxNestingDepth) {
            return self.fail(error.NestingTooDeep, .limit, group_start, "parenthesis nesting exceeds safety limit");
        }

        var is_capturing = true;
        var group_name: ?[]const u8 = null;
        const saved_flags = self.current_flags;

        if (self.match('?')) {
            if (self.match(':')) {
                // Non-capturing group (?:...)
                is_capturing = false;
            } else if (self.peek() == '=' or self.peek() == '!') {
                // Lookahead: unsupported in v0.0.2
                return self.fail(error.UnsupportedLookaround, .unsupported, group_start, "lookaround assertions are unsupported in v0.0.2");
            } else if (self.peek() == '<' and self.pos + 1 < self.pattern.len and (self.pattern[self.pos + 1] == '=' or self.pattern[self.pos + 1] == '!')) {
                // Lookbehind: unsupported in v0.0.2
                return self.fail(error.UnsupportedLookaround, .unsupported, group_start, "lookbehind assertions are unsupported in v0.0.2");
            } else if (self.match('P') or self.peek() == '<') {
                // Named capture (?P<name>...) or (?<name>...)
                if (self.peek() == '<') {
                    self.pos += 1;
                    const name_start = self.pos;
                    while (self.pos < self.pattern.len and self.pattern[self.pos] != '>') {
                        self.pos += 1;
                    }
                    if (self.pos >= self.pattern.len) {
                        return self.fail(error.MissingGroupName, .syntax, name_start, "unclosed named capture group name");
                    }
                    const raw_name = self.pattern[name_start..self.pos];
                    self.pos += 1; // consume '>'
                    if (raw_name.len == 0) {
                        return self.fail(error.InvalidGroupName, .syntax, name_start, "group name cannot be empty");
                    }
                    for (raw_name) |c| {
                        if (!std.ascii.isAlphanumeric(c) and c != '_') {
                            return self.fail(error.InvalidGroupName, .syntax, name_start, "group name contains invalid characters");
                        }
                    }
                    group_name = try alloc.dupe(u8, raw_name);
                } else {
                    return self.fail(error.InvalidGroupName, .syntax, group_start, "malformed named group syntax");
                }
            } else {
                // Inline flags (?imsU) or flag group (?imsU:...)
                var set_flag = true;
                while (self.pos < self.pattern.len) {
                    const c = self.peek().?;
                    if (c == ')') {
                        self.pos += 1;
                        // Return empty node for pure flag modifier
                        const empty_node = try alloc.create(Node);
                        empty_node.* = .{ .empty = {} };
                        return empty_node;
                    } else if (c == ':') {
                        self.pos += 1;
                        is_capturing = false;
                        break;
                    } else if (c == '-') {
                        set_flag = false;
                        self.pos += 1;
                    } else if (c == 'i') {
                        self.current_flags.caseless = set_flag;
                        self.pos += 1;
                    } else if (c == 'm') {
                        self.current_flags.multiline = set_flag;
                        self.pos += 1;
                    } else if (c == 's') {
                        self.current_flags.dotAll = set_flag;
                        self.pos += 1;
                    } else if (c == 'U') {
                        self.current_flags.ungreedy = set_flag;
                        self.pos += 1;
                    } else {
                        return self.fail(error.UnsupportedConstruct, .unsupported, self.pos, "unknown inline flag");
                    }
                }
            }
        }

        var group_idx: ?usize = null;
        if (is_capturing) {
            self.capture_count += 1;
            const capture_limit = @min(self.options.limits.maxCaptures, options_mod.max_inline_capture_groups);
            if (self.capture_count > capture_limit) {
                return self.fail(error.TooManyCaptures, .limit, group_start, "capture group count exceeds limit");
            }
            group_idx = self.capture_count;
            if (group_name) |name| {
                if (self.named_groups.contains(name)) {
                    return self.fail(error.DuplicateGroupName, .syntax, group_start, "duplicate capture group name");
                }
                try self.named_groups.put(alloc, name, group_idx.?);
            }
        }

        const body = try self.parseAlternation();

        if (!self.match(')')) {
            return self.fail(error.UnterminatedGroup, .syntax, group_start, "unclosed group parenthesis");
        }

        self.current_flags = saved_flags;

        const node = try alloc.create(Node);
        node.* = .{
            .group = .{
                .index = group_idx,
                .name = group_name,
                .child = body,
            },
        };
        return node;
    }

    fn parseCharClass(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        const class_start = self.pos;
        self.pos += 1; // consume '['

        var is_negated = false;
        if (self.match('^')) {
            is_negated = true;
        }

        var ranges: std.ArrayList(Range) = .empty;
        defer ranges.deinit(alloc);

        var first_item = true;
        var closed = false;

        while (self.pos < self.pattern.len) {
            const c = self.peek().?;
            if (c == ']' and !first_item) {
                self.pos += 1;
                closed = true;
                break;
            }
            first_item = false;

            if (c == '[' and self.pos + 1 < self.pattern.len and self.pattern[self.pos + 1] == ':') {
                // POSIX class [:name:]
                self.pos += 2;
                const posix_start = self.pos;
                while (self.pos < self.pattern.len and !(self.pattern[self.pos] == ':' and self.pos + 1 < self.pattern.len and self.pattern[self.pos + 1] == ']')) {
                    self.pos += 1;
                }
                if (self.pos >= self.pattern.len) {
                    return self.fail(error.UnclosedCharacterClass, .syntax, class_start, "unclosed POSIX character class");
                }
                const posix_name = self.pattern[posix_start..self.pos];
                self.pos += 2; // consume ':]'

                if (PosixClass.fromName(posix_name)) |pclass| {
                    var bm = Bitmap256.initEmpty();
                    pclass.populateBitmap(&bm);
                    try appendBitmapRanges(alloc, &bm, &ranges);
                    continue;
                } else {
                    return self.fail(error.InvalidEscapeSequence, .syntax, posix_start, "unknown POSIX character class name");
                }
            }

            if (c == '\\' and self.pos + 1 < self.pattern.len) {
                const esc_char = self.pattern[self.pos + 1];
                switch (esc_char) {
                    'd', 'D', 'w', 'W', 's', 'S' => {
                        self.pos += 2;
                        const base = std.ascii.toLower(esc_char);
                        const neg = esc_char != base;
                        const src = self.shorthandSrc(base);
                        if (neg) {
                            const max_cp: u21 = if (self.options.ascii) 255 else 0x10FFFF;
                            try appendComplement(alloc, src, &ranges, max_cp);
                        } else {
                            try appendCpRanges(alloc, src, &ranges);
                        }
                        continue;
                    },
                    'p', 'P' => {
                        self.pos += 2;
                        const src = try self.propertySrc();
                        if (esc_char == 'P') {
                            try appendComplement(alloc, src, &ranges, 0x10FFFF);
                        } else {
                            try appendCpRanges(alloc, src, &ranges);
                        }
                        continue;
                    },
                    else => {},
                }
            }

            const item = try self.parseCharClassItem();

            // Check for range 'item - next'
            if (self.peek() == '-' and self.pos + 1 < self.pattern.len and self.pattern[self.pos + 1] != ']') {
                self.pos += 1; // consume '-'
                const next_item = try self.parseCharClassItem();
                if (item > next_item) {
                    return self.fail(error.InvalidCharacterRange, .syntax, class_start, "character range start greater than end");
                }
                try ranges.append(alloc, .{ .min = item, .max = next_item });
                if (self.current_flags.caseless) {
                    // Also add flipped case ranges if ASCII
                    if (item <= 255 and next_item <= 255 and std.ascii.isLower(@intCast(item)) and std.ascii.isLower(@intCast(next_item))) {
                        try ranges.append(alloc, .{ .min = std.ascii.toUpper(@intCast(item)), .max = std.ascii.toUpper(@intCast(next_item)) });
                    } else if (item <= 255 and next_item <= 255 and std.ascii.isUpper(@intCast(item)) and std.ascii.isUpper(@intCast(next_item))) {
                        try ranges.append(alloc, .{ .min = std.ascii.toLower(@intCast(item)), .max = std.ascii.toLower(@intCast(next_item)) });
                    }
                }
            } else {
                try ranges.append(alloc, .{ .min = item, .max = item });
                if (self.current_flags.caseless) {
                    if (item <= 255 and std.ascii.isLower(@intCast(item))) {
                        const flipped = std.ascii.toUpper(@intCast(item));
                        try ranges.append(alloc, .{ .min = flipped, .max = flipped });
                    } else if (item <= 255 and std.ascii.isUpper(@intCast(item))) {
                        const flipped = std.ascii.toLower(@intCast(item));
                        try ranges.append(alloc, .{ .min = flipped, .max = flipped });
                    }
                }
            }
        }

        if (!closed) {
            return self.fail(error.UnclosedCharacterClass, .syntax, class_start, "unclosed character class bracket");
        }

        var cc = try CharClass.init(alloc, ranges.items, is_negated);
        cc.caseless = self.current_flags.caseless;
        const node = try alloc.create(Node);
        node.* = .{ .char_class = cc };
        return node;
    }

    fn appendBitmapRanges(
        alloc: std.mem.Allocator,
        bitmap: *const Bitmap256,
        ranges: *std.ArrayList(Range),
    ) Error!void {
        var b: usize = 0;
        while (b < 256) {
            if (!bitmap.isSet(@intCast(b))) {
                b += 1;
                continue;
            }
            const start = b;
            while (b < 256 and bitmap.isSet(@intCast(b))) : (b += 1) {}
            try ranges.append(alloc, .{
                .min = @intCast(start),
                .max = @intCast(b - 1),
            });
        }
    }

    fn appendCpRanges(
        alloc: std.mem.Allocator,
        src: []const ucd.CpRange,
        ranges: *std.ArrayList(Range),
    ) Error!void {
        for (src) |r| {
            try ranges.append(alloc, .{ .min = r.lo, .max = r.hi });
        }
    }

    /// Append the complement of sorted, merged `src` within [0, max_cp].
    fn appendComplement(
        alloc: std.mem.Allocator,
        src: []const ucd.CpRange,
        ranges: *std.ArrayList(Range),
        max_cp: u21,
    ) Error!void {
        var cur: u32 = 0;
        for (src) |r| {
            if (r.lo > cur) {
                try ranges.append(alloc, .{ .min = @intCast(cur), .max = @intCast(r.lo - 1) });
            }
            cur = @as(u32, r.hi) + 1;
            if (cur > max_cp) return;
        }
        if (cur <= max_cp) {
            try ranges.append(alloc, .{ .min = @intCast(cur), .max = max_cp });
        }
    }

    /// Source ranges for a \d/\w/\s shorthand, honoring the ascii option.
    fn shorthandSrc(self: *Parser, base: u8) []const ucd.CpRange {
        if (!self.options.ascii) {
            return switch (base) {
                'd' => &ucd.digit_ranges,
                'w' => &ucd.word_ranges,
                's' => &ucd.space_ranges,
                else => unreachable,
            };
        }
        const S = struct {
            const d = [_]ucd.CpRange{.{ .lo = '0', .hi = '9' }};
            const w = [_]ucd.CpRange{
                .{ .lo = '0', .hi = '9' }, .{ .lo = 'A', .hi = 'Z' },
                .{ .lo = '_', .hi = '_' }, .{ .lo = 'a', .hi = 'z' },
            };
            const s = [_]ucd.CpRange{ .{ .lo = 0x09, .hi = 0x0D }, .{ .lo = 0x20, .hi = 0x20 } };
        };
        return switch (base) {
            'd' => &S.d,
            'w' => &S.w,
            's' => &S.s,
            else => unreachable,
        };
    }

    /// Parse a \p property name (braced or single letter) and return its ranges.
    fn propertySrc(self: *Parser) Error![]const ucd.CpRange {
        const start = self.pos;
        var name: []const u8 = undefined;
        if (self.match('{')) {
            const name_start = self.pos;
            while (self.pos < self.pattern.len and self.pattern[self.pos] != '}') : (self.pos += 1) {}
            if (self.pos >= self.pattern.len) {
                return self.fail(error.InvalidEscapeSequence, .syntax, start, "unclosed unicode property brace");
            }
            name = self.pattern[name_start..self.pos];
            self.pos += 1; // consume '}'
        } else {
            if (self.pos >= self.pattern.len) {
                return self.fail(error.InvalidEscapeSequence, .syntax, start, "empty unicode property name");
            }
            name = self.pattern[self.pos .. self.pos + 1];
            self.pos += 1;
        }
        const prop = ucd.lookupProperty(name) orelse {
            return self.fail(error.InvalidEscapeSequence, .syntax, start, "unknown unicode property name");
        };
        return ucd.propertyRanges(prop);
    }

    fn parseCharClassItem(self: *Parser) Error!u21 {
        if (self.pos >= self.pattern.len) {
            return self.fail(error.UnclosedCharacterClass, .syntax, self.pos, "unexpected end of class");
        }

        if (self.pattern[self.pos] == '\\') {
            self.pos += 1;
            if (self.pos >= self.pattern.len) {
                return self.fail(error.UnterminatedEscape, .syntax, self.pos - 1, "dangling escape inside character class");
            }
            const esc = self.advance().?;
            switch (esc) {
                'a' => return 0x07,
                'b' => return 0x08, // backspace inside char class
                'e' => return 0x1B,
                'f' => return 0x0C,
                'n' => return '\n',
                'r' => return '\r',
                't' => return '\t',
                'v' => return 0x0B,
                '0' => return 0,
                '\\', '-', '[', ']', '^' => return esc,
                'x' => return self.parseHexEscape(),
                'u' => return self.parseUnicodeEscape(),
                else => return esc,
            }
        }

        // Decode a complete UTF-8 character so ranges and single items operate on
        // codepoints rather than individual bytes. Invalid sequences fall back to
        // their leading byte, preserving byte-oriented escapes such as \xFF.
        if (unicode_mod.decodeUtf8Char(self.pattern[self.pos..])) |dec| {
            self.pos += dec.len;
            return dec.cp;
        }
        const b = self.pattern[self.pos];
        self.pos += 1;
        return b;
    }

    fn parseHexEscape(self: *Parser) Error!u21 {
        if (self.pos + 2 <= self.pattern.len and std.ascii.isHex(self.pattern[self.pos]) and std.ascii.isHex(self.pattern[self.pos + 1])) {
            const h1 = std.fmt.charToDigit(self.pattern[self.pos], 16) catch unreachable;
            const h2 = std.fmt.charToDigit(self.pattern[self.pos + 1], 16) catch unreachable;
            self.pos += 2;
            return (@as(u21, h1) << 4) | h2;
        }
        return self.fail(error.InvalidEscapeSequence, .syntax, self.pos - 2, "invalid hex escape sequence");
    }

    fn parseUnicodeEscape(self: *Parser) Error!u21 {
        if (self.match('{')) {
            const start = self.pos;
            var val: u32 = 0;
            var count: usize = 0;
            while (self.pos < self.pattern.len and self.pattern[self.pos] != '}') {
                const c = self.pattern[self.pos];
                if (!std.ascii.isHex(c)) {
                    return self.fail(error.InvalidEscapeSequence, .syntax, start, "invalid hex digit in unicode escape");
                }
                val = (val << 4) | (std.fmt.charToDigit(c, 16) catch unreachable);
                count += 1;
                self.pos += 1;
                if (count > 6) {
                    return self.fail(error.InvalidEscapeSequence, .syntax, start, "unicode codepoint value exceeds 21 bits");
                }
            }
            if (!self.match('}')) {
                return self.fail(error.InvalidEscapeSequence, .syntax, start, "unclosed unicode escape brace");
            }
            if (count == 0) {
                return self.fail(error.InvalidEscapeSequence, .syntax, start, "empty unicode escape");
            }
            if (val > 0x10FFFF) {
                return self.fail(error.InvalidEscapeSequence, .syntax, start, "unicode codepoint out of bounds");
            }
            return @intCast(val);
        }
        return self.fail(error.InvalidEscapeSequence, .syntax, self.pos - 2, "invalid unicode escape format");
    }

    fn parseEscape(self: *Parser) Error!*Node {
        const alloc = self.arena.allocator();
        const esc_start = self.pos;
        self.pos += 1; // consume '\'

        if (self.pos >= self.pattern.len) {
            return self.fail(error.UnterminatedEscape, .syntax, esc_start, "dangling escape character at end of pattern");
        }

        const c = self.advance().?;
        switch (c) {
            // Anchors
            'A' => {
                const node = try alloc.create(Node);
                node.* = .{ .anchor = .start_text };
                return node;
            },
            'z' => {
                const node = try alloc.create(Node);
                node.* = .{ .anchor = .end_text };
                return node;
            },
            'b' => {
                const node = try alloc.create(Node);
                node.* = .{ .anchor = .word_boundary };
                return node;
            },
            'B' => {
                const node = try alloc.create(Node);
                node.* = .{ .anchor = .non_word_boundary };
                return node;
            },
            // Shorthands
            'd', 'D', 'w', 'W', 's', 'S' => {
                return self.parseShorthandClass(c);
            },
            // Unicode property classes
            'p' => return self.parsePropertyClass(false),
            'P' => return self.parsePropertyClass(true),
            // Backreferences: unsupported
            '1'...'9' => {
                return self.fail(error.UnsupportedBackreference, .unsupported, esc_start, "backreferences are unsupported in linear-time v0.0.2 engine");
            },
            'k' => {
                return self.fail(error.UnsupportedBackreference, .unsupported, esc_start, "named backreferences are unsupported in v0.0.2");
            },
            // Hex / Unicode escapes
            'x' => {
                const val = try self.parseHexEscape();
                const node = try alloc.create(Node);
                node.* = .{ .byte_range = .{
                    .min = @intCast(val),
                    .max = @intCast(val),
                    .caseless = self.current_flags.caseless,
                } };
                return node;
            },
            'u' => {
                const val = try self.parseUnicodeEscape();
                if (val <= 255) {
                    const node = try alloc.create(Node);
                    node.* = .{ .byte_range = .{
                        .min = @intCast(val),
                        .max = @intCast(val),
                        .caseless = self.current_flags.caseless,
                    } };
                    return node;
                } else {
                    var ranges = [_]Range{.{ .min = val, .max = val }};
                    var cc = try CharClass.init(alloc, &ranges, false);
                    cc.caseless = self.current_flags.caseless;
                    const node = try alloc.create(Node);
                    node.* = .{ .char_class = cc };
                    return node;
                }
            },
            // Control escapes
            'a' => return self.makeLiteralByte(0x07),
            'e' => return self.makeLiteralByte(0x1B),
            'f' => return self.makeLiteralByte(0x0C),
            'n' => return self.makeLiteralByte('\n'),
            'r' => return self.makeLiteralByte('\r'),
            't' => return self.makeLiteralByte('\t'),
            'v' => return self.makeLiteralByte(0x0B),
            '0' => return self.makeLiteralByte(0),
            // Escaped metacharacters & literals
            else => return self.makeLiteralByte(c),
        }
    }

    fn makeLiteralByte(self: *Parser, b: u8) Error!*Node {
        const alloc = self.arena.allocator();
        const lit = try alloc.alloc(u8, 1);
        lit[0] = b;
        const node = try alloc.create(Node);
        node.* = .{ .literal = .{
            .bytes = lit,
            .caseless = self.current_flags.caseless,
        } };
        return node;
    }

    fn parseShorthandClass(self: *Parser, c: u8) Error!*Node {
        const alloc = self.arena.allocator();
        const base = std.ascii.toLower(c);
        const is_neg = c != base;
        const src = self.shorthandSrc(base);

        var ranges: std.ArrayList(Range) = .empty;
        defer ranges.deinit(alloc);
        try appendCpRanges(alloc, src, &ranges);

        var cc = try CharClass.init(alloc, ranges.items, is_neg);
        cc.caseless = self.current_flags.caseless;
        const node = try alloc.create(Node);
        node.* = .{ .char_class = cc };
        return node;
    }

    fn parsePropertyClass(self: *Parser, negated: bool) Error!*Node {
        const alloc = self.arena.allocator();
        const src = try self.propertySrc();

        var ranges: std.ArrayList(Range) = .empty;
        defer ranges.deinit(alloc);
        try appendCpRanges(alloc, src, &ranges);

        var cc = try CharClass.init(alloc, ranges.items, negated);
        cc.caseless = self.current_flags.caseless;
        const node = try alloc.create(Node);
        node.* = .{ .char_class = cc };
        return node;
    }
};

test "parser basic literals and groups" {
    const testing = std.testing;
    var p = Parser.init(testing.allocator, "(abc|def)+", .{});
    defer p.deinit();

    var ast = try p.parse();
    defer ast.deinit();

    try testing.expectEqual(@as(usize, 1), ast.capture_count);
}

test "parser diagnostics and errors" {
    const testing = std.testing;
    var p = Parser.init(testing.allocator, "(abc", .{});
    defer p.deinit();

    try testing.expectError(error.UnterminatedGroup, p.parse());
    try testing.expect(p.diagnostic != null);
    try testing.expectEqual(error.UnterminatedGroup, p.diagnostic.?.err);
    try testing.expectEqual(@as(usize, 0), p.diagnostic.?.offset);
}

test "parser unsupported backreference error" {
    const testing = std.testing;
    var p = Parser.init(testing.allocator, "(a)\\1", .{});
    defer p.deinit();

    try testing.expectError(error.UnsupportedBackreference, p.parse());
    try testing.expectEqual(error_mod.ErrorCategory.unsupported, p.diagnostic.?.category);
}

test "parser character class UTF-8 and closing bracket" {
    const testing = std.testing;

    var p = Parser.init(testing.allocator, "[\xC3\xA9-\xC3\xAA]", .{});
    defer p.deinit();
    var ast = try p.parse();
    defer ast.deinit();
    try testing.expect(ast.root.* == .char_class);
    try testing.expectEqual(@as(u21, 0x00E9), ast.root.char_class.ranges[0].min);
    try testing.expectEqual(@as(u21, 0x00EA), ast.root.char_class.ranges[0].max);

    var p2 = Parser.init(testing.allocator, "[]", .{});
    defer p2.deinit();
    try testing.expectError(error.UnclosedCharacterClass, p2.parse());

    var p3 = Parser.init(testing.allocator, "(?<=a)b", .{});
    defer p3.deinit();
    try testing.expectError(error.UnsupportedLookaround, p3.parse());
}
