# 0626 — `descend` + `go_back` with `autosave_backup=0` silently REVERTS the parent's unsaved edits

STATUS: **OPEN.** Measured 2026-08-22 on branch `annotate` at `4853cbd2` by the
S3 crew, on a byte-copy of the shipped `sky130A/xschem_libs/sky130_tests_ase/
bandgap_opamp/schematic/bandgap_opamp.sch`.

Not op_annot's invention. `proc traversal` (src/xschem.tcl:3590), both PDK
prototypes (`sky130A/sky130_procs.tcl`, `ihp-sg13g2/sg13g2_procs.tcl`) and
`hierarchy_close` all reach it. S3's new **Create device OP .save file** menu
item is a new **one-click** way in, which is why S3 refuses rather than walks.

⚠ **THE OTHER HALF OF THE MATRIX IS ISSUE [0632](0632-op-annot-walk-writes-ancestor-autosave-backups-when-the-entry-sheet-is-dirty.md)
AND IT IS NOT GUARDED.** S3 refuses `modified=1` + `autosave_backup=0` (this
issue). `modified=1` + `autosave_backup=**1**` — the shipped default — is
**walked**, and 0632 measures what that costs: the walk rewrites the
`<cell>~.sch` of **ancestor** levels the user never touched, and over a genuinely
stale one it under-emits at `rc=0` saying *"normal for such cells"*. **Rule on
both together** — if the ruling is *refuse*, the cheapest correct shape is to
refuse **any** modified entry buffer and drop the autosave condition entirely.

---

## MEASURED

```
xschem load <copy>/bandgap_opamp.sch          -> 73 instances, modified 0
set ::autosave_backup 0
select last instance ; xschem delete          -> 72 instances, modified 1
xschem select instance 0 ; xschem descend 1 2
xschem go_back 2                              -> 73 instances, modified 1   <-- the edit is GONE
```

With `::autosave_backup 1` the same sequence keeps **72** — the edit survives,
because `descend` wrote `bandgap_opamp~.sch` on the way down (save.c:4156) and
`go_back` loaded it back (`load_backup_as`, save.c:4191).

Two things are wrong at once:

1. **The unsaved edit is reverted**, with no prompt and no message. The in-memory
   buffer is replaced by the on-disk `.sch` (actions.c:4766 → the
   `load_schematic(1, filename, …)` fall-through when `load_backup_as` returns 0
   at save.c:4197).
2. **`modified` still reads 1** afterwards. So the buffer claims to hold unsaved
   work that no longer exists, and a subsequent Save writes the *disk* content
   back over itself while the user believes their edit was kept.

## MECHANISM

`load_backup_as` (save.c:4191) is the only thing that carries a modified parent
across a descend/go_back round trip, and its **first** guard is
`if(!tclgetboolvar("autosave_backup")) return 0;` (save.c:4197). With the flag
off there is no `~` trail (`write_backup` returns at save.c:4156 for the same
reason), so the ascent has nothing to restore from and silently reloads the
cell. Issue 0060 fixed the *untitled* half of this; the titled half is gated on
`autosave_backup` and was never closed.

## WHY S3 REFUSES RATHER THAN FIXES

S3's Files cell is `src/op_annot.tcl`. A fix belongs in `go_back`/`descend` and
its blast radius is **every** descend/go_back user in the tree — the two PDK
prototypes, `traversal`, `hierarchy_close`, the context menu, Ctrl-E and
BackSpace. That is its own step.

`op_annot::_assert_saveable` (src/op_annot.tcl) therefore refuses the one
combination that loses data — `modified == 1` **and** `autosave_backup == 0` —
and names both halves in the message so the user can act (save, or turn autosave
back on). Guardian: `tests/headless/test_op_annot.tcl` row **W31**, whose
sabotage variant `save_gate_off` reddens it and nothing else.

**Note the asymmetry S3 relies on**: with the buffer **clean** the same flag can
safely be *parked at 0* for the duration of a read-only walk, which is what
closes issue 0495 — see `op_annot::_park_backup` and rows W19a/W19b.

## OPTIONS FOR THE FIX (not taken here)

1. `go_back` warns (or asks) when `xctx->modified` is set and no backup exists.
   Smallest honest change; still loses the edit if the user says go ahead.
2. `descend` forces a save (pre-B5 behaviour) when `autosave_backup` is off.
   Restores an old, disliked behaviour.
3. Keep the parent's in-memory buffer across the round trip instead of reloading
   it at all. Largest, and the only one that loses nothing.

## ACCEPTANCE, WHEN IT IS FIXED

* a modified parent + `autosave_backup 0` + descend + go_back keeps the edit, or
  says so out loud;
* `modified` never reports 1 over content that matches the disk;
* `op_annot::_assert_saveable`'s refusal can then be relaxed, and row W31
  rewritten to assert the new behaviour.
