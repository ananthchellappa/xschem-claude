# 0168 — Direct Plot refused to work from a DESCENDED schematic

Status: **FIXED** (2026-07-26)
Area: `src/ase.tcl` (`ase::session_for_current`, `ase::no_session_notice`, three
entry points), `src/ase_window.tcl` (`sod_base_level`, `sod_rel_path`,
`sod_qualify` gains a base level, `raise_design_editor`), `src/hilight.c`
(`resolved_net_from`), `src/scheduler.c` (`resolved_net` level arg,
`xschem windows` hierarchy field), `src/xschem.h`
Tests: `tests/headless/test_ase_hier_plot_0168.tcl` — `HL0`-`HL27` (31 checks, new file)
Fixture: the 0161 `tests/headless/fixtures/ase_hier/` hierarchy, re-registered by the
test into a scratch library (top + mid registered, leaf deliberately outside it)
Spec: `doc/claude/specs/ase_l.md`, "Select On Design v1 scope"
Reference: `doc/claude/code_analysis/waveform_subsystem_reference.md` §11 landmine 30
Related: 0161 (the pick-name half of the same feature — this is its reachability half),
0151 (Ctrl-Shift-4, same resolution chain), 0153/0159/0160 (the pick path)

## Report

Verbatim:

> ASE-L's Results > Direct Plot and also the command Ctrl-4 is bound to in schematic
> are not supporting hierarchy. Once I have run a simulation, I should be able to
> descend within an instance and plot its internal node voltages. Instead I get:
> `ase: no ASE-L session for this design -- Launch ASE-L (Tools menu) or open its
> ngspice_state view first`

Confirmed at `c31fad1d`. Two independent halves, both a "which window / which
session is this?" identity bug, neither of them in the pick code 0161 fixed.

**1. Ctrl-4 asked the wrong question.** `ase::direct_plot_for_current` (and its two
siblings `plot_mode_for_current` / `window_number_for_current`) resolved the session
with `ase::design_of_current` → `ase::session_for_design`, and `design_of_current`
reads `xschem get schname` — which descending changes to the CHILD. The child cell has
no session, so the lookup failed and printed the message above while the session that
ran the simulation sat one level up the very same hierarchy stack.

**2. Results > Direct Plot could not find the descended window.** The menu path goes
`select_on_design` → `ase::ui::design_window` → `ase::ui::raise_design_editor`, which
scans `xschem windows` and matches a window by `lindex $e 4` — `ctx->sch[ctx->currsch]`,
the *current* schematic name. A window descended into the design therefore looked like
it was not holding the design at all, so `design_window` fell through to
`xschem load -gui <top>` and re-opened the top somewhere else, discarding the hierarchy
the user had navigated to — the exact context they wanted to probe.

## Fix

### The ancestor walk (`src/ase.tcl`)

