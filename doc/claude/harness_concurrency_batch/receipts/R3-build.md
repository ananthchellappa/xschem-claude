# R3-build — `C11` and its twin `H1` became deltas, landed alone, every cell measured

**Status:** DONE

The delta shipped **by itself**, as the design crew's correction 1 directed and
contrary to `DECISIONS.md`'s original *"neither ships alone"*. **No containment was
built.** No `.gitignore` rule, no sweep, 0356 untouched.

---

## Files touched

| file | lines | what |
|---|---|---|
| `tests/headless/test_ase_core.tcl` | **`:463-520`** | new: watch-dir list, `untitled*` snapshot at suite start, `note` evidence line |
| | **`:1576`** | citation fix `actions.c:207` → **`:208`** |
| | **`:1591-1605`** | `C11` replaced: existence test → set difference |
| `tests/headless/test_op_dump_altshow.tcl` | **`:57-87`** | the twin's baseline block |
| | **`:975-984`** | `H1` replaced: existence test → set difference, **still one row** |
| `tests/headless/test_no_untitled_litter.tcl` | **`:4-19`, `:93-100`** | **nine stale citations** corrected + a re-verification stamp |
| `doc/claude/issues/0609-…md` | fix-code block + tail | marked **SUPERSEDED**, new "the delta landed" section |
| `doc/claude/issues/1480-…md` | `§5`, `§6 item 3` | §5 heading corrected; §6 item 3 marked **DONE** |

---

## Rows changed — red-before / green-after, all quoted from today's runs

### `C11` (`test_ase_core`) and `H1` (`test_op_dump_altshow`)

**RED BEFORE — the false-red direction.** Foreign `untitled~.sch` + `untitled~.sym`
planted in the repo root, suites otherwise clean and leaking nothing:

```
FAIL: C11 no untitled~.sch was dropped in the repo root (issue 0609) -> {1} (exp {0}) : FAIL
FAIL: H1 HYGIENE the suite left the cwd where it found it and made no untitled* in the repo root -> {0} (exp {1}) : FAIL
```

**GREEN AFTER — same planted litter, same command:**

```
RESULT: ALL PASS (675 checks)
ok:   C11 this suite added no untitled* to the repo root or to the directory it was launched from …
RESULT: ALL PASS (70 checks)
ok:   H1 HYGIENE the suite left the cwd where it found it and added no untitled* …
```

### Non-vacuity — the row still reds on a real leak (`:1520-1530` park removed)

The design crew named this test explicitly. Run from the repo root:

```
RESULT: 1 FAILED (674 passed)
FAIL: C11 this suite added no untitled* … -> {/home/analog/dev/xschem-claude/untitled~.sch} (exp {}) : FAIL
--- litter actually left in repo root: untitled~.sch
```

### ⚠ THE BLIND DIRECTION — the cell that justifies the whole change

Same sabotage, run **from `tests/`, which is T1's cwd**:

```
BEFORE:  ok:   C11 no untitled~.sch was dropped in the repo root (issue 0609)
         RESULT: ALL PASS   rc=0
         --- litter left in tests/: tests/untitled~.sch      <-- written by this very suite
AFTER:   FAIL: C11 this suite added no untitled* … -> {/home/…/tests/untitled~.sch} (exp {}) : FAIL
         RESULT: 1 FAILED (674 passed)
```

**The old row reported `ok:`, `RESULT: ALL PASS`, exit 0, while the suite it was
guarding was writing `tests/untitled~.sch` at that moment.** G1's claim was an
inference from source; this is the execution of it.

### `H1` detector non-vacuity

`test_op_dump_altshow` has **no `autosave_backup` park to remove** — it does not leak
— so its delta cannot be reddened by a real leak. Reddened instead by blanking its
baseline (`set h1_pre {}`) with litter present, which proves the detector sees files
and that it is the *comparison* doing the greening:

```
FAIL: H1 HYGIENE … -> {1 {/home/…/untitled~.sch /home/…/untitled~.sym}} (exp {1 {}}) : FAIL
```

### Check counts — unchanged, both suites

`675 → 675` and `70 → 70`. `H1` was deliberately kept as **one** row with two legs
(`[list [expr {[pwd] eq $T_OLDPWD}] $h1_new] {1 {}}`); splitting it would have moved a
recorded number for no gain.

---

## What was kept and what was discarded from 0609's supplied fix code

**Kept:** the idea — snapshot at suite **start**, assert only that this suite added
something.

**Discarded, both halves:**

1. **The `llength` comparison.** Replaced with a **set difference**. 0609's shape
   scores a run that removes `untitled~.sym` and adds `untitled~.sch` as `1 <= 1`,
   clean — and **0609 §3 is itself the correction recording that both extensions
   occur.** The set form also prints the offending *paths* in the FAIL line instead of
   a bare `{1}`, which the measurements above show working.
2. **`-directory $repo` alone.** Replaced with a deduplicated
   **`{$repo, $env(PWD), [pwd]}`**. Watching `$repo` alone fixes the false-red
   direction and leaves the blind direction exactly as blind — `$repo` comes from
   `[info script]` (`:460`) and is cwd-independent, so under T1 it never looks where
   the litter lands.

