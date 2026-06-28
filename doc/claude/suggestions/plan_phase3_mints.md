# Plan: Phase 3 — mint missing subcommands, close markers & silent ids

**Decisions (user, 2026-06-11):** (1) nolog the gesture-start commands;
(2) word-arg naming `xschem scroll up` / `xschem pan dx dy` as designed;
(3) mint all 4 toggle subcommands (uniform route); (4) rectcolor logging and
rotate-during-move stay out of scope.

Checklist rows 29–32 + the Layer C deferrals + the START/END reconciliation.
Goal: after this phase the feature is functionally complete and a final
spec/checklist reconciliation pass closes the books.

## Audit findings (step 0, done)

### The silent Layer A ids (csv rows with empty command)

15 ids, all C-backed (`act_*` in callback.c), all currently silent at dispatch:

| id | behavior (audited) | replay shape |
|---|---|---|
| view.scroll_up/down/left/right | `±CADMOVESTEP*zoom` on x/yorigin + draw | relative to view → composes like zoom_in/out |
| view.pan_up/down/left/right | same, half step (`/2`) | same |
| view.snap_half / snap_double | `set_snap(cadsnap/2 or *2)` + linewidth + draw | relative; `xschem set cadsnap` exists but is absolute+dynamic — a static csv command can't carry a runtime value |
| view.toggle_show_netlist | tcl var flip + alert dialogs | pure toggle |
| view.toggle_draw_pixmap | `xctx->draw_pixmap` flip + alert | C state — NOT expressible in plain Tcl |
| edit.toggle_stretch | `enable_stretch` tcl var flip | pure toggle |
| edit.toggle_orthogonal_wiring | tcl var flip + `xctx->manhattan_lines=0` on disable | mixed Tcl+C state |
| view.zoom_rect | gesture START | stays silent — its END now logs `zoom_box` (Layer C) |

### Middle-button pan gesture (row 32)

Hard-coded in C (not in the binding table — the documented Button2 carve-out).
`pan(START)` at callback.c:4472/4927, continuous `pan(RUBBER)` during motion,
and the "END" is just `ui_state &= ~STARTPAN` at the two ButtonRelease sites
(4865/5220) — **no net delta is captured anywhere**. To log it we must snapshot
xorigin/yorigin at pan START and emit the delta at the release.

### Layer A logging mechanics constraint

C-backed ids log a **static** string (`log_cmd`, pushed from the csv command
column at startup). Tcl-backed ids log `d->tcl` **unconditionally** — there is
no nolog gate on that branch yet (the csv `nolog` column only stops the
log_cmd push for C-backed ids). The reconciliation below needs that gate.

### Gesture-START commands that now duplicate Layer C END lines

Tcl-backed ids whose command is a no-arg gesture starter: tools.insert_wire
(`xschem wire`), insert_line, insert_rect, insert_polygon, insert_arc,
insert_snap_wire (`xschem snap_wire` — audit whether its placement funnels
through `new_wire`), insert_symbol (`xschem place_symbol` — opens a FILE
DIALOG when replayed), insert_text (`xschem place_text` — opens the text
dialog), edit.move_objects (+ stretch/kissing variants), edit.duplicate_objects,
view.zoom_box (palette/menu only; Z is bound to view.zoom_in).

## Design

### Principle for the mints

Each new subcommand calls the **same C code the `act_*` function calls**
(extract the body into a shared function where needed) → equivalence is by
construction, not by audit; the csv command column gets the subcommand and the
startup loop pushes it as log_cmd. This is the slice-2 discipline with the
audit burden engineered away. Replay must NOT pass through `new_*`/act
dispatch in a way that re-logs (same invariant as Layer C).

### New subcommands (scheduler.c)

1. `xschem scroll up|down|left|right` — full-step viewport scroll (csv command
   for the 4 scroll ids).
2. `xschem pan up|down|left|right` — half-step (csv for the 4 pan ids);
   `xschem pan dx dy` — numeric form for the drag-gesture END (row 32).
   argv[2] alpha vs numeric disambiguates.
3. `xschem snap half|double` — relative snap change (csv for the 2 snap ids).
   Absolute stays `xschem set cadsnap`.
4. `xschem toggle_stretch`, `xschem toggle_orthogonal_wiring`,
   `xschem toggle_draw_pixmap`, `xschem toggle_show_netlist` — wrap the same
   toggle bodies (the last two carry C state / alerts that plain Tcl can't
   reach). Naming follows the existing `xschem toggle_colorscheme`.
