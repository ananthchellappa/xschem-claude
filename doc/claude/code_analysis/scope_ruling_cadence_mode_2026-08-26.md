# Scope ruling, 2026-08-26 — legacy xschem annotation surfaces are OUT OF SCOPE

Given by the user during the first eyes-on annotation sitting, verbatim:

> (9) "Try the refusal" - I am not interested in testing legacy Xschem behavior.
> I am interested solely in Cadence-compatible mode till we get the feature done
> for the prime use-case.

## What it settles

The **prime use-case** is: ASE-L session → `Netlist and Run` → `Results >
Annotate` (and the `6` / `Alt-6` / `Ctrl-6` chords). Everything reached only
through stock xschem's own menus is *not* on the critical path until that works
end to end.

Concretely **deprioritised** (not closed — deprioritised):

* `Waves > Op Annotate`'s refusal notice when no ASE-L session is bound
  (issue **0683**, and parts 1–2 of look debt
  `[0683_0684_annotation_binding_…]`).
* `Simulation > Graphs > Annotate Operating Point into schematic`, same.
* The wording and placement of any notice those two emit.

**Still fully in scope**, because they are on the prime path:

* parts 3, 4 and 5 of that same look debt — the **second-run numbers** check
  (issue 0684), annotating with a waveform graph loaded, and closing the session
  leaving the sheet un-annotated (issue 0686);
* everything in look debt `[0682_ASE-L_Results___Annotate…]` except its part 3,
  which the user confirmed on 2026-08-26 (see below);
* the greying predicate — issue **0838**, found in this same sitting.

## What the sitting confirmed as CORRECT

> (10) does show the "Show hidden texts" but not the annotation check items

That is part 3 of the 0682 look debt and it **passes**: `View > Show` keeps
`Show hidden texts` and no longer carries the two annotation checkbuttons, which
is exactly what the user's own 0682 ruling asked for.

It also makes two ledger entries **stale**, because they ask the user to look at
a control that must not exist any more:

* look debt `[annot_show_View_Show_checkbutton_pair__0457b_]` — *"Open View >
  Show: two new boxes under 'Show hidden texts'"*. Those boxes are gone by
  ruling. **Recommend `clear look`; the user's word is the only thing that
  clears it.**
* the trailing half of look debt
  `[0678_branch_currents_moved_from_Alt-6_to_6]` — *"Also read the two View >
  Show labels"*. The rest of that debt (the chord behaviour) stands.
* rule debt `[0678]` — the View label **wording**. Already recorded as MOOT
  under 0682; this sitting is the direct observation confirming it.

## What the sitting FAILED

Part 1 of the 0682 look debt — *"With NO run yet, both must be GREYED"* — failed
on the bench and produced issue **0838** (a failed run left the entries live and
annotation painted the previous run's numbers). Fixed the same day; the debt does
**not** clear on that, it re-queues as look debt
`[0838_failed_run_must_grey_Results_Annotate]`.

**This is the look ledger working exactly as designed.** Twenty-eight passing
checks did not find it; one person looking at a screen for ten minutes did.
