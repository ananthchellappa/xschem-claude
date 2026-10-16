# 1663 — Direct Plot now follows ASE-L's destination drop-down, whose default is Replace

**STAMP:** `v1 claim=open tree=fc4c4ab9 stamped=2026-10-16 fix=none open=1 by=driver`

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

Nothing is reverted pending the answer.