5. `xschem polygon x1 y1 x2 y2 x3 y3 ... [prop]` — coordinate form (≥3 points,
   even arg count) calling `store_poly(-1, …, rectcolor, 0, prop)` exactly as
   `new_polygon`'s store does; keeps the current no-coord/`gui` forms intact.

### Layer C upgrades enabled by the mints

- `new_polygon` store site: replace the `#` marker with the real
  `xschem polygon …` line built from `nl_polyx/nl_polyy[0..nl_points-1]`
  (dynamic-length line — build with my_realloc, not a fixed buffer).
- Pan gesture: snapshot origin at the two `pan(START)` sites (one helper),
  log `xschem pan dx dy` at the two STARTPAN release sites when the origin
  actually changed (skip no-op clicks).

### START/END reconciliation (decision needed — recommendation below)

Add a nolog gate to the **Tcl-backed** dispatch branch: load the csv `nolog`
flag into ActionDef (e.g. extend the startup push loop with
`xschem set_action_nolog <id>`, mirroring set_action_log_cmd), check it before
both `log_action` calls in the tcl branch. Then set `nolog` on the
gesture-start ids listed above.

**Recommendation: nolog the start forms.** Spec granularity decision 3 says
"gestures collapse to ONE command" — the START line is a second command for
the same gesture. Worse, two of the starts open dialogs when replayed
(`place_symbol`, `place_text`), so a sourced log would block on a file
chooser. With the starts silenced the log reads as pure effects:
`xschem instance {...} …`, `xschem wire …`, `xschem move_objects dx dy`.
The alternative (keep both, intent + effect) is more journal-like but makes
logs non-sourceable wherever a start opens a dialog — would need per-id
exceptions anyway.

Caveat to state in the spec: with starts silenced, an *aborted* gesture leaves
no trace at all (today it leaves a dangling start command). That matches
"log the effect" — an aborted gesture has none.

### Explicitly NOT in this phase

- rectcolor/layer-switch logging (line/rect replay layer fidelity) — note as
  v1 limit unless the user asks; layer changes happen via Tcl menus which are
  outside the three logging layers.
- rotate/flip-during-move marker upgrade (needs an anchor-preserving rotate
  subcommand; `xschem rotate` pivots differently — audit said no).
- Issues 0003/0004/0005 (standing deferrals).

## Worklist (each slice = code+tests commit, then docs)

1. **Slice A — view/toggle mints + csv + Layer A un-silencing.**
   scheduler.c subcommands 1–4 (shared bodies with act_*), csv command column
   filled for the 14 ids (zoom_rect stays empty), regenerate nothing (bindings
   files unaffected — commands, not chords). Test: drive each bound chord via
   `xschem callback` (arrows = scroll, wheel+Shift? use `bindings dump` to
   find live chords), assert log line + state delta + replay (source the line,
   same delta again); snap restored after.
2. **Slice B — polygon coordinate form + Layer C marker upgrade.**
   Test: polygon gesture logs `xschem polygon …`; replay places an identical
   poly (extend acceptance smoke record driver with the polygon gesture — the
   saved-.sch byte-diff then covers it).
3. **Slice C — pan gesture END logging** (`xschem pan dx dy` + origin
   snapshot). Test: Button2 press/motion/release logs the delta; replaying
   shifts origin by the same amount; no-op click logs nothing.
4. **Slice D — START/END reconciliation** (nolog gate for Tcl-backed +
   csv nolog on the start ids). Test: wire gesture produces exactly ONE log
   line (the END); place_symbol drop produces only the `xschem instance` line;
   acceptance smoke updated (its grep list loses nothing — starts were
   script-driven there, not logged).
5. **Slice E — reconciliation pass**: walk every checklist row against the
   code, flip statuses, restate the 0003/0005 bounds on row 11 explicitly,
   update spec status + memory; feature declared functionally complete.

## Open questions for review

1. **START/END reconciliation**: agree with nolog-the-starts (recommended), or
   keep intent+effect double lines (with per-id exceptions for the two
   dialog-opening starts)?
2. **Naming**: `xschem scroll/pan/snap` with word args as designed, or prefer
   `scroll_up`-style flat names (matching `zoom_in`)?
3. **Toggles**: minting 4 `toggle_*` subcommands is the uniform route; an
   alternative is csv Tcl one-liners for the two pure-Tcl toggles and
   subcommands only for the two with C state. Uniform preferred (one rule,
   by-construction equivalence) — OK?
4. Scope check: anything you want pulled in (e.g. rectcolor logging) or
   pushed out?
