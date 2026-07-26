# Receipt — item 08 design-interact (ROUND 2 FINAL, acceptance gate)

Verdict: **DONE** ([x] in PLAN.md ledger). **This item was the round-2
acceptance gate and it PASSED**: the whole-flow leg ran end-to-end with
zero SKIPs and no in-test workarounds.

Commit (NOT pushed, batch policy):
- `54c78d31` — `feat(ase): Select On Design click mode + whole-flow
  acceptance` — the ONE implementer commit, 2 files, +694/−10 (verified
  vs `git show --stat 54c78d31`: `src/ase_window.tcl`,
  `tests/headless/test_ase_interact.tcl`). No fixer commits: zero fix
  rounds were needed.

## What landed

All in `src/ase_window.tcl` (D-numbers = scout micro-decisions in
prompts/item08_design-interact.md):

- **Select On Design click mode** — `ase::ui::select_on_design` /
  `sod_end` / `sod_click` / `sod_queue` + pure helpers `sod_expr` /
  `sod_merge`. One mode globally; starting it while another is active
  ends the old one first. Raise-or-open of the design schematic reuses
  the item-05-fixed Design Window path.
- **Binding discipline**: the mode seizes ONLY `<ButtonPress-1>`,
  `<ButtonRelease-1>`, `<Key-Escape>` on the design canvas
  (more-specific Tk widget bindings pre-empt the generic
  xschem-callback ones; every seized script ends in `break`; Motion is
  NOT touched so mousex_snap keeps updating in C). Previous binding
  strings are saved and restored VERBATIM on mode end.
- **Click semantics**: wire / net-label click queues voltage output
  `v(<net>)`; vsource/ammeter instance click queues source current
  `i(<inst>)`; tokens lowercased so ngspice's echoed print lines match
  `result_probe`. Any OTHER instance gets a `ciw_echo` notice — the
  documented v1 terminal-current restriction (D2, honest scope:
  non-source device terminals need `.options savecurrents` +
  `@device[current]` syntax, deferred; spec note added, see below).
- **Queueing**: dedupe on the EXACT expression string; flags OR into an
  existing row (D6); identical re-queues write nothing; every write
  goes `session_update` + `populate` so the row is visible in the
  Outputs pane immediately. ESC ends the mode and returns focus to the
  ASE window.
