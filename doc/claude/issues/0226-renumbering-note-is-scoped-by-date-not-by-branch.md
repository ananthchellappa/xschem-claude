# 0226 — the renumbering note in `status.md` is scoped by **date**, not by **branch**, so it misroutes this branch's own 0220–0225 onto real but unrelated `open_pdk` issues

Status: **FIXED** 2026-08-08 — `doc/claude/issues/status.md` lines 10-12 rewritten in the
same commit as this file, rescoping the +10 rule from "any commit dated on or before
2026-08-08" to "commits reachable from `99d6f1ed` but not from the merge base `74ef1aed`",
and naming this branch's 0212–0225 as exempt. Lines 3-9 were left alone: every factual
claim in them checks out.
Found by: the merge-4 audit of `doc/claude/issues/status.md` — reading the note that
`open_pdk` brought in at merge commit `15c600c6` against this branch's own issue filings
on the same dates.
Related: `doc/claude/issues/0227-*.md`, `0228-*.md`, `0229-*.md` (the other three findings
of the same audit).

## Symptom

The note reads, verbatim from the merged tree (`doc/claude/issues/status.md:3-12`):

```
> **Renumbering, 2026-08-08 — the old 0220–0238 block is now 0230–0248 (+10).**
> `open_pdk` had filed 0220–0238 while the branch it merges into was filing its
> own issues in 0220–0229, so the two blocks collided. …
> **Commit messages are not** — history is immutable, so any commit dated on or
> before 2026-08-08 that says "issue 0231" means what is now **0241**. Subtract
> 10 when reading git log, add 10 when reading anything checked out.
```

The load-bearing qualifier is on line 10: **"any commit dated on or before 2026-08-08"**.
Nothing in the note names a branch, an author, or an ancestry range.

But `fluid-editing` was independently filing 0212–0225 on exactly those dates, and none of
its numbers moved. `git log --format='%h %ad %s' --date=short pre-open-pdk-merge-4 --
doc/claude/issues/`:

```
589d7424 2026-08-08 docs(wviewer): reconcile the doc oracles (two-pane 19)
a98ab6fe 2026-08-07 docs(issues): 0218-0224 from the merge-3 interaction audit
422b3f55 2026-08-07 fix(wviewer): strip ngspice device-class prefixes (0217)
```

`a98ab6fe` is dated 2026-08-07 — on or before 2026-08-08 — so by the rule as written its
numbers are shifted. Its body says:

```
0220 medium  change_index.tcl's +/- loop may cascade A[0]->A[1]->A[2] and short
             two nets. …
```

Apply the rule ("add 10 when reading anything checked out") and you look for **0230**. Both
files exist, so nothing errors:

| the rule sends you to | which is actually about |
|---|---|
| `doc/claude/issues/0230-signal-short-silent-on-nohier-and-dead-highlight.md` | "`signal_short()` is silent on `-nohier` / current-level-only netlist, and its highlight branch is unreachable" |
| `doc/claude/issues/0220-change-index-plus-minus-can-cascade-across-a-selection.md` | "`change_index.tcl`'s `+`/`-` loop can cascade: `A[0]→A[1]` then `A[1]→A[2]` merges two nets" |

Second pair from the same commit's body, 0224 → 0234:

* `0234-bus-tap-and-label-format-strings-unreachable-in-backends.md` — "`bus_tap`'s
  `verilog_format`/`vhdl_format` are unreachable, and every label symbol's `format=` is dead"
* `0224-pin-rename-test-gaps-with-quotes-split-and-two-warning-paths.md` —
  "`test_pin_rename_propagate.tcl` gaps: the `with_quotes` 0-vs-3 split, and two of five
  warning paths"

This is the worst failure mode a lookup rule can have: it does not 404. It resolves to a
real, well-formed, plausible issue file, so the reader gets no signal that they were
misrouted — and the correct file was sitting under the number the commit actually wrote.

## Why it was invisible

The note is **byte-identical to the one `open_pdk` wrote**, and on `open_pdk` it is correct.
`git diff 99d6f1ed HEAD -- doc/claude/issues/status.md` is **empty (exit 0)**. Our pre-merge
tip has no note at all — `git show pre-open-pdk-merge-4:doc/claude/issues/status.md | head -20`
goes straight from the title to the snapshot paragraph:

```
     1	# What is still open — branch `fluid-editing`
     2	
     3	Snapshot taken **2026-07-30**, immediately after issue 0176 was closed
```

`git diff pre-open-pdk-merge-4 HEAD -- doc/claude/issues/status.md` is exactly the 11-line
`+` hunk. So the note arrived whole from one side of the merge and was never re-read from
the receiving side — the side whose numbers the scope predicate silently sweeps in.

