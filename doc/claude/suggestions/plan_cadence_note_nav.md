# Plan — text-note-aware lib/hier nav (RED-first)

Spec: `doc/claude/specs/cadence_note_nav.md`. Pure Tcl; binds in
`src/cadence_style_rc`, procs in `utils/cadence_nav.tcl` + `utils/lib_mgr_helpers.tcl`.

Verified anchors (this session):
- Binds: `cadence_style_rc:102` (C-A-s → `locate_selected_in_libmgr`), `:106`
  (C-S-N → `cadence::open_inst_sch_readonly`), `:115/:117` (Alt-E/Alt-X), C-A-d FREE.
- `utils/lib_mgr_helpers.tcl:12` `locate_selected_in_libmgr`.
- `utils/cadence_nav.tcl`: `return_to_top:188` (sets `last_loc(<root>)`),
  `descend_to_last:218` (inline select/descend loop), `open_inst_sch_readonly:138`,
  `ascend_to_top`, `one_instance_selected`, `hier_instnames`.
- Primitives: `xschem get_inst_lcv`, `schematic_cellview`, `cellview_path`,
  `xschem library_manager {lib cell}`, `xschem load_new_window -window <f>`,
  `xschem set readonly 1`, `xschem get first_sel|lastsel`, `xschem text_string n`,
  `xschem text 1 x y r f {txt} {props} hs vs`, `xschem move_objects`,
  `enter_text` prefills from `tctx::retval` (xschem.tcl:34); `place_text` CLEARS it
  (actions.c:4049 — must mirror, not call).

Selection-state seam for tests/branching — a small helper:
`cadence::selkind {}` → returns `none` | `inst <n>` | `text <n> <string>` | `multi` |
`other`, from `lastsel`/`first_sel`/`text_string`. Pure-ish (reads engine, no mutate);
keeps each shortcut's branch one-line and gives tests a single thing to drive.

---

## Slice 1 — pure parse helpers + descend refactor + RED tests

GREEN-of-seam first, then a failing assertion list.

1. Add to `utils/cadence_nav.tcl`:
   - `cadence::first_libcell {text}` → `{lib cell}` | `{}` (regexp `(\w+)/(\w+)`, first).
   - `cadence::deeppath_from_text {text}` → list | `{}` (regexp `^\s*(\w+(?:/\w+)+)`,
     then `split / `).
   - `cadence::descend_instnames {names}` (extracted from `descend_to_last`; §5.1).
   - Rewrite `descend_to_last` to call `descend_instnames`.
   - `cadence::selkind {}` selection classifier.
2. RED test `tests/cadence_note_nav.tcl` (headless, self-asserting like
   `tests/buried_hilight.tcl`):
   - parse: `first_libcell "devices/res"`→`devices res`; `"see devices/res now"`→same;
     `"plain"`→``; `deeppath_from_text "Xamp/Xstage1/Xmir"`→`Xamp Xstage1 Xmir`;
     `"  a/b "`→`a b`; `"nope"`→``.
   - descend: build/load the 3-level fixture (reuse `tests/buried_hilight/` cells a/b/c/d
     or a dedicated `tests/cadence_nav/` with instance names `x_b x_c x_d`), then
     `cadence::descend_instnames {x_b x_c x_d}` and assert `xschem get sch_path` ==
     `.x_b.x_c.x_d.`; a bad name returns 0 and leaves a clean state.
   First run: parse procs don't exist yet → FAIL (RED). Then implement (1) → GREEN.

Fixture note: the existing `tests/buried_hilight/` already nests a.sch→x_b→x_c→x_d with
`type=subcircuit` cells — reuse it (the proc is library-path-agnostic). Source
`utils/cadence_nav.tcl` + its deps in the test preamble (mirror how xschem loads it; if
`ciw_echo` is undefined headless, define a stub in the test).

DoD: parse + descend assertions green; `descend_to_last` still works (engine shared).

---

## Slice 2 — CTRL-ALT-S locate (3 cases)

