# Item 03 — retrofit the legacy dialog onto the shared matcher — LEDGER RECEIPT

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `6a3f8e42`.
Date 2026-08-04. Written by the ledger stage from the implementer result **and** the
independent verifier result. The implementer's own long-form receipt (committed inside
`afdd44a0`) is preserved **verbatim** as the appendix at the bottom of this file —
nothing it said was dropped. Where the two disagree, §1-§9 wins.

---

## 1. Verdict

**DONE.** Verified: `ok: true`, `scopeClean: true`. The verifier did not take the
implementer's table on trust: it re-ran the build and the suite, wrote **its own unnamed
sabotage aimed at the item core** (plus a bonus coverage probe), built **two independent
oracles** — a hand-picked 80-comparison equivalence probe and an 8000-comparison fuzz of
legacy-vs-new — re-verified every cited anchor from source, ran a full solo audit, and
isolation-tested against the pre-item source every fail it could not immediately clear.

**Committed, NOT pushed.**

| | |
|---|---|
| commit | `afdd44a059d60e7d7c3280a50d7b2fb04c1da8db` (short `afdd44a0`), *"refactor(graph): dialog filter onto sig_match"* |
| parent / item-start HEAD | `6a3f8e42` |
| scope | **3 files, +444 / -13.** No C, no new test file, **`src/wave_viewer.tcl` untouched** — item 1's sabotage-pinned `sig_match` ships exactly as committed, zero blast radius (`git show --stat`, re-run by the verifier) |
| blast radius | **contained to `.graphdialog`.** Repo-wide grep: `graph_get_signal_list`'s only callers are `graph_fill_listbox:4691` and `:4696`; the only test files mentioning `.graphdialog` / `graph_fill_listbox` / `graph_get_signal_list` are `test_wave_sigsearch.tcl` and `test_wave_markers.tcl` (which only asserts the dialog does NOT exist). No other suite can reach the changed proc. |
| the ⚠ (load order) | **checked, not assumed.** `source $XSCHEM_SHAREDIR/wave_viewer.tcl` is column 0, unconditional, top-level; both call sites are runtime-only. Confirmed from source by the verifier and at runtime under `--nogui`. `sig_match` did not move. |

## 2. Files touched

