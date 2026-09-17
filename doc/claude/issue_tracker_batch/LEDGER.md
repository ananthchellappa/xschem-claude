# Ledger — issue tracker batch

Receipts collected by the driver, newest stage at the bottom. A row lands here only
after the driver has read the receipt and checked at least one of its claims.

**Opened** 2026-09-17 at `2cbce753`, branch `fluid-editing`.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| A1 | sample files 1–10, classify against the tree | **DONE** | **accepted** — and it re-aims the batch | — |
| A2 | sample files 11–20, classify against the tree | **DONE** | **accepted** — and it corrects the plan twice (see below) | — |
| A3 | sample files 21–30, classify against the tree | **DONE** | **accepted** — it decided the design (see below); triggered D8 | — |
| A4 | sample files 31–40, classify against the tree | **DONE** | **accepted** — and it caught driver error 6, in its own dispatch brief | — |
| E1 | triage 190 `rule` debts — *does this reach a person?* | **DONE** | **accepted** — and it refutes the driver's claim to the user | — |

## Running findings

### A2 (files 11–20) — the dangerous direction was empty; the **citation layer** is what rots

`TRUE-OPEN 7 · TRUE-FIXED 2 · STALE-FIXED 1 · BAD-FIX 1 · ROTTED-CITE 8 · STALE-OPEN 0 ·
DUPLICATE 0 · UNKNOWN 0.` n=10 — **not a rate** (D1).

**The headline is the shape, not the count. In all eight rotted citations the symbol
still existed and still behaved as the issue described — only the coordinates died.**
0654 has 5 cites and 5 misses; 0674's two load-bearing cites drifted **~15 000 lines**;
0618's ~20 bad cites sit in a section titled *"so a later reader need not re-derive it"*.

**This converges with the driver's symbol scan from the opposite direction**, and the two
were measured independently: symbols are **98.4% stable** (2016 backticked `foo()`
citations, 33 absent — and see the correction below, of which only a handful are rot at
all), while A2 found line coordinates wrong **8 times in 10**. The tracker's problem is
not that it describes the wrong code. **It is that it points at the wrong place.**
`src/op_annot.tcl:2366-2368` already models the answer in shipped source: *"Cited by
function name, not by line number, on purpose."*

**The rot has escaped the tracker into shipped source.** `src/ciw.tcl:122-126` repeats
0654's three dead coordinates as fact; `src/ase.tcl:15795` cites `ase.tcl:802` from inside
`ase.tcl`. **A checker scoped to `doc/claude/issues/` would miss half the corpus** — C1
must be able to sweep `src/` comments even if D1 only repairs the tracker.

**0442 is a `BAD-FIX` the schema did not anticipate: a placement defect, not a truth
defect.** Its numbered item 1 was accurate when written; the tree then fixed the defect by
the *unnumbered alternative buried at the end of the same section*, and the file's own
header records why the prescribed shape was abandoned — *"a hand-maintained mirror of
another module's rules is wrong by construction and had already drifted twice."* Pasting
item 1 today re-introduces what was deliberately deleted. **No status field would have
caught this**, so B1 must make a prescribed fix say **which option was taken**, not merely
whether it was verified.

**3 of 10 carry their own refutation 100+ lines below the wrong text.** 0665 line 3 says
OPEN and line 59 says FIXED. Append-without-touching-the-top is not an occasional lapse —
it is the corpus's default editing motion, and it is what the **510 both-words** census
measures. The header block has to be able to express supersession.

**Sizing D7: 9 of 10 needed no suite run at all.** The `UNKNOWN`/`NEEDS-RUN` fraction may
be small. The exception is 0448's count-instability claim, which needs repeated T1s and
cannot be refuted by a single green run.

**Two corrections owed upward, both accepted:**
* `PLAN.md:3` said the batch opened at `2cbce753`; **HEAD was `8608c7ef`** by the time A2
  read it. ⚠ **The driver's own plan carried a rotted tree-state citation, inside the
  batch about rotted tree-state citations, within an hour of writing it** — and it rotted
  because *the driver itself committed twice*. This is the sharpest possible argument for
  B1: a tree state in prose decays the moment anyone commits, so the convention must be
  cheap to re-stamp or it will not be kept.
* **CLAUDE.md's `run_regression.tcl:376`** for the four counted shapes is now **`:387`** —
  the same citation CLAUDE.md already records as having moved once from `:327`. Third
  position for one sentence.
