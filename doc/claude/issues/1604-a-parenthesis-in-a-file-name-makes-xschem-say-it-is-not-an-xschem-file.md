# 1604 — a parenthesis in a file name makes xschem say it is not an xschem file

**STAMP:** `v1 claim=open tree=db66fe87 stamped=2026-09-22 fix=untried open=2 by=driver`

**Status: OPEN — filed 2026-09-22** by the driver, from a side finding the 1601 crew made
while measuring the preview bindings and explicitly did not file.
**Class** an over-broad pattern in a file-type test. **Not a security defect** — it fails
closed, and the 1601 crew said so when they set it aside. It is a plain usability one.
**Related:** **1601** (the preview bindings; this was found in the same proc's caller).

---

## The defect — MEASURED

`proc is_xschem_file` in `src/xschem.tcl` opens with

```tcl
regsub {\(.*} $f {} f ;# remove trailing generator args (gen.tcl(....))  if any
```

The intent is sound: a **generator** is named `gen.tcl(arg,arg)`, and the arguments must
come off before the path is tested. The pattern is not. `\(.*` matches **the first
parenthesis and everything after it**, anywhere in the string — not a trailing
argument list.

Measured in plain `tclsh` at `db66fe87`:

| file the user has | what `is_xschem_file` then tests for existence |
|---|---|
| `/lib/bandgap(rev2).sch` | `/lib/bandgap` |
| `/lib/foo (1).sch` | `/lib/foo ` (trailing space) |
| `/lib/opamp(v3)_final.sym` | `/lib/opamp` |
| `/lib/gen.tcl(a,b)` | `/lib/gen.tcl` ← the case it is for, correct |
| `/lib/plain.sch` | unchanged, correct |

The truncated path does not exist, so `is_xschem_file` returns `0`.

## What that costs the user — READ, at three of the five call sites

* **Insert dialog — it will not place the file.** `file_chooser_place load` runs only when
  the type is `SCHEMATIC`. A file with a `(` in its name is never that, so selecting it
  does nothing.
* **Insert dialog — no preview.** The preview is gated on `$type ne {0}`.
* **Open dialog — a wrong sentence.** The user is told
  `<name> does not seem to be an xschem file...\nContinue?`, about a perfectly ordinary
  schematic they saved themselves. Answering yes does open it, so this one is a false
  accusation rather than a block.

`foo (1).sch` is the name a browser, a file manager or a copy gives a duplicate, and a
parenthesised revision tag is ordinary engineering practice, so this is not an exotic
input.

## The shape a fix takes

Anchor the pattern to what it is for: a **trailing** parenthesised argument list at the
very end of the string, `{\([^()]*\)$}` or equivalent, rather than `\(.*` anywhere. Then
`gen.tcl(a,b)` still loses its arguments and `bandgap(rev2).sch` keeps its name.

⚠ **Check the generator spelling before changing the pattern.** This issue asserts what
the regsub *does*, measured; it does **not** assert that every generator invocation in
this tree ends in `)`. Nested parentheses in an argument, an argument list followed by a
suffix, or a generator referenced with trailing whitespace would each need the anchor
chosen differently. Find the real spellings first — `is_xschem_file` has five call sites
and `generator` is set from a `#!` first line, so the grammar lives elsewhere too.

## Still open

1. Survey how a generator path is actually spelled everywhere it is constructed, then
   anchor the pattern to that.
2. A test row. The cheap half is pure Tcl and needs no display: assert that
   `is_xschem_file` reports a real schematic named `bandgap(rev2).sch` as `SCHEMATIC` and
   still strips the arguments from `gen.tcl(a,b)`. The expensive half — that the Insert
   dialog will now place it — needs the display arm, and
   `tests/headless/test_preview_name_inject_1601.tcl` already drives those dialogs.
