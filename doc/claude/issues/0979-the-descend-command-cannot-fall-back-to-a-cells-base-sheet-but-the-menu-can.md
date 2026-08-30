# 0979 — `xschem descend` cannot fall back to a cell's base sheet, but the menu can

**STATUS: FILED, NOT FIXED (2026-08-30, item S4b).**

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

