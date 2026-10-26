# Contributing to regex.zig

Thank you for your interest in contributing to **regex.zig**, a super fast regex library for Zig!

## Development Workflow

### Prerequisites

- **Zig 0.17.0**
- Git

### Building the Project

```bash
# Build the library and artifacts
zig build

# Run all unit and integration tests
zig build test --summary all

# Run all examples
zig build example

# Run client-side benchmarks
zig build bench

# Emit native Zig documentation
zig build docs
```

### Code Style & Standards

1. **Standard Formatting**: Always format code using `zig fmt .` before submitting.
2. **Explicit Allocator Ownership**: Never allocate hidden global memory. Pass explicit allocators for operations that create new slices or strings (`findAll`, `replace`, `replaceAll`, `split`).
3. **Inline `.{}` Options Convention**: Every configurable operation must accept an explicit options struct as its final argument, with documented defaults accessible via `.{}`.
4. **Linear Time Safety**: Do not introduce backtracking or recursive execution routines into the PikeVM matching engine.
5. **Portability**: Rely strictly on the Zig standard library (`std.ascii`, `std.unicode`, `std.math`). Do not introduce C/C++ or OS-specific dependencies into the core engine.

## Submitting Pull Requests

1. Fork the repository and create your feature branch: `git checkout -b feature/my-enhancement`
2. Write clean, tested code with regression tests where appropriate.
3. Ensure `zig build test --summary all` passes cleanly.
4. Verify all 11 examples run with `zig build run-all-examples`.
5. Check code formatting with `zig fmt --check src/ examples/ bench/`.
6. Open a pull request against `main`.
