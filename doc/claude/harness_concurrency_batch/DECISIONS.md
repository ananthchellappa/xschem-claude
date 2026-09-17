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

## ⚖ R1 — AMENDED 2026-09-16 by A1's measurement, still unratified

R1's *verdict* half stands unchanged: `results.log` keeps its canonical name and is
serialised. Its *scratch* half was *wrong as written* and is amended.

R1 said "pid-scope the scratch and it costs nothing". A1 measured that exact shape:
`"$testname/results/.work.[pid]"` leaves **658** phantom FATALs against today's 660 —
a no-op. The shared object is `$testname/results` itself, wiped at startup by every
run. So the amended scratch half is: **the workroot moves out of `results/`**
(`"$testname/.work.[pid]"`, measured 0 phantoms), **and the startup wipe is made
run-safe** — which is what face 2 actually turns on.

**This strengthens the case for the verdict lock rather than weakening it.** With the
wipe and the workroot both per-run, two runs stop corrupting each other's *files*; the
lock remains what stops them corrupting each other's *answer*. Nothing here changes
the question the user was asked, so it is not re-asked — but note that a lock taken for
the whole of `run_regression.tcl` would close all four faces at once, at the price of
serialising runs completely, and that option only became visible through this
measurement. If the user overturns R1 toward "no agent ever waits", that is the branch
where it matters.

## ⚖ R1 — a third shape appeared, and it is the "no agent waits" branch

B1's `publish_results` pattern — work in `<case>/results.<pid>`, then restore the
canonical `<case>/results` name — raises an option nobody had when the user was asked:
the **verdict file could do the same thing**. Write `results.<pid>.log`, then rename to
`results.log` at the end.

That would give the "no agent ever waits" branch of R1 something it previously lacked:
`results.log` keeps its canonical name *and* no run is made to queue. It is not free —
the second finisher's rename still overwrites the first's verdict, so one run's answer
is lost, merely lost *cleanly* (a complete, internally consistent file) instead of
truncated mid-write. A lock, by contrast, serialises and keeps **both** answers.

**This does not change what was implemented.** R1 as ruled stands: C1 builds the lock.
But the option is recorded here so that if the user overturns R1 toward "no agent
waits", the work is already scoped rather than rediscovered — and C1 is asked to
evaluate it in its receipt for exactly that reason.

## Note — the measured premise that failed

0990 stated a row here "would have to run two regressions at once, which is
expensive". Measured 2026-09-16: one **case**, not a regression, and ~70 s. The
estimate that stood on that sentence was wrong for seventeen days and nobody
re-measured it. Recorded because it is the batch's own cautionary tale.
