# 0224 — `test_pin_rename_propagate.tcl` gaps: the `with_quotes` 0-vs-3 split, and two of five warning paths

Status: **OPEN**
Severity: low (regression-guard gaps, not live bugs)
Applies to: `tests/headless/test_pin_rename_propagate.tcl` (47 checks, all passing), which
arrived on `fluid-editing` via merge 3 (`958ada03`).
Found by: the merge-3 interaction audit.

## Gap 1 — the `with_quotes` split is untested

`doc/claude/specs/pin_rename_propagation.md` calls out the compare-vs-write asymmetry as the
thing that is *"easy to get backwards"*: matching uses the **evaluated** `lab`
(`with_quotes=0`, at `src/editprop.c:974, 1011, 1050, 1143` and `src/scheduler.c:11484`)
while the write uses the **raw** text (`with_quotes=3` at `src/editprop.c:1051` →
`subst_token` at `:1076`), so an expression-valued pin name and its labels track together
instead of the labels freezing to a snapshot.

**None of the 47 checks exercises it.** The shipped `xschem_library` has no
`lab=tcleval(...)`, so the suite stays green whichever way the pair is wired.

Missing scenario: set a Tcl global (`set ::EE FOO`), place `ipin lab=tcleval($::EE)` and
`lab_pin lab=FOO`, rename the pin; and separately rename a plain pin *onto*
`tcleval($::EE)` and read the label back with `getprop instance_notcl`.

*Correction to the original filing*: a swap at `editprop.c:1050/1051` alone cannot strand
labels. `newlab_cmp` is never the target-selection key — targets come from
`strcmp(cand, oldlab)` at `:1011-1013`, both sides `with_quotes=0`. A `1050/1051` swap can
only (a) write the evaluated form into the labels (the freeze the spec warns about) and
(b) mis-decide `PRR_SAME` / `PRR_GLOBAL_NEW` / `PRR_MERGE` on raw text. Stranding would need
the compare sites (`:974`, `:1011`) or the callers' `old_lab` captures (`:1143`,
`src/scheduler.c:11482`) flipped — equally untested. So "green either way" holds, just for a
wider set of mutations than first stated.

## Gap 2 — two of the five warning paths assert only the non-mutation

The warn block is `src/editprop.c:1059-1073` (condition `:1059-1060`, the `statusmsg` pair
`:1063-1064`); the status strings are at `:949` and `:953`.

`PRR_AMBIGUOUS` (scene `P7`: `ipin lab=A`, `opin lab=A`, `lab_pin lab=A`, then
`xschem setprop instance p1 lab AA`) and `PRR_SELECTED` (scene `P10`) both assert that the
labels did **not** move. Neither asserts `[info_has "another pin still has that name"]` /
`[info_has "a matching label is selected"]`.

A regression that silences either refusal ships green: the user renames a pin, nothing happens
to the labels, and nothing on either channel says why — the pre-feature silent-disconnect
behaviour the spec set out to eliminate.

*Narrowing*: in the `change_index` `+`/`-` case the caller's own loop renames the selected
label itself, so a silenced `PRR_SELECTED` warning **there** is benign. The genuine
user-visible loss is (a) `PRR_AMBIGUOUS` on a sheet with a duplicated port name, and
(b) `PRR_SELECTED` reached by an ordinary single rename while a matching label happens to be
selected — the path `P11` exercises.

## Suggested fix

Add the two `info_has` assertions to `P7`/`P11`, and one `tcleval`-valued scene covering both
directions of gap 1. Cheap; both are pure additions to an already-passing file.
