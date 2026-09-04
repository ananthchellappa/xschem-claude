# 1300 — the RDW's keys 1, 2 and 3 select a list IDENTITY and narrow no CONTENT

**Status: FILED, NOT FIXED.** Found by item **B4** while implementing the keys.
This is B4's own **E question** and it is on the owed ledger.

> **⚠ ITEM B4 WAS REVERTED (status F, 2026-09-04)** on issues **1303**, **1304**
> and the two holes in `PLAN.md`'s B4 table. The keys described below are
> therefore **not in the tree**; they are in
> `doc/claude/op_param_batch/B4_working_tree_REVERTED.patch`. **The question
> this issue asks is unaffected by the revert** — it is about what keys 1, 2
> and 3 should MEAN, and the next crew to apply that patch inherits it
> unchanged.

## What was measured

`src/rdw.tcl` at `724c4160`..`735ea26e` renders a block from
`rdw::format_answer ans ctx`. **`format_answer` takes no list argument at all**,
and the file names the list store nowhere — row **S1** of
`tests/headless/test_rdw_window_1245.tcl` is a hard structural fence that
forbids the token in this file. So keys 1, 2 and 3 as shipped by B4 produce
**byte-identical blocks**; the only thing that differs is `::rdw::listkind`
(and therefore the button greying that reads it).

The spec's B4 table (`doc/claude/specs/op_param_lists.md` §4.2) says key 1 shows
the descriptor's annotation list, key 2 the summary list and key 3 everything —
i.e. **content narrowing**. No item in `doc/claude/op_param_batch/PLAN.md` owns
that work: B4's Do cell does not mention it and B5's Do cell is buttons and
scope dialogs.

## Why B4 did not take it

Ladder L1, invariant **I1** — one builder, several consumers. The narrowing has
exactly one definition in this tree today: the list store's `effective`, plus
ruling **DD-6**'s display key that item B2b built. Three options were costed:

* **(a) filter inside `rdw.tcl` from `op_annot::descriptor`'s `params`** — no
  fence violation, but a **second** definition of "the annotation list" beside
  DD-6's, which is precisely the silent drift I1 exists to prevent.
* **(b) call the list store's `effective`** — reds row S1 and inherits issue
  **1278**'s unbounded-glob freeze on a path a key press reaches.
* **(c) print a `list: annotation` label in the block** — worse than silence: a
  label naming a list whose content is identical for all three *implies* a
  narrowing that did not happen. That is the DD-1 failure shape.

**Taken: none of them.** The keys select the identity through `rdw::set_list`,
which is what PLAN's B3 section already requires of B4, and the narrowing waits
for the item that owns the store.

## The question for the user

Should key 1 / key 2 narrow what the block PRINTS, and if so, does that
narrowing come from `op_param_lists::effective` (one definition, but reds S1
and needs 1278 fixed first) or from the DD-6 `shown` key the sheet already
draws from?

## Where it should be fixed

Item **B5**, which is the first item allowed to touch the list store, or a new
item after 1278 is closed. Row **K11** of `test_rdw_window_1245.tcl` pins
today's answer (zero occurrences of the store's namespace in `src/rdw.tcl`), so
whichever way this is ruled, the fix reds that row rather than passing in
silence.

---

## UPDATE, 2026-09-04 — the keys are still not in the tree, and this ruling gains a THIRD sentence to judge

Items **B4** and **B4-2** were both refuted and reverted, so **nothing above is
running code**: `src/rdw.tcl` and `src/cadence_style_rc` are byte-identical to
`735ea26e`, bare `1`-`4` still reach C's `logic_set`, and this ruling is owed
against the preserved patch
(`doc/claude/op_param_batch/B4-2_working_tree_REVERTED.patch`), not against
behaviour the user can go and press.

**B4-2 proposes a third sentence on the same CIW channel**, and it is the only
one a user should never see:

> Results window: this build cannot report the un-snapped mouse position, so a
> click cannot be resolved to the device under the cursor - press ESC to leave.

It fires only when `xschem get mousex` / `mousey` are missing — a Tcl half newer
than the binary. **The choice was to REFUSE rather than fall back to the
grid-snapped pair**, under invariant **I3**, because that fallback *is* issue
**1303**: measured on the shipped `cmos_inv.sch`, `175.175 -199.612 → M1` and
`180 -200 → R1`, with 0.5% of a whole-sheet sweep naming a different device
silently. **Ratify the refusal, or say it should fall back and be wrong
quietly.**

No new debt id was minted for it; it is on this one. Rule debt **1300**.
