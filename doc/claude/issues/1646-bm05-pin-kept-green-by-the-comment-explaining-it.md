# 1646 — a pin kept green by the comment written to explain it

**STAMP:** `v1 claim=fixed tree=060c6d77 stamped=2026-10-03 fix=taken open=1`

Status: **OPEN**, found 2026-10-03 by the Calculator batch while acting on issue 1645.
Area: `tests/headless/test_wave_sigbrowser.tcl` (row `BM05`), `src/wave_viewer.tcl`.

## The defect

Row `BM05` pins `wviewer::plot_signals`' four-parameter signature with a whole-file
`string first` for the literal

    proc wviewer::plot_signals {token exprs {colors {}} {destover {}}}

over `src/wave_viewer.tcl` read as **one string**. It does not go through `wvproc_body`, which
is the only helper that strips comments. At `060c6d77` that literal occurs **twice**:

| line | what it is |
|---|---|
| 7696 | inside the block comment headed *"WHY THIS IS AN ARMED HAND-OFF AND NOT `plot_signals`' FIFTH ARGUMENT"*, which quotes the signature verbatim **in order to say that it is pinned** |
| 7797 | the real proc |

So the comment is the row's evidence. **A fifth formal on the real proc leaves `BM05` green.**

### Measured, not reasoned

Three copies of `src/wave_viewer.tcl` were served through a symlink shadow tree with
`XSCHEM_SHAREDIR` redirected, so the executed code changed and not merely the text the suite
reads:

| shadow source | counted arm | display arm |
|---|---|---|
| HEAD text (control) | `ALL PASS (135 checks)` | `ALL PASS (353 checks)` |
| fifth formal `{xaxis {}}` on the real proc, comment untouched | `ALL PASS (135 checks)`, printing `ok: BM05 the signature really carries the optional destover` | `ALL PASS (353 checks)` |
| fifth formal **and** the comment copy rewritten | `1 FAILED (134 passed)`, `FAIL: BM05 … -> {0} (exp {1})` | — |

The third row is the control that matters: it proves the shadow source really is what the suite
reads, so the second row's green is a measurement rather than a mis-wired fixture.

## Why this is worse than an unregistered fence

`test_wave_sigbrowser` is in neither `hcases` nor `dcases` (issue 1645), so a gate never runs it.
But `full_audit.sh` globs `test_*.tcl`, **does** run it, and reports it green — and issue 1645's
own table names `BM05` as the thing holding this arity. A reader checking whether the signature is
fenced finds a row that says yes and cannot fail.

## The rule this breaks, and it is already written down

CLAUDE.md: *"A comment must not quote a count a command produces over the tree's own text"* — the
`grep -c '#pragma'` lesson, where a sentence shipped wrong three times because the correcting
rewrite spread the word `#pragma` across three lines and the comment became its own counterexample.
**This is the same family with the roles swapped: a comment must not quote the literal a row greps
for.** The comment did not become its own counterexample; it became the row's evidence.

The general form is one sentence: **if a predicate scans a file as text, every occurrence in that
file counts, including the ones in prose about the predicate.**

## Two things that are NOT claimed here

1. **The arity is not unfenced.** Row `WD4` of `test_calc_wave_dest` — already in `hcases`, already
   gating — pins it with `[llength [pcall info args ::wviewer::plot_signals]]`, which is immune to
   comments and to reformatting. Sabotage-confirmed on the counted arm: HEAD gives
   `ALL PASS (124 checks)`; the five-formal build gives `2 FAILED (122 passed)` with
   `FAIL: WD4 … -> {3 grid 5 {token exprs} 1 1 1 1}` and `FAIL: WD12 … -> {{} {} 1 0 {} 5 0}`.
   `WD4` reddens on a fourth `graph_props` formal too. **So issue 1645 is right about the mechanism
   and wrong about who holds the line**, and that table needs correcting.
2. **`BM05` is not uniformly vacuous.** Its other legs do work. Leg 4 —
   `regexp -all {wviewer::plot_signals \$token \$names \{\} \$destover}` — is a separate and
   narrower defect: it is **not end-anchored**, so a five-*argument* call still answers 1. Row
   `BT06` has the identical blindness. On the display arm that break gives
   `RESULT: 22 FAILED (330 passed)` across `BT28`–`BT32`, `BT43`, `BT44`, `BM30`, `BM31`, `BM43`,
   `BM44`, every failure reading as an **empty recorded call**, which is the swallowed-`catch`
   symptom `src/wave_viewer.tcl`'s own comment predicts.

## The repair, and why it has to be two edits

Changing only the predicate does **not** work: `regexp -all … == 1` would be **red at HEAD**,
because it answers 2. So either the comment stops reproducing the literal, or the row moves off
text scanning. Both, in fact:

* move the arity leg to `WD4`'s `info args` shape, which cannot be satisfied by prose;
* end-anchor or body-scope leg 4 and `BT06`, which also moves the five-argument break onto the
  **counted** arm;
* carry a non-vacuity leg proving the predicate moves when the formal count moves;
* rewrite the comment to describe the **shape** and name the row without reproducing the signature
  string, keeping every true statement it makes.

⚠ Row names: *"the signature really carries the optional destover"* is a **coverage claim** over a
method that asserted only *"this string occurs somewhere in this file"*, and leg 4's name,
*"browser_plot_ids forwards destover and reads no destination itself"*, accepts *"forwards destover
and anything after it"*. Both should name their method.

## Fixed

Repaired red-first in the commit that files this issue. The arity leg moved to `info args`, the
defaults regained a fence through `info default` (a coverage regression the first repair itself
caused — the retired literal had carried `{colors {}} {destover {}}` inside it), and the call-site
population became a derivation over command words, so an **unqualified** forward joins it. Across
43 derived sabotages the interpreter-introspecting legs were never evaded once.

⚠ **The general lesson, which outlived the defect:** every evasion this stage found was an evasion
of a **text-scanning** leg — first a comment copy of the signature, then an unqualified callee, then
a backslash continuation. None of the `info args` / `info default` legs was ever defeated. Source
text is the wrong instrument for pinning a signature, and it fails in the direction that reads as
coverage. Row `WD4` of `test_calc_wave_dest.tcl` had used the right shape all along, which is why it
caught breaks `BM05` slept through for a month.

## Outstanding

1. One declared limit of the new derivation, measured across fifteen continuation spellings and
   asserted as a limit rather than left silent: whole-line comments are dropped **before**
   continuations are joined, so a five-argument call continued onto a `#`-leading line with its
   closing word on a line of its own answers arity four where Tcl answers five. Reordering the two
   steps was deliberately **not** done — the walk's word count already diverges from Tcl's in four
   of those fifteen spellings while still reaching the right verdict in all but this one, and each
   previous attempt to make the text scan exact produced a fresh evasion.
