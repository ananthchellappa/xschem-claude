# `xschem load` window routing (no-clobber open + `-window` targeting)

## Problem

`xschem load <file>` historically loads the file **in place**, replacing the
content of the *current* editor window. A bare, user-typed `xschem load {file}`
(no flags → `force = 1`) therefore silently clobbers whatever the current window
was showing, with no "Save changes?" prompt. That is wrong for a user-facing
open: a window that already holds a real cellview, or has objects drawn in it,
must not be thrown away just because a file was opened.

Desired editor behavior (Cadence / NEdit-style):

- An open must **not** reuse an occupied window. The current window may be
  reused **only** if it is a pristine `untitled<N>.sch|.sym` scratch buffer that
  is completely empty (no objects, not modified).
- If the current window is occupied, the file opens in a **new window/tab**.
- A specific existing window can be named as the reuse target
  (`-window <winpath>`); if that window's cellview is modified, pop
  "Save changes?" first and abort the load if the user cancels.

## Design

Two additions to the `load` handler in `scheduler.c` (the `xschem load` branch),
plus a routing decision. **Internal / scripted in-place loads are left exactly
as they were** — the change only affects user-facing opens.

### In-place vs. user-open discrimination

Every internal caller that needs true in-place replacement passes at least one
"scripted" flag:

| caller | flags |
|--------|-------|
| symbol-edit reload | `-keep_symbols -nodraw -noundoreset` |
| descend / ascend   | `-undoreset -nodraw` |
| swap/compare       | `-nofullzoom -gui` |
| pristine-untitled reuse arm (`load_new_window`) | bare, but only when `is_pristine_untitled()` |

Routing is gated on `-gui` (interactive opens: `force == 0`). This is the
critical safety line: **bare `xschem load <f>` (`force == 1`) and every scripted
load stay in place.** The whole regression suite drives *repeated bare loads into
a single window* (e.g. `pin_name_text.tcl` loads f1, o1, f2, … sequentially;
`bus_resize.tcl` reloads `a.sch` as a reset) and depends on that — routing bare
loads to new windows would break dozens of tests and any internal bare-load
caller. So only `-gui` opens (File>Open, recent, Library Manager) route.

Belt-and-suspenders, a load is a **user open** only if it also carries none of
the in-place hint flags (`-nosymbols`, `-nodraw`, `-nofullzoom`, `-keep_symbols`,
`-noundoreset`, `-inplace`) — this keeps `swap_compare_schematics` (`-nofullzoom
-gui`) on the in-place path. A user open with a *pristine untitled* current
window collapses to an in-place load anyway, so the reuse arm keeps working.

```
inplace_hint = -inplace | -nosymbols | -nodraw | -nofullzoom | -keep_symbols | -noundoreset
route_newwin = has_x && -gui && !(-window) && !inplace_hint && !is_pristine_untitled()
```

### What "pristine" means (tightened by issue 0172)

`is_pristine_untitled()` is the shared predicate behind all three reuse doors — this
routing decision, `load_new_window <file>`, and `load_new_window` via the file dialog —
so it is where the exclusions live, not in the callers. It is true only when the current
context is top level, not `modified`, named `untitled*` (or unnamed), **empty of every
object type** (no instances, wires, texts, and no rects/lines/polygons/arcs on any
layer), and **not a waveform viewer** (`xctx->wave_viewer`, stamped by `wviewer::open`).

Both of the last two are issue 0172. An ASE viewer is a schematic buffer whose content
is graph *rects* and whose `modified` is pinned at 0 for life by the `with_edit` D1
contract, so by the old shape test it was permanently "pristine" — and a user open
landed a real schematic inside a live viewer window, under the viewer's bindtag, where
`Ctrl-D` then wiped it. Checking every object array closes the same hole for any buffer
that has had `set_modify 0` applied to it with content in place.

`readonly` is deliberately **not** part of the test: this branch opens ordinary
schematics read-only (descend read-only, the reopen shortcuts) and those are still fair
reuse targets. Guards: `tests/headless/test_pristine_untitled_viewer_0172.tcl` (no X)
and `test_wave_clear_all.tcl` CG9/CG10 (need X).