| file | what |
|---|---|
| `src/xschem.tcl` | +52/-13. `graph_get_signal_list`'s body is now a `wviewer::sig_match` call (proc moves `:4469` -> `:4502` behind a +30-line comment block). Signature, proc name, the `graph_sort` global and both call sites UNCHANGED. **First `src/xschem.tcl` -> `wviewer::` call in the tree.** |
| `tests/headless/test_wave_sigsearch.tcl` | +78. Group **GS** (15 checks) appended per settled decision 9, plus one declared one-line comment correction (E6). |
| `doc/claude/signal_browser_batch/receipts/03_receipt.md` | the implementer long-form — now the appendix of this file. |
| `doc/claude/signal_browser_batch/PLAN.md` | ledger tick only, left **UNSTAGED** (driver's file; item-2 D6 precedent). Not part of the commit. |

Body as shipped:

```tcl
proc graph_get_signal_list {siglist pattern } {
  global graph_sort
  set direction -1
  if {$graph_sort} {set direction 1}
  if {$pattern ne {}} { set pattern ".*(?:$pattern).*" }
  set r [wviewer::sig_match [split $siglist \n] $pattern \
           -syntax regexp -case 1 -sort $direction]
  if {[lindex $r 0] ne {ok}} { return {} }
  set result {}
  foreach i [lindex $r 1] {
    regsub {^v\((.*)\)$} $i {\1} i
    lappend result $i
  }
  return $result
}
```

## 3. Tests

| | |
|---|---|
| test file | `/home/qflow/dev/xschem/claude_1/xschem/tests/headless/test_wave_sigsearch.tcl` (settled decision 9: one file, appended) |
| checks added | **15** (GS01-GS15) |
| checks total | **61 -> 76** |
| verified how | the verifier counted GS01-GS15 by hand (15 added, 61 -> 76 — *"claim matches exactly"*) and re-ran `./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl` -> `RESULT: ALL PASS (76 checks)`. Green under `--nogui` **and** under a real X via `run_suites.sh`; in the PASS column of both full audits. |
| build | `make` at repo root -> *"Nothing to be done for all"* on every subdir; binary unchanged (Tcl-only item). |

**Behaviour was measured, not reasoned.** The implementer ran the same 15-case probe
in-binary against the SHIPPING legacy body and then against the retrofit: **11 of 15
byte-identical**, 1 sanctioned change (invalid regexp `[` -> `{}` instead of the whole
signal list — settled decision 4), 3 declared deltas (D3, pinned by GS12/GS13/GS14).

**The verifier built its own oracles rather than re-reading that table:**

* **Equivalence probe** (pure `tclsh`; matcher procs extracted from `wave_viewer.tcl`,
  legacy body reconstructed verbatim from `afdd44a0^`): 20 hand-picked patterns × 2
  signal lists × both sort directions = **80 comparisons. 66 identical, 14 different,
  and every difference falls in a declared class.**
* **Fuzz**: 4000 random regexp-ish patterns × 2 sort directions = **8000 legacy-vs-new
  comparisons** over a realistic raw name set. `same=4830`, `classA` (invalid pattern,
  the sanctioned decision-4 change) `=3104`, `classB` (fully explained by the
  full-raw-name match subject, checked against an independently computed model) `=66`,
  **`UNEXPLAINED = 0`.** No hidden on-screen delta beyond the sanctioned one and D3's.

**Fixture rule, stated in the group header and worth carrying forward:** `GSPLAIN`
deliberately carries NO `v(...)`-wrapped name, and GS05/GS12/GS13/GS14 assert a length or
a strip-invariant element. That is what makes the NAMED sabotage single-target. A later
item that "tidies" these fixtures into one shared wrapped list silently hands that
sabotage extra targets.

**EYEBALLED** (not skipped, though the item is not PIXEL-tagged): `.graphdialog` opened
for real under a DISPLAY on `poweramp.sch` with an in-memory raw, and the **actual Tk
listbox contents read back out of the widget**. `v(out)` displays as `out` while sorting
in its full-name slot; `i(v1)` is not stripped; `out` still matches unanchored; `[` gives
an EMPTY listbox; `Incr. sort` still flips the order. Window capture confirms it renders.

## 4. Sabotage table — implementer's round

Nine injections, every one `diff`-confirmed to be the sabotage and nothing else BEFORE
the run, every one measured, every one **reverted** (see D5 for the revert mechanism and
why it was not `git checkout --`; final md5 `53c567ac8f82ecb548303915206d23c2`, re-run
`ALL PASS (76)`).

| # | sabotage | predicted target | measured | failedExactly | reverted |
|---|---|---|---|---|---|
| **NAMED** | delete the display strip (`regsub {^v\((.*)\)$} $i {\1} i`) | GS03 | **GS03 alone**, 1 FAILED / 75 passed (`v(out)` instead of `out`) | **yes** | **yes** |
| u1 | delete the `.*(?:$pattern).*` unanchor wrap — i.e. inject **the PLAN's literal call composition** | GS06+GS10+GS12 | **exactly the predicted three.** THE sabotage that proves D1 is load-bearing: pattern `out` returns `{}` where the shipping dialog returns `about x1.out` | **yes** | **yes** |
| u2 | drop the non-capturing group (`.*$pattern.*`) | GS10 | **GS10 alone** — a user's alternation `x\|y` collapses to `{}` | **yes** | **yes** |
| u3 | swap the legacy strip for `wviewer::sig_bare` | GS04 | GS01, GS02, **GS04** — superset. `GSPLAIN` contains `i(v1)` and GS01/GS02 assert the WHOLE list, so a wrapper strip that eats `i(...)` shows up there too | no (honest superset) | **yes** |
| u4 | drop `-case 1` | GS06+GS07 | **exactly the predicted two**; both become `about Out x1.out` | **yes** | **yes** |
| u5 | invert the sort mapping | GS01+GS02 | GS01, GS02, GS05, GS06, GS10, GS15 — superset: a direction flip changes every multi-element result, not just the two checks that name the direction | no (honest superset) | **yes** |
| u6 | restore the legacy widening (on `err`, return the whole sorted+stripped list) | GS08 | GS08 + GS13 — superset of 2, **both decision-4 checks**: `(?i)out` is also invalid under the wrapper, so the widening un-empties it too | no (honest superset) | **yes** |
| u7 | strip BEFORE `sig_match` (strip-then-sort) | GS05 | GS05, **GS12, GS14** — superset: stripping first also changes the MATCH SUBJECT. Same defect, three symptoms | no (honest superset) | **yes** |
| u8 | pass the blob instead of `[split $siglist \n]` | GS15 | **GS15 alone**: `a b c` (3 elements) instead of `{a b} c` | **yes** | **yes** |

**The NAMED sabotage fired on exactly one check.** Five of nine were single- or
exactly-predicted; the four supersets are honest scoping, not leakage — see D6.

## 5. The verifier's own sabotages, and their outcomes

The verifier wrote its own, aimed at the item core and **absent from the list of nine**.
Both were reverted from a byte-exact snapshot with the md5 (`53c567ac…`) restored and a
green re-run.

| # | sabotage | outcome |
|---|---|---|
| **V1 — the verifier's own unnamed sabotage** | **half-anchor the compat device**: `.*(?:$pattern).*` -> `.*(?:$pattern)`. Deliberately subtle — it leaves the wrap *present*, so every "the wrap exists" reading still looks right, and only breaks trailing-context matching | **CAUGHT. 2 FAILED / 74 passed** — GS10 (alternation: `{ay}` instead of `{ay xa}`) and GS12 (0 instead of 1). Verdict: *"the tests really do cover the feature."* Reverted, md5 restored, re-run `ALL PASS (76)`. |
| **V2 — bonus coverage probe** (a dead-mutation hunt, not a defect hunt) | drop the display strip's **trailing anchor**: `regsub {^v\((.*)\)$}` -> `regsub {^v\((.*)\)}` | **SURVIVED — ALL 76 PASS.** An uncovered mutation: no fixture carries a `v(...)`-prefixed name with trailing text. Irrelevant for real raw names, but the strip is pinned only *up to that anchor*. Carried forward as P2. Reverted, md5 restored, green. |

The verifier also re-verified every cited anchor from the shipping tree rather than
trusting line numbers: `xschem.tcl:4502` (proc), `:4691`/`:4696` (call sites),
`wave_viewer.tcl:1490` `sig_type`, `:1528` `sig_match`, `:1573` the `^(?:$pat)$` wrapper,
`:1581` the empty-pattern short-circuit, `:1584`/`:1590` the two separate `-nocase` flags
(**E6's correction is correct**), `:1596` the return. All exact.

## 6. Non-baseline fails

**Implementer:** `nonBaselineFails: []`. One solo `full_audit.sh` (held 34 minutes by a
live human Pause on the GUI control panel, **not overridden**) ->
`SUMMARY: 265 pass  18 fail  0 crash/timeout  0 skip  (total 283)`, `WIREEDIT PASS`,
`SCRATCH 0 leaked dirs`, `grep -c "X connection to :0 broken"` = **0** (so that run *is* a
measurement). 16 of the 18 fails are the 16 HARD baseline names on their recorded checks.
Two names outside the baseline, both chased to the ground:

| name | disposition |
|---|---|
| `test_verb_noun_descend_0200` | `run_suites.sh -n 3` -> **3/3 PASS**. Flake. |
| `test_hover_highlight` | **pre-existing ~30% environmental flake, proven by an INTERLEAVED A/B** — see below. |

`test_hover_highlight` nearly fooled the implementer: the naive sequential comparison was
15/15 PASS reverted vs 7/9 present (Fisher p≈0.05) — the shape of a real regression. That
was a **time-ordering confound** (item-present batches ran straight after a 283-test
audit, when WSLg has degraded). Re-run interleaved, 10 rounds, arms swapped by
`git checkout <sha> -- src/xschem.tcl` between *every single run*: **3/10 failures in BOTH
arms, failing in the SAME rounds (4, 7, 10), on different checks each time.** Mechanically
it also cannot be item 3 — every caller of `graph_fill_listbox` is a `.graphdialog`
binding or the dialog build, and `test_hover_highlight` never opens that dialog.

**Verifier: independently ran its own solo audit** (also Pause-held ~50 minutes by a
human, also **not** overridden) ->
`SUMMARY: 261 pass  21 fail  0 crash/timeout  1 skip  (total 283)`, `WIREEDIT PASS`,
`SCRATCH 0 leaked dirs`, `test_wave_sigsearch` in the PASS column. Fail-list diff vs the
2026-08-04 HARD baseline: **all 16 HARD names present, each on the check the PLAN block
records** (spot-verified PS0/W7/FE8/R10/GUI8+GUI9/LM-LOC3/P1-P4/`library_list`×3/
rot180-ip/SA5-SA8b/6 self-log keys), plus 2 FLAKY-list names and 3 names on neither list.
Every name on neither list was re-run 3×:

| name | disposition |
|---|---|
| `test_getprop_index_bounds` | 3/3 PASS. Its audit "fail" was the run's single `X connection to :0 broken` — zero checks ran. |
| `test_graph_context` | 3/3 PASS |
| `test_wave_modes` | 3/3 PASS |
| `test_nh_anim_rearm` (FLAKY list) | 3/3 PASS — excused |
| `test_palette` (FLAKY list) | fails on its recorded flaky signature *"EVENT opens palette: NO"* — excused |
| `test_cadence_drag` (HARD list, **different checks**) | **isolation-proved**: `git checkout 6a3f8e42 -- src/xschem.tcl` (item ABSENT) -> fails the identical 2 checks, 2/2 runs. Not item 3's. See P3. |

**Ledger conclusion: NO regression is attributable to item 3.** `nonBaselineFails: []`
survives the independent check — with the disclosure in P4 that the verifier's audit was
repaired by targeted re-runs rather than re-run pristine.

## 7. Verifier problems (all NON-BLOCKING) — carried forward

* **P1 — a stale citation is now baked into shipped code.** The new comment block in
  `src/xschem.tcl` says `wave_viewer.tcl` *"is sourced unconditionally at
  `xschem.tcl:14295`"*. That was the **pre-edit** line; the item's own +30-line comment
  block pushed the `source` to **`:14325`**. §8 of the appendix is internally consistent
  (it deliberately cites pre-edit numbers), but the comment a future reader will follow
  points at an unrelated line. One-character-class fix, no behavioural impact.
* **P2 — the display strip's trailing anchor is not pinned** (found by the verifier's
  bonus probe V2, not stated by the implementer). Changing `regsub {^v\((.*)\)$}` to
  `regsub {^v\((.*)\)}` leaves **all 76 checks green**, because no fixture carries a
  `v(...)`-prefixed name with trailing text. The appendix's claims (c)+(d) pin the strip
  only up to that anchor. **One fixture element closes it** — items 4/5 append to this
  same file and can take it in passing.
* **P3 — the PLAN's baseline anchor for `test_cadence_drag` is wrong, and will trip the
  next verifier.** The PLAN records 12 fails whose first is *"plain click selects
  instance 0"*; the verifier measured 2 fails (Ctrl+drag / non-cadence plain drag *"leaves
  wires behind"*) and the PLAN's anchor check **PASSED**. Under the stated rule (*"fails
  on a DIFFERENT check => treat it as new and yours"*) that reads as a new regression; it
  is not (isolation-proved against `6a3f8e42`). The recorded anchor is a flakier variant
  of the same test. **The driver should re-anchor that baseline name.**
* **P4 — disclosure on the verifier's own audit status.** Its log contains exactly one
  `X connection to :0 broken` (inside `test_getprop_index_bounds`, zero checks run — a
  pure WSLg Xwayland casualty). By the letter of the baseline rules that makes the run
  *"not a measurement"*. The verifier did not spend another hour on a second full
  283-test pass; it instead re-ran every non-baseline and flaky name 3× (all green) and
  isolation-tested the one anchor mismatch. The implementer's separate audit **did** have
  zero X deaths, so between the two runs the item is covered — but no single pristine
  283-test pass exists for this commit from the verifier's side.
* **P5 — neutral on the BASELINE FEEDBACK.** `test_hover_highlight` PASSED in the
  verifier's audit, so it neither confirms nor refutes the implementer's measured ~30%
  flake rate. The interleaved-A/B methodology point stands on its own regardless.
* **D3 remains OWED by the driver.** The verifier independently reproduced all three
  residual deltas on a realistic raw name set and confirmed the root cause from
  `afdd44a0^` (the legacy body stripped BEFORE it matched). Its judgement, adopted here:
  *"a flagged divergence, not a silent one, so it is not a verification failure — but the
  item's bolded 'On-screen behaviour must not change' is NOT fully satisfied and the
  driver must rule."*

## 8. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | The PLAN's literal call spelling (`sig_match -syntax regexp` with the user's pattern AS-IS) is **MEASURED to break the dialog**, so the caller pre-wraps a non-empty pattern as `.*(?:$pattern).*`. | Under the literal reading, typing `out` returns `{}` where the dialog returns `about x1.out` today. `sig_match`'s regexp arm is whole-name anchored (settled decision 3, the `^(?:$pattern)$` wrapper at `wave_viewer.tcl:1573`); the legacy `regexp $pattern $i` was NOT. Wrapping makes `sig_match` compute `^(?:.*(?:$pattern).*)$` — the unanchored semantics. **`sig_match` is UNCHANGED; decision 3 is NOT overturned** — the legacy dialog is simply a caller that always searches with an implicit `.*…*`, a legal pattern under decision 3. The item's bolded *"On-screen behaviour must not change"* wins over the call spelling. Pinned by sabotage **u1**, which injects exactly the literal reading, and by the verifier's V1, which half-breaks it. |
| **D2** | Decision 2's *"compat flag"* is implemented **caller-side** (pattern wrap in, legacy strip out), not as a flag inside `sig_match`. | Explicitly permitted by driver note (d). `src/wave_viewer.tcl` is not touched at all, so item 1's sabotage-pinned proc keeps **zero blast radius** and items 4-15 inherit `sig_match` exactly as item 1 shipped it. |
| **D3** | **DRIVER RULING OWED. Three residual on-screen deltas** beyond the sanctioned invalid-regexp one, all measured and all pinned (GS12/GS13/GS14): (1) a user's `^…$` no longer matches a `v()`-wrapped name; (2) patterns that see the wrapper text (a bare `v`) now hit; (3) ARE directors / embedded options (`(?i)x`) are an error. | **Root cause, which the item's scope line does not state:** the LEGACY body stripped BEFORE it matched (`xschem.tcl:4479-4483` — `regsub`, then `regexp $pattern $i`), so a full-raw-name subject cannot reproduce it. Driver note (d)'s two halves — *"the MATCH still runs against the full raw name"* AND *"do not change what the dialog puts on screen"* — are therefore in **genuine tension**; this item took the subject clause because it is the one note (d) states positively. The byte-exact alternative (strip the input list before matching, `-sort 0`) violates note (d) AND the item's own `-sort $graph_sort` instruction, so it was not taken. **Two lines + five check expectations** if the driver rules the other way. Independently reproduced by the verifier. |
| **D4** | Decision 4 says *"items 3/4 surface"* the error; item 3 surfaces it as an **EMPTY listbox only**. | The `.graphdialog` left pane has no error widget; adding one is outside the item's Files line, and a live message would fire on every partial pattern (`[`, `[a`, …). **Item 4's search bar owns the error label.** |
| **D5** | Sabotages were reverted from a byte-exact snapshot + md5, **not** `git checkout -- src/xschem.tcl`. | The scout asserted a git checkout was safe *"because `src/xschem.tcl` is committed and clean"* — true only BEFORE the item's edit landed; afterwards a checkout would have destroyed the ITEM along with the sabotage (item 2's D5 situation). Each injection was `diff`-confirmed to be the sabotage and nothing else before the run; each restore `diff`-confirmed IDENTICAL after it, md5-matched, green re-run. (The verifier's own round ran post-commit and could use `git checkout --`.) |
| **D6** | Four of nine sabotages (u3, u5, u6, u7) fired on **supersets** of the scout's predicted targets. | Honest scoping, explained per-sabotage in §4 and the appendix §5 — the shared `GSPLAIN` fixture plus the full-list assertions GS01/GS02 mean one wrong answer trips more than the check that names it. The NAMED sabotage still fires on **exactly one** check, which is the property the item asked for. |
| **E5** | Item 3 retires **NONE** of the three open-coded `split [xschem raw list]` sites (`:2566`, `:6798`, `:7458`). | Driver note (c) answered: none of them is `graph_get_signal_list`, whose input is `xschem raw_query list` arriving as an *argument* from `graph_fill_listbox`. `:7458` is `wviewer::add_trace_dialog` — **item 5's**. Scope deliberately not widened. |
| **E6** | One declared one-line comment correction INSIDE the test file: SM27's stale `wave_viewer.tcl:1571`/`:1577` -> `:1584`/`:1590`. | Item 2's insertion drifted them +13. Declared rather than silent because items 4+ read that comment. It is the only edit outside the item's own appended group. **Verified correct by the verifier from source.** |
| **PROCESS** | The solo `full_audit.sh` was held 34 minutes at 15/283 by a live Pause on the GUI control panel (pressed 25 s after it started). | **NOT overridden** — `GUI_GATE=0` or a hand-written control write would have flooded the user's display and broken the one rule the gate exists to enforce. It completed on Resume. The commit was made before the audit landed (green build, 76/76, 9 sabotages) and then **amended** with the completed receipt. The verifier's audit was likewise Pause-held ~50 minutes and likewise not overridden. |
| **BASELINE FEEDBACK** | **`test_hover_highlight` should be ADDED TO THE FLAKY LIST** — measured **3/10 failures with this item ABSENT**, by interleaved A/B. | It is in neither the 16 HARD nor the 9 FLAKY names because it happened to pass both re-baseline runs. Items 4+ will hit it and should not spend an hour on it again. `test_verb_noun_descend_0200` is a milder case (1 audit fail, then 3/3 clean). Carried alongside **P3** (`test_cadence_drag`'s anchor is on the wrong check) as the two baseline corrections this item earned. |
| **D9** *(this stage)* | The ledger line carries the item's open flags inline rather than a bare `-> DONE (afdd44a0)`, and this file **merged** the implementer long-form instead of clobbering it. | Item 1's/item 2's ledger precedent: D3 is a ruling the driver owes and a bare tick would bury it. Because the implementer wrote its long-form straight to the pipeline path `receipts/03_receipt.md` (and committed it inside `afdd44a0`), this stage put the ledger receipt on top and preserved the long-form verbatim as the appendix — nothing lost, no second file. The receipt is consequently **dirty vs `afdd44a0`**, like `PLAN.md` and `receipts/02_receipt.md`; nothing was committed by this stage. |

**Carried forward, NOT item 3's to fix:** item 2's P2 (the two dead lines in
`signal_list` — still uncovered; item 3 added no coverage and did not touch them), and
item 2's D2 (the three open-coded sites, and which item owes each).

## 9. If a human looks at one thing

Item 3 is **DONE** and nothing here is a failure, so this is a queue for the driver, in
order:

1. **D3 — rule on the match subject.** Driver note (d) asks for two things the legacy
   body's own order of operations makes incompatible (it stripped BEFORE matching). This
   item took the subject clause and pinned all three consequences so they can never be
   silent. **The one users will meet:** in a real raw every voltage is `v(...)`, so a user
   who types a bare `v` in the Graph dialog now gets **every voltage** instead of only
   names containing a literal `v`. Arguably better, definitely different. Two lines and
   five check expectations to reverse — and the longer it sits the more items build on it.
2. **The baseline, twice over: P3** (`test_cadence_drag`'s recorded anchor check is one
   that now PASSES — the next verifier will read its real 2-check failure as a new
   regression) and the **BASELINE FEEDBACK** row (`test_hover_highlight` belongs on the
   FLAKY list at ~30%).

To hand to item 4 when it starts: **P1** (the stale `:14295` citation inside the shipped
comment), **P2** (one fixture element pins the strip's trailing anchor), **D4** (item 4's
search bar owns the invalid-pattern error label — item 3 shows an empty listbox only), and
the **fixture rule** in §3 (do not tidy `GSPLAIN` into a wrapped list).

---

---

# APPENDIX — implementer long-form receipt, preserved verbatim

Below is the receipt as committed inside `afdd44a0` (file
`doc/claude/signal_browser_batch/receipts/03_receipt.md`, 327 lines), unedited. Where it
and §1-§9 above disagree, **§1-§9 wins** — specifically, its §6/§8 citation of
`src/xschem.tcl:14295` for the `source` line is the PRE-edit number (post-edit `:14325`,
see P1), and its §5/§7 claims about sabotage coverage are qualified by P2 (the display
strip's trailing anchor survives mutation).

---

# Item 03 — retrofit the legacy dialog onto the shared matcher — receipt

Batch `signal_browser_batch`, branch `fluid-editing`. HEAD at item start `6a3f8e42`.
Date 2026-08-04. Implementer receipt (the PLAN's older name for this file was
`03_legacy_retrofit.md`; the pipeline's path is `03_receipt.md`, per driver note (a),
and that is what this is).

---

## 1. What shipped

One proc body replaced in `src/xschem.tcl`: `graph_get_signal_list` (`:4469` before,
`:4502` after the comment block). Signature, proc name and the `graph_sort` global are
UNCHANGED. The Graph dialog's two call sites (`graph_fill_listbox` at `:4691` and
`:4696`, both re-measured post-edit) are untouched — same argument shape (a `\n` blob from `xschem raw_query list`),
same return shape (a Tcl list fed to `eval ... list1 insert 0 $retv`).

```tcl
proc graph_get_signal_list {siglist pattern } {
  global graph_sort
  set direction -1
  if {$graph_sort} {set direction 1}
  if {$pattern ne {}} { set pattern ".*(?:$pattern).*" }
  set r [wviewer::sig_match [split $siglist \n] $pattern \
           -syntax regexp -case 1 -sort $direction]
  if {[lindex $r 0] ne {ok}} { return {} }
  set result {}
  foreach i [lindex $r 1] {
    regsub {^v\((.*)\)$} $i {\1} i
    lappend result $i
  }
  return $result
}
```

`src/wave_viewer.tcl` is **NOT touched**. `wviewer::sig_match` ships exactly as item 1
committed it — zero blast radius on item 1's sabotage-pinned proc.

**No C** (settled decision 8). **No new file** (settled decision 9: the checks append to
`tests/headless/test_wave_sigsearch.tcl`).

## 2. On-screen behaviour: measured before and after, not reasoned

The same 15-case probe was run against the SHIPPING legacy body and then against the
retrofit, in-binary (`./src/xschem --pipe -q --nolog --nogui --script <probe>`):

| case | pattern / blob | legacy | retrofit | |
|---|---|---|---|---|
| GS01 | `{}`, `graph_sort 1` | `about i(v1) net5 Out time x1.out` | identical | |
| GS02 | `{}`, `graph_sort 0` | `x1.out time Out net5 i(v1) about` | identical | |
| GS03 | `v(out)` | `out` | identical | |
| GS04 | `i(v1)` | `i(v1)` | identical | |
| GS05 | `"v(aa)\nmm"` | `mm aa` | identical | |
| GS06 | `out` | `about x1.out` | identical | |
| GS07 | `Out` | `Out` | identical | |
| GS08 | `[` | **all six names** | **`{}`** | ← the SANCTIONED change (decision 4) |
| GS09 | empty blob | `{}` | identical | |
| GS10 | `x\|y` | `ay xa` | identical | |
| GS11 | `^time$` | `time` | identical | |
| GS12 | `v\(` on `v(out) zz` | `{}` (0) | **`out` (1)** | ← DECLARED, D3 |
| GS13 | `(?i)out` on `Out zz` | `Out` (1) | **`{}` (0)** | ← DECLARED, D3 |
| GS14 | `^out$` on `v(out) zz` | `out` (1) | **`{}` (0)** | ← DECLARED, D3 |
| GS15 | `"a b\nc"` | `{a b} c` | identical | |

Eleven of fifteen byte-identical; one sanctioned change; three declared deltas (§5 D3).

## 3. Why the body is what it is

Five load-bearing details, all in the proc's comment block so a later reader cannot
"simplify" one away:

* **(a) the sort mapping.** `set direction -1 / if {$graph_sort} {set direction 1}`
  mirrors the legacy `-decreasing`/`-increasing` pair line for line — same truth test,
  same throw on a junk `graph_sort`. NOT collapsed to `[expr {$graph_sort ? 1 : -1}]`;
  the item says keep the mapping exactly.
* **(b) `.*(?:$pattern).*` — THE COMPAT DEVICE** (this is item 3's answer to decision 2's
  "compat flag"; see D1/D2). `sig_match`'s regexp arm is whole-name anchored (decision 3,
  the `^(?:$pattern)$` wrapper at `wave_viewer.tcl:1573`); the legacy `regexp $pattern $i`
  was UNANCHORED. Wrapping makes `sig_match` compute `^(?:.*(?:$pattern).*)$`, which IS
  the unanchored semantics. **Measured: without it, typing `out` returns NOTHING** where
  it returns `about x1.out` today (sabotage u1). The non-capturing group is not cosmetic —
  it keeps a user's alternation whole (`x|y` over `{xa ay zz}` is `{ay xa}` with it and
  `{}` without; sabotage u2). The EMPTY pattern is passed through UNTOUCHED so
  `sig_match`'s own coded "empty pattern matches everything" short-circuit (`:1581`) is
  what fires.
