# 1450 — the Options editor refused every row that carried a name

**Status:** fixed
**Branch:** `fluid-editing`
**Area:** ASE-L — the one list of non-setting row keys (`src/ase.tcl`) and its
three readers (`src/ase.tcl`, `src/ase_window.tcl` ×2)
**Suites:** `tests/headless/test_ase_core.tcl` section **NS** (both arms),
`tests/headless/test_ase_dialogs.tcl` section **NX** + the rewritten **GH13b**
(display arm)
**Batch:** `doc/claude/ase_analyses_batch/`, the tail of ⚖ **R6**
**Found by** issue **1449**'s task, which measured it and could not fix it: the
second and third copies live in a file that task was not given.

---

## The defect

**Opening `Options…` on an analysis row that carried a name — or a verbatim
hatch — listed the key as a free-text setting and then refused to save.** The
editor could not be opened-and-saved on such a row at all, and the one gesture
that *did* get an OK out of it was **deleting the name**.

`DECISIONS.md` **D4** licenses exactly **two** optional per-row keys: `id` (⚖ R6's
stable handle) and `x` (issue 1419's verbatim `.control` lines). Three places in
the tree kept a list of *"keys on an analysis row that are not settings"*, and the
three disagreed:

| place | its list | knew `x`? | knew `id`? |
|---|---|---|---|
| `ase::analysis_emit_check` (`src/ase.tcl`) | `type enabled x id` + declared fields | yes, since **1419** | yes, since **1449** |
| `ase::ui::chana_options` — the subdialog's **reader** | `type enabled` + declared fields | **no** | **no** |
| `ase::ui::chana_x_ok` — the subdialog's **writer** | `type enabled` + declared fields | **no** | **no** |

Measured through the real widgets on the unfixed tree, on one `dc` row carrying
both keys — `{type dc enabled 0 source V2 start 0 stop 1.8 step 0.01 id vinsweep
x {{echo hi}}}`:

```
the pairs Options... SHOWS : {id vinsweep} {x {{echo hi}}}
after OK, still up         : 1            (the subdialog is left standing)
the stored row now         : unchanged
what it SAID               : ase: this dc analysis has a setting named 'id'
                             that ASE-L cannot emit
status line                : This dc analysis has a setting named 'id' that
                             ASE-L cannot emit.
```

and each key alone reproduces it, while the identical row with neither key
commits and closes:

```
ONLY-x   shows {x {{echo hi}}}   OK-closed=0   said: ... named 'x' that ASE-L cannot emit
ONLY-id  shows {id vinsweep}     OK-closed=0   said: ... named 'id' that ASE-L cannot emit
NEITHER  shows                   OK-closed=1
```

⚠ **`x` had been in this state since issue 1419** — three weeks and four commits
— and nothing noticed, because **each of the three sites was right about
itself**. `id` joined it with ⚖ R6 and was fixed in one of the three by issue
1449.

⚠ **AND THE WRITER'S HALF WAS THE SHARPER ONE.** `chana_x_ok` strips the row
before writing it back:

```tcl
foreach k [dict keys $row] {
  if {[lsearch -exact $skip $k] < 0} { set row [dict remove $row $k] }
}
```

With a `skip` that has never heard of `id` or `x`, that loop **deletes both** on
the way past. The refusal above happened to fire first, so the destruction was
latent rather than shipped — but "the commit door destroys the handle" is one
reordered `return` away, and nothing in the tree said so.

## The fix — one proc, three callers

The structural defect is not the two stale copies. **It is that the list was
copied at all**, which makes a fourth copy the natural way to write the fifth
surface. The answer now lives in one place, in the schema namespace, because the
schema owns what a row's keys mean (**D34**–**D37**):

```tcl
proc ase::analysis_nonsetting_keys {} {
  return {type enabled x id}
}
```

| caller | what it used to spell |
|---|---|
| `ase::analysis_emit_check` (`src/ase.tcl`) | `set known [list type enabled x id]` |
| `ase::ui::chana_options` (`src/ase_window.tcl`) | `set skip [concat {type enabled} [ase::ui::chana_fields $type $_sim]]` |
| `ase::ui::chana_x_ok` (`src/ase_window.tcl`) | the same line again |

⚠ **IT ANSWERS NOTHING ELSE.** It is not "keys to ignore". `analysis_emit_check`'s
job is refusing a key that would **silently not emit** — issue 1418 is what a
dropped setting costs, issue 1401 what a dropped analysis costs — so a third
optional key is a change to **D4** and to this proc, deliberately, with its own
reason written down, and not a shrug. Row **NX3** is that guard from the GUI side
and **NS1**'s wide stub from the core side.

⚠ **AND `Add` IS UNCHANGED.** Typing `id` or `x` into the subdialog's NAME/VALUE
pair is still refused, because neither is a setting this editor sets: `id` is
written by ⚖ R6's own surfaces and `x` is the hatch. Row **NX4** pins it — without
it, *"hide them from the list"* and *"let the list edit them"* are
indistinguishable.

## The fourth-copy guard

A runtime row cannot see a fourth copy: a copy is **correct on the day it is
written** and wrong the day D4 gains a key. That is exactly how `Options…` spent
three weeks refusing every row that carried `x`. So **NS2** scans `src/ase.tcl`
and `src/ase_window.tcl` for a hardcoded list literal on any line that is not
wholly a comment, and requires **exactly one** — the proc's own `return`. Its
third and fourth terms are the positive controls: the scanner really does match a
copy-shaped line, and really does **not** match `dict create type $type enabled 0`,
which is a row being built rather than a list being copied.

## What `GH13b` asserted, and what it asserts now

`test_ase_dialogs` row `GH13b` was written by issue 1448's task to pin issue
1449's defect, and its header said *"Fixing it turns that row RED, which is the
point."* 1449 landed, so it was red.

| | |
|---|---|
| **before** | `{unknownkey id emit_incomplete {}}` — the emit check refuses `id`, the gate refuses the whole bench, and the identical bench without the key runs |
| **now** | `{{} {} {} {dc V2 0 1.8 0.01} emit_incomplete vinsweep dc1}` — the emit check is clean, the gate is **silent**, the paired id-less bench is silent too, the row still renders its analysis card, a **third** state carrying a key nothing can spend is still refused, and the two fixtures **disagree about their own handle** |

⚠ **The paired control was kept and a third state was added, because the pair no
longer disagrees.** Under the defect `GH13G` and `GH13GN` answered differently and
that difference *was* the row; now both answer `{}`, so a gate that had stopped
running at all would satisfy both terms.

## Measurements

* `test_ase_core` **624 → 626** (section **NS**), `ALL PASS` on **both** arms.
* `test_ase_dialogs` **37 / 340 → 37 / 346** (section **NX**, six rows, display
  only). Display arm **2 FAILED (338 passed) → 1 FAILED (345 passed)** — the one
  remaining red is the standing `G2sens` (issue **1436**), value
  `{1 1 0 1 0 Entry Entry normal}`, unmoved. Headless unmoved at 37 because every
  NX row drives widgets.
* **104 of 104** tracked `.state` files load and re-serialize **byte-identically**
  (416 analysis rows, **zero** carrying `id`, **zero** carrying `x`); the
  in-process control — one `id` added to one committed row — disagrees, so the
  comparison is not vacuous. No tracked `.state` file modified. **No new state
  key, no schema version bump, nothing added to `ase::omit_if_empty`.**
* `test_ase_persist` 49 / 153, `test_ase_meas_1443` 100 / 100,
  `test_ase_window` 56 / 295, `test_ase_preflight` 235 / 235,
  `test_ase_options_1437` 75 / 75 — `ALL PASS`, both arms.
* **No new user-facing sentence.** The user-visible change is a sentence that
  **stops** being shown, and two free-text pairs that stop being listed.
* **Pure Tcl on both sides**, and no simulator is started by any new row: the
  three-binary rule (apt 45.2 *and* the fork) does not apply — nothing here
  emits, reads back or offers anything a simulator sees. The deck the fix
  unblocks is byte-identical to the one an id-less bench already rendered, which
  issue 1449 measured.

## The ruling this leaves open — ⚖ R9

**Should `Options…` TELL the user their row carries a name?** The keys are no
longer listed there, and this is the user's call, not a crew's.

⚠ **And the two keys are NOT equally visible elsewhere**, which is what makes
this a ruling rather than an edit. Measured on the row above:

```
handle grid, Handle column     : vinsweep
Analyses > List                : vinsweep  DC  V2 0 1.8 0.01
handle grid, Arguments column  : V2 0 1.8 0.01              <- no hatch
main window Analyses pane      : dc V2 0 1.8 0.01  + verbatim: 1 line
```

`id` is on screen **twice inside the very dialog** whose button opens the
subdialog. `x` is mentioned only in the **main window's** Analyses pane: the
grid's Arguments column is `ase::analysis_line`'s answer (through
`ase::analysis_handle_fields`) and not `ase::ui::arg_summary`'s, so it never
carries the `+ verbatim` clause.

* **A — say nothing new (recommended, and what shipped).** Issue 1444's own
  argument — *three surfaces showing three spellings would be worse than none* —
  applies to a fourth, and the old list was never an editor for these keys
  anyway: it refused to save.
* **A′ — A, but give the handle grid's Arguments column the `+ verbatim` clause
  the main window's pane already has.** The narrowest answer to the asymmetry
  above, and it adds **no new sentence** — the clause exists and is already
  ratified; it would simply be shown in a second place.
* **B — a read-only line at the head of the subdialog**, e.g. `HANDLE: vinsweep`.
  Costs one new sentence and one more place the handle is spelled.
* **C — list the two keys again, greyed and not editable**, with a note. Closest
  to the old pixels; also the shape that made the old list look like an editor
  when it was not.
* **D — A, plus a sharper refusal at `Add` for exactly these two keys.** Today
  typing `id` there answers *"has a setting named 'id' that ASE-L cannot emit"*,
  which is now the wrong reason — the reason is that it is **not a setting**.
  That sentence is unchanged from before this fix, so leaving it is not a
  regression; changing it is a new sentence.

`owed.sh add rule 1450` filed. A `look` debt is filed too: the subdialog's list is
empty where it used to hold two rows, on any bench that carries either key.

## What is still owed

Nothing from this issue. Issue **1444**'s editable `id` field and the
Measurements dropdown remain open, and this removes the last reason they were
blocked: a row carrying an `id` can now be run **and** edited.
