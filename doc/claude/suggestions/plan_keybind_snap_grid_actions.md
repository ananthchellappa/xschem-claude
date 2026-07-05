# Plan (RED-first): data-driven snap/grid/highlight key actions; CTRL-G → toggle grid (user-bound)

Target branch: `fluid-editing`. Spec: `doc/claude/specs/keybind_snap_grid_actions.md`.

**Progress:** Phase 0 (scaffold) + Phase 1 (register actions) done. Phase 2 (remove snap
defaults) done — and it **folded in Phase 4** (the shipped `keybindings.csv` must lose the
`g`/`G` rows in the same change, else the startup csv replay re-binds them) **and Phase 6's
`cadence_style_rc` recipe block** (brought forward so the FAQ can point at real lines; the
active `CTRL-G→view.toggle_draw_grid` line is live). `test_key_graph_context.tcl` was
updated (it asserted the old `g`/`G` snap defaults). Phase 3 (delete the dead `case 'g'` and
`case '%'`, incl. the orphaned `dr_gr` local) done — scaffold all-green; verified that
unbound `%`/Ctrl-g/Alt-g are now no-ops (no residual set-snap dialog) and a table-bound `%`
still toggles grid. Phase 5 (blank stale menu accelerators: Half/Double Snap Threshold, Draw
grid) done. Phase 7 done: spec → **implemented**, FAQ Q17 update + Q18, `action-registry`
memory extended. **COMPLETE** — all phases landed; scaffold all-green; binding/key regression
green.

## Shape of the work

Finish migrating the last hardcoded `g`-family + grid keys off the `handle_key_press`
switch and into the action registry, so their chords are **data-driven and user-specified**.
Three new `ActionDef` rows (two Tcl-backed, one C-backed); **remove** the existing `g`/`G`
snap defaults and add **no** replacements (these actions ship unbound); two dead `case`
deletions; a regenerated `keybindings.csv`; menu-accelerator blanking; and the actual chords
specified in `cadence_style_rc` (CTRL-G→grid **active**, the other four commented).

This **needs `make`** (C changes in `src/callback.c`). Most of the binding plumbing already
exists (`xschem bind`, `ActionDef`, `dispatch_input_action`, the csv loader) — we are adding
catalog entries and *removing* defaults, not building new mechanism, and not adding any new
default binding.

**Method: RED-first.** Each step adds/extends a headless test that FAILS on current code
(RED), then the smallest change to GREEN, then a sabotage check (revert, confirm RED again —
guards against `green_but_hollow`). One headless file grows across the plan:
`tests/headless/test_keybind_snap_grid.tcl` (needs X; fires real key events via
`xschem callback .drw <keypress> …` and inspects `cadsnap` / `draw_grid` / `xschem bindings dump`).
GUI tests run **serially** (WSLg X server — see `parallel-tests` memory / issues 0001-0002).

Keysyms: `g`=103, `G`=71, `%`=37, `s`=115. Mods for `xschem bind`: `0|ctrl|alt|shift|super`
(`+`-joined). A key event is fired as `xschem callback .drw <type> <mx> <my> <keysym> 0 0 <state>`
(keypress type + state mask; mirror existing usage in `tests/headless/test_binding_precedence.tcl`).

---

## Phase 0 — test scaffold (RED)

Create `tests/headless/test_keybind_snap_grid.tcl` encoding the spec's acceptance list. All
"end-state" checks are RED now. Keep them; they go GREEN phase by phase.

Checks (IDs map to spec §7):
- **KB1** on a plain startup, `xschem bindings dump` has NO row for any of `view.snap_half` /
  `view.snap_double` / `view.set_snap_value` / `hilight.send_to_waveform` /
  `view.toggle_draw_grid`. Nothing in this family is bound by default.
- **KB2** after `xschem bind key 103 ctrl canvas view.toggle_draw_grid` (what cadence_style_rc
  does), firing **Ctrl-G** flips `draw_grid` and the change persists after a redraw.
- **KB3** every action is bindable from Tcl: `xschem bind key 103 0 canvas view.snap_half`
  then firing `g` halves `cadsnap`; `xschem bind key 115 alt canvas view.set_snap_value` is
  accepted (action exists); `hilight.send_to_waveform` / `view.toggle_draw_grid` accepted too.