Rewrite `locate_selected_in_libmgr` (`utils/lib_mgr_helpers.tcl`) to branch via
`cadence::selkind`:
- `inst` → `xschem get_inst_lcv` → `xschem library_manager $lcv` (current path).
- `none` → `schematic_cellview [xschem get schname]` → `library_manager [lrange $lcv 0 1]`.
- `text` → `cadence::first_libcell` → `library_manager $lc` (or hint).
- else → hint.
Keep `ciw_echo` messaging. No headless assert (Tk) → manual GUI (Slice 6). Smoke: source
the file, call with nothing selected on a loaded lib cell, expect no error + a
`library_manager` call (can stub `xschem library_manager` in a smoke harness to capture
args).

DoD: builds/loads clean; arg-capture smoke shows the right lcv per branch.

---

## Slice 3 — CTRL-SHIFT-N open read-only (2 cases)

Extend `cadence::open_inst_sch_readonly`:
- `inst` → current behaviour.
- `text` → `cadence::first_libcell` → `xschem cellview_path "$lib/$cell" schematic`;
  if non-empty: `xschem load_new_window -window $f` → `xschem set readonly 1` →
  `after 120 [list force_window_repaint [xschem get current_win_path] 0]`; else hint.
- else → extended hint.
Factor the RO-open recipe into `cadence::open_file_readonly_newwin {f}` (shared, testable
arg-capture). Manual GUI verify.

DoD: arg-capture smoke shows the resolved file path + readonly call; GUI deferred.

---

## Slice 4 — CTRL-ALT-D round trip + bind

1. `utils/cadence_nav.tcl`: `cadence::deeploc_note`:
   - `none` → `last_loc(<win>)` empty? error : `join names /` → `cadence::place_note_prefilled $path`.
   - `text` + `deeppath_from_text` non-empty → `descend_instnames $names`.
   - text-but-not-path / other → hints.
2. `cadence::place_note_prefilled {txt}` — mirror `place_text` with the seed kept:
   set `tctx::retval`/`hsize`/`vsize`/`props`, `enter_text {text:} normal`, bail if empty,
   `xschem text 1 [xschem get mousex_snap] [xschem get mousey_snap] 0 0 $t $props $hs $vs`,
   select the new text (`xschem select text [expr {[xschem get texts]-1}]` — verify the
   `select text` subcommand; else select via the returned id), `xschem move_objects`.
3. `src/cadence_style_rc`: `bind .drw <Control-Alt-Key-d> {cadence::deeploc_note; break}`
   (add near the other cadence binds, with a comment).
4. Headless round-trip test (extends `tests/cadence_note_nav.tcl`): descend deep, ALT-E
   (`return_to_top`) to remember, ascend confirm at top; drive the *write* path without
   the GUI dialog/placement by calling a seam — split `deeploc_note`'s none-branch so the
   path string is produced by a testable `cadence::remembered_path {win}` and assert it
   equals `x_b/x_c/x_d`; then create a note with that text, select it, call the
   read-branch logic (`descend_instnames [deeppath_from_text ...]`) and assert sch_path.
   (The dialog+placement themselves are GUI-only; the path/parse/descend are asserted.)

DoD: round-trip parse+descend asserted headless; bind present; ALT-X unchanged.

---

## Slice 5 — wire-up sanity + regression

- `make` is irrelevant (Tcl only), but confirm the rc + utils load without error in a
  real `xschem --pipe` start (source check) and that no bind clobbers an existing one.
- Re-run the full `tests/cadence_note_nav.tcl` + `tests/buried_hilight.tcl` (untouched).

DoD: all headless suites green; clean load.

---

## Slice 6 — manual GUI verification + docs/memory

GUI checklist (spec §8) on real WSLg — gentle: ONE xschem session, clean exit, avoid
launch/kill churn. Capture a PNG or two where useful. Then:
- Mark spec acceptance; new memory `cadence-note-nav.md` + MEMORY.md line; link
  [[cadence-bindkeys]], [[library-manager]].

DoD: acceptance met; docs/memory updated.

---

## Risks / watch-items
- `place_text` clears `tctx::retval` — DON'T call it; mirror its body. (actions.c:4049)
- `xschem select text <n>` may not exist — verify; fall back to id-based select or the
  `move_objects` path that operates on the just-created+selected text (create_text via
  `xschem text` may already leave it unselected — select explicitly).
- `ciw_echo` undefined in a bare headless interp — stub in tests.
- Regex `\w` excludes vector `[..]` — documented limitation, keep.
- Don't change ALT-X semantics — only extract the shared engine.
- Same note string means different things under S/N vs D — by design (spec §6.1).
