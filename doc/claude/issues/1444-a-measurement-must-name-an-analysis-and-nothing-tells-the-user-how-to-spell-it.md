# 1444 — a measurement must name an analysis, and nothing tells the user how to spell it

**Design issue, filed by the driver on the user's instruction.** Not a defect report: this
is the surface that has to exist before ⚖ **R6**'s per-analysis identity is usable by a
person, and it is filed rather than built because **the handles it would list do not exist
yet**.

**Branch:** fluid-editing. **Raised by the user**, 2026-09-13, while ruling ⚖ R6:

> *"also plan for a way for measure statements (pending work) that could be used in the
> calculator to refer to different analyses. It should be easy for a user to find out how
> to refer to different analyses for purposes of building measure statements. One way could
> be, where we currently have (in ASE-L UI) Analyses > Choose, we can add Analysis > List
> which will dump one liners on each of the enabled analyses. Just thinking aloud here. If
> there is a better way, you may pursue that."*

## Why this is a real gap and not a nicety

Three things arrive at once and none of them works without a **name the user can see**:

* ⚖ **R6 — ANSWERED 2026-09-13, add per-row identity.** One bench may now hold two DC
  sweeps, or a DC sweep and a temperature sweep. The moment there are two of a type, *"the
  DC sweep"* stops being a reference.
* **`PLAN.md` §8a's measurement rows already assume it.** Every example row in the plan
  carries **both** an analysis type **and** a handle:
  `{name pm analysis ac id a1 kind param …}`. The plan has been written against a naming
  scheme that was never specified and never surfaced.
* **Stage 8 task 1 built the binding while this was being filed.** `ase::meas_binding`
  answers *"which analysis occurrence this row reads"* as **`{type idx}`** — so the machine
  half exists and is index-shaped. What is missing is the half a person reads.

⚠ **And the calculator is the case that makes a picker insufficient.** `src/calculator.tcl`
(the `calc::` namespace — its own menubar, panes, function pad and buffer) is where a user
*types* an expression. A dropdown solves the dialog; it does nothing for someone composing
`180 + vp(out)` by hand, or writing a verbatim `x` block. That is the user's own reason for
raising it, and it is right.

## The proposal — three surfaces, ONE naming scheme

⚠ **The single deliverable is the naming scheme itself.** Three surfaces showing three
spellings would be worse than none. Everything below is downstream of deciding it once,
and `ase::meas_binding`'s `{type idx}` is the shape it should follow.

**1. Pick, don't type — the primary.** In the Measurements sub-dialog (`PLAN.md` §8b,
Stage 8 task 2), the *which analysis* field is a **dropdown of the enabled analyses**, each
shown as its handle plus a human one-liner:

```
ac1   AC   dec 10   1 Hz … 10 MHz
dc1   DC   sweep VIN  0 … 1.8  step 10m
dc2   DC   sweep TEMP -40 … 125  step 5
tran1 TRAN 1n … 10u
```

The user never needs to know the scheme, because they never spell it. **Lands with Stage 8
task 2.**

**2. The handle is visible where the user already is — the cheapest of the three.** One
column in the **Choose Analyses** grid, showing each enabled analysis's handle. No new
window, no new menu entry, and it answers *"what do I call this one?"* at the moment the
user is looking straight at the analysis. **Lands with ⚖ R6's addressing task.**

**3. `Analyses > List` — the user's idea, and it earns its place because of the
calculator.** A copy-pasteable dump of one-liners for the enabled analyses, beside the
existing `Analyses > Choose…`. It is the weakest of the three for *discovery* — a separate
place to look, duplicating what the grid can show — and the **strongest** for the one case
the other two cannot reach: **composing an expression by hand in `calc::`, where there is
no dropdown to pick from and the text has to be typed correctly.** Keep it, as an addition
to 1 and 2 rather than instead of them. **Lands with ⚖ R6's addressing task**, beside
surface 2, since both are the same grid's data rendered twice.

