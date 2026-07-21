# Item 10 — esc-dismiss: every ASE-L dialog dismissible with ESC

Repo: /home/qflow/dev/xschem/claude_1/xschem, branch `fluid-editing`.
Spec: doc/claude/specs/ase_l.md — "UI v2 — ADE-L parity rework" :155-271,
"Dialog style" :268-271, "Log window (not a pane)" :257-260, "Select On
Design v1 scope" :215-229.
Item detail: PLAN.md "Round 2 addendum / 10 esc-dismiss" (:354-383).
All anchors below re-verified from source 2026-07-21 by the scout
(post-05b2a708/900d7e6d tree; ase_window.tcl = 2618 lines).

## RUNBOOK policies (copied verbatim — non-negotiable)

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

Additional batch facts for THIS item:
- Dirty tracked files right now (never stage any of them):
  `doc/claude/ase_l_batch/PLAN.md` (driver-owned),
  `doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
  `src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
  `tests/run_regression.tcl`, and the two `xschem_libs_newsym/SANDBOX/...`
  files. All three files in this item's commit list were verified CLEAN at
  scout time (`git status --porcelain` empty for them); re-verify before
  staging.
- Protected tests that must stay green: test_ase_core, test_ase_view,
  test_ase_window, test_ase_final, test_ase_interact (this item should need
  ZERO assertion changes in any of them — the feature is additive; if reality
  disagrees, justify every change in the receipt). test_ase_dialogs is this
  item's own test and grows new legs.
- Baseline full_audit fail list (tolerated, list equality): FAIL:
  test_altf5_ciw, test_cadence_descend_newwin_ro, test_cadence_drag,
  test_cadence_window_hop_log, test_ciw, test_crossview_paste,
  test_fluid_editing, test_hi_descend, test_launch_context,
  test_lib_manager_gui, test_lib_sweep, test_palette, test_phase3_mints,
  test_pin_type_edit, test_reopen_readonly, test_select_at,
  test_selflog_output, test_verb_noun_copy_move, test_wire_split,
  test_wire_vertex_grab. TIMEOUT: test_key_graph_context. Known WSLg flakes
  (not regressions if a direct re-run passes): test_deselect_mode,
  test_hover_highlight, test_ase_window inside PARALLEL audit runs, plus the
  receipts/08 addendum trio test_graph_context / test_multi_window /
  test_readonly_action_dispatch — rerun-first.

## Scope

User request 2026-07-21: ANY dialog opened through ASE-L must be dismissible
with ESC, and ESC must run the dialog's CANCEL path (per-window records
cleaned, zero state mutation) — never a bare `destroy` that leaks records.

- ONE new helper + wiring in `src/ase_window.tcl` (no ase.tcl change — it
  holds no Tk code, verified: zero `toplevel`/`tk_messageBox`/`Escape` hits).
- ESC on the ASE MAIN session window stays UNBOUND (no accidental close).
- The log window stays ESC-unbound (scout decision D6 below).
- The item-08 Select-On-Design canvas `<Key-Escape>` seize/restore
  (select_on_design :1077/:1091/:1096, sod_end :1108/:1114) is UNTOUCHED —
  it lives on the design canvas, not on ASE toplevels; a regression leg
  proves it still works.
- Native popups (tk_popup context menus; the one tk_messageBox in
  references/) already ESC-cancel natively — out of scope.

## Dialog inventory (scout-enumerated; the complete set — 7 toplevel-creation
sites in ase_window.tcl: :197 session, :829 dialog_frame, :1312 confirm,
:1484 chana.x, :1731 listdlg, :1969 loadst, :2395 logwin)

Scaffold dialogs — all built by `dialog_frame` :827 and all calling
`dialog_buttons` :843 with their cancel command (9 dialogs, 8 call sites):

