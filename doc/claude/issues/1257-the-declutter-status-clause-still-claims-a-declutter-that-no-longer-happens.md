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
