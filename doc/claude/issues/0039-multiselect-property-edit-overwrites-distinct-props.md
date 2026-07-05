# Issue 0039 — Multi-select Edit Properties silently overwrites each object's distinct properties

**Opened:** 2026-06-26
**Status:** ✅ FIXED 2026-06-30 (commit a5df8d83) — verified 2026-07-01. `editprop.c:1468-1470` now forces `preserve_unchanged_attrs=1` when `xctx->lastsel>1 && type!=ELEMENT`, before the `switch(type)`, so all six non-instance branches take the per-token preserve path; regression at `tests/headless/test_editprop_preserve.tcl` (DISPLAY-gated). No further action.
**Severity:** HIGH — silent data loss (user-entered net labels / attributes destroyed with no cue).
**Branch:** `fluid-editing`.
**Source:** `/code-review high` this session (workflow `wf_1a6ce6c4-0d9`), finding #1 (CONFIRMED).
**Affects:** `src/editprop.c` `edit_property()` (~:1373) and the six non-instance multi-edit paths
— rect (~:294), line (~:391), wire (~:457), arc (~:512), poly (~:594), text (~:763);
`apply_symbol_prop` (`only_different=1`, **instances only**); `preserve_unchanged_attrs` default 0
(`src/xschem.tcl:14466`). Related: [[slick-property-forms]].

---

## 1. Symptom

Select several **non-instance** objects that carry *distinct* properties (e.g. wires/labels with
different `lab=` net names, or rects/texts with different attributes), open **Edit Properties**,
change one field (or nothing) and confirm. Every selected object's entire property string is
overwritten with the **first** object's edited text — the others' distinct net labels / attributes
are silently lost. No `*`-prompt distinction, no warning.

## 2. Root cause

`edit_property()` no longer forces `preserve_unchanged_attrs=1` when multiple objects are selected.
The re-establishment of that guard lives in `apply_symbol_prop` (with `only_different=1`) which covers
**only the instance path**. The six non-instance object kinds still wholesale-overwrite their property
string when `preserve_unchanged_attrs==0`, and that variable **defaults to 0**
(`xschem.tcl:14466`). So a multi-select edit of wires/labels/rects/lines/arcs/polys/texts blasts the
first object's string onto all of them.

## 3. Fix sketch

Restore the multi-select auto-preserve at the dispatch point: in `edit_property()` force
`preserve_unchanged_attrs=1` (or the `only_different` path) whenever `xctx->lastsel > 1`, for **all**
object kinds — not just instances. Alternatively apply the `only_different`/preserve logic uniformly in
the six non-instance branches. Add a regression that selects two wires with distinct `lab=`, edits one
field, and asserts the *other* wire keeps its label.

## 4. Acceptance

Multi-selecting objects with differing properties and editing one field preserves every other object's
unchanged attributes; only the explicitly-changed field propagates.
