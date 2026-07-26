# Item 17 — dp-open-race (ROUND 5, Waveform Viewer interaction fixes)

Branch: fluid-editing. Repo root: /home/qflow/dev/xschem/claude_1/xschem.
Pure Tcl, zero C changes expected. NEVER push. ONE feature commit with an
explicit file list.

READ FIRST (in order): doc/claude/ase_l_batch/RUNBOOK.md (policies verbatim at
the bottom of this prompt), doc/claude/specs/ase_l.md, doc/claude/specs/
waveform_viewer.md ("Item 13 notes" + "Item 14 notes"), and the receipts
receipts/11_viewer-window.md + receipts/13_ase-plot.md (the auto_plot `after
idle` landmine is directly relevant).

---

## USER BUG (verbatim intent)

Results > Direct Plot the FIRST time launches a viewer window that then
VANISHES; only the SECOND Direct Plot makes the Graph Window appear. Fix the
open race so the first Direct Plot opens exactly ONE viewer that STAYS VISIBLE.

Scope = the OPEN RACE ONLY. Do NOT touch graph-fills-window (item 18) or
interaction rebinding (item 19).

---

## Corrected anchors (scout re-verified 2026-07-22 — lines are current HEAD)

### src/ase_window.tcl
- `ase::ui::direct_plot` proc **@1450**; body = `select_on_design $key
  {save 0 plot 1} plot` @1451. (Results > Direct Plot entry invokes this.)
- `ase::ui::select_on_design` proc **@1253**; calls `design_window $key`
  @1256; seizes the design-canvas bindings @1270-1274 (`<ButtonPress-1>`,
  `<ButtonRelease-1>`, `<Key-Escape>` = `"[list ase::ui::sod_end $key]; break"`).
- `ase::ui::sod_end` proc **@1294**; restores the 3 bindings @1298-1300;
  plot-mode branch @1310-1314 → **`ase::ui::dp_finish $key $queue` @1312** then
  `return`.
- `ase::ui::sod_click` proc **@1333**; plot routing `dp_queue` **@1367-1368**.
- `ase::ui::dp_finish` proc **@1420-1445**; op-only gate @1423-1425;
  **`wviewer::open $key` @1427**; `last_rawfile`+`attach_raw` @1431-1433;
  `add_graph` @1439; `add_trace` loop @1441-1443.
- `ase::ui::open_viewer` (the `~` strip button) proc **@1456**;
  `catch {wviewer::open $key}` @1457.