* **(c) the strip is the legacy `regsub {^v\((.*)\)$}`, not `wviewer::sig_bare`.**
  `sig_bare` strips ANY `<fn>(...)` wrapper (`^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$`) and would
  put `v1` on screen where the dialog shows `i(v1)`. Measured under sabotage u3.
* **(d) the sort runs on FULL names, the strip after**, exactly as the legacy body did (it
  `lsort`ed at `:4475` and stripped inside the loop at `:4480`). Strip-then-sort reorders
  the listbox — measured: `"v(aa)\nmm"` with `graph_sort 1` displays `mm aa`, not `aa mm`
  (sabotage u7).
* **(e) `if {[lindex $r 0] ne {ok}} { return {} }`** — settled decision 4. The legacy
  `set err [catch {regexp $pattern {12345}} res]; if {$err} {set pattern {}}` widened a
  typo into "show everything".

Also recorded in the comment: **this is the FIRST `src/xschem.tcl` -> `wviewer::` call in
the tree**, so `wave_viewer.tcl` is now load-bearing for the legacy Graph dialog. No
`info procs` fallback was added — it would be an untestable branch, and the ⚠'s premise
was checked and is safe (§6).

## 4. Tests

| | |
|---|---|
| test file | `tests/headless/test_wave_sigsearch.tcl` (settled decision 9 — appended, existing style, inside the existing outer `catch ... bigerr`, reusing `check` and `pcall`; NO new helper) |
| checks added | **15** (GS01-GS15) |
| checks total | **61 -> 76** |
| green | `--nogui` standalone -> `RESULT: ALL PASS (76 checks)`; `tests/headless/run_suites.sh test_wave_sigsearch` (under the GUI gate, real DISPLAY) -> `PASS  run 1/1  RESULT: ALL PASS (76 checks)` |
| build | `cd src && make` -> *"Nothing to be done for 'all'"* — Tcl-only item, binary unchanged |

