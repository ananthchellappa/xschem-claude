# Plan — Net highlight style editor (GUI)

Status: PLANNED (2026-06-26). Spec: `doc/claude/specs/net_hilight_style_editor.md` (all decisions LOCKED, no
open questions). Memory: [[net-hilight-styles]], [[action-registry]], [[ciw-feedback-channels]],
[[user-run-config]], [[green-but-hollow]].

Builds the no-docs GUI editor for the `net_hilight_style` table. The hard parts (the style schema,
the C compile/render/animation engine, and the fault-tolerant table-mutation procs) **already
exist** — this is almost entirely new Tcl UI sitting on top of them, plus three small wiring points
(palette row, Tools menu, startup load). No change to the row schema or the C engine.

Discipline (matches the rest of this branch): **each slice is one commit, RED-first** (write the
failing test first), then a `/code-review high` pass before the next slice. Pure-Tcl logic is tested
headless; widget construction/behaviour is tested with a Tk window (`DISPLAY=:0`; no xvfb here — keep
GUI tests short and `update idletasks`-driven; `-g` geometry hangs under WSLg, see [[net-hilight-styles]]).

---

## Ground-truth anchors (read these before coding)

- Row model: 8 cols `{index color width dash angle blink_ms anim rate_persec}`; comment at
  `src/xschem.tcl:513-519`; struct `NetHilightStyle` in `src/xschem.h`.