**Added beyond the design:** `untitled*` rather than `untitled~.sch` (0609 §3's
`untitled~.sym`), and a non-asserting `note` line printing the watch dirs.

0609's block is now banner-marked **SUPERSEDED — DO NOT PASTE** in the issue file,
with both defects written out, so the next reader cannot repeat it. It was the
**fifth** issue file in this batch prescribing a fix that would ship a no-op or a
partial.

---

## Commands run (every one bounded)

```
timeout 600 make -C /home/analog/dev/xschem-claude/src          # rc 0
timeout 90|300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_ase_core.tcl
timeout 90|300 ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_op_dump_altshow.tcl
( cd tests && timeout 90 /home/analog/dev/xschem-claude/src/xschem --nogui --pipe -q --nolog \
    --script headless/test_ase_core.tcl )                        # the T1-cwd arm
timeout 300 tests/headless/devdisplay.sh exec ./src/xschem --pipe -q \
    --script tests/headless/test_no_untitled_litter.tcl
```

No bare `xschem` anywhere. No stall: every run returned a `RESULT:` line, never rc 124.
**I held the suite slot; no other suite ran.** **I did not run T1** — instructed not to.

---

## Measurements

| what | command | answer |
|---|---|---|
| binary freshness | `ls -la src/xschem` vs newest `src/*.c` | `xschem` **07:00** > `actions.c` **06:47** — `make`'s *"Nothing to be done"* was **honest this time** |
| `test_ase_core` count | its `RESULT:` line, before & after | **675 → 675** |
| `test_op_dump_altshow` count | its `RESULT:` line, before & after | **70 → 70** |
| `test_no_untitled_litter` | `grep -c '^ok:'` | **12 ok, `ALL PASS`**, before & after |
| watch dirs by hand | the `note` line | **1** — `{/home/analog/dev/xschem-claude}` |
| watch dirs under T1's cwd | the `note` line | **2** — `{…/xschem-claude …/xschem-claude/tests}` |
| stale citations in `test_no_untitled_litter` | enumerated below | **exactly 9**, as the design crew said |

**The nine corrected citations** (old → measured today):
`save.c:4508-4511` → `xinit.c:181-196` + `save.c:6500-6503`; `actions.c:4639-4652` →
`actions.c:6588-6595`; `xinit.c:2952` → `xinit.c:3175`; `save.c:4149` → `save.c:6139`;
`save.c:4159-4162` → `save.c:6149-6152`; `save.c:4156` → `save.c:6146`;
`xinit.c:3690-3693` → `xinit.c:3917-3919`; `actions.c:4618` → `actions.c:6561`;
`save.c:4175-4182` → `save.c:6165-6172`. Correct and left alone: `actions.c:208`,
`xinit.c:174`, `full_audit.sh:64`.

⚠ **`src/save.c:4149` is cited by SEVEN OTHER SUITES** — `test_annot_show_menu:54`,
`test_delete_cut_selflog:26`, `test_instance_update:30`, `test_perform_action_align:50`,
`test_statusmsg_hold_0248:40`, `test_traversal_flag_leak:34`, `test_undo_selection:15`.
All stale by ~2000 lines, all outside my file list. **Reported, not fixed.**

---

## Claims checked vs taken on trust

**The design crew's whole design was inferred from source and supplied for
falsification. Verdict on each:**

| # | claim | verdict | what settled it |
|---|---|---|---|
| G1 | under T1, `C11` cannot catch its own leak | ✅ **CONFIRMED BY EXECUTION** | sabotaged suite from `tests/` printed `ok:` while writing `tests/untitled~.sch` — upgraded from inference to measurement |
| — | `test_ase_core` never `cd`s / no `env(PWD)` | ✅ CONFIRMED | `grep -n '^[[:space:]]*cd \|env(PWD)'` → silence |
| — | `$repo` from `[info script]` at `:460`; `C11` at `:1531-1532`; `H1` at `:939-941` | ✅ CONFIRMED | read verbatim |
| — | 0609's fix code is count-based and `$repo`-only | ✅ CONFIRMED | `0609:124-129` |
| — | nine stale citations + `test_ase_core:1516` off by one | ✅ CONFIRMED | enumerated above; `actions.c:208` is the `write_backup()` call |
| B-i | the delta greens the row under foreign litter | ✅ CONFIRMED | planted `.sch`+`.sym` |
| B-ii | the delta still reds on a real leak | ✅ CONFIRMED | park removed → names the path |
| B-iii | 2 dirs under T1, 1 by hand | ✅ CONFIRMED | the `note` line |
| B-iv | count moves 675 → 675 | ✅ CONFIRMED | `RESULT:` lines |
| — | mechanism sites `save.c:6139/6146/6149-6152`, `xinit.c:174/3175/3917-3919`, `actions.c:208`, `full_audit.sh:64` | ✅ CONFIRMED | all read today |

**REFUTED — one, and it matters beyond this task:**

