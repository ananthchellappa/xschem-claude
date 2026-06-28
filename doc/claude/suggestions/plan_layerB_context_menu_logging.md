# Plan — action-log Layer B: the right-click context menu

**Date:** 2026-06-11. **Branch:** `feature/action-logging`.
**Spec:** `doc/claude/specs/action_logging.md` §2 Layer B (the context-menu row); checklist
row 25. **Builds on:** Layer A (slices 1+2) and the row-50 acceptance smoke.

## The thing being logged

`context_menu_action(mx, my)` (`callback.c:2070`) pops the Tk `.ctxmenu`
(`xschem.tcl:8656`), reads back an int `retval` (1–21), and `switch`es it to a
direct C call. Layer B = record the equivalent replayable `xschem …` command
when a pick fires — at the single chokepoint (the switch), never per Tk button.

## The classification (this is the whole job)

Unlike Layer A's bound keys, most context-menu items are NOT cleanly replayable
commands. Each `ret` falls in one of four buckets; the bucket decides what (if
anything) is logged. **Bucket assignments below are hypotheses to confirm in
step 0 by reading each case body AND the candidate subcommand — the slice-2
lesson (`e`/`attach_labels`) applies verbatim.**

| ret | case body (callback.c) | bucket | logged form |
|----|----|----|----|
| 1  | `start_place_symbol()` | A gesture-start | defer to Layer C |
| 2  | `start_wire(mx,my)` | A gesture-start | defer to Layer C |
| 3  | `start_line(mx,my)` | A gesture-start | defer to Layer C |
| 4  | `new_rect(PLACE,…)` | A gesture-start | defer to Layer C |
| 5  | `new_polygon(PLACE,…)` | A gesture-start | defer to Layer C |
| 6  | `place_text(…)` + move | A gesture-start | defer to Layer C |
| 16 | `move_objects(START,…)` | A gesture-start | defer to Layer C |
| 17 | `copy_objects(START)` | A gesture-start | defer to Layer C |
| 19 | `new_arc(PLACE,180,…)` | A gesture-start | defer to Layer C |
| 20 | `new_arc(PLACE,360,…)` | A gesture-start | defer to Layer C |
| 7  | cut: `save_selection(2);delete(1)` | B selection-dep | `xschem cut`? (verify) |
| 15 | copy: `save_selection(2)` | B selection-dep | `xschem copy`? (verify) |
| 18 | delete: `delete(1)` | B selection-dep | `xschem delete`? (verify) |
| 12 | `descend_schematic(0,1,1,1)` | B selection/cursor-dep | `xschem descend`? (verify args) |
| 13 | `descend_symbol()` | B cursor-dep | `xschem descend_symbol`? (verify) |
| 14 | `go_back(1)` | B hierarchy-dep | `xschem go_back`? (verify) |
| 8  | paste: `merge_file(2,".sch")` | C replayable-ish | `xschem paste` (mouse-positioned) |
| 9  | load recent: `xschem load -gui …` | C replayable | the exact command (already Tcl) |
| 10 | `edit_property(0)` | D dialog | `#` marker |
| 11 | `edit_property(1)` | D dialog | `#` marker |
| 21 | `abort_operation()` | D non-state | `#` marker (or skip) |

### Bucket meanings

- **A — gesture-start (10 of 21).** Entering a placement/move mode that
  completes with later mouse input. The replayable command forms at the gesture
  END — this is precisely Layer C / Phase 2 (rows 26–28), the SAME END hooks
  used for the keyboard/toolbar versions of these gestures. Logging the start is
  not replayable. **Do nothing in Layer B; Layer C covers them uniformly** (a
  context-menu "place wire" and a `w`-key "place wire" reach the same END).
- **B — selection/cursor/hierarchy-dependent (6).** Have an `xschem`
  subcommand, but faithful replay needs the selection or hierarchy cursor
  reproduced — which click-select cannot do yet (issue 0005). **Precedent
  (Layer A hilight `k`/`K`): log the command anyway** — it reads the selection,
  is genuinely the action taken, and replays correctly *when* the selection is
  reproduced. The bounded fidelity is the issue-0005 gap, not a Layer-B defect.
