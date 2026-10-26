const std = @import("std");
const charset = @import("charset.zig");
const Range = charset.Range;
const CharClass = charset.CharClass;

/// Anchor assertion types.
pub const AnchorType = enum {
    start_text, // \A or ^ (when not multiline)
    end_text, // \z or $ (when not multiline)
    start_line, // ^ in multiline mode
    end_line, // $ in multiline mode
    word_boundary, // \b
    non_word_boundary, // \B
};

/// Repetition quantifier information.
pub const Repetition = struct {
    min: usize,
    max: ?usize, // null means unbounded (e.g. * or +)
    greedy: bool,
};

/// Capturing or non-capturing group information.
pub const Group = struct {
    index: ?usize, // null for non-capturing (?:...), 1-based index for capturing
    name: ?[]const u8, // optional group name
    child: *Node,
};

/// Single AST node.
pub const Node = union(enum) {
    empty: void,
    literal: []const u8,
    byte_range: struct { min: u8, max: u8 },
    char_class: CharClass,
    any_char: bool, // true if dotAll (matches newline)
    anchor: AnchorType,
    concat: []*Node,
    alt: []*Node,
    group: Group,
    quantifier: struct {
        child: *Node,
        rep: Repetition,
    },

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .char_class => |*cc| cc.deinit(allocator),
            else => {},
        }
    }
};

/// AST container that owns the arena holding all nodes.
pub const Ast = struct {
    arena: std.heap.ArenaAllocator,
    root: *Node,
    capture_count: usize,
    named_groups: std.StringHashMapUnmanaged(usize),

    pub fn init(allocator: std.mem.Allocator, root: *Node, capture_count: usize) Ast {
        return .{
            .arena = std.heap.ArenaAllocator.init(allocator),
            .root = root,
            .capture_count = capture_count,
            .named_groups = .empty,
        };
    }

    pub fn deinit(self: *Ast) void {
        self.named_groups.deinit(self.arena.allocator());
        self.arena.deinit();
        self.* = undefined;
    }
};

test "ast node creation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const node = try alloc.create(Node);
    node.* = .{ .literal = "hello" };
    try std.testing.expectEqualStrings("hello", node.literal);
}
