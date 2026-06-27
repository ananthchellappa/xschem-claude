# Phase 3d.4b — load keybindings.csv / mousebindings.csv at startup

**Status:** DONE (commit `99564587`). **Branch:** `feature/action-registry`.
**Predecessor:** d4a (`7cb366f1`, actions.csv labels every bound id).

## Goal

Users remap (or un-bind) any default key/wheel/button chord by **editing a file**,
no recompile, no GUI: `keybindings.csv` / `mousebindings.csv` rows are replayed
through the existing `xschem bind`/`xschem unbind` at startup. The C side is done
(d1–d3); this is Tcl + two generated data files.

## Design

- **File format** = the `xschem bind` token vocabulary, one row per chord:
  `device,code,mods,ctx,action,idle` — device `key|wheel|button`; code = X keysym
  number / button number / `up|down`; mods `0` or `ctrl|alt|shift|super` joined by
  `+`; ctx `canvas|graph|global`; idle `1` = idle-gated. **action `-` = un-bind
  the chord.** Same RFC4180 parser as actions.csv (`action_parse_csv_line`).
- **Loader** (`action_registry.tcl`): `load_input_bindings_file <path>` replays
  rows (bad rows warn to stderr, never abort startup); `load_input_bindings` runs
  the share-dir defaults then `$USER_CONF_DIR` copies — later loads override, so
  a user file wins over the shipped defaults.
- **Call site:** `xschem.tcl` top level, right after `load_action_table`. The
  `xschem` command is registered (xinit.c:2845) before xschem.tcl is sourced
  (:2883), and `xschem bind` needs no xctx (ensure_input_bindings only).
  Note xschemrc is sourced even earlier (:2742) — *before* the `xschem` command
  exists — so the file loader cannot clobber an rc-file remap; these files ARE
  the supported file-remap mechanism.
- **Seeded defaults:** `save_input_bindings_file <path> <devices>` writes the
  LIVE table (`xschem bindings dump`) in loader format — the generator for the
  shipped `src/keybindings.csv` (key rows) and `src/mousebindings.csv`
  (wheel+button rows). Defaults == builtins → loading them is a no-op re-bind;
  behavior is identical when no user file exists. Regenerating after a C-table
  change is one proc call; the smoke test diffs the shipped files against a fresh
  save, so silent drift fails the suite (the "view reads the truth" lesson).
- **Install:** add the two csv files to Makefile.in `install_shares` (precedent:
  actions.csv; the generated src/Makefile is stale and regenerates on configure).

## Test (`tests/headless/test_bindings_file.tcl`)

1. Shipped defaults are faithful: fresh `save_input_bindings_file` output ==
   committed share files (drift guard).
2. Re-loading the share defaults is a no-op (dump before == after).
3. Fixture file: binds key 96 (`` ` ``, the d1b safe probe) to
   `edit.toggle_stretch` with idle, and un-binds `y` (action `-`). After
   `load_input_bindings_file`: rows present/absent in the dump, **live behavior
   follows** — backtick press flips `enable_stretch`, `y` press no longer does
   (case 'y' was deleted from the switch, so unbound = inert).
4. Bad rows (unknown action / device) warn but don't abort; table restored to
   defaults afterwards (sorted-dump == baseline).

## Non-goals

- No C changes. No per-event Tcl (files are replayed once at startup).
- No GUI editor (a future "customize shortcuts" dialog would write these files).
