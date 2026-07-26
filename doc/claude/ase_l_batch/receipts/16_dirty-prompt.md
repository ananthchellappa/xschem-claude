# Receipt — item 16 dirty-prompt (round-4)

Verdict: **DONE** [x]. One feature commit + one round-1 fixer commit (neither pushed):
- `750b3577` feat(ase): prompt to save a dirty ASE-L session on close and on
  xschem quit. Exactly the six prescribed files staged explicitly; no pre-batch
  dirty tracked file swept in:
  - `src/ase_window.tcl`                   +121 (close_request wrapper + prompt)
  - `src/xschem.tcl`                       +6  (quit_xschem ASE sweep)
  - `tests/headless/test_ase_dirty.tcl`    +365 NEW
  - `tests/headless/test_ase_persist.tcl`  +5/-2 (dirty-session Close → direct `ase::ui::close`)
  - `tests/headless/test_ase_interact.tcl` +5/-2 (same)
  - `tests/headless/test_ase_dialogs.tcl`  +7/-2 (same)
- `f04703e0` fix(ase): harden the ASE-L save-on-close prompt against a
  build-time teardown race (round-1 fixer; verifier-flagged DR4 WSLg flake).
  Two in-scope files only: `src/ase_window.tcl` +11/-2,
  `tests/headless/test_ase_dirty.tcl` +21/-2.

Outstanding problems: **none** (empty problem list at ledger time; working tree
clean at HEAD for all committed files).

## Ledger-agent re-verification (at HEAD = f04703e0)

- `test_ase_dirty.tcl` re-run green under X this session: **41/41**
  (`RESULT: ALL PASS (41 checks)`); DISPLAY-guarded self-SKIP without a display.
- Commit `--stat` matches the six-file feature claim; fixer touches only the two
  in-scope files (ase_window.tcl + test_ase_dirty.tcl) — no pre-batch dirty file
  in either commit. Neither commit is on any remote branch (not pushed).
- Modified protected suites re-run: `test_ase_interact` 63/63 PASS,
  `test_ase_dialogs` 133/133 PASS. `test_ase_persist` flaked once
  (`1 FAILED (96 passed)`, aborted at the G10 raw-load leg) then passed
  **109/109** on immediate re-run — a WSLg GUI flake in the known ASE-suite
  category (receipts/06/15), NOT a regression; the item touches only its
  teardown line, not G10.
- Every proc the wiring leans on exists: `ase::ui::close` (ase_window.tcl:233,
  the unconditional teardown primitive, unchanged in contract),
  `close_request` :343, `ask_save_close` :281, `asksave_done` :273,
  `save_state_modal` :326, `prompt_all_on_quit` :359; namespace var
  `asksave_result` :66. quit_xschem sweep at xschem.tcl:13437-13439.

## What landed (D1–D5, all pure Tcl — no C, no generated-file edits)

- **D1 — close prompt.** `ase::ui::close` stays the unconditional teardown
  primitive; a new wrapper `ase::ui::close_request` (ase_window.tcl:343) does the
  `ase::session_dirty` check and, when dirty, raises a themed Yes/No/Cancel modal
  (`ask_save_close` :281, mirrors `ask_save` xschem.tcl:9537 semantics, wears the
  ASE `[ase::theme panel]` background, ESC = Cancel via `asksave_done`).
  Yes → `save_state_modal` (:326) blocks on the modeless Save-As and returns 1
  iff it completed (guarded by a `do_save_state_as` completion flag behind
  `info exists`, so ordinary menu Save State stays byte-identical); close only on
  completion, abort on Save-As cancel. No → discard + close. Cancel → abort, the
  window and per-window state arrays (ase_window.tcl:238-246) left intact.
  Wired at the three real user-close entry points: WM_DELETE (:216),
  Ctrl-W/Ctrl-W (:217-218), Session > Close menu (:404-405).
