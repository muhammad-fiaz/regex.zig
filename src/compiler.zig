const std = @import("std");
const ast_mod = @import("ast.zig");
const Ast = ast_mod.Ast;
const Node = ast_mod.Node;
const Repetition = ast_mod.Repetition;
const automaton_mod = @import("automaton.zig");
const Inst = automaton_mod.Inst;
const Opcode = automaton_mod.Opcode;
const EmptyWidthType = automaton_mod.EmptyWidthType;
const Prog = automaton_mod.Prog;
const charset_mod = @import("charset.zig");
const CharClass = charset_mod.CharClass;
const options_mod = @import("options.zig");
const Options = options_mod.Options;
const CompileFlags = options_mod.CompileFlags;
const error_mod = @import("error.zig");
const Error = error_mod.Error;
const unicode_mod = @import("unicode.zig");

/// NFA Fragment during compilation representing a subgraph with dangling exit pointers.
const Frag = struct {
    start: u32,
    /// List of instruction indices whose out1 or out2 should be patched to the next instruction.
    out_patches: []const u32,
};

pub const Compiler = struct {
    allocator: std.mem.Allocator,
    patch_arena: std.heap.ArenaAllocator,
    options: Options,
    flags: CompileFlags,
    insts: std.ArrayList(Inst) = .empty,
    char_classes: std.ArrayList(CharClass) = .empty,

    pub fn init(allocator: std.mem.Allocator, options: Options) Compiler {
        return .{
            .allocator = allocator,
            .patch_arena = std.heap.ArenaAllocator.init(allocator),
            .options = options,
            .flags = CompileFlags.fromCompileOptions(options),
            .insts = .empty,
            .char_classes = .empty,
        };
    }

    pub fn deinit(self: *Compiler) void {
        self.patch_arena.deinit();
        self.insts.deinit(self.allocator);
        for (self.char_classes.items) |*cc| {
            cc.deinit(self.allocator);
        }
        self.char_classes.deinit(self.allocator);
        self.* = undefined;
    }

    fn addInst(self: *Compiler, inst: Inst) Error!u32 {
        if (self.insts.items.len >= self.options.limits.maxProgramSize) {
            return error.ProgramTooLarge;
        }
        const idx: u32 = @intCast(self.insts.items.len);
        try self.insts.append(self.allocator, inst);
        return idx;
    }

    fn patch(self: *Compiler, patch_list: []const u32, target: u32) void {
        for (patch_list) |idx| {
            if (self.insts.items[idx].out1 == 0) {
                self.insts.items[idx].out1 = target;
            } else if (self.insts.items[idx].out2 == 0) {
                self.insts.items[idx].out2 = target;
            }
        }
    }

    fn appendPatches(self: *Compiler, a: []const u32, b: []const u32) Error![]const u32 {
        if (a.len == 0) return b;
        if (b.len == 0) return a;
        const arena = self.patch_arena.allocator();
        const combined = try arena.alloc(u32, a.len + b.len);
        @memcpy(combined[0..a.len], a);
        @memcpy(combined[a.len..], b);
        return combined;
    }

    fn makePatch1(self: *Compiler, idx: u32) Error![]const u32 {
        const arena = self.patch_arena.allocator();
        const list = try arena.alloc(u32, 1);
        list[0] = idx;
        return list;
    }

    fn freePatches(self: *Compiler, list: []const u32) void {
        _ = self;
        _ = list;
    }

    pub fn compile(self: *Compiler, ast: *const Ast) Error!Prog {
        try self.insts.ensureTotalCapacity(self.allocator, 64);
        try self.char_classes.ensureTotalCapacity(self.allocator, 8);

        // Entire match is capture group 0
        const start_cap0 = try self.addInst(.{
            .op = .capture_start,
            .data = 0, // slot 0 = start of full match
        });

        const root_frag = try self.compileNode(ast.root);

        // Patch start_cap0 to root_frag.start
        self.insts.items[start_cap0].out1 = root_frag.start;

        const end_cap0 = try self.addInst(.{
            .op = .capture_end,
            .data = 1, // slot 1 = end of full match
        });

        self.patch(root_frag.out_patches, end_cap0);
        self.freePatches(root_frag.out_patches);

        const match_inst = try self.addInst(.{
            .op = .match,
        });

        self.insts.items[end_cap0].out1 = match_inst;

        // Clone named groups
        var named_map: std.StringHashMapUnmanaged(usize) = .empty;
        var it = ast.named_groups.iterator();
        while (it.next()) |entry| {
            const key_copy = try self.allocator.dupe(u8, entry.key_ptr.*);
            try named_map.put(self.allocator, key_copy, entry.value_ptr.*);
        }

        // Check for pure literal or literal prefix
        const is_pure = self.checkPureLiteral(ast.root);
        const prefix = try self.extractLiteralPrefix(ast.root);

        const owned_insts = try self.insts.toOwnedSlice(self.allocator);
        const owned_ccs = try self.char_classes.toOwnedSlice(self.allocator);

        const is_anchored = (self.insts.items.len > 1 and
            self.insts.items[root_frag.start].op == .empty_width and
            @as(EmptyWidthType, @fromBackingInt(@intCast(self.insts.items[root_frag.start].data))) == .start_text);

        return Prog{
            .insts = owned_insts,
            .char_classes = owned_ccs,
            .capture_count = ast.capture_count,
            .named_groups = named_map,
            .flags = self.flags,
            .start_inst = start_cap0,
            .literal_prefix = prefix,
            .is_pure_literal = is_pure,
            .is_start_anchored = is_anchored,
            .allocator = self.allocator,
        };
    }

    fn compileNode(self: *Compiler, node: *const Node) Error!Frag {
        switch (node.*) {
            .empty => {
                const nop = try self.addInst(.{ .op = .nop });
                return Frag{
                    .start = nop,
                    .out_patches = try self.makePatch1(nop),
                };
            },
            .literal => |lit| {
                if (lit.len == 0) {
                    const nop = try self.addInst(.{ .op = .nop });
                    return Frag{
                        .start = nop,
                        .out_patches = try self.makePatch1(nop),
                    };
                }

                if (!self.flags.caseless) {
                    var first_inst: ?u32 = null;
                    var prev_inst: ?u32 = null;

                    for (lit) |b| {
                        const inst = try self.addInst(.{
                            .op = .byte,
                            .flags = 0,
                            .data = b,
                        });
                        if (prev_inst) |p| {
                            self.insts.items[p].out1 = inst;
                        } else {
                            first_inst = inst;
                        }
                        prev_inst = inst;
                    }

                    return Frag{
                        .start = first_inst.?,
                        .out_patches = try self.makePatch1(prev_inst.?),
                    };
                }

                // Caseless matching: UTF-8 aware
                var frags: std.ArrayList(Frag) = .empty;
                defer frags.deinit(self.allocator);

                var off: usize = 0;
                while (off < lit.len) {
                    const dec = unicode_mod.decodeUtf8Char(lit[off..]) orelse {
                        const b = lit[off];
                        off += 1;
                        const inst = try self.addInst(.{ .op = .byte, .flags = 1, .data = b });
                        try frags.append(self.allocator, .{ .start = inst, .out_patches = try self.makePatch1(inst) });
                        continue;
                    };
                    off += dec.len;

                    if (dec.cp < 128) {
                        const inst = try self.addInst(.{ .op = .byte, .flags = 1, .data = @intCast(dec.cp) });
                        try frags.append(self.allocator, .{ .start = inst, .out_patches = try self.makePatch1(inst) });
                    } else if (unicode_mod.toOtherCase(dec.cp)) |other_cp| {
                        var b1: [4]u8 = undefined;
                        const l1 = std.unicode.utf8Encode(dec.cp, &b1) catch 1;
                        var b2: [4]u8 = undefined;
                        const l2 = std.unicode.utf8Encode(other_cp, &b2) catch 1;

                        const f1 = try self.compileByteSlice(b1[0..l1]);
                        const f2 = try self.compileByteSlice(b2[0..l2]);

                        const alt_inst = try self.addInst(.{ .op = .alt });
                        self.insts.items[alt_inst].out1 = f1.start;
                        self.insts.items[alt_inst].out2 = f2.start;

                        const combined = try self.appendPatches(f1.out_patches, f2.out_patches);
                        self.freePatches(f1.out_patches);
                        self.freePatches(f2.out_patches);

                        try frags.append(self.allocator, .{ .start = alt_inst, .out_patches = combined });
                    } else {
                        var b1: [4]u8 = undefined;
                        const l1 = std.unicode.utf8Encode(dec.cp, &b1) catch 1;
                        const f = try self.compileByteSlice(b1[0..l1]);
                        try frags.append(self.allocator, f);
                    }
                }

                var res = frags.items[0];
                var k: usize = 1;
                while (k < frags.items.len) : (k += 1) {
                    const next_frag = frags.items[k];
                    self.patch(res.out_patches, next_frag.start);
                    self.freePatches(res.out_patches);
                    res = .{
                        .start = res.start,
                        .out_patches = next_frag.out_patches,
                    };
                }
                return res;
            },
            .byte_range => |br| {
                const inst = try self.addInst(.{
                    .op = .byte_range,
                    .flags = if (self.flags.caseless) 1 else 0,
                    .data = @as(u32, br.min) | (@as(u32, br.max) << 8),
                });
                return Frag{
                    .start = inst,
                    .out_patches = try self.makePatch1(inst),
                };
            },
            .char_class => |cc| {
                const cc_copy = try CharClass.init(self.allocator, cc.ranges, cc.is_negated);
                const cc_idx: u32 = @intCast(self.char_classes.items.len);
                try self.char_classes.append(self.allocator, cc_copy);

                const inst = try self.addInst(.{
                    .op = .char_class,
                    .data = cc_idx,
                });
                return Frag{
                    .start = inst,
                    .out_patches = try self.makePatch1(inst),
                };
            },
            .any_char => |dot_all| {
                const inst = try self.addInst(.{
                    .op = if (dot_all or self.flags.dotAll) .any_byte else .any_non_nl,
                });
                return Frag{
                    .start = inst,
                    .out_patches = try self.makePatch1(inst),
                };
            },
            .anchor => |anc| {
                const empty_type: EmptyWidthType = switch (anc) {
                    .start_text => .start_text,
                    .end_text => .end_text,
                    .start_line => .start_line,
                    .end_line => .end_line,
                    .word_boundary => .word_boundary,
                    .non_word_boundary => .non_word_boundary,
                };
                const inst = try self.addInst(.{
                    .op = .empty_width,
                    .data = @backingInt(empty_type),
                });
                return Frag{
                    .start = inst,
                    .out_patches = try self.makePatch1(inst),
                };
            },
            .concat => |children| {
                if (children.len == 0) {
                    const nop = try self.addInst(.{ .op = .nop });
                    return Frag{
                        .start = nop,
                        .out_patches = try self.makePatch1(nop),
                    };
                }

                var current_frag = try self.compileNode(children[0]);
                var i: usize = 1;
                while (i < children.len) : (i += 1) {
                    const next_frag = try self.compileNode(children[i]);
                    self.patch(current_frag.out_patches, next_frag.start);
                    self.freePatches(current_frag.out_patches);
                    current_frag = .{
                        .start = current_frag.start,
                        .out_patches = next_frag.out_patches,
                    };
                }
                return current_frag;
            },
            .alt => |branches| {
                if (branches.len == 0) {
                    const nop = try self.addInst(.{ .op = .nop });
                    return Frag{
                        .start = nop,
                        .out_patches = try self.makePatch1(nop),
                    };
                }
                if (branches.len == 1) {
                    return self.compileNode(branches[0]);
                }

                // Compile right-associated binary alternatives
                return self.compileAltSlice(branches);
            },
            .group => |grp| {
                if (grp.index) |idx| {
                    const cap_start = try self.addInst(.{
                        .op = .capture_start,
                        .data = @intCast(2 * idx),
                    });
                    const child_frag = try self.compileNode(grp.child);
                    self.insts.items[cap_start].out1 = child_frag.start;

                    const cap_end = try self.addInst(.{
                        .op = .capture_end,
                        .data = @intCast(2 * idx + 1),
                    });
                    self.patch(child_frag.out_patches, cap_end);
                    self.freePatches(child_frag.out_patches);

                    return Frag{
                        .start = cap_start,
                        .out_patches = try self.makePatch1(cap_end),
                    };
                } else {
                    return self.compileNode(grp.child);
                }
            },
            .quantifier => |q| {
                return self.compileQuantifier(q.child, q.rep);
            },
        }
    }

    fn compileAltSlice(self: *Compiler, branches: []*Node) Error!Frag {
        const alt_inst = try self.addInst(.{
            .op = .alt,
        });

        const left_frag = try self.compileNode(branches[0]);
        self.insts.items[alt_inst].out1 = left_frag.start;

        var right_frag: Frag = undefined;
        if (branches.len == 2) {
            right_frag = try self.compileNode(branches[1]);
        } else {
            right_frag = try self.compileAltSlice(branches[1..]);
        }
        self.insts.items[alt_inst].out2 = right_frag.start;

        const combined_patches = try self.appendPatches(left_frag.out_patches, right_frag.out_patches);
        self.freePatches(left_frag.out_patches);
        self.freePatches(right_frag.out_patches);

        return Frag{
            .start = alt_inst,
            .out_patches = combined_patches,
        };
    }

    fn compileQuantifier(self: *Compiler, child: *Node, rep: Repetition) Error!Frag {
        // Zero-or-more: * or *?
        if (rep.min == 0 and rep.max == null) {
            const alt_inst = try self.addInst(.{ .op = .alt });
            const child_frag = try self.compileNode(child);

            if (rep.greedy) {
                self.insts.items[alt_inst].out1 = child_frag.start;
                // out2 is patched to exit
            } else {
                self.insts.items[alt_inst].out2 = child_frag.start;
                // out1 is patched to exit
            }

            self.patch(child_frag.out_patches, alt_inst);
            self.freePatches(child_frag.out_patches);

            return Frag{
                .start = alt_inst,
                .out_patches = try self.makePatch1(alt_inst),
            };
        }

        // One-or-more: + or +?
        if (rep.min == 1 and rep.max == null) {
            const child_frag = try self.compileNode(child);
            const alt_inst = try self.addInst(.{ .op = .alt });

            if (rep.greedy) {
                self.insts.items[alt_inst].out1 = child_frag.start;
            } else {
                self.insts.items[alt_inst].out2 = child_frag.start;
            }

            self.patch(child_frag.out_patches, alt_inst);
            self.freePatches(child_frag.out_patches);

            return Frag{
                .start = child_frag.start,
                .out_patches = try self.makePatch1(alt_inst),
            };
        }

        // Zero-or-one: ? or ??
        if (rep.min == 0 and rep.max != null and rep.max.? == 1) {
            const alt_inst = try self.addInst(.{ .op = .alt });
            const child_frag = try self.compileNode(child);

            if (rep.greedy) {
                self.insts.items[alt_inst].out1 = child_frag.start;
            } else {
                self.insts.items[alt_inst].out2 = child_frag.start;
            }

            const alt_patches = try self.makePatch1(alt_inst);
            defer self.freePatches(alt_patches);

            const combined = try self.appendPatches(child_frag.out_patches, alt_patches);
            self.freePatches(child_frag.out_patches);

            return Frag{
                .start = alt_inst,
                .out_patches = combined,
            };
        }

        // Bounded repetition: {min, max}
        var frags: std.ArrayList(Frag) = .empty;
        defer frags.deinit(self.allocator);

        // Required min repetitions
        var i: usize = 0;
        while (i < rep.min) : (i += 1) {
            const f = try self.compileNode(child);
            try frags.append(self.allocator, f);
        }

        // Optional remaining repetitions up to max
        if (rep.max) |max_val| {
            var j = rep.min;
            while (j < max_val) : (j += 1) {
                const opt_frag = try self.compileQuantifier(child, .{ .min = 0, .max = 1, .greedy = rep.greedy });
                try frags.append(self.allocator, opt_frag);
            }
        } else {
            // Unbounded: {min,}
            const star_frag = try self.compileQuantifier(child, .{ .min = 0, .max = null, .greedy = rep.greedy });
            try frags.append(self.allocator, star_frag);
        }

        if (frags.items.len == 0) {
            const nop = try self.addInst(.{ .op = .nop });
            return Frag{
                .start = nop,
                .out_patches = try self.makePatch1(nop),
            };
        }

        var res = frags.items[0];
        var k: usize = 1;
        while (k < frags.items.len) : (k += 1) {
            const next_frag = frags.items[k];
            self.patch(res.out_patches, next_frag.start);
            self.freePatches(res.out_patches);
            res = .{
                .start = res.start,
                .out_patches = next_frag.out_patches,
            };
        }
        return res;
    }

    fn checkPureLiteral(self: *const Compiler, node: *const Node) bool {
        switch (node.*) {
            .literal => |lit| {
                if (self.flags.caseless) {
                    for (lit) |b| {
                        if (b > 127) return false;
                    }
                }
                return true;
            },
            .concat => |children| {
                for (children) |c| {
                    if (c.* != .literal) return false;
                    if (self.flags.caseless) {
                        for (c.literal) |b| {
                            if (b > 127) return false;
                        }
                    }
                }
                return true;
            },
            .group => |grp| {
                return self.checkPureLiteral(grp.child);
            },
            else => return false,
        }
    }

    fn compileByteSlice(self: *Compiler, bytes: []const u8) Error!Frag {
        var first_inst: ?u32 = null;
        var prev_inst: ?u32 = null;
        for (bytes) |b| {
            const inst = try self.addInst(.{
                .op = .byte,
                .flags = 0,
                .data = b,
            });
            if (prev_inst) |p| {
                self.insts.items[p].out1 = inst;
            } else {
                first_inst = inst;
            }
            prev_inst = inst;
        }
        return Frag{
            .start = first_inst.?,
            .out_patches = try self.makePatch1(prev_inst.?),
        };
    }

    fn appendLiteralBytes(self: *Compiler, lit: []const u8, prefix_list: *std.ArrayList(u8)) Error!bool {
        if (!self.flags.caseless) {
            try prefix_list.appendSlice(self.allocator, lit);
            return true;
        } else {
            for (lit) |b| {
                if (b > 127) return false;
                try prefix_list.append(self.allocator, b);
            }
            return true;
        }
    }

    fn extractPrefixFromNode(self: *Compiler, node: *const Node, prefix_list: *std.ArrayList(u8)) Error!bool {
        switch (node.*) {
            .anchor => |a| {
                if (a == .start_text or a == .start_line) {
                    return true;
                }
                return false;
            },
            .literal => |lit| {
                return self.appendLiteralBytes(lit, prefix_list);
            },
            .group => |grp| {
                return self.extractPrefixFromNode(grp.child, prefix_list);
            },
            .quantifier => |q| {
                if (q.rep.min >= 1) {
                    _ = try self.extractPrefixFromNode(q.child, prefix_list);
                }
                return false;
            },
            .concat => |children| {
                for (children) |c| {
                    const cont = try self.extractPrefixFromNode(c, prefix_list);
                    if (!cont) break;
                }
                return false;
            },
            else => return false,
        }
    }

    fn extractLiteralPrefix(self: *Compiler, node: *const Node) Error!?[]const u8 {
        var prefix_list: std.ArrayList(u8) = .empty;
        defer prefix_list.deinit(self.allocator);

        _ = try self.extractPrefixFromNode(node, &prefix_list);

        if (prefix_list.items.len > 0) {
            return try prefix_list.toOwnedSlice(self.allocator);
        }
        return null;
    }
};

test "compiler simple literal" {
    const testing = std.testing;
    const parser_mod = @import("parser.zig");
    var p = parser_mod.Parser.init(testing.allocator, "abc", .{});
    defer p.deinit();

    var ast = try p.parse();
    defer ast.deinit();

    var c = Compiler.init(testing.allocator, .{});
    defer c.deinit();

    var prog = try c.compile(&ast);
    defer prog.deinit();

    try testing.expect(prog.is_pure_literal);
    try testing.expect(prog.literal_prefix != null);
    try testing.expectEqualStrings("abc", prog.literal_prefix.?);
}
