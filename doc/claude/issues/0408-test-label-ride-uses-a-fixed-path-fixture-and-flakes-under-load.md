# 0408 — `test_label_ride.tcl` writes a fixed-path fixture (not parallel-safe) and row V22 flakes under load

Status: **(a) FIXED 2026-09-17** by crew item **E2** (harness-concurrency batch); **(b) STILL OPEN**
— but read the withdrawal below before chasing it: (b) may well have been (a) all along, and the
claim in this file that it could not be has been **refuted by measurement**.
Filed by crew item **D10** (Verify-A and Verify-C both hit it, from opposite directions).
Area: `tests/headless/test_label_ride.tcl` — the `set ::rfsch …` line just above `proc rotflip`,
and row **V22** (the `+2` orientation sweep).
**Line numbers deliberately omitted**: the `:548`/`:678` this file used to cite had drifted before
anyone re-read them, and the section W rows added by the fix move them again. Cite the anchor text.
Related: `doc/claude/WIRING.md` (sabotage/measurement discipline), the gated-tier list in every
crew brief — `label_ride` is one of them, at 157 checks.

## Two observations, one suspected shared cause

**(a) Not parallel-safe.** The fixture path is fixed and lives *in the test directory*, not in a
per-PID scratch dir. Two headless suites running concurrently write and delete the same
`tests/headless/_label_ride_rf.sch`: the adversary agent ran two `Bash` batches at once and saw
`test_label_ride` abort, and — worse — the *next, sequential* run stay red until the stale file was
cleaned. Re-run strictly sequentially, it is `ALL PASS (157)` three times in a row.

**Re-measured 2026-09-17 (E2), and the headline number is worse than filed: 8 of 20 runs bad**, in
ten concurrent pairs on today's tree. Two distinct shapes, and the first is the dangerous one:

| shape | count | what it looks like |
|---|---|---|
| aborted, **rc 0**, no `RESULT:` line at all | **6** | `couldn't open "tests/headless/_label_ride_rf.sch": no such file or directory` at `Line No: 640/649/653/662` |
| **wrong answers**, rc 1 | **2** | `V22 -> {1}`, `V45 -> {{0 100} {0 0}}` |

The abort shape **exits 0**. `--nogui --pipe` returns 0 on an uncaught mid-script Tcl error, so a
collided run is a *silent pass* to anything reading the exit code; only the completion-banner rule
catches it. That is worth more attention than the flake — a tier can be scored green having
measured nothing.

⚠ **The "next, sequential run stays red" half did NOT reproduce, and the mechanism says it cannot.**
Five planted flavours of a stale fixture — plausible `.sch` content, zero-byte, read-only, a
directory squatting on the path, a non-empty read-only directory — each gave `ALL PASS (157)` on the
very next run, as did a sequential run taken straight after all ten concurrent pairs. `rotflip`'s
first statement is `file delete -force $::rfsch`, which removes every one of those states before
`saveas` runs. The most likely explanation of the original observation is that the "sequential" run
still overlapped a live peer, or that the red seen was the rc-1 wrong-answer shape above rather than
a poisoned-fixture shape. **Fixed anyway** — a crashed run leaving a corpse in a tracked directory
is a real defect on its own terms — but nobody should spend time reproducing the poisoning claim.

**(b) Row V22 flakes.** Verify-A measured `V22 40 orientation x transform cells all agree`
returning a nonzero disagreement count (`{4}` once, `{1}` once) — tier 157 → 156, `OVERALL: notok` —
**2 failures in 16 runs against a byte-identical binary** (`md5 d8f471d7eb014c21f5a815957db97c4e`
verified before and after every batch). 10/10 consecutive passes on a quiet machine; both failures
fell inside a window when other crew agents were active.

~~(b) is *not* explained by (a) — a fixture collision aborts the script, it does not return a wrong
agreement count — so this issue records two symptoms and one confirmed cause.~~

⚠ **THAT SENTENCE IS WRONG, AND IT IS THE MOST EXPENSIVE THING IN THIS FILE.** Refuted by
measurement 2026-09-17 (E2): a fixture collision returns a wrong agreement count *routinely*. Of
twenty runs in ten concurrent pairs, two did not abort at all — they reported `V22 -> {1}` and
`V45 -> {{0 100} {0 0}}`, which is exactly (b)'s recorded shape and, for V22, exactly one of (b)'s
two recorded values.

