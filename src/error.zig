const std = @import("std");

/// High-level categorization of regular-expression errors.
pub const ErrorCategory = enum {
    syntax,
    unsupported,
    limit,
    memory,
};

/// Specific error codes returned during regex compilation or matching.
pub const Error = error{
    // Syntax errors
    UnexpectedCharacter,
    UnterminatedGroup,
    UnclosedCharacterClass,
    UnterminatedEscape,
    InvalidEscapeSequence,
    InvalidCharacterRange,
    InvalidRepetitionRange,
    InvalidQuantifier,
    EmptyRepetition,
    MissingGroupName,
    InvalidGroupName,
    DuplicateGroupName,
    EmptyClass,

    // Limits
    PatternTooLong,
    NestingTooDeep,
    ProgramTooLarge,
    TooManyCaptures,
    RepetitionLimitExceeded,

    // Unsupported constructs
    UnsupportedBackreference,
    UnsupportedLookaround,
    UnsupportedConstruct,

    // Resource / Memory
    OutOfMemory,
};

/// Human-readable diagnostic details describing where and why compilation failed.
pub const Diagnostic = struct {
    err: Error,
    category: ErrorCategory,
    offset: usize = 0,
    line: usize = 1,
    column: usize = 1,
    message: []const u8 = "",

    pub fn write(self: Diagnostic, writer: anytype) !void {
        try writer.print("{s} error at offset {} (line {}, column {}): {s}", .{
            @tagName(self.category),
            self.offset,
            self.line,
            self.column,
            self.message,
        });
    }

    pub fn printBuf(self: Diagnostic, buf: []u8) ![]const u8 {
        return std.fmt.bufPrint(buf, "{s} error at offset {} (line {}, column {}): {s}", .{
            @tagName(self.category),
            self.offset,
            self.line,
            self.column,
            self.message,
        });
    }
};

test "diagnostic printBuf" {
    const diag = Diagnostic{
        .err = error.UnterminatedGroup,
        .category = .syntax,
        .offset = 4,
        .line = 1,
        .column = 5,
        .message = "unclosed group parenthesis",
    };
    var buf: [128]u8 = undefined;
    const msg = try diag.printBuf(&buf);
    try std.testing.expectEqualStrings("syntax error at offset 4 (line 1, column 5): unclosed group parenthesis", msg);
}
