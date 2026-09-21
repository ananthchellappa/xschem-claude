# 1489 — The issue-stamp checker names honest fences and fenced stamp examples; four fixes are ready without the opener rule

**STAMP:** `v1 claim=fixed tree=c84aee78 stamped=2026-09-20 fix=taken open=0 by=stranger-reds`

**Status: FIXED in `9fcf9177`, 2026-09-20**, by the stranger-reds batch, item D — read
**Resolution** at the foot, and in particular *"What the fix does NOT cover"*: two limits are
documented rather than coded, and one red the verifier called a false alarm is kept
deliberately. **Filed 2026-09-18** by the outsider-fixes batch's driver, when that batch
closed Item 1 under its own rule (`doc/claude/outsider_fixes_batch/DECISIONS.md` D21: "there
is no round 11").

## What is wrong in the committed checker (`d42fc517`)

These are fail-closed false alarms on honest content. They are loud, and none of them fires
on today's corpus: the parser diff over all 1056 issue files is 0.

1. **Any `key=value` word in a fence's info string marks the fence.** An mkdocs
   ```` ```python title="example.py" ````, a ```` ```sh cc=gcc make ```` or a `prefix=/usr` is
   therefore read strictly and named as "a key the grammar does not know".
2. **A stamp body (the `v1 …` part of a stamp line) anywhere outside the stamp line is named**, including a
   documentation example inside a fenced code block. This one is **deliberate** (D21). Two rounds that
   tried to exempt fenced examples (S1-fix8, S1-fix9) each opened regressions on nested
   markdown, one of them fail-open, because a line-based scanner cannot settle nested
   containers. The workaround is in `doc/claude/specs/issue_stamp.md`: show the example
   outside `doc/claude/issues/`, or break the body.
3. The same variant key (`ASSERT=`, `QUOTE=`, `assert =`, `Assert= absent`) is named **twice**.
4. The `assert=` "total budget" is a wall clock for the whole gate, so slow non-scan work can
   exhaust it and misname a fast assertion (the S1-fix7 refuter's 240-valid-quote recipe).
5. Problem text is uncapped: one pathological line produces a multi-megabyte problem line.

## What is ready

S1-fix10's final files (saved in-repo as
`doc/claude/outsider_fixes_batch/patches/1489-s1fix10-candidate.patch`, a diff against
`d42fc517`'s bytes; the scratch copy under `/var/tmp` is gone; the receipt is
`doc/claude/outsider_fixes_batch/receipts/S1.md`, section `## S1-fix10`) fix items 1, 3, 4
and 5, plus one more item: **3′, a backtick line whose info string holds a backtick does not open a
fence** (the CommonMark opener rule). Its refuter (`receipts/S1_verify.md`, last section)
measured **one regression family, caused by 3′ alone**. Pairing fences the CommonMark way lets a
fence with a misspelled marking key (`asert=`, `qoute=`) after a Slack-style
```` ```sh `make` output ```` line go silent, where `d42fc517` names it. With **only the 3′
condition removed**, the refuter's direct-call probes were byte-identical to `d42fc517`, and a
20 000-case fuzz found **0** silent passes for the remaining items.

## The next step

Land items 1, 3, 4 and 5 from S1-fix10's files **without 3′**. Invert or remove row Q24 and
the self-test cases that assert 3′, re-run S1-fix10's refuter battery against `d42fc517`, and
gate with a solo T1. If 3′ is wanted later, it needs `stray_attrs` to name misspelled marking
keys **independently of fence pairing**. The refuter measured that `stray_attrs` matches only
`(quote|assert)[ \t]*=`.

---

## Resolution — landed in `9fcf9177`, 2026-09-20 (stranger-reds batch, item D)

Receipts: `doc/claude/stranger_reds_batch/receipts/D-impl.md` (the land) and `D-verify.md`
(the one fix round). Batch decision: that batch's `DECISIONS.md` **D9**. Files:
`tests/headless/issue_stamp.tcl`, `tests/headless/test_issue_stamp.tcl`,
`doc/claude/specs/issue_stamp.md` — nothing else in the repository was written.

### What was done

* **Items 1, 3, 4 and 5 above landed** from the prepared candidate
  (`doc/claude/outsider_fixes_batch/patches/1489-s1fix10-candidate.patch`): a fence is
  marked only by a marking key, typo'd keys are named once, the `assert=` budget charges
  scanning time while the gate's wall clock gets its own named budget, and problem text is
  capped.
* **The "next step" above was wrong about what had to be removed.** S1-fix10 was the round
  built *after* D21, so it had **already withdrawn** the in-fence body exemption and the
  container-stripped scan. MEASURED four ways rather than assumed: a proc-level byte diff of
  `stray_stamps`, `stamp_shaped`, `md_strip` and `stray_cause` against `d42fc517` is empty;
  a corpus-wide behavioural diff over **1060 files / 5046 fence lines** gives
  `find_blocks=0 stray_stamps=0 stray_attrs=0`; rows `Q19` and `Q22` (which assert the D21
  limit) pass on `d42fc517` *and* on the landed bytes; and fixture `b16_body_in_fence` is
  1 problem, rc 1, on both.
* **Item 3′ (the CommonMark opener rule) landed too, with the repair the section above said
  it needed.** The refuter's one regression family came from pairing: each pairing rule has
  a hole on the side the other one closes. So the fix stopped asking the question —
  `stray_attrs` now tests the key on **the fence line's own info string**, with nothing asked
  about the fences around it. A word shaped `key=` one edit from `quote` or `assert` is a
  named problem wherever it sits, and silent only where a block the gate READ came from that
  same line, so it is named exactly **once**. New `near_miss_key` (length-bounded by two
  integer comparisons before any loop), `misspelled_mark`, `attr_words`, `stray_why`.
* **Anti-overshoot, because one letter separates `assert=` from `asset=`:** a misspelling
  counts only where the fence is visibly a block — another grammar key in the same info
  string, or the misspelled key's own value (`absent`/`present`, or a revision token). An
  exclusion list was refused as a fail-open on a typo that happens to be a word.
* **The fix round added three things** (D-verify §1–§4): `misspelled_mark` folds the
  **value** as well as the key — one capital letter silently disarmed the whole new check,
  a fail-open, while its lowercase twin was named and `d42fc517` named all three; the gate
  asks its wall clock **before** `fence_scan`/`stray_attrs` rather than after; and the
  swallowed-fence diagnostic now names both line numbers instead of only the author's own
  honest fence.

### What was measured

| measurement | value |
|---|---|
| `test_issue_stamp` | 93 → 101 → **102 checks** (`Q18`–`Q26`), **0** `skip:` lines |
| checker self-test | 87 → 122 → 170 → **180 parser cases** |
| red-first, by row | `d42fc517`: **7 FAILED (94 passed)** — `Q14 Q18 Q20 Q21 Q23 Q24 Q25`; the candidate: **1 FAILED (100 passed)**; landed+fixed: **ALL PASS** |
| fail-closed | **19 fixtures**, every one rc 1 with the same problem count on `d42fc517` **and** on the fixed bytes — the fix removes no red |
| strangers | six shapes green (renamed clone, worktree, shallow, `git archive` export, export inside another repo, unborn), every skipped revision named individually, **29** `NOT VERIFIED` |
| whole corpus | `d42fc517` vs fixed over **1061** files: **1** difference, this file's own `opened` map at its line 15, changing no block, no stray stamp, no stray attribute and no verdict. Item D's landed bytes vs fixed: **0** |
| the budget defect | 90 MB corpus, budget 2 s: **9.6 s → 2.5 s**, same verdict, same 16 named files |
| the real corpus | `self-test PASSED (180 parser cases)` / `history: full` / `ok (0 problems)`, rc 0 |
| T1 gate (solo) | `cases=87 blocks=86 counted_failures=0 elapsed=524s` — `tests/results.1188390.log` |

The four false alarms of the section above were each measured red first and green after: the
mkdocs `title=` fence, `cc=gcc` and `prefix=/usr` (rc 1 → `ok (0 problems)`); the typo'd
marking key passing unnoticed over a FALSE claim (five shapes, rc 0 → rc 1, and 61 of a
65-row key×context matrix name the defect exactly once, never twice); the honest `assert=`
and `quote=` false-redded by a backtick in an info string above them; and the budget case
(700 valid quotes then one true assertion: rc 1 at 74.39 s → rc 0 at 74.70 s).

### ⚠ What the fix does NOT cover

Two limits were **documented rather than coded**, and one red the verifier called a false
alarm was **kept** — all three by measurement, so that a later reader meets them as
decisions and not as fresh defects. A suite row pins each.

1. **A stamp's body inside a fence in `doc/claude/issues/` is still named** — item 2 above,
   D21's deliberate limit. A line-based scanner cannot settle nested-container ambiguity:
   the two rounds that tried to exempt fenced examples each opened a regression on nested
   markdown, one of them fail-open. The workaround stays in `doc/claude/specs/issue_stamp.md`
   §6 (show the example outside `doc/claude/issues/`, or break the body). Rows `Q19`/`Q22`
   hold it, and they are green on `d42fc517` too — a row green on both is a row that
   measures no change.
2. **An unknown, non-near-miss key on a swallowed fence is silent** where `d42fc517` named
   it. No rule was built, because naming any unknown `key=` on an unread fence that also
   carries a block key re-opens the false-alarm class this issue exists to close (a
   `path=/tmp` inside an example block is exactly such a sample). And `d42fc517` had no rule
   here to regress against: it named that text **only** where it happened to *read* the
   fence, and is silent on the identical text in all four other unread positions (MEASURED).
   Nothing evaluable is lost — the key is neither `assert=` nor `quote=`, so there is no
   claim. Row `Q26` pins it; spec §6 states it.
3. **The kept "new false red".** A **true** assertion written after a Slack-style
   backtick-in-info-string line is RED on the landed checker where `d42fc517` was green. It
   stays red: a reference CommonMark parser (markdown-it 3.0.0, asked directly for the token
   stream) renders that line as a **paragraph** and reads the author's assertion as the
   *content* of the fence below it — literal text that nothing evaluates. **A green there
   would be a claim passing unevaluated**, which is the one direction this checker may not
   fail in. `d42fc517`'s own answer is *name it* in three of the four positions it does not
   read (indented, `~~~`, never closed); the Slack shape was the outlier, and its green came
   from a parse the reference rejects. What was fixed instead is the **diagnostic**, which
   now names the opener and the backtick line that made it one. MEASURED words-only: fixed
   against landed over 1061 files is 0 differences.

Smaller residues, recorded here rather than filed: `misspelled_mark` guards near misses of
`quote` and `assert` only (a fence carrying a claim is marked by the surviving key and read);
a fence whose key **and** value are both outside the grammar is silent, and adding any
grammar key re-arms the check, so `asset=absent path=x` is named and costs its author a
rename while `asset=x` alone is an ordinary code sample; and 50 000 stray marked fence lines
still produce 50 000 problems, each line capped — the existing contract, `d42fc517` behaves
identically. One knob, not a defect: `run_suites.sh`'s 200 s `SUITE_TIMEOUT` is far short of
this suite, which builds ~20 git fixtures; T1 gives it 900 s through `T1_CASE_TIMEOUT`, which
is why T1 never saw it.
