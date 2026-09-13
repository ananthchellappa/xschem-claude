# 1448 — the handle is visible, and the second row of a type is reachable

**Status:** fixed (⚖ R6's GUI half; two of issue 1444's four surfaces — see *What is still owed*)
**Branch:** `fluid-editing`
**Area:** ASE-L — the Choose Analyses dialog and the Analyses menu (`src/ase_window.tcl`)
**Suites:** `tests/headless/test_ase_dialogs.tcl` section GH (18 rows, display arm)
**Batch:** `doc/claude/ase_analyses_batch/`, ⚖ **R6**'s addressing task
**Ships the surfaces issue 1447 left open.** 1444 stays open for the other two.

---

## The defect

Issue **1447** gave every analysis row a name. **Nothing rendered one**, and the row
that the name was invented for could not be edited at all.

* **`ase::ui::chana_row` returned the FIRST row of its type** — its own header said so,
  *"the FIRST state row of `type` ... extra same-type rows stay X-deletable in the
  pane"* — and `ase::ui::pane_dblclick` derived a type from the row the user
  double-clicked and then **threw the index away**. So a bench that says *"sweep VIN,
  **and also** sweep temperature"* — the bench ⚖ R6 was ruled to make possible — had a
  second `dc` row that could be **deleted from the pane and never edited**. Both doors
  into the dialog, and both commit doors inside it, walked to the first row of the type.
  `DECISIONS.md` ⚖ R6 records it from the other side and calls it *"the work"*.
* **The word itself was invisible.** `ase::analysis_handles` answered `dc1`/`dc2`, and a
  user had no way to learn which was which — which is the whole of the user's request:
  *"It should be easy for a user to find out how to refer to different analyses for
  purposes of building measure statements."*

## What shipped

**Three surfaces and one mechanism.**

| | |
|---|---|
| **the handle grid** | a `ttk::treeview` in the Choose Analyses dialog, one line per analysis row — `Handle`, `Type`, `Enable`, `Arguments` — rendering `ase::analysis_handle_fields`. Picking a line edits **that** row |
| **`Analyses > List`** | a read-only viewer whose whole body is `ase::analysis_handle_text`, every row, disabled ones marked `(off)`. Ctrl-W closes it |
| **row addressing** | `dlg($key,anrow,<type>)`, read through the one proc `ase::ui::chana_row_idx`, which `chana_row`, `chana_ok` and `chana_x_ok` all now ask |

```
Handle  Type  Enable  Arguments
op1     OP      ☑
dc1     DC      ☑     V2 0 1.8 0.01
ac1     AC      ☐     dec 10 1 10meg
tran1   TRAN    ☐     1n 10u
dc2     DC      ☐     TEMP -40 125 5
```

## ⚠ The decision the schema half did not settle: the edit cache is keyed by HANDLE

⚖ R5 (issue 1445) keyed the dialog's per-edit cache by **type**, because a type was the
only identity a row had. The moment two rows of a type are reachable that is a leak with
a straight face: type `5u` into `dc1`, click `dc2`, and a type-keyed cache overlays
`dc1`'s edit on `dc2`'s form — the user is looking at a temperature sweep wearing a
voltage sweep's numbers, and pressing OK writes them.

**`ase::ui::chana_cache_key` answers `ase::analysis_handle`'s word**, or `*<type>` for a
type with no row (no handle can begin with `*`: `ase::analysis_id_ok` requires a bare
identifier and a derived handle is `<type><n>`). Row **GH6** is that sentence as a
measurement, and sabotage **s5** — the cache keyed by type again — reds it **plus six
existing ⚖ R5 / 1446 rows**.

**And the key is snapshotted, not recomputed.** `dlg($key,anshownkey)` is taken when the
form is built, for `anshown`'s own reason one level down: picking a line sets the
addressing and *then* rebuilds, so a save that computed the key at save time would file
`dc1`'s typing under `dc2`. Sabotage **s8** is exactly that and reds GH6.

## ⚠ The defect this found in the half that shipped before it

**`ase::analysis_emit_check` has never heard of `id`.** Its `known` list is
`{type enabled x}` plus the declared field names (`src/ase.tcl:4615`), and issue 1447
added `id` to the **row** without adding it there. `ase::preflight_gate` runs that check
over every **enabled** stored analysis row before a run, so:

```
ase::analysis_emit_check ngspice {type dc enabled 1 source V2 start 0 stop 1.8 step 0.01 id vinsweep}
  ->  {unknownkey id {has a setting named 'id' that ASE-L cannot emit}}
ase::preflight_gate  with the id  ->  emit_incomplete
ase::preflight_gate  without it   ->  {}
```

**A user who names an analysis and switches it on cannot run the bench**: no deck, no
raw, no log, and `set ase_preflight 0` does not disable it. The surface this issue ships
is the one that invites them to do it.

**The fix is one word — `set known [list type enabled x id]` — and `src/ase.tcl` was not
this task's file.** Row **GH13b** pins all three measurements, with the identical
id-less bench as its paired control (sabotage **s11** collapses the control and reds the
row). When the word lands, GH13b goes red and names this paragraph.

⚠ **The Choose Analyses commit door is NOT the exposure**, which was measured rather than
assumed: `chana_ok`'s D6 probe is built from `vals`, the form's **declared fields**, so a
row key the form knows nothing about never reaches the check. Row **GH13** was first
written expecting a refusal; the dialog disagreed and the dialog was right.

## Measured

```
104 of 104 tracked .state files load and re-serialize BYTE-IDENTICALLY
   0 committed analysis rows carry `id`
```

`test_ase_dialogs` **37 / 322 → 37 / 340**, headless unmoved because every GH row drives
widgets. The one red on the display arm is `G2sens`, issue **1436**, with the identical
actual value it has carried since before this change; `GG9` passed on every run of both
arms. **Sixteen sabotages**, each restored by `cp` + md5; every GH row has at least one
witness and four of them redden rows in sections this change did not write.

## What is still owed — issue 1444 stays open

| surface | status |
|---|---|
| handle column in Choose Analyses | **delivered here** |
| `Analyses > List` | **delivered here** |
| Measurements dropdown | open — Stage 8 task 2 |
| an **editable `id` field** | open — and blocked by the `emit_check` defect above |

The editable field is deliberately not in this change: it would put the `id` key on the
commit path, and until `ase::analysis_emit_check` knows the key, a field that wrote one
onto an enabled row would stop the bench running. **Fix `src/ase.tcl` first.**

## Ruling owed

Four new user-facing strings ride ⚖ **R9** — the `Handle` column heading, the `List` menu
entry, the list window's title, and the empty-bench sentence. Filed with
`owed.sh add rule 1448`. The five strings already in the review as **R9-373 … R9-377**
are consumed unchanged, not re-minted.

A `look` debt is filed: this is a new grid and a new window, and a green suite is not a
pair of eyes.
