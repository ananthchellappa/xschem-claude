# Bugfix prompt — issue 0127 RESIDUAL (batch item 7): scripted `xschem text` coord form pushes NO undo and never sets modify

(This file previously held item 4's prompt for the rect/line/arc legs, FIXED de1b75d4 —
see receipts/bugfix_0127.md. This is item 7: the `text` sibling recorded as RESIDUAL in
doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md. Re-scouted
2026-07-19 after a prior implementer crashed pre-receipt — see CRASH INHERITANCE.)

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch fluid-editing. Item 6 landed
096f3f84 (touched src/actions.c).

## CRASH INHERITANCE — read this first

A prior implementer died pre-receipt leaving UNCOMMITTED edits. The re-scout
(2026-07-19) verified EVERY inherited edit against source, rebuilt, and ran the
full extended test (25/25 green) plus the fallout suites. Your job is NOT to
re-type the fix — it is to VERIFY the inherited edits byte-match this prompt,
then run the red-first equivalence + sabotages + audit + docs + commit. The four
dirty files (keep ALL of them):

1. `src/scheduler.c` — the two fix lines (the entire runtime fix; exact text in
   EDITS). `git diff src/scheduler.c` must show EXACTLY two added lines.
2. `tests/headless/test_scripted_shape_undo.tcl` — extended 18 → 25 checks
   (text block SSU-T1..T4/TD1, SSU-TM1, SSU-RO4, header comment) exactly per the
   TEST section blocks below.
3. `tests/stable_handles/text_body.tcl` — COMMENT-ONLY edit above TH5 (the old
   comment "Graphical/text create is not undoable" became false with this fix);
   no check logic changed. Legit fallout, keep.
4. `doc/claude/issues/0127-...md` — "RESIDUAL FIXED (2026-07-19 ...)" section
   already written; re-scout verified its claims (anchors, 25 checks, red pair
   SSU-T2+SSU-TM1, zero create_save text callers). Keep; add the TH6 note (DOCS).

If any file deviates from this prompt, reconcile TO the prompt (it was verified
from source today). The tree's binary already contains the fix — still rebuild
yourself before trusting any run.

## Bug (re-verified from source 2026-07-19)

Scripted `xschem text x y rot flip text props size draw` stores the text but:
1. pushed NO undo checkpoint — one `xschem undo` after a scripted text rides the
   PREVIOUS checkpoint and destroys unrelated edits along with the text;
2. never called `set_modify(1)` — the buffer showed unmodified after a real edit
   (no `*` title marker, no autosave backup, quit without save prompt).

The interactive twin `place_text` pushes undo (src/actions.c:5010) and the drop
path sets modify; the three sibling coord arms rect/line/arc were fixed by
de1b75d4 and now push + set_modify. `text` was the last of the four coord forms
out of line — a worse, two-part hole (receipts/24_text.md documented it).

## ANCHORS (all verified 2026-07-19 on the INHERITED tree — re-verify, lines drift)

- src/scheduler.c:11184 `else if(!strcmp(argv[1], "text") )` — the branch (in
  xschem_cmds_t).
  - :11186 `!xctx` guard, :11187 `scheduler_readonly_reject(interp, "text")`,
    :11188-11189 `argc < 10` validation — both rejects return TCL_ERROR BEFORE
    the push, so a refused call can never burn a slot (0121/0125 class),
    :11191 the inherited push, :11192-11193 `create_text(atoi(argv[9]), ...)`,
    :11194 the inherited set_modify, :11195 `Tcl_ResetResult(interp);` (result
    contract unchanged — branch returns empty).
