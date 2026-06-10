# Opening prompt for the next session (Phase 3d — d5: retire the Phase-2 Tk intercept; dead-remnant audit)

Goal: Phase 3d.5 — retire the Phase-2 Tcl keyboard interception so ONE mechanism (the
C binding table) owns every key, then audit/delete dead remnants. d4 is DONE (d4a
`7cb366f1` csv single-source, d4b `99564587` file loader): every bound id has a csv
label, and keybindings.csv/mousebindings.csv remap/un-bind chords at startup.

  d5a (recommended first): RETIRE THE PHASE-2 TK INTERCEPT. `migrated_action_ids`
      (action_registry.tcl) still Tk-binds u/U/Shift+Z/Ctrl+Z via
      bind_accelerators_from_table — a Tk binding with a key detail PRE-EMPTS the
      generic <KeyPress>, so in the real GUI those four chords never reach the C
      dispatch (the C rows for u/U added in sem-gated batch 1 are shadowed; worse, the
      Tk path has NO idle gate, so `u` during a busy engine runs `xschem undo` where
      the C row would be skipped — a real behavior divergence between mechanisms).
      Plan: (1) seed C rows for the two zoom chords — key 90 (Z; Shift folds into the
      keysym for letters) mods 0 canvas -> view.zoom_in, and key 122 mods ctrl canvas
      -> view.zoom_out; d4a PROVED view_zoom(0.0) == view_zoom(CADZOOMSTEP) so the csv
      commands and C acts are identical (one id, one behavior — see
      plan_phase3d4a_csv_single_source.md "Reconciles" §2). VERIFY first what case
      'Z'/'z' in the switch do with those exact chords (delete or keep per the
      exact-vs-family rule; also re-read `xschem zoom_out` = view_unzoom(0.0) ==
      act_zoom_out anyway). (2) empty migrated_action_ids (keep the Phase-2 machinery
      procs — bind_accelerators_from_table/remap_action_accel are tested and become
      no-ops over an empty list). (3) rewrite/retire test_remap + test_accelerators:
      their job flips from "Tcl intercept works" to "NO Tk key-detail binding shadows
      the C table"; remap coverage lives in test_bindings_file. (4) u/U regain their
      idle gate in the real GUI for free — assert no Tk binding exists for <Key-u> so
      the C path must serve it.

  d5b (audit, small): grep for dead/duplicated remnants the migrations left behind —
      e.g. the Button2 special-casing noted at Phase 3b (callback.c skip logic),
      keys.help vs the generated cheat-sheet (two help texts; consider pointing the
      old Help menu entry at show_keybindings_help or just note the overlap), comments
      referencing already-deleted cases. Delete only what is provably dead.

  AFTER d5: the well of clean key migrations is dry. Remaining un-migrated chords are
  structurally parked: dialogs (Q edit-attrs, i/I insert-sym), semaphore-manipulating
  (q quit, o load, e/I new-window branches), unconditional symbol keys
  (&/>/</?/:/%/_/* — additive-only), cadence_compat-gated (plain s, Ctrl+r — need a
  mode axis the plan explicitly resists; revisit only on a concrete user ask).
  Candidate new directions (ask the user): generate more menus from actions.csv (only
  File is), an `xschem action <id>` dispatcher so label-only rows become
  palette-runnable, or a customize-shortcuts dialog writing keybindings.csv.

Behavior-preserving, tested, small commits (split code vs docs). Scope -> short plan
doc (mirror plan_phase3d4a/b) -> implement.

PRE-FLIGHT:
1. Re-grep callback.c line numbers (they shift every batch).
2. Read case 'Z' and case 'z' in handle_key_press as they are NOW; verify which exact
   chords they serve and whether Shift+Z / Ctrl+z are exact (deletable) or families.
3. Read bind_accelerators_from_table + accel_to_tk_sequence + test_remap +
   test_accelerators BEFORE emptying migrated_action_ids — know exactly what each
   test asserts so the rewrite keeps real coverage.
4. Check whether the Z/z switch branches have `if(sem>=2)break;` — if yes the new
   rows must be idle_only (and the Tk intercept's missing gate was a second
   divergence worth recording).

BACKINGS: reuse csv ids view.zoom_in / view.zoom_out (C-backed acts already in the
registry, proven == the csv commands). Don't coin new ids.

TEST (extend test_key_graph_context.tcl or a new smoke):
- rows present for the new chords; cases deleted/kept per exact-vs-family.
- live: Shift+Z via `xschem callback` divides zoom by 1.2 (zoom-toward-mouse), Ctrl+z
  multiplies; u/U still undo/redo via callback at sem=0, skipped at sem=2 (reuse
  batch-1's instance-count pattern).
- after emptying migrated_action_ids: `bind .drw <Key-u>` etc. return EMPTY (no Tk
  shadow); the cheat-sheet is unchanged (it reads the dump).
- engine run.sh 6/6 + ALL smokes incl. test_bindings_file. NB: regenerate
  keybindings.csv via save_input_bindings_file after seeding the new rows — the
  drift guard WILL fail until you do; that is it working, not a flake.
- Watch for older count/glob assertions tripped by new rows (every batch narrows one).

Warm-start reads:
- CLAUDE.md; claude_suggs/refactor_plan_action_registry_phase3.md (d4 DONE, d5 last)
- claude_suggs/lessons_learnt_action_registry.md (READ FIRST — themed lessons; note
  the new d4 entries: a deferred "collision" is a hypothesis too, drift-guard for
  generated defaults, label-only rows, idle in two layers, xschemrc ordering)
- claude_suggs/plan_phase3d4a_csv_single_source.md + plan_phase3d4b_bindings_file_loader.md
- claude_suggs/tutorial_action_registry_phase3d.md (d1..d4 chronological)
- src/action_registry.tcl — migrated_action_ids (~l.168), bind_accelerators_from_table,
  load/save_input_bindings_file (d4b), generate_keybindings_text
- src/callback.c — action_registry[] + init_input_bindings (re-grep; ~2325-2600)
- tests/headless/run.sh; test_bindings_file.tcl (the drift guard)

Gotchas (also project memory action-registry.md):
- GUI: DISPLAY=:0, capture with --pipe: `DISPLAY=:0 ./src/xschem --pipe -q --script F`.
  Drive events: `xschem callback .drw 2 <mx> <my> <keysym> 0 0 <state>` (KeyPress=2;
  Shift=1,Ctrl=4,Alt=8). kmods=(key<0xff00)?rstate:state; letters strip Shift -> the
  Shift+Z chord is keysym 90 ('Z') with mods 0; Ctrl+z is keysym 122 mods ctrl.
- `xschem callback` BYPASSES Tk bindings — it proves the C path, NOT the Tk
  shadowing. The shadowing claim needs `bind .drw <seq>` introspection (or Tk
  event generate, which is flaky headless — see test_palette).
- The shipped keybindings.csv/mousebindings.csv are GENERATED; after ANY
  init_input_bindings change run save_input_bindings_file for {key} and
  {wheel button} and commit the regenerated files.
- Whole-delete a case only when EVERY chord it handled is data-or-noop; else delete
  the branch and keep the case + break.
- Commit code and docs separately; don't push or do anything outward-facing without
  asking.

DoD:
1. d5a scoped + signed off + short plan doc; one mechanism per key in the real GUI.
2. New zoom rows seeded (+ regenerated keybindings.csv); migrated_action_ids empty;
   Phase-2 tests rewritten to assert the new invariant (no Tk shadows).
3. Verified empirically (live zoom/undo behavior + bind introspection); engine 6/6 +
   all smokes green.
4. Docs chain updated (plan/tutorial/refactor-plan/memory) + refresh THIS prompt.

Start with the pre-flight: read case Z/z and the Phase-2 test pair, then propose the
d5a plan.
