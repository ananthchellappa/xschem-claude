# Stage F2/F3 — `cross`: the red-first suite, and the implementation that turned it green

Four crews over 2026-10-01/02: author, two adversarial lenses, repair, independent verify, repair
again, implement. Driver collected. Contract: `../CROSS_CONTRACT.md`. Evidence and golden data:
`F-cross-recon.md`.

## Red first, and the red was audited rather than assumed

`tests/headless/test_calc_cross.tcl` was written **before** `calc::cross` existed, run, and observed
failing. Final shape: **187 checks, 15 bands CX0–CX14**, `hcases` alone.

The red on the frozen pre-implementation suite: `RESULT: 122 FAILED (56 passed)`, exit 1, with
**every** failure naming `NOPROC:calc::cross` and **no** row throwing. CX0 and CX1 — fixture load,
accessor facts, the suite's own independent derivation of the crossings — were green throughout,
which is what distinguishes *"the suite works and the feature is absent"* from *"the suite is
broken"*.

⚠ **The authoring crew's FIRST red was over-claiming and it caught that itself.** Run 1 was
63 passed / 106 failed, and **nineteen of those passes were accidental**: a sentinel satisfies a bare
identity or predicate just as a real answer does. `cross(a) eq cross(b)` is true when both sides are
the same error marker; `string is double -strict` is false for a sentinel exactly as for a genuine
absence; `llength` of a one-word sentinel is 1, so `{1 1 1}` sailed past an expected `{3 2 5}`;
`cx_increasing` over a one-element list returns `ok` without looping. Restructured so every such row
carries the disposition as the first element of what it compares, run 2 was 53 / 116. **That drop of
ten is the measure of how much the first red lied**, and the lesson generalises past this suite: a
red run is evidence only if each row's failure is attributable.

## The precision defect, found three times at three depths

`xschem raw value` returns `dtoa(val)` = `"%.8g"`; the `values` arm formats `"%.16g"`. That one fact
produced three separate defects:

1. **In the contract.** D10 had `cross` scanning per point for speed (0.11 ms against 15 ms on
   100 000 points). A crossing interpolated from `%.8g` samples carries ~1e-8 relative error against
   the fixture's documented **1e-12** tolerance, so the fast door **cannot produce an assertable
   answer**. D10 reversed to bulk-always, one read path.
2. **In the suite's comparands.** Six `eq` legs compared bulk-derived answers against
   `xschem raw value` comparands, so **no value could ever be string-equal to the comparand** and all
   six read identically for a snapping implementation as for an interpolating one — while the row's
   name claimed six discriminating inequalities. A sibling row was alive on one leg of two, and
   CX7's "bit for bit" leg was alive *only* because `time[50]` round-trips through `%.8g`. CX10's two
   phantom legs compared across the gap under a 1e-12 tolerance when `%.8g`'s error reaches ~5e-9.
   Repaired to read the bulk column, plus **a new derived row that re-measures the door disagreement
   itself**, so it cannot be reintroduced quietly.
3. **As a hole that stays open, declared.** A reference reading *every* sample per point — the
   reversed D10 applied **consistently** — passes the whole suite. `CX5`'s bit-identity row catches
   only the *mixed* two-route design. The repair crew deliberately declined to write the fence that
   would close it, because that row would also pin D4's exact floating-point expression *order* and
   would redden a conforming implementation that merely re-parenthesised the same formula. The
   contract already says D10 is unfenceable; this measures it.

⚠⚠ **The way defect 1 would have gone wrong silently is the finding worth keeping.** A row compared
the `nth = 0` answer against `nth = 1` with string identity, which under two read paths could never
hold — and an implementation quietly using bulk for everything turned that row **green with nothing
else noticing D10 had been discarded**. A row whose only route to green is for the implementation to
ignore the spec is a row that selects for that outcome. Reversing the decision deliberately is the
honest version of the same end state.

## Twelve false claims in one file, three of which no lens had flagged

The repair crew was handed nine and found three more, the sharpest being **a second copy of the same
miscount three paragraphs from the one it was fixing** — a comment reading "the three procs below"
above four procs, where the one being corrected said the same thing about a different four. **This
batch's signature failure, twice in one file.** Found only because the brief said to grep *every*
occurrence rather than fix the two it was told about; the instruction earned its keep, exactly as
issue 1628's same-class brief did.