* A2 also **refused a hint in its own dispatch**: the driver suggested 0676 might concern
  `share_farm_child` launching children under the developer's real `HOME`; 0676 is about
  action-log **slot 0** and has nothing to do with `HOME`. Do not merge them in D1.

A2 explicitly records that it did **not** re-verify the plan's 1047/510/742/0 census, so
its receipt is **not** corroboration of those figures.

### ⭐ THE AGGREGATE — all 40 pre-registered files, and it re-aims the batch

| verdict | count / 40 | what it means |
|---|---|---|
| **ROTTED-CITE** | **27** | **the disease** |
| TRUE-OPEN | 21 | says open, is open |
| TRUE-FIXED | 14 | says fixed, is fixed |
| **STALE-FIXED** | **7** | says open, tree already fixed it |
| **BAD-FIX** | **1** | a stored fix that would damage the tree |
| **STALE-OPEN** | **0** | *the dangerous direction never appeared* |
| DUPLICATE | 2 | |
| UNKNOWN | 1 | |

*(Crews used slightly different secondary labels, so the four primary rows are the robust
ones. A file can carry several verdicts. **n=40 of 1047 — roughly ±15 points at 95%.
Do not quote this to two significant figures**, per D1.)*

**`PLAN.md` was aimed at the wrong target, and D1 is why we know.** The plan was scoped
around `BAD-FIX` and `STALE-OPEN` — the six prescribed bad fixes the last batch found. In a
**random** sample `STALE-OPEN` is **0 of 40** and `BAD-FIX` is **1 of 40**. Those six were a
**selected** sample, exactly as D1 warned, and a batch that had skipped the pre-registered
measurement would have spent itself hunting a defect class that is genuinely rare while
walking past one that affects **two files in three**.

**The tracker does not describe the wrong code. It points at the wrong place.**

⚠ **And the undercount is real: `BAD-FIX 1` is too low.** A1 declined to score 0296 and
0435 as `BAD-FIX` although both quote C that no longer exists **and still looks like valid
C**. Its verdict on 0435: *"correct by reference, damaging by paste."*

### A1 (files 1–10) — the rot is BELOW THE FOLD, where no header checker can see it

`TRUE-OPEN 7 · TRUE-FIXED 3 · ROTTED-CITE 9 · STALE-FIXED 1 · BAD-FIX 0 · STALE-OPEN 0 ·
UNKNOWN 0 · NEEDS-RUN 0.` Ten files, **ten status-line directions correct**.

⚠ **The finding that most constrains C1: a first-ten-lines checker scores the worst file
in the sample GREEN.** 0071's header is *correct* — it says OPEN and it is open. The rot is
**below the fold**, in the tables an **umbrella** issue uses to track its children: §3 lists
0063 as an unresolved HIGH while 0063 reads `✅ REPLAYABLE`; §4 calls 0003 *"pre-existing"*
while 0003 reads CLOSED; §4b's six *"next mutators"* are **five done**. **Umbrella issues
are what people read to pick work**, so this is the highest-consequence rot in the corpus
and a header-scoped validator is blind to all of it.

**The tracker already contains its own prescription, unimplemented.** Issue **0229** *is*
the write-up of line-number rot: it prescribes *"cite symbols, not offsets"*, **ships a
ready-made pre-commit grep**, is **still OPEN**, and has since rotted itself — its class-d
*"only survivor"* `select.c:790` now lives at `:1021`, and it is the driver's one confirmed
rotted quote (`src/callback.c:2990`). **The fix for this batch's central finding has been
sitting in the tracker, written down, for weeks, unbuilt.** That is the five-filings-zero-
fixes pattern in its purest form.

### E1 — the queue is real; its problem is shape, not validity

| verdict | count | share |
|---|---|---|
| **THEIRS** — reaches a person | **153** | **81%** |
| **MINE** — internal, never should have been filed | 24 | 13% |
| STALE — already decided or moot | 11 | 6% |
| UNKNOWN | 2 | 1% |

**The headline is the 153, not the 24** (driver error 7 above). **48 of the 153 are one
repeated request** — *ratify this batch's new on-screen wording* — already explicitly
batched under ⚖ R9 and then filed **one entry at a time over weeks**. Collapsing those 48
into the single review they were always meant to be is the most valuable thing available to
put to the user.

