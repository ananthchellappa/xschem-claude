# Decisions — harness concurrency batch

## ⚖ R1 — scratch made parallel-safe, verdict serialised

**Status: IMPLEMENTED ON THE RECOMMENDED SHAPE, NOT RATIFIED.** Recorded on the owed
ledger against issue 0990. The user was asked twice and the question is still open;
the batch proceeds on the recommendation rather than idling, and this ruling remains
theirs to overturn. Overturning it changes C1 only.

**The question.** When two regression runs collide, both believe they own
`tests/<case>/results/` and both believe they own `tests/results.log`. Two ways out,
differing in what happens to the second agent: a **lock** (it waits or refuses) or
**per-run roots** (both proceed, nothing is shared).

**Why it is the user's call and not an engineering detail.** This user runs crews
that verify in parallel by design. A lock means two agents can never finish a T1 at
the same time. Per-run roots mean they can — at the cost of the canonical filename.

**What tipped it.** The two files are different kinds of thing:

* `tests/<case>/results/.work` is **scratch**. Nothing reads it after the run. Giving
  it the pid scope the runner already uses at `test_utility.tcl:82` costs nothing and
  no reader notices.
* `tests/results.log` is **the verdict**. Per-run naming (`results.<pid>.log`) would
  delete the canonical filename that `doc/claude/ledger/crew.js`, CLAUDE.md's own
  reading instructions, and the user all name explicitly. That is a real cost the
  scratch directory does not carry.

**Decision.** Pid-scope the scratch unconditionally (B1). Lock only the verdict (C1),
keeping `results.log` under its own name, with the second run told plainly to wait —
never silently truncating. This closes all four faces without renaming the file
everyone reads.

**What would overturn it.** The user preferring that a second agent never wait at
all. Then C1 becomes `results.<pid>.log` plus a stable symlink, and every reader of
the canonical name has to be updated — `crew.js` and CLAUDE.md included.

## Note — the measured premise that failed

0990 stated a row here "would have to run two regressions at once, which is
expensive". Measured 2026-09-16: one **case**, not a regression, and ~70 s. The
estimate that stood on that sentence was wrong for seventeen days and nobody
re-measured it. Recorded because it is the batch's own cautionary tale.
