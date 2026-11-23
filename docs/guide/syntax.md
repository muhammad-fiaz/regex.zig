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

Supported escapes include `\n`, `\r`, `\t`, `\f`, `\v`, `\a`, `\e`, `\0`,
`\xHH` (byte value), and `\u{HHHHHH}` (Unicode codepoint up to `0x10FFFF`).
Escaped metacharacters such as `\.` or `\[` match their literal character.

---

## Dot (`.`)

`.` matches one complete UTF-8 character, not one byte. For example, `.` against
`"é"` produces a single match spanning both UTF-8 bytes (`0..2`). By default `.`
excludes newline (`\n`); enable `dotAll` (`(?s)` or `.dotAll = true`) to include it.
Invalid or truncated UTF-8 sequences are consumed one byte at a time so scanning
always makes progress.

---

## Character Classes

Bracket expressions define custom character sets. Items and ranges are decoded as
UTF-8 codepoints, so multi-byte characters behave as single members:

- `[abc]`: Matches any character in the set (`a`, `b`, or `c`).
- `[^abc]`: Negated set — matches any character not in `a`, `b`, or `c`.
- `[a-z0-9]`: Range expressions matching lowercase letters and digits.
- `[é-ê]`: Raw UTF-8 characters and ranges are supported directly.
- `[\u{3040}-\u{309F}]`: Unicode codepoint ranges up to 21 bits.

Negated classes also consume a complete character, so `[^a]` matches `"é"` as one
match rather than two byte matches. With `caseInsensitive`, classes use full
Unicode simple case folding.

### Predefined Character Shorthands

By default these are Unicode-aware; set `.ascii = true` to restrict them to ASCII.

| Shorthand | Meaning | Unicode definition | ASCII mode |
| :--- | :--- | :--- | :--- |
| `\d` | Digit | `\p{Nd}` | `[0-9]` |
| `\D` | Non-digit | `\P{Nd}` | `[^0-9]` |
| `\w` | Word character | `\p{L}\p{M}\p{Nd}\p{Pc}` | `[a-zA-Z0-9_]` |
| `\W` | Non-word character | complement of `\w` | `[^a-zA-Z0-9_]` |
| `\s` | Whitespace | Unicode `White_Space` | `[ \t\r\n\x0c\x0b]` |
| `\S` | Non-whitespace | complement of `\s` | `[^ \t\r\n\x0c\x0b]` |

`\b`/`\B` word boundaries use the same word definition (Unicode by default, ASCII
when `.ascii = true`) and are evaluated at character boundaries.

### Unicode Property Classes

`\p{…}` matches a codepoint with a Unicode property; `\P{…}` matches its complement.
Both work standalone and inside bracket expressions (`[\p{L}\p{Nd}]`).

- General categories: `Lu`, `Ll`, `Lt`, `Lm`, `Lo`, `Mn`, `Mc`, `Me`, `Nd`, `Nl`,
  `No`, `Pc`, `Pd`, `Ps`, `Pe`, `Pi`, `Pf`, `Po`, `Sm`, `Sc`, `Sk`, `So`, `Zs`,
  `Zl`, `Zp`, `Cc`, `Cf`, `Cs`, `Co`, `Cn`.
- Grouped categories: `L` (Letter), `LC` (Cased_Letter), `M` (Mark), `N` (Number),
  `P` (Punctuation), `S` (Symbol), `Z` (Separator), `C` (Other).
- Binary property: `White_Space` (alias `space`).

A single-letter form such as `\pL` is also accepted. Long names like `Letter`,
`Number`, and `Punctuation` are aliases for the grouped categories.

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
- `\b`: Word boundary (`\w` adjacent to `\W` or string bounds). Unicode-aware by
  default; ASCII when `.ascii = true`.
- `\B`: Non-word boundary.

---

## Grouping & Captures

- `(expr)`: Numbered capturing group. Submatch offsets are recorded into capture slots `$1`, `$2`, etc. Up to 31 capturing groups are addressable (32 inline slots including the full match).
- `(?:expr)`: Non-capturing group. Groups sub-expressions without consuming capture slot indices.
- `(?P<name>expr)` / `(?<name>expr)`: Named capturing group. Retrieve matched slice by identifier with `caps.name("name")`.
- `(?i)` / `(?-i)`: Inline case-insensitive flag toggles.
- `(?m)` / `(?-m)`: Inline multiline flag toggles.
- `(?s)` / `(?-s)`: Inline dot-all flag toggles.
- `(?U)` / `(?-U)`: Inline ungreedy flag toggles.
- `(?i:expr)`: Scoped flag group. Flags apply only inside the group and are restored afterwards.

---

## Unsupported Constructs

To guarantee **linear-time execution** and prevent arbitrary computational complexity, the following non-regular constructs are intentionally rejected at compile time:

- **Backreferences** (e.g. `\1`, `\2`, `\k<name>`): Backreferences transform pattern matching into an NP-complete problem.
- **Lookaround Assertions** (e.g. `(?=...)`, `(?!...)`, `(?<=...)`, `(?<!...)`): Lookahead and lookbehind assertions complicate non-backtracking NFA engines.
