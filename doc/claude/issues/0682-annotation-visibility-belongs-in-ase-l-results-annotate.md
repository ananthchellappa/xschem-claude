# 0682 — annotation visibility belongs in ASE-L `Results > Annotate`, not the schematic's View menu

STATUS: **RULED BY THE USER 2026-08-24. Not yet implemented.**
Reverses: [0457](0457-annot-show-has-no-stock-affordance.md) decision (b).
Supersedes: the wording question raised by [0678](0678-branch-currents-are-gated-by-alt-6-but-belong-to-6.md) — see §5.
Related: 0613, 0614, 0615, 0621, 0678, 0681.

---

## 1. The ruling, verbatim

Asked which wording the `View > Show / Hide` checkbutton should carry, the user
rejected the question's premise:

> What is View > Show? We want to be like Cadence. It needs to ONLY be in
> ASE-L > Results > Annotate > Operating Point Info.

Asked what a user should do who has annotations on screen with no ASE-L window
open:

> results (including OP info) only make sense when there is a result loaded -
> meaning an ASE-L is active, to which this schematic is "bound". We're trying to
> be the same as Cadence. Departures from legacy Xschem are OK.

Two rulings, and the second is the load-bearing one.

## 2. What this reverses, and why that is not a criticism of 0457

0457(b) was ruled **by the same user two days earlier**, on 2026-08-22: the
control was to be "a View-menu checkbutton pair". It was implemented that day and
has shipped since. This issue reverses that placement.

It should be recorded as a **reversal, not a repair**. 0457(b) answered the
question it was asked — *where can this control live without new C code* — and
answered it correctly. The question it was not asked, and which the user has now
answered, is *where would a person coming from Cadence look for it*. Those have
different answers, and only the second one matters for the product this is trying
to be.

The same shape as 0678, which reversed 0614's decision D4 a day after the same
user ratified it. A ruling reversed on new grounds is the process working.

## 3. The state of the destination — it is a stub

`src/ase_window.tcl:530-535`:

```tcl
menu $top.mb.results.annotate -tearoff 0
$top.mb.results.annotate add command -label {Operating Point info} \
  -state disabled
$top.mb.results.annotate add command -label {DC Node Voltages} \
  -state disabled
$top.mb.results add cascade -label Annotate -menu $top.mb.results.annotate
```

Both entries are **permanently greyed out**. `grep -n 'results.annotate'` returns
only these four lines and nothing anywhere calls `entryconfigure` on them. There
is no code behind either item.

**So this is not a move.** It is: build the two ASE-L controls for the first time,
then delete the View pair. Anyone estimating this as "relocate two checkbuttons"
will be wrong by the whole implementation.

## 4. What the second ruling settles

The obvious objection to an ASE-L-only control is the orphan case: annotations on
a schematic whose ASE-L window has been closed, with no menu anywhere to switch
them off. Outside the cadence profile there are no `6`/`Ctrl-6` chords either, so
the user would be back to editing `~/.xschem/xschemrc` — **which is the exact
complaint 0457 was filed about.**

The user's answer dissolves the case rather than handling it: results only exist
while a result is loaded, and a loaded result means a live ASE-L session the
schematic is bound to. There is no "annotated schematic with no session" state to
design an escape hatch for. If one is reachable today, that is a **binding
defect** to be found and fixed, not a menu to be added.

That is a stronger ruling than any of the three options offered, and it is why
none of them was chosen. It also explicitly licenses divergence from stock
xschem: *"Departures from legacy Xschem are OK."*

**Implementation consequence, and it must be verified rather than assumed**: the
annotation visibility state has to be reachable from, and meaningful within, the
ASE-L session that owns the result. `xctx->annot_show` is currently a per-context
C field with a mirrored Tcl variable, owned by nothing. Whether it should become
session-scoped is the first thing to measure. **Do not assume it already is.**

## 5. This supersedes 0678's wording question

Rule debt `[0678]` asks whether the bit0 checkbutton should read *"Show device OP
/ branch current annotation"* (shipped) or *"Show device OP annotation"*. Under
this ruling **the checkbutton it is asking about ceases to exist**, and the ASE-L
entries already carry Cadence's own names — `Operating Point info` and
`DC Node Voltages` — which name neither subclass.

The debt is left standing, because a rule debt clears only when the user says so
and no other command may convert or discharge one. It is annotated here as moot.
It should be cleared with `owed.sh clear rule 0678` at the user's word, not by
this file.

## 6. Open, to be decided by measurement rather than asked

Recorded so they are not silently invented during implementation:

1. **Checkbutton or command?** Cadence's Results > Annotate is a mode selection,
   and the shipped stubs are `add command`. The two annot bits are booleans, so
   `add checkbutton` bound to the mask is the honest widget. Assume checkbutton
   unless the ASE-L menu conventions say otherwise.
2. **Per-session or global?** See §4. Measure `annot_show`'s current ownership
   before choosing.
3. **What enables them.** They are `-state disabled` today; something must decide
   live-vs-greyed. The natural test is "this session has a loaded result", which
   is the same predicate §4 leans on — so it wants to exist exactly once.
4. **The `6` / `Alt-6` / `Ctrl-6` chords stay.** The user confirmed on a real
   bench that all three behave correctly (0678). Nothing here touches them.
5. **`annot_show_menu_sync` / `annot_show_menu_apply`** (`src/xschem.tcl`) exist
   to serve the View pair and are pinned by `test_annot_show_menu.tcl` rows
   A4/A5/A19. Deleting the pair without re-pointing those is how the suite goes
   green over a control nobody can reach.
