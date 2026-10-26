# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.0.1   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability or bug that leads to denial of service, unexpected memory consumption, or memory unsafety in `regex.zig`, please [create a GitHub security advisory or issue](https://github.com/muhammad-fiaz/regex.zig/issues).

All vulnerabilities and edge cases are investigated and addressed promptly.

## Security Architecture & ReDoS Defense

`regex.zig` is designed specifically to prevent **Regular Expression Denial of Service (ReDoS)**:

1. **Non-Backtracking PikeVM Execution**: The engine executes a Thompson NFA using Rob Pike's Virtual Machine. State transitions proceed in lockstep across input bytes in guaranteed $O(M \times N)$ linear time. Pathological backtracking patterns like `(a+)+$` complete in microseconds on adversarial input rather than exponentially hanging the process.
2. **Resource Limits**: The compiler enforces configurable safety limits on pattern length (`maxPatternLength`), group nesting depth (`maxNestingDepth`), compiled bytecode size (`maxProgramSize`), and repetition bounds (`maxRepetition`).
3. **No Dynamic System Code Execution**: The engine does not execute JIT-compiled native assembly from untrusted input, nor does it spawn external processes or depend on C runtime vulnerabilities.
4. **Memory Safety**: Pure Zig standard library allocation model. Scratch buffers and compiled bytecode have clear allocator lifecycles with zero hidden leaks.