- **KB4** the C source has no `case 'g'` / `case '%'` in `handle_key_press` (file grep check).
- **KB5** `src/cadence_style_rc` contains the **active** (uncommented)
  `xschem bind key 103 ctrl canvas view.toggle_draw_grid` line (file grep check).

Run: `DISPLAY=:0 ./src/xschem --preinit 'set XSCHEM_TMP_DIR {…}' --pipe -q --nolog --script tests/headless/test_keybind_snap_grid.tcl`.
(For KB1's "plain startup" use `--rcfile tests/headless/minrc` so no user rc binds anything.)

---

## Phase 1 — register the three new actions (GREEN: KB3 "accepted" + KB2 once bound)

In `src/callback.c`, action-registry region (`~2602`–`2700`):

1. **`view.toggle_draw_grid`** — Tcl-backed (no new C fn). Add to the `ActionDef` table:
   `{ "view.toggle_draw_grid", NULL, "set draw_grid [expr {!$draw_grid}]; xschem redraw", "Toggle grid display" }`.
2. **`view.set_snap_value`** — Tcl-backed:
   `{ "view.set_snap_value", NULL, "input_line {Enter snap value (float):} {xschem set cadsnap} $cadsnap", "Set snap value (dialog)" }`.
   (Same Tcl the View menu runs, `xschem.tcl:11491`.)
3. **`hilight.send_to_waveform`** — C-backed. Add `act_highlight_send_waveform(const
   ActionEvent *e)` containing the **verbatim** body of the current `case 'g'`
   `EQUAL_MODMASK` branch (`callback.c:3890`–~3920): keep the `if(xctx->semaphore >= 2)
   return 0;` early-out (so it is a no-op while busy under any binding), end with
   `hilight_net(tool); redraw_hilights(0);` and `return 1;`. Register
   `{ "hilight.send_to_waveform", act_highlight_send_waveform, NULL, "Highlight net and send to waveform viewer" }`.

`make`, run. The action ids are now bindable, so the in-test `xschem bind … <id>` calls
succeed (KB3's "accepted" checks) and a test that binds Ctrl-G→grid then fires it goes GREEN
(KB2). KB1 still RED (the old `g`/`G` snap defaults remain).

Sabotage: misspell one registered id → `xschem bind … <id>` errors → KB3 RED.

---

## Phase 2 — remove the snap defaults; add NO replacements (GREEN: KB1)

In `init_input_bindings()` (`src/callback.c:~2875`):
- **delete** `set_input_binding(DEV_KEY, 'g', 0, ACTX_CANVAS, "view.snap_half");`
  and `set_input_binding(DEV_KEY, 'G', 0, ACTX_CANVAS, "view.snap_double");`
- **add nothing** — no `Ctrl-G→grid` default, no `%`, no snap, no highlight. These five
  actions ship **unbound**; chords are specified by the user (Phase 6 / their rc).

`make`, run. On a plain startup nothing in the family is bound (KB1 GREEN). KB2/KB3 stay GREEN
(they bind explicitly in-test). Sabotage: re-add the `'g' 0 snap_half` default → KB1 RED.

> Why no default `Ctrl-G→grid`: the binding is the *user's* choice and lives in their config
> (`cadence_style_rc`), per the spec. The shipped build leaves the chord free.

---

## Phase 3 — delete the dead C cases (GREEN: KB4)

In `handle_key_press` (`src/callback.c`):
- delete the whole **`case 'g':`** block (`:3880`–~3921). Plain `g` was already migrated;
  the `ControlMask` (set-snap) and `EQUAL_MODMASK` (highlight) logic now live in actions.
- delete the whole **`case '%':`** block (`:4708`–~4723) — `view.toggle_draw_grid` handles it
  when bound.
- keep the existing `case 'G'` migration comment; remove or trim the now-stale ones.

`make`, run. KB4 GREEN; KB2/KB3 stay GREEN (proves the table path, not the switch, serves
these). Sabotage: restore the `case '%'` body, do NOT bind `%` → grid still does not toggle on
`%` via the case because… it would — so instead sabotage-verify by binding `%`→grid in-test
and confirming it works *only* through the table (delete the case again, the in-test `%` bind
still toggles), proving the case is dead.

---

## Phase 4 — regenerate the shipped keybindings.csv (GREEN: binding-file smoke test)

`src/keybindings.csv` is generated from the live built-in table; it must not drift (the
binding-file smoke test diffs it). Regenerate after Phase 2:

```
DISPLAY=:0 ./src/xschem --pipe -q --nolog --preinit 'set XSCHEM_TMP_DIR {…}' \
  --command 'save_input_bindings_file [file join $XSCHEM_SHAREDIR keybindings.csv] {key}; exit'
```
(or call `save_input_bindings_file` from a one-line `--script`). Confirm the diff: the `g`/`G`
snap rows are gone and **nothing is added** (no grid row, no `%` row — those are user rc
bindings, not builtins). Run `tests/headless/test_bindings_file.tcl` (or the existing
binding-file smoke) → green.

Sabotage: hand-edit a stray row into the csv → smoke test RED (drift detected).

---

## Phase 5 — menu accelerator blanking (no behavior change)

`src/xschem.tcl` (pure Tcl, no rebuild). Since nothing is bound by default, blank the static
accelerator labels so the menus don't advertise chords that aren't there:
- "Half Snap Threshold" / "Double Snap Threshold" (`:11346`, `:11349`): `-accelerator {}`.
- "Draw grid" checkbutton (`:11342`, was `%`): `-accelerator {}`.
- (Audit nearby snap/grid menu items for other stale accel strings.)

The cheat-sheet (`show_bindkeys`) regenerates from the **live** table, so once the user's rc
binds `CTRL-G→grid` it appears there automatically (and never drifts). Test: `grep` the menu
build for the blanked labels, or a lightweight check that the cheat-sheet of a *plain* startup
lists none of these five.

---

## Phase 6 — cadence_style_rc: the active grid binding + commented recipes (GREEN: KB2 e2e, KB5)

Append the spec §6 block to `src/cadence_style_rc`:
- **active** (uncommented): `xschem bind key 103 ctrl canvas view.toggle_draw_grid` — CTRL-G
  toggles grid under the user's config.
- **commented** templates: `view.snap_half` (g), `view.snap_double` (G),
  `hilight.send_to_waveform … idle` (Alt-g), `view.set_snap_value` (an unused chord, e.g.
  Alt-s = keysym 115), and `view.toggle_draw_grid` on `%` (keysym 37, to restore the old key).

End-to-end check: load `cadence_style_rc`, confirm `xschem bindings dump` now lists
`key 103 ctrl … view.toggle_draw_grid` and firing Ctrl-G toggles `draw_grid` (KB2 via the rc,
not an in-test bind); and KB5 (the file contains the active line). Sabotage: comment the active
line → the rc-loaded dump no longer has the grid row → KB2-via-rc RED.

---

## Phase 7 — docs

- Flip `doc/claude/specs/keybind_snap_grid_actions.md` Status → **implemented**.
- Add a short "Update (implemented): …" note to `doc/claude/FAQ.md` Q17, pointing at the
  spec + the new action ids; correct Q17's "Tier B default binding" framing to "no default;
  user-bound in cadence_style_rc".
- Memory: update/extend the `action-registry` memory with the new action ids and the
  "ship-unbound, user specifies the chord in their rc" pattern.

---

## Risks / notes

- **No built-in defaults — by design.** None of the five actions is bound by the shipped
  build; the only chord that exists out of the box for a cadence user is the **active**
  CTRL-G→grid line in `cadence_style_rc`. A plain (`minrc`) startup leaves all five free.
- **Keysym-with-shift gotcha.** Shift changes the *keysym* (e.g. Shift-g → `G`/71), exactly
  the trap that bit `Ctrl-Shift-2` earlier. The examples use the real produced keysyms and the
  set-snap example avoids a shifted-letter chord. Flag this in the rc comment.
- **Alt mask.** `EQUAL_MODMASK` (Alt) is `Mod1Mask` on X; `parse_mods("alt")` → `Mod1Mask`,
  so the `alt` recipe matches. On Windows Alt is reported differently (`xschem.tcl:10990`
  builds masks manually) — out of scope here; note it.
- **`idle` flag.** `hilight.send_to_waveform` keeps its internal `semaphore>=2` guard, so
  binding it `idle` is optional but recommended (the recipe includes it).
- **No new Tcl-action-registration mechanism.** Adding action ids is still a C edit to the
  `ActionDef` table; only the *binding* is data-driven / user-specified. If the project later
  wants register-action-from-Tcl, that is a separate feature (a generic `xschem action define
  <id> <tcl>` command) — noted, not in scope.
