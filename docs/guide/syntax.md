---
title: Regex Dialect & Syntax
description: Syntax guide covering bracket expressions, predefined shorthands, greedy/lazy quantifiers, assertions, and group captures.
keywords: zig, regex, syntax, dialect, character classes, quantifiers, groups, anchors
---

# Regex Dialect & Syntax

`regex.zig` supports an expressive subset of standard regular expression syntax optimized for linear-time processing and complete ReDoS immunity.

---

## Metacharacters & Escaping

The following metacharacters have special syntactic meaning and must be escaped with `\` to be treated as literal characters:

```
\ . + * ? ( ) [ ] { } | ^ $
```

Use `regex.escape(allocator, raw_str)` or `regex.escapeBuffer(&buf, raw_str)` to programmatically escape user input.

---

## Character Classes

Bracket expressions define custom character sets:

- `[abc]`: Matches any character in the set (`a`, `b`, or `c`).
- `[^abc]`: Negated set — matches any character not in `a`, `b`, or `c`.
- `[a-z0-9]`: Range expressions matching lowercase letters and digits.
- `[\u{3040}-\u{309F}]`: Unicode codepoint ranges up to 21 bits.

### Predefined Character Shorthands

| Shorthand | Meaning | ASCII Equivalent |
| :--- | :--- | :--- |
| `\d` | Digit | `[0-9]` |
| `\D` | Non-digit | `[^0-9]` |
| `\w` | Word character | `[a-zA-Z0-9_]` |
| `\W` | Non-word character | `[^a-zA-Z0-9_]` |
| `\s` | Whitespace | `[ \t\r\n\x0c\x0b]` |
| `\S` | Non-whitespace | `[^ \t\r\n\x0c\x0b]` |

### POSIX Character Classes

Inside bracket expressions:
`[:alnum:]`, `[:alpha:]`, `[:ascii:]`, `[:blank:]`, `[:cntrl:]`, `[:digit:]`, `[:graph:]`, `[:lower:]`, `[:print:]`, `[:punct:]`, `[:space:]`, `[:upper:]`, `[:word:]`, `[:xdigit:]`.

---

## Quantifiers & Repetition

Quantifiers define how many times the preceding atom may match:

| Quantifier | Meaning | Greediness |
| :--- | :--- | :--- |
| `*` | 0 or more times | Greedy |
| `*?` | 0 or more times | Lazy |
| `+` | 1 or more times | Greedy |
| `+?` | 1 or more times | Lazy |
| `?` | 0 or 1 time | Greedy |
| `??` | 0 or 1 time | Lazy |
| `{n}` | Exactly $n$ times | Bounded |
| `{n,}` | At least $n$ times | Bounded |
| `{n,m}` | Between $n$ and $m$ times | Bounded |
| `{n,m}?` | Between $n$ and $m$ times | Lazy bounded |

---

## Anchors & Zero-Width Assertions

- `^`: Beginning of line (in multiline mode) or beginning of text.
- `$`: End of line (in multiline mode) or end of text.
- `\A`: Absolute beginning of input string.
- `\z`: Absolute end of input string.
- `\b`: ASCII word boundary (`\w` adjacent to `\W` or string bounds).
- `\B`: Non-word boundary.

---

## Grouping & Captures

- `(expr)`: Numbered capturing group. Submatch offsets are recorded into capture slots `$1`, `$2`, etc.
- `(?:expr)`: Non-capturing group. Groups sub-expressions without consuming capture slot indices.
- `(?P<name>expr)`: Named capturing group. Retrieve matched slice by identifier with `caps.name("name")`.
- `(?i)` / `(?-i)`: Inline case-insensitive flag toggles.
- `(?m)` / `(?-m)`: Inline multiline flag toggles.
- `(?s)` / `(?-s)`: Inline dot-all flag toggles.

---

## Unsupported Constructs

To guarantee **linear-time execution** and prevent arbitrary computational complexity, the following non-regular constructs are intentionally rejected at compile time:

- **Backreferences** (e.g. `\1`, `\2`): Backreferences transform pattern matching into an NP-complete problem.
- **Lookaround Assertions** (e.g. `(?=...)`, `(?!...)`): Lookahead and lookbehind assertions complicate non-backtracking NFA engines.
