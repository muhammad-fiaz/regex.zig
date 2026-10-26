const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Core regex module
    const mod = b.addModule("regex", .{
        .root_source_file = b.path("src/regex.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library artifact with native docs emission
    const lib = b.addLibrary(.{
        .name = "regex",
        .root_module = mod,
    });
    b.installArtifact(lib);

    // Tests step
    const lib_tests = b.addTest(.{ .root_module = mod });
    const run_lib_tests = b.addRunArtifact(lib_tests);
    const test_step = b.step("test", "Run all unit and integration tests");
    test_step.dependOn(&run_lib_tests.step);

    // Zig native documentation emission step
    const docs_step = b.step("docs", "Generate library documentation");
    const install_docs = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });
    docs_step.dependOn(&install_docs.step);

    // Examples step
    const example_step = b.step("example", "Run all examples");
    const run_all_examples_step = b.step("run-all-examples", "Run all examples");
    run_all_examples_step.dependOn(example_step);

    const examples = [_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "search", .path = "examples/search.zig" },
        .{ .name = "captures", .path = "examples/captures.zig" },
        .{ .name = "validation", .path = "examples/validation.zig" },
        .{ .name = "replace", .path = "examples/replace.zig" },
        .{ .name = "split", .path = "examples/split.zig" },
        .{ .name = "iteration", .path = "examples/iteration.zig" },
        .{ .name = "options", .path = "examples/options.zig" },
        .{ .name = "unicode", .path = "examples/unicode.zig" },
        .{ .name = "errors", .path = "examples/errors.zig" },
        .{ .name = "limits", .path = "examples/limits.zig" },
    };

    inline for (examples) |ex| {
        const exe = b.addExecutable(.{
            .name = ex.name ++ "_example",
            .root_module = b.createModule(.{
                .root_source_file = b.path(ex.path),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "regex", .module = mod }},
            }),
        });
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        example_step.dependOn(&run.step);

        const individual_step = b.step("run-example-" ++ ex.name, "Run the " ++ ex.name ++ " example");
        individual_step.dependOn(&run.step);
    }

    // Benchmark step
    const bench_step = b.step("bench", "Run client-side benchmarks");
    const bench_exe = b.addExecutable(.{
        .name = "regex_benchmarks",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{.{ .name = "regex", .module = mod }},
        }),
    });
    const run_bench = b.addRunArtifact(bench_exe);
    bench_step.dependOn(&run_bench.step);
}
