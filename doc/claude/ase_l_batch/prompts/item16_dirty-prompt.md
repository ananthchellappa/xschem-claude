# Item 16 — dirty-prompt (IMPLEMENTER PROMPT)

Repo: `/home/qflow/dev/xschem/claude_1/xschem`, branch `fluid-editing`.
ASE-L mini-batch, ROUND 4, item 16. Read the spec `doc/claude/specs/ase_l.md`
(UI v2 "Menu tree" > Session > Close/Save State; "Dialog style") and
`doc/claude/ase_l_batch/receipts/15_launch-ase.md` (untitled sessions are
dirty-tracked; an untitled launch is NOT dirty until edited) before coding.
This prompt is the authoritative contract; the scout re-verified every anchor
from source (2026-07-22) and resolved every micro-decision below.

## Goal (user bug)

Opening an `ngspice_state1` view into ASE-L, editing it, then closing the ASE
window (or quitting xschem) DISCARDS the edits WITHOUT prompting. ASE session
close and xschem quit must offer a Cadence/ask_save-style **Yes / No / Cancel**
"save changes?" prompt for any dirty ASE session, exactly like a normal
schematic does.

Pure Tcl. NO C changes. NO generated-file edits. Do NOT change how a normal
(non-ASE) schematic quit/close behaves.

---

## Corrected / verified anchors (current line numbers, 2026-07-22)

Lines drifted from the PLAN sketch; these are the TRUE current lines.

- `src/ase.tcl`
  - `proc ase::session_dirty {key}` at **:524** (PLAN said :515 — drifted).
    Canonical dirty test: `state_serialize state ne state_serialize saved`.
    Reuse it; do NOT reimplement.
  - `proc ase::session_close {key}` **:567**, `proc ase::session_state` **:506**,
    `proc ase::session_getattr` **:581**, `proc ase::state_get` **:50**,
    `proc ase::state_serialize` **:168**. No edits to ase.tcl are needed.
- `src/ase_window.tcl`
  - `namespace eval ase::ui {` **:62**; `variable wins [dict create]` **:64**
    (session key -> `.ase<N>` toplevel — THE open-window registry the quit
    sweep iterates), `variable wnum` :66, `variable meta` :68, `variable dlg`
    (declared later, per-dialog scratch array). Add the new
    `variable asksave_result {}` here.
  - `ase::ui::open` **:198**: `wm protocol $top WM_DELETE_WINDOW [list
    ase::ui::close $key]` at **:212** (the WM close hook to rewire); this is
    also where the new `<Control-w>` binding is added.
  - `proc ase::ui::close {key}` **:227** — the UNCONDITIONAL teardown. Its
    `if {[ase::session_dirty $key]} { ... ciw_echo "...discarded" }` at
    **:234-236** LOGS ONLY today. **Leave `close` as-is (it stays the teardown
    primitive)** — see D1. Cleanup unsets are **:238-246**.
  - Session menu `Close` entry `$top.mb.session add command -label Close
    -command [list ase::ui::close $key]` at **:287** (the second close hook to
    rewire).
  - `proc ase::ui::apply_theme {w}` **:157** (Toplevel/Frame/Label/Button/Entry
    -> panel #f2f2f2 bg + AseLabelFont; call it on the new prompt so it inherits
    the ASE palette). `proc ase::theme` **:126** (`panel #f2f2f2`, `accent
    #8b0000`). `proc ase::ui::bind_dialog_esc {w cancelcmd}` **:872**.
  - `proc ase::ui::save_state_dialog {key}` **:2258** — **MODELESS** (builds
    `[dict get $wins $key].saveas`, wires OK -> `save_state_ok`, Cancel ->
    `saveas_cancel`, `return $w`; it does NOT block and does NOT report
    save-vs-cancel). This is the load-bearing fact: after "Yes" the Save-As is
    ASYNCHRONOUS, so the close/quit code must WAIT for it (D2).
  - `proc ase::ui::saveas_cancel {key}` **:2291** (destroys `.saveas`, no
    success signal). `proc ase::ui::save_state_ok {key}` **:2318** (validates,
    then either shows the RO overwrite `ase::ui::confirm` or calls
    `do_save_state_as`). `proc ase::ui::do_save_state_as {key l c v}` **:2409**
    — returns **1 on success / 0 on reported error** (NOT "cancel"); on success
    it runs the shared tail (`libmgr::refresh_after`, `ciw_echo`, destroy
    `.saveas`) at **:2437-2442** then `return 1`. The two success arms
    (same-file `session_save`; new/different-view `library_new_view` +
    `state_save`) both fall through that tail — the single place to set the
    completion flag (D3).
  - `proc ase::ui::design_cell_name {key}` **:2449** (the cell name for the
    prompt message). `proc ase::ui::refresh_title` **:2461**,
    `session_changed` **:2504** (untouched — the dirty ` *` marker already
    works).
  - Log window is `$top.logwin`, a **child toplevel** of the session `$top`
    with its OWN `<Control-w>` (destroy the log) at **:2645-2646**. A
    `bind $top <Control-w>` does NOT reach `$top.logwin` (distinct toplevel,
    independent bindtags), so the new session-window Ctrl-W will not conflict.