**Ordered for the user** (E1's ranking): `1453` ASE-L's test decks filled their *File >
Open Recent* with ten dead entries · `1352` typing in an xschem dialog runs what you type
as code · `1358_digits…vs_D2` **a ruling they already made was reversed without being put
back to them** · `1395-default` the gesture they asked for in 0932 has no door left ·
`1446` a value typed into a collapsed section is echoed back and silently not saved ·
`1398` every glyph in ASE-L changed typeface, unseen on their screen.

**The clearest never-theirs:** `1377_isolate_opt_in` — *should a test fixture clear the
simulator registry by default or on request?* No surface, no wording, no consequence any
XSCHEM user could observe. Eleven of the 24 are harness or tracker mechanics; five more
state their own answer — **an entry whose text says "Forced by…" is not a question.**

**Two notes carried up.** **Issue 0356 has no ledger entry at all** (0 hits across
rule/look/suite) — the standing constraint protecting it was **inert**. And `1397`/`1458`
are MINE to fix but carry a fact that is theirs to know: **50 of the user's 101 saved
window geometries were permanently displaced by test runs.**

**E1 corrected itself, in the batch's own idiom.** Its first draft took tier sizes from its
table's **row** counts and silently dropped **10 THEIRS entries**; the verdict totals were
right and the presentation lost ten. Caught by grepping the artefact against the ledger,
not by re-reading. *That is the cases-vs-lines conflation CLAUDE.md records getting wrong
three times — reproduced by a crew that had just read the warning.*

**Read-only confirmed by evidence, not assertion:** `diff -rq` against the driver's backup
is **silent**; the ledger is byte-identical. Nothing cleared, edited or added.

### The OTHER half of the user's queue, which E1 did not triage

E1 took the **190 `rule`** debts. Nobody has looked at the **71 `look`** or the **11
`suite`**. Measured by the driver, 2026-09-17:

**The `look` queue has the SAME shape defect as the rule queue.** By mtime: **54 of the 71
were filed on a single day** — 2026-09-10 — then 1, 1, 10, 1, 3, 1 across the following
week. That is one batch discharging its pixel debts one entry at a time into a queue a
person reads serially, which is exactly the pattern D11 is collapsing for the 48 wording
ratifications. **The fix is the same fix**, and it should follow E2's document rather than
invent a second shape.

**These are genuinely the user's, and unlike the rule debts they are not arguable.** A
`look` debt asks for their eyes, and the sample entry reads exactly as it should —
*"Suites green (124 --nogui / 136 :99 window, 53 keys :99, 130 store, 485 op_annot control,
T1 zero); please look: does the row visibly move where you expect, does the shading land on
it and not on the line it left…"*. That is the rule working: **never report a pixel
deliverable done on a green suite.** The defect is the serialisation, not the filing.

**The 11 `suite` debts are NOT the user's** and need no ruling — a suite debt clears itself
on a pass and `owed.sh drain` runs them as one batch with the gate live:
`test_annot_declutter_1244`, `test_ase_campaign_gui_1464`, `test_ase_core`,
`test_ase_dialogs`, `test_ase_optsheet_1441`, `test_ase_simdlg_0937`, `test_ase_window`,
`test_hier_pdf_links_1333`, `test_ps_valid_1350`, `test_rdw_keys_1245`,
`test_rdw_window_1245`. **Deferred, not forgotten:** draining them runs GUI suites, and the
driver's T1 baseline is live — a concurrent suite run would muddy the one number F1 needs.

### A4's geometry finding, independently confirmed by the driver

A4 reported that issues 1397/1458 are live. Confirmed on the user's real configuration:

```
2026-09-17 09:08:56   7076 bytes   ~/.xschem/geometry      <- written TODAY
2026-09-13 18:53:01   2632 bytes   ~/.xschem/recent_files  <- frozen four days ago
101 entries in geometry
```

