const std = @import("std");
const automaton_mod = @import("automaton.zig");
const Prog = automaton_mod.Prog;
const Inst = automaton_mod.Inst;
const Opcode = automaton_mod.Opcode;
const EmptyWidthType = automaton_mod.EmptyWidthType;
const match_mod = @import("match.zig");
const Match = match_mod.Match;
const Span = match_mod.Span;
const Captures = match_mod.Captures;
const literal_mod = @import("literal.zig");
const charset_mod = @import("charset.zig");
const unicode_mod = @import("unicode.zig");

pub const MAX_CAPTURE_GROUPS = 32;
pub const MAX_SLOTS = MAX_CAPTURE_GROUPS * 2;
pub const UNSET_SLOT = std.math.maxInt(usize);

pub const Thread = struct {
    inst_id: u32,
    slots: [MAX_SLOTS]usize = @splat(UNSET_SLOT),
};

/// Reusable execution scratch state to avoid runtime allocations during matching.
pub const Scratch = struct {
    curr_queue: []Thread,
    next_queue: []Thread,
    visited: []u32,
    generation: u32 = 0,
    bool_curr: []u32,
    bool_next: []u32,
    raw_threads: []Thread,
    raw_u32s: []u32,
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_insts: usize) !Scratch {
        const capacity = max_insts + 4;
        const u32s = try allocator.alloc(u32, capacity * 3);
        errdefer allocator.free(u32s);

        const vis = u32s[0..capacity];
        const b_curr = u32s[capacity .. capacity * 2];
        const b_next = u32s[capacity * 2 .. capacity * 3];

        @memset(vis, 0);

        return .{
            .curr_queue = &[_]Thread{},
            .next_queue = &[_]Thread{},
            .visited = vis,
            .generation = 0,
            .bool_curr = b_curr,
            .bool_next = b_next,
            .raw_threads = &[_]Thread{},
            .raw_u32s = u32s,
            .capacity = capacity,
            .allocator = allocator,
        };
    }

    pub fn ensureThreadQueues(self: *Scratch) !void {
        if (self.raw_threads.len == 0) {
            const threads = try self.allocator.alloc(Thread, self.capacity * 2);
            self.raw_threads = threads;
            self.curr_queue = threads[0..self.capacity];
            self.next_queue = threads[self.capacity .. self.capacity * 2];
        }
    }

    pub fn deinit(self: *Scratch) void {
        if (self.raw_threads.len > 0) {
            self.allocator.free(self.raw_threads);
        }
        self.allocator.free(self.raw_u32s);
        self.* = undefined;
    }

    pub fn nextGeneration(self: *Scratch) u32 {
        self.generation +%= 1;
        if (self.generation == 0) {
            self.generation = 1;
            @memset(self.visited, 0);
        }
        return self.generation;
    }
};

