# PLAN — selectall_getprop_batch

Two wish-list items, one stage each, plus a recon stage. Driver orchestration: one task per
crew, receipt back, driver gates and commits. Read `CREW_BRIEF.md` first.

Opened 2026-09-29 at `b89fddda`, T1 baseline `107/106/0/8`.

## Stage R — recon (read-only, no edits)

**Deliverable:** a written answer to the questions below, as `receipts/R-recon.md`. Nothing
in the tree changes. This exists because the driver's own scouting has been wrong twice in
a row and a plan built on it should be checked before code is written.

**Stage A questions (Ctrl-A):**
1. What exactly does `ctrl+a` do today when the pointer is over a waveform graph? Trace the
   real path: `keybindings.csv` → the action name → what it dispatches to in C or Tcl.
2. What is the existing trace-selection model? Name the procs and the C entry points
   (`wviewer::model_sel`, `sel_waves`, `graph_sel_waves_set`, `edit_wave_attributes` are the
   leads from issues 0175/0176 — verify, do not assume).
3. What does Delete-the-selection already do, and what does it require the selection set to
   look like? Ctrl-A must produce exactly that shape or the existing delete path will not
   consume it.
4. Which suite should carry the fence, does it already exist, is it registered in T1, and
   does its epilogue satisfy `banner_complete`?
5. ⚠ Does `select_all()` in `src/select.c` get reached by ctrl+a over a graph, and if so
   what does it select? The driver's scouting claims it selects schematic rects with zero
   wave awareness — verify that claim or refute it.
6. Is there any conflict with Ctrl-A elsewhere (the schematic canvas, a dialog, a text
   entry)? Name what must NOT change.

**Stage B questions (getprop):**
7. Enumerate the **actual** `getprop` arms in `scheduler.c` — every object type, and for
   each: does it return a full property string, a single token, or nothing at all? The
   driver's scouting says instance / instance_notcl / symbol are full, rect / text / wire are
   token-only, and line / poly / arc have no arm. **Verify each of the nine and correct the
   list.**
8. For line, poly and arc: what does the object actually store that a property read could
   return? Name the struct fields (`xLine`, `xPoly`, `xArc` in `xschem.h`).
9. What is the exact existing call syntax, and what would the new arms' syntax be? Is there
   a `setprop` counterpart whose spelling the new arms should mirror?
10. What does `xschem object` / `xschem objects` return today, and is there an existing
    address-only API these arms should compose with?
11. Which suite should carry the fence — existing or new — and the same registration and
    banner questions as (4).
12. ⚠ Is there an existing spec that constrains the answer? `doc/claude/specs/property_introspection.md`
    is the lead. Say whether it is stale, and whether it commits to a syntax.

**Also report:** any user-visible surface either stage would touch, since those are the
user's to ratify and not the crew's to decide.

## Stage A — Ctrl-A selects all traces (issue 1617)

**Deliverable:** working code + fence, uncommitted, receipt `receipts/A-impl.md`.

Red first. The scope is: over a waveform graph, Ctrl-A puts **every drawn trace** into the
existing trace-selection set, so the existing Delete path can act on it. Out of scope:
changing what Ctrl-A does anywhere else, and changing the delete path itself.

Constraints:
* Reuse the shipped selection model. Do not invent a second one.
* The action must be **logged replayably** if the surrounding gestures are — check what
  `wviewer::log_action` does for the sibling gestures and match it.
* If the binding is remappable via `keybindings.csv`, it must go through that table rather
  than a hard-coded `bind`.
* Fence both directions: selecting all when there are traces, and the empty case.

## Stage B — the missing `getprop` arms (issue 1618)

**Deliverable:** working code + fence, uncommitted, receipt `receipts/B-impl.md`.

Red first. The scope is: close the gaps Stage R's answer to question 7 actually establishes
— which is expected to be arms for line, poly and arc, plus whatever rect / text / wire
cannot currently report. Out of scope: item 26's `o~>prop` handle syntax, and any change to
`setprop`.

Constraints:
* **Mirror the existing arms' shape.** A new arm that answers in a different grammar from
  the shipped ones is a worse outcome than the gap.
* C89 (this tree targets it), `_ALLOC_ID_` placeholders for allocations — never hand-numbered.
* A bad index or a missing object must return an error or an empty string **consistently
  with the existing arms**, not a crash and not a fabricated value. Fence that.
* If an existing arm's behaviour is wrong rather than missing, say so in the receipt and do
  not silently change it — that is a separate issue.

## Driver-retained work (not for crews)

* Issue numbers **1617** and **1618**, already minted; `NUMBERING.md` entries.
* Issue files with valid `**STAMP:**` lines (`tclsh tests/headless/issue_stamp.tcl` → ok).
* The solo T1 gate in a fresh `git clone --local --no-hardlinks` at a **short** path,
  `./configure && make` from scratch, zero live-peer lines.
* Commits, the commit messages, and the push.
* Judging whether any red is real, and whether a sabotage genuinely reddened.
* `CLAUDE.md` baseline update if the case count moves.