| # | dialog (path under $top) | created at | dialog_buttons call | CANCEL path | per-window records the cancel cleans |
|---|---|---|---|---|---|
| 1 | `.addvar` Add Variable | :855-868 | :861-862 | `[list destroy $w]` | none |
| 2 | `.edvar` Edit Variable | :898-919 | :912-913 | `variable_editor_cancel` :948 | `edrow($key,var)` |
| 3 | `.edout` Add/Edit Output | :960-997 | :990-991 | `output_editor_cancel` :1037 | `edrow($key,out)`, `edchk($key,plot)`, `edchk($key,save)` |
| 4 | `.chana` Choose Analyses | :1360-1387 | :1383-1384 | `chana_cancel` :1460 | `dlg($key,antype)`, `dlg($key,anen)`, `dlg($key,anextra)` |
| 5 | `.design` Setup Design | :1608-1634 | :1623-1624 | `design_cancel` :1697 | `dlg($key,dlib)`, `dlg($key,dcell)`, `dlg($key,dview)` |
| 6 | `.modrow` Model File row editor | via `listdlg_editor` :1787-1814 | :1809-1810 | `listdlg_editor_cancel` :1861 | `dlg($key,models)` |
| 7 | `.optrow` Sim Option row editor | via `listdlg_editor` (same site) | :1809-1810 | `listdlg_editor_cancel` :1861 | `dlg($key,simopt)` |
| 8 | `.saveall` Save All | :1901-1921 | :1915-1916 | `save_all_cancel` :1937 | `dlg($key,allv)`, `dlg($key,alli)` |
| 9 | `.saveas` Save State (Save-As) | :2080-2105 | :2097-2098 | `saveas_cancel` :2113 | `dlg($key,salib)` |

Non-scaffold dialogs (own `toplevel` + own buttons — need explicit wiring):

| # | dialog | created at | current Cancel/Close | records |
|---|---|---|---|---|
| 10 | `.confirm` shared confirm | :1307-1326 | Cancel = `[list destroy $w]` :1318 | none (oncmd must NOT run) |
| 11 | `.chana.x` Analysis Options subdialog | :1479-1521 | Cancel = `[list destroy $w]` :1509 — LEAKS `dlg($key,anextra)` until parent close | `dlg($key,anextra)` (unset today only by `chana_x_ok` :1586 / `chana_cancel` :1464 / `close` :236) |
| 12 | `.models` / `.simopt` list dialogs | `listdlg_open` :1725-1759 | Close = `[list destroy $w]` :1742 | none |
| 13 | `.loadst` Load State browser | :1964-2001 | Cancel = `[list destroy $w]` :1990 | none |

NOT dialogs (stay ESC-unbound):
- `.ase<N>` session window (`ase::ui::open` :193-211; no Escape binding
  today — grep confirms Escape appears in ase_window.tcl only at
  :1050/:1062 comments + sod :1091/:1096/:1114).
- `$top.logwin` log window (`log_open` :2385-2406, Ctrl-W close :2402-2403).

## Verified Tk facts (scout live-probed on this box, Tk 8.6 under WSLg)

- Toplevel bindtags are `{$w Toplevel all}`; a child widget's bindtags are
  `{child Class $nearestToplevel all}`. So `bind $w <Key-Escape>` on a dialog
  toplevel fires from ANY child (the entry-bubbling requirement) — the Entry
  class Escape binding is Tk's no-op `# nothing` and does NOT stop
  propagation (probe-confirmed: ESC in an entry fires the toplevel binding).
- A NESTED toplevel (`.chana.x` inside `.chana`) has bindtags
  `{.chana.x Toplevel all}` — the parent dialog's ESC binding can NEVER fire
  while focus sits in the subdialog (probe-confirmed both directions).
- `bind all <Key-Escape>` is empty in this app — no `break` needed in the
  new bindings.
- House precedent: xschem.tcl binds `<Escape>` to the Cancel-button path on
  ~15 dialogs (e.g. :7650 `.editpaths`, :8512 `.symview`, :9518/:10541
  `.dialog`) — this item brings ASE up to that standard.

## Scout decisions (each with its one-line justification)

- **D1 helper name/namespace**: `ase::ui::bind_dialog_esc {w cancelcmd}` —
  every dialog-layer proc in this file lives in `ase::ui`, so the item
  detail's suggested `ase::` spelling is adjusted for file consistency.
  Body: `bind $w <Key-Escape> $cancelcmd` (no `break`; see Tk facts).
- **D2 constructor wiring**: the call goes INSIDE `dialog_buttons` :843
  (`ase::ui::bind_dialog_esc $w $cancelcmd` — $w IS the dialog toplevel,
  dialog_frame grids everything into it directly): all 9 scaffold dialogs
  get ESC by construction and every FUTURE dialog_frame+dialog_buttons
  dialog inherits it automatically. Document that in the dialogs section
  comment block :818-822.
- **D3 explicit sites**: four non-scaffold dialogs get one
  `ase::ui::bind_dialog_esc` call each at creation: `.confirm` →
  `[list destroy $w]` (its Cancel), `.chana.x` → the NEW `chana_x_cancel`
  (D5), `listdlg_open`'s `$w` → `[list destroy $w]` (its Close),
  `.loadst` → `[list destroy $w]` (its Cancel).