Banner updated: the `GS01-GS15` line in the group index, and `graph_sort` added to the
PROCESS STATE LEFT BEHIND block (the group leaves it DEFINED and set to **0** — the value
`set_ne graph_sort 0` gives it when `.graphdialog` opens, so nothing downstream can tell).

**Fixture rule, stated in the group header:** `GSPLAIN` deliberately carries NO
`v(...)`-wrapped name, and GS05/GS12/GS13/GS14 assert a length or a strip-invariant
element. That is what makes the NAMED sabotage single-target. A later item that "tidies"
these fixtures by reusing a wrapped list silently hands that sabotage extra targets — the
same trap SM05's comment already documents for item 1.

## 5. Sabotage table — nine injections, every one measured, every one reverted

The item was still UNCOMMITTED at this point, so `git checkout -- src/xschem.tcl` would
have destroyed the ITEM along with the sabotage (item 2's D5 situation, and the scout's
"src/xschem.tcl is committed and otherwise clean, so `git checkout --` is safe" was true
only BEFORE the edit landed). Reverts therefore came from a byte-exact snapshot of the
item's own file, each injection proven by `diff` to be the sabotage and nothing else
BEFORE the run, each restore proven `IDENTICAL` by `diff` AFTER it, plus an md5 match and
a clean green re-run at the end (`53c567ac8f82ecb548303915206d23c2`, `ALL PASS (76)`).