- **D2 — quit sweep.** `quit_xschem` (xschem.tcl:13426) gained an ASE sweep at
  :13434-13439, slotted right AFTER the existing `hierarchy_close quit`
  dirty-schematic sweep (scout-confirmed it already had one), guarded by
  `[info commands ase::ui::prompt_all_on_quit] ne {}` AND inside the
  `if {$force eq {}}` interactive branch — so it is a strict no-op for a preset-
  force quit, for a build where ase_window is not loaded, and (via
  prompt_all_on_quit returning 1) when no ASE window is open. A Cancel on ANY
  dirty session returns 0 → `return` aborts the whole quit.
- **D3 — read-only-opened view.** A dirty RO-opened session on Yes routes
  through Save-As (item-07 overwrite-confirm path); the RO backing file is never
  silently written (asserted by DR10's mtime witness).
- **D4 — untitled launched sessions (item 15).** A dirty untitled session (from
  Tools > Launch ASE-L) prompts on close; Yes → Save-As creates the view.
- **D5 — tests.** `tests/headless/test_ase_dirty.tcl` (NEW, auto-discovered by
  full_audit.sh; NOT registered in the pre-batch-dirty run_regression.tcl).
  Three protected suites had their DIRTY-session menu-Close teardowns switched to
  direct `ase::ui::close $key` (behavior-identical to the pre-rewire menu Close,
  avoids the new modal blocking headless); the CLEAN-session menu-Close sites
  were left as `invoke Close` to keep covering the no-prompt-on-clean path.

## Tests

`tests/headless/test_ase_dirty.tcl` — **41 checks**, DR0–DR14, DISPLAY-guarded
(`RESULT: SKIP` under --nogui / no display). All dialogs driven by INVOKING
buttons (no key events) for WSLg robustness.

- **DR0–DR2** open_state + Close/WM_DELETE wired to `close_request`.
- **DR4** real prompt builds fully then Cancel (two-stage deferred poller so the
  raise/grab/focus completes before cancel).
- **DR5** clean session closes with NO prompt, unregisters.
- **DR6** Cancel → prompt shown, still dirty, window + state unchanged.
- **DR7** No → session unregistered (discarded).
- **DR8** Yes → real Save-As ran + on-disk witness (`Vgs value 9.9`).
- **DR9** untitled Yes → Save-As.
- **DR10** RO-opened Yes → Save-As, RO file never written (mtime).
- **DR11** Yes + Save-As cancelled → window SURVIVES, still dirty.
- **DR12** quit Cancel → returns 0, still dirty.
- **DR13** quit No → returns 1, unregistered, window gone.
- **DR14** no ASE windows → prompt_all_on_quit is a no-op returning 1, no prompt.

Implementer full_audit: 196 pass / 16 fail / 0 crash-timeout / 9 skip; all 16
fails a STRICT SUBSET of the declared baseline, zero non-baseline fails, zero
timeouts. All 11 protected ASE/wave suites pass
(test_ase_{core,view,window,dialogs,final,interact,plot,persist,launch,dirty},
test_wave_viewer).

## Sabotage table (three; each failed EXACTLY its target)

| # | Sabotage | Target | Failed exactly? |
|---|----------|--------|-----------------|
| S1 | close_request Cancel arm → `ase::ui::close` (Cancel no longer aborts) | DR6 Cancel-keeps-window (also DR4 real-prompt Cancel); DR5/DR7–DR14 green | yes |
| S2 | close_request Yes arm ignores `save_state_modal` result (unconditional close) | DR11 Yes+Save-As-cancelled aborts (window SURVIVES + still dirty); DR8 Yes+proceed + others green | yes |
| S3 | prompt_all_on_quit default arm → continue (quit Cancel no longer aborts) | DR12 quit-Cancel returns 0 (got 1); DR13 quit-No + others green | yes |

Revert mechanism (documented deviation, same guarantee as receipts/15): the
feature was uncommitted at sabotage time, so reverts were precise reverse-Edits
verified sabotage-only by diff, not `git checkout -- <file>`.

## Fix-round history

**Round 1 — `f04703e0` (fixer).** Verifier `tests` lens saw an intermittent
`1 FAILED (5 passed)` on `test_ase_dirty` (~1 in 5 runs on this WSL2 box). Root
cause: `ask_save_close` pumps the event loop in a build-time `update`, then
unconditionally `focus $w.btns.yes` + `tkwait window $w`. If a Cancel/close
(WM/WSLg compositor teardown or a test) lands during that `update`, the dialog is
destroyed before the focus line, and the unguarded focus throws
`bad window path name .aseN.askclose.btns.yes` — an uncaught error propagating
out of `close_request` and aborting the caller, skipping DR5–DR14.
Fix: guard the focus with `catch` (matching the raise/grab lines above it) and
skip `tkwait` when the window is already gone, returning the result
`asksave_done` already recorded (Cancel/{} default). Pure hardening — nothing
tears the dialog down mid-build in normal use, so no behavior change (proven with
a forced-race repro: a ~100 ms build update makes the pristine proc throw the
exact traceback deterministically; guarded proc 41/41 every time). The fixer also
added a `settle` helper (vwait on a short timer) at the dominant window-churn
points in the test to pace WSLg through its ~10 toplevels — pure pacing, never
changes what a check observes. Two targeted re-sabotages (close-Cancel abort,
quit-Cancel abort) each failed exactly their target and reverted clean; protected
suites green. All three lenses re-ran clean after the fixer.

## Deviations (accepted, reality-forced)

1. Test `make_dirty` strengthened with a unique per-call counter variable so a
   session is reliably dirty even after an earlier leg (DR8) saved a make_dirty
   state to the same view's disk; DR8's `Vgs value 9.9` on-disk witness
   preserved.
2. DR4's poller defers its Cancel to a later event cycle (two-stage
   `dr4_poll`/`dr4_cancel`) so the real prompt fully builds (raise/grab/focus)
   before cancel — otherwise it destroyed the dialog during `ask_save_close`'s
   own build-time `update`. Product `ask_save_close` kept verbatim per the prompt
   for the feature commit; the build-time race it exposed was then closed by the
   round-1 fixer f04703e0 (see fix-round history).