## Why it is not being built now

**The handles do not exist yet.** ⚖ R6's `id` is ruled and unimplemented, Stage 8 task 2's
dialog is unwritten, and `ase::meas_binding` landed hours ago. A lister built today would
render a naming scheme that is not settled, on rows that cannot yet be told apart — which
is the shape of every *"green but hollow"* surface this batch has spent the year removing.

**So it is sequenced instead**, and the sequencing is the point of filing it:

| surface | rides with | why there |
|---|---|---|
| the naming scheme | ⚖ **R6**'s addressing task | it is the thing `id` is *for* |
| handle column in the grid | ⚖ **R6**'s addressing task | same file, same data, no new surface |
| `Analyses > List` | ⚖ **R6**'s addressing task | same data again; one menu entry |
| the dropdown | **Stage 8 task 2** | the dialog does not exist until then |

⚠ **The one thing that must not happen** is Stage 8 task 2 inventing its own spelling for a
reference because R6's task had not settled one. **R6's task owns the scheme and ships it
first**; task 2 consumes it. If the order ever inverts, task 2 must be told to consume
`ase::meas_binding`'s `{type idx}` verbatim rather than mint a display form.

## Ruling

The one-liner text itself is **new user-facing copy** and rides ⚖ **R9** with the rest of
the batch's unratified wording. The *shape* — handle plus a human summary — is settled here;
the exact words are not.

---

## ⚠ WHICH HALF HAS LANDED — 2026-09-13, issue 1447

**The naming scheme shipped. None of the three surfaces did. This issue stays open.**

⚖ R6's addressing task shipped the row `id` key and **the one speller** in
`src/ase.tcl` — `ase::analysis_handles` / `_handle` / `_by_handle` /
`_handle_faults` / `_handle_fields` / `_handle_text`, plus one arm on
`ase::meas_binding` so a measurement row carrying `id` binds by handle. Measured:
**104 of 104** tracked `.state` files still round-trip byte-identically and **zero**
committed analysis rows carry the key. `test_ase_core` 602 → 620,
`test_ase_persist` 44 → 49 / 148 → 153, both arms. Detail:
`doc/claude/issues/1447-two-sweeps-of-one-type-and-no-word-for-either-of-them.md`.

**The scheme, so a surface author does not have to go and read the code:** a row's
handle is its `id` if it declares one, and `<type><n>` otherwise, `n` counting 1
from the top among rows of the same type — `ac1`, `dc1`, `dc2`, `tran1`, `op1`.

**What each of this issue's surfaces owes, and the exact call:**

| surface | the call | owed |
|---|---|---|
| **2** — handle column in Choose Analyses | `ase::analysis_handle $state $idx` | `src/ase_window.tcl` |
| **3** — `Analyses > List` | `ase::analysis_handle_text $sim $state` | `src/ase_window.tcl` |
| **1** — Measurements dropdown | `ase::analysis_handle_fields $sim $state $idx` per row; write the chosen handle onto the measurement row's `id` | Stage 8 task 2 |
| (new) an editable `id` field | `ase::analysis_id_ok` to validate, `ase::analysis_handle_faults $state` to report | with surface 2 |

⚠ **THE ONE THING THAT MUST NOT HAPPEN IS STILL THE SAME ONE.** No surface mints a
display form of its own. The handle a user reads off the grid has to be the word
they type into `calc::`, and every proc above returns the same answer precisely so
that there is nothing left to invent.

⚠ **AND `Analyses > List` LISTS EVERY ROW, NOT ONLY THE ENABLED ONES** — a
correction to the proposal above. A measurement bound to a switched-off row
REFUSES, and the user's next question is *which one is off*; a list that omitted it
could not answer, and it would disagree with the grid beside it, which shows them
all. `ase::analysis_handle_text` marks a disabled row `(off)`.

The one-liner's **words** are still ⚖ R9's, as this issue said; `owed.sh add rule
1447` carries them.