- **D4 confirm gets ESC**: the item's "tk_messageBox/confirm popups already
  ESC-cancel natively — leave" clause covers NATIVE popups only;
  `ase::ui::confirm` is a custom modeless toplevel with no ESC today
  (verified :1307-1326) — ESC = its Cancel (destroy, oncmd NOT run).
- **D5 chana.x cancel-path fix**: add `proc ase::ui::chana_x_cancel {key}`
  = `array unset dlg $key,anextra` + destroy `.chana.x`, and rewire the
  existing Cancel button :1509 to it too — today's bare-destroy Cancel
  leaves `dlg($key,anextra)` set until the parent closes, exactly the leak
  class the item forbids (`chana_cancel`/`close` stay as backstops;
  `chana_options` re-derives anextra on every open :1487-1493, so no
  behavior change beyond the cleanup).
- **D6 log window is NOT a dialog**: the spec gives it its own section
  ("Log window (not a pane)" :257-260) separate from "Dialog style", its
  documented close is Ctrl-W, and ESC-killing a live-follow log mid-run
  would surprise — stays unbound; a structural check asserts that.
- **D7 main window**: stays unbound per the item; the no-op leg proves ESC
  DELIVERY with a temporary test-side witness binding (receipts/06 lesson:
  rejection/no-op legs need a delivery witness), then restores the empty
  binding.
- **D8 Select-On-Design isolation**: sod seizes `<Key-Escape>` on the DESIGN
  canvas, never on ASE toplevels — zero interaction with this item; keep a
  compact regression leg in test_ase_dialogs AND re-run the protected
  test_ase_interact (its I7 is the deep coverage).
- **D9 send_key**: generalize test_ase_dialogs' local `send_return`
  :104-122 to `send_key {w ev done}` (event string parameter) and keep
  `send_return {w done}` as a 2-line wrapper so the existing call sites
  :305/:377/:424 don't change. ONLY test_ase_dialogs.tcl is touched —
  per-file helper copies are the established discipline (test_ase_window's
  copy stays as-is).
- **D10 spec note**: one sentence appended to "Dialog style" :268-271
  ("Every dialog dismisses on ESC through the same cancel path as its
  Cancel button; the ASE main window and the log window are exempt.") —
  batch precedent (items 08/09 spec notes); file verified clean.

## Deliverables

### 1. `src/ase_window.tcl`

a. New proc `ase::ui::bind_dialog_esc {w cancelcmd}` near the dialogs
   section header (:818-826), with a comment naming the contract (ESC = the
   dialog's cancel path; wired centrally in dialog_buttons so future
   dialogs inherit it) and referencing this item.
b. `dialog_buttons` :843-850: add `ase::ui::bind_dialog_esc $w $cancelcmd`
   (covers dialogs 1-9 of the inventory).
c. New proc `ase::ui::chana_x_cancel {key}` (D5) next to `chana_x_ok`
   :1562; rewire the `.chana.x` Cancel button :1509 to it.
d. Explicit `bind_dialog_esc` calls in: `confirm` :1307ff (→
   `[list destroy $w]`), `chana_options` :1479ff (→
   `[list ase::ui::chana_x_cancel $key]`), `listdlg_open` :1725ff (→
   `[list destroy $w]`), `load_state_dialog` :1964ff (→
   `[list destroy $w]`).
e. NOTHING else: no binding on the session toplevel (`ase::ui::open`) or
   the log window (`log_open`); sod procs untouched; no ase.tcl change.

### 2. `doc/claude/specs/ase_l.md`

Append the D10 sentence to the "Dialog style" paragraph (:268-271).

### 3. Tests — `tests/headless/test_ase_dialogs.tcl` (currently 608 lines,
73 checks; helpers :39-138, GUI guard `if {[info exists ::has_x] ...}` :270,
G10 :553-559, G11 :561-583, final close leg :585-588, cleanup :599-601)

Generalize `send_return` per D9. Insert the new `GE` section after the G11
check (:583) and BEFORE the final close leg (the close leg stays last).
Common pattern per dialog leg: `set snap [ase::state_serialize
[ase::session_state $key]]` before opening; open via a REAL entry point
(menu/strip/ctx where one exists; direct proc call acceptable for row
editors and confirm — their open paths are already proven in G1-G10);
optionally perturb a field; `send_key <target> <Key-Escape> {![winfo exists
<dialog>]}`; then the named checks. Suggested check names (keep the
prefixes; exact wording yours):