⚠ **The design crew wrote that `write_backup()`'s lying header comment
(`save.c:6137-6138`) was *"re-confirmed by reading today"* as still wrong. It is
FIXED.** `:6137-6138` now reads *"NOT skipped for an untitled buffer -- it is a
PRODUCER of `<dir>/untitled~.sch` (issue 0060, gate note below)."* Landed under issue
**0060** — commit `a6038098`, in this session's own recent-commits list, i.e. it
landed inside the window the design crew was reading. **1480 §6 item 3 and 0609's
closing ⚠ were both reporting done work as outstanding**; both are now marked ✅ so it
is not re-filed a sixth time.

**CORRECTED — two, both hardening of the supplied design:**

1. **The watch list is three entries, not two.** The design's `c11_litter_dirs`
   preferred `$env(PWD)` *or* `[pwd]`. But the mechanism has **two** cwd producers —
   `$env(PWD)` (`save.c:6492-6497`, `xinit.c:3917-3919`) and the startup `getcwd`
   (`xinit.c:3175`) — and preferring one hides the other if they ever diverge. All
   three are watched, deduplicated.
2. **The directory list is FIXED at suite start, not re-derived at the row.** The
   design's `c11_litter_snap` called `c11_litter_dirs` afresh each time, so a suite
   that `cd`s would glob a *different* directory at the end than at the start and
   score its pre-existing files as new. Latent, not observed — and note the twin the
   design told me to apply "the same edit" to, `test_op_dump_altshow`, **is** a suite
   that `cd`s (`:55`, `:938`). Harmless there only because the `cd` back precedes the
   row.

**Taken on trust, named as such:** 0609's "80 of 116 suites" (2026-08-22); the
13-of-13 red audits; **T1's 84-case / zero baseline — I did not run T1**; and the
design crew's entire Task A / R2 work, which I did not touch.

---

## Guard rails

**`W15a/b/c`, `W16a`, `V57` cannot have moved, and this is proof rather than
assertion.** All five assert on the *source text of* `tests/run_regression.tcl`.
`git diff --name-only` does not list it:

```
UNMODIFIED  tests/run_regression.tcl        UNMODIFIED  tests/test_utility.tcl
UNMODIFIED  tests/headless/test_regression_concurrency_1476.tcl
UNMODIFIED  tests/headless/test_startup_guard_0663.tcl
UNMODIFIED  DECISIONS.md / LEDGER.md / PLAN.md
```

The delta touches **no shared helper** — no `scratch.tcl`, no `sharefarm.tcl`, no
driver. Both new helpers are file-local procs with file-local names
(`c11_*` / `h1_*`, greped for collisions: none).

**Litter checked with `ls`, never `git status`** — `.gitignore` hides `*~.sch`, which
is issue 1480 and how a whole audit missed the leak.

---

## Corrections to PLAN.md

None — `PLAN.md` does not cover R3. Corrections went to **`0609`** (its fix code, now
banner-marked SUPERSEDED; its closing ⚠, now ✅) and **`1480`** (§5's overstated
"must land together"; §6 item 3, now ✅). `DECISIONS.md` was already corrected by the
design crew and I did not touch it.

**For the crew that builds the containment:** the delta has removed your hardest
constraint. `C11` no longer cares which directory you pick, because it watches its own
cwd — so 0609 §3's *"if that is `$REPO`, every T1 run goes red"* no longer applies.

---

## Left dirty

Five files, all mine, no commit:

```
tests/headless/test_ase_core.tcl            | 79 ++++++++++-
tests/headless/test_op_dump_altshow.tcl     | 49 ++++++-
tests/headless/test_no_untitled_litter.tcl  | 27 ++--
doc/claude/issues/0609-…md                  | 79 +++++++++--
doc/claude/issues/1480-…md                  | 21 ++-
```

**No new issue number minted** — 0609 already names `C11` and records the 13/13 reds,
exactly as `DECISIONS.md` said.

**Nothing of mine leaked:** repo root and `tests/` both clean (`ls untitled*` → no
such file, both); no `_*_[0-9]*` scratch dirs; `~/.xschem/ase_simulators` still
**724 bytes, mtime 2026-09-14 00:22** — untouched, though I ran the simulator-
registering `test_op_dump_altshow` four times.

Untracked entries are the four pre-batch ones (`.xschem/`, `rdw_lists_batch/`,
`rdw_sim_batch/`, `sky130A/…/debug_st1/`) plus this receipt. The concurrent `claude-md`
crew's edits to `CLAUDE.md`, `NUMBERING.md`, `receipts/claude-md.md` and issue `1481`
appeared and then left my diff during the task — **not mine, not touched.**

---

## Owed to the user

**Nothing new, and nothing cleared.** I did not touch `owed.sh` (brief rule 8).

No pixels, no UI copy, no user-visible behaviour — this is internal test-harness
engineering, which is the driver's stated reason for taking R3 off the user's queue.
Nothing found here disturbs that, and **0356 remains the user's**: no `.gitignore`
rule and no sweep was added, deliberately.
