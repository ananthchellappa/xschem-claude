# 1663 — Direct Plot now follows ASE-L's destination drop-down, whose default is Replace

**STAMP:** `v1 claim=fixed tree=f3976c1b stamped=2026-10-16 fix=taken open=0 by=driver`

A user-visible change made by `fc4c4ab9f` (the viewer has no plot destination; each source
owns its own), recorded here because it needs the user's ruling, not a write-up.

## What changed

Before: an ASE-L Direct Plot went through the Waveform Viewer's own remembered destination,
which defaulted to **Append**, so successive Direct Plot batches accumulated in the target
subwindow.

Now: `ase::ui::dp_finish` passes `ase::ui::plot_dest` (the ASE-L status-bar drop-down, state
key `plot_dest`), the same setting that governs `~` and the run-end auto-plot. That drop-down
defaults to **Replace** (`ase::ui::plot_dest_label` maps an empty or unknown value to Replace),
so **each Direct Plot batch (one per ESC) now clears the target subwindow first**. A user who
wants Direct Plots to pile up must pick Append.

Spec: `doc/claude/specs/ase_l.md` R-OUT15, the Direct Plot bullet. Fence: band PO16k of
`test_ase_plot_outputs`. Rows restated to pick Append first: `test_ase_plot` P4,
`test_wave_modes` MG12.

## The question for the user

Is Replace-by-default right for Direct Plot? In ADE-L the Plotting Mode drop-down governs
Direct Plot too; whether its default there is Replace is a Cadence fact the user knows.

- **(a) Keep it** (ships now): one drop-down, ADE-L's shape, default Replace for every source.
- **(b) Default ASE-L's drop-down to Append** instead, for every source (`~` and the run-end
  plot would then accumulate too).
- **(c) Direct Plot keeps its own Append** and ignores the drop-down: restores the old
  behaviour but gives ASE-L two destination rules.

Nothing was reverted pending the answer.

## Ruling (user, 2026-10-16): option (a), plus an rc default

> "Yes, Direct Plot follows the drop-down; default is Replace. When user changes it, ensure
> there is logging in CIW so user knows what to put in the rc file to get what she wants as
> default"

Built on top of `f3976c1b`:

- **(a) is kept**: Direct Plot, `~` and the run-end plot all follow ASE-L's drop-down, default
  Replace.
- **The rc default** is the new variable `ase_plot_dest` (`set_ne` in `src/xschem.tcl`; values
  `append`, `replace`, `newsubwin`, `newwin`, labels and any case accepted; empty = Replace;
  anything else = Replace with one CIW warning per bad value), read by
  `ase::plot_dest_default`. A session whose state saved no choice (`plot_dest {}` or absent,
  every committed `.state`) starts on it; a session that saved a choice keeps it. A choice
  equal to the rc default is still stored as `{}`, so picking it back leaves the session
  clean; any other choice, Replace included under a non-Replace rc, is written out.
- **The CIW line**: a user change of the drop-down (`ase::ui::plot_dest_picked`, the
  `<<ComboboxSelected>>` handler) prints ONE line through `ase::echo`, e.g.
  `ase: plot destination = Append (xschemrc: set ase_plot_dest append)`. A programmatic
  `ase::ui::set_plot_dest` (a replayed action log, a script, a CIW-typed call), Load State
  and Revert print none.
- **The Calculator's W13** gets the same treatment with its existing `calc_plot_dest`
  (default Append, unchanged): the W13 sentence, which `calc::status` already copies to the
  CIW, now reads `Plot destination: Replace (xschemrc: set calc_plot_dest replace).`; a
  rebuild prints nothing; a garbage value is Append with one CIW warning.

Fences: band RC of `tests/headless/test_ase_persist.tcl` (both arms), rows PD4/PD5 of
`tests/headless/test_ase_window.tcl` (display), band PL6 of `tests/headless/test_calc_plot.tcl`
(display). Specs: `doc/claude/specs/ase_l.md` R-OUT15, `doc/claude/specs/calculator.md` R601.