There is a **fourth** door that the predicate does not govern: `ask_new_file()`
(`src/actions.c`), entered from `xschem load` with no filename and from Ctrl-O / Alt-O.
With `open_in_new_window` 0 (the default) its in-place arm calls `load_schematic()`
unconditionally — it never asks whether the current window is pristine, which is why
routing had to be added to `xschem load -gui` in the first place. Issue 0172 gave it the
one exclusion it needs (`xctx->wave_viewer` forces the new-window arm); everything else
about it is unchanged.

`has_x`: routing to a "new window" is meaningless without a GUI, so a headless
(`--nogui`) run — including an action-log replay of a `-gui` line — never routes
and always loads in place.

Interactive call sites: `file_chooser` already passes `xschem load -gui`; the
Library Manager "current window" arm (`library_manager.tcl`) is updated from bare
`xschem load` to `xschem load -gui` so it, too, stops clobbering an occupied
window.

### Typed CIW commands (`ciw_interactive_load`)

A command a human TYPES into the CIW command entry is an interactive open too,
but a typed `xschem load {file}` carries no `-gui`. `ciw_exec` (`ciw.tcl`) passes
the line through `ciw_interactive_load`, which injects `-gui` into a bare
`xschem load …` (only when no routing/scripted flag is already present, and never
`load_new_window` / `load_backup`). The regsub touches only the `xschem load`
prefix, so braces/spaces/backslashes in the path are safe.

This is deliberately the ONLY place bare `xschem load` becomes interactive:
`--script` files, external drivers and action-log **replays do not pass through
`ciw_exec`**, so their bare loads stay in place — which is exactly what the
regression suite depends on (dozens of headless cases drive repeated bare
`xschem load` into a single window). So the scheduler's bare-load semantics are
unchanged; only the human-typed path is upgraded, giving "typed command opens a
new window" with zero test migration.

### Routing

- `route_newwin == 1`: preset `first_loaded = 1` before the file loop, so the
  first file (like the 2nd..Nth today) is opened via
  `new_schematic("create", ...)` → a new window/tab. The current window is left
  untouched: skip its `save()` prompt, its hilight/selection clear, and its
  context reset.
- `route_newwin == 0` and no `-window`: legacy in-place load into the current
  window (pristine-untitled reuse, or a scripted in-place load).

### `-window <winpath>` targeting

`winpath` is a Tk drawing path (`.drw`, `.x1.drw`, …) or the slot's current cell
name — resolved with `get_tab_or_window_number()` / `get_window_path()`.

1. Unknown / closed window → `TCL_ERROR` ("no such window").
2. Switch context to it (`new_schematic("switch", path, "", 0)`).
3. If its buffer is modified → `save(1, 0)` ("Save changes?" `ask_save` dialog).
   Cancel (returns −1) → abort the load quietly, target untouched.
4. Otherwise load the file **in place** into that (now current) window.

Targeting the current window is allowed (switch is a no-op) — it is the explicit
"reuse this window, prompting to save" path.

### `-inplace`

Escape hatch: force legacy in-place load into the current window regardless of
routing (opt out of new-window routing).

## Blast radius

Zero for scripted / `--script` / replayed bare loads — they keep the legacy
in-place path. Behavior changes for **interactive opens**: menu/`-gui` opens
(File>Open, recent menu, Library Manager) AND commands the user TYPES into the
CIW entry, which now open a new window instead of clobbering an occupied one.
`swap_compare_schematics` (passes `-nofullzoom -gui`) is explicitly exempt.

## Tests

`tests/headless/test_load_window_routing.tcl` — needs X, run from repo root:

- LR1: occupied current window + user open → new window, current untouched.
- LR2: pristine untitled current window + user open → reused in place (no new
  window).
- LR3: modified current window + user open → new window, no data loss, no prompt
  on current.
- LR4: `-window <occupied>` + clean target → loads into that window.
- LR5: `-window <occupied,modified>` → save-prompt fires; cancel aborts (target
  content preserved).
- LR6: `-inplace` / scripted flags → legacy in-place (sabotage guard: proves the
  routing did not leak into scripted loads).

`tests/headless/test_ciw_interactive_load.tcl` — pure-Tcl (`--nogui`), wired into
`run_regression.tcl` hcases. Pins `ciw_interactive_load`'s rewrite table:
`xschem load {f}` → `xschem load -gui {f}`; paths with spaces, multi-file, extra
whitespace; and the non-rewrites (`-gui`/`-window`/`-inplace`/`-nodraw` already
present, `load_new_window`, `load_backup`, non-load commands, idempotent re-run).