- **C — replayable now (2).** `load recent` is fully replayable; `paste` places
  the clipboard at the mouse (position not captured, like wheel-zoom origin —
  the action replays, the drop point may differ). Log the command.
- **D — dialog / non-state (3).** `edit attributes` opens a prop dialog (no Tcl
  form, like the other dialogs spec §6 defers); `abort` just cancels. **`#`
  marker** naming the pick (`# context-menu: edit attributes`), or skip `abort`
  entirely (it changes nothing replayable).

## Step 0 — equivalence audit (gates B and C)

For each bucket-B/C `ret`, read the case body and the candidate subcommand and
confirm they do the same thing, INCLUDING args:

- `cut`/`copy`/`delete`: the case bodies call `rebuild_selected_array()` then
  `save_selection`/`delete`. Does `xschem cut`/`copy`/`delete` do the same
  (incl. the `lastsel` guard and `to_push_undo`)? If the subcommand differs
  (e.g. no rebuild), either it is still equivalent because dispatch rebuilds, or
  it is bucket-D-by-default until proven.
- `descend`: case calls `descend_schematic(0,1,1,1)`. Does `xschem descend`
  pass the same 4 args? (Memory flags a known mismatch risk: `e`-key descend was
  `(0,0,0,1)` vs `(0,1,1,1)` — so `xschem descend` may NOT match this case.
  VERIFY; if it differs, mint nothing, mark `#` or defer.)
- `go_back`: case `go_back(1)` vs `xschem go_back` arg.
- `paste`: case `merge_file(2,".sch")` vs `xschem paste`.
- `load recent`: already a Tcl command in the case body — log it verbatim
  (capture the resolved filename, not `[lindex $tctx::recentfile 0]`, so replay
  doesn't depend on the recent-list state).

Any id that fails the audit drops to a `#` marker — never log a command that
isn't what the case does.

## Implementation

1. Audit (step 0); record the verdict table in the commit message.
2. A small static map in `context_menu_action`: `ret` → replayable command
   string (NULL for gesture-start/skip). After the switch dispatches, if the
   map has a command, `log_action("%s", cmd)`; for bucket-D log a `#` marker.
   Record AFTER the action runs (consistent with Layer A / CIW).
   - For `load recent` the command text is dynamic (the filename) — build it
     from the resolved path the case already used.
   - Gesture-start rows map to NULL → silent in Layer B by construction.
3. The map is data, not per-call-site hand-writing — one table, mirroring the
   ActionDef approach.

## Tests — `tests/headless/test_context_menu_log.tcl` (new)

Driving the real Tk menu headlessly is awkward (it grabs the pointer). Instead
test at the seam: the menu's only output is `retval`, and `context_menu_action`
is reachable via the same callback path that shows it (`callback.c:4978`). Two
viable approaches, pick in implementation:
- **(preferred) stub `context_menu`** to return a chosen `ret` (it is a Tcl
  proc; redefine it to `return N`), then trigger the context-menu callback and
  assert the log gained the expected command / `# marker` / nothing.
- iterate a representative `ret` from each bucket: a C-replayable (load — but
  load has side effects; use `paste` on an empty clipboard, or copy on a
  selection), a B (copy with something selected → `xschem copy` in log, and
  state-effect observable), a D (edit attributes → `# marker`, dialog stubbed),
  a gesture-start (wire → NOTHING logged in Layer B).
- assert the file stays source-able; assert a gesture-start pick logs no line.

## Out of scope (subsequent steps)

- **Layer C / Phase 2 (rows 26–28):** the END hooks for move/copy/wire/line/
  rect/poly/arc/text — covers all 10 bucket-A context-menu items AND their
  keyboard/toolbar twins in one place. This is the natural next step after B.
- Minting any NEW subcommand (Phase 3).
- Closing the selection-reproduction gap (issue 0005).

## Risk

- The context menu is interactive, gesture-heavy code; the logging must be PURE
  ADDITION (a `log_action` after dispatch), changing no case behavior. No case
  body is rewritten to "invoke the command instead" — that would risk the
  interactive semantics for no logging benefit.
- The `descend` arg mismatch is the likeliest audit failure; treat bucket-B
  command-logging as unproven until each body is read.