Also retired: a header count that drifted (18 → measured 22 *and* 27 for the same six bands,
depending on the hazard's shape — a better argument for dropping the number than the drift was), and
a `"NINETEEN rows passed"` count taken over a revision of the file that no longer exists, so no
instrument could reproduce it. Both are the house rule against writing down a number nothing
re-checks, failing in a comment again.

## Sabotage and mutation: 15 + 21, no holes among them

Every sabotage of the implementation reddened named rows. The targeting is narrow where it should be:

| sabotage | rows |
|---|---|
| drop the direction filter | 34 |
| reverse the interpolation operands | 33 |
| leak the temp vector | 26 |
| absence reported as `0` | 20 |
| snap to the sample | 20 |
| negative `nth` counts forward | 13 |
| truncate the `nth = 0` list | 13 |
| sweep as index 0 instead of by name | **2** (both OP-read rows, and nothing else) |
| integer-*spelled* instead of integer-*valued* | **2** (both rows written for it) |
| the old two-route D10 | **1** (the only observable) |
| **route the reads through a helper proc — i.e. GAMING the SR5 fence** | **1**, in `test_calc_scratch_reuse` |

Two mutations had reddened **nothing** and were fixed into fences rather than accepted: an empty
absence message now reddens 1 row, a lowercase refusal 6.

## SR5 was widened as a derivation, not as a longer list

`cross` legitimately becomes the second `::calc::` proc issuing `xschem raw add`, so SR5's
`{eval_rpn}` literal had to move. It was replaced by **five independently computed sets** over the
decommented namespace — minters, adders, readers, deleters, pre-flighters — with the claims stated as
`minters == adders == readers == deleters` (R402's whole discipline as one equality, printing all
four so a failure names which set fell out), `adders ⊆ preflight` as a *subset* because `plot_rpn`
pre-flights while reaching the engine by the viewer's door, and a new row asserting the direct-verb
and viewer-door sets are **disjoint** — which is where *"exactly one DIRECT verb"* survives as a
narrow claim instead of dissolving. A non-vacuity leg guards it, because four empty sets satisfy the
equality perfectly.

**Why that is honest and not a dodge**: `{cross eval_rpn}` is the same hand-kept list one name
longer, and **seven more T-route verbs stand on `cross`** — the next one edits it again, which is
`test_snprintf_fmt_1608` row X1's lesson one level up. The derived form is strictly stronger, and
sabotage S15 proves it: routing the reads through another proc to escape the row reddens it, where
the literal would have let that straight through.

## What the crews corrected in the driver

- **D10** (above) — the driver optimised on a measurement it had asked for and never asked the
  complementary question. *A performance number is not a reason on its own; the cheaper route has to
  be shown adequate first.*
- **D6's blast-radius sentence** said a throw "reaches the file-scope catch and aborts the whole
  suite". Measured against the suite's three real catch layers: a throw out of `::calc::cross` is
  caught by `cx_call` and fails **one row**; a throw out of suite code is caught by `group` and
  abandons **one band**. Smaller than claimed — *and* the overstatement hid the worse half, that an
  abandoned band silently stops measuring its remaining rows.
- **`scalar/list`** in spec §7.2 was the driver's own edit and was unshippable: S24 holds `returns`
  to `{scalar wave bool scalar/wave}`, so it is a counted failure in a registered `dcases` suite.
  The crew shipped `scalar/wave`, flagged the conflict instead of silently respelling the spec, and
  said the spec side was outside its permitted files. `scalar/wave` is also the more faithful word —
  the reference tool returns a waveform for `nth = 0`.
- **One crew corrected itself**: it called `regression_case_failed $out 0` with the arguments
  backwards (the signature is `{childcode body}`), read the `1` as "this suite cannot be registered",
  and caught it. Had it trusted that number it would have reported the registration as unsafe.

## Golden data: independent re-derivation AGREED

The implementation crew re-derived every crossing without using any xschem crossing function and
matched `F-cross-recon.md`. The apparent mismatch the driver had flagged — `0.00616` against
`0.0061599999999999997` — is the **`%.17g` spelling of the same double**
(`expr {0.00616 == 0.0061599999999999997}` → 1), not a disagreement.

## Holes declared, not papered over

1. **D10's bulk read is fenced by nothing** (above), with the trade spelled out in the suite.
2. **The `np < 1` points-gate threshold is unfenced** — a `cross` refusing every 1-point tran read
   passes the suite. Fencing it needs a 1-point database *with* a resolvable sweep column, which the
   fixture has not got. The row to write is named in CX11's comment.
3. **The `engine` refusal kind has no trigger in the suite**, so its sentence shape is unfenced; said
   plainly so the per-kind loop is not read as covering it.
4. **CX12's leak row cannot redden** — every path in that band refuses before a temporary is minted.
   Kept for uniformity and renamed a *consistency row, not a fence*.
5. **The `ac` → `frequency` sweep arm is unfenced** (no AC read in the fixture), as is
   `calc::cross_scalar`'s `nth = 0` refusal, whose calling surface is phase 5's.
6. **`dc` is refused outright**, declared rather than guessed: a DC sweep column carries the swept
   source's own name, so there is no constant to look up.

## Sibling suites, `--nogui`

```
test_calc_cross             ALL PASS (187 checks)
test_calc_scratch_reuse     ALL PASS (53 checks)      51 before; SR5 +2
test_calc_engine            ALL PASS (265 checks)
test_registered_banner_1626 ALL PASS (10 checks)
test_scratch_home_note      ALL PASS (22 checks)
```

## Registration

`tcases` 3, `hcases` **93 → 94**, `dcases` 24 → `planned_cases` **122**. Every entry in both lists
machine-checked to resolve to a file on disk, 0 missing. Derived from `summarize_all`'s own regexp
arms over the suite's real captured output: cases +1, blocks +1, counted +0, skips +0, `wc -l` +3 →
**122/121/0/8**. Read the trailer; do not check it against that.

⚠ **`tests/headless/test_calc_cross.tcl` is untracked and registered**, which is the
"nearly committed two untracked suites" failure from the other side. It must be `git add`ed in the
same commit or a fresh clone registers a file that is not there. Flagged by the implementation crew
as the first thing it could not do itself.
