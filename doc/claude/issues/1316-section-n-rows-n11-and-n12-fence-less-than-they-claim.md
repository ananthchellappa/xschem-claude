# 1316 — section N's two headline rows fence less than their own wording claims

**Filed by item B2e's Verify-B (sabotage) and Verify-C (adversary) passes,
2026-09-04, against the change B2e itself landed. Measured, NOT fixed.**
Status: **open — a TEST defect in B2e's own new suite section, not a defect in
the shipped code.** The code is correct today; the rows that are supposed to
keep it correct tomorrow are weaker than they read.

This is the batch's own recurring lesson landing on the batch itself: *a suite
fences the questions its author thought of, and a green count is a statement
about the FENCE, not the code.* Section N is green at 102 and two of its rows
would stay green through real regressions.

---

## 1. N11 — the headline adversary row — is laundered by the issue-1292 undo

Row **N11** is the row the driver's brief called *"the row that matters most:
after any sequence of edits, the PDK's declaration is still what the PDK
registered. Attack it; do not assert it."* It drives a five-step storm
(reorder annotation, delete two rows, add a row, delete from summary, apply
after each) and then a `reset` + `apply`.

**All six of its terms are read AFTER that final `reset` + `apply`** — and that
pair is exactly what fires B2e's own issue-1292 undo, which rewrites `params`
back to the pre-apply bytes. So a broken declaration is repaired by the undo
one line before the row looks at it.

Measured under three sabotage variants (scratch drivers
`/tmp/claude-1000/-home-analog-dev-xschem-claude/scratch_B2e_vb/n11probe.tcl`
and `n11probe2.tcl`, Verify-B):

* **SB-RESTAMP-ALWAYS** (the design DD-13 rejected as option (a)'s
  alternative). Mid-storm, after step 1:

  ```
  declared = {gds gds 1} {gm gm 1} {id ids 0}     <- the UNION's order, not the PDK's
  ```

  It stays wrong through every step. N11 does not fire.

* **SB-UNION-WITHOUT-DECLARATION** (`_declared_rows` returns `{}`, i.e. DD-4's
  third input removed). **Mid-storm** `params` is

  ```
  params = {id ids 0} {gm gm 1}          <- the {gds gds 1} triple is GONE
  ```

  and the `.save` card goes with it — **the live DD-4 violation, inside N11's
  own storm** — but N11 reads `ol_triple_in [ol_dkey nmos params] gds` and its
  `_cards_for` leg only after the restore has put it back. N11 does not fire.

* **SB-SEED-READS-PARAMS** (`_decl_state` returns `{0 {}}`, so `_params` falls
  back to `params` for the whole storm). N11 asserts the raw key
  `ol_dkey nmos declared`, which `op_annot::register` preserves whether or not
  anything reads it, plus a post-restore `seed mos` that answers restored
  `params`. A seed reading the wrong field for the entire storm is invisible
  to the row. N11 does not fire.

**Three of the seven sabotage variants should have red N11 and none did.**

### The fix, which is a pure addition of terms to the existing row

Capture N11's terms **immediately after step 4/5, BEFORE the `reset`**, and keep
the post-reset legs as a second term:

* `ol_dkey nmos declared` and `ol_dkey pmos declared`,
* `seed mos`,
* the `gds` triple's presence in `params`,
* the `_cards_for M1 {}` leg.

Verify-B measured that this makes **three** of the seven variants red the row.
No new fixture is needed — the storm already reaches every state.

---

## 2. N12 — the structural fence — is defeated by a variable key

Row **N12** is the row that is supposed to make *"`apply` is structurally
incapable of writing the declaration"* checkable rather than asserted. Its
helper `ol_dictset_lines` counts lines carrying `dict set|replace|update|…`
**and the literal string `declared`**.

A write through a variable key —

```tcl
dict set d $key $value
```

— carries no literal and is **not counted**. That is not a hypothetical shape:
`op_param_lists::_apply_state`, two procs away from `apply` in the same file,
already writes exactly that way.

Nothing evades the row today (measured: `op_param_lists.tcl` has zero
dict-writing lines naming the key; `op_annot.tcl` has exactly one, inside
`op_annot::_declare`). The row is honest about the present and thin about the
future, and its own wording — *"no line anywhere in this file writes the key"* —
claims the stronger property.

### The fix

Assert the property the row names, from the outside: after a storm, compare
`ol_dkey <t> declared` against the value `op_annot::register` was handed, for
every type, rather than counting source lines. A source-text count can only ever
fence the spellings its author enumerated.

---

## 3. What is NOT wrong

* Section N's other thirteen rows behave as documented; the RED-before /
  GREEN-after transition was measured for all thirteen.
* Four of the seven sabotage variants matched their predictions exactly
  (SB-NO-STAMP 8/8, SB-RESTORE-NEVER 1/1, SB-PDK-DOC 1/1, and
  SB-RESTORE-BLIND over-fired rather than under-fired).
* The shipped code is not implicated by anything in this file. Both gaps were
  found by attacking the code from *outside* the suite and finding real
  breakage the suite slept through.

## 4. Still open

Whether to fix both rows in one pass (recommended; §1 and §2 are each a few
lines and need no new fixture) or to fold them into whichever later item next
edits `tests/headless/test_op_param_store_1245.tcl`. Nobody is assigned.

⚠ Any edit to that suite must keep every new row **above line 2788**, so item
B5's preserved patch hunk `@@ -2850,6 +2850,353 @@` still applies —
`git apply --check doc/claude/op_param_batch/B5_working_tree_REFUTED.patch` is
an acceptance row, not a courtesy.