| # | sabotage | predicted | measured | exactly? |
|---|---|---|---|---|
| **NAMED** | delete the `regsub {^v\((.*)\)$} $i {\1} i` line (revert the display strip) | GS03 | **GS03 alone**, 1 FAILED / 75 passed (`v(out)` instead of `out`) | **yes** |
| u1 | delete the `.*(?:$pattern).*` wrap (the PLAN's literal composition) | GS06+GS10+GS12 | **GS06, GS10, GS12** — exactly the predicted three. This is the sabotage that proves D1 is load-bearing: `out` -> `{}`. | **yes (3, declared)** |
| u2 | drop the non-capturing group (`.*$pattern.*`) | GS10 | **GS10 alone**, 75 passed | **yes** |
| u3 | swap the legacy strip for `wviewer::sig_bare` | GS04 | GS01, GS02, **GS04** — superset (see below) | no |
| u4 | drop `-case 1` | GS06+GS07 | **GS06, GS07** — exactly the predicted two | **yes (2, declared)** |
| u5 | invert the sort mapping | GS01+GS02 | GS01, GS02, GS05, GS06, GS10, GS15 — superset | no |
| u6 | restore the legacy widening (on `err`, return the whole sorted+stripped list) | GS08 | GS08, GS13 — superset of 2 | no |
| u7 | strip BEFORE `sig_match` (strip-then-sort) | GS05 | GS05, **GS12, GS14** — superset | no |
| u8 | pass the blob instead of `[split $siglist \n]` | GS15 | **GS15 alone**, 75 passed | **yes** |

**The NAMED sabotage fired on exactly one check.** The four supersets are honest scoping,
not leakage, and each is explainable in one line:

* **u3** — `GSPLAIN` contains `i(v1)`, and GS01/GS02 assert the WHOLE list, so a wrapper
  strip that eats `i(...)` necessarily shows up there too. (The scout predicted "GS04
  alone"; that was measured before GS01/GS02 existed as full-list assertions.)
* **u5** — a sort-direction flip changes every multi-element result in the group, not just
  the two checks that name the direction.
* **u6** — GS13 is also an invalid-pattern check (`(?i)out` is an error under the wrapper),
  so restoring the widening un-empties it too. Both targets are decision-4 checks and
  nothing else.
* **u7** — strip-then-sort also changes the MATCH SUBJECT, so it trips the two subject
  checks (GS12/GS14) on top of the order check. Correct: those are the same defect.

## 6. The ⚠ — load order, checked not assumed

The item's warning: *"`src/xschem.tcl` may not depend on `wave_viewer.tcl` having been
sourced."*

**Verified from source and at runtime. The dependency is SAFE and `sig_match` did not
move.** `src/xschem.tcl:14295` is `source $XSCHEM_SHAREDIR/wave_viewer.tcl`, at column 0,
unconditional, in the same top-level source block as `cmdmode.tcl`, `ase.tcl`,
`ase_window.tcl` and `property_form.tcl`. Runtime-probed under `--nogui`:
`::wviewer::sig_match`, `::wviewer::sig_type` and `::graph_get_signal_list` are all
defined, and the retrofit answers correctly in that configuration (76 checks green under
`--nogui`, which is the configuration where a missing source would bite hardest).

Both facts are recorded in the proc's comment, because nothing about the Graph dialog
otherwise advertises that it now needs the waveform viewer file. A future
"source `wave_viewer.tcl` lazily / only under X" change would break the Graph dialog with
`invalid command name wviewer::sig_match` at keystroke time.

## 7. Verification

1. `cd src && make` -> *"Nothing to be done for 'all'"*.
2. `./src/xschem --pipe -q --nolog --nogui --script tests/headless/test_wave_sigsearch.tcl`
   -> **ALL PASS (76 checks)**.
3. `tests/headless/run_suites.sh test_wave_sigsearch` (GUI gate, real DISPLAY)
   -> **1/1 runs passed, ALL PASS (76 checks)**.
4. Sabotage round: §5, nine injections, each measured, each reverted (`diff` IDENTICAL),
   followed by a clean green re-run and an md5 match against the pre-sabotage snapshot.
5. One solo `tests/headless/full_audit.sh`. It was **held for 34 minutes by a live Pause**
   on the GUI control panel (pressed at 09:02:35, 25 s after the audit started; parked at
   15/283). **It was NOT overridden** — `GUI_GATE=0` or a hand-written `control` write
   would both have flooded the user's display and broken the one rule the gate exists to
   enforce. On Resume it ran to completion:

   ```
   SUMMARY: 265 pass  18 fail  0 crash/timeout  0 skip  (total 283)
   WIREEDIT: PASS      SCRATCH:  0 leaked dir(s)
   ```

   `grep -c "X connection to :0 broken"` -> **0**, so this IS a measurement.
   `test_wave_sigsearch` is in the PASS column. **16 of the 18 fails are the 16 HARD
   baseline names, each on the check the PLAN block records for it** (the action-log/
   self-log cluster; the three PDK libmgr `library_list` fails with the `{SANDBOX TEST}`
   extras from `~/.xschem/library.defs`; `test_fluid_editing` on exactly FE8). All nine
   FLAKY names PASSED, as did `test_wave_trace_menu` and
   `test_resolved_net_hash_bus_0158`, which the re-baseline un-excused.

   **Two non-baseline names, both chased to the ground, neither attributable to item 3:**

   | name | failing check | disposition |
   |---|---|---|
   | `test_verb_noun_descend_0200` | VN6a / VN10d *"click resolved the instance (got `` want x1)"* | `run_suites.sh -n 3` -> **3/3 PASS**. Flake. |
   | `test_hover_highlight` | HV5 *"hover over an instance reports it (=> wire)"* | **Pre-existing flake, PROVEN by an interleaved A/B.** See below. |

   `test_hover_highlight` needed real work, because the naive comparison pointed the wrong
   way: 15/15 PASS with the item reverted vs 7/9 with it present (Fisher p≈0.05) — which
   is the shape of a real regression. That was a **time-ordering confound**: the
   item-present batches ran right after the 283-test audit, when WSLg has degraded; the
   reverted batches ran later, on a settled machine. Re-run as a properly **interleaved**
   A/B, 10 rounds, arms swapped by `git checkout <sha> -- src/xschem.tcl` between every
   single run:

   ```
   ITEM     fails: 3/10        REVERTED fails: 3/10
   failures land in the SAME rounds (4, 7, 10) in BOTH arms
   ```

   Identical rates, time-clustered, and the two observed failures hit *different* checks
   (HV5 once, HV10a+HV10b once) — a defect would be deterministic. Mechanistically it also
   cannot be item 3: **every** caller of `graph_fill_listbox` (`:4779`, `:4906`, `:4924`,
   `:5193`, `:5365`, `:5389`) is a `.graphdialog` widget binding or the dialog build
   itself, so `graph_get_signal_list` is unreachable unless the Graph Properties dialog is
   open, and `test_hover_highlight` never opens it (grepped: no `graphdialog` reference).

   **`nonBaselineFails: []` — measured, and both candidates disproved rather than waved at.**
6. **EYEBALL — DONE**, under a real DISPLAY through `gated_xschem.sh`, on
   `xschem_library/examples/poweramp.sch` with an in-memory raw carrying
   `vsweep time about i(v1) x1.out net5 Out v(out)`. The `.graphdialog` was opened for real
   and the **actual Tk listbox contents** were read back out of the widget
   (`.graphdialog.center.left.list1 get 0 end`) — the thing headless checks cannot see:

   ```
   sort=0 pat={}   -> x1.out vsweep out time Out net5 i(v1) about
   sort=0 pat=out  -> x1.out out about
   sort=0 pat=[    -> (EMPTY)
   Incr.sort toggled -> 1
   sort=1 pat={}   -> about i(v1) net5 Out time out vsweep x1.out
   ```

   All four expectations hold on screen: `v(out)` DISPLAYS as `out` while sorting in
   `v(out)`'s full-name slot (between `vsweep` and `time` descending — decision (d) visible
   in the widget); `i(v1)` is NOT stripped; `out` still matches unanchored; `[` gives an
   **EMPTY listbox** where it used to show everything; and the `Incr. sort` checkbox still
   flips the order. A window capture (`xwd -id [winfo id .graphdialog]`, converted to PNG)
   confirms the dialog renders normally with the expected list — `import`/`scrot` are not
   installed on this box, `xwd` on `[wm frame ...]` BadMatches under WSLg, and `winfo id`
   is what works.
7. `git status --porcelain -- src/ tests/ doc/` shows this item's three files plus the two
   pre-existing dirty driver files (`PLAN.md`, `receipts/02_receipt.md`), which are NOT
   staged. No droppings: nothing was written into the repo; probes and the snapshot live
   in the scratchpad.

## 8. Anchors re-verified from the shipping tree

Every line the scout cited was re-measured before it was trusted. Two of them had drifted
and the scout had already caught both; nothing new drifted.

* `src/xschem.tcl:4469` — `proc graph_get_signal_list {siglist pattern } {`. EXACT, body
  `:4469-:4486`.
* `src/xschem.tcl:4480` — `regsub {^v\((.*)\)$} $i {\1} i`. EXACT. **And `:4479-:4483`
  shows the legacy stripped BEFORE it matched** (`regsub` then `regexp $pattern $i`), which
  is the mechanical source of the D3 deltas — worth stating plainly because the item's
  scope line does not.
* `src/xschem.tcl:4477-4478` — `set err [catch {regexp $pattern {12345}} res]` /
  `if {$err} {set pattern {}}`. Both exact.
* `src/xschem.tcl:4661`, `:4666` — the two `graph_get_signal_list` call sites inside
  `graph_fill_listbox` (`:4640-:4671`). Exact, and untouched by this item.
* `src/xschem.tcl:14295` — the unconditional `source .../wave_viewer.tcl`. Exact (§6).
* `src/wave_viewer.tcl:1490` `sig_type`, `:1528` `sig_match`, `:1573` the `^(?:$pattern)$`
  wrapper, `:1581` the empty-pattern short-circuit, `:1596` `return [list ok $out]`. All
  exact.
* `src/wave_viewer.tcl:1584` / `:1590` — the two SEPARATE `-nocase` flags. The scout's
  +13 drift call is confirmed; the stale `:1571`/`:1577` was baked into the TEST file's
  own SM27 comment and is corrected in this item (declared, E6).
* `src/wave_viewer.tcl:1619` `sig_bare` (`^[A-Za-z_][A-Za-z_0-9]*\((.*)\)$` — it strips
  `i(v1)` to `v1`, which is exactly why it may not replace the legacy strip), `:1626`
  `sig_split`, `:1636` `signal_entry`, `:1659` `signal_list`. All exact.
* The three open-coded `split [xschem raw list]` sites — `:2566`, `:6798`, `:7458` (with
  the `catch` at `:7455`). All exact. **None is item 3's** (E5).

## 9. Divergences from the PLAN

| # | divergence | reason |
|---|---|---|
| **D1** | The PLAN's literal composition — `sig_match -syntax regexp` with the user's pattern AS-IS — is MEASURED to break the dialog, so the caller pre-wraps non-empty patterns as `.*(?:$pattern).*`. | Under the literal reading, typing `out` returns `{}` where the dialog returns `about x1.out` today (sabotage u1 injects exactly that and measures it). The item's **bolded** *"On-screen behaviour must not change"* and its single-exception clause win over the call spelling. `sig_match` is UNCHANGED and still anchors — **decision 3 is not overturned**; the legacy dialog is simply a caller that always searches with an implicit `.*...*`, a legal pattern under decision 3's own semantics. If the driver disagrees, the alternative is to accept anchoring in the legacy box, and the measured consequence is the number above. |
| **D2** | Decision 2's "compat flag" is implemented as a **caller-side transform** (pattern wrap in, strip out), not a flag inside `sig_match`. | Explicitly permitted by driver note (d). Zero blast radius on item 1's sabotage-pinned proc; `src/wave_viewer.tcl` is not touched, so items 4-15 inherit `sig_match` exactly as item 1 shipped it. |
| **D3** | **Three residual on-screen deltas** beyond the sanctioned invalid-regexp one, all measured and all pinned (GS12/GS13/GS14): (1) a user's `^...$` no longer matches a `v()`-wrapped name; (2) patterns that see the wrapper text (a bare `v`, a `.` adjacent to the wrapper) now hit; (3) ARE directors / embedded options (`(?i)x`, `***=x`) are an error. | (1) and (2) follow directly from driver note (d)'s *"the MATCH still runs against the full raw name"* — the legacy body stripped BEFORE matching (`xschem.tcl:4479-4483`), so a full-name subject cannot reproduce it. (3) follows from decision 3's wrapper and is already documented in `sig_match`'s own header. **Note (d)'s two halves are in tension** — full-raw-name subject AND no on-screen change — and only the driver can close it; this item took the subject clause because it is the one note (d) states positively. The alternative that removes (1) and (2) entirely (strip the input list BEFORE matching, keeping the sort on full names with `-sort 0`) is byte-exact legacy but violates note (d) AND the item's own `-sort $graph_sort` instruction, so it is NOT taken. Named here so the driver can rule; it is a **two-line change plus five check expectations** if the ruling goes the other way. |
| **D4** | Decision 4 says *"items 3/4 surface"* the error. Item 3 surfaces it as an **EMPTY listbox only**. | The `.graphdialog` left pane has no error widget; adding one is outside the item's Files line, and a live CIW message would fire on every partial pattern (`[`, `[a`, ...). Item 4's search bar owns the error label. |
| **D5** | Sabotages reverted from a byte-exact snapshot, not `git checkout -- src/xschem.tcl`. | The item was uncommitted, so a git checkout would have destroyed the item along with the sabotage. Each injection was `diff`-confirmed to be the sabotage and nothing else before the run; each restore was `diff`-confirmed IDENTICAL, md5-matched and followed by a green re-run — the same guarantee, one level down (item 2's D5 precedent). |
| **D6** | Four of nine sabotages fired on **supersets** of their predicted targets (u3, u5, u6, u7); the scout predicted single targets for three of them. | Honest scoping, explained per-sabotage in §5 — the shared `GSPLAIN` fixture and the full-list assertions GS01/GS02 mean one wrong answer trips more than the check that names it. The NAMED sabotage still fires on exactly one check, which is the property the item asked for. |
| **E5** | Item 3 retires **NONE** of the three open-coded `split [xschem raw list]` sites (`:2566`, `:6798`, `:7458`). | Driver note (c) answered: none of the three is `graph_get_signal_list`. `:7458` is `wviewer::add_trace_dialog`, which is **item 5's**. Item 3 owns only the `src/xschem.tcl` proc, and its input is `xschem raw_query list` (not `raw list`) arriving as an argument from `graph_fill_listbox`. Scope deliberately not widened. |
| **E6** | One declared one-line comment correction INSIDE the test file: the SM27 comment's `wave_viewer.tcl:1571`/`:1577` -> `:1584`/`:1590`. | Item 2's insertion drifted them +13. Declared rather than silent because items 4+ will read that comment, and it is the only edit this item makes outside its own appended group. |

**Carried forward, NOT item 3's to fix:** item 2's D1 `path`/`leaf` ruling (now AFFIRMED as
settled decision 14) and its P2 (the two dead lines in `signal_list` — still uncovered;
item 3 added no coverage for them and did not touch them).

## 10. Note for the next item's baseline work

`test_hover_highlight` fails **~30% of the time on this box with the item absent**
(measured: 3/10 in the REVERTED arm of §7.5's interleaved A/B). It is in neither the 16
HARD names nor the 9 FLAKY names of the 2026-08-04 re-baseline, because it happened to
pass both re-baseline runs. **Items 4+ will hit it and should not spend an hour on it
again** — it belongs on the FLAKY list. `test_verb_noun_descend_0200` is a milder case of
the same (1 audit fail, then 3/3 clean).

The methodological point is worth more than the two names: the *first* comparison
(15/15 reverted vs 7/9 present) pointed at a regression, and it was wrong. GUI flake rates
on this box drift with how recently the display has been hammered, so **a sequential
A-then-B comparison is not evidence** — only an interleaved one is.

## 11. If a human looks at one thing

**D3 / the tension inside driver note (d).** Note (d) asks for two things that the legacy
body's own order of operations makes incompatible: the legacy stripped BEFORE matching, so
"match against the full raw name" and "on-screen behaviour must not change" cannot both
hold. This item took the subject clause and pinned the three consequences so they can never
be silent. The one that will be noticed in practice: in a real raw every voltage is
`v(...)`, so a user who types a bare `v` in the Graph dialog now gets **every voltage**
instead of only names containing a literal `v`. Arguably better, definitely different.
A ruling the other way is two lines and five check expectations.
