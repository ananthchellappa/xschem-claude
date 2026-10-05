# Low-hanging fruit queue — derived 2026-10-05, branch `fluid-editing`

Answer to the user's question *"What low hanging fruit is available in any area, not necessarily
calculator"*. Derived by a four-angle survey (wish list, issues + ledger, inert UI, batch PLANs) over
the tree at `062ed56e`, each candidate then adversarially verified by an independent agent that tried
to prove it was already built or did not reach a person. 47 raw candidates, **42 survived**, 3 were
refuted as already shipped, 2 were internal-only.

⚠ This is a snapshot, not a source of truth. Re-verify any item against the tree before building it:
three items the wish list called open turned out to be shipped, and one it called shipped was not.

## Status at the time of writing

| thread | state |
|---|---|
| **IN FLIGHT** — four Tcl-only fixes below (0999, 0925, `add_graph`, the two menu no-ops) | dispatched, red-first, not committed |
| **BLOCKED ON A REBUILD** — 0458 and 1605 | wait until the calculator batch commits; both relink `src/xschem` |
| **IN FLIGHT ELSEWHERE** — PLAN 7.5 stability verbs | repair round running in `src/calculator.tcl` |

**Why the sequencing matters.** 0458 edits `src/Makefile.in`, which obliges re-running `./configure`,
and 1605 is C in `src/actions.c`. Both relink `src/xschem`, and `src/scheduler.c` embeds `__DATE__`
so the binary's md5 moves on every relink even with identical source — which would corrupt the
measurements of any crew running that binary concurrently.

## Tier 1 — the one that harms the branch the user shares

### Issue 0458 — `utils/` is installed by nothing (size S, blocked on nothing)

`make install` never ships the fourteen `.tcl` files under `utils/`, but `src/cadence_style_rc` has
thirteen `source` lines that load them. So anyone who installs and loads the Cadence profile gets an
error at its very first line and loses Find Navigator, Instance Update, bus resize and transpose, the
Cadence clip operations, apply-highlight, the net-highlight style navigator, select-same-cell, toggle
pins/netlabels and the Annotate entries.

**This is invisible to the user because they run from the source tree**, and `fluid-editing` is the
branch they hand to other people — so it is the one defect on this list that bites every recipient
and nobody else.

Area: the `install_shares` list and the `install:` / `uninstall:` rules in `src/Makefile.in`.
⚠ Editing `src/Makefile.in` obliges re-running `./configure`; verify with
`/usr/bin/grep -c <newfile> src/Makefile`, expecting 2 (an install and an uninstall line).

## Tier 2 — user-experienced defects, each blocked on nothing

* **Issue 0999 — Library Manager prompts hang until quit.** Right-click, pick *New cell…* /
  *Rename…* / *Copy view…*, close the name box with the **title-bar X** rather than Cancel: the box
  vanishes, nothing happens, and that command stays stuck waiting for an answer it can never get
  until xschem is quit. Six procs in `src/library_manager.tcl` (`simple_prompt`, `cell_dialog`,
  `view_dialog`, `newview_dialog`, `commit_dialog`, `maintain_picker`). The precedent to copy is
  already in the tree: `libmgr::newlib_dialog` with `libmgr::newlib_vanished`, fixed under 0998.
* **Issue 0925 — saved net-highlight styles silently discarded at every startup.** The dialog
  promises the file loads automatically next session; it does not. `write_net_hilight_style_conf` is
  correct, so the file on disk is good — `load_net_hilight_conf` is the broken reader, called at top
  level during startup. Also explains the command palette re-emphasising that entry every session.
* **`wviewer::add_graph` is outside undo and outside the macro log**, while every sibling
  (`split_strip`, `move_strip`, `move_trace`, `move_traces`, `delete_empty_strips`) is in both. Press
  Add Graph, press `u`, and the undo backs out whatever came *before* while the strip stays. A
  recorded session also replays without the strip.
* **Simulation ▸ View last job data / View last job errors are silent no-ops.** Both bodies in
  `build_widgets` are an `if` with no `else`, so in a fresh session the entries do nothing at all —
  no window, no message, no status line.
* **Issue 1605 — the netlist provenance comment truncates a name at its first parenthesis.** The
  header line that exists to tell a reviewer where a deck came from names the wrong file.
  `sanitized_abs_sym_path()` in `src/actions.c` and its five netlister callers. ⚠ C, so it relinks.

## Tier 3 — small, but each needs something first

* **Waveform-viewer trace context menu has no Delete**, although `wviewer::delete_items` already
  resolves undo, logging, marker remapping and selection for free. Today the only entry is *Move to
  Separate Strip*; the DEL key works but is undiscoverable from the menu. ⚠ Needs
  `tests/headless/test_wave_trace_menu.tcl` — which exists, is unregistered, and prints only
  `RESULT: ALL PASS` with no `OVERALL: ok` — to get the sentinel and a `dcases` entry first.
* **Hover fly-lines, the freeze / pin-snapshot key** (wish new-4, the user's own note: *"70% DONE by
  Claude Code. Needs polish."*). Hover a net, press a key, and the fly-lines stay put while the mouse
  moves away. Semantics already settled in the spec; the key letter is an internal choice. C-side.
* **Hover fly-lines do not start on a bare device pin.** Hovering a MOSFET gate that is not on a wire
  or label does nothing, which reads as the feature being broken on the object most often pointed at.
  `find_closest_pin` exists and the select path already consults it; the fly-line resolve cascade does
  not. Must honour the same `en_pin_select` guard.
* **ASE-L *Save All…* shows a disabled, unexplained "Levels:" field** backed by no state at all. A
  Cadence user reads it as save depth. ⚠ The declared reason it is dead is that adding a state key
  would ripple into a protected byte-identity fixture, so building it means versioning that fixture or
  carrying the depth outside the state schema.

## Needs the user, not the tree

* **The ASE-L menubar's leftmost cascade is a dead "Launch"** whose only entry is the literal label
  `(placeholder)`, greyed and unpostable. In ADE-L that menu is where ADE XL / Explorer / Assembler
  live, so **what belongs behind it is a product question and genuinely the user's.** The multi-run
  capability it would front partly exists already (`ase::campaign_run`,
  `ase::ui::campaign_dialog`, live under Simulation). Either it holds those doors, or it is removed so
  the menubar stops advertising a hole.

## Refuted — do not re-file these

* **Cadence-style Search and Replace** (wish new-9) is **built**; found independently by two sweeps.
* A durable handle for the six non-wire object types (wish old-26 residue) is built.