New `ase::session_for_current` returns `{key level lib cell view}`: walk the stack from
`xschem get currsch` up to 0, `xschem get schname $l` → `ase::design_of_path` →
`ase::session_for_design`, first hit wins. A level that resolves to no registered
cellview is **skipped, not fatal** — descending into a cell from outside every library
is ordinary, and its parent may still hold the session. All three entry points now use
it; `ase::launch_for_current` deliberately does NOT (Tools > Launch ASE-L binds a session
to the cellview actually on screen, Cadence's Tools > ADE-L semantics).

**NEAREST ancestor wins, not the top.** A session bound to an intermediate cell
simulates that cell as its deck's top, so names for a pick below it must be measured
from there. `level` is that measuring stick.

New `ase::no_session_notice` is the one honest report, and tells two failures apart:
no level of the stack resolves to a design at all (re-raise `design_of_path`'s own
wording — the shipped symbol-view/unregistered behavior) vs some level resolves but
none owns a session (say so, and say the parents were searched, so a descended user is
not left thinking their parent session was ignored).

### Names measured from the session's level (`ase_window.tcl` + C)

`ase::ui::sod_qualify` gains a third argument `baselvl` (default 0 = the shipped
meaning, so every top-level session is byte-for-byte unchanged), supplied per click by
new `ase::ui::sod_base_level`, which finds where the session's own design sits in this
window's stack. Recomputed per click, not latched when the mode was armed, so
descending/ascending while the pick mode is up stays correct.

- **voltage** — `xschem resolved_net <net> ?level?`. The level had to reach the C:
  `resolved_net()` measured its path from `sch_waves_loaded()`, which is a property of
  whatever raw the *schematic window* has loaded, not of the session's deck. New
  `resolved_net_from(net, from_level)` (`hilight.c`) takes it explicitly; `-1` keeps the
  shipped auto behavior and `resolved_net()` is now a one-line wrapper, so no existing
  caller moves. This also retires 0161's known-limit 1 for the ASE path.
- **current** — new `ase::ui::sod_rel_path`: the current `sch_path` (`.x1.x2.`) minus the
  base level's own `sch_path` (`.x1.`) → `x2.`. Plain prefix arithmetic is sound for an
  *instance* path (a pure prefix chain) and would be wrong for a net (which can resolve
  UP through a port and stop anywhere) — which is why the voltage arm hands the level to
  the engine instead.

### A descended window is no longer invisible (`scheduler.c` + `ase_window.tcl`)

`xschem windows` entries gain a **7th field**: the window's whole hierarchy stack,
`ctx->sch[0]` … `ctx->sch[currsch]`. Appended, so every existing `lindex $e 0..5`
consumer is untouched. `raise_design_editor` now scans exact `current_name` matches
FIRST (a window actually showing the design is the better answer, and that ordering
keeps the shipped behavior byte for byte), then falls back to any window whose stack
contains the path; the raise body is factored into `ase::ui::raise_window_entry`.

## Verification

- `tests/headless/test_ase_hier_plot_0168.tcl` — **31 checks**, new file, green in BOTH
  arms (`--nogui` and under `DISPLAY`). RED before the fix: **19 FAILED / 12 passed**,
  with the shipped-behavior controls (`HL19`, `HL21`, `HL25`, `HL26`) passing throughout.
- Full headless suite (254 files) run against a `git worktree` build of `c31fad1d` and
  diffed: **the only difference is the new file**. Every pre-existing FAIL/FATAL/no-result
  (all GUI-only tests) is identical on both sides.
- GUI arm re-run for `test_ase_hier_pick_0161`, `test_ase_plot`, `test_ase_window`,
  `test_wave_modes`: all pass.
- **Sabotage-verified, ten teeth**, each applied by an assert-the-anchor-was-found
  patcher (never a blind rewrite — the 0154 trap list), C breaks rebuilt:

  | sabotage | caught by |
  |---|---|
  | revert: the ancestor walk only looks at the current level | HL3, HL5, HL6, HL7, HL8b, HL9b, HL12 |
  | opposite: TOP-most session wins instead of nearest ancestor | HL6, HL7 |
  | revert: `sod_qualify` ignores the base level | HL16, HL27 |
  | revert: the current arm uses the whole path again | HL17 |
  | revert: `sod_base_level` always answers 0 | HL14, HL27 |
  | revert: `sod_click` stops passing the base level | HL27 |
  | revert: `raise_design_editor` stops scanning the stack | HL23 |
  | revert: `xschem windows` drops the hierarchy field | HL22, HL23 |
  | revert: the C ignores the explicit start level | HL16, HL20, HL27 |
  | revert: the notice never mentions the parents | HL11 |

- **End-to-end against ngspice-42**, on the `ase_hier` fixture (`xschem netlist` →
  `.save all` → `ngspice -b`): the raw carries `v(x1.x2.mid)` and `i(v.x1.x2.v1)` —
  byte for byte the expressions a descended pick now queues.

## Known limits

1. **The node must be IN the raw.** Direct Plot deliberately writes no `.save` rows
   (Cadence parity, item 13 D2), so an internal node of a descended instance is
   plottable only when the run saved it: a session with NO explicit outputs (ngspice
   then saves everything) or with the Save-All-Voltages flag (`.save all`). With an
   explicit `.save` list and no blanket, the queued trace resolves to nothing and
   `dp_finish` reports a per-trace "cannot plot" — honest, but the cause is the deck,
   not the pick.
2. **Running is still top-only.** `ase::netlist` compares `xschem get schname` against
   the session's design path, so Run from the ASE window while the design window sits
   descended still refuses with "is not the current schematic". Unchanged by this fix:
   the reported workflow is run-then-descend-then-plot, and the queued names are
   top-relative, so they stay correct after ascending.
3. **`launch_for_current` is not hierarchy-aware, by design** (see above). Tools >
   Launch ASE-L on a descended view registers a session for the cellview on screen.
4. ~~Not eyeballed interactively~~ — **eyeballed by the user 2026-07-27, works**
   (run → descend → Ctrl-4 / Results > Direct Plot). Retired.

## Bycatch (NOT fixed here)

`trace_set_vars` (`src/xschem.tcl`) rebuilds `pathlist` on a write to
`XSCHEM_LIBRARY_PATH` by comparing the traced name against the bare string
`XSCHEM_LIBRARY_PATH`. A `set ::XSCHEM_LIBRARY_PATH …` hands it
`::XSCHEM_LIBRARY_PATH`, the comparison fails, and the search path is silently never
rebuilt — an rc file or `--script` that qualifies the name gets no libraries. Found
while building this test's fixture (which is why that file assigns the variable
unqualified, with a comment). One-line fix (`string trimleft $varname :`), left out of
this change to keep it reviewable.