The rule is also *right for every commit it was written for*. Ten `open_pdk` commits name a
number in the block and +10 resolves correctly for all of them: `11debb49` (2026-08-08,
"a cancelled placement deletes the PREVIEW, not the selection (issue 0231)") really does
mean today's `0241-placement-abort-deletes-the-selection-not-the-preview.md`. The note is
**under-scoped, not incorrect** — which is precisely why nobody re-derived it.

## Repro

All commands run at `15c600c6` from the repo root.

1. **The renumber moved only `open_pdk`'s files.** Merge base:
   `git merge-base pre-open-pdk-merge-4 99d6f1ed` → `74ef1aed`. Comparing issue-file
   basenames base-vs-theirs, `comm -23` (only in base) is **empty** and `comm -13` (only in
   theirs) is exactly **19 files**, `0230-…` through `0248-…` (208 → 227 files). The
   0220–0238 names never existed at the merge base; they were created *and* renumbered
   entirely inside `open_pdk`:

   ```
   99d6f1ed 2026-08-08 docs(issues): renumber the 0220-0238 block to 0230-0248 for the merge
   ```

   `git show -M --name-status 99d6f1ed -- doc/claude/issues/` lists 19 renames, a clean +10
   with the slug preserved.

2. **Our 0220–0225 are untouched by merge 4.**
   `git diff --stat pre-open-pdk-merge-4 HEAD -- doc/claude/issues/022[0-5]-*.md` is
   **empty**. `git ls-tree -r --name-only pre-open-pdk-merge-4 doc/claude/issues/` already
   carries 0212 through 0225.

3. **The misroute.** `for n in 0220 0224 0230 0234; do head -1 doc/claude/issues/${n}-*.md; done`
   prints the four titles tabulated above — two unrelated pairs, both resolving.

4. **The discriminator is ancestry.** `git log 99d6f1ed --not 74ef1aed` contains the ten
   commits the +10 applies to. `a98ab6fe` and `422b3f55` are not in that range.

## Fix

`doc/claude/issues/status.md:10-12`, rewritten in this same commit. Lines 3-9 unchanged.

Before:

```
> **Commit messages are not** — history is immutable, so any commit dated on or
> before 2026-08-08 that says "issue 0231" means what is now **0241**. Subtract
> 10 when reading git log, add 10 when reading anything checked out.
```

After:

```
> **Commit messages are not** — history is immutable. The shift applies to
> **`open_pdk`'s own commits**: those reachable from `99d6f1ed` but not from the
> merge base `74ef1aed` (`git log 99d6f1ed --not 74ef1aed`; ten of them name a
> number in the block). In one of those, "issue 0231" means what is now **0241**.
> **Date is not the discriminator, branch is** — `fluid-editing` was filing its own
> 0212–0225 on the same dates (`a98ab6fe`, 2026-08-07, "docs(issues): 0218-0224 …")
> and none of its numbers moved, so +10 on one of ours lands on a real but
> unrelated file. Our commits already mean the files on disk.
```

Two deliberate choices:

* The SHAs `99d6f1ed` and `74ef1aed` go **inline**, so the scope is mechanically checkable
  years from now rather than resting on a date the reader must take on trust.
* The worked example stays `0231 → 0241`, which is a genuine `open_pdk` commit
  (`11debb49`), so the note keeps demonstrating the rule on a case where it is right.

### Not done, and worth considering separately

A one-line "this number was never renumbered" pointer at the top of
`doc/claude/issues/0220-*.md` … `0225-*.md`. Those six files are the only ones a misapplied
rule can strand, and a reader who lands on 0230 by mistake will never look at `status.md`
again. Not done here because it edits six files to defend against a rule that is now
correctly scoped.

## What is *not* wrong with the note

Recorded because the audit checked each of these and they held — the defect is confined to
the scope predicate on line 10.

* The block really is exactly 0220–0238 → 0230–0248: 19 renames in
  `git show -M --name-status 99d6f1ed`.
* `test_signal_short_nohier_0220 → _0230`, `test_statusmsg_hold_0238 → _0248` and
  `doc/claude/evidence/{0230 => 0240}/` all appear in that commit's stat, as claimed.
* "0219 and below are untouched" is true, and it is what keeps `422b3f55` ("strip ngspice
  device-class prefixes (0217)") safe: 0217 is below the block and there is no 0227 file to
  land on. The exposure was exactly our 0220–0225.
* One weaker observation, recorded but **not** asserted as a defect: the direction sentence
  ("Subtract 10 when reading git log, add 10 when reading anything checked out") can be read
  against its own example one sentence earlier, which takes 0231 out of a commit message and
  *adds* 10. The intended reading is presumably "subtract 10 to go from a checked-out file
  back to the commit that made it". It is ambiguous rather than provably backwards; the
  rewrite above disambiguates it in passing by dropping the bare subtract/add pair.

No code, tests or suites are implicated — this is documentation only.