- `src/xschem.tcl`
  - `proc quit_xschem {{force {}}}` **:13426**. Interactive quit (`$force eq
    {}`) does `hierarchy_close quit` (per-cell ask_save on the CURRENT window's
    schematic hierarchy) then `xschem new_schematic destroy_all $force` (which
    prompts OTHER schematic windows). **CONFIRMED: quit_xschem has NO ASE
    sweep** — ASE needs its own hook, slotted right after the `hierarchy_close
    quit` success inside the `if {$force eq {}}` block (D7).
  - `proc ask_save {{ask ...} {cancel 1}}` **:9537** — the semantics to mirror:
    modal `toplevel .dialog` + `grab set` + `tkwait window`, returns `yes` /
    `no` / `{}` (empty == Cancel); binds `<Return>`->Yes, `<y>`, `<n>`,
    `<Escape>`->Cancel.
- Tests that will be edited (all CLEAN pre-batch — verified `git status` empty;
  NONE are in the pre-batch dirty list): `tests/headless/test_ase_persist.tcl`
  (menu-Close at :466), `tests/headless/test_ase_interact.tcl` (:442),
  `tests/headless/test_ase_dialogs.tcl` (:852). New file
  `tests/headless/test_ase_dirty.tcl` does not exist yet.

---

## Decisions (scout's calls, each justified)

- **D1 — the prompt lives in a NEW wrapper `ase::ui::close_request`, NOT inside
  `ase::ui::close`.** `ase::ui::close` is called DIRECTLY as an unconditional
  teardown by ~10 test sites (test_ase_view/persist/plot/dialogs/interact/
  launch/window/interact) and by the quit sweep and the No/Yes paths of this
  item. If the modal prompt lived inside `close`, every one of those
  programmatic closes on a dirty session would pop a grab+tkwait dialog and
  HANG the protected suites. So `close` STAYS the teardown; a new
  `ase::ui::close_request {key}` does the dirty-check + prompt and delegates to
  `close`. The two real USER close entry points — WM_DELETE (:212) and Session>
  Close menu (:287) — are rewired to `close_request`. Behavior contract is
  identical; the ~10 direct `close` callers are untouched.