- **GE1 Add Variable** (`$top.strip.var invoke`; type a name first):
  `GE1 ESC dismisses Add Variable`; `GE1 state unchanged`
  (serialize eq $snap).
- **GE2 Edit Variable** (`ase::ui::variable_editor $key 0`; focus + type in
  `$top.edvar.value`, then send ESC TO THE ENTRY — the bubbling proof):
  `GE2 ESC from inside an entry dismisses the editor`;
  `GE2 edrow record cleaned` (`info exists ::ase::ui::edrow($key,var)` = 0);
  `GE2 state unchanged`.
- **GE3 Add Output** (`$top.strip.out invoke`):
  `GE3 ESC dismisses Add Output`; `GE3 edrow/edchk records cleaned` (all
  three of `edrow($key,out)`, `edchk($key,plot)`, `edchk($key,save)` gone —
  one check or three, your call); `GE3 state unchanged`.
- **GE4 Choose Analyses** (`$top.strip.ana invoke`; click the tran radio
  first): `GE4 ESC dismisses Choose Analyses`; `GE4 antype/anen records
  cleaned`; `GE4 state unchanged`.
- **GE5 Analysis Options subdialog** (open chana, `$top.chana.opts invoke`;
  ESC on `.chana.x`): `GE5 ESC dismisses Analysis Options`;
  `GE5 parent Choose Analyses survives` (nested-toplevel isolation);
  `GE5 anextra record cleaned` (`dlg($key,anextra)` gone — the D5 fix);
  then ESC on `.chana`: `GE5 ESC then dismisses Choose Analyses`.
- **GE6 Setup Design** (menu `$top.mb.setup` "Design…"):
  `GE6 ESC dismisses Setup Design`; `GE6 dlib/dcell/dview records cleaned`;
  `GE6 state unchanged`.
- **GE7 Model Files list dialog** (menu): `GE7 ESC dismisses Model Files`.
- **GE8 Model row editor** (reopen models, ctx "Add…"; ESC on `.modrow`):
  `GE8 ESC dismisses the row editor`; `GE8 models list dialog survives`;
  `GE8 dlg(models) record cleaned`; then ESC closes `.models`.
- **GE9 Sim Options** (menu; ctx "Add…"): same trio for `.simopt` /
  `.optrow` / `dlg($key,simopt)` (may be terser than GE8 — one dismiss
  check each + the record check).
- **GE10 Save All** (menu; toggle `$top.saveall.alli` first):
  `GE10 ESC dismisses Save All`; `GE10 allv/alli records cleaned`;
  `GE10 state unchanged` (the toggled checkbox must NOT reach
  `save_all_i`).
- **GE11 Load State browser** (menu): `GE11 ESC dismisses Load State`;
  `GE11 state unchanged`.
- **GE12 Save State Save-As** (menu): `GE12 ESC dismisses Save-As`;
  `GE12 salib record cleaned`; `GE12 state unchanged`.
- **GE13 confirm** (`unset -nocomplain ::ge13;
  ase::ui::confirm $key T msg {set ::ge13 1}`): `GE13 ESC dismisses the
  confirm`; `GE13 oncmd did not run` (`info exists ::ge13` = 0).
- **GE14 main window ESC is a no-op**: `GE14 session toplevel has no Escape
  binding` (`bind $top <Key-Escape>` eq {}); add witness
  `bind $top <Key-Escape> {set ::ge14 1}`, send_key with done
  `{[info exists ::ge14]}`: `GE14 ESC delivery witnessed`;
  `GE14 window survives` + `GE14 state unchanged`; restore
  `bind $top <Key-Escape> {}`.
- **GE15 log window stays exempt** (`ase::ui::log_open $key`):
  `GE15 log window has no Escape binding` (structural — Ctrl-W close is
  already covered by test_ase_window W6c); destroy it afterwards.
- **GE16 Select-On-Design ESC regression** (D8):
  `ase::ui::select_on_design $key {save 1 plot 0}` — if it returns 0
  (design window unopenable, WSLg W4-class stall) print a justified
  `SKIPPED:` line instead (self-SKIP, receipts/06 classification); else
  capture `$::ase::ui::sod($key,canvas)` + `sod($key,prevesc)` and drive a
  focus-gated `<Key-Escape>` at the CANVAS with the test_ase_interact I7
  retry pattern (:244-263 there; done = `[bind $cv <Key-Escape>] eq $prev`):
  `GE16 SOD ESC still ends the mode`; `GE16 canvas Escape binding
  restored verbatim`.

