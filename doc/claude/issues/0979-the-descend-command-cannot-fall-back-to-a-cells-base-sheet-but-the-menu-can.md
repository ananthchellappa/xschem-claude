# 0979 — `xschem descend` cannot fall back to a cell's base sheet, but the menu can

**STATUS: FIXED (2026-08-31, item S7).** `xschem descend` grows an opt-in
`-fallback` flag and the seven controls a person can press all pass it. The bare
form is unchanged, byte for byte — see "What landed" at the bottom.

## What the user sees

Nothing, today, if they use the menus. This one bites scripts and tests.

An instance may carry a `schematic=` attribute naming a sheet that does not
exist on disk. That is not a mistake — it is the library author's own idiom,
taught in words on the shipped `sky130_tests/gain_stage` sheet ("These
transistors have parametrized `modeln` attribute that can be set in instance
together with a instance based `schematic=....` attribute") and used by three
shipped instances. It is what makes the netlister write a SECOND copy of the
cell's body with the model that one instance asked for, and it is the mechanism
issue 0970 was repaired with.

When a person opens such an instance, the product asks them:

> Schematic /…/passgate_1 does not exist. Descend into base schematic?

and on Yes they land in the cell's own `passgate.sch`, which is the right
answer. That path is `callback.c:5490`, `:5493` and `:7668`, all of which call
`descend_schematic(0, 1, 1, 1)` — **fallback on**.

The `xschem descend` command cannot do that. `scheduler.c:3355`, `:3362` and
`:3364` all pass fallback as a hard-coded **0**, so a script or a test gets a
blank sheet at `<cwd>/passgate_1` and nothing is said about it.

## Measured

On the SHIPPED `sky130_tests/gain_stage` sheet, with none of item S4b's changes
applied, descending into `x6` (which carries `schematic=passgate_1`):

```
DESCEND x6 -> sch_path=.x6. file=/home/analog/dev/xschem-claude/passgate_1 instances=0
```

`sch_path` advanced, the file name is a path that does not exist, and the sheet
holds zero instances.

## Why it is not fixed here

Turning the flag on would make `get_sch_from_sym()` reach its `has_x && fallback`
arm, which calls `ask_save` — a **modal dialog**. Every GUI suite that descends
would hang on it, which is issue 0803 exactly. A fix needs a non-modal answer
for the scripted case (descend to the base sheet silently, or a new
`descend -base` form), and that is a user-visible decision, not a bug fix.

`tests/headless/test_ase_optier_0963.tcl`'s `n_dsc_base` works around it by
using the one-shot `hi_descend_view_path` override to land on the cell's base
sheet — the same sheet the person lands on.

## ⚠ ITEM S4b MADE THIS REACHABLE ON A SHIPPED BENCH

When this was filed it was a latent gap measured on `gain_stage`. The same item's
repair of issue 0970 gave `bandgap.sch`'s `x5` and `x6` a
`schematic=passgate_lvtp` attribute, so two of the five visually identical
passgates on that bench now take this path. That the name resolves to no file is
measured directly and is the root of it:

    grep -n "schematic=passgate_lvtp" .../sky130_tests*/bandgap/schematic/bandgap.sch
      sky130_tests_ase/.../bandgap.sch:120  (x5)
      sky130_tests_ase/.../bandgap.sch:122  (x6)
      sky130_tests/.../bandgap.sch:192      (x5)
      sky130_tests/.../bandgap.sch:194      (x6)

    ls sky130A/xschem_libs/sky130_tests/passgate/schematic/  ->  passgate.sch
    find . -name 'passgate_lvtp*'                            ->  (nothing)

The descend transcript itself was taken by the verification pass, not
reproduced by this write-up — a plain scripted `xschem descend` under
`--nogui` did not move the hierarchy here, so the shape below is theirs:

    INST x3 descend_rc=0 sch_path=.x3. schname=passgate.sch     instances=13
    INST x5 descend_rc=0 sch_path=.x5. schname=passgate_lvtp    instances=0

Before the repair all five behaved like `x3`. Through the **menu or the
keyboard** the person is still fine — that path passes `fallback=1` and asks
*"Schematic ... does not exist. Descend into base schematic?"*. Through the
`xschem descend` **command**, which a script or a keybinding may use, the user
gets `rc=0`, no message, and an empty buffer whose full name is
`<cwd>/passgate_lvtp`.

So the cost of the 0970 repair is not zero, and it lands on the bench the user
is about to inspect while ruling on 0965. That is part of the ruling: if the
`schematic=` mechanism is the right fix, this gap is worth closing; if it is
not, the alternative was deleting the `modelp=` line the user typed.



## What landed (2026-08-31, item S7)

`xschem descend` now accepts an optional leading `-fallback` flag
(`src/scheduler.c`, the `descend` branch). With it, all three argument shapes call
`descend_schematic(n, 1, 1, set_title)` — exactly what the right-click canvas item
has always done. Without it, nothing moved: same arguments, same return values,
same `descend_error` tokens.

**Why opt-in and not the default.** `tests/headless/test_op_annot.tcl` row W30a
asserts `{x6 1 load-failed} {x3 1 load-failed}` from a bare `xschem descend 1 2` —
the `1` is the hierarchy-level delta, so the test pins the stranding as a measured
invariant. Two committed workarounds and three scripted hierarchy walks read the
same `0`. Changing the default would have moved all of them at once, including
walks whose correct answer nobody has measured (issue 1233). Row A7 of
`tests/headless/test_descend_doors_1228.tcl` now pins the bare form from the other
side, so a later crew meets an explained assertion rather than a surprise.

**The seven controls that carry the flag:** the toolbar's `Push schematic` button,
the command-palette row `edit.push_schematic`, `Alt-E` (open in a new window),
`hi_descend_finish` (which is `E` and `Edit > Push schematic`), and the three
Cadence chords `Ctrl-X`, `Ctrl-Shift-X`'s edit sibling and `Alt-X` /
`Ctrl-Alt-D`'s path walk.

**Two neighbours had to land in the same pass** or the fix would have created a
worse defect than it cured: issue 1229 (the existence test sat behind the display
test, so a headless fallback discarded a *valid* binding) and issue 1230
(answering No still loaded the missing file).

**Read-only.** The Cadence-mode read-only stamp no longer requires the load to
have succeeded. A failed descend leaves the window one level down on a blank
buffer named after the missing file; that buffer used to come back **editable**,
so an accidental save would have created the junk file, inside the one mode whose
whole purpose is looking without touching.

**The workaround this retires:** `tests/headless/test_ase_optier_0963.tcl`'s
`n_dsc_base` used to arm the one-shot `hi_descend_view_path` override by hand; it
now just asks for the fallback. `src/op_annot.tcl`'s `_descend_to` **keeps** its
override on purpose — the deck names the exact file, which is strictly more precise
than "the cell's own sheet", and opening a sheet the deck did not name would be a
D5-1 plausible wrong answer.

Rows: `tests/headless/test_descend_doors_1228.tcl` A5, A6, A7, C3, D1, D2, D3, E1,
E6, F1.

## The blank page is not gone — only this issue's half of it (write-up pass, 2026-08-31)

This issue is about a copy whose own `schematic` setting names a file that is not
there, and that half is fixed. The blank page still happens when the **cell** has no
schematic file at all — no `schematic` setting anywhere, so `filename` is empty and
the whole fallback block, existence test and question included, is skipped. Measured
on shipped data (copy x7 of `xschem_library/inst_sch_select`, a `type=subcircuit`
symbol with no `.sch`): all three doors give `rc=0 currsch=1 instances=0`, no question.
Filed as **1234**, with the cause and the repair.