- **D2 — the Save-As is asynchronous, so "Yes" waits via a modal
  `ase::ui::save_state_modal`.** `save_state_dialog` is modeless and gives no
  save-vs-cancel answer, so `close_request`/the quit sweep cannot synchronously
  learn whether the user completed or cancelled the Save-As. `save_state_modal`
  shows the real `save_state_dialog`, blocks on `tkwait window $top.saveas`, and
  returns **1 iff the save COMPLETED, 0 iff it was cancelled**. Completion is
  signalled by a flag `dlg($key,saveas_result)` set by `do_save_state_as` (D3).
  This is robust for the untitled/new-view case where `session_dirty` stays
  true even after a successful Save-As (the new-view arm does not update the
  session's `saved`), so a "re-check dirty after the dialog closes" heuristic
  would be WRONG — the explicit flag is required.
- **D3 — `do_save_state_as` sets the completion flag, guarded.** In its shared
  success tail (before destroying `.saveas`, :2439), add `if {[info exists
  dlg($key,saveas_result)]} { set dlg($key,saveas_result) 1 }` (and `variable
  dlg` to its decls). The guard makes it a no-op for the ordinary menu Save
  State path (which never initialised the flag) — byte-identical behavior for
  every existing Save-As test.
- **D4 — NO grab in `save_state_modal`.** The RO-overwrite path (item 07) opens
  a NESTED `ase::ui::confirm` toplevel on top of `.saveas`; an application grab
  on `.saveas` would block that confirm. `tkwait window $top.saveas` alone
  gives the needed synchronous wait; the ASE window staying interactable during
  the wait matches the already-modeless Save-As and is acceptable. (The
  yes/no/cancel prompt itself DOES grab — it has no nested child.)
- **D5 — `ask_save_close` mirrors ask_save but wears the ASE theme.** A plain
  `toplevel $top.askclose` (NOT `-class Dialog` — apply_theme's class switch
  does not theme a `Dialog` class), `wm transient` to `$top`, Yes/No/Cancel
  buttons, message via `design_cell_name`, `apply_theme $w`, Return->Yes,
  `<y>`->Yes, `<n>`->No, `<Escape>`->Cancel (ESC=Cancel is the item-10 child-
  dialog idiom; the main window stays ESC-exempt). Modal via `update; catch
  {raise $w}; catch {grab set $w}; tkwait window $w`; returns `yes`/`no`/`{}`.
  Do NOT use `tkwait visibility` (WSLg map-stall trap — see the send_return
  diagnosis in test_ase_window.tcl:142).
- **D6 — quit sweep iterates the OPEN-WINDOW registry `ase::ui::wins`, not
  `ase::sessions`.** Only sessions with a live toplevel can be prompted/closed;
  headless sessions have no window. `dict keys $wins` snapshots the keys into a
  list, so calling `ase::ui::close` (which `dict unset`s `wins`) mid-loop is
  safe. Empty `wins` -> the sweep returns 1 (proceed) with zero side effects —
  the "no-op when no ASE sessions" guarantee. quit_xschem calls it behind
  `[info commands ase::ui::prompt_all_on_quit] ne {}` so a build/profile without
  ase_window.tcl is unaffected.
- **D7 — quit hook slots after `hierarchy_close quit`.** Inside
  `if {$force eq {}}`, after the schematic-hierarchy prompt succeeds and before
  `new_schematic destroy_all`. The ASE sweep, like `hierarchy_close`, may have
  saved/closed earlier sessions before a later Cancel aborts — the same
  side-effect model the existing per-level schematic prompts already accept
  (documented, acceptable v1). A preset `force` (programmatic force-quit) skips
  the sweep, matching how it skips `hierarchy_close`.
- **D8 — Ctrl-W on the session toplevel.** The item lists "any Ctrl-W" as a
  close trigger; the main ASE window currently binds none (only the log
  toplevel does). Add `bind $top <Control-w>` / `<Control-W>` ->
  `ase::ui::close_request $key` in `ase::ui::open` beside the WM_DELETE hook.
  Confirmed no conflict with the log window's own Ctrl-W (distinct toplevel).
- **D9 — the three protected menu-Close teardown sites become direct
  `ase::ui::close` calls.** `$top.mb.session invoke Close` today runs the menu
  command `[list ase::ui::close $key]`, i.e. it IS `ase::ui::close $key`. After
  the menu is rewired to `close_request`, three protected legs invoke the menu
  purely to TEAR DOWN a **dirty** session (their comments say "unsaved edits are
  discarded by contract" / they Save-As'd to a *different* view leaving the
  session dirty) and would now HANG on the modal prompt. Change ONLY those three
  lines to `ase::ui::close $key` (behavior-IDENTICAL to what the menu did
  before) to preserve their exact silent-discard teardown. The remaining three
  menu-Close sites (test_ase_window W8 :974 — clean via revert; test_ase_persist
  G9 :518 — reopened fresh, snapshot-at-save-only viewer edits do not dirty;
  test_ase_interact WF :462 — reopened fresh) close CLEAN sessions and are LEFT
  as `invoke Close` so the protected suite still exercises the new no-prompt-on-
  clean menu path. If the implementer's run reveals a TIMEOUT at any of those
  three "clean" sites (a mis-assessed dirty session), convert that one too and
  note it in the receipt.
- **D10 — new test file `tests/headless/test_ase_dirty.tcl`** (auto-discovered
  by `full_audit.sh`; NOT registered in the pre-batch-dirty `run_regression.tcl`).
  The prompt behavior is entirely GUI (windows/dialogs), so every substantive
  leg is DISPLAY-guarded (`[info exists ::has_x]` + `main_ready` self-SKIP);
  under `--nogui` the file does fixture setup only and SKIPs. Deliverable-5
  decision-flow legs STUB `ase::ui::ask_save_close` (the sanctioned modal-prompt
  test idiom — see `test_hier_walkup.tcl:45` stubbing `ask_save`) to return a
  chosen answer and count invocations, keeping `save_state_modal`/`save_state_
  dialog` REAL so the actual Save-As path is exercised. One best-effort leg
  drives the UNSTUBBED real prompt to assert the dialog widget exists.

---

## Deliverables (implement exactly)

### 1. `src/ase_window.tcl`

**(a)** In the `namespace eval ase::ui { ... }` block (near :64), add:
```tcl
  # item 16: ask_save_close's yes/no/cancel result (read across tkwait)
  variable asksave_result {}
```

**(b) `ase::ui::asksave_done` + `ase::ui::ask_save_close`** (place near the
other dialog helpers). Modal yes/no/cancel, ASE-themed, mirrors ask_save:
```tcl
proc ase::ui::asksave_done {w val} {
  set ::ase::ui::asksave_result $val
  catch {destroy $w}
}

# Modal "save this dirty ASE session?" prompt (ask_save semantics + ASE theme).
# Returns yes / no / {} (empty == Cancel). Child of the session toplevel so it
# dies with it and tests can find it at $top.askclose.
proc ase::ui::ask_save_close {key} {
  variable wins
  if {![dict exists $wins $key]} { return no }
  set top [dict get $wins $key]
  set w $top.askclose
  catch {destroy $w}
  toplevel $w
  wm title $w {Save State?}
  catch {wm transient $w $top}
  set cell [ase::ui::design_cell_name $key]
  label $w.msg -font AseLabelFont -justify left -anchor w \
    -text "Simulation state “$cell” has unsaved changes.\n\nSave changes before closing?"
  pack $w.msg -side top -fill x -padx 16 -pady 12
  frame $w.btns
  button $w.btns.yes    -text Yes    -width 8 -command [list ase::ui::asksave_done $w yes]
  button $w.btns.no     -text No     -width 8 -command [list ase::ui::asksave_done $w no]
  button $w.btns.cancel -text Cancel -width 8 -command [list ase::ui::asksave_done $w {}]
  pack $w.btns.yes $w.btns.no $w.btns.cancel -side left -padx 5 -expand yes
  pack $w.btns -side bottom -fill x -padx 8 -pady 8
  bind $w <Return> [list $w.btns.yes invoke]
  bind $w <y>      [list $w.btns.yes invoke]
  bind $w <n>      [list $w.btns.no invoke]
  ase::ui::bind_dialog_esc $w [list $w.btns.cancel invoke]  ;# ESC = Cancel
  ase::ui::apply_theme $w
  set ::ase::ui::asksave_result {}
  update
  catch {raise $w}
  catch {grab set $w}
  focus $w.btns.yes
  tkwait window $w
  return $::ase::ui::asksave_result
}
```

**(c) `ase::ui::save_state_modal`** — show the real Save-As, block, return
1(completed)/0(cancelled):
```tcl
# Run Save State (Save-As) MODALLY for the close/quit paths: show the modeless
# save_state_dialog, block until it is dismissed, and report whether the save
# COMPLETED (1) or was cancelled (0). No grab (the RO-overwrite confirm is a
# nested child). Completion is flagged by do_save_state_as via
# dlg($key,saveas_result).
proc ase::ui::save_state_modal {key} {
  variable wins; variable dlg
  if {![dict exists $wins $key]} { return 0 }
  set dlg($key,saveas_result) 0
  set w [ase::ui::save_state_dialog $key]
  if {![winfo exists $w]} { catch {unset dlg($key,saveas_result)}; return 0 }
  tkwait window $w
  set r 0
  if {[info exists dlg($key,saveas_result)]} { set r $dlg($key,saveas_result) }
  catch {unset dlg($key,saveas_result)}
  return $r
}
```

**(d) `ase::ui::close_request`** — the prompt-aware close (the new WM_DELETE /
menu Close / Ctrl-W target):
```tcl
# item 16: prompt-aware session close. Clean -> teardown. Dirty -> yes/no/cancel:
#   Yes    -> Save-As; close ONLY if the save completed (cancelled Save-As aborts)
#   No     -> close, discarding (ase::ui::close's :234 notice fires)
#   Cancel -> abort, leaving the window + per-window state arrays intact
proc ase::ui::close_request {key} {
  variable wins
  if {![dict exists $wins $key]} { return }
  if {![ase::session_dirty $key]} { ase::ui::close $key; return }
  switch -- [ase::ui::ask_save_close $key] {
    yes     { if {[ase::ui::save_state_modal $key]} { ase::ui::close $key } }
    no      { ase::ui::close $key }
    default { return }
  }
}
```

**(e) `ase::ui::prompt_all_on_quit`** — the quit sweep:
```tcl
# item 16: xschem-quit ASE sweep. Prompt each dirty open session; a Cancel on
# ANY aborts the whole quit (return 0). Yes -> Save-As (a cancelled Save-As also
# aborts); No -> discard+close. Returns 1 to proceed. No-op (returns 1) when no
# ASE window is open. Iterates a snapshot of the open-window keys so the
# ase::ui::close dict-unset mid-loop is safe.
proc ase::ui::prompt_all_on_quit {} {
  variable wins
  foreach key [dict keys $wins] {
    if {![dict exists $wins $key]} { continue }
    if {![ase::session_dirty $key]} { continue }
    catch {raise [dict get $wins $key]}
    switch -- [ase::ui::ask_save_close $key] {
      yes     { if {![ase::ui::save_state_modal $key]} { return 0 }
                ase::ui::close $key }
      no      { ase::ui::close $key }
      default { return 0 }
    }
  }
  return 1
}
```

**(f) Rewire the two close entry points + add Ctrl-W** — in `ase::ui::open`
around :212:
```tcl
  wm protocol $top WM_DELETE_WINDOW [list ase::ui::close_request $key]
  bind $top <Control-w> [list ase::ui::close_request $key]
  bind $top <Control-W> [list ase::ui::close_request $key]
```
and the Session menu Close entry at :287:
```tcl
  $top.mb.session add command -label Close -command [list ase::ui::close_request $key]
```

**(g) `do_save_state_as` completion flag** — add `variable dlg` to its decls
(after `variable wins` at :2410) and, in the shared success tail just before the
`if {[dict exists $wins $key]} { catch {destroy [dict get $wins $key].saveas} }`
(:2439):
```tcl
  if {[info exists dlg($key,saveas_result)]} { set dlg($key,saveas_result) 1 }
```

**Do NOT** edit `ase::ui::close` (it stays the teardown; its :234-236 discard
notice remains — accurate for the No path, cosmetically loose after a Yes-save
to a new view, which is acceptable v1).

### 2. `src/xschem.tcl` — quit_xschem ASE sweep (D7)

Inside `proc quit_xschem`, in the `if {$force eq {}}` block, immediately AFTER
`if {![hierarchy_close quit]} return`:
```tcl
    # item 16: prompt to save any dirty ASE-L session before exit; a Cancel on
    # any aborts the quit. No-op when no ASE window is open (and when ase_window
    # is not loaded), so normal quit / other windows are unaffected.
    if {[info commands ase::ui::prompt_all_on_quit] ne {}} {
      if {![ase::ui::prompt_all_on_quit]} return
    }
```

### 3. Protected-test teardown edits (D9) — one line each, behavior-preserving

- `tests/headless/test_ase_persist.tcl:466`
  `$top.mb.session invoke Close` -> `ase::ui::close $key`
- `tests/headless/test_ase_interact.tcl:442`
  `$top.mb.session invoke Close` -> `ase::ui::close $key`
- `tests/headless/test_ase_dialogs.tcl:852`
  `$top.mb.session invoke Close` -> `ase::ui::close $key`

(Each closes a DIRTY session as a pure teardown; the direct call reproduces the
pre-rewire behavior exactly. Do NOT touch the clean-session menu-Close sites at
test_ase_window.tcl:974, test_ase_persist.tcl:518, test_ase_interact.tcl:462 —
they now cover the no-prompt-on-clean menu path.)

### 4. `tests/headless/test_ase_dirty.tcl` (NEW)

Model the fixture on `tests/headless/test_ase_window.tcl:197-260` (scratch
`aselib` via a `library.defs` DEFINE + `::library_registry_defs_only 1`, a
`nfet_clean/schematic/nfet_clean.sch`, `library_new_view aselib nfet_clean
ngspice_state1 ngspice_state1`, then shape + `session_save` the state). Use
`check`/`check_true` and `main_ready` from test_ase_window.tcl. Standalone repro
from repo ROOT: `./src/xschem --pipe -q --nolog --script
tests/headless/test_ase_dirty.tcl` (add DISPLAY for the GUI legs; a run leg is
not needed — this item never simulates).

Helpers to define in the test:
```tcl
proc make_dirty {key} {                     ;# session_update -> dirty, headless-safe
  set st [ase::session_state $key]
  dict set st variables [list [list name Vgs value 9.9]]
  ase::session_update $key $st
}
# after-poller that drives the modeless Save-As during save_state_modal's tkwait
proc drive_saveas {top view action} {       ;# action: proceed | cancel
  if {[winfo exists $top.saveas]} {
    set ::saveas_seen 1
    if {$action eq {proceed}} {
      if {$view ne {}} { $top.saveas.view delete 0 end; $top.saveas.view insert 0 $view }
      $top.saveas.btns.proceed invoke
    } else { $top.saveas.btns.cancel invoke }
    return
  }
  after 30 [list drive_saveas $top $view $action]
}
```

GUI legs (guard the whole block with `if {[info exists ::has_x] && [info
commands winfo] ne {}}` and `if {![main_ready]} { puts "SKIPPED: ..."; ... }`;
open a fresh window per leg via `ase::open_state aselib nfet_clean
ngspice_state1` -> `set top [ase::ui::window_for $key]`). Named checks:

- **DR1 menu Close wired to close_request** —
  `[$top.mb.session entrycget Close -command]` eq `[list ase::ui::close_request $key]`.
- **DR2 WM_DELETE wired to close_request** —
  `[wm protocol $top WM_DELETE_WINDOW]` eq `[list ase::ui::close_request $key]`.
- **DR3 Ctrl-W bound to close_request** —
  `[string match *close_request* [bind $top <Control-w>]]`.
- **DR4 real prompt dialog appears (best-effort; run BEFORE the stub is
  defined)** — `make_dirty $key`; schedule an after-poller that waits for
  `$top.askclose`, records `winfo exists` + that `$top.askclose.btns.yes/no/
  cancel` all exist + `[$top.askclose cget -background]` eq `[ase::theme panel]`,
  then `$top.askclose.btns.cancel invoke`; call `ase::ui::close_request $key`;
  assert the recorded facts and that the window SURVIVED (Cancel). If the poller
  times out (WSLg), `puts "SKIPPED: DR4 (WSLg dialog stall)"` and continue — do
  NOT emit the full-audit SKIP token for this one leg.

  Then define the stub `proc ase::ui::ask_save_close {key} { incr ::askc; return
  $::askans }` for the decision-flow legs (keep save_state_modal/save_state_
  dialog REAL):

- **DR5 unedited -> NO prompt** — clean session; `set ::askc 0`;
  `ase::ui::close_request $key`; check `$::askc`==0 and `![winfo exists $top]`
  (closed with no prompt).
- **DR6 Cancel keeps window + state intact** — fresh dirty session; snapshot
  `set snap [ase::state_serialize [ase::session_state $key]]`;
  `set ::askans {}; set ::askc 0`; `ase::ui::close_request $key`; check
  `$::askc`==1, `[winfo exists $top]` (survives), `[ase::session_state $key] ne
  {}` (still registered), `[ase::session_dirty $key]`==1, and the serialize
  still equals `$snap`.
- **DR7 No -> discard + close** — (continue the DR6 dirty session)
  `set ::askans no`; `ase::ui::close_request $key`; check `![winfo exists $top]`
  and `[ase::session_state $key] eq {}` (unregistered).
- **DR8 Yes + save completes -> saved + closed (own view)** — fresh dirty
  session; `set ::askans yes; set ::saveas_seen 0`;
  `after 30 [list drive_saveas $top {} proceed]`; `ase::ui::close_request $key`;
  check `$::saveas_seen`==1 (real Save-As ran), `![winfo exists $top]` (closed),
  and the on-disk state file now carries `Vgs value 9.9`
  (`string match *{name Vgs value 9.9}* [read <spath>]`).
- **DR9 Yes untitled -> Save-As creates the view (deliverable 4)** — register an
  untitled session (`set uk [ase::new_session aselib nfet_clean schematic];
  ase::ui::open $uk aselib nfet_clean (unsaved)`), `make_dirty $uk`;
  `set ::askans yes; set ::saveas_seen 0`; `after 30 [list drive_saveas $utop
  ngspice_dirty1 proceed]`; `ase::ui::close_request $uk`; check the new view file
  `$scratch/aselib/nfet_clean/ngspice_dirty1/nfet_clean.state` exists and the
  untitled window is gone.
- **DR10 Yes RO -> Save-As, RO file untouched (deliverable 3)** — open RO
  (`ase::open_state aselib nfet_clean ngspice_state1 1`), `make_dirty`; capture
  the RO file's mtime; `set ::askans yes`; `after 30 [list drive_saveas $top
  ngspice_ro1 proceed]` (a DIFFERENT new view); `ase::ui::close_request $key`;
  check the RO view file's mtime is UNCHANGED (never silently written) and
  `ngspice_ro1/nfet_clean.state` was created.
- **DR11 Yes + Save-As cancelled -> abort** — fresh dirty session;
  `set ::askans yes; set ::saveas_seen 0`;
  `after 30 [list drive_saveas $top {} cancel]`; `ase::ui::close_request $key`;
  check `$::saveas_seen`==1, `[winfo exists $top]` (SURVIVES — abort),
  `[ase::session_dirty $key]`==1.
- **DR12 quit Cancel aborts, session survives** — fresh dirty session;
  `set ::askans {}`; `set r [ase::ui::prompt_all_on_quit]`; check `$r`==0,
  `[winfo exists $top]`, `[ase::session_dirty $key]`==1.
- **DR13 quit No proceeds + closes** — (same session) `set ::askans no`;
  `set r [ase::ui::prompt_all_on_quit]`; check `$r`==1, `![winfo exists $top]`,
  `[ase::session_state $key] eq {}`.
- **DR14 quit no-op with no ASE windows** — after DR13 leaves `wins` empty,
  `check "DR14" [ase::ui::prompt_all_on_quit] 1` (returns 1, no prompt: `::askc`
  unchanged across the call).

End with a `RESULT: ALL PASS (<n> checks)` / `RESULT: <fail> FAILED` summary
line and the full-audit SKIP token only when the WHOLE GUI block self-SKIPs
(no DISPLAY / main not ready), matching test_ase_window.tcl.

---

## MUST NOT regress

- `ase::ui::close` is UNCHANGED — every direct `ase::ui::close $key` caller
  (test_ase_view/persist/plot/dialogs/interact/launch/window and the log
  window's own teardown) behaves exactly as before.
- Ordinary Save State (menu `Save State` -> save_state_dialog -> do_save_state_as)
  is byte-identical: the `dlg($key,saveas_result)` write is guarded by
  `info exists`, so it never fires outside `save_state_modal`.
- Normal (non-ASE) schematic quit/close: `quit_xschem`'s ASE sweep is a no-op
  when no ASE window is open (`dict keys $wins` empty -> `prompt_all_on_quit`
  returns 1) and is skipped on a preset `force`. `hierarchy_close` /
  `new_schematic destroy_all` / `close_schematic_window` are untouched.
- The nine protected ASE/wave suites must stay green:
  `test_ase_{core,view,window,dialogs,final,interact,plot,persist,launch}` and
  `test_wave_viewer`. The three teardown edits (D9) are behavior-preserving; any
  further assertion change (should a "clean" menu-Close site prove dirty) MUST be
  justified in the receipt.

## Verification before commit

Run each test in its own process from the repo ROOT
(`./src/xschem --pipe -q --nolog --script tests/headless/<t>.tcl`, add DISPLAY
for the GUI legs): the new `test_ase_dirty` plus the ten protected suites above
(especially the three edited: persist, interact, dialogs), then
`tests/headless/full_audit.sh`. The fail set must be a SUBSET of the PLAN
baseline (below); any non-baseline fail — or a TIMEOUT that was not there before
(a hung modal on a missed dirty close) — is yours. Sabotage-verify per the
policy block.

Baseline-tolerated full_audit fails (pre-existing, NOT yours):
test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context, test_lib_manager_gui,
test_lib_sweep, test_palette, test_phase3_mints, test_pin_type_edit,
test_reopen_readonly, test_select_at, test_selflog_output,
test_verb_noun_copy_move, test_wire_split, test_wire_vertex_grab; TIMEOUT
test_key_graph_context. WSLg flakes (not regressions if a direct re-run passes):
test_deselect_mode, test_hover_highlight, test_ase_window (send_return / self-
SKIP; rerun-first).

## Sabotage plan (≥2; do all three; each fails EXACTLY its target, nothing else)

- **S1** — in `ase::ui::close_request` change the `default { return }` arm to
  `default { ase::ui::close $key }` (Cancel no longer aborts). Target: **DR6**
  (Cancel keeps the window) FAILS — the window is destroyed. DR5/DR7 stay green.
  Confirms Cancel gates the close.
- **S2** — in `ase::ui::close_request` change the Yes arm to
  `yes { ase::ui::save_state_modal $key; ase::ui::close $key }` (ignore the
  return). Target: **DR11** (Yes + Save-As cancelled -> abort) FAILS — the
  window is destroyed despite the cancelled Save-As. DR8 stays green. Confirms
  the save-cancel abort.
- **S3** — in `ase::ui::prompt_all_on_quit` change the `default { return 0 }`
  arm to `default { continue }` (Cancel no longer aborts the quit). Target:
  **DR12** (quit Cancel -> returns 0) FAILS — it returns 1 and closes the
  session. DR13 stays green. Confirms the quit-abort-on-cancel.

**Revert mechanism:** the feature is UNCOMMITTED at sabotage time, so
`git checkout -- <file>` would nuke the feature edits (the RUNBOOK's "git diff
confirms the file holds nothing but the sabotage" precondition cannot hold).
Revert each sabotage with a precise reverse-`Edit`, confirm via `git diff` that
only the sabotage lines moved (before) and a clean green re-run (after) — the
documented item-15 precedent (receipts/15). Then make the single feature commit.

## Commit (ONE commit, explicit file list — stage ONLY these six)

```
git add src/ase_window.tcl src/xschem.tcl \
        tests/headless/test_ase_dirty.tcl \
        tests/headless/test_ase_persist.tcl \
        tests/headless/test_ase_interact.tcl \
        tests/headless/test_ase_dialogs.tcl
