# Opening prompt for the next session (Phase 3d — d4: actions.csv unification + load-from-file remap)

Committed on branch `feature/action-registry`: 3a (wheel), 3b (right-drag zoom
gesture), 3c (context-routed keys — complete), 3d.1 (Tcl-command-backed actions; `B`
out), 3d.2 batches 1-3 (`H`, Alt-h, `y`,`G`,`g`,`T`,`O`, `A`,`L`,`=`,`$`), **3d.1b
(semaphore `idle_only`)** (`a`,`b`,`Ctrl+f`,`Ctrl+s` routing), **3d.2 sem-gated batches
1-3** (`n`,`U`,`u`; `k`,`K`; `j` branch), and **3d.3** (cheat-sheet generated live from
`xschem bindings dump`; `mods_name`/`parse_mods` now do Super).

Keys/chords out of the switch so far: **B, H, Alt-h, y, G, g, T, O, A, L, =, $, n, U,
k, K** (whole or branch), **u, j** (branch); plus graph routing for `f`/arrows/Group-B/
`t`/the 4 sem-first chords.

The clean sem-gated well is thin (remaining keys are dialogs / `semaphore`-manipulating /
unconditional — see SKIP/DEFER below). The recommended next move per the plan is **d4**.
Paste the block below into a fresh session.

---

