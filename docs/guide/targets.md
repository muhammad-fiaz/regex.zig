---
title: Cross-Platform Targets
description: Compilation matrix and portability design principles across 32-bit and 64-bit architectures on Windows, Linux, and macOS.
keywords: zig, regex, cross platform, compilation, targets, windows, linux, macos, aarch64, x86
---

# Supported Target Matrix

`regex.zig` is architecture-neutral and portable. The core engine relies strictly on Zig 0.17.0 native types and standard library facilities, without assuming a 64-bit pointer size, a specific endianness, or operating-system-specific services.

---

## Validated Operating Systems & Architectures

| Target Triple | Operating System | Architecture | Bit Width | Verification Type |
| :--- | :--- | :--- | :--- | :--- |
| `x86_64-windows` | Windows | x86_64 | 64-bit | Native compilation & unit tests |
| `x86-windows` | Windows | x86 | 32-bit | Native compilation & unit tests |
| `aarch64-windows` | Windows | AArch64 | 64-bit | Cross-compilation verified |
| `x86_64-linux-gnu` | Linux | x86_64 | 64-bit | Native runner & unit tests |
| `aarch64-linux-musl` | Linux | AArch64 | 64-bit | Cross-compiled & QEMU tests |
| `x86-linux-musl` | Linux | x86 | 32-bit | Cross-compiled & QEMU tests |
| `arm-linux-musleabihf`| Linux | ARM | 32-bit | Cross-compiled & QEMU tests |
| `aarch64-macos` | macOS | AArch64 (Apple Silicon) | 64-bit | Native runner & unit tests |
| `x86_64-macos` | macOS | x86_64 (Intel) | 64-bit | Native runner & unit tests |

---

## Portability Design Principles

1. **No libc or OS Dependencies**: Compilation and matching do not link to libc, POSIX headers, or Windows APIs.
2. **Endian-Neutral & Pointer-Agnostic**: All serialized bytecode and match spans use explicit fixed-width or pointer-sized integers (`usize`, `u32`, `u21`, `u8`) without assuming pointer size equals 8 bytes.
3. **No Unaligned Pointer Casts**: Data structures use explicit byte packing and standard alignments safe for 32-bit ARM targets.
4. **Checked Arithmetic**: Repetition and allocation sizes are validated using `std.math.mul` and `std.math.add` before allocation.

---

## How to Cross-Compile

Cross-compiling `regex.zig` for any target requires zero external toolchains. Simply pass the `-Dtarget` flag:

```bash
# Cross-compile for Linux 64-bit
zig build -Dtarget=x86_64-linux

# Cross-compile for Linux ARM 32-bit
zig build -Dtarget=arm-linux-musleabihf

# Cross-compile for macOS Apple Silicon
zig build -Dtarget=aarch64-macos

# Cross-compile for Windows 32-bit
zig build -Dtarget=x86-windows
```
