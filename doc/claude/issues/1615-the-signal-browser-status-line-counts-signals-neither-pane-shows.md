# 1615 — the signal browser's status line counts signals neither pane shows

**STAMP:** `v1 claim=fixed tree=a708b74d stamped=2026-09-28 fix=taken open=3`

Status: **FIXED**, 2026-09-28, in `wviewer::browser_refresh`. Measured on this tree
at `a708b74d` · Branch: `fluid-editing`
Related: spec `doc/claude/specs/waveform_signal_browser_two_pane.md` §6, §7.2 and
ruling **R11**; `doc/claude/specs/waveform_signal_browser.md` limit **CNT**;
TWO-PANE items **10**, **11**, **12** and **19** of
`doc/claude/signal_browser_2pane_batch/`; rows **BW80**–**BW84** of
`tests/headless/test_wave_sigbrowser_panes.tcl`. Same defect shape as issue
**1251** (a status line blind to a filter bit) one surface over.

## The defect

`wviewer::browser_refresh` built the sidebar's count as

```tcl
set st "[llength $names] of $total signals"
```

`$total` is the current database's whole inventory (`llength $browsersigs($token)`).
`$names` is the **bar-matched** name list from `wviewer::browser_match` — and it is
**class-filter blind**: R11's two checkboxes (`Show device internals`, `Show internal
source branch currents`) are applied to `$entries`, several lines further down, and
their result is what the tree, the lower pane and every gesture consume.

So the caption reported a set that **no surface in the window shows**. With the search
and filter bars empty — the state the browser opens in — `$names` *is* the whole
inventory, so the sentence degenerated to `<total> of <total>`: the same number twice,
no matter what the user had ticked.

## Measured, 2026-09-28, on this tree at `a708b74d`

Driven through the shipped widget variables on `tests/headless/fixtures/tb_bandgap_vars.txt`
(424 names), which is the one inventory in the tree whose classes discriminate.
Class histogram through `signal_entry`/`sig_class`: **devnode 234, net 140, srcbranch
50, devmeas 0**, summing to 424.

| `devint` | `srccur` | both panes hold | tree nodes | **the caption said** |
|---|---|---|---|---|
| 1 | 1 | 424 | 129 | `424 of 424 signals` |
| **0** | **1** | **190** | **45** | `424 of 424 signals` |
| 1 | 0 | 374 | 129 | `424 of 424 signals` |
| 0 | 0 | 140 | 45 | `424 of 424 signals` |

Row 2 is R11's shipped default, so **this is what the browser said when it opened**:
424 of 424, with 234 signals hidden and the tree showing a third of its nodes.

With a pattern in the bar the two narrowings compose, and the caption followed only
one of them. Search `*b*` matches 238 labels (234 devnode, 2 net, 2 srcbranch):

```
devint 1 srccur 1   panes 238   caption "238 of 424 signals"    (correct)
devint 0 srccur 1   panes   4   caption "238 of 424 signals"    (wrong by 234)
```

### The `+N from M other DB` suffix was the same defect

The All-DBs loop narrows each foreign inventory with `browser_class_filter` into
`$dent`, hands **`$dent`** to the tree (`lappend groups`) and to the lower pane
(`browserseadbent`) — and then accumulated **`$dnames`**, the pre-filter list, into
the suffix. `ndbs` was incremented unconditionally, so a foreign database the class
filter emptied entirely was still counted as a database.

Measured with two seeded foreign inventories — `d:7` mixed (2 net, 1 devnode, 1
srcbranch) and `d:8` entirely device-classed:

```
devint 1 srccur 1   caption "...+6 from 2 other DBs"   foreign panes {6 2}   (correct)
devint 0 srccur 1   caption "...+6 from 2 other DBs"   foreign panes {3 1}
                    -> d:8 mints NO header and NO row in the tree, its pane
                       snapshot is empty, and the sentence still claims it