pub const Engine = struct {
    /// Ultra-fast boolean matching: tests whether `prog` matches anywhere in `input`.
    pub fn matchExists(
        prog: *const Prog,
        scratch: *Scratch,
        input: []const u8,
        start_pos: usize,
    ) bool {
        if (start_pos > input.len) return false;

        // Fast-path: pure literal pattern
        if (prog.is_pure_literal and prog.literal_prefix != null) {
            return literal_mod.findLiteralPos(input, prog.literal_prefix.?, start_pos, prog.flags.caseless) != null;
        }

        const is_start_anchored = prog.is_start_anchored;

        // Fast-path: start-anchored pattern with prefix
        if (is_start_anchored) {
            if (prog.literal_prefix) |prefix| {
                if (!literal_mod.startsWith(input[start_pos..], prefix, prog.flags.caseless)) {
                    return false;
                }
            }
            return matchExistsAt(prog, scratch, input, start_pos);
        }

        // Scanning loop across starting positions
        var pos = start_pos;
        while (pos <= input.len) {
            // Literal prefix acceleration if available and unanchored
            if (prog.literal_prefix) |prefix| {
                if (prefix.len > 0) {
                    if (input.len < pos + prefix.len) return false;
                    if (literal_mod.findLiteralPos(input, prefix, pos, prog.flags.caseless)) |cand| {
                        pos = cand;
                    } else {
                        return false;
                    }
                }
            }

            if (matchExistsAt(prog, scratch, input, pos)) {
                return true;
            }

            pos += 1;
        }

        return false;
    }

    fn matchExistsAt(
        prog: *const Prog,
        scratch: *Scratch,
        input: []const u8,
        start_pos: usize,
    ) bool {
        var curr_len: usize = 0;
        var next_len: usize = 0;
        var matched_early = false;

        const gen = scratch.nextGeneration();

        addBoolThread(
            prog,
            scratch,
            &scratch.bool_curr,
            &curr_len,
            &matched_early,
            prog.start_inst,
            input,
            start_pos,
            gen,
        );

        if (matched_early) return true;
        if (curr_len == 0) return false;

        var p = start_pos;
        while (p < input.len and curr_len > 0) {
            const c = input[p];
            next_len = 0;
            const next_gen = scratch.nextGeneration();

            for (scratch.bool_curr[0..curr_len]) |inst_id| {
                const inst = prog.insts[inst_id];
                var matched = false;

                switch (inst.op) {
                    .byte => {
                        if (inst.isCaseless()) {
                            matched = unicode_mod.eqlByteCaseless(c, @intCast(inst.data));
                        } else {
                            matched = (c == @as(u8, @intCast(inst.data)));
                        }
                    },
                    .byte_range => {
                        const lo: u8 = @intCast(inst.data & 0xFF);
                        const hi: u8 = @intCast((inst.data >> 8) & 0xFF);
                        if (inst.isCaseless()) {
                            const cl = unicode_mod.toLowerAscii(c);
                            matched = (cl >= unicode_mod.toLowerAscii(lo) and cl <= unicode_mod.toLowerAscii(hi));
                        } else {
                            matched = (c >= lo and c <= hi);
                        }
                    },
                    .any_byte => {
                        matched = true;
                    },
                    .any_non_nl => {
                        matched = (c != '\n');
                    },
                    .char_class => {
                        const cc = prog.char_classes[inst.data];
                        matched = cc.matchesByte(c);
                    },
                    .match => {
                        return true;
                    },
                    else => {},
                }

                if (matched) {
                    addBoolThread(
                        prog,
                        scratch,
                        &scratch.bool_next,
                        &next_len,
                        &matched_early,
                        inst.out1,
                        input,
                        p + 1,
                        next_gen,
                    );
                    if (matched_early) return true;
                }
            }

            // Swap queues
            const temp = scratch.bool_curr;
            scratch.bool_curr = scratch.bool_next;
            scratch.bool_next = temp;
            curr_len = next_len;

            p += 1;
        }

        // Process any remaining match threads at end of input
        for (scratch.bool_curr[0..curr_len]) |inst_id| {
            if (prog.insts[inst_id].op == .match) {
                return true;
            }
        }

        return false;
    }

    fn addBoolThread(
        prog: *const Prog,
        scratch: *Scratch,
        queue: *[]u32,
        queue_len: *usize,
        matched_early: *bool,
        start_inst_id: u32,
        input: []const u8,
        p: usize,
        gen: u32,
    ) void {
        var inst_id = start_inst_id;
        while (true) {
            if (matched_early.*) return;
            if (inst_id >= prog.insts.len) return;
            if (scratch.visited[inst_id] == gen) return;
            scratch.visited[inst_id] = gen;

            const inst = prog.insts[inst_id];
            switch (inst.op) {
                .match => {
                    matched_early.* = true;
                    return;
                },
                .nop, .capture_start, .capture_end => {
                    inst_id = inst.out1;
                    continue;
                },
                .alt => {
                    addBoolThread(prog, scratch, queue, queue_len, matched_early, inst.out1, input, p, gen);
                    if (matched_early.*) return;
                    inst_id = inst.out2;
                    continue;
                },
                .empty_width => {
                    const ew_type: EmptyWidthType = @fromBackingInt(@intCast(inst.data));
                    if (checkAssertion(ew_type, input, p)) {
                        inst_id = inst.out1;
                        continue;
                    }
                    return;
                },
                .byte, .byte_range, .any_byte, .any_non_nl, .char_class => {
                    if (queue_len.* < queue.len) {
                        queue.*[queue_len.*] = inst_id;
                        queue_len.* += 1;
                    }
                    return;
                },
                .fail => return,
            }
        }
    }

    /// Execute search for the leftmost-first match of `prog` in `input` starting at `start_pos`.
    pub fn search(
        prog: *const Prog,
        scratch: *Scratch,
        input: []const u8,
        start_pos: usize,
    ) ?Captures {
        if (start_pos > input.len) return null;

        // Fast-path: pure literal pattern
        if (prog.is_pure_literal and prog.literal_prefix != null) {
            const prefix = prog.literal_prefix.?;
            const caseless = prog.flags.caseless;
            if (literal_mod.findLiteralPos(input, prefix, start_pos, caseless)) |pos| {
                var caps = Captures{
                    .input = input,
                    .capture_count = 0,
                    .named_groups = &prog.named_groups,
                };
                caps.spans[0] = .{ .start = pos, .end = pos + prefix.len };
                return caps;
            }
            return null;
        }

        scratch.ensureThreadQueues() catch return null;

        const is_start_anchored = prog.is_start_anchored;

        // Fast-path: start-anchored pattern with prefix
        if (is_start_anchored) {
            if (prog.literal_prefix) |prefix| {
                if (!literal_mod.startsWith(input[start_pos..], prefix, prog.flags.caseless)) {
                    return null;
                }
            }
            return runAt(prog, scratch, input, start_pos);
        }

        // Scanning loop across starting positions
        var pos = start_pos;
        while (pos <= input.len) {
            // Literal prefix acceleration if available and unanchored
            if (prog.literal_prefix) |prefix| {
                if (prefix.len > 0) {
                    if (input.len < pos + prefix.len) return null;
                    if (literal_mod.findLiteralPos(input, prefix, pos, prog.flags.caseless)) |cand| {
                        pos = cand;
                    } else {
                        // Prefix never occurs in remainder of input
                        return null;
                    }
                }
            }

            if (runAt(prog, scratch, input, pos)) |caps| {
                return caps;
            }

            pos += 1;
        }

        return null;
    }

    fn runAt(
        prog: *const Prog,
        scratch: *Scratch,
        input: []const u8,
        start_pos: usize,
    ) ?Captures {
        var curr_len: usize = 0;
        var next_len: usize = 0;

        const gen = scratch.nextGeneration();
        const num_slots = @min(MAX_SLOTS, (prog.capture_count + 1) * 2);

        var init_slots: [MAX_SLOTS]usize = undefined;
        @memset(init_slots[0..num_slots], UNSET_SLOT);
        init_slots[0] = start_pos;

        var best_match_slots: ?[MAX_SLOTS]usize = null;

        // Add starting thread at start_pos
        addThread(
            prog,
            scratch,
            &scratch.curr_queue,
            &curr_len,
            &best_match_slots,
            prog.start_inst,
            &init_slots,
            input,
            start_pos,
            gen,
            num_slots,
        );

        // If an immediate match occurred at starting position (e.g. empty match or anchor)
        if (best_match_slots != null and curr_len == 0) {
            return makeCaptures(prog, input, best_match_slots.?);
        }

        var p = start_pos;
        while (p < input.len and curr_len > 0) {
            const c = input[p];
            next_len = 0;
            const next_gen = scratch.nextGeneration();

            for (scratch.curr_queue[0..curr_len]) |*t| {
                const inst = prog.insts[t.inst_id];
                var matched = false;

                switch (inst.op) {
                    .byte => {
                        if (inst.isCaseless()) {
                            matched = unicode_mod.eqlByteCaseless(c, @intCast(inst.data));
                        } else {
                            matched = (c == @as(u8, @intCast(inst.data)));
                        }
                    },
                    .byte_range => {
                        const lo: u8 = @intCast(inst.data & 0xFF);
                        const hi: u8 = @intCast((inst.data >> 8) & 0xFF);
                        if (inst.isCaseless()) {
                            const cl = unicode_mod.toLowerAscii(c);
                            matched = (cl >= unicode_mod.toLowerAscii(lo) and cl <= unicode_mod.toLowerAscii(hi));
                        } else {
                            matched = (c >= lo and c <= hi);
                        }
                    },
                    .any_byte => {
                        matched = true;
                    },
                    .any_non_nl => {
                        matched = (c != '\n');
                    },
                    .char_class => {
                        const cc = prog.char_classes[inst.data];
                        matched = cc.matchesByte(c);
                    },
                    .match => {
                        var match_slots: [MAX_SLOTS]usize = undefined;
                        @memcpy(match_slots[0..num_slots], t.slots[0..num_slots]);
                        best_match_slots = match_slots;
                        break;
                    },
                    else => {},
                }

                if (matched) {
                    addThread(
                        prog,
                        scratch,
                        &scratch.next_queue,
                        &next_len,
                        &best_match_slots,
                        inst.out1,
                        &t.slots,
                        input,
                        p + 1,
                        next_gen,
                        num_slots,
                    );
                }
            }

            // Swap queues
            const temp = scratch.curr_queue;
            scratch.curr_queue = scratch.next_queue;
            scratch.next_queue = temp;
            curr_len = next_len;

            p += 1;
        }

        // Process any remaining match threads at end of input
        for (scratch.curr_queue[0..curr_len]) |*t| {
            if (prog.insts[t.inst_id].op == .match) {
                var match_slots: [MAX_SLOTS]usize = undefined;
                @memcpy(match_slots[0..num_slots], t.slots[0..num_slots]);
                best_match_slots = match_slots;
                break;
            }
        }

        if (best_match_slots) |slots| {
            return makeCaptures(prog, input, slots);
        }

        return null;
    }

    fn addThread(
        prog: *const Prog,
        scratch: *Scratch,
        queue: *[]Thread,
        queue_len: *usize,
        best_match_slots: *?[MAX_SLOTS]usize,
        start_inst_id: u32,
        initial_slots: *const [MAX_SLOTS]usize,
        input: []const u8,
        p: usize,
        gen: u32,
        num_slots: usize,
    ) void {
        var inst_id = start_inst_id;
        var slots = initial_slots;
        while (true) {
            if (inst_id >= prog.insts.len) return;
            if (scratch.visited[inst_id] == gen) return;
            scratch.visited[inst_id] = gen;

            const inst = prog.insts[inst_id];
            switch (inst.op) {
                .match => {
                    var match_slots: [MAX_SLOTS]usize = undefined;
                    @memcpy(match_slots[0..num_slots], slots[0..num_slots]);
                    match_slots[1] = p;
                    if (queue_len.* == 0 and best_match_slots.* == null) {
                        best_match_slots.* = match_slots;
                    }
                    if (queue_len.* < queue.len) {
                        const target = &queue.*[queue_len.*];
                        target.inst_id = inst_id;
                        @memcpy(target.slots[0..num_slots], match_slots[0..num_slots]);
                        queue_len.* += 1;
                    }
                    return;
                },
                .nop => {
                    inst_id = inst.out1;
                    continue;
                },
                .alt => {
                    addThread(prog, scratch, queue, queue_len, best_match_slots, inst.out1, slots, input, p, gen, num_slots);
                    inst_id = inst.out2;
                    continue;
                },
                .capture_start, .capture_end => {
                    var new_slots: [MAX_SLOTS]usize = undefined;
                    @memcpy(new_slots[0..num_slots], slots[0..num_slots]);
                    const slot = inst.data;
                    if (slot < num_slots) {
                        new_slots[slot] = p;
                    }
                    addThread(prog, scratch, queue, queue_len, best_match_slots, inst.out1, &new_slots, input, p, gen, num_slots);
                    return;
                },
                .empty_width => {
                    const ew_type: EmptyWidthType = @fromBackingInt(@intCast(inst.data));
                    const holds = checkAssertion(ew_type, input, p);
                    if (holds) {
                        inst_id = inst.out1;
                        continue;
                    }
                    return;
                },
                .byte, .byte_range, .any_byte, .any_non_nl, .char_class => {
                    if (queue_len.* < queue.len) {
                        const target = &queue.*[queue_len.*];
                        target.inst_id = inst_id;
                        @memcpy(target.slots[0..num_slots], slots[0..num_slots]);
                        queue_len.* += 1;
                    }
                    return;
                },
                .fail => return,
            }
        }
    }

    fn checkAssertion(ew_type: EmptyWidthType, input: []const u8, p: usize) bool {
        switch (ew_type) {
            .start_text => return p == 0,
            .end_text => return p == input.len,
            .start_line => {
                if (p == 0) return true;
                return input[p - 1] == '\n';
            },
            .end_line => {
                if (p == input.len) return true;
                return input[p] == '\n' or (input[p] == '\r' and p + 1 < input.len and input[p + 1] == '\n');
            },
            .word_boundary => {
                const prev_word = p > 0 and charset_mod.isWordByte(input[p - 1]);
                const curr_word = p < input.len and charset_mod.isWordByte(input[p]);
                return prev_word != curr_word;
            },
            .non_word_boundary => {
                const prev_word = p > 0 and charset_mod.isWordByte(input[p - 1]);
                const curr_word = p < input.len and charset_mod.isWordByte(input[p]);
                return prev_word == curr_word;
            },
        }
    }

    fn makeCaptures(prog: *const Prog, input: []const u8, slots: [MAX_SLOTS]usize) Captures {
        var caps = Captures{
            .input = input,
            .capture_count = prog.capture_count,
            .named_groups = &prog.named_groups,
        };

        var i: usize = 0;
        while (i <= prog.capture_count and i < caps.spans.len) : (i += 1) {
            const start = slots[2 * i];
            const end = slots[2 * i + 1];
            if (start != UNSET_SLOT and end != UNSET_SLOT and start <= end) {
                caps.spans[i] = .{ .start = start, .end = end };
            } else {
                caps.spans[i] = null;
            }
        }

        return caps;
    }
};

