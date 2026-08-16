# 0422 — spec §4.2's `devpath` templates do not survive `xschem translate`

Status: **open — claimed by step S1 of the op-annotation run (2026-08-16)**.
Filed as a stub by the S1 Planner to reserve the number; body written by the S1
Implement/Write-up agents when the fix lands.

## What was measured

All three worked descriptors in `doc/claude/specs/op_annotation.md` §4.2 spell the
device-path template unescaped, e.g.

```
devpath {@m.$path@spiceprefix@name.msky130_fd_pr__@model}
```

Fed to `xschem translate <inst> …` on branch `annotate` with the in-tree
`src/xschem`, that template produces

```
Xnfet_01v8
```

— no error, no warning, a plausible-looking wrong string.

Cause: `SPACE(c)` (`src/token.c:24`) is `{\n, space, \t, \0, ;}` only, so `.` does
**not** terminate an `@token`. `@m.x1.` and `@name.msky130_fd_pr__` are each scanned
as one unknown token, and an unknown token that misses `get_tok_value()` appends
**nothing** (`src/token.c:5351-5366`).

The working form is the one the shipped sky130 symbol already uses
(`sky130A/xschem_libs/sky130_fd_pr/nfet_01v8/symbol/nfet_01v8.sym:63-64`) — escape
the leading `@` and escape the `.` that must terminate a token:

```
devpath {\@m.@path@spiceprefix@name\.msky130_fd_pr__@model}
```

which measures as `@m.x1.XM1.msky130_fd_pr__nfet_01v8`, and after `string tolower`
matches the S1 acceptance goldens byte for byte.

## Why it matters

Plan step S2 is instructed to *copy* the §4.2 descriptors. Copied verbatim they
would register three PDKs whose every device name is silently wrong — the exact
silent-drift failure invariant I1 exists to prevent.

## Also recorded here (measured, not separately filed)

* `xschem getprop symbol <cell> type` **raises** `Symbol not found` for a cell name
  without the `.sym` suffix, while `xschem getprop instance <n> <attr>` returns the
  empty string for a missing attribute. Every descriptor lookup must `catch`.
* `xschem translate` runs a trailing `expr(…)` / `expr_eng(…)` / `tcleval(…)` pass
  (`token.c:5424-5432`): `xschem translate M1 {expr(1+1)}` measures as `2`.
  A `devpath` template is therefore restricted to plain `@`-token text.

## Fix

Correct §4.2's three templates in the spec, document the escaping rule beside them,
and correct the S1 acceptance note in
`doc/claude/suggestions/next_session_prompt_op_annotation.md` ("with no schematic
loaded, … a stubbed instance" is measured false — `xschem translate` needs a real
loaded instance; `translate -1 <tmpl>` substitutes each token with its own name).