```
NEVER stage the pre-batch dirty tracked files regardless of their current
state: `doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
`tests/run_regression.tcl`. Never `git add -A`/`commit -a`, never `git reset
--hard`, never push.

Suggested message (normal prose + Co-Authored-By trailer):
`feat(ase): prompt to save a dirty ASE-L session on close and on xschem quit`

---

## RUNBOOK — Policies (non-negotiable) [verbatim]

- Git: NEVER `git reset --hard`, NEVER `git add -A`/`commit -a`, NEVER push.
  Stage explicit file lists only. Pre-existing dirty tracked files at batch
  start (listed in PLAN.md preflight) must NEVER be staged; in particular
  `tests/run_regression.tcl` is dirty pre-batch → this batch does NOT register
  tests there; tests/headless/full_audit.sh auto-discovers `test_*.tcl`.
- A green suite ≠ the changed code ran: sabotage-verify (each sabotage fails
  EXACTLY its target check, revert via targeted `git checkout -- <file>` only
  after `git diff` confirms the file holds nothing but the sabotage, clean
  re-run green).
- Headless traps: each test its own process; repo-root cwd for relative paths;
  script error idles rather than hangs; `--nogui --pipe -q --nolog --script`.
- GUI tests: DISPLAY-guarded self-SKIP (`winfo exists .` guard pattern from
  full_audit.sh); replay WHOLE Tk event sequences in the shipping rc profile.
- User-facing messages via `ciw_echo`, not puts/statusbar.
- Tcl: TIP-278 (`variable`/absolute names in namespaces); C (if any): C89,
  `_ALLOC_ID_` placeholders. Windows: guard unix-only subprocess paths.
- Do not touch `_nhangle_*`/`_allm_*`/junk dirs or anything outside declared
  scope. Do not edit generated files (Makefile from Makefile.in — tmpasm, no
  `$@`/`$<`, `@` is the delimiter).
- Commit messages: normal prose, Co-Authored-By trailer per repo convention.
