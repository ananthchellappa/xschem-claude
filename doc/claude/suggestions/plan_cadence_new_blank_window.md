# Plan — Ctrl-N → new blank window (RED-first)

Spec: `doc/claude/specs/cadence_new_blank_window.md`. Pure Tcl: one helper
(`utils/cadence_nav.tcl`) + one bind (`src/cadence_style_rc`).

Verified anchors (this session):
- Primitive: `xschem new_schematic create_window {}` → new top-level window, blank
  `untitled.sch`, current window switches to it; original window intact
  (`new_schematic`/`create_new_window`, xinit.c:2359/1725; `load_schematic(1,"",…)`:1827;
  `clone_canvas_bindings .drw <new>`:1832).
- Default Ctrl-N today: `keybindings.csv:47`, `callback.c:3053` → `file.clear_schematic`
  = `xschem clear schematic` (destructive, in-place). Stays on File menu (`actions.csv:38`).
- Bind override precedent: cadence_style_rc `bind .drw <Control-Shift-Key-N> {… ; break}`
  etc. override C-table defaults; the specific `<Control-Key-n>` wins + `break`.
- `xschem windows` lists `{win top topwin modified file}` per window;
  `xschem new_schematic switch <win>` switches context.

---

## Slice 1 — RED test

Add `tests/cadence_new_window.tcl` (headless, self-asserting; reuse `tests/buried_hilight/`
`a.sch` as the "current" schematic, 1 instance). Stub `ciw_echo` if absent; source
`utils/cadence_nav.tcl`. Assertions:
- after `cadence::new_blank_window`: `xschem get instances` == 0;
  `[file tail [xschem get schname]]` == `untitled.sch`; window count == 2; current win
  path != the original.
- switch back to the original win (`xschem new_schematic switch <orig>`):
  `xschem get instances` == 1; schname tail == `a.sch` (non-destructive).

First run: `cadence::new_blank_window` undefined → test FAILS (RED).

## Slice 2 — GREEN: helper + bind

1. `utils/cadence_nav.tcl`: add `cadence::new_blank_window` (spec §4) — call the
   primitive, log the replayable action, ciw_echo the new win path.
2. `src/cadence_style_rc`: add `bind .drw <Control-Key-n> {cadence::new_blank_window; break}`
   with a comment (near the other Ctrl bindings). Confirm no existing `<Control-Key-n>`
   bind to clobber (only `<Control-Shift-Key-N>` exists — distinct).
3. Run the test → GREEN. Source-load smoke (proc defined, rc parses).

## Slice 3 — regression + docs/memory

- Re-run `tests/cadence_new_window.tcl`, `tests/cadence_note_nav.tcl`,
  `tests/buried_hilight.tcl` — all green.
- Mark spec acceptance; update [[cadence-note-nav]] / a memory note + MEMORY.md.
- Manual GUI (user): Ctrl-N opens a focused blank scratchpad window; the prior window’s
  edits are untouched; Ctrl-N inside the scratchpad opens another.

## Risks / watch-items
- `clone_canvas_bindings` emits a benign `winfo` error under `--nogui` (Tk absent) but the
  window is still created — the test tolerates it (the command returns normally).
- Don't touch the global default / File-menu Clear Schematic (scope = cadence_style_rc).
- `<Control-Key-n>` is lowercase-n, distinct from `<Control-Shift-Key-N>`; verify both fire
  independently in a real session.
