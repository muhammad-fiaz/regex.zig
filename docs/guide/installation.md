---
title: Installation
description: Add regex.zig to your project using zig fetch, package manifests, local paths, or build system imports.
keywords: zig, regex, installation, zig fetch, build.zig.zon, package manager, cross-compilation
---

# Installation

`regex.zig` is designed for Zig **0.17.0** and has zero external dependencies and zero C/libc requirements.

---

## Method 1: Zig Fetch (Recommended)

### Latest Release (0.0.1)

Run the following command in your project directory:

```bash
zig fetch --save https://github.com/muhammad-fiaz/regex.zig/archive/refs/tags/0.0.1.tar.gz
```

This downloads the archive and automatically writes the dependency entry and cryptographic package hash into your `build.zig.zon`.

---

## Method 2: Zig Fetch (Latest Development Build)

To use the latest development build directly from the `main` branch of GitHub:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/regex.zig.git
```

---

## Method 3: Manual `build.zig.zon` Configuration

You can also manually declare the dependency in your project's `build.zig.zon`:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .fingerprint = 0xa5b80453d7cc01f1,
    .dependencies = .{
        .regex = .{
            .url = "https://github.com/muhammad-fiaz/regex.zig/archive/refs/tags/0.0.1.tar.gz",
            .hash = "...", // Run `zig build` or `zig fetch --save <url>` to compute the hash
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

---

## Method 4: Local Source Checkout

For local library development, hacking, or monorepos:

```bash
git clone https://github.com/muhammad-fiaz/regex.zig.git
cd regex.zig
zig build test
```

Reference the local path in your project's `build.zig.zon`:

```zig
.dependencies = .{
    .regex = .{
        .path = "../regex.zig",
    },
},
```

---

## Wiring into `build.zig`

Once added to your `build.zig.zon`, import `regex` in your `build.zig` and add it to your executable, library, or test target:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 1. Resolve regex dependency
    const regex_dep = b.dependency("regex", .{
        .target = target,
        .optimize = optimize,
    });

    // 2. Add module import to your executable
    const exe = b.addExecutable(.{
        .name = "my_app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("regex", regex_dep.module("regex"));

    b.installArtifact(exe);
}
```

::: tip Duplicate Module Instances
If you encounter `file exists in modules 'X' and 'X0'` when combining multiple packages that depend on `regex`, try passing `.{}` instead of `.target = target` and `.optimize = optimize` to `b.dependency("regex", .{})`.
:::

---

## Verification

Verify that your installation was successful by creating a simple test in `src/main.zig`:

```zig
const std = @import("std");
const regex = @import("regex");

pub fn main() !void {
    var re = try regex.compile(std.heap.page_allocator, "^[a-z]+$", .{});
    defer re.deinit();

    const matches = re.isMatch("hello", .{});
    std.debug.print("Matches: {}\n", .{matches}); // true
}
```

Build and run:

```bash
zig build run
```