- Fault-tolerant table procs (the GUI's whole API): `src/xschem.tcl:512-650`
  — `net_hilight_style_{default_row,norm,current,replace,merge,append,remove,reset}`.
  Every one calls `xschem update_net_hilight_style` (live recompile+redraw). **No new core mutation
  code** — Move/Duplicate compute a list and call `net_hilight_style_replace`.
- Normalizer clamps (the widgets must not exceed these): `net_hilight_style_norm`
  `src/xschem.tcl:526-541` (width≥1; angle 0..45; blink_ms≥0; anim∈{none,march_fwd,march_rev};
  rate≥0). C parser parallel: `parse_net_hilight_styles` `src/hilight.c:434-540`.
- Color resolution source: `find_best_color()` `src/xinit.c:277,286` → `XAllocNamedColor` →
  `/usr/share/X11/rgb.txt` (754 entries). Tk-side validate with `winfo rgb`.
- Palette: `command_palette`/`palette_refilter` `src/action_registry.tcl:369-498`; result widget is a
  **listbox** (`:475`); rows inserted in a loop (`:404-417`). Per-item color via `itemconfigure`.
- Tools menu (hand-written): `src/xschem.tcl:12004-12404` (add item near "Library Manager" `:12397`).
- actions.csv (palette + cheat-sheet source; File is the only csv-built MENU): `src/actions.csv`.
- Persistence idiom (write a Tcl-sourceable file in `$USER_CONF_DIR`, source at startup):
  `write_recent_file` `:1506`, `load_recent_file` `:1441`; startup var init `set_ne net_hilight_style {}`
  `:~13386`. CIW channel: `ciw_echo` (NOT puts/statusbar — [[ciw-feedback-channels]]).
- `tk_chooseColor` precedent `:8506`; combobox/spinbox/scale precedents `:3775,:3916,:8080`.

---

## Decisions LOCKED (from the spec; do not re-litigate)

Palette emphasis = font **color** via `itemconfigure -foreground` (no widget change, not bold) ·
color dropdown sourced from **rgb.txt**, multi-word names stored single-token CamelCase or `#RRGGBB`
· **blink & march speed = entry fields** with unit labels (only **angle** is a slider) · **dash =
text entry + examples dropdown that fills it** · **one shared** animated-canvas preview following the
focused row · free-row action = **Add / Overwrite(row # spinbox)** · per-row **Move↑/↓ Delete
Duplicate** enabled only when a table row has focus · buttons **OK/Apply/Load…/Save…/Cancel**, **WM ✕ =
Cancel** (revert to open-time snapshot) · harmless **seen flag auto-persists**
to `~/.xschem/net_hilight_editor_seen`; the **style table writes only via explicit located Save…**
(warn + `ciw_echo` the `xschem --script {path}` line when path ≠ the auto-load file) · non-modal,
single instance, edits the one global table.

**Superseded post-implementation (2026-06-26, requester feedback — spec §8.1/§8.5):** **STAGED apply**
(NOT live-apply — edits restage with `apply=0`; Apply/OK push live via `nhse_apply_live`; Reset is the
lone live exception) · **Load…** companion to Save… = **parse, never source** (safe child interp,
`xschem` no-op'd), **Replace or Add**, staged (slice 9).

---

## Worklist (each slice = one RED-first code+tests commit, then `/code-review high`)

### Slice 1 — persistence scaffolding + startup load (pure Tcl, headless-testable) — STATUS: DONE (`93e06c43`)
**Goal:** the file I/O and globals, with no GUI yet.
- Add global `net_hilight_editor_seen` (default 0) at the `net_hilight_style` init site (`:~13386`).
- `proc write_net_hilight_editor_seen {}` → write `$USER_CONF_DIR/net_hilight_editor_seen` containing
  `set net_hilight_editor_seen 1` (catch-guarded, like `write_recent_file`).
- `proc write_net_hilight_style_conf {path}` → write the Tcl-sourceable style file:
  header comment, `set net_hilight_editor_seen 1`, `set net_hilight_style { … }`,
  `catch {xschem update_net_hilight_style}`.
- Startup: after `set_ne net_hilight_style {}`, source `$USER_CONF_DIR/net_hilight_editor_seen` and
  `$USER_CONF_DIR/net_hilight_style` if present (beside `load_recent_file`).
- **RED-first test** (headless, `tests/headless/test_nh_editor_persist.tcl`): call
  `write_net_hilight_style_conf $tmp`; re-source in a fresh interp → `net_hilight_style` round-trips
  and `net_hilight_editor_seen==1`; `write_net_hilight_editor_seen` then re-source → flag 1.
- **Done-when:** round-trip test green; startup sourcing wired (grep the init site).

### Slice 2 — discoverability: palette row + Tools item + color emphasis + stub launcher — STATUS: DONE (`51dd6992`)
**Goal:** the action is discoverable and the first-launch emphasis works, before the dialog has content.
- `src/actions.csv`: new row `tools.net_hilight_style_editor,command,tools,Net highlight styles…,,net_hilight_style_editor,,,"Edit net highlight colors, dashes, blink and marching-ants without editing rc files",`
  (help has a comma → quote it; verify field count parses — see the gh_issue_1 CSV lessons).
- Tools menu (`:~12397`): `add command -label "Net highlight styles…" -command {net_hilight_style_editor}`.
- **Stub** `proc net_hilight_style_editor {{topwin {}}}`: create an empty toplevel `.nhse` titled
  "Net highlight styles", set `net_hilight_editor_seen 1`, call `write_net_hilight_editor_seen`.
  (Fleshed out in later slices.)
- `palette_refilter`: after inserting the row, if its `id eq tools.net_hilight_style_editor` and
  `net_hilight_editor_seen==0`, `$w.l itemconfigure <i> -foreground <accent>`.
- **RED-first tests:** (a) headless — `palette_refilter` marks the row when seen==0 and not when ==1
  (assert via a stubbed listbox capturing itemconfigure, or check the chosen index/flag logic in a
  helper proc factored out for testability); (b) GUI — calling the stub sets seen=1, writes the
  marker, opens `.nhse`.
- **Done-when:** palette shows the entry (emphasized once), Tools item present, stub flips+persists
  the flag. **Factor the "which row to emphasize" decision into a tiny pure proc** so it is testable
  without a real listbox.

### Slice 3 — table view (read-only render of the current rows) — STATUS: DONE (`2ff6f4c1`)
**Goal:** the dialog shows the existing table, one row per style; no editing yet.
- Build a scrollable frame (`canvas`+inner `frame`, the standard Tk scroll idiom) inside `.nhse`.
- `proc nhse_rebuild {}` reads `net_hilight_style_current` and renders one row per style: a read-only
  index label + one (static, text-only for now) cell per column. Column header labels.
- **RED-first test (GUI):** open with a seeded 3-row table → 3 rows present, index column 0/1/2,
  values match. (Drive by `info commands`/`winfo children` on the row frames.)
- **Done-when:** `nhse_rebuild` faithfully reflects the table; reopening after an external
  `net_hilight_style_replace` re-renders.

### Slice 4 — per-cell editing widgets (static; live-apply on commit) — STATUS: DONE (`f067b78a`)
**Goal:** real widgets, each writing back to the table on commit. No animation/preview yet.
- Color: swatch button + `ttk::combobox`. Populate list = `Layer 0..N` + names parsed from
  `/usr/share/X11/rgb.txt` (single-token CamelCase variants; dedupe; bundled fallback list if the
  file is absent) + `Custom…`. `Custom…`/swatch → `tk_chooseColor` → store `#RRGGBB`. Validate any
  value with `winfo rgb` before apply; multi-word → store its `winfo rgb` hex.
- Width: `spinbox` 1..100. Dash: `entry` + examples `ttk::combobox` {Solid,Dash `6 4`,Dot `2 3`,
  Dash-Dot `6 3 2 3`,Long-Dash `12 4`} that fills the entry. Angle: `scale` 0..45. Blink: `entry`
  labelled `(ms)`. Marching: `ttk::combobox` {Off,Forward,Reverse}. Speed: `entry` labelled `(per/s)`.
- Disable Angle/Marching/Speed when the dash entry is empty (solid).
- Commit path: on `<FocusOut>`/`<Return>`/combobox-select, rebuild the whole table list from the row
  widgets and call `net_hilight_style_replace` → live redraw. (Replace renumbers; index stays == pos.)
- **RED-first tests:** (headless where possible) rgb.txt parser yields a deduped single-token list
  incl. `red/orange/yellow`; a multi-word pick stores hex; (GUI) editing each cell updates
  `net_hilight_style` and the value is `norm`-clamped (e.g. width 0 → 1, angle 90 → 45).
- **Done-when:** every column round-trips widget→table→widget; no widget can emit a value `norm`
  would silently clamp (cross-check test).

### Slice 5 — shared live preview canvas — STATUS: DONE (`bcb29fcf`)
**Goal:** one preview that mirrors the focused row, animated.
- Add a `canvas` at the top. `<FocusIn>` on any row's widgets sets `nhse_focus_row` and repaints the
  preview from that row's *current widget values* (so it tracks uncommitted edits too).
- Draw a horizontal wire segment honoring color/width/dash/angle; animate blink (50% duty from
  `blink_ms`) and march (offset `dir·rate·P·frac(t)`, `P=sum(dash)`) via a single self-rescheduling
  `after` tick that stops when `.nhse` is gone. Reuse the timing semantics from `hilight.c`
  (`net_hilight_style_on_now`/`net_hilight_march_offset`); a ~15-line Tcl reimplementation is fine,
  or expose a read-only C query if exactness matters.
- **RED-first test (GUI):** preview item color matches the focused row; with `blink_ms>0` the item's
  visibility toggles across two sampled ticks; with marching, the dash offset advances. Keep it short
  (a few `after`/`update` cycles).
- **Done-when:** focusing different rows repaints; animation runs and **stops on close** (no orphan
  `after`).
- **Built:** pure-Tcl timing `nhse_dash_period` + `nhse_preview_state {row now_ms}`→`{visible offset}`
  mirror hilight.c (blink 50% duty; march `P*frac(rate*now_s)`, rev-mirror, odd-period doubling).
  `.nhse.preview` canvas pinned above the table; `nhse_focus_set` (bound `<FocusIn>` on every cell)
  tracks `::nhse_focus_row` and repaints; `nhse_preview_paint` draws color/width/dash/angle (sheared
  dash bands via `nhse_dash_bands`) from the focused row's UNCOMMITTED widget values; baseline wire
  shows even on blink-OFF. Single self-rescheduling `nhse_preview_tick` (40ms), `nhse_preview_start`
  on open, `nhse_preview_stop` cancels on `.nhse` `<Destroy>`. Display-only — never calls
  `nhse_commit`. Test `tests/headless/test_nh_editor_preview.tcl` (20 headless math + 7 GUI checks;
  G7 sabotage-verified to catch an orphaned `after`).

### Slice 6 — free-to-edit row + Add/Overwrite + Update + separator — STATUS: DONE (`c1e8e725`)
**Goal:** compose-and-commit a new/overwritten style.
- Pinned top row (`NEW` label), same widget set, seeded from `net_hilight_style_default_row`.
- Action `ttk::combobox` {Add, Overwrite}; when Overwrite, show a `row #` `spinbox` (0..N-1).
- `Update`: Add → `net_hilight_style_append {row}`; Overwrite → `net_hilight_style_merge {row with
  index=row#}`. Then `nhse_rebuild`; keep the free-row values.
- `ttk::separator` between the free row and the table (the spec's requested divider).
- **RED-first tests (GUI):** Add appends a row equal to the composed style; Overwrite row#=1 changes
  only row 1; free-row values persist after Update.
- **Done-when:** both actions behave per the §6 example; separator present.
- **Built:** pinned `NEW` row (key "new", `.nhse.tbl.free.rnew`) built with the same `nhse_build_row`;
  the per-row helpers now resolve the row's frame via `::nhse_rowpath` (set by the builder) so one
  builder serves both the scrollable rows and the pinned free row. Free row is COMPOSE-ONLY:
  `nhse_cell_commit` commits to the live table only for integer (table) keys; the free row's edits
  never touch the table until Update. Action combobox {Add, Overwrite} + `Row #` spinbox
  (`nhse_refresh_over_range`, shown only for Overwrite) + `Update` (`nhse_free_update`: Add→`append`,
  Overwrite→`merge` with the composed row's index set to the #). `ttk::separator` `.nhse.tbl.sep`
  divides the free row from the table. `nhse_rebuild` clears only integer-keyed vars
  (`nhse_clear_table_rows`) so the free row survives + Update keeps its values. Test
  `tests/headless/test_nh_editor_free.tcl` (GUI, 16 checks; the commit-guard check is commit-counter
  + sabotage-verified — a "table unchanged" check alone is hollow since `nhse_assemble_table` already
  skips the free row).

### Slice 7 — per-row ops (Move ↑/↓, Delete, Duplicate) + enable/disable — STATUS: DONE (`96732d1f`)
**Goal:** reorder/remove/clone a table row, buttons gated on table-row focus.
- Track `nhse_focus_row` via `<FocusIn>` (table rows only; the free row clears it / disables ops).
- Move↑/↓: swap with neighbour → `net_hilight_style_replace`. Delete: `net_hilight_style_remove`.
  Duplicate: insert a copy immediately below → `replace` (renumbers everything after).
- Buttons greyed unless a table row has focus.
- **RED-first tests (GUI):** each op yields the expected renumbered table; Duplicate puts the clone at
  focus+1 and shifts the rest; buttons disabled while the free row holds focus.
- **Done-when:** ops chain (focus follows the moved/duplicated row) and respect the enable rule.
- **Built:** `.nhse.ops` bar (Move Up/Down, Delete, Duplicate) pinned bottom. `nhse_op_target` =
  focused integer table row (free row "new" → {} → ops disabled). `nhse_ops_enable_state` greys all
  unless a table row has focus + greys Move Up on row 0 / Move Down on last (boundary moves no-op);
  wired into `nhse_focus_set` + `nhse_rebuild`. Ops route through replace/remove (renumber); Duplicate
  = `linsert` copy below. `nhse_focus_after_op` moves focus to the moved/clone/clamped row so the
  preview follows + ops chain. Test `tests/headless/test_nh_editor_rowops.tcl` (GUI, 16 checks;
  focus-follow sabotage-verified). NOTE for slice 8: pack the OK/Apply bar `-side bottom -before
  .nhse.ops` so it sits below the ops bar.

### Slice 8 — OK / Apply / Save… / Cancel, snapshot-revert, located save + warning + CIW echo — STATUS: DONE (`a4b9bc7a`)
**Goal:** the commit/persist surface and the no-silent-write guarantee.
- On open: snapshot `net_hilight_style`. **Apply** = re-`replace` current + redraw (stay open).
  **OK** = close (state already live). **Cancel** and **WM ✕** = restore snapshot +
  `xschem update_net_hilight_style`, close. **Reset to defaults** = `net_hilight_style_reset`.
- **Save…** = `tk_getSaveFile` (init dir `$USER_CONF_DIR`, name `net_hilight_style`) →
  `write_net_hilight_style_conf $path`. If `$path` ≠ `$USER_CONF_DIR/net_hilight_style`:
  `tk_messageBox` warning it won't auto-load, and `ciw_echo "# load next session: xschem --script {$path}"`.
- **RED-first tests:** (GUI) Cancel reverts live edits to the snapshot; (headless) Save to a temp path
  → re-source → table+flag persist; (logic) the warn/echo branch fires iff path ≠ auto-load path
  (factor the path-compare into a pure proc and assert it + that `ciw_echo` got the exact line).
- **Done-when:** no code path writes the style file except Save…; Cancel/✕ revert; located-save warns
  + echoes.
- **Built:** `.nhse.btns` bar (Reset left; OK/Apply/Save…/Cancel right) packed `-side bottom -before
  .nhse.ops`. Open snapshots the `net_hilight_style` global (`::nhse_snapshot`) + `wm protocol
  WM_DELETE_WINDOW nhse_cancel`. `nhse_apply` = `update_net_hilight_style`; `nhse_ok` = close;
  `nhse_cancel` (= ✕) = restore snapshot + update + close; `nhse_reset` = `net_hilight_style_reset` +
  rebuild. `nhse_save` = `tk_getSaveFile` → `write_net_hilight_style_conf`; the path-compare
  (`nhse_is_autoload_path`) and warn/echo decision (`nhse_save_announce`, returns 1 + echoes the exact
  `xschem --script {path}` line when path ≠ auto-load) are pure procs for headless testing. Test
  `tests/headless/test_nh_editor_buttons.tcl` (6 headless logic + 10 GUI; Cancel-revert
  sabotage-verified). Also folded in a user-feedback fix commit `a36f656e` (Help button, readable
  literal-pattern dash dropdown, always-visible Overwrite Row #).

### Post-slice-8 (already done, not original slices) — staged model + feedback fixes
Folded in after slice 8 from requester feedback (commits on `fluid-editing`): **staged commit model**
(`b0c75ca3` — edits restage with `apply=0`, Apply/OK push live via `nhse_apply_live`, supersedes spec
§8.1 live-apply); **Help button + readable literal-pattern dash dropdown + always-visible Overwrite
Row #** (`a36f656e`); **flush typed-but-not-committed edits on Apply/OK/Save/ops + mouse-wheel scroll**
(`b9bbbc40`); **grid header/column alignment** (`f19a40b5`). Slice 9 (Load) builds directly on the
staged `apply=0` mutators.

### Slice 9 — Load… (parse a styles file INTO the editor; Replace / Add) — STATUS: DONE (`04773bba`)
**Goal:** a Load… companion to Save… that brings a saved/similar file *into* the editor without
sourcing it, staged like every edit (spec §8.5). **Builds on the staged `apply=0` mutators.**
- **`proc nhse_parse_style_file {path}` → list-of-rows | `{}`** (pure, headless-testable — no Tk):
  read the file; `set ip [interp create -safe]`; `$ip alias xschem nhse_load_noop` (a master no-op so
  `catch {xschem …}` / a bare `xschem …` does nothing); `catch {$ip eval $contents}`; then
  `catch {set rows [$ip eval {set net_hilight_style}]}`; `interp delete $ip`. Return `{}` if no
  `net_hilight_style` was set. (Safe interp hides `open`/`exec`/`source`/`file`/`glob`/`cd`/`load`/
  `exit`, so any dangerous line is inert; `set`/`catch`/`list`/`lappend`/`lset`/`expr` remain.)
  Do **not** normalize here — return raw rows; the staged mutators normalize on stage.
- **`proc nhse_load {}`** (the button): `tk_getOpenFile -parent .nhse -initialdir $USER_CONF_DIR`;
  if cancelled, return. `set rows [nhse_parse_style_file $path]`. If `{}` → `tk_messageBox` + `ciw_echo`
  "no net highlight styles found in {$path}", no change. Else ask **Replace / Add** (a small chooser —
  start with a `tk_messageBox`-style 3-button dialog **[Replace] [Add] [Cancel]**, or a mode dropdown
  beside the button; pick one and note it): Replace → `net_hilight_style_replace $rows 0`; Add →
  `net_hilight_style_append $rows 0`. Then `nhse_rebuild`; `ciw_echo` the loaded count. **Stays
  staged** — Apply/OK push live, Cancel/✕ revert to the open-time snapshot.
- **Button:** add `.nhse.btns.load` to the bottom bar between Apply and Save… (pack order
  L→R: OK Apply Load… Save… Cancel; pack right side: cancel, save, load, apply, ok).
- **RED-first tests** `tests/headless/test_nh_editor_load.tcl`:
  - (headless) `write_net_hilight_style_conf $tmp` then `nhse_parse_style_file $tmp` returns rows
    equal to the saved table; a file with no `net_hilight_style` → `{}`.
  - (headless, SAFETY) a styles file that also writes a sentinel via a dangerous path — e.g. a line
    `set ::nhse_pwned 1` is harmless but a `file mkdir`/`exec touch <sentinel>` must NOT create the
    sentinel, and a bare `xschem update_net_hilight_style` must NOT fire (wrap `xschem` to count — 0);
    `nhse_parse_style_file` still returns the table. Assert the sentinel side effect did NOT happen.
  - (GUI) Load Replace → editor table becomes the file's rows (staged, `apply=0` ⇒ no live update —
    count via the `xschem` wrapper as in `test_nh_editor_staged.tcl`); Load Add → appended +
    renumbered; the Load… button exists; "no styles" path leaves the table unchanged.
  - Drive the Replace/Add choice deterministically (factor the chooser so the test can pass the mode,
    not click a modal) — e.g. `nhse_load_apply {rows mode}` does the stage, `nhse_load` only does the
    file pick + chooser + calls it.
- **Done-when:** Save→Load round-trips the table; Replace/Add behave; a dangerous line in the file is
  inert and Load never touches the live session (only Apply/OK do); sabotage-verify the safety test
  (e.g. temporarily source-instead-of-parse ⇒ sentinel appears / live update fires ⇒ test FAILS).
- **Built (`04773bba`):** `nhse_parse_style_file` evaluates the file in a child `interp create -safe`
  (open/exec/source/file/glob/cd/load/exit hidden → dangerous lines inert by capability) with `xschem`
  aliased to the master no-op `nhse_load_noop`, reads back the child's `net_hilight_style`, deletes the
  child; returns RAW rows (the staged mutators normalize on stage) or `{}` (no assignment / unreadable).
  `nhse_load_apply {rows mode}` stages Replace→`net_hilight_style_replace $rows 0` / Add→`…_append
  $rows 0` + `nhse_rebuild` + `ciw_echo` the count — factored so the test passes the mode (not a modal).
  `nhse_load_chooser` = a `tk_dialog` [Replace] [Add] [Cancel]; `nhse_load` = `tk_getOpenFile` (init
  `$USER_CONF_DIR`) → parse → (if `{}` → `tk_messageBox` + CIW "no … found", no change) → chooser →
  apply. Button `.nhse.btns.load` packed between Apply and Save… (right side reverse-packs cancel save
  load apply ok ⇒ visible L→R OK Apply Load… Save… Cancel). Test `tests/headless/test_nh_editor_load.tcl`
  (8 headless A/B + 12 GUI). SAFETY (B2/B3/B4) **sabotage-verified**: replacing the safe-interp body
  with `source $path` flips all three to FAIL (sentinel reaches main, evil dir+exec created, live update
  fires). GREEN-BUT-HOLLOW guard reused: the staged "no live update" checks wrap the `xschem` COMMAND
  (count `update_net_hilight_style`), not `nhse_apply_live`. Slices 1–8 + staged/feedback tests still green.

### Slice 10 — acceptance + polish + docs
- End-to-end acceptance (2-process where possible): open editor, add a marching style, Save to a temp
  dir, restart with `--script <that file>`, confirm the table is present and a net renders with it
  (sample via `net_hilight_dump_pixmap`/`net_hilight_test_now`). Confirm a fresh `$USER_CONF_DIR`
  marker makes the palette un-emphasize permanently. Round-trip **Save→Load** end-to-end (Save a
  table, edit it, Load the saved file with Replace → table restored).
- Update `doc/claude/specs/net_hilight_styles.md` cross-ref + FAQ (incl. the staged model + Load); mark this plan
  DONE per slice.

---

## Watch-items / risks

- **Listbox per-item color, not font** (already designed around): emphasis is `itemconfigure
  -foreground`. Don't reintroduce a font/bold path.
- **Multi-word rgb.txt names corrupt the row** (a Tcl list): always store single-token CamelCase or
  hex; the parser must prefer the no-space variant rgb.txt provides on the same RGB line.
- **Staging via `replace` (apply=0) renumbers** — never persist a user-typed `index`; the spec's
  `index == position` invariant is owned by the procs. Read index as display-only. (The editor passes
  `apply=0`; the live push happens only via `nhse_apply_live` on Apply/OK.)
- **Load must PARSE, not `source`** (slice 9): never `source` the chosen file in the main interp —
  use a `interp create -safe` child with `xschem` aliased to a no-op, read back its `net_hilight_style`,
  delete the child. Sourcing would run the file's `catch {xschem update_net_hilight_style}` (live apply,
  bypassing staging) and any dangerous lines. Sabotage-verify the safety test catches a source-instead-
  of-parse regression (a sentinel side effect appears / a live update fires).
- **Animation `after` leak:** the preview tick must self-cancel when `.nhse` is destroyed (bind
  `<Destroy>`), or it spins forever / errors on a dead canvas.
- **Don't double-source / double-apply:** the startup load sets the var then calls
  `update_net_hilight_style`; the editor's own edits also call it — fine, but avoid re-sourcing the
  conf file on every open (load once at startup only).
- **CSV row hygiene** (see the gh_issue_1 fixes this session): quote the comma-bearing help field;
  confirm `action_parse_csv_line` yields the right field count; no stray statement-separator issues.
- **Headless/Tk:** pure-Tcl slices (1, parts of 2/4/8) run without a window; GUI slices need
  `DISPLAY=:0`. Guard the editor proc so `--nolog`/no-X runs never try to build it.
- **Reproduce under the user's real config** when smoke-testing interactively: `src/xschem --script
  src/cadence_style_rc --logdir /tmp` ([[user-run-config]]); a green headless build ≠ the dialog
  works ([[green-but-hollow]]).

## Out of scope (per spec §12)
Schema/engine changes; the apply-to-nets UI (the 9/8/0 keys, `net_hilight_apply`); a general
palette-emphasis framework.