3. DR8 `string match` pattern quoted (`"*{...}*"`) — the prompt's unquoted brace
   pattern is a Tcl arg-count error.
4. Three protected tests' DIRTY-session menu-Close teardowns switched to direct
   `ase::ui::close $key` (behavior-identical to the pre-rewire menu Close);
   CLEAN-session sites left as `invoke Close` to preserve no-prompt-on-clean
   coverage. Justified in the commit.

## Corrected anchors worth keeping (verified at f04703e0)

- `ase::ui::close` (the unconditional teardown primitive, contract unchanged):
  **src/ase_window.tcl:233**; per-window state unsets at :238-246.
- New close-path procs in src/ase_window.tcl: `asksave_done` :273,
  `ask_save_close` :281, `save_state_modal` :326, `close_request` :343,
  `prompt_all_on_quit` :359; namespace var `asksave_result` :66.
- Close wiring: WM_DELETE :216, Ctrl-W/Ctrl-W :217-218, Session > Close menu
  :404-405 — all route to `close_request`. (The old :212/:227/:234 anchors from
  the PLAN drifted; the prompt now lives in the wrapper, not in `close`.)
- Save-As seam reused unchanged: `save_state_dialog` (called at :330/:402),
  completion flagged by `do_save_state_as` (guarded by `info exists` so ordinary
  menu Save State is byte-identical).
- quit_xschem ASE sweep: **src/xschem.tcl:13434-13439**, immediately after the
  existing `hierarchy_close quit` dirty-schematic sweep and inside the
  `if {$force eq {}}` interactive branch — the double guard
  (`info commands ase::ui::prompt_all_on_quit ne {}` + force-preset skip) is what
  makes a normal / non-ASE quit a strict no-op.
- Dirty detect `ase::session_dirty` (ase.tcl:515) unchanged; the item only
  promoted the previously LOG-ONLY dirty check into a real Yes/No/Cancel gate.