The mechanism is inside `rotflip` and needs no second cause: it returns the literal `"?"` when its
`C {...}` scan finds no matching line, which is what it sees when the file it just wrote has been
replaced or truncated by the other run. `V22` compares `$ref ne [rotflip l1]` and scores a
disagreement; the tier goes 157 → 156 with no error message anywhere. (b)'s own note that *"both
failures fell inside a window when other crew agents were active"* points at (a), not away from it.

**(b) remains open** — nobody has yet reproduced a V22 disagreement with the fixture private — but
the honest next step is to re-run the V22 loop under load **now that (a) is fixed**, not to hunt a
second cause. If it never reproduces again, (b) was (a).

## Why it matters

`label_ride` is a **gated tier**: a crew item that changes nothing in its path can still be handed a
red tier and be wrongly reverted, or a real regression can be waved off as "the flake". Either way
the run substrate is replay/autograding, and a tier that is not deterministic is not a gate.

Ruled out as a cause of the flake: item D10's own change (issue 0266). V22 drives only
`move_objects 0 0 $mr $mf -anchor 0 0 kissing`, whose `argv[2]`/`argv[3]` are the literal `0` `0`,
which the new validator accepts deterministically; the change adds pure `argv` inspection and no
state.

## Fix sketch

1. Move the fixture to a per-PID path (`_label_ride_rf.[pid].sch`, or the scratch dir the other
   suites use) and delete it in a `finally`-shaped cleanup, so concurrent runs cannot collide and a
   crashed run cannot poison the next one.
2. Then chase V22 on its own: log the four transform cells that disagreed rather than only the
   count, and run it in a loop under artificial load until it reproduces.

## What was actually done for (a), 2026-09-17 (E2)

The sketch offered two options; **the second was taken**, and the first would have been worse:

* `test_label_ride.tcl` now `source`s `tests/headless/scratch.tcl` and sets
  `set ::rfsch [file join [test_scratch label_ride_rf] rf.sch]`. **Nothing outside `rotflip` ever
  read the fixture** (swept: the only two hits in the whole repo were the `set` line and this issue
  file), so there is no canonical name to publish back to — unlike the regression cases in B1.
* **Why not a bare `_label_ride_rf.[pid].sch` in `tests/headless/`, the sketch's first suggestion:**
  that path is **not gitignored** (`.gitignore:84`'s `_*_[0-9]*/` is *directory*-only — verified
  with `git check-ignore -v` on all three candidate spellings), so a corpse from a killed run sits
  in the developer's `git status` indefinitely. Worse, the near-miss spelling
  `_label_ride_rf_[pid].sch` **does** match `full_audit.sh:381`'s scratch glob, which is listed with
  `ls -1d` and therefore matches *files* as well as directories — under the default
  `AUDIT_STRICT_SCRATCH=1` a leaked fixture would have become a **fatal audit failure** under a rule
  written about directories. `test_scratch` sidesteps both: `tests/headless/.scratch/` is gitignored
  (`.gitignore:85`), the directory is deleted by scratch.tcl's wrapped `exit` on *every* path
  including the failing `exit 1`, and dead-pid corpses are swept on next use (issue **0148**, whose
  remediation text in `full_audit.sh` says exactly "convert the owning test to scratch.tcl").
* **B1's trap was checked, not assumed:** pid-scoping a leaf inside a directory something else wipes
  wholesale is a no-op. Nothing wipes `tests/headless/` or `tests/headless/.scratch/` — the only
  deleters are full_audit's scratch arm (which removes only paths that *appeared during that run*)
  and `__scratch_sweep` (dead pid, ≥300 s old). So the pid genuinely isolates here.

**Rows: W1–W4**, added at the end of the suite; 157 → **161 checks**. They assert the **runtime**
value of `::rfsch`, never the source text — a `has_text`/`src_line` row takes the first match in the
file, so the comment explaining the fix would have become the thing it measured.

**Verification.** Post-fix: **0 of 40** concurrent runs bad across two independent rounds of ten
pairs (pre-fix 8 of 20), zero `couldn't open` in any of them; `ALL PASS (161)` sequentially, after
the concurrent rounds, with `DISPLAY` unset, and after a `kill -9` mid-flight that left no corpse in
the tracked tree. CI headless gate exactly as `ci.yaml:68` runs it: **15 pass, 0 fail, floor met,
rc 0**, `SCRATCH: 0 leaked`, `TREE: 0 appeared 0 vanished`.