```
Goal: implement d4 — make actions.csv the single source of truth for EVERY bound id, then
load bindings from a file at startup so users can remap by editing a file. Two atomic
steps (do d4a first):

  d4a (data + small reconcile): the cheat-sheet (d3) now shows several bound action ids
      with NO human label because they live only in the C registry, not actions.csv —
      that un-labeled list IS this work-item. Run the cheat-sheet
      (`generate_keybindings_text`) and add an actions.csv row for each id printed as a
      bare id: view.scroll_up/down/left/right, view.pan_up/down/left/right,
      view.zoom_full, view.zoom_rect, view.snap_half/snap_double, edit.toggle_stretch,
      view.toggle_show_netlist, view.toggle_draw_pixmap, edit.toggle_orthogonal_wiring,
      sch.edit_header, sym.attach_net_labels_to_component_instance,
      sym.make_schematic_and_symbol_from_selected_components,
      sym.create_symbol_pins_from_selected_schematic_pins, graph.forward (+ any others
      the dump shows id-only). Add an `idle` column to the csv schema (so the
      idle-ness is data too). RECONCILE the Z/view.zoom_in collision: the wheel binds
      view.zoom_in = view_zoom(CADZOOMSTEP) but the csv maps view.zoom_in→Shift+Z→
      view_zoom(0.0); give Shift+Z a DISTINCT id (e.g. view.zoom_in_center) so one id =
      one behavior. Keep the C registry ids and csv ids in agreement.
      Test: extend test_keybindings_help.tcl to assert NO bound row falls back to a bare
      id (every chord shows a label); test_palette/dump_file_menu still green.

  d4b (Tcl loader): read keybindings.csv / mousebindings.csv at startup (Tcl parses ->
      `xschem bind <device> <code> <mods> <ctx> <action> [idle]`), so editing a file
      remaps or un-binds defaults without recompiling. Seed the default files FROM the
      current built-in init_input_bindings table so behavior is identical when no user
      file is present. Test: a fixture rc that remaps + unbinds a key, asserting the
      live behavior follows (drive the key via `xschem callback`).

  NB the C side (`xschem bind/unbind/bindings`, idle) already exists — d4 is mostly
  Tcl + csv. If you'd rather keep migrating keys instead, see SKIP/DEFER below (all
  remaining sem-gated candidates are caveated); prefer d4 unless the user says otherwise.

Behavior-preserving, tested, small commits (split code vs docs). No pre-written plan —
scope it, write a short plan doc (mirror plan_phase3d2_semgated_batch3.md), implement.

WHAT d1b GIVES YOU (read claude_suggs/plan_phase3d1b_idle_only.md +
tutorial_action_registry_phase3d.md §d1b first):
- A binding can be idle_only: the DEV_KEY dispatch skips it when xctx->semaphore>=2,
  BEFORE current_input_ctx (so no waves_selected side effect while busy) — reproducing
  `if(sem>=2)break;`. Seed with set_input_binding_idle(...); or `xschem bind ... idle`.
- `bindings dump` appends " idle" to idle_only rows; the gate is testable via
  `xschem set semaphore <n>` + an observable action.
- So a sem-gated key whose branch is `if(sem>=2)break; <behavior>` migrates by: add an
  idle_only canvas row → <behavior's action> (C- or Tcl-backed), delete the whole case
  (or just the branch if other chords stay). If the key ALSO had a waves guard, add an
  idle_only over_graph→graph.forward row too (that's what the 4 sem-first chords did).

PRE-FLIGHT:
1. Re-grep callback.c line numbers (they shift every batch).
2. Re-run the cleanliness scan, but this time you WANT sem-gated branches. Find ones
   that are sem-gated and OTHERWISE clean (no mouse-coords mousex_snap|mx_double|
   infix_interface, no modal move_objects|new_*|place_|start_line|ui_state, no
   cadence_compat / other untable-able mode condition). Inspect each candidate as-is.
3. SKIP already-migrated (B,H,Alt-h,y,G,g,T,O,A,L,=,$,n,U,u,k,K,j and the routing-only
   a/b/Ctrl+f/Ctrl+s). DEFER anything cadence_compat-gated (plain s, Ctrl+r),
   param-dependent (`\` fullscreen uses win_path), or that manipulates the semaphore
   directly (q quit, o load, the e/I edit-in-new-window branches) until a mechanism
   exists.

STRONG CANDIDATES for batch 3 (verify against scheduler.c, don't trust) — sem-gated,
EXPLICIT mod guard, single-fn. The clean well is thinning; remaining decent ones:
  `j`/`J` (print_hilight_net — but `j`'s 4th branch `SET_MODMASK && state&ControlMask`
  is a FAMILY with no sem guard → `j` can only BRANCH-migrate plain/Ctrl/Alt and keep
  the case; `J`'s sole guard is `SET_MODMASK`, also a family → additive/branch),
  `Q` (plain edit_property(1) sem-gated, Ctrl edit_property(2) NOT — both DIALOGS; test
  via the gate, don't open them), `i`/`I` (descend_symbol etc. — but Ctrl/Alt branches
  are dialogs / semaphore-save; branch-migrate the clean plain one), `K`-like leftovers.
  Prefer reusing a csv Tcl id ONLY after verifying it equals the C branch incl. any
  redraw tail (the `e` trap: xschem descend ≠ the key's descend params; batch 2 verified
  every hilight cmd's redraw). Else write a C act.
  AVOID: `?`,`/`,`&`,`>`,`<`,`*`,`:`,`%`,`_` (UNCONDITIONAL — no mod guard — whole-delete
  changes modified-press behavior; additive-only).

If the clean well is genuinely thin, PIVOT to d3 (cheat-sheet from `xschem bindings
dump`): Tcl-side, no switch edits, low risk; it can flag idle_only chords and is the
right place to FIX the cosmetic `mods_name` Mod4/Super gap (dump prints Mod4 rows as
mods "0"; teach `mods_name` "super" and `parse_mods` "super"/"mod4" for round-trip).

BACKINGS: call the exact C fn the switch did (C-backed act) OR a global tcl command
string (Tcl-backed). For a tcleval branch, prefer Tcl-backed reusing an actions.csv id
if one exists (grep src/actions.csv); else coin a C id (fold into csv at d4). Don't swap
a C fn for its `xschem ...` Tcl equivalent unless verified identical.

TEST (extend tests/headless/test_key_graph_context.tcl):
- rows present (+ " idle" marker on the new idle_only rows; canvas-only keys have no
  graph row).
- the action fires when idle: observe its effect (tcl var flip, or stub a Tcl proc as a
  counter). For destructive canvas ops (dialogs), prove via the idle GATE on a probe
  like d1b did, or assert dispatch-without-error + rows.
- the idle GATE: `xschem set semaphore 2` → the migrated key does NOT fire; reset to 0 →
  it does. (Reset semaphore to 0 afterwards — leaving it high wedges later checks.)
- Re-run the full suite: engine run.sh 6/6, all GUI smokes green. Watch for older
  count/glob assertions tripped by new rows (narrow them, as every batch has).

Warm-start reads:
- CLAUDE.md; claude_suggs/refactor_plan_action_registry_phase3.md (d1b DONE, d2/d3/d4/d5)
- claude_suggs/plan_phase3d1b_idle_only.md (the gate; the cadence_compat deferral)
- claude_suggs/lessons_learnt_action_registry.md (THE cross-cutting lessons — read first;
  themed: behavior-preservation, the dispatch gate, exact-vs-family, idle_only, don't-swap-
  for-an-equivalent, testing, process. Append to it when a batch teaches something.)
- claude_suggs/tutorial_action_registry_phase3d.md (all d1/d2/d1b lessons, chronological)
- src/callback.c — RE-GREP: action_registry[] + find_action_def (~2325-2400); act_* fns
  above it; set_input_binding_idle + key_chord_is_idle_only (~2415-2455);
  init_input_bindings (~2435-2545); the DEV_KEY dispatch gate (~3095) — idle term is
  already folded into the `if(...)` condition there.
- tests/headless/run.sh (engine 6/6)

Gotchas (also project memory action-registry.md):
- GUI: DISPLAY=:0, capture with --pipe: `DISPLAY=:0 ./src/xschem --pipe -q --script FILE`.
  Drive events: `xschem callback .drw 2 <mx> <my> <keysym> 0 0 <state>` (KeyPress=2;
  Shift=1,Ctrl=4,Alt=8). kmods=(key<0xff00)?rstate:state; letters strip Shift.
- A migrated act() takes (const ActionEvent*e), ignores mouse ctx, must NOT read
  handle_key_press params — read the source (tcl var / xctx field).
- Whole-delete a case only when EVERY chord it handled is data-or-noop; else delete the
  branch and keep the case + break. For a sem-gated chord, the idle_only row replaces
  the `if(sem>=2)break;` — confirm the branch had NOTHING else before the break.
- Commit code and docs separately; don't push or do anything outward-facing without asking.

DoD:
1. Small sem-gated batch scoped + signed off + short plan doc.
2. idle_only rows added (canvas, + over_graph if it routed); cases whole-deleted where
   single-branch; acts match the originals exactly.
3. Verified empirically (effect or gate-via-semaphore probe); engine 6/6 + smokes green;
   test extended.
4. After it lands: update plan/tutorial/refactor-plan/memory and refresh THIS prompt.

Start with the pre-flight: re-grep, scan for clean sem-gated branches, propose the batch.
```

---

## Roadmap after this batch

- More sem-gated full-migration batches (the bulk of the remaining switch) until that
  well thins.
- **d3** cheat-sheet from `xschem bindings dump` (can now show `idle`).
- **d4** load `keybindings.csv`/`mousebindings.csv` at startup (incl. an `idle` column);
  **fold the C-only ids into `actions.csv`** (`edit.toggle_stretch`, `view.snap_half`,
  `view.snap_double`, `view.toggle_show_netlist`, `edit.toggle_orthogonal_wiring`,
  `view.toggle_draw_pixmap`); **reconcile `Z`/`view.zoom_in`** (wheel CADZOOMSTEP vs
  Shift+Z `view_zoom(0.0)` — distinct ids). Consider a `cadence_compat` axis so plain
  `s`/`Ctrl+r` can migrate.
- **d5** delete the dead switch ladders.

The running user-facing Q&A lives in `code_analysis/action_registry_faq.md` (stamped
with phase + HEAD); add to it when the user asks a keep-worthy question.
