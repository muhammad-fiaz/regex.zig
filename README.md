<div align="center">

# Regex.zig

<a href="https://muhammad-fiaz.github.io/regex.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io%2Fregex.zig-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.17.0-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/regex.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/regex.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/regex.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/regex.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/regex.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/regex.zig/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/regex.zig/actions/workflows/github-code-scanning/codeql"><img src="https://github.com/muhammad-fiaz/regex.zig/actions/workflows/github-code-scanning/codeql/badge.svg?branch=main" alt="CodeQL"></a>
<a href="https://github.com/muhammad-fiaz/regex.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/regex.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-GitHub-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://hits.sh/muhammad-fiaz/regex.zig/"><img src="https://hits.sh/muhammad-fiaz/regex.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A Blazing-Fast, Native Regular Expression Engine for Zig.</em></p>

<b><a href="https://muhammad-fiaz.github.io/regex.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/regex.zig/api/regex">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/regex.zig/guide/getting-started">Quick Start</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

`regex.zig` is a modern, high-performance, linear-time regular expression engine implemented natively in **Zig 0.17.0** from first principles. It provides everything needed to build fast and reliable pattern-matching into networked applications, CLI tools, web services, compilers, parsers, and text processing pipelines.

> [!TIP]
> If you build with regex.zig, make sure to give it a star.

## Why regex.zig

> [!IMPORTANT]
> `regex.zig` is a native Zig regular expression engine designed for speed, safety, and predictability. Powered by a non-backtracking PikeVM, it guarantees strict $O(M \times N)$ linear-time execution with complete immunity against ReDoS attacks. It requires zero C or libc dependencies, featuring SIMD literal prefilters, 32 inline capture slots, named groups `(?P<name>...)`, full UTF-8 support, streaming iterators, and an explicit inline `.{}` options API with zero hidden allocations.

**Related Zig projects:**

