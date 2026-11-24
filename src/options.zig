const std = @import("std");

/// Number of capture groups addressable by the inline `Captures` storage.
/// Group 0 is the full match, leaving 31 user-visible groups in 32 slots.
pub const max_inline_capture_groups: usize = 31;

/// Safety and resource limits to defend against algorithmic denial of service (ReDoS).
pub const Limits = struct {
    /// Maximum allowed pattern length in bytes.
    maxPatternLength: usize = 65536,

    /// Maximum group/parenthesis nesting depth during parsing.
    maxNestingDepth: usize = 256,

    /// Maximum compiled instruction count in the bytecode program.
    maxProgramSize: usize = 65536,

    /// Maximum number of capturing groups allowed in a pattern.
    /// Values above `max_inline_capture_groups` are clamped to keep every
    /// capture addressable by the inline `Captures` storage.
    maxCaptures: usize = max_inline_capture_groups,

    /// Maximum repetition count in bounded repetitions {min,max}.
    maxRepetition: usize = 1000,
};

/// Options for compiling a regular expression pattern.
pub const CompileOptions = struct {
    /// Case-insensitive matching ('i' flag).
    caseInsensitive: bool = false,

    /// Multiline mode ('m' flag): '^' and '$' match at line boundaries ('\n').
    multiline: bool = false,

    /// Dot-all mode ('s' flag): '.' matches any character including newline '\n'.
    dotAll: bool = false,

    /// Inverts the greediness of quantifiers ('U' flag).
    ungreedy: bool = false,

    /// Restrict shorthand classes (\d, \w, \s) and word boundaries (\b, \B) to
    /// ASCII. By default these are Unicode-aware. Does not affect dot, explicit
    /// character classes, or \p{…} property classes.
    ascii: bool = false,

    /// Extended (verbose) mode ('x' flag): ignores unescaped ASCII whitespace
    /// and `#` line comments between tokens. Whitespace inside bracket
    /// expressions and inside `\Q…\E` quotes remains significant.
    extended: bool = false,

    /// Safety and memory resource limits.
    limits: Limits = .{},
};

/// Standard CompileOptions alias.
pub const Options = CompileOptions;

/// Internal packed representation of compilation flags.
pub const CompileFlags = packed struct {
    caseless: bool = false,
    multiline: bool = false,
    dotAll: bool = false,
    ungreedy: bool = false,
    ascii: bool = false,
    extended: bool = false,
    _padding: u2 = 0,

    pub fn fromCompileOptions(opts: CompileOptions) CompileFlags {
        return .{
            .caseless = opts.caseInsensitive,
            .multiline = opts.multiline,
            .dotAll = opts.dotAll,
            .ungreedy = opts.ungreedy,
            .ascii = opts.ascii,
            .extended = opts.extended,
        };
    }
};

/// Options for single-match and search checks (isMatch, find, captures).
pub const MatchOptions = struct {
    startOffset: usize = 0,
};

/// Options for collecting all matches (findAll).
pub const FindAllOptions = struct {
    startOffset: usize = 0,
    maxMatches: ?usize = null,
};

/// Options for single replacement (replace).
pub const ReplaceOptions = struct {
    startOffset: usize = 0,
};

/// Options for replacing all matches (replaceAll).
pub const ReplaceAllOptions = struct {
    startOffset: usize = 0,
    maxReplacements: ?usize = null,
};

/// Options for splitting text by regex matches (split).
pub const SplitOptions = struct {
    startOffset: usize = 0,
    /// Maximum number of delimiters to consume. The unconsumed remainder of the
    /// input becomes the final field, so `maxSplits = n` yields at most `n + 1`
    /// fields. `0` performs no splits; `null` splits on every match.
    maxSplits: ?usize = null,
};

/// Options for counting matches (count).
pub const CountOptions = struct {
    startOffset: usize = 0,
    maxMatches: ?usize = null,
};

/// Options for streaming iteration (iterator, capturesIterator).
pub const IterateOptions = struct {
    startOffset: usize = 0,
};

test "options defaults and inline initialization" {
    const default_opts: CompileOptions = .{};
    try std.testing.expect(!default_opts.caseInsensitive);
    try std.testing.expect(!default_opts.multiline);
    try std.testing.expectEqual(@as(usize, 65536), default_opts.limits.maxPatternLength);

    const custom: CompileOptions = .{
        .caseInsensitive = true,
        .multiline = true,
        .limits = .{ .maxPatternLength = 1024 },
    };
    try std.testing.expect(custom.caseInsensitive);
    try std.testing.expect(custom.multiline);
    try std.testing.expectEqual(@as(usize, 1024), custom.limits.maxPatternLength);

    const match_opts: MatchOptions = .{};
    try std.testing.expectEqual(@as(usize, 0), match_opts.startOffset);

    const find_all_opts: FindAllOptions = .{ .maxMatches = 50 };
    try std.testing.expectEqual(@as(?usize, 50), find_all_opts.maxMatches);
}