```

The strongest single case measured, bar `*body*` plus one foreign database:
`234 of 424 signals, +2 from 1 other DB` **while both panes were completely empty
and the tree held no foreign row at all.**

## Why it survived the whole two-pane batch, and why nothing was red

TWO-PANE item 12 wired the two checkboxes and recorded the caption as owed. Its
receipt (`12_receipt.md` §7) and spec §7.2 both give the same reason for not
touching it:

> **Not changed here**: a dozen checks across four files pin `.ph` byte-identically
> (BD52, BX37, BX42, BX44-BX46, BH50, BH51, BH54) … whoever takes §7.2's three-state
> caption should settle it then.

**That reason was measured for this issue and it does not hold.** Enumerating every
check in the tree that reads `.ph`'s text:

* There are **43**, not twelve, across ten files.
* "Twelve" reconciles only by counting **BX37 three times** (it has three `.ph`
  pins). The distinct ids are **ten**.
* **Nine of the ten** pin *navigation* sentences written by `browser_say`/`browser_msg`
  (`showing x1.x2`, `no signals under '…'`, `showing the simulation top level`). The
  caption does not build those, so the change cannot touch them.
* Only **BD52** among the named ten carries a count, and the list omits **BD52b**,
  which is the sole pin anywhere on the `+N from M other DB` suffix.
* **Not one of the 43 rows' expectations had to change.** Every fixture that asserts
  a count is entirely `net`-classed — `BTFIX` 8/8 net, `_i12` and `_0315` 3/3 net,
  `_i14` 3+3 all net, `_i1315`'s `brB` 3/3, `_panes`' three-name inventory, and every
  `_digital` name either `digital` (never filtered) or from a 2-name all-net raw — so
  `browser_class_filter` removes nothing from them and the caption reads identically
  before and after.
* The 424-name corpus **is** seeded into a live browser by three suites
  (`_panes`, `_keys`, `_sea`) and **none of them ever asserted `.ph`**.

So the caption was free to be wrong and the whole 43-row wall would have stayed green.
That is `test_scratch_home_note` row `C1`'s shape one level in: **the sentence that
said the string was pinned was itself the thing nothing checked.** The tree also
carried **three mutually inconsistent versions of the list** — spec §7.2 (ten ids,
includes BK37, omits BD52b), `browser_sea_say`'s own header in `src/wave_viewer.tcl`
(two different lists, one of which includes BD52b and omits BK37), and
`11_receipt.md` (the origin, "~12 checks across four files" for a ten-id list).

## What was changed

Three lines in `wviewer::browser_refresh`, and **nothing else** — no tree change, no
pane change, no gesture change, no new user-facing vocabulary:

```tcl
set st "[llength $seaent] of $total signals"     ;# was [llength $names]
incr extra [llength $dent]                       ;# was [llength $dnames]
if {[llength $dent]} { incr ndbs }               ;# was unconditional
```

`$seaent` is the class-filtered ∩ bar-matched set already built above — the set spec
§6 calls "one consistent set" and the one both panes consume. It is provably never
larger than `$names`, so the numerator can never exceed the denominator (18 measured
points confirm it, including a duplicate-name inventory, the only shape that could
have inverted it).

### Three decisions, with the rejected alternative named

* **The denominator stays `$total`, the raw's own inventory.** REJECTED:
  `[llength $entries]`, i.e. `190 of 190 signals` — true, and it says nothing. The gap
  between the two numbers *is* the information about what the checkboxes are hiding.
  Row BW80 pins the denominator at 424 across all four combinations so this cannot
  drift back.
* **The caption is re-numerated, NOT routed through `browser_msg`'s three-state
  formatter.** Spec §7.2 files the caption alongside that formatter, which is the
  natural reading — and REJECTED, measured: `browser_msg`'s `seabars`/`seaclass`/
  `seacount` sentences describe the **selected node** on `$f.pw.sea.st` and carry a
  parenthetical naming which narrowing emptied it. Reusing them here would make one
  proc the shared owner of two surfaces with different subjects, put a parenthetical
  on a sidebar line that **alternates with `browser_say`'s navigation sentences**, and
  pull `BK33`'s nine-rendering byte-freeze and `BK34`'s one-formatter source oracle
  into scope — for a change that moves one integer. No new sentence was written, so
  **no wording needs ratifying** (contrast issue 1251, which added a clause and owes
  a `rule` debt for it).
* **`ndbs` is guarded but `lappend groups` is not.** Fixing `extra` alone would turn
  the emptied-database case into `+0 from 1 other DB`, which still names a database
  nobody can see, so both numbers moved. But the group itself is left appended: an
  empty entry list mints no rows, so it is already invisible, and `browserseadbent`
  keeping its empty key is what lets row BW83 tell "this database was emptied" apart
  from "this database was never seeded". **This issue moves the status line and
  nothing else.**

## The fence, and it was written first

Rows **BW80**–**BW84** of `tests/headless/test_wave_sigbrowser_panes.tcl`, added and
run **before** the product change. The red, verbatim from that run:

```
FAIL: BW80 -> {{{424 424} 424} {{424 424} 190} {{424 424} 374} {{424 424} 140}}
          exp {{{424 424} 424} {{190 424} 190} {{374 424} 374} {{140 424} 140}}
