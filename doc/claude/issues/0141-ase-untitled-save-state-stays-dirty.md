# 0141 — ASE-L: untitled session stays "(unsaved) *" after Session > Save State

**Status:** FIXED (not pushed)
**Branch:** fluid-editing
**Area:** ASE-L Save-As worker (`src/ase_window.tcl` `ase::ui::do_save_state_as`) +
session model (`src/ase.tcl` new `ase::session_adopt`). Spec `doc/claude/specs/ase_l.md`.
**Reported by:** user, 2026-07-25.
**Test:** `tests/headless/test_ase_savestate_adopt.tcl` (26 checks; Part A headless core,
Part B DISPLAY-guarded open-window title/status reproduction).

## Symptom

Launch ASE-L (Tools > Launch ASE-L) → an **untitled** session (title
`Analog Sim Environment <cell> (unsaved)`). Make a change (edit a variable, enable an
analysis, add an output) → title gains the ` *` dirty marker. Choose **Session > Save
State**, pick a view, save. The state **file is written correctly**, but with the window
kept open the title **still shows `(unsaved) *`** and the status bar still reads
`State: (unsaved)` — the session reads as never-saved / modified forever. A second Save
State never clears it either.

## Root cause

An ASE session's dirty flag (`ase::session_dirty`, `src/ase.tcl:530`) is
`state_serialize(state) != state_serialize(saved)`; the title/status
(`refresh_title` `src/ase_window.tcl:2649-2650`, `refresh_status`) append `(unsaved)` from
the `untitled` attr and ` *` from `session_dirty`.

Launch ASE-L builds an **untitled** session (`ase::new_session`, `src/ase.tcl:698`):
`path {}`, `saved == state`, attr `untitled 1`.

Session > Save State → `save_state_ok` → `ase::ui::do_save_state_as`. It computes
`own = session_path` (=`{}` for untitled) and `target = cellview_path`. The
own-view arm (`[file normalize $target] eq [file normalize $own]`) calls
`ase::session_save`, which sets `saved <- state` and clears dirty. But for an untitled
session `own eq {}`, so it **always** falls to the else-branch, which writes the file via
`state_save` and then **never updates `saved`, never clears the `untitled` attr, never sets
the session `path`**. So `session_dirty` stays 1 and `untitled` stays 1 → the still-open
window keeps `(unsaved) *`.

(An opened-from-file session saving to its own view was unaffected — it has a non-empty
`path`, so it takes the own-view `session_save` arm and clears correctly. The bug is
untitled-only, i.e. the common Launch → edit → save flow.)

## Fix

Adopt-in-place (**not** a re-key). New `ase::session_adopt {key newpath}` (`src/ase.tcl`,
after `session_save`): `path <- newpath`, `saved <- state` (clears dirty), `untitled <- 0`,
fire notify. `do_save_state_as` calls it **gated on `own eq {}`** (the untitled marker),
after a guaranteed-successful write, and first updates `meta[$key]` to `[list l c v]` so
`refresh_status` shows the real `State: <view>` and the next Save-As prefill is correct.

The session **key is deliberately left unchanged** (`lib/cell/(unsaved)`). Re-keying to the
saved view was rejected: `ase::ui::open` (`src/ase_window.tcl:200`) bakes the literal `$key`
into `WM_DELETE_WINDOW`, `Ctrl-W`, and ~91 menu/`-command`/`bind` scripts across `build()`
(plus the sod canvas rebinds and the wviewer token) — a re-key would zombie the window
(every menu/button hits `![dict exists $wins $key]` and no-ops) unless the whole widget tree
is re-walked and ~13 dicts/arrays relocated. It would also break the close-path callers
(`save_state_modal` → `ase::ui::close $key`, `prompt_all_on_quit`) that hold the pre-save
key (DR9 landmine). The key is an opaque handle — nothing parses it, and Launch dedup
(`ase::session_for_design`) matches on `state.design`, not the key — so keeping the
synthetic key is invisible and safe.

Gating on `own eq {}` preserves both deliberate behaviors: a **titled** session saving-as to
a **different** view still stays dirty (item 14 D5, `src/ase_window.tcl:2519-2531`), and the
own-view save (first arm) is untouched.

### Deferred (pre-existing, not a regression)

After adopt-in-place, a later LibMgr/hi_descend open of the now-real `ngspice_state1` view
computes a different key and could spawn a **second** session on the same file. Re-key would
have prevented this, but the collision already exists in the current design and is out of
scope for the reported "shows modified after save" bug.

## Verification

- `test_ase_savestate_adopt.tcl` RED before the fix (AD7/AD8/AD9/AD9b — the exact adopt
  fields — fail; the empty `path` even errors AD9c), GREEN after (26/26).
- No regressions: `test_ase_dirty` 41, `test_ase_dialogs` 133, `test_ase_launch` 38,
  `test_ase_interact` 29, `test_ase_window` 155 — all pass. The titled-different-view
  stays-dirty legs (dialogs H3/H4, interact WF), own-view save (window W3, dialogs G7/G8),
  and the close/quit dirty-prompt flow (dirty DR8-DR14) are all preserved.

## Files

- `src/ase.tcl` — new `ase::session_adopt`.
- `src/ase_window.tcl` — `do_save_state_as`: `variable meta` + untitled-adopt block +
  header comment; `viewer_snapshot` D5 note carve-out.
- `tests/headless/test_ase_savestate_adopt.tcl` — new (auto-discovered by `full_audit.sh`).
- `doc/claude/specs/ase_l.md` — Save State adopt contract.
