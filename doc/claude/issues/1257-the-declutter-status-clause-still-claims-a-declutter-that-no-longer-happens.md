# 1257 — the declutter status clause still claims a declutter that no longer happens

Status: **open** (STUB claimed by item A5's RED pass, 2026-09-02; **not fixed**,
and deliberately not A5's to fix) · Branch: `fluid-editing`
Related: **1244**, rulings **D-6** / **D-8**, issues **1251** (the clause), **1250**

## The defect, in one sentence

After item **A5-a**, pressing `6` on a sheet with **no results file** hides
nothing — ruling D-6 needs a NUMBER, and a label with no number did not get one —
but the held status line still says other device text is hidden.

## Where the two halves live

* The **gate** is `annot_instance_annotated()` in `src/actions.c`: item A5-a makes
  it require at least one `op_annot::text` row carrying an actual value.
* The **sentence** is `cadence::_annot_declutter_clause` in
  `utils/annot_mode.tcl`, gated on **bit 3 AND bit 0 of `annot_show` only**. It
  never asks whether anything was actually hidden.

`utils/annot_mode.tcl` is item **A4**'s landed file and is **not item A5's to
edit**, so A5 files this and hands it on rather than reaching into it.

## Measured

`tests/headless/test_annot_declutter_1244.tcl` row **E6**, whose fifth leg item
A5 flips `0 -> 1` (the sheet keeps `CW=1u` at mask 9 with `xschem raw loaded` =
-1) while legs 8 and 11 keep golding the clause **present** on that same press.
The row asserts the gap on purpose so it stays visible.

## The open question (a `rule` debt, the user's to settle)

Should the clause follow the gate — say nothing when nothing was hidden — or
should the press be refused outright with "Run a simulation first"? Recorded so
the decision is seen to be the user's.

---

## A7 attempt, 2026-09-03 — **`[F]`, reverted. This issue stays OPEN.**

Item **A7-a** implemented the driver's ruling (*"THE CLAUSE FOLLOWS THE GATE …
three states, three sentences"*) with a new C counter `annot_declutter_count`
bumped at `text_hidden_core()`'s declutter rung, a pure `hid` argument on
`cadence::_annot_declutter_clause`, and a `cadence::_annot_declutter_refresh`
helper that reads the counter delta across one `update_all_sym_bboxes` +
`redraw`. **The two states this issue names were fixed and driven** — no raw, and
the dead-raw state this issue never named (`op_annot::_annotated` answers 1 there
exactly as on a valued raw, which is why no Tcl-only fix can pass).

It was refuted on a **fourth** state and reverted: the counter is bumped above
the `show_hidden_texts` / `HIDE_TEXT` / `HIDE_TEXT_INSTANTIATED` arms, so on any
annotated device whose only non-`@name` text is already `hide=instance` (57
shipped device symbols) the sheet is byte-identical at mask 1 and mask 9 and the
clause is still emitted. **See issue 1270** for the measurement, the four-line
repair, the row that must go with it, and the whole preserved implementation
(`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`).

`rule` debt **1257_A7_armed_no_values** was recorded by A7 and describes a
sentence (`DC_ARM` in the armed-but-no-numbers state) that is **no longer in the
tree**. It is left standing — a rule debt clears only when the user says so — but
the re-do should reach the same state before the question is answerable.

## Closed by item A7's re-do, 2026-09-03

Item **A7** implemented this, was refuted on a state nobody had named
(issue **1270** — the declutter counter counted the *rung*, not what came off
the sheet), was reverted with every line preserved as
`doc/claude/op_param_batch/A7_working_tree_REFUTED.patch`, and was re-done by
the driver: patch re-applied, the four-line repair added at A7's own edit point,
and two new suite rows (**A64**, **A65**) that catch the 1270 defect and the
tempting wrong repair, both proved by sabotage rather than asserted.

Read **1270** for the full account, including the residual risks that survive
this fix. Item A7 closes feature A of `doc/claude/op_param_batch/PLAN.md`.