- **Entry points rewired**: Outputs > To Be Saved > Select On Design →
  `{save 1 plot 0}`; Outputs > To Be Plotted > Select On Design →
  `{save 1 plot 1}`; new `From Design…` button in the Add/Edit Output
  dialog (flavor read from the dialog's checkboxes with save coerced
  per D5; the dialog's typed name/expr is discarded).
- **Binding-leak guard**: `ase::ui::close` ends an active mode before
  destroying the toplevel (so canvas bindings never leak past session
  close; `sod_end`'s raise-the-ASE-window arm no-ops on the dead
  toplevel). Verified by test leg I10.
- **`ase::ui::todo_stub` REMOVED** — `grep -E "todo_stub|TODO\(item08\)"
  src/*.tcl` returns nothing (re-verified at ledger time). Closes the
  receipts/07 anchor "todo_stub still exists with exactly 2 callers".

Spec: `doc/claude/specs/ase_l.md` gained the **"Select On Design v1
scope"** note (present in the working tree, verified at ledger time)
— see deviation 1 for why it is not in the item commit.

## Tests — NEW `tests/headless/test_ase_interact.tcl`, 63 checks

63 checks = 9 headless (H1/H2: `sod_expr` / `sod_merge` pure-proc
units) + 54 GUI (I0–I10 + WF), auto-discovered by full_audit.sh
(run_regression.tcl untouched — pre-batch dirty). **Zero SKIPs fired on
every clean run** (63/63; no W4-class nudges needed).

- Hermetic fixture: the committed `test_nfet_final` cell is CLONED per
  run — the committed tree is never written; the clone's rundir is
  rewritten via public `state_load`/`state_save` (D10).
- I2 drives the REAL Motion+Press+Release gesture at pixel coordinates
  `(wx+xorigin)/zoom` on the design canvas (gesture-test-full-sequence
  lesson); I7 drives a REAL focus-gated `<Key-Escape>` with retry.
- I7 asserts all seized bindings restored verbatim; I10 asserts close
  during an active mode restores them too (leak guard).
- **WF (the gate leg)**: open test_nfet_final ngspice_state1 → Choose
  Analyses (op enabled) → add `vd=v(d)` via the `-->` dialog → Netlist
  and Run → log toplevel appears + Status Ready/Green + Outputs Value:
  id ≈ 409.7 µA (±1) AND vd ≈ 1.0 → Save State (Save-As) to scratch
  view `ngspice_scratch1` → close session → reopen scratch view →
  variables/analyses/outputs string-identical + pane spot-check.

**Protected tests re-run green post-change**: test_ase_core 45/45,
test_ase_view 36/36, test_ase_window 144/144, test_ase_dialogs 73/73,
test_ase_final 28/28 — no assertion changes needed in any of them.
All six ASE tests (incl. the new test_ase_interact) also PASSED inside
both full audits (implementer's and verifier's).

## Sabotage table

Each `git diff`-confirmed sabotage-only tree, targeted
`git checkout -- <file>` revert, clean re-runs 63/63:

| # | Sabotage | Target check(s) | Result |
|---|----------|-----------------|--------|
| S1 | `sod_click` voltage arm returns without queueing (src/ase_window.tcl) | I2 v(g) row; I3 both checks; I8 both checks (5 fails, 58 pass) | failed EXACTLY the targets — I5/I6/H/WF stayed green |
| S2 | `sod_end` skips restoring the saved `<ButtonPress-1>` binding | exactly `I7 ButtonPress-1 binding restored verbatim` + `I10 close restored ButtonPress-1` (the same-binding leak check, predicted by the prompt); all other I7 restore checks green (2 fails, 61 pass) | failed EXACTLY the targets |
| S3 | `sod_queue` drops the `ase::ui::populate` call (session_update kept) | exactly `I3 row visible in the Outputs pane immediately` — the state check right before it stayed green (differential proof; 1 fail, 62 pass) | failed EXACTLY the target |

## Fix-round history

None. Zero fixer rounds consumed; the outstanding-problems list handed
to the ledger was verified EMPTY.

**Audit classification (ledger-time read of the COMPLETED logs, per the
receipts-05/07 precedent — the implementer's audit was still in flight
at their forced-report time):**

- Implementer audit (scratchpad `full_audit_item08.log`, completed):
  `SUMMARY: 190 pass 18 fail 1 crash/timeout 7 skip (total 216)`.
  15 of the 18 fails + the timeout (test_key_graph_context) are in the
  baseline list; **3 fails are NOT baseline**: test_graph_context,
  test_multi_window, test_readonly_action_dispatch.
- Verifier (tests-lens) audit re-run AFTER the commit (scratchpad
  `full_audit_verif08.log`, 2026-07-21 11:36): `SUMMARY: 200 pass
  15 fail 0 crash/timeout 1 skip (total 216)` — the fail list is a
  STRICT SUBSET of baseline, and **all 3 non-baseline fails PASSED**,
  as did key_graph_context. Per the rerun-first policy those 3 are
  classified WSLg parallel-audit flakes (same class as the
  receipts-05/06 test_deselect_mode / test_hover_highlight incidents),
  not regressions. Several baseline fails also passed in one or both
  runs (e.g. cadence_window_hop_log, palette, verb_noun_copy_move,
  wire_vertex_grab, launch_context) — flaky baseline, expected.

## Declared implementer deviations (recorded per protocol)

1. **Spec edit left UNSTAGED (D12, pre-authorized)**:
   doc/claude/specs/ase_l.md carries the driver's uncommitted round-2
   "UI v2" contract, so the item's "Select On Design v1 scope" note was
   added to the working tree but deliberately NOT staged in `54c78d31`
   — the driver's ledger commit carries the spec file. Verified present
   in `git diff` at ledger time.
2. **`send_return` not copied into the new test** — no generated
   `<Return>` exists in it (dialogs driven via `.btns.proceed` invoke);
   the I7 Escape loop uses the same focus-gated + done-condition retry
   pattern inline.
3. **I7's mode-inactive done-condition** is "seized `<Key-Escape>`
   binding reverted" rather than the prompt's ButtonPress-1 example —
   chosen so sabotage S2 fails exactly its 2 target checks instead of
   also timing out the ESC retry loop.
4. **Small additions beyond the prompt's leg list**: I0 open/window
   checks and an "I1 mode canvas is the main canvas" assertion
   validating the `.drw` pre-capture assumption.

## Outstanding problems

None — outstanding-problems list verified EMPTY at ledger time (no
fixer rounds; the 3 verifier lenses were clean on the first pass; the
audit's 3 non-baseline fails resolved as flakes by the verifier's
re-run, see above).

## Corrected/confirmed anchors worth keeping

- **Canvas seize pattern**: to overlay a temporary click mode on an
  xschem canvas, bind ONLY the specific events you need on the widget
  (widget bindings pre-empt the generic callback bindings), end every
  script with `break`, leave `<Motion>` alone (C-side mousex_snap keeps
  working), and save/restore the previous binding STRINGS verbatim.
- **`ase::ui::close` now ends an active sod mode** — anything that
  destroys ASE toplevels can rely on canvas bindings not leaking.
- **Output-token case**: v()/i() tokens are lowercased at queue time so
  ngspice's echoed print lines match `result_probe` — keep any future
  output-producing path consistent with this.
- **`sod_merge` dedupe contract**: exact-expression string match; plot/
  save flags OR into the existing row; no duplicate rows.
- **Generated pointer events on the schematic canvas**: compute pixel
  coordinates as `(wx + xorigin) * zoom`-style transforms from design
  coordinates (see I2) and replay the full Motion+Press+Release
  sequence — a lone press does not exercise the shipping path.
- **Hermetic cell fixtures**: clone the committed cell, then rewrite
  the clone's rundir through public `state_load`/`state_save` — never
  write the committed tree, never hand-edit the .state file.
- **`todo_stub` is gone** — no stub sites remain in src/*.tcl; future
  items add their own stubs if they need staged entry points.
- **Flake roster addendum**: test_graph_context, test_multi_window,
  test_readonly_action_dispatch can FAIL inside PARALLEL full_audit
  runs on WSLg and pass on re-run — rerun-first before treating them
  as regressions (this item's implementer audit vs verifier audit).

## Commit hygiene

`54c78d31` staged exactly the 2 listed files (verified vs
`git show --stat`). No pre-batch dirty tracked files staged; no
`_ase_interact_*` leftovers (test cleans its scratch — verified by the
implementer). doc/claude/specs/ase_l.md + PLAN.md + this receipt left
unstaged for the driver's single ledger commit. NOT pushed.