- `ase::ui::auto_plot` proc @2887; **`wviewer::open $key` @2910**.
  `auto_plot_idle` @2942; `run_finished` schedules it via **`after idle`
  @2971** (the established deferral — see receipt 13 landmine #1).
- `ase::ui::design_window` proc @2692; `raise_design_editor` @2698/@2708;
  `after 120 [list force_window_repaint ...]` @2710 — **only in the
  design-not-already-open branch** (so the common repro, where the design
  window is already up, does NOT schedule it).
- `ase::ui::window_for` @191 (session window; test helper).

### src/wave_viewer.tcl
- `wviewer::window_for` @167; `wviewer::forget` @186-207 (the registry/
  layout/cursor teardown).
- **`wviewer::open` proc @213-297** — THE fix site. Two arms:
  - unknown-session guard @217-222; `has_x` guard @223.
  - **RE-OPEN arm @226-234**: `if {[dict exists $windows $token]}` →
    `if {[winfo exists $top]}` → **`raise_activate_toplevel $top` @229 +
    `catch {focus $top}` @230 + `return 1` @231**; stale entry →
    `wviewer::forget $token` @233 (falls through to fresh build).
  - **FRESH arm @235-296**: `xschem load_new_window -window {}` @238;
    `current_win_path` @239; `xschem set readonly 1` **@246** (item brief
    said :245 — off by one); `dict set windows` @247; `build_menubar` @248;
    `strip_bindings` @249; `pack forget $top.toolbar` @263; model/cursor
    init @264-272; readout bar @273-283; `<ButtonRelease>` bind @290;
    `retitle` @291; `<FocusIn>` bind @292; `<Destroy>` bind @295;
    **`return 1` @296**. **NO `raise_activate_toplevel`, NO `focus`, NO
    `deiconify` anywhere in the fresh arm** — this asymmetry is the root
    cause (see below).
- `wviewer::restore` proc @715; `wviewer::open $token` @718 (item-14 relaunch
  / Load-State / LibMgr-open-of-a-viewer-state path).
- `raise_activate_toplevel` (src/xschem.tcl @5526-5540): mapped → withdraw+
  deiconify (WSLg re-map, issue 0054); not-yet-mapped → deiconify; then
  `raise` + `activate_window`. Safe to call on a freshly-created window
  regardless of map state.

---

## ROOT CAUSE — scout reproduction + evidence (deliverable 1: REPRODUCE FIRST)

**Confirmed by direct probing at HEAD** (scratch repro, DISPLAY=:0/WSLg, dc-sweep
session with `outputs plot 0` so Direct Plot is the FIRST viewer open; ngspice
NOT needed — a dc-enabled analysis makes `dp_finish` pass the op-only gate and
open the viewer even with no run):

1. `wviewer::open` has TWO arms. The RE-OPEN arm (wave_viewer.tcl:229-230)
   brings the existing viewer to front the WSLg-honored way (`raise_activate_
   toplevel` = withdraw+deiconify re-map, issue 0054). The FRESH arm (235-296)
   creates the window via `load_new_window` and **never raises/focuses it** —
   it relies purely on `load_new_window`'s natural first map.
2. At Direct Plot mode entry, `select_on_design`→`design_window` raises the
   DESIGN window to the FRONT (`raise_activate_toplevel`). So when the FIRST
   Direct Plot's ESC → `sod_end`(@1312) → `dp_finish`(@1427) → `wviewer::open`
   creates the viewer, under interactive WSLg the fresh viewer maps BEHIND the
   just-raised design window (WSLg applies stacking only at map time and ignores
   post-map `raise`; issue 0054) and never comes forward → the user sees
   "launch then VANISH" (created-but-stacked-under, NOT destroyed). The SECOND
   Direct Plot hits the RE-OPEN arm, whose withdraw+deiconify re-map WSLg DOES
   honor → the viewer "appears."
3. **The window is NOT destroyed.** Scout repro confirmed `winfo exists`=1 and
   the registry entry survives; it is purely a stacking/visibility failure.

**Honest reproduction caveat (MUST be stated in the receipt):** under SCRIPTED
Tk with heavy `update`/`after` pumping (the focus-gated real-ESC loop), the
first fresh viewer maps top-of-stack and the symptom does NOT manifest — i.e.
the vanish is an INTERACTIVE WSLg stacking race that a headless/scripted driver
cannot faithfully reproduce (scout's two scripted runs both showed the first
viewer top-of-stack + mapped; the transient flicker actually appeared on the
SECOND/re-open arm's withdraw+deiconify). Therefore: (a) the implementer MUST
reproduce INTERACTIVELY in the real GUI and document the exact click→ESC→vanish
→2nd-time-appears sequence in the receipt; (b) the automated test asserts the
open-race INVARIANT (exactly one live viewer that STAYS; second raises the SAME
one), and the raise-fix's user-facing correctness is argued from the interactive
reproduction + the 0054 asymmetry above + code review.

---

## THE FIX (deliverable 2)

### Required — symmetric raise in the fresh-open arm
Make the FRESH arm of `wviewer::open` finish by bringing the new viewer to the
front the WSLg-reliable way, exactly as the re-open arm does. Immediately before
`return 1` @296, add:

```tcl
raise_activate_toplevel $top
catch {focus $top}
```

Rationale: unifies both arms so EVERY open path (dp_finish, `~`/open_viewer,
auto_plot, restore) ends front-and-focused; a viewer that just opened should be
in front. `raise_activate_toplevel` handles both the mapped and not-yet-mapped
cases (xschem.tcl:5530-5537), so it is safe on a window `load_new_window` may
have mapped asynchronously. This is additive: no caller wants a viewer opening
behind, so it does not regress `~`, LibMgr/restore, or auto-plot — it improves
them (all four funnel through this one arm; scout verified the caller set:
wave_viewer.tcl:718, ase_window.tcl:1427/1457/2910).

### Optional — defer dp_finish out of the ESC-event context (adopt ONLY if the
### interactive reproduction shows raise-alone is insufficient)
`dp_finish` runs SYNCHRONOUSLY inside the `<Key-Escape>` binding on the design
canvas (sod_end@1312). Receipt 13's landmine #1 established that viewer/context
ops from an event/semaphore context misbehave and were deferred via `after idle`
(auto_plot_idle@2942, run_finished@2971). If (and ONLY if) reproduction proves
the raise alone does not make the first viewer stay-in-front, defer the open:
schedule `dp_finish` from `sod_end`'s plot branch via `after idle [list
ase::ui::dp_finish $key $queue]` (the queue is captured; the mode records are
already wiped before it fires — mode fully exited first). **If you adopt
deferral you MUST update the EXISTING test_ase_plot P4/P6 assertions**, which
read the viewer graph list immediately after the real-ESC loop (before an idle
flush) — add a bounded poll / `update idletasks` so they wait for the deferred
`dp_finish` (justify in the receipt; the item note permits assertion updates).
Prefer raise-alone if it fixes the symptom — it has zero test ripple.

### Do NOT
- Do NOT change `design_window`'s raise (item-08 behavior).
- Do NOT weaken the re-open (raise-not-duplicate, item 13) arm.
- Do NOT touch graph-fills-window (item 18) or interaction rebinding (item 19).
- Do NOT edit generated files or any pre-existing dirty tracked file.

---

## TESTS (deliverable 3)

Add a NEW phase to **tests/headless/test_ase_plot.tcl** (DECISION: this suite
already owns the clone fixture, the Direct Plot flow, and the helpers
`main_ready`/`viewer_ready`/`toplevel_count`/the focus-gated real-ESC loop; the
bug is in the ASE Direct-Plot→wviewer::open path this suite covers). Do NOT
create a new test file; do NOT register anything in tests/run_regression.tcl
(pre-batch dirty — full_audit.sh auto-discovers `test_*.tcl`).

**Placement + fixture:** put the phase AFTER P7 (which closes the session +
viewer) so it opens a genuinely FRESH session whose viewer has NEVER opened —
this is the ONLY way to exercise the fresh arm. Gate it on `mainok` (has_x)
**independently of `have_ng`** (the open-race needs no ngspice: reshape the
clone state to `dc enabled 1` + every output `plot 0`, do NO run; `dp_finish`
opens the viewer for a dc sim_type regardless of a raw). Reuse the existing
`viewer_ready`/`toplevel_count` helpers; add a `viewer_tops`-style helper only
if needed. Deliver ESC via the SAME focus-gated `event generate <Key-Escape>`
retry loop P4 uses (gesture-test-full-sequence lesson — a lone synthetic ESC is
green-but-hollow).

**Named checks (phase prefix e.g. `P8`):**
- `P8 fresh session has NO viewer yet` — `wviewer::window_for $key` eq {}
  (baseline before the first Direct Plot; record `set N0 [toplevel_count]`).
- `P8 first Direct Plot opened a viewer` — after the first Direct Plot +
  settle: `wviewer::window_for $key` ne {} AND `winfo exists` that toplevel.
- `P8 first viewer mapped` — `viewer_ready $vtop` == 1 (polls up to ~6s).
- `P8 exactly ONE new toplevel` — `toplevel_count` == `N0 + 1` (no orphan /
  no second viewer window).
- `P8 first viewer STAYS` — poll `winfo exists`+`winfo ismapped` across a
  settle window (e.g. 40×25 ms); assert it is exists+mapped at the END of the
  settle (a transient unmap during a withdraw/deiconify re-map is tolerated,
  a persistent gone/unmapped is a FAIL).
- `P8 first viewer top of stackorder` — `[lindex [wm stackorder .] end]` eq
  `$vtop` (the raise-fix end-state; see the honest caveat — in scripted timing
  this may already hold pre-fix, so it is a REGRESSION guard, and sabotage S3
  below gives it teeth).
- `P8 second Direct Plot raises the SAME viewer` — capture `set vtop1 $vtop`;
  after a second Direct Plot + settle: `wviewer::window_for $key` eq `$vtop1`
  (raise-not-duplicate, item 13).
- `P8 second Direct Plot added no new toplevel` — `toplevel_count` == `N0 + 1`
  (unchanged; count STAYS 1 viewer).
- `P8 second viewer still exists+mapped` — `winfo exists`+`ismapped` of
  `$vtop1`.

Clean up the phase's scratch (the suite already deletes `_ase_plot_*`); close
the session/viewer at the end.

**Protected suites that MUST stay green (direct re-run, correct invocation
`--pipe -q --nolog --script` + DISPLAY):** test_ase_plot (your suite),
test_wave_viewer, test_ase_core/view/window/dialogs/final/interact/persist/
launch/dirty. The added fresh-arm raise (withdraw+deiconify) introduces a
per-open flicker that these suites' open/reopen legs must tolerate — re-run
test_wave_viewer + test_ase_plot P3/P5/P6 and confirm green (their mapped
polls already absorb a transient unmap). Any assertion you flip must be
justified in the receipt.

### Sabotage plan (>=2; each `git diff`-confirmed sabotage-only, targeted
### `git checkout -- <file>` revert after diff, clean re-run green)
- **S1 (mandatory) — open suppressed:** in `dp_finish`, force the open to fail
  (e.g. replace `wviewer::open $key` @1427 with `expr 0`, or `return` before
  @1427). Target: `P8 first Direct Plot opened a viewer` + `P8 first viewer
  mapped` + `P8 exactly ONE new toplevel` + the second-plot checks FAIL; the
  earlier PH/P1-P7 legs stay green.
- **S2 (mandatory) — raise-not-duplicate broken:** comment out the RE-OPEN arm
  (wave_viewer.tcl:226-234) so `wviewer::open` ALWAYS builds fresh. Target: the
  SECOND Direct Plot creates a NEW toplevel → `P8 second Direct Plot raises the
  SAME viewer` + `P8 second Direct Plot added no new toplevel` FAIL; the FIRST
  open legs (P8 first*) stay green (and P5 `~`-same-viewer also breaks — note
  it, it is the same invariant).
- **S3 (recommended) — top-of-stack teeth:** at the end of the fresh arm (after
  the new raise), add a line that raises the ASE/design window back over the
  viewer (e.g. `raise_activate_toplevel .` or the design top). Target: `P8
  first viewer top of stackorder` FAILS deterministically; the exists/mapped/
  count legs stay green — proving that check can detect a behind-viewer.
- **S3-alt (recommended) — "stays" teeth:** in the fresh arm just before
  `return 1`, add `catch {xschem new_schematic destroy $wp}` (simulate the
  vanish). Target: `P8 first viewer STAYS` (and/or `winfo exists`) FAILS.

Pick S1 + S2 at minimum; add S3 or S3-alt so at least one sabotage witnesses a
fix-related end-state.

---

## Explicit commit file list (stage ONLY these; `git add <path>` each — NEVER
## `git add -A`/`-a`)
- `src/wave_viewer.tcl`   (fresh-arm raise fix)
- `tests/headless/test_ase_plot.tcl`   (new P8 open-race phase)
- `src/ase_window.tcl`   **ONLY IF** you adopt the optional dp_finish idle
  deferral (and only then, with the P4/P6 settle updates)

Do NOT stage `doc/claude/specs/waveform_viewer.md` (untracked; rides with the
ledger/spec commit per receipt 13's note). Do NOT stage any pre-existing dirty
tracked file (list below). Verify `git status` before committing: only the
declared files staged, no `_allm_*`/`_ase_*`/`_nhangle_*`/junk dirs, no
generated file. Commit message: normal prose + the Co-Authored-By trailer per
repo convention.

**Pre-existing dirty tracked files — NEVER stage (from PLAN.md preflight):**
`doc/claude/specs/sky130_workarea.md`, `sky130A/xschem_libs/library.defs`,
`src/ciw.tcl`, `tests/headless/test_sky130a_libmgr.tcl`,
`tests/run_regression.tcl`,
`xschem_libs_newsym/SANDBOX/solar_ctl/symbol/solar_ctl.sym`,
`xschem_libs_newsym/SANDBOX/test_hier_descend_etc/schematic/test_hier_descend_etc.sch`.

**Baseline full_audit fails (tolerated, NOT yours; compare LIST EQUALITY, any
NEW fail is a regression):** test_altf5_ciw, test_cadence_descend_newwin_ro,
test_cadence_drag, test_cadence_window_hop_log, test_ciw, test_crossview_paste,
test_fluid_editing, test_hi_descend, test_launch_context, test_lib_manager_gui,
test_lib_sweep, test_palette, test_phase3_mints, test_pin_type_edit,
test_reopen_readonly, test_select_at, test_selflog_output,
test_verb_noun_copy_move, test_wire_split, test_wire_vertex_grab; TIMEOUT:
test_key_graph_context. Known WSLg flakes (NOT regressions if a direct re-run
passes): test_deselect_mode, test_hover_highlight, test_ase_window/test_ase_dirty
in PARALLEL audits (rerun-first).

---

## RUNBOOK policies (non-negotiable — copied verbatim from
## doc/claude/ase_l_batch/RUNBOOK.md)

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
