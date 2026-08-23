# 0632 — the OP-annotation walk rewrites ancestor `~` backups when the entry sheet has unsaved edits

STATUS: **OPEN.** Measured 2026-08-22 on branch `annotate`, step **S3**, by the
S3 adversary and then re-measured and **narrowed** by the S3 write-up agent.
Landed anyway; S3 is status **E** partly because of this row.

This is the one thing that stopped S3 being an `x`. Invariant **I4** ("the
overlay never modifies the schematic") is **held on the clean path and open on
the dirty one**, and the spec's I4 cell has been amended to say so rather than
claiming a closure the code does not deliver.

---

## The claim that was refuted

S3's central claim included *"…without modifying the user's schematic (I4)"*.
`op_annot::_park_backup` (`src/op_annot.tcl:1805`) parks `::autosave_backup` at
0 for the walk **only when `xschem get modified` is 0**, because on a modified
buffer the `<cell>~.sch` is where the unsaved edits live and parking would throw
them away (that is issue **0626**, and it is why `_assert_saveable` refuses
`modified=1` + `autosave_backup=0` outright).

The consequence nobody guarded: **`modified=1` + `autosave_backup=1`** — the
shipped default combination — passes both `_assert_saveable` and `_park_backup`,
so the walk runs with autosave live and every `go_back` goes through
`load_backup_as` (`save.c:4191`), which loads that level's `~` content into the
buffer and calls `set_modify(1)` (`:4207`), which calls `write_backup()`
(`actions.c:208`).

---

## BEFORE — the adversary's transcript, verbatim

> **I4 / FILE WRITES - BROKE IT**. Planted a marker line in the shipped
> `sky130A/xschem_libs/sky130_tests_ase/bandgap_opamp/schematic/bandgap_opamp~.sch`.
> Walk from a CLEAN buffer: marker intact (the _park_backup fix works). Walk from
> a MODIFIED buffer with `autosave_backup=1` (the shipped default): marker GONE,
> md5 reverted to the .sch's content. `write_backup()` fires from `set_modify(1)`
> (actions.c:208) on the go_back path, and _park_backup (:1805) parks only when
> `xschem get modified` is 0. Control: a plain manual descend/go_back with
> modified=1 destroys it identically, so the MECHANISM is pre-existing - but S3 is
> a new one-click, whole-hierarchy trigger on a menu item documented as read-only,
> and rows W19a/W19b only ever measure the clean path.

> **SILENT UNDER-EMISSION / issue 0497 - BROKE IT**. Same state (entry modified=1,
> autosave_backup=1) plus a stale `bandgap_opamp~.sch` whose content differs from
> the .sch. `op_annot::save_cards` returned **rc=0** with 451 lines against the
> correct 469 - `x3.xm1`, `x3.xm2` and `xm3` missing entirely - `last_counts` =
> {dropped_by_rule 7 not_found 0 name_failed 0}, and the only warning read "7
> instance(s) were dropped by a netlister rule … - normal for such cells".

---

## AFTER — re-measured by the write-up agent, and the refutation is NARROWER

Both halves above were reproduced against a **hand-planted** `~` whose content
differs from what autosave would have written for the current buffer. That state
is not one the editor reaches on its own once the sheet is dirty: `set_modify(1)`
writes the backup at the moment of the edit, so `modified=1` under
`autosave_backup=1` implies the entry cell's `~` **already matches the buffer**.
Measured, on a byte-copy of the shipped `bandgap_opamp` with the `~` written by
the editor's own autosave rather than by hand:

```
AFTER-EDIT  inst=72 modified=1 bak=1 md5=819e5811588508b97d3bcd16b1edc9c1
AFTER-WALK  inst=72 modified=1 currsch=0 rc=0 lines=103
AFTER-WALK  bak md5=819e5811588508b97d3bcd16b1edc9c1  changed_by_walk=0
AFTER-WALK  C-lines in ~ = 72 ; in .sch = 73   (the user's edit is alive in both)
```

and the under-emission does **not** reproduce on the user's own bench either —
same cards, dirty or clean, on `sky130_tests_ase/tb_bandgap`:

```
CLEAN rc=0 lines=469 counts=dropped_by_rule 0 not_found 0 name_failed 0 modified=0
DIRTY entry inst=33 modified=1
DIRTY rc=0 lines=469 counts=dropped_by_rule 0 not_found 0 name_failed 0 modified=1 inst=33 currsch=0
DELTA missing=0
```

**The clean path writes nothing at all.** Full recursive `find`+`size`+`mtime`
signature over `sky130A/xschem_libs/sky130_tests_ase` across one walk:

```
CLEAN-WALK rc=0 lines=469 modified=0
DISK IDENTICAL = 1
```

**The dirty path does write, and this is the real residual.** Same signature,
same bench, entry buffer modified by one deleted instance, autosave ON:

```
DIRTY-WALK rc=0 lines=469 modified=1
DISK IDENTICAL = 0
  /sky130_tests_ase/bandgap_opamp/schematic/bandgap_opamp~.sch 7618 …113 -> 7618 …171
  /sky130_tests_ase/tb_bandgap/schematic/tb_bandgap~.sch       3799 …170 -> 3799 …171
```

The entry cell's own `~` (`tb_bandgap~`) is rewritten with content it already
had — harmless. **`bandgap_opamp~.sch` is an ANCESTOR two levels down the walk,
in a cell the user never touched, and the walk rewrote it.** Sizes are unchanged
only because the shipped `~` happens to be byte-identical to its `.sch` — the
Measure agent recorded that coincidence in the same words ("today they happen to
be byte-identical on bandgap_opamp, so nothing is lost by luck").

So the accurate statement of the defect, replacing the adversary's:

> With unsaved edits on the entry sheet and `autosave_backup` on, the walk does
> not park autosave, so **every intermediate level that has a `<cell>~.sch`
> beside it has that backup's content loaded into the buffer and the file
> rewritten**. Where such a backup is genuinely stale — a crashed session's
> recovery file — the walk silently continues in the **backup's** content while
> the deck index describes the **disk** content, and under-emits at `rc=0` with
> the `dropped_by_rule` counter and the words *"normal for such cells"*. That
> last sentence is exactly what issue **0497** was filed about, and the 0497
> three-counter split cannot see it: `not_found` stayed **0** while devices
> vanished.

`_block_is_here` (`src/op_annot.tcl:1929`) cannot catch it either — it compares
`xschem get schname`, and `load_backup_as` deliberately re-asserts the cell's
logical identity after loading the backup (`save.c:4204-4206`), so the guard
sees the right name over the wrong content.

---

## DECISION — record it, do not patch it in the write-up pass

**Ladder rung L2** (smallest blast radius), with the L3 half handed to the user.

Not fixed here, and deliberately. Three candidate fixes exist and **all three are
structural, not one-liners**:

* **park below the entry only** — park `::autosave_backup` after the first
  `descend` and unpark before the final `go_back` into the entry level. This is
  the correct fix and it is surgery inside `_walk`/`_unwind`, needing its own
  guardian rows, its own sabotage variant and its own adversary pass.
* **refuse any modified entry buffer**, making `_assert_saveable` symmetric.
  One line, but it *changes user-visible behaviour* and contradicts row **W31**,
  which asserts today that `modified=1` + autosave ON is walked. That is the
  user's call, and it is the same question as issue **0628**.
* **warn by name** instead of refusing. Cheapest, but cosmetic against a hazard
  whose real fix is the first bullet.

**Rejected: patching it in the write-up pass.** A behaviour change introduced
after the sabotage and adversary passes have run is unverified by construction,
and this step has been reverted four times for precisely that class of
late, unguarded addition. Recorded, filed, propagated to the plan, and left for
a crew that can carry a guardian with it.

---

## STILL OPEN

1. The dirty-entry path above, in full. **The fix owes a guardian that plants a
   `~` on an INTERMEDIATE level, not on the entry cell** — rows W19a/W19b only
   ever plant one beside the entry, which is why this survived them.
2. `op_annot::last_counts` cannot distinguish *"the netlister dropped it"* from
   *"the walk was standing in the wrong cell content"*. A cross-check of the
   emitted card device set against the deck's own element set for the block
   being walked would catch it; `_walk` already holds `idx` and `block` at that
   point. Rider on issue **0497**.
3. `_walk` caches `xschem get instances` before descending and indexes by
   position afterwards, so a `go_back` that reloads a level from a `~` with a
   different instance count raises `xschem getprop: instance not found:<n>`.
   Loud today, and only because the stale file the adversary planted happened to
   be smaller.
4. Unreproduced, recorded not claimed: one run in ~14 of a 30-trip forced-raise
   sweep came back with `no_draw=1 keep_symbols=1 _busy=1`, the signature of
   `op_annot::_restore` never running, after which the `_busy` latch legitimately
   refuses every later call. Not reproduced in 13 further runs and no code path
   explains it (every line of `_restore` before `set _busy 0` is catch-wrapped).
   A `_busy` self-heal — clear it when `currsch` equals the entry level and no
   walk is in flight — is worth more than a hunt.
5. `_wrap` kind 1 (`:422`) returns `${dev}[${param}]` and `_cards_for` (`:1864`)
   retypes `.save ${dev}\[…\]`. They agree today (78 devices, 0 mismatches) and
   the device **path** still has one builder, so this is not an I1 breach — but
   it is the same drift shape one level down, and `_wrap $dev $param 1` removes
   it at zero cost.
6. `_restore` resets `no_undo` to 0 unconditionally rather than to its entry
   value, because there is no getter (issue **0432**). A caller that had
   deliberately set `no_undo 1` around the menu action silently gets it cleared —
   **`render_deck` is that caller**, which S4 must handle.
7. `write_save_file` writes to `$netlist_dir`, not to the directory the user's
   own netlist lands in when `local_netlist_dir` is set, so the `.save` file and
   the deck it is meant to be `.include`d from can end up in different trees.
8. The menu item added at `src/xschem.tcl:15476` is X-only and was exercised in
   this step only through `op_annot::write_save_file` directly. Its `alert_` and
   `textwindow` arms are unmeasured. A `look`/`suite` debt is in the ledger.

---

## 2026-08-23 — what S4 did about this, and what it did NOT do

The ASE path (`ase::op_cards_capture`, src/ase.tcl) **refuses** to build the OP
save cards whenever `ase::design_is_dirty` (= `xschem get modified`) is true, and
reports both the unsaved edits and this issue number. So the one-click
Netlist-and-Run route into the disputed behaviour is closed for now.

Two things this did NOT do, deliberately:

* it did **not** change `op_annot::_assert_saveable` or any op_annot policy. That
  gate refuses only `modified=1 + autosave_backup=0`; this issue's live hazard is
  `modified=1 + autosave_backup=1`, the shipped default. Tightening it would also
  silently change the shipped *Create device OP .save file* menu item and redden
  test_op_annot W31.
* it did **not** settle this issue. The refusal is PROVISIONAL and is filed as
  its own question in **0633**; if the ruling lands on "walk anyway", the row to
  rewrite is `test_ase_core.tcl` C12.

**Correction to still-open item 6 of this issue, measured:** it claims
`render_deck` wraps `save_cards` in its own `no_undo 1` scope and would be
silently disarmed by the restore. `grep` finds no `no_undo`, `no_draw` or
`keep_symbols` anywhere in `src/ase.tcl` or `src/ase_window.tcl`, and S4 adds no
such scope. There is nothing to defend against on this tree.