- src/actions.c:4918-4986 `create_text` — NO failure/early-return mode: always
  stores, calls `text_register` (:4984, stamps id) and returns 1. A push before
  the call is therefore always matched by a store (the de1b75d4 "only on the
  path that actually stores" judgment; for text the whole arm IS that path).
- src/actions.c:5010 `xctx->push_undo();` in `place_text` — interactive twin.
- Fixed-sibling precedents (comment style mirrored): rect arm push
  src/scheduler.c:8909; line :5778; arc (inside layer gate) :2094 — all tagged
  `/* issue 0127 */`.
- src/callback.c:1729-1743 PLACE_TEXT funnel logs the read-back replay line
  `xschem text %.16g %.16g rot flip txt prop scale 1` (log_action_argv(10,av)
  at :1743). Replaying it now pushes exactly one slot — matching the one push
  the interactive original made. Fidelity GAIN, same argument accepted for
  rect/line/arc in de1b75d4.
- src/actions.c `set_modify(int)` — mod==1 sets flag + write_backup + button
  colors; `xschem clear force` runs set_modify(0), so SSU-TM1 is genuinely red
  pre-fix.
- Consumers verified clean at re-scout (record, don't re-litigate):
  - ZERO `xschem text` callers under tests/create_save/ (recursive grep, empty
    — the goldens defer trigger CANNOT fire).
  - src/create_graph.tcl:30 (+1 slot per composite; its trailing
    `xschem set_modify 0` at :54 still clears the flag at composite end) and
    src/place_sym_pins.tcl:41 (+N slots; that buffer already went modified via
    its rect/line calls) — accepted wire/rect per-call-push class (MAX_UNDO=80
    ring caps depth; undo depth is convenience, not correctness). No C-side
    tcleval callers exist.
- The extended test needs NO runner registration: full_audit.sh auto-discovers
  tests/headless/test_*.tcl in the default `--pipe -q --nolog --script` class.
  Its `reset_undo` double-toggle MUST head every block (undo ring persists
  across `xschem clear force`).

## EDITS (already in tree — VERIFY byte-exact, complete nothing)

### 1. src/scheduler.c — the text branch

```c
      xctx->push_undo(); /* issue 0127 residual: checkpoint like interactive place_text + the rect/line/arc coord arms */
      create_text(atoi(argv[9]), atof(argv[2]), atof(argv[3]), atoi(argv[4]), atoi(argv[5]),
                    argv[6], argv[7], atof(argv[8]), atof(argv[8]));
      set_modify(1); /* issue 0127 residual: mark modified like the rect/line/arc coord arms */
      Tcl_ResetResult(interp);
```

`xctx->push_undo();` immediately BEFORE the pre-existing `create_text(...)`,
`set_modify(1);` immediately AFTER it, before `Tcl_ResetResult`. No new
declarations (C89 safe). Readonly gate, argc validation, result contract
untouched; NO logging added (the arm is deliberately unlogged —
receipts/24_text.md, D3 family).

### 2. tests/headless/test_scripted_shape_undo.tcl — 7 new checks (18 → 25)

Verify the inherited extension matches: (a) text block after SSU-A5, before the
"modified + readonly controls" section — SSU-T1 (text stored), SSU-T2 (prior
wire survives one undo — THE regression), SSU-T3 (undo removed the text), SSU-T4
(second undo peels the wire = exactly-one-push), SSU-TD1 (two redos restore
wire+text); (b) SSU-TM1 after SSU-M1 (set_modify 0; scripted text; modified==1);
(c) SSU-RO4 after SSU-RO3 (readonly text refused: rc==1, "*read-only*" message,
texts STAY 1 — block (b) placed one — modified stays 0). Header comment mentions
the residual. All use draw=0 (headless-safe).

### 3. tests/stable_handles/text_body.tcl — comment-only above TH5

Verify: only the TH5 header comment changed (creates now push their own
checkpoint per issue 0127; TH5 keeps its delete->undo cycle). NOTHING else in
the file may differ.

## TEST PLAN

Run from REPO ROOT:
`src/xschem --pipe -q --nolog --script tests/headless/test_scripted_shape_undo.tcl`

1. Rebuild (`cd src && make`) and run: expected 25/25 `RESULT: ALL PASS`
   (re-scout witnessed this today on the inherited tree).
2. **Red-first equivalence** (the fix pre-exists, so red = removing it):
   `cp src/scheduler.c <scratchpad>/scheduler.c.fixed` FIRST (the fix is
   UNCOMMITTED — see revert protocol), delete BOTH inherited lines, rebuild,
   run. Expected: EXACTLY **SSU-T2** and **SSU-TM1** fail, the other 23 green
   (re-scout empirically rebuilt the pre-fix binary today: the T-block undo
   lands on the wire's own pre-store snapshot, so T3/T4/TD1 pass vacuously;
   RO4's gate pre-exists at :11187). Restore via cp, rebuild, 25/25 green.
3. create_save golden defer-trigger witness (record in receipt, no regen):
   `grep -rn "xschem text " tests/create_save/` → empty (re-scout verified);
   the diff touches only the `xschem text` branch, so goldens cannot change
   (item 4 byte-verified the shared machinery under its pushes). Optionally run
   the create_save harness once per item-4/5/6 precedent (absolute-path PATH
   wrapper, expect 5/5 jobs zero FATAL).

### Fallout suites (re-scout ran all three today — re-run to witness)

- `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/stable_handles/text_wrap.tcl`
  → /tmp/sh_text_test.log: expect 12 PASS + **TH6a/TH6b FAIL — PRE-EXISTING, DO
  NOT FIX, DO NOT ATTRIBUTE**. Re-scout proof: fails IDENTICALLY on a pre-fix
  rebuild. Root cause: TH6 (2026-06-13, 9ff519ee) asserts invalidate-on-restore
  for text ids across disk undo, but 6658b655 (2026-07-02, issue 0043) extended
  the disk-undo id side-channel to texts (save.c walk_user_text_ids), so a
  matched-shape disk undo now re-stamps the SAME id — TH6's contract has been
  stale since then. Outside full_audit (headless test_*.tcl only), so it cannot
  pollute the audit. Record it (DOCS); fixing that test is out of scope.
- `cd src && timeout -s KILL 120 ./xschem -q --script ../tests/undo_stable_ids.tcl`
  → /tmp/sh_undo_ids.log: 26 PASS, `DONE (0 failures)` (proves the superseding
  text-id-preservation contract).
- `cd tests && timeout -s KILL 120 ../src/xschem --nogui --pipe -q --script text_size.tcl`
  → `text_size: all checks PASS`.

### Sabotages

Each must fail EXACTLY its one target and nothing else, then be reverted, then a
clean re-run must be 25/25 green. **Revert protocol: the fix is UNCOMMITTED —
NEVER `git checkout -- src/scheduler.c` before the commit (it would destroy the
fix). Revert by `cp <scratchpad>/scheduler.c.fixed src/scheduler.c`; after every
revert `git diff src/scheduler.c` must show exactly the two + fix lines**
(item-6 gotcha: Edit-based reverts have duplicated comment blocks; cp avoids
it). Rebuild between every step.

- **SB-T1**: remove the `xctx->push_undo();` line (keep set_modify) → EXACTLY
  SSU-T2 fails.
- **SB-T2**: duplicate the push (two consecutive `xctx->push_undo();`) →
  EXACTLY SSU-T4 fails (second undo restores the wire instead of peeling it;
  both pushes snapshot pre-text state so T2/T3/TD1 stay green).
- **SB-TO**: move the push to AFTER the create_text call (order guard) →
  EXACTLY SSU-T3 fails (the undo restores the slot that now CONTAINS the text;
  first undo yields wires=1 so T2 green, second undo hits the wire-push's empty
  snapshot so T4 green).
- **SB-TM**: remove the `set_modify(1);` line (keep push) → EXACTLY SSU-TM1
  fails (T-block is state-count based; RO4 checks modified==0, still 0).
- **SB-RO**: remove the `scheduler_readonly_reject(interp, "text")` line →
  EXACTLY SSU-RO4 fails (rc==0, texts==2; no later check counts texts or
  modified, so isolation holds).

### full_audit

Run `tests/headless/full_audit.sh` once fully before commit. Baseline fails =
the 14-test PLAN.md header list (2026-07-18): test_cadence_descend_newwin_ro,
test_cadence_drag, test_ciw, test_descend_untitled_preserve, test_hi_descend,
test_lib_manager_gui, test_lib_sweep, test_phase3_mints, test_reopen_readonly,
test_save_as_cellview, test_select_at, test_selflog_output, test_untitled_reuse,
test_wire_split. Watchlist must PASS: test_scripted_shape_undo,
test_gesture_end_log, test_shape_setprop_log. Any OTHER fail: retry in isolation
first (congestion/WSLg flake precedent, items 4/6: test_fluid_editing,
test_graph_context, test_hover_highlight, test_palette, test_launch_context,
test_lib_manager_launch, test_wire_vertex_grab); test_fluid_editing FE8 has a
recorded environmental pre-existing signature (items 2/4) — if seen, confirm it
fails identically on a pre-fix rebuild before clearing it.

## DOCS + MEMORY

- Issue file doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md:
  the RESIDUAL FIXED section is already written and re-scout-verified — keep.
  ADD one short "Re-scout verification note (2026-07-19)" bullet at its end:
  TH6a/TH6b in tests/stable_handles/text_body.tcl fail PRE-EXISTING (since
  6658b655 extended the 0043 disk-undo id side-channel to texts, superseding
  TH6's invalidate-on-restore expectation; fails identically on the pre-fix
  binary; outside full_audit; not addressed here — candidate for its own issue
  at next planning).
- Memory: per-item detail into the batch block in
  /home/qflow/.claude/projects/-home-qflow-dev-xschem-claude-1-xschem/memory/action-logging.md
  (fix shape, 25-check test, 5 sabotages, TH6 pre-existing finding, crash
  inheritance, commit hash); the MEMORY.md index stays one short line (do not
  grow it beyond the batch pointer).

## COMMIT

Explicit file list ONLY (never -A / -a): src/scheduler.c,
tests/headless/test_scripted_shape_undo.tcl, tests/stable_handles/text_body.tcl,
doc/claude/issues/0127-scripted-rect-arc-coord-form-no-push-undo.md. Do NOT
sweep in pipeline-owned ledger/prompt/receipt files or anything else dirty in
the tree. NEVER reset --hard, NEVER push.

Message:

```
fix(undo): scripted text coord form pushes undo + sets modify (issue 0127 residual)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
```
