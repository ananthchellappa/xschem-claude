# 0171 — Waveform viewer: Clear All (Ctrl-D) — delete everything, start from scratch

**Status:** IMPLEMENTED (not pushed)
**Branch:** fluid-editing
**Area:** ASE waveform viewer (`src/wave_viewer.tcl`), the shipped chord profile
(`src/cadence_style_rc`, documentation only). Pure Tcl — no C change.
**Requested by:** user, 2026-07-27.
**Spec:** `doc/claude/specs/waveform_viewer.md`, "Clear All (issue 0171)".
**Reference:** `doc/claude/code_analysis/waveform_subsystem_reference.md` §8, §13.
**Tests:** new `tests/headless/test_wave_clear_all.tcl` — `CA1`-`CA3` (no
window, run under `--nogui` too) + `CG0`-`CG7` (GUI, self-SKIP without a usable
DISPLAY): **54 checks**. `tests/headless/test_wave_viewer.tcl` 292 and
`tests/headless/test_wave_modes.tcl` 174 unchanged and green.
**Related:** 0151 (plot modes / target strip — the state this feature must
retain), item 13 (the auto-plot strip it must not resurrect).

## 1. What was asked

Verbatim:

> User should be able to press CTRL-D (should be remappable using bind command
> in rc file) in Waveform Viwer to "delete all and start from scratch". Only one
> graph element should remain, empty. The plot mode should be retained (multi vs
> single). And the associated Tcl command should be logged to CIW in replayable
> form

## 2. What shipped

`wviewer::clear_all ?token?` (`src/wave_viewer.tcl`) — optional token like every
other command in that section ({} = the viewer window owning the current xschem
context). Returns 1, or {} plus a CIW error when no viewer resolves. Reachable
three ways: the **Ctrl-D** key, **Graph > Clear All** (accelerator `Ctrl+D`), and
the command itself typed in the CIW.

**Gone:** every graph and every trace, and the `auto 1` marker with them.
**Kept, deliberately:**

| kept | why |
|---|---|
| plot mode (single/multi) | the explicit requirement — a user working in multi-plot keeps working in multi-plot after a clear |
| Shared X, cursor/readout mirrors | window options, same argument as the mode |
| the **loaded raw data** | `xschem raw clear` would also kill every `raw add` expression vector and force a re-run; the point of a clear is to re-pick from the SAME results |

The surviving strip is a plain `empty_graph`, **not** the auto-plot strip. Making
it tool-owned would let item 13's always-replace rebuild silently wipe whatever
the user hand-picked into the one visible strip — `plan_plot` excludes the auto
strip as a landing site for exactly that reason. A later auto-plot run therefore
appends its own strip (`ensure_auto_graph`), leaving the empty one at index 0.

The target strip resets to 0 (the only strip there is).

## 3. Why the key lives on a BINDTAG, not on the canvas

`wviewer::strip_bindings` **sweeps every widget-level sequence** on a viewer
canvas — that is the item-11 D2 mechanism that keeps schematic editing verbs out
of a read-only graph window, and it also clears anything
`clone_canvas_bindings` copied from the main `.drw`. So the two obvious
placements both fail: a widget-level default would have to be re-installed after
every sweep, and the repo's usual rc idiom (`bind .drw <seq> {...; break}`)
never survives into the viewer at all.

The default is therefore installed on a shared **`WaveViewer` bindtag**
(`wviewer::install_default_binds`), and `strip_bindings` inserts that tag at
**index 1** of the canvas's bindtags — right after the widget itself, so
`key_filter` keeps first refusal and the `Canvas` class bindings still come last.
`key_filter` never `break`s, so a key it swallows still reaches the tag.

Remapping from any rc file (`~/.xschem/xschemrc`, `cadence_style_rc`, a
`--script`), documented in `src/cadence_style_rc` next to the Ctrl-4 / Ctrl-Shift-4
entries:

```tcl
bind WaveViewer <Control-Key-d> {break}                      ;# drop the default
bind WaveViewer <Control-Key-r> {wviewer::clear_all_at %W; break}
```

Two rules make that work and both are asserted (`CG6`):

- **rc wins.** Defaults are installed **once**, at the first viewer open, and
  only for a sequence nothing has bound yet — rc files are sourced long before
  any viewer window exists.
- **disable with `{break}`, not `{}`.** An empty script *deletes* a Tk binding,
  which is indistinguishable from "never bound" and would simply be re-defaulted.

`clear_all_at %W` resolves the token from the **event's canvas**, not from the
current xschem context: a key can arrive on a viewer Tk has focused before the C
side switched context to it, and clearing "whatever context is current" would
then wipe the wrong window.

## 4. Logging

Through the existing `wviewer::log_action` seam (`xschem log_action`, mirrored
into the CIW), the same one the 0151 mode/target commands use:

```
wviewer::clear_all sky130_tests/test_nfet_final/ngspice_state1
```

Resolved, explicit token, so replay does not depend on which window is active at
replay time. Logged on **every** successful call — unlike `set_plot_mode` /
`set_target_strip`, which log only on a real change. A clear is a destructive
gesture: a replay that skipped a "redundant" one would rebuild a different window
whenever the gesture was not in fact redundant. `CG3` replays the logged line and
asserts it reproduces the state.

## 5. Receipts

- `tests/headless/test_wave_clear_all.tcl`: **54/54** (3 pure + 51 GUI).
- Sabotage-verified (memory `green-but-hollow`), three separate breaks:
  removing the bindtag insertion → `CG4` ×3 red (and `CG5`/`CG6` self-SKIP, no
  key delivery); making `clear_all` not rewrite the graph list → 9 red;
  dropping the log line + letting `install_default_binds` overwrite an existing
  binding → 7 red.
- `tests/headless/test_wave_viewer.tcl` 292/292 (the D2 sweep-completeness leg
  `G1s` included — the tag adds no widget-level sequence), and
  `tests/headless/test_wave_modes.tcl` 174/174.
- **Not asserted, stated:** pixels. That a cleared viewer *renders* as one empty
  grid is eyeball-only, like every other wave rendering.

## 6. Eyeball status

PENDING — not yet confirmed by the user in a real interactive session.
