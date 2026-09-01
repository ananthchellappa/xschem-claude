# 1225 - the branch that reads a symbol's own drawing name is exercised by nothing

**Filed by** item S6b's sabotage pass, 2026-08-31. **Severity** medium (untested code
on the path that decides a cell name). **Area** `auto_spec_symbol_body()`,
src/actions.c.

## What is wrong

While walking the design's sheets, XSCHEM normally finds a cell's drawing sitting
beside its symbol, same name, `.sch` instead of `.sym`. When that file is not there,
a second branch opens the **symbol** and reads the drawing name out of it. That branch
is `auto_spec_symbol_body()` plus the second file read next to it.

**Nothing runs it, and nothing greps it.**

## Measured

Replace the whole function body with `out[0] = '\0';` and rebuild:
`test_auto_specialize_1201` **77 checks all pass**, `test_unused_attr_0970` 67.

`grep -rn auto_spec_symbol_body tests/` returns nothing, so there is no structural row
either -- AS74 reads only `auto_spec_scan_file` and `auto_spec_scan_design`.

The reason is that every fixture symbol in the suite (`aswv`, `aswmid`, `aswmat`,
`asnh`, `aspass` ...) is written with a same-named drawing beside it, so the ordinary
branch always wins and the fallback never executes. Its quoting, its escape handling
and its skipping of `@` and `(` values are all unrun.

## Why it matters

This is on the path that decides whether a cell name a designer typed one level down
is noticed. If the fallback mis-reads a name, the tool goes back to the 1212 behaviour
-- two copies sharing one cell body and one designer's setting leaving the deck
without a word -- for exactly the library layout where a symbol names its own drawing,
which is common in vendor PDKs.

## The repair

A fixture where the symbol names a drawing that is **not** beside it. Note the trap
found while trying: a symbol-level `schematic=<name>` resolves relative to the current
directory, not into the scratch library, so the fixture has to place the drawing where
`abs_sym_path()` will actually find it. Worth writing carefully once rather than
approximately.

---

## CLOSED 2026-08-31 by item S6b's REPAIR pass

New row **AS84**: a middle cell laid out the way vendor PDK libraries are -- the
symbol names the drawing it is built from, and there is no drawing of the
symbol's own name beside it -- with a copy one level down inside that drawing
hand-typing the very cell name the top sheet's copy would invent. Same
measurement as AS72: both devices in the deck, the copy that typed the name
keeps it, the invented one steps aside.

The trap this file warned about is real and is recorded in the fixture: the
symbol-level `schematic=` value has to be written library-relative
(`schematic=as/assbdraw`) or `abs_sym_path()` does not find it and the walk
never reaches the sheet. Written plainly, the branch is exercised: emptying
`auto_spec_symbol_body()` reddens AS84 and nothing else.