FAIL: BW81 -> {Signal Browser / 424 of 424 signals}
          exp {Signal Browser / 190 of 424 signals}
FAIL: BW82 -> {*b* {{{238 424} 238} {{238 424} 4}}}
          exp {*b* {{{238 424} 238} {{4   424} 4}}}
FAIL: BW82 (THE BAR'S RESTORE) -> {{424 424} 190}   exp {{190 424} 190}
FAIL: BW83 -> ...{{Signal Browser / 424 of 424 signals, +6 from 2 other DBs} {3 1}}
          exp ...{{Signal Browser / 190 of 424 signals, +3 from 1 other DB}  {3 1}}
FAIL: BW83 (THE FOREIGN RESTORE) -> {0 0 {Signal Browser / 424 of 424 signals}}
          exp {0 0 {Signal Browser / 190 of 424 signals}}
ok:   BW84 (BW83's PRECONDITION)                    {4 3 2 2 0}
RESULT: 6 FAILED (82 passed)
```

BW80's first tuple shows the defect at its plainest: the caption reads `424 424` in
**all four** combinations while the pane set moves 424 → 190 → 374 → 140.

After the change: `RESULT: ALL PASS (88 checks)`.

Two properties of the rows worth keeping:

* **Every numeric row asserts the caption against a live set in the same tuple**, not
  against a literal alone — BW80 against `browserseaent`, BW83 against
  `browserseadbent`. A literal alone is green on a caption that agrees with nothing,
  and the pairing cannot be satisfied by making both wrong because `bw_seen` is the
  very number row BW60 pins.
* **BW84 is BW83's precondition**, asserting that the two seeded foreign inventories
  really carry the classes BW83's arithmetic depends on (`{4 3 2 2 0}`). Without it,
  a name I merely *believed* was device-classed would make BW83 agree with the wrong
  thing.

## Sabotage matrix (md5 of `src/wave_viewer.tcl` verified restored after the run)

One variant per changed line, so each is shown to be independently fenced rather than
carried by the others:

| variant | red rows | note |
|---|---|---|
| `numerator-reverted` (`$seaent` → `$names`) | BW80 BW81 BW82 BW82-restore BW83 BW83-restore (**6**) | this is the pre-fix tree, i.e. the red transcript above |
| `denominator-collapsed` (`$total` → `[llength $entries]`) | the same **6** | |
| `extra-reverted` (`$dent` → `$dnames`) | BW83 (**1**) | |
| `ndbs-unguarded` (drop the `if`) | BW83 (**1**) | |

⚠ **The first two variants red the same six row NAMES**, so the row set alone does not
tell a wrong numerator from a wrong denominator — only the detail lines do (BW80 carries
both numbers in its tuple, `{190 424}`, which is what makes the distinction recoverable).
Recorded rather than fixed by adding a seventh row: a reader diagnosing a red here should
read the tuple, not the name.

## ⚠ AND THE SUITE CARRYING THE FENCE WAS RUN BY NOTHING

Measured while fencing this: **all fourteen `test_wave_sigbrowser*` suites — and in
fact every `test_wave_*` suite in the tree — are in neither `hcases` nor `dcases` in
`tests/run_regression.tcl`.** `/usr/bin/grep -c sigbrowser tests/run_regression.tcl`
returns **0**. They run only under `tests/headless/full_audit.sh`, which globs
`test_*.tcl`, and full_audit is not what gates a commit.

So a new fence added here would have rotted exactly as `test_scratch_home_note` row
`C1` did. **`test_wave_sigbrowser_panes` is therefore registered in `dcases` in the
same commit** — `dcases` and not `hcases`, because the BW56+ band is display-only
(under `--nogui` this file runs BW01–BW14 and prints an uppercase `SKIPPED:` banner,
which T1 does not count as a `skip:`).

### ⚠⚠ AND REGISTERING IT EXPOSED WHY NONE OF THEM COULD BE

The first gate of that registration came back **`cases=105 blocks=104
counted_failures=1 skips=8`**, and the one counted failure was the newly registered
suite — *with all 88 of its own checks passing*:

```
HARNESS: headless/test_wave_sigbrowser_panes (display arm) did not complete cleanly
         (exit=0, OVERALL_ok=0, died=0) -- crashed, aborted mid-script, or a check
         failed: FAIL
RESULT: ALL PASS (88 checks)
```

`tests/banner_rule.tcl`'s `banner_complete` — the ONLY Tcl reader, and the one
`run_regression.tcl` sources — is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`, and that
file's own header says it *"implements no `RESULT: ALL PASS` spelling at all"*.
`wvbs_finish` in `tests/headless/wvbs_common.tcl`, the shared epilogue of all fourteen
`test_wave_sigbrowser*` suites, printed **only** the `RESULT:` line. **So this family
was structurally unregisterable, and that — not an oversight — is why all 34
`test_wave_*` suites sat outside T1.**

`run_suites.sh` and `full_audit.sh` each carry their own ERE and both DO accept
`RESULT: ALL PASS`, which is why every standalone and audit run had always looked
clean. **The two readers that could see these suites were the two that are not the
gate.**

Fixed here by making `wvbs_finish` emit `OVERALL: ok ($npass checks)` **in addition to**
its `RESULT:` line — `RESULT:` kept last, because `summarize_all` publishes a case's
*last* `RESULT:` line. Measured: **119 suites in `tests/headless` already print that
sentinel and `wvbs_common.tcl` printed it zero times**, so the outlier conforms.
REJECTED: teaching `banner_rule.tcl` a fourth spelling — it would mean re-spelling all
three readers plus section K of `test_audit_classifier.tcl`, and forcing a ruling on
the inner-parenthesis divergence that file documents as deliberate
(`test_ase_bus_bits_0159` emits `(12 checks, 2 group(s) skipped)`).

⚠ **This is the same defect family as issues 0420, 0456, 0492, 0629 and 0689**, whose
standing red `banner_rule.tcl`'s header records as *"filed FOUR times and waved through
as furniture each time"* — here wearing a different spelling: not a counted
`OVERALL: ok`, but a family that never emitted the sentinel at all. The lesson that
generalises is in `doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`:
**a suite's banner is only ever validated by the reader that actually reads it, so
"it passes standalone" is no evidence that it can be registered.**

`test_audit_classifier` (75 checks), `test_regression_concurrency_1476` (46) and
`test_scratch_home_note` (22) — the three suites that police the banner rule, the
counted shapes and `summarize_all` itself — were run against the change and all pass.

**The other thirteen are left unregistered and that is a separate decision, not an
oversight.** Registering the family wholesale would take T1 from 104 cases to ~118
and add its whole display-arm runtime to a run that already takes ~600 s, which is a
cost worth measuring on its own rather than smuggling into a one-integer fix. The
finding is recorded here so it is not re-discovered.

## Still open

* **The label's rendered width is unmeasured, and needs eyes.** `.ph` carries
  `-width 22` while the sentence with the All-DBs suffix is ~50 characters, so what a
  user actually *sees* may be clipped. `cget -text` cannot tell you that and no suite
  measures it. ⚠ This change cannot make it worse: `190 of 424` and `424 of 424` are
  the same length, as are `+0` and `+3`, and the guarded `ndbs` can only *remove* the
  suffix. A `look` debt could not be filed — `owed.sh` writes are currently refused by
  the permission classifier — so it is recorded here instead.
* **The thirteen other unregistered `test_wave_sigbrowser*` suites**, and the wider
  `test_wave_*` family, per the section above. The banner blocker is now removed for all
  fourteen, so registering them is a cost decision rather than an impossibility.
* **The other 320 unregistered `tests/headless/test_*.tcl` suites** — 334 of 418 files are
  in neither `hcases` nor `dcases` — whose epilogues are unmeasured against
  `banner_complete`. Written up, with the decision not to register them, in
  `doc/claude/code_analysis/t1_runs_84_of_418_headless_suites.md`.

## Documents this change falsifies, and which were corrected

Corrected here: spec `waveform_signal_browser_two_pane.md` §7.2's "still owed /
class-filter blind / twelve checks" paragraph; `waveform_signal_browser.md`'s **CNT**
limit row; and the two source comments that carried the stale list —
`browser_sea_say`'s header in `src/wave_viewer.tcl` and this suite's own BW56 block
header in `test_wave_sigbrowser_panes.tcl`.

**Deliberately left alone:** every dated receipt in
`doc/claude/signal_browser_2pane_batch/` (11, 12, 13, 14, 15, 16, 17b, 18, 19,
`LEDGER.md`, `item_pipeline.js`) and
`doc/claude/suggestions/next_session_2pane_item11.md`. Those are records of what was
known when they were written; editing them to match today would falsify the record,
per CLAUDE.md's rule about dated records. A reader who finds the old sentence there
should land on this file.
