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

## 6. Follow-up (same day): the cleared strip must GET USED

Reported after the first drop, verbatim:

> I open a Waveform Viewer and that has plots, do CTRL-D to clear it and have
> just one graph element. Then, in the schematic window, I do CTRL-SHIFT-4 to go
> into multi-plot mode. Then, I do CTRL-4 to enter select-signals-to-plot command
> mode, and choose some signals. When I press ESC, they are plotted, but, in the
> Waveform Window, there is one empty strip at the top

Correct, and not really a Clear-All bug: **multi-plot appended unconditionally**
(`plan_plot`, issue 0151 D2), so the cleared strip — or any strip made with
Graph > Add Graph — could never be filled and stayed as a blank band, shrinking
every real strip. Single-plot hid it because it lands in the target, which
`clear_all` resets to that very strip.

**Fixed in the landing policy, not in `clear_all`:** an empty strip is a place
to plot, so a batch fills the empty strips first (index order) and appends only
what is left over.

- new PURE `wviewer::empty_graph_indices {gs {auto -1}}` — strips with no traces,
  excluding the auto strip;
- `wviewer::plan_plot` gains a 6th optional arg `empties` (omitted = none, so
  every pre-existing call site and test keeps its old meaning) and re-sanitizes
  it — in-range, non-auto, deduped, sorted;
- multi: the batch takes up to *n* empty strips plus however many it must
  create; single: an explicit usable target still wins, reuse only resolves the
  "target unusable" case (empty stack / target is the auto strip);
- both callers (`plot_signals`, `predict_colors`) pass the same list, so the
  Direct Plot picker's predicted colors cannot drift from what lands;
- `plot_signals` now moves the target (single mode) to the strip the batch
  actually landed in, reused or created — idempotent, so no spurious log line.

Result for the reported flow: clear → multi-plot → 3 signals → **3 strips, no
blank band**.

### 6b. Second follow-up (same day): newest on top

Requested right after: *"in multi-plot mode, new strips are on top (not bottom)
… v1, v2, v3 — v3 will be on top, not v1"*. So a multi-plot gesture now grows the
stack **upward**, and the batch is laid out **newest-first**: `v1 v2 v3` reads
`v3, v2, v1` top-down.

`plan_plot`'s multi arm now computes its landing sites in the **post-insert**
index space (created strips are `0..new-1`, everything already on the canvas is
`+new`) and deals the picks **bottom-up** — pick *k* takes the *k*-th site from
the bottom. It cannot carry an "insert at the top" flag without changing the
result dict shape every caller and test compares, so the insert lives in the
indices and **`plot_signals` performs the actual front-insert**; a caller that
appended would scramble the batch. Because inserting renumbers every strip,
`plot_signals` also shifts the stored target by `new` — multi-plot still never
RE-targets, but the marker must not drift onto a different strip.

Two consequences worth knowing: the model's strip order is **no longer pick
order**, so a test comparing predicted vs assigned trace colors must pair them
**per signal** (`MG6d`, `CG8` now do); and with Shared X on, the x-range master
(strip 0 at regenerate time) is the newest strip rather than the oldest.

Tests: `M3` multi legs rewritten to the new indices, `MG6`/`MG12` to the new
layout, `CG8` asserts `p3, p2, p1` top-down. Sabotage: dealing top-down instead
of bottom-up → 2 + 14 red; appending instead of front-inserting → MG6 red plus a
hard abort on the scrambled model.

**Tests:** `test_wave_clear_all.tcl` `CG8` (the flow end-to-end, plus a
fixture-teeth check that the pre-clear model really held traces);
`test_wave_modes.tcl` `M3` (7 new pure legs incl. the Clear-All shape and the
sanitizing), new `M3b` (`empty_graph_indices`), and `MG6`/`MG12` **updated to
the new contract** — they asserted the old unconditional append, and `MG7` now
builds its own 4-strip fixture instead of inheriting whatever the landing policy
left. 67 + 193 checks green; test_wave_viewer 292 and test_ase_plot 145
untouched. Sabotage: forcing the reusable set to {} → 5 red in the clear test,
8 in the modes test.

## 7. Eyeball status

PENDING — not yet confirmed by the user in a real interactive session.
