# 1717 — crash recovery is offered only when a cell is opened in place: a routed open, `load_new_window` and descend never offer it, and the first edit then overwrites the previous session's `cell~.sch`

**STAMP:** `v1 claim=open tree=e6b38ba83 stamped=2026-11-15 fix=untried open=1 by=drag_perf-D3`

Found by the drag-performance batch's verifier (finding G2 of
`doc/claude/drag_perf_batch/receipts/D2-verify.md`) and re-measured while filing, on the base
build `e6b38ba83` and on stage D3's fix tree (`e6b38ba83` + stage D + D3), which agree on every
line below. **Present on the base build; the drag batch did not cause it.** Filed, not fixed.
Whether upstream xschem shares it was not checked.

## Measured while filing

A private Xvfb, a throwaway HOME, the `sky130_tests_ase` testbench `tb_bandgap` and its `bandgap`
cell on a scratch copy. Before each open, a foreign `bandgap~.sch` was planted: the cell's own
text with pin `p2` moved from `150 -130` to `220 -80`, and an mtime 60 s newer than the cell, as a
crashed earlier session would leave it. Then `bandgap` was reached four ways, and one wire was
drawn (any edit):

| how `bandgap` was reached | recovery offered | `~` before the edit | `~` after the edit |
|---|---|---|---|
| `xschem load -gui` into an empty untitled window (opens in place) | once ("Recover unsaved changes?") | handled by the offer | this session's sheet |
| `xschem load -gui` from an occupied window (routed to a new tab) | no | the foreign `p2 220 -80` | this session's sheet, `p2 150 -130` |
| `xschem load_new_window` | no | the foreign `p2 220 -80` | this session's sheet, `p2 150 -130` |
| `xschem descend` into `x1` from `tb_bandgap` (`descend_readonly 0`) | no | the foreign `p2 220 -80` | this session's sheet, `p2 150 -130` |

So on the three routes a user restarting after a crash is most likely to take (reopen the
testbench and go down into the cell, or open the cell from a window that already holds
something), the backup is never mentioned, and the first edit replaces it: the only copy of the
earlier session's work is gone, with nothing said.

## Cause (by reading code)

- The `xschem load` branch of `xschem()` (`src/scheduler.c`) calls `xschem_recover_backup`
  (`src/xschem.tcl`) only in its in-place `load_schematic()` arm (`if(!force && has_x)`). The
  routed arm goes through `new_schematic("create", "noconfirm", …)` and never reaches it.
  `load_new_window` and `descend_schematic()` (`src/actions.c`, which loads the child with
  `load_schematic()`) have no call either.
- `write_backup()` (`src/save.c`) runs on the first `set_modify(1)` and writes this session's sheet
  over whatever `cell~.sch` is there.

## Related

- **0362** (the `~` has no "whose work is this" identity): its consequence 3 is a *save*
  destroying a backup the user was never shown, and it notes that headless opens never get the
  offer. This issue adds the routed open, `load_new_window` and descend as doors that never offer,
  and the first *edit* as the destroyer. A writer that could tell a foreign `~` from its own needs
  0362's identity; the missing offer does not.
- **1715** (go_back adopted a foreign `~` as the parent's unsaved edits; fixed by stage D of the
  drag-performance batch by recording which backups this session wrote).

## Open item

1. Decide where the offer belongs: in every door that opens a cell into a fresh buffer (the
   routed `load -gui`, `load_new_window`, `descend`), or once, before the first `write_backup()`
   of a cell this session has not written. The second also covers doors not listed here, but asks
   at the first edit rather than at the open. Not built.