**`geometry` moved today and `recent_files` did not**, which is the signature: the
`no_recent_files` gate protects one file and not the other, so test runs still write the
user's saved window positions. **50 of those 101 entries were permanently displaced.** This
is `MINE` to fix (E1's verdict) but the *fact* is theirs to know — it is their windows
opening in the wrong place.

⚠ **A separate, unrelated thing that looks similar and is not:** the untracked
`.xschem/op_param_lists.conf` in the **repo root** is dated **2026-09-09**, long before
this batch. It is not tonight's litter and not the geometry defect. Noted so the next
reader does not spend an hour on it — but note also that a repo-root `.xschem/` shadows the
user's own for anything launched from there.

### The driver's corpus-wide run of A4's closure detector

`tools/closescan.py` (self-testing, per the rule the eight errors bought). **165** issue
numbers are claimed closed somewhere — in issue files, `src/`, `tests/` or git log. **154**
have a header that agrees. **7 do not**, and they are the mechanical face of sub-problem 2:

`0071` · `0216` · `0249` · `0264` · `0516` · `0650` · `0947`

**Two are closed by shipped source and git log rather than by another issue** — 0216 via
`src/wave_viewer.tcl`, 0516 via `src/calculator.tcl` — which is the concrete argument for
C1 sweeping beyond `doc/claude/issues/`. At **4.3%** this is a smaller class than citation
rot, and unlike citation rot it is **exactly detectable**, today, with no judgement calls.

### A3 (files 21–30) — the citation split, and 0905's account of its own fix

`TRUE-OPEN 4 · TRUE-FIXED 4 · STALE-FIXED 2 · ROTTED-CITE 6 · UNKNOWN 0` — and A3 says it
**distrusts its own zero**, because this draw happened to name readable symbols. Counts,
not a rate.

**The measurement that decided the design (see D8):** 5 files citing bare `file:line` →
**5 of 5 rotted**. 1 file citing line **plus a revision** (0818) → **4 of 4 reproduced**
via `git show fadb226d:`. 3 files citing **symbolically** (0945, 1344, 0896) → **3 of 3
held**. *"The least ceremonious files survived intact."*

**0905 — the subject is genuinely fixed; the file's account of its own fix is
substantially stale.** `32dff39a`, the commit that *replaced* the design 0905 describes,
appears **zero times** in it. §1 still says the second run *"refuses loudly and exits 2
writing nothing"* — `exit 2` is gone. **§3 is the dangerous one**: it records the
per-pid-log shape as *"considered and deliberately NOT taken"* when that is exactly what
shipped, as a **copy**, which was 0905's own stated objection to it. **A reader in good
faith is told not to build the thing the tree already runs.** Its other half —
*"`banner_rule.tcl` is unchanged"* — is **still true** (136 lines, zero `T1-RUN`), so a
blanket `STALE-FIXED` would over-claim. One file, three sections, three different truth
values.

**The OOM loop has a measured origin and a live residue.** 0905 is where the phrase enters,
and it was never a measurement — it was *"a documented event"*, an appeal to a document
that does not exist. Both ends now carry in-place corrections that cross-reference
correctly. **The uncorrected residue is `0432:82`**, which asserts the **event**, not
merely the figure — *"(this box OOMs on concurrent builds, ~7.8 GB)"* — with no correction
attached. That one still reads as live.

**A free red for C1:** the sabotage protocol's own `grep -rn SABOTAGE src/ # must be
empty` returns **8** on a clean tree. That is issue **1219**'s subject, and it is live.
A3 also refuted 1219's own numbers — *"60 lines / 28 files"* is **118 / 44** — in the
direction that **strengthens** the issue.

### A4 (files 31–40) — corrections land outside the issue file

`TRUE-FIXED 5 · TRUE-OPEN 3 · STALE-FIXED 3 · ROTTED-CITE 4 · DUPLICATE 1 · UNKNOWN 1 ·
**BAD-FIX 0 · STALE-OPEN 0**`. Six of ten carry a defect verdict; **three have a status
line that alone sends the reader the wrong way.**

**The finding that most changes C1: corrections land *outside* the issue file, two times
in three.** 1436's refutation lives in the **suite**; 1395's in `ase_window.tcl:9435`;
1439's *"Fixes issue 1438"* never propagated back to 1438. **A checker confined to
`doc/claude/issues/` misses two of three** — and on this sample the source comments cite
*more* accurately than the tracker does.

**Both `STALE-FIXED` files share one mechanical pattern, and it is detectable:** filed as
A, fixed later under number B, B's header names A, **A is never updated**. Grep for *"Fixes
issue N"* / *"Supersedes N"* and check N's header. 1439→1438 is a worked example sitting
in the tree right now. **This is the concrete detector for sub-problem 2** (nothing closes
an issue when the thing is fixed).

**1458 is a `DUPLICATE` of 1397 — and names 1397 in its own `Related:` line while
duplicating it.** So **cross-reference presence is not duplicate detection**, and a
checker must not assume it is. The defect is **live and was reproduced today**:
`~/.xschem/geometry` mtime **2026-09-17 09:08** against `recent_files` frozen at
**2026-09-13 18:53**. A4 recommends merging 1458 and 1397 to one number — a D1 item.

**1436 answered without running T1, and it is a trap for C1.** The rows sit in `hcases`
(`run_regression.tcl:76`), **not** `dcases` — the driver's own comment at `:172` says *"⚠
THEY GO IN `hcases`, NOT HERE."* So a **green T1 and a red display-arm row are
consistent**. ⚠ **C1 must not assert "no open issue may claim a red row while T1 is
green"**: it would false-red the one file in this sample that is careful about exactly
that distinction. The *"two rows"* count is nonetheless stale — the suite itself at
`:407-411` records that only G2sens reds.

## Wrong recorded beliefs caught in this batch

The last batch's tally was twenty, *"every one caught by re-measuring rather than
re-reading."* Same table here, same discipline.

| # | belief | who held it | what measurement said |
|---|---|---|---|
| 1 | *"1050 issue files explicitly call themselves a duplicate"* | **the driver** | **7.** There are only 1047 numbered files, so 1050 was impossible on its face and the driver published it anyway. Cause: `/usr/bin/grep -lieE 'duplicate of…'` — in a bundled short-option string **`-e` consumes the rest as its pattern**, so the command searched for the literal letter `E` and matched every file. Proved by experiment: `grep -lieE 'zzz-no-such-pattern-zzz'` also returns **1050**. **A plausible number from a silently broken command** — the same shape as the fossil `results.log` that reads exactly like a clean sweep. |
| 2 | *"69 citations in the tracker are demonstrably wrong"* | **the driver** | **Near zero.** `citescan.py` resolved 3751 `file:line` citations across 620 files and labelled 69 "missing", but the samples are `outitf.c`, `rawfile.c`, `tfanal.c`, `inp2dot.c` (**ngspice**), `libio/iovsprintf.c`, `debug/fortify_fail.c` (**glibc**) and `tcltk/tk8.6/entry.tcl` (**system Tk**) — legitimate citations into **external source trees**, counted as rot because the scanner only knew this repo. Same false-positive class as `pgrep -af` self-matching: **a pattern matched against the wrong namespace.** |
| 3 | *"the tracker's citations rot at 85%"* | **the driver** | **Unmeasured, and not measurable this way.** `quotescan.py` checked 20 quoted numbered source lines and called 17 mismatches, but 16 are the heuristic (*"nearest filename mentioned above"*) grabbing **SPICE decks, netlist listings and `results.log` excerpts** that happen to carry line numbers inside fenced blocks. **Exactly one was genuine** — see the finding below. The lesson is not a rate; it is that **retrospective rot detection cannot be done by heuristic**, which is a Stage C input. |

| 4 | *"only 1 issue file in 1047 states the tree it was measured against"* | **the driver** | **Wrong, and by the same mechanism as 1–3.** 1477, 1478 and 1479 visibly open with *"measured in the tree at `aa0e2213`"* — the driver had **read them in this session** and still published a census that excluded them. **Two** causes, both in one command: the phrase **hard-wraps across a newline** (`measured in` ⏎ `the tree at`) so a **line**-oriented grep cannot match it, and inside **single** quotes the `` \` `` escapes became a literal backslash-backtick, so the SHA alternation matched nothing either. |
| 5 | *"193 of 508 git SHAs cited in issue files do not resolve"* | **the driver** | **Not SHAs.** The regex `[0-9a-f]{8,40}` matches any 8-digit **decimal** number, so the non-resolving list is led by `16091816` (the box's `MemTotal` **in kB**, from the RAM correction), `141592654` (**π**), `12405346`, `1286397804`, `0000001e`. A SHA-ish token must contain at least one `a`–`f`. |

| 6 | *"issue **0663** is the guard suite that was **writing** `~/.xschem/geometry`, and its ruling was isolate-not-prune"* | **the driver**, in **A4's own dispatch brief** | **0663 is not about geometry at all.** It is *"a Tcl error in any file sourced late by `xschem.tcl` SEGFAULTS startup"*, fixed in C on 2026-08-24. `/usr/bin/grep -c geometry` on it returns **0**. There is no geometry-writing guard suite in it and no isolate-not-prune ruling. **The real sibling of 1458 is 1397**, filed four days earlier, citing the same proc at the same line. |

| 7 | *"the user's 190 `rule` debts are largely internal engineering misfiled as theirs — the three cleared on 2026-09-17 were the tip of an iceberg"* | **the driver**, and it was said **to the user**, in the answer that opened this batch | **153 of 190 (81%) are genuinely THEIRS.** E1's triage: THEIRS **153** · MINE **24** · STALE **11** · UNKNOWN **2**. The filter does **not** dissolve the queue. Its problem is **shape, not validity** — 48 of the 153 are *one repeated request* (ratify a batch's new on-screen wording), already batched under ⚖ R9 and then filed one entry at a time over weeks. |
| 8 | *"`SUPERSEDED` appears in ~15 hits across ~13 files"* | the driver, `PLAN.md` baseline table | **26 hits across 19 files** (A1 re-measured). A1 confirmed 1047 and 742. |

⚠ **Error 7 is the most consequential of the eight, because it is the only one the USER
heard.** It was asserted in the answer that persuaded them to take this batch on. The three
debts cleared that day were real, and generalising from three to 190 is the same move as
generalising six *selected* bad fixes into a rate — **the error this batch was designed to
avoid, committed by the driver in the act of proposing it.**

⚠ **Error 6 is the batch's subject happening to the batch.** The driver took a belief from
**its own compacted summary of a previous session**, did not re-measure it, and wrote it
into a crew's instructions as fact — which is precisely how a defect gets filed five times
in seven weeks. It is the same shape as the last batch's *"0609's containment pins T1's
cwd to `$REPO`"*, where the driver also reasoned from its own summary rather than the
document. **A4 checked it and refused it**, which is the behaviour `CREW_BRIEF.md` rule 10
asks for, and it was contained to one brief only because A4 looked.

## The rule those five errors bought

**Every mechanical check is run first against a case whose answer is already known, and
reports nothing if it fails that.** All five driver errors are one family — *a command
that returns a plausible number without doing what was meant* — and every one was caught
only by a number looking impossible (1050 > 1047) or by reading the samples instead of
the count. This is **red-first applied to measurement**: the last batch's brief demanded
that a test row be observed red before it is trusted, and a grep is a test row.
`tools/stampscan.py` implements it — it asserts 1473/1477/1478/1479 are detected and
`sys.exit(1)`s rather than print a census if they are not.

**This is also the tracker's own disease, reproduced five times in one evening by the
agent auditing it.** The corpus is 1047 confident sentences produced the same way.

## Findings the driver measured directly (2026-09-17, at `8608c7ef`)

**No citation in the tracker points past the end of a file.** `citescan.py`: 3751
distinct `file:line` citations, **PAST-EOF = 0**. So the cheap, mechanical rot check —
does the line exist? — finds **nothing**, and the only rot that matters is the kind where
the citation resolves and the text moved. That is the `+15` shift that produced the last
batch's worst error, and it is **not** computable retrospectively.

**The one genuine rotted quote is perfect.** Issue **0229**, whose title is *"comment
line number citations in `callback.c` are stale"*, cites `src/callback.c:2990` as
`int wire_label_try_commit(void)`; the tree at that line says `} else {`. **An issue
about stale line citations whose own line citation went stale.** (0229 is in A1's
sample — the crew's independent verdict is the check on this one.)

**Self-declared refiling: 11 files.** 9 say *"filed four times"*, 2 say *"filed five
times"*. Only **7** files say *"duplicate of NNNN"* at all, against **101** that use the
word "duplicate" somewhere — so the tracker records refiling in prose far more often than
in any form a reader or a tool could act on.

**The cross-clone number collision is not visible today, and that does NOT retire it.**
Both clones hold an identical set of **1048** numbers; **zero** unique to either side and
**zero** `15xx` in op-wcard, despite `1500–1599` being reserved for it. Reason measured:
`/home/analog/dev/xschem-op-wcard` is checked out on **`fluid-editing`** — *this* branch —
at `875ae443`, a commit from the last batch. It is currently a second checkout of our own
branch, not a second line of work. **The hazard is parked, not removed**: one `git
checkout` in that tree restores it. Read this the way CLAUDE.md reads the empty
`/usr/local/bin` — the absence of the collision today is a fact about where a clone
happens to be sitting, not about the numbering rule.