- For **HTTP client & server**, check out **[httpx.zig](https://github.com/muhammad-fiaz/httpx.zig)**.
- For **Env.zig** (.env parsing), check out **[env.zig](https://github.com/muhammad-fiaz/env.zig)**.
- For **TUI** support, check out **[tui.zig](https://github.com/muhammad-fiaz/tui.zig)**.
- For **ZON file format** support, check out **[zon.zig](https://github.com/muhammad-fiaz/zon.zig)**.
- For **Spinners/loading/progress bar** support, check out **[loaders.zig](https://github.com/muhammad-fiaz/loaders.zig)**.
- For **Terminal colors & text styles** support, check out **[tint.zig](https://github.com/muhammad-fiaz/tint.zig)**.
- For **MCP** support, check out **[mcp.zig](https://github.com/muhammad-fiaz/mcp.zig)**.
- For **API framework** support, check out **[api.zig](https://github.com/muhammad-fiaz/api.zig)**.
- For **Web framework** support, check out **[zix](https://github.com/muhammad-fiaz/zix)**.
- For **archive/compression** support, check out **[archive.zig](https://github.com/muhammad-fiaz/archive.zig)**.
- For **compression file format** support, check out **[zigx](https://github.com/muhammad-fiaz/zigx)**.
- For **CUDA** support, check out **[cuda.zig](https://github.com/muhammad-fiaz/cuda.zig)**.
- For **Simplified build.zig config** support, check out **[buildx.zig](https://github.com/muhammad-fiaz/buildx.zig)**.
- For **SQLite (zig-native implementation)** support, check out **[sqlite.zig](https://github.com/muhammad-fiaz/sqlite.zig)**.
- For **File downloading** support, check out **[downloader.zig](https://github.com/muhammad-fiaz/downloader.zig)**.
- For **update checker/auto-updater** support, check out **[updater.zig](https://github.com/muhammad-fiaz/updater.zig)**.
- For **Numerical computing** support, check out **[num.zig](https://github.com/muhammad-fiaz/num.zig)**.
- For **Logging** support, check out **[logly.zig](https://github.com/muhammad-fiaz/logly.zig)**.
- For **Data validation and serialization** support, check out **[zigantic](https://github.com/muhammad-fiaz/zigantic)**.
- For **UUID** support, check out **[uuid.zig](https://github.com/muhammad-fiaz/uuid.zig)**.
- For **Key-Value database** support, check out **[zkv.zig](https://github.com/muhammad-fiaz/zkv.zig)**.
- For **Terminal color & text styles** support, check out **[hint.zig](https://github.com/muhammad-fiaz/hint.zig)**.
- For **Brotli compression** support, check out **[brotli.zig](https://github.com/muhammad-fiaz/brotli.zig)**.
- For **Zstd compression** support, check out **[zstd.zig](https://github.com/muhammad-fiaz/zstd.zig)**.
- For **Tree-Sitter** support, check out **[tree-sitter.zig](https://github.com/muhammad-fiaz/tree-sitter.zig)**.
- For **Regex** support, check out **[regex.zig](https://github.com/muhammad-fiaz/regex.zig)**

---

<details>
<summary><strong>Features</strong> (click to expand)</summary>

| Feature | Description |
|---------|-------------|
| **Linear-Time PikeVM** | Non-backtracking virtual machine executing an in-order Thompson NFA across dual lockstep queues with $O(1)$ state deduplication. Worst-case execution time is strictly bounded to $O(M \times N)$. |
| **ReDoS Immunity** | Mathematically immune to catastrophic backtracking and Regular Expression Denial of Service (ReDoS) exploits. Pathological inputs like `(a+)+$` on $a^{30}!$ reject in microseconds. |
| **Inline `.{}` Options** | Ergonomic and uniform configuration standard across all public APIs: `compile(alloc, pat, .{})`, `isMatch(in, .{})`, `find(in, .{})`, `findAll(alloc, in, .{})`, `captures(in, .{})`, `replace(...)`, and `split(...)`. |
| **Submatch Captures** | High-performance capture group extraction with up to 32 inline capture slots, zero heap allocations during search, and positional indexing (`caps.get(1)`). |
| **Named Captures** | Full support for Perl-compatible named groups `(?P<name>...)` accessible by identifier with `caps.name("name")`. |
| **Literal Prefilters** | Automatic literal prefix extraction with fast substring search that bypasses full NFA simulation when the prefix does not appear in the input. |
| **Unicode & UTF-8** | Multi-byte UTF-8 decoding, Unicode codepoint ranges (`[\u{3040}-\u{309F}]`), ASCII shorthands (`\d`, `\w`, `\s`), POSIX bracket classes, and Unicode simple case-folding across multi-byte codepoints. |
| **Replacement Subsystem** | Fast template expansion replacing the first match (`replace`) or all matches (`replaceAll`) with numbered `$1` and named `${name}` backreferences. |
| **Splitting & Delimiters** | Splits text across regular expression delimiters with configurable maximum split counts and zero memory leaks. |
| **Safe Streaming Iterators** | Forward stream iteration (`iterator`, `capturesIterator`) that safely progresses past zero-length matches (such as `\b`) without getting stuck in infinite loops. |
| **Zero Runtime Allocations** | Boolean matching, leftmost-first finding, and capture extraction execute entirely inside a pre-calculated, reusable thread scratch buffer with zero heap allocations during matching. |
| **Hardened Safety Limits** | Configurable limits (`Limits`) for maximum pattern length, group nesting depth, repetition bounds, and compiled bytecode budgets to prevent memory exhaustion. |
| **Structured Error Diagnostics** | Returns typed Zig error unions accompanied by line, column, and byte-offset syntax error diagnostic reporting. |
| **Pure Native Zig 0.17** | Built entirely from scratch in native Zig 0.17.0 using standard library facilities (`std.ascii`, `std.unicode`, `std.math`). Zero C code, zero libc, and zero external packages. |
| **Cross-Platform Portability** | Endian-neutral, pointer-size agnostic implementation tested and validated across Windows, Linux, and macOS on x86, x86_64, aarch64, and ARM architectures. |

</details>

---

<details>
<summary><strong>Prerequisites and Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Zig** | **0.17.0** (required) | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Architecture-neutral native execution |

> [!IMPORTANT]
> **Zig 0.17.0 is required.** This project targets the stable Zig 0.17.0 release. Please use Zig 0.17.0 for all builds.

---

## Supported Platforms

| Platform | x86_64 (64-bit) | aarch64 (ARM64) | x86 (32-bit) | ARM (32-bit) |
|----------|-----------------|-----------------|--------------|--------------|
| **Linux** | Yes | Yes | Yes | Yes |
| **Windows** | Yes | Yes | Yes | No |
| **macOS** | Yes | Yes (Apple Silicon) | No | No |

### Cross-Compilation

```bash
# Build for Linux ARM64 from Windows
zig build -Dtarget=aarch64-linux

# Build for Windows from Linux
zig build -Dtarget=x86_64-windows

# Build for macOS Apple Silicon from Linux
zig build -Dtarget=aarch64-macos

# Build for 32-bit Windows
zig build -Dtarget=x86-windows
```

</details>

---

## Installation

### Method 1: Zig Fetch (Recommended)

**Latest Release (0.0.1)**

```bash
zig fetch --save https://github.com/muhammad-fiaz/regex.zig/archive/refs/tags/0.0.1.tar.gz
```

### Method 2: Zig Fetch (Latest Development Build)

Use this for the latest development build directly from the `main` branch:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/regex.zig.git
```

### Method 3: Manual `build.zig.zon` Configuration

```zig
.dependencies = .{
    .regex = .{
        .url = "https://github.com/muhammad-fiaz/regex.zig/archive/refs/tags/0.0.1.tar.gz",
        .hash = "...", // Run `zig fetch --save <url>` to generate the hash.
    },
},
```

### Method 4: Local Source Checkout

```bash
git clone https://github.com/muhammad-fiaz/regex.zig.git
cd regex.zig
zig build test
```

To use a local checkout from another project:

```zig
.dependencies = .{
    .regex = .{
        .path = "../regex.zig",
    },
},
```

### Wire into `build.zig`

```zig
const regex_dep = b.dependency("regex", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("regex", regex_dep.module("regex"));
```

> [!NOTE]
> If you encounter `file exists in modules 'X' and 'X0'`, pass `.{}` instead of `.target = target` and `.optimize = optimize` to `b.dependency("regex", .{})`. See [Zig issue #36694](https://codeberg.org/ziglang/zig/issues/36694).

---

## Quick Start

Compile a pattern using an allocator and execute boolean checks or search operations with inline `.{}` options:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. Compile pattern with inline options
    var re = try regex.compile(allocator, "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}", .{});
    defer re.deinit();

    // 2. Fast boolean match test (zero heap allocation)
    const valid = re.isMatch("dev@example.com", .{});
    std.debug.print("Matches: {}\n", .{valid}); // true

    // 3. Find first match with byte coordinate spans
    const text = "Contact our team at support@example.com for inquiries.";
    if (re.find(text, .{})) |m| {
        std.debug.print("Found '{s}' at byte offset {}..{}\n", .{ m.slice, m.start, m.end });
    }
}
```

### Stateful & Advanced Operations

#### Submatch & Named Captures

```zig
var re = try regex.compile(allocator, "(?P<host>[a-zA-Z0-9.-]+):(?P<port>\\d+)", .{});
defer re.deinit();

if (re.captures("Connected to api.service.com:8443 securely", .{})) |caps| {
    std.debug.print("Full match: {s}\n", .{caps.slice()});
    std.debug.print("Host: {s}\n", .{caps.name("host").?}); // "api.service.com"
    std.debug.print("Port: {s}\n", .{caps.name("port").?}); // "8443"
    std.debug.print("Group 1: {s}\n", .{caps.get(1).?});    // "api.service.com"
}
```

#### String Replacement with Template Expansion

```zig
var date_re = try regex.compile(allocator, "(\\d{2})/(\\d{2})/(\\d{4})", .{});
defer date_re.deinit();

const iso = try date_re.replaceAll(allocator, "Date: 10/26/2026", "$3-$1-$2", .{});
defer allocator.free(iso);
std.debug.print("Formatted: {s}\n", .{iso}); // "Date: 2026-10-26"
```

#### String Splitting

```zig
var delim = try regex.compile(allocator, "[,;\\s]+", .{});
defer delim.deinit();

const tokens = try delim.split(allocator, "alpha, beta;  gamma   delta", .{});
defer allocator.free(tokens);
// tokens: ["alpha", "beta", "gamma", "delta"]
```

#### Safe Streaming Iteration

```zig
var kv_re = try regex.compile(allocator, "([a-z])=(\\d+)", .{});
defer kv_re.deinit();

var it = kv_re.capturesIterator("x=10, y=20, z=30", .{});
while (it.next()) |caps| {
    std.debug.print("Key: {s}, Value: {s}\n", .{ caps.get(1).?, caps.get(2).? });
}
```

#### Custom Options & Safety Limits

```zig
var re = try regex.compile(allocator, "^[a-z]+$", .{
    .caseInsensitive = true,
    .multiline = true,
    .limits = .{
        .maxPatternLength = 4096,
        .maxNestingDepth = 32,
        .maxRepetition = 500,
    },
});
defer re.deinit();
```

---

## Examples

The `examples/` directory contains 11 runnable examples demonstrating all features of `regex.zig`:

- [`basic`](examples/basic.zig) - Pattern compilation, boolean matching, and match coordinates
- [`search`](examples/search.zig) - Server log scanning and batch match extraction
- [`captures`](examples/captures.zig) - URL parsing with named groups `(?P<name>...)` and positional submatches
- [`validation`](examples/validation.zig) - Semantic version, hex color, and identifier validation
- [`replace`](examples/replace.zig) - Date reformatting with `$3-$1-$2` and secret token sanitization
- [`split`](examples/split.zig) - Tokenizing across multi-character and HTML tag delimiters
- [`iteration`](examples/iteration.zig) - Key-value pair streaming and zero-length boundary progression
- [`options`](examples/options.zig) - Inline options: case-insensitive, multiline, and dot-all modes
- [`unicode`](examples/unicode.zig) - Japanese Hiragana, currency symbols, and multi-byte case-folding
- [`errors`](examples/errors.zig) - Syntax error handling with structured line/column diagnostics
- [`limits`](examples/limits.zig) - Pathological ReDoS verification and custom resource bounds

To run all examples sequentially:

```bash
zig build example
```

Or run any individual example:

```bash
zig build run-example-basic
zig build run-example-captures
zig build run-example-limits
```

---

## Validation Matrix

```bash
# Run unit and integration tests
zig build test

# Run all 11 examples sequentially
zig build run-all-examples

# Run client-side performance benchmarks
zig build bench
```

For explicit cross-target compilation validation:

```bash
# Linux 64-bit
zig build test -Dtarget=x86_64-linux

# Linux ARM64
zig build test -Dtarget=aarch64-linux

# Windows 32-bit
zig build test -Dtarget=x86-windows

# macOS Apple Silicon
zig build test -Dtarget=aarch64-macos
```

---

## Performance

Run benchmarks locally:

```bash
zig build bench
```

Benchmark target: `x86_64-windows`, `ReleaseFast` (Zig 0.17.0, warmup + 5-round statistical averaging).

| Benchmark | Category | Avg Latency | Throughput | Target |
| :--- | :--- | :---: | :---: | :---: |
| `literal_search_2kb` | Core Operations | 22.0 ns/op | **45,438,023 ops/sec** | `x86_64-windows` |
| `email_pattern_compile` | Compilation | 50.8 µs/op | **19,653 ops/sec** | `x86_64-windows` |
| `email_matching` | Matching | 1.5 µs/op | **675,466 ops/sec** | `x86_64-windows` |
| `named_captures_extract` | Captures | 3.4 µs/op | **293,699 ops/sec** | `x86_64-windows` |
| `replace_all_10_numbers` | Transformation | 7.0 µs/op | **143,075 ops/sec** | `x86_64-windows` |
| `pathological_redos_linear` | ReDoS Immunity | 11.4 µs/op | **87,702 ops/sec** | `x86_64-windows` |

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `zig build test`
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

---

## Project Structure

```
regex.zig/
├── src/
│   ├── regex.zig              # Public API entry point & re-exports
│   ├── ast.zig                # Abstract syntax tree definitions
│   ├── automaton.zig          # Thompson NFA construction
│   ├── charset.zig            # Character class sets & Bitmap256
│   ├── compiler.zig           # AST to bytecode compilation & prefilters
│   ├── engine.zig             # PikeVM dual-queue thread simulation
│   ├── error.zig              # Comprehensive error sets & diagnostics
│   ├── escape.zig             # Literal pattern escaping
│   ├── iterator.zig           # Zero-length progression streaming iterators
│   ├── literal.zig            # Literal prefilter search
│   ├── match.zig              # Match & Captures data structures
│   ├── options.zig            # Compile, match, and limits options
│   ├── parser.zig             # Recursive-descent regex parser
│   ├── replace.zig            # Template & named capture replacement
│   └── unicode.zig            # UTF-8 decoding & case-folding
├── examples/                  # 11 runnable examples
│   ├── basic.zig              # Basic matching & searching
│   ├── captures.zig           # Named and numbered submatches
│   ├── errors.zig             # Error inspection & diagnostics
│   ├── iteration.zig          # Safe streaming iteration
│   ├── limits.zig             # ReDoS defense & safety limits
│   ├── options.zig            # Inline configuration flags
│   ├── replace.zig            # String replacement & sanitization
│   ├── search.zig             # Log scanning & batch search
│   ├── split.zig              # String splitting by regex
│   ├── unicode.zig            # Unicode & multi-byte case-folding
│   └── validation.zig         # Version, color, and identifier validation
├── bench/                     # Client-side performance benchmarks
│   └── main.zig               # Microbenchmark suite
├── docs/                      # VitePress documentation site
├── build.zig                  # Build system & native doc emission
├── build.zig.zon              # Package metadata
├── README.md
├── SECURITY.md
├── LICENSE
└── CONTRIBUTING.md
```

---

## License

MIT License - see [LICENSE](LICENSE) for details.
