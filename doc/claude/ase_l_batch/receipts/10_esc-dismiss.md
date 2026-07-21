# Receipt — item 10 esc-dismiss (round-2 addendum)

Verdict: **DONE** [x]. Commit `d8ab6769` (ONE commit, 3 files, +327/-16,
NOT pushed). No fixer rounds. Outstanding problems: none.

## What landed

Product (`src/ase_window.tcl`, +45/-mods):
- New central helper `ase::ui::bind_dialog_esc {w cancelcmd}`
  (src/ase_window.tcl:837, documented at the dialogs section header :824):
  binds `<Key-Escape>` on a dialog toplevel to its OWN cancel command —
  never a bare `destroy` that would leak per-window state arrays
  (copy_current_cell_dialog cleanup idiom).
- Wired CENTRALLY inside `ase::ui::dialog_buttons` (:860, call at :868), so
  all 9 scaffold dialogs — Add/Edit Variable, Add/Edit Output, Choose
  Analyses, Setup Design, Model-File row editor, Sim-Option row editor,
  Save All, Save-As — and every FUTURE `dialog_frame`+`dialog_buttons`
  dialog get ESC-runs-the-cancel-path **by construction**.
- 4 explicit sites outside the scaffold: shared `confirm` (:1343 — ESC =
  the Cancel destroy, `oncmd` never runs), Choose-Analyses Options
  subdialog (:1540), `listdlg_open` (:1796 — Model Files + Simulation
  Options), `load_state_dialog` (:2040).
- BONUS LEAK FIX: new `ase::ui::chana_x_cancel` (:1592) — the Options
  subdialog's old bare-destroy Cancel leaked `dlg($key,anextra)` until the
  parent closed; the Cancel button is rewired to it (:1530) and ESC uses
  the same path.
- Exempt by design (spec item 3): ASE session MAIN window and the log
  window stay ESC-unbound (no accidental session close; Ctrl-W owns the
  log); item-08 Select-On-Design canvas ESC seize/restore untouched.

Spec (`doc/claude/specs/ase_l.md`): D10 sentence appended to the
"Dialog style" section (ESC = Cancel on every ASE dialog, by construction).

## Tests

`tests/headless/test_ase_dialogs.tcl` — 133 GUI + 16 headless checks, both
arms ALL PASS:
- `send_return` generalized to `send_key {w ev done}` (:115; `send_return`
  kept as a 2-line wrapper :136, 3 old call sites unchanged) — same WSLg
  contract: generated keys delivered async, gate on focus ownership +
  done-condition (receipts/06).
- New GE1-GE16 section (60 new checks): per-dialog ESC dismissal + record
  cleanup (`info exists` = 0) + `state_serialize` snapshot immutability;
  GE2 entry-bubbling proof (ESC while focus in an entry still dismisses);
  GE5 subdialog isolation + anextra cleanup; GE13 confirm `oncmd` guard;
  GE14 main-window exemption via temporary witness binding (delivery
  proven, binding restored to empty); GE15 log-window structural
  exemption; GE16 Select-On-Design ESC regression via send_key with the
  I7 done-condition (self-SKIP arm only for select_on_design==0 — it
  armed and RAN here).
- Protected tests re-run green, ZERO assertion changes: test_ase_interact
  63, test_ase_window 153, test_ase_view 36, test_ase_core 66,
  test_ase_final 28.

## Sabotage table (all POST-commit; each `git diff` held ONLY the sabotage,
targeted `git checkout -- src/ase_window.tcl` revert, clean 133/133 re-run
after each)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | constructor wiring dropped (`bind_dialog_esc` call removed from `dialog_buttons`) | scaffold-dialog dismissal + record checks: GE1-GE6, GE8-GE10, GE12 blocks | yes (19 fails, ALL inside the targeted blocks; see deviation 2) |
| S2 | cancel path bypassed (`dialog_buttons` binds ESC to bare `[list destroy $w]` instead of `$cancelcmd`) | exactly the record-cleaned checks GE2, GE3, GE4, GE6, GE8, GE9, GE10, GE12 (GE1 + all dismissal/state checks stayed green) | yes |
| S3 | `chana_x_cancel` cleanup dropped (`array unset dlg $key,anextra` removed) | exactly "GE5 anextra record cleaned" (132/133 others green) | yes |

S2 vs S1 is the load-bearing differential: S2 proves ESC dismissal alone is
not enough — the record-cleanup checks catch a wiring that skips the cancel
path; S3 proves the subdialog leak fix is live.

## Fix-round history

None. No verifier problems; verdict DONE with empty outstanding-problems
list on the first pass.

## Implementer deviations (accepted)

1. An initial S1 ran PRE-commit (20 fails, same targeted blocks), reverted
   by exact Edit (a checkout revert would have wiped the uncommitted
   feature); S1 redone post-commit per RUNBOOK letter.
2. Post-commit S1 observed 19 fails — all inside the targeted
   GE1-GE6/GE8-GE10/GE12 blocks, including GE8 "ESC then closes Model
   Files" (WSLg focus-cascade from the surviving sabotaged row-editor
   toplevel stealing focus from its sibling list dialog — finer granularity
   inside targeted blocks, item-07 S2 precedent). Explicit-site legs (GE5
   subdialog trio, GE7, GE11, GE13) and GE14-16 stayed green — the
   differential proving the two wiring layers are independently covered.
3. Forced-report race: full_audit.sh was still IN FLIGHT at implementer
   report time. Closed by the ledger (below).

## Ledger-time audit closure

Audit log (scratchpad full_audit_item10.log) read after completion:
SUMMARY 189 pass / 16 fail / 1 crash-timeout / 10 skip (216 total).
- All 6 ASE tests PASS inside the audit (test_ase_core/_dialogs/_final/
  _interact/_view/_window).
- ONE non-baseline classification: `test_readonly_action_dispatch` FAIL
  (geometry-flavored lines: "zoom_in ... zoom X -> X"). Direct re-run via
  `tests/headless/full_audit.sh test_readonly_action_dispatch` → **PASS**
  → WSLg parallel-run flake per the rerun-first policy, NOT a regression.
- Remaining 15 fails + 1 timeout are a strict subset of the baseline list
  (baseline members test_altf5_ciw, test_cadence_window_hop_log,
  test_palette, test_verb_noun_copy_move, test_wire_vertex_grab passed
  this run).
- The leftover `_ase_interact_*` scratch dir noted by the implementer was
  audit residue; the audit cleaned it up on completion (none present).
- Working tree: src/ase_window.tcl, test_ase_dialogs.tcl, ase_l.md all
  clean at HEAD post-sabotage-reverts. No pre-batch dirty tracked file
  staged in d8ab6769 (diffstat = exactly the 3 item files).

## Anchors worth keeping (verified in tree at d8ab6769)

- `src/ase_window.tcl:837` `proc ase::ui::bind_dialog_esc` (helper);
  `:860/:868` `dialog_buttons` central wiring — THE constructor hook future
  dialogs inherit.
- `:1326/:1343` confirm; `:1500/:1540` chana_options; `:1592`
  `chana_x_cancel`; `:1763/:1796` listdlg_open; `:2005/:2040`
  load_state_dialog — the 4 explicit non-scaffold sites.
- `tests/headless/test_ase_dialogs.tcl:115` `send_key {w ev done}` (use
  this, not raw `event generate`, for ANY generated-key GUI leg);
  `:136` `send_return` wrapper.
