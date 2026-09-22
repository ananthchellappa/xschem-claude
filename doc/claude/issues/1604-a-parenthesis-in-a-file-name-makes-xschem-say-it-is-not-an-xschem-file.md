# 1604 — a parenthesis in a file name makes xschem say it is not an xschem file

**STAMP:** `v1 claim=fixed tree=021876975a stamped=2026-09-22 fix=taken open=0 by=crew-1604`

**Status: FIXED — filed 2026-09-22** by the driver, from a side finding the 1601 crew made
while measuring the preview bindings and explicitly did not file. **Closed 2026-09-22**
by the 1604 crew: `proc is_xschem_file` now strips a trailing generator argument list and
only that, anchored to the grammar `is_generator` in `src/token.c` actually enforces.
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

---

## THE SURVEY — done before the pattern was touched

The issue asked for the real spelling before the anchor was chosen, and it was right to:
the grammar does **not** live in `is_xschem_file`.

**The authority is `is_generator` in `src/token.c`**, a compiled ERE:

```
^[^ \t()]+\([^()]*\)[ \t]*$
```

It is the function `save.c` `load_schematic` and `paste.c` consult to decide whether to
`popen` a name or `fopen` it, so it — not this proc, and not this file — decides what a
generator is. Confirmed at the C entry point with `xschem is_generator`, not read off the
source:

| name | `xschem is_generator` |
|---|---|
| `gen.tcl(a,b)`, `gen.tcl()`, `gen.tcl(inv,1200)` | 1 |
| `gen.tcl(a,b)` with a trailing space | 1 |
| `bandgap(rev2).sch`, `foo (1).sch`, `opamp(v3)_final.sym` | 0 |
| `gen.tcl((a))`, `a(b)c(d)`, `gen.tcl(a,b)x`, `foo.sym)` | 0 |
| a generator under a directory whose name has a space | 0 |

**The four questions the survey had to answer:**

1. **Can an argument contain a nested parenthesis?** No. `[^()]*` forbids it, and
   `gen.tcl((a))` measures 0.
2. **Can anything follow the closing parenthesis?** Only spaces and tabs — `[ \t]*$`.
   A suffix takes the name out of the grammar, which is exactly why `opamp(v3)_final.sym`
   is not one. `load_schematic` trims whitespace before it ever asks, and its own
   `ffname[len-1] != ')'` test assumes the same thing.
3. **Is the argument list ever absent?** **Yes, and this is the trap.** `save.c`
   `load_schematic` and `actions.c` `place_symbol` both call `is_xschem_file` on a *bare*
   generator path and append `()` themselves once the answer comes back `GENERATOR`. A
   pattern that required a parenthesis, or that touched a name without one, would break
   the shipped `symbolgen.tcl` with no arguments.
4. **Is the path ever already truncated?** Not truncated, but `place_symbol` strips a
   literal `tcleval(` prefix first and hands over a name that still carries the matching
   trailing `)` — a string with a close parenthesis and no open one. Both the old pattern
   and the new one leave it alone and answer 0, which is what that path expects.

**The shipped generator spellings**, from `xschem_library/generators/`:
`schematicgen.tcl(buf)`, `schematicgen.tcl(buf,4)`, `schematicgen.tcl(inv)`,
`symbolgen.tcl()`, `symbolgen.tcl(inv,@ROUT\)`, `mosgen.tcl(@model\)`,
`res.tcl(@value\)`, `tier.tcl(@lab\)`. The `@…\` forms are raw instance references:
`translate()` resolves the token before the name ever reaches this proc, so what arrives
is an ordinary argument list.

## THE FIX

`proc is_xschem_file` in `src/xschem.tcl` now carries

```tcl
regsub {^([^ \t()]+)\([^()]*\)[ \t]*$} $f {\1} f
```

— `is_generator`'s ERE character for character, with the head captured. It fires exactly
when C calls the name a generator and never otherwise.

**Anchoring to the tail alone would not have been enough.** `{\([^()]*\)$}`, the shape
this issue suggested, also strips a generator living under a directory whose name has a
space — which C refuses, because its head admits no space. That name would come back
`GENERATOR` here and be opened as a plain file there, and fail. Agreeing with
`is_generator` is the requirement; anchoring is only how it is met.

**Two more occurrences of the unanchored pattern survive in `src/xschem.tcl` on purpose**,
in `cellview_edit_item` and in the cell-view list that builds its balloon. Both sit inside
an `if {[xschem is_generator …]}` guard, so C has already established the string is
head-then-arguments and the two patterns cannot differ. Row `S3` enforces the **guard**
rather than the pattern, and `S3b` keeps it from going vacuous.

## THE RESIDUAL LIMIT

A name that is *entirely* head-then-parenthesised-list with nothing after the closing
parenthesis — `rev(2)`, no extension — **is** a generator invocation by this tree's
grammar, and a file of that exact name is still reported `0`. The two cases are not
distinguishable by spelling, and widening it means changing the C ERE, at which point the
Tcl and the C must move together. Rows `F12`/`F13` pin this down so nobody meets it as a
surprise; row `S8` is what makes the two move together.

## THE TEST

`tests/headless/test_generator_paren_1604.tcl`, registered in `tests/run_regression.tcl`
in both `hcases` and `dcases`. **41 checks headless, 46 on the display arm.**

* `S1`–`S8b` structural, both arms; the source is read with comment lines stripped,
  because the fix's own comment quotes the defective pattern verbatim. `S8` compares the
  shipped Tcl pattern with the ERE read out of `src/token.c`, character for character.
* `G1`–`G18` grammar, both arms. The strip is **lifted out of the shipped file**, not
  copied into the test, and run over a name table with `xschem is_generator` as the
  oracle. `G16` shows the old pattern failing that same table.
* `F1`–`F13` functional, both arms: real files on disk under real parenthesised names.
* `D1`–`D5` the Insert dialog, display arm only; one `skip:` line on the headless arm.

**Sabotage** (the defective pattern put back): 9 rows redden headless — `S2`, `S3`, `S3b`,
`S5`, `S8`, `G15`, `F3`, `F4`, `F5` — and 14 on the display arm, the extra five being
`D1`–`D5`, with `D1` showing `file_chooser_place` never called at all.

## Still open

Nothing.
