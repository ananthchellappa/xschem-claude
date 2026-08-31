# 0984 — the new netlist diagnostic's guards are pinned by fewer rows than they look

**Status: FIXED (2026-08-30, item S4c).** All four gaps closed in
`tests/headless/test_unused_attr_0970.tcl`, which went from 21 checks to **40**.

* **Gap 1, the stoplist.** Row **UF14** parses `unused_attr_stoplist[]` straight
  out of `src/token.c` and exercises **every** name on it, one at a time, on a
  sheet that also carries a control setting nothing reads. The control is what
  makes it honest: a name that silently swallowed the whole instance would
  otherwise look like a name that was properly excused. Before: 3 of 55 names
  were reached by any fixture. After: 56 of 56 (`select` was added to the list by
  issue 0980's fix), `unexcused=0`.
* **Gap 2, GUARD UA-NAME.** Row **UF15** gives it a fixture witness of its own —
  an instance whose properties continue behind a SPICE `+` marker, the way the
  shipped charge-pump sheet writes its inverters. The guard no longer depends on
  one shipped sheet's formatting.
* **Gap 3, the severity.** Row **UF16** is structural and pins
  `statusmsg(str, 2)` at exactly one occurrence with `statusmsg(str, 1)` and
  `statusmsg(str, 3)` at zero. These notices append to the info window and never
  force it open or fail the netlist. That loudness is still on the user's ruling
  queue with issue 0970; it is now a decision a test holds still.
* **Gap 4, rows PD4/PD5.** Both needles re-anchored from
  `translate $instname @model` to `translate $instname @model]`. All four call
  sites in the two shipped helper files end the command with a bracket, so a
  rename to `@modelXX` now reddens them; before, `@modelXX` still contained
  `@model` and the rows scored the same count either way.

Rows added by the same pass for the behaviour fixes: UF1–UF13, UF18, UF19.

**Original report, unchanged:** Four coverage
gaps in `tests/headless/test_unused_attr_0970.tcl`, three of them proved with a
real build in the sabotage pass. A fifth, in row **UB9**, was found the same way
and **is fixed** in this commit; it is recorded here because it is the reason to
believe the other four.

This is a test-coverage issue, not a behaviour one. Nothing here is a defect the
user can see today. Each is a place where the suite would stay green while a
shipped guard was removed.

## The one that was fixed here, and why it earns the rest

Row **UB9** is the structural row for GUARD UA-TOKSIZE — the latch that saves
and restores the netlister's token-found flag around the check's own lookups. It
asserted:

    [u_count $UB_FN {= xctx->tok_size}] >= 1

The skip test a few lines below the latch reads that same flag **six** times as
`skip = xctx->tok_size ? 1 : 0;`, so the loose spelling matched **7** times in
the function body. Deleting the latch line alone left **6** — still green — while
the surviving restore wrote an **uninitialised** value into the netlister's
token-found flag on every subcircuit instance. That is exactly the failure the
guard exists to prevent. Measured with a built binary in the sabotage pass: the
whole tier stayed green.

Fixed by anchoring on the latch's own variable, `saved_tok_size = xctx->tok_size`
(1 match, 0 after the deletion). A guard is only pinned by a row that its
*plausible* removals can fail.

## Gap 1 — 52 of the 55 stoplist names are pinned by nothing

`unused_attr_stoplist[]` holds **55** attribute names the diagnostic must stay
silent about. Row **UB5** exercises **three** of them — `place`, `sig_type`,
`device_model`, the ones the fixture instance `x10` happens to carry.

Measured with a built binary: cutting the list from 55 names to just those three
left `test_unused_attr_0970` at ALL PASS (21 checks), and
`test_hash_extra_node_warn_0165`, `test_ase_optier_0963` and `test_ase_core` all
green. So deleting `spiceprefix`, `pinnumber`, `format`, `template`, `net_name`
or any of the other 52 is invisible to every test in the tree — and each
deletion starts printing a paragraph telling a designer that a setting the
netlister genuinely reads "did not reach the simulator and changed nothing".

The row's description implies it covers the list. A fixture instance carrying
every name on it, asserted silent, costs one instance.

## Gap 2 — GUARD UA-NAME's only witness is one shipped sheet's formatting

UA-NAME is the test that a token reads as an attribute name at all. It was added
during implementation after measurement, and appears in neither the plan's guard
list nor its sabotage list.

`sky130_tests/charge_pump_phasegen.sch` writes its instance properties over
three lines with SPICE-style `+` continuation markers, so `list_tokens()`
returns a bare `+`. Without the guard the shipped `tb_charge_pump` bench emits
eight lines reading `instance x7 (a lvtnot) sets +=`. Deleting the guard reddens
**UB8 only**, through that one bench's count.

Re-save that single sheet without continuation markers and the guard silently
loses its only witness while the defect stays live. The fixture `uatop.sch` has
no continuation-marked instance.

## Gap 3 — the severity choice is pinned by nothing

The diagnostic calls `statusmsg(str, 2)`: it appends to the info/ERC window and
does **not** raise the netlister's `err`, so `show_infowindow_after_netlist`
(default `onerror`) never pops the window. That choice is deliberate, is
documented at the call site, and is on the user's ruling queue for **0970**.

    grep -n 'show_infowindow\|onerror\|netlist_err\|statusmsg' \
      tests/headless/test_unused_attr_0970.tcl   ->  (empty)

Change it to raise `err` and every netlist of any design carrying one such
setting pops the info window, with all 21 checks still green. A decision the
user is being asked to ratify should be pinned by a row before they ratify it.

(A change to `statusmsg(str, 1)` *would* be caught, since `ua_lines` reads
`infowindow_text`.)

## Gap 4 — rows PD4 and PD5 count by prefix, not by token

Both use `u_count {translate $instname @model}`, a prefix substring test. A
rename to `@modelXX` would still be counted. Found while sabotaging PD5: the
first attempt renamed the token and the count stayed 3. Deleting a site properly
does redden them (3 -> 2), so the rows work against deletion today, but not
against a rename.

## Related

**0970** (the diagnostic these guards belong to), **0980**/**0981**/**0983**
(three shapes the rows do not cover because no fixture reaches them).

## SABOTAGE-VERIFIED, 2026-08-30 — all four gaps closed, six new ones found

This issue's core demand was *mutation-verify every guard*. That has now been
done against real rebuilds, one guard at a time — 24 builds on the first pass
and 27 on a fresh repeat of the whole matrix — restoring and re-asserting the
baseline green between every one.

**The four gaps this file names are genuinely closed:**

* **Gap 1** (stoplist reached 3 of 55 names) — SAB-STOP, cutting the list to
  three names, reddens UF14; the row exercises all 56 beside a control.
* **Gap 2** (UA-NAME had no witness but one shipped sheet's formatting) —
  SAB-NAME reddens UF15, the fixture's `+` continuation. It no longer reddens
  the shipped bench, and *that is the point*: `lvtnot.sym`'s own `template=`
  uses `+` continuation markers, so GUARD UA-TMPL — added after this file was
  written — now silences the bare `+` there too. Without UF15 the guard would
  have had no witness left at all.
* **Gap 3** (severity was unpinned) — SAB-SEVERITY, `statusmsg(str, 2)` →
  `(str, 1)`, reddens UF16 `{0 1 0}`. Where this file records "all 21 checks
  still green", the answer is now a red.
* **Gap 4** (PD4/PD5 counted by prefix) — the re-anchor onto
  `translate $instname @model]` is real. Renaming to `@modelXX` reddens PD4 and
  PD5, and the OLD needle still counts 1 and 3 respectively after that rename,
  so the pre-re-anchor rows genuinely could not have failed.

**But five guard halves still delete clean with all 40 checks green**, including
the early-return restore of the netlister's token-found flag — the same defect
row UB9 was re-anchored to fix, one level down. Filed as **0986**, which the
repeat pass grew to six: the `%` sigil half of GUARD UA-FMT has no row either,
and `%tok` is a substitution the netlister really honours.
