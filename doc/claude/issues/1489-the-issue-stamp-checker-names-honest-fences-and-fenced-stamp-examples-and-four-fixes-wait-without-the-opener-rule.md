# 1489 — The issue-stamp checker names honest fences and fenced stamp examples; four fixes are ready without the opener rule

**STAMP:** `v1 claim=open tree=32b6a9cd stamped=2026-09-18 fix=none open=1 by=outsider-fixes`

**Status: OPEN, filed 2026-09-18** by the outsider-fixes batch's driver, when that batch
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
