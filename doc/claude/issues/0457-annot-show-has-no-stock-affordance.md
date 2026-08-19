# 0457 — `annot_show` has no stock (non-cadence-profile) control

Status: OPEN — this is step S8's status-E question.
Found: S8 of doc/claude/specs/op_annotation.md.

S7 gave `hide=op` / `hide=opvolt` teeth behind the `annot_show` mask and left the
mask at 0 with nothing in a running session able to write it. S8 supplies three
writers:

  * `6` / `Ctrl-6` / `Alt-6` in the **cadence profile** (src/cadence_style_rc),
  * and, for everyone, `xschem set annot_show 1` inside the two shipped
    **Annotate Operating Point** menu items (decision D8).

S8 decision D9 ratified the default of 0: with no raw loaded, mask 1 paints a
block of label-only rows on every carrier at startup, and S10 will multiply that
across every PDK FET, so a resting state the user leaves with one keystroke is
the least surprising one.

**THE UNRATIFIED RESIDUAL, which is the ledger question.** Outside the cadence
profile there is still no *control*: the two Annotate-OP menu items are on-ramps
with no off-ramp short of editing `~/.xschem/xschemrc`, and the three chords are
invisible to `xschem bindings dump` so they cannot be remapped the way every
other action can (S8 decision D10).

> Should `annot_show` get a first-class stock control — a View-menu pair of
> checkbuttons, or three registered C actions in `keybindings.csv` so the chords
> are remappable — or is the cadence profile the intended home for this feature?

Answering it needs a C action and a build, which S8's rc-only, no-build scope
excluded. Recorded here so the decision is made once, deliberately.
