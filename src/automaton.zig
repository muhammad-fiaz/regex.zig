const std = @import("std");
const charset = @import("charset.zig");
const CharClass = charset.CharClass;
const options_mod = @import("options.zig");
const CompileFlags = options_mod.CompileFlags;

/// Instruction opcodes executed by the regex virtual machine.
pub const Opcode = enum(u8) {
    /// Pattern match reached.
    match,

    /// Match exact byte in data.
    byte,

    /// Match byte in range [data & 0xFF, (data >> 8) & 0xFF].
    byte_range,

    /// Match any byte (used by '.' in dotAll mode).
    any_byte,

    /// Match any byte except newline '\n' (used by '.' in default mode).
    any_non_nl,

    /// Match a character class referenced by index in data.
    char_class,

    /// Alternation branch: out1 is explored first (higher priority), then out2.
    alt,

    /// Record capture group start: slot 2 * group.
    capture_start,

    /// Record capture group end: slot 2 * group + 1.
    capture_end,

    /// Zero-width assertion check (^, $, \A, \z, \b, \B).
    empty_width,

    /// No-operation forwarding jump to out1.
    nop,

    /// Failure instruction that never matches.
    fail,
};

/// Empty-width assertion sub-types.
pub const EmptyWidthType = enum(u8) {
    start_text,
    end_text,
    start_line,
    end_line,
    word_boundary,
    non_word_boundary,
};

/// Virtual machine instruction.
pub const Inst = struct {
    op: Opcode,
    flags: u8 = 0, // 1 = caseless
    data: u32 = 0,
    out1: u32 = 0,
    out2: u32 = 0,

    pub fn isCaseless(self: Inst) bool {
        return (self.flags & 1) != 0;
    }
};

/// Compiled regular expression program.
pub const Prog = struct {
    insts: []const Inst,
    char_classes: []const CharClass,
    capture_count: usize,
    named_groups: std.StringHashMapUnmanaged(usize),
    flags: CompileFlags,
    start_inst: u32,
    literal_prefix: ?[]const u8,
    is_pure_literal: bool,
    is_start_anchored: bool = false,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Prog) void {
        self.allocator.free(self.insts);
        for (self.char_classes) |cc| {
            self.allocator.free(cc.ranges);
        }
        self.allocator.free(self.char_classes);
        if (self.literal_prefix) |lp| {
            self.allocator.free(lp);
        }

        var it = self.named_groups.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.named_groups.deinit(self.allocator);
        self.* = undefined;
    }
};

test "instruction initialization" {
    const inst = Inst{
        .op = .byte,
        .flags = 1,
        .data = 'a',
        .out1 = 1,
    };
    try std.testing.expectEqual(Opcode.byte, inst.op);
    try std.testing.expect(inst.isCaseless());
    try std.testing.expectEqual(@as(u32, 'a'), inst.data);
}
