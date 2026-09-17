# Ledger — issue tracker batch

Receipts collected by the driver, newest stage at the bottom. A row lands here only
after the driver has read the receipt and checked at least one of its claims.

**Opened** 2026-09-17 at `2cbce753`, branch `fluid-editing`.

| stage | task | crew status | driver verdict | commit |
|---|---|---|---|---|
| A1 | sample files 1–10, classify against the tree | dispatched | — | — |
| A2 | sample files 11–20, classify against the tree | **DONE** | **accepted** — and it corrects the plan twice (see below) | — |
| A3 | sample files 21–30, classify against the tree | **DONE** | **accepted** — it decided the design (see below); triggered D8 | — |
| A4 | sample files 31–40, classify against the tree | **DONE** | **accepted** — and it caught driver error 6, in its own dispatch brief | — |
| E1 | triage 190 `rule` debts — *does this reach a person?* | dispatched | — | — |

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
