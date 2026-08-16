# 0395 — the `.mkinst` library browser is a fourth Escape swallow site: its own `<Key-Escape>` never reaches the C Escape terminal

Status: **OPEN** — measured under xvfb, not fixed.
Severity: **minor** (same class as 0245, one window narrower: the browser is a transient selector,
and closing it returns focus to `.ciform`, whose Escape *does* forward since 0245 landed).
Area: `src/create_instance.tcl:351` — `bind $w <Key-Escape> {mkinst::cancel; break}`
Found: 2026-08-11, by the D7 adversary pass on issue **0245**; confirmed independently by the D7
write-up agent before committing 0245.
Related: **0245** (the same defect on the three placement *forms*, FIXED), **0122** E2 (the shared
`.drw` slot), **0394** (ASE's seized canvas Escape, same shape, also open).

## What is wrong

0245's inventory of Escape seizes counted `.drw`-level grabs and found exactly three
(`addpin`, `addlabel`, `ciform`) plus ASE's `sod` seize. That count is literally correct and the
premise behind it is wrong: **Tk routes a key event to `[focus]`, not to the window named in the
binding**, so a grab on a *form's own toplevel* swallows Escape exactly as effectively as a grab on
`.drw`. `.mkinst` — the Library/Cell/View browser opened by the Create Instance form's *Browse…*
button — has one:

```tcl
bind $w <Key-Escape> {mkinst::cancel; break}     ;# create_instance.tcl:351
```

`mkinst::cancel` closes the browser. It does not call `abort_operation()`, does not set `tclstop`,
does not clear `MENUSTARTWIRE`, and does not reach `escape_terminal()`. While `.mkinst` holds
focus — which it does from the moment Browse is pressed — Escape is swallowed whole.

## Measured (xvfb, `xschem` at the 0245 fix)

```
mkinst exists=1 bind='mkinst::cancel; break'
mkinst focus=.mkinst.pw.lib.lb
mkinst after-ESC ui=65536 ui2=1
```

i.e. an armed `xschem wire` (`ui_state` 65536, `ui_state2` 1 = `MENUSTART|MENUSTARTWIRE`) survives
the Escape byte-identically — the same signature as 0245's headline transcript. For contrast, the
three forms after the 0245 fix:

```
LABEL  focus=.addlabel.f.ename   armed=65536/1  after-ESC ui=0 ui2=0  gone=1
PIN    focus=.addpin.f.ename     armed=65536/1  after-ESC ui=0 ui2=0  gone=1
CI     focus=.ciform.f.elib      armed=65536/1  after-ESC ui=0 ui2=0  gone=1
```

Probe: `/tmp/.../scratch_D7/writeup/focus_probe2.tcl` (X-only; Tk key delivery to a real widget
needs a display).

## Why it was not fixed with 0245

Blast radius and a pinned test. `test_create_instance.tcl` **CI7b** (`:158-159`) asserts `.mkinst`'s
Escape is wired to `mkinst::cancel`, and **CI9** pins what `ciform::escape` tears down. More
importantly the right answer is not obviously "forward": `.mkinst` is a *child selector* of
`.ciform`, and Escape in a browser conventionally means "cancel this browse", not "abort everything
on the canvas". Deciding that is a separate ratification from 0245's *"canvas Escape must reach
C"*, so bundling it in would have been the fifth grab in an item that already carried an
unratified user-visible change.

## The likely fix

Either (a) `mkinst::cancel` gains a trailing `catch {xschem escape}` — consistent with the three
forms, and defensible because the browser is modal-ish over the same canvas; or (b) Escape in the
browser closes only the browser and returns focus to `.ciform`, whose Escape already forwards —
in which case the correct change is `focus`-restoring, not a forward, and this issue closes as
*works as intended* with a test row pinning that the arm dies on the **second** Escape.

(b) is the smaller blast radius and matches the browser convention; (a) matches 0245's rule that
*Escape means the gesture ends*. Not adjudicated here.

## Landmine

Whichever way it goes, note that `.mkinst` does **not** own the shared `.drw <Key-Escape>` slot —
`ciform::grab_esc` does — so this is purely about the browser's own toplevel binding. Do not add
`.mkinst` to `canvas_esc_release`'s sibling walk (`xschem.tcl`); it has no `.drw` grab to release.