Headless arm: unchanged (H1-H4); the whole GE section sits inside the
existing `::has_x` guard.

### 4. Runs (repo root cwd)

```sh
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl   # with DISPLAY
env -u DISPLAY ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_dialogs.tcl  # headless arm still green
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_interact.tcl  # protected — I7 sod ESC
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_window.tcl    # protected
./src/xschem --pipe -q --nolog --script tests/headless/test_ase_view.tcl      # protected
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl   # protected
./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_final.tcl  # protected
tests/headless/full_audit.sh    # compare against the baseline list above
```

## Sabotage plan (≥2 required; do all three; one at a time, `git diff` must
show ONLY the sabotage, targeted `git checkout -- src/ase_window.tcl`
revert, clean re-run green after each)

- **S1 constructor wiring dropped**: remove the `bind_dialog_esc` call from
  `dialog_buttons` only. Every scaffold-dialog GE dismissal check fails
  (send_key times out with its diagnostic, dialog survives): GE1-GE4,
  GE5's "ESC then dismisses Choose Analyses", GE6, GE8 row-editor, GE9
  row-editor, GE10, GE12 — plus their dependent record/state checks in
  those blocks. The explicit-site legs (GE5 subdialog trio, GE7, GE9
  `.simopt` dismiss, GE11, GE13) and GE14-GE16 stay green — the
  differential that proves the two wiring layers are independently
  covered. Enumerate the observed fail set in the receipt (item-07 S2
  precedent: finer granularity than predicted is fine if every fail sits
  inside the targeted blocks).
- **S2 cancel path bypassed**: in `dialog_buttons`, bind ESC to
  `[list destroy $w]` instead of `$cancelcmd`. All dismissal + state
  checks stay green; EXACTLY the record-cleaned checks of the
  record-carrying scaffold dialogs fail: GE2, GE3, GE4, GE6, GE8, GE9,
  GE10, GE12 (GE1 has no records and stays fully green). Proves the
  cleanup assertions are not hollow.
- **S3 chana.x cleanup dropped**: make `chana_x_cancel` destroy without the
  `array unset`. EXACTLY `GE5 anextra record cleaned` fails; everything
  else green.

## Commit — ONE commit, explicit file list

Stage EXACTLY these three files (re-verify each with
`git status --porcelain <file>` before staging; NEVER `git add -A`):

```
src/ase_window.tcl
tests/headless/test_ase_dialogs.tcl
doc/claude/specs/ase_l.md
```

Suggested message shape: `feat(ase): ESC dismisses every ASE-L dialog via
its cancel path` + a body naming the central helper, the dialog_buttons
constructor wiring, the four explicit sites, the chana.x cancel-path fix,
and the exemptions (main window, log window, sod untouched); end with the
repo's Co-Authored-By trailer. Do NOT push. Do NOT stage PLAN.md or any
pre-batch dirty file.

## Cautions

- Generated `<Key-Escape>` is focus-redirected under WSLg exactly like
  `<Return>` (receipts/06/07) — EVERY generated key goes through send_key's
  focus-gate + done-condition retry; never a bare `event generate`.
- GE legs must be mutation-free by construction — a stray state write flips
  the running serialize snapshots AND leaves the session dirty for the
  close leg; keep each leg's snapshot local to itself.
- `.chana.x` dies with `.chana` (Tk child); always ESC the subdialog FIRST
  in GE5, and re-open chana fresh via the strip if a prior leg left it up
  (dialog_frame catch-destroys on reopen — stale dialogs cannot collide).
- Do NOT bind ESC with `break` and do NOT touch the sod bindings or the
  addpin/addlabel shared `.drw <Key-Escape>` slot (xschem.tcl :10773-10782)
  — the canvas is not yours here.
- The confirm's ESC must not run `oncmd` — bind to the Cancel destroy, not
  to `confirm_ok`.
- test_ase_dialogs/test_ase_window inside PARALLEL audit runs are known
  WSLg flakes — rerun-first directly with DISPLAY before classifying
  anything as a regression.
- The GE16 self-SKIP arm is for a WSLg raise stall ONLY (select_on_design
  returning 0); if the mode arms, the ESC assertions MUST run — a skip
  there would hollow the regression leg.