test "engine basic matching" {
    const testing = std.testing;
    const parser_mod = @import("parser.zig");
    const compiler_mod = @import("compiler.zig");

    var p = parser_mod.Parser.init(testing.allocator, "[a-z]+@[a-z]+\\.com", .{});
    defer p.deinit();
    var ast = try p.parse();
    defer ast.deinit();

    var c = compiler_mod.Compiler.init(testing.allocator, .{});
    defer c.deinit();
    var prog = try c.compile(&ast);
    defer prog.deinit();

    var scratch = try Scratch.init(testing.allocator, prog.insts.len);
    defer scratch.deinit();

    const caps = Engine.search(&prog, &scratch, "contact: dev@example.com for info", 0);
    try testing.expect(caps != null);
    try testing.expectEqualStrings("dev@example.com", caps.?.slice());

    try testing.expect(Engine.matchExists(&prog, &scratch, "contact: dev@example.com for info", 0));
    try testing.expect(!Engine.matchExists(&prog, &scratch, "no email here", 0));
}

test "engine capture groups extraction" {
    const testing = std.testing;
    const parser_mod = @import("parser.zig");
    const compiler_mod = @import("compiler.zig");

    var p = parser_mod.Parser.init(testing.allocator, "(\\w+)=([0-9]+)", .{});
    defer p.deinit();
    var ast = try p.parse();
    defer ast.deinit();

    var c = compiler_mod.Compiler.init(testing.allocator, .{});
    defer c.deinit();
    var prog = try c.compile(&ast);
    defer prog.deinit();

    var scratch = try Scratch.init(testing.allocator, prog.insts.len);
    defer scratch.deinit();

    const caps = Engine.search(&prog, &scratch, "PORT=8080", 0);
    try testing.expect(caps != null);
    try testing.expectEqualStrings("PORT=8080", caps.?.slice());
    try testing.expectEqualStrings("PORT", caps.?.get(1).?);
    try testing.expectEqualStrings("8080", caps.?.get(2).?);

    try testing.expect(Engine.matchExists(&prog, &scratch, "PORT=8080", 0));
}

test "engine anchors" {
    const testing = std.testing;
    const parser_mod = @import("parser.zig");
    const compiler_mod = @import("compiler.zig");

    var p = parser_mod.Parser.init(testing.allocator, "^hello$", .{});
    defer p.deinit();
    var ast = try p.parse();
    defer ast.deinit();

    var c = compiler_mod.Compiler.init(testing.allocator, .{});
    defer c.deinit();
    var prog = try c.compile(&ast);
    defer prog.deinit();

    var scratch = try Scratch.init(testing.allocator, prog.insts.len);
    defer scratch.deinit();

    try testing.expect(Engine.search(&prog, &scratch, "hello", 0) != null);
    try testing.expect(Engine.search(&prog, &scratch, "hello world", 0) == null);

    try testing.expect(Engine.matchExists(&prog, &scratch, "hello", 0));
    try testing.expect(!Engine.matchExists(&prog, &scratch, "hello world", 0));
}
