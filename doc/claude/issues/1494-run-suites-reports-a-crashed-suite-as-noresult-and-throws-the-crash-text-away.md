# 1494 — `run_suites.sh` reports a crashed suite as `NORESULT` and throws the crash text away

**STAMP:** `v1 claim=open tree=0eed8a1b stamped=2026-09-20 fix=none open=3 by=B-docs`

**Status: OPEN — filed 2026-09-20** by the stranger-reds batch, from item B's fix round
(`receipts/B-verify.md` §4.6, finding 12 of 14), under batch decision **D6**.
**Class** harness / verdict honesty: the documented command hides the one line that says
what happened. **Related: 1487**, the same family in the T1 verdict (`summarize_all`
drops `skip:` lines); **0227** and **1492**, the crashes this defect hid; **0891** and
**0147**, the precedents for a printed-but-unreported line. See "Why this is not filed
into 1487".

---

## The defect

`tests/headless/run_suites.sh` is the command CLAUDE.md documents as the trustworthy
signal for running one suite. When the binary dies, it prints an exit code and discards
everything the binary said on its way out.

**MEASURED** (`receipts/B-verify.md` §4.6), item B's fixed build, on a suite that crashes
headless:

```
$ GUI_GATE=0 AUDIT_DISPLAY=none ./run_suites.sh --nogui test_undo_selection
display arm: none (DISPLAY unset; GUI legs will self-skip)
NORESULT | test_undo_selection          run 1/1 (exit 1 — binary never reported)
RESULT: 0/1 runs passed
```

and nothing else — **while the same binary, run bare, prints `EMERGENCY SAVE DIR: …` and
`FATAL: signal 11`.**

`exit 1 — binary never reported` is true and useless. It is what a suite that crashed,
a suite that bailed, and a suite that exited 1 for a hundred unrelated reasons all look
like.

## What it cost, measured

**MEASURED by the `completeness` verifier and recorded here at second hand**
(`receipts/B-verify.md` §4.6): a sweep of all 405 suites through the documented driver
found `FATAL: signal` in **zero** output files. The four real crashes of the 0227 family —
`test_keybind_snap_grid`, `test_undo_selection`, `test_hilight_case_senders`,
`test_window_switch_bogus_enter` — surfaced only when the non-passers were re-run **bare**.

So the defect is not hypothetical and not cosmetic: it is why a full sweep of the corpus
through the project's own recommended command reported no crashes in a tree that had four.

## The code already knows how, one arm up — READ at `0eed8a1b`

In `tests/headless/run_suites.sh`, the FAIL arm ends with an echo of the suite's own
failure lines, indented under its verdict:

```sh
printf '%s\n' "$out" | grep -E '^(FAIL|FATAL)' | sed 's/^/         | /'
```

and its own comment says exactly why `FATAL` is in that alternation: *"a suite that dies
through `bail` prints its verdict there and never prints a FAIL: line, so the FAIL: grep
alone would show nothing."* **The NORESULT arm, eight lines above it, has no such
line.** The literal is already in the file, in the right shape, for the right reason, on
the wrong arm.

### The sharper half: two echoes DO survive a NORESULT

**READ at `0eed8a1b`:** two more echoes sit *after* the whole `if`/`elif` chain, so they
run on every arm including NORESULT — the suite's `^skip:` lines (DECISIONS D13.11, the
fix for issue **1487**'s sibling) and its `note: corpus-source` line (issue **1485**).

So `run_suites.sh` faithfully carries a crashed suite's **skips** and its **corpus
provenance** through the verdict, and drops the one line that says the binary died. The
information a reader most needs is the only kind this arm discards.

## Why this is not filed into 1487

Same family, different defect, and neither fix implies the other:

| | **1487** | this file |
|---|---|---|
| file | `summarize_all` in `tests/run_regression.tcl` | the NORESULT arm of `tests/headless/run_suites.sh` |
| reader | the T1 verdict | a single-suite run |
| line lost | `skip:` — coverage that did not run | `FATAL:` / the crash text — the run that died |
| reads as | a clean sweep | an unexplained exit code |

Filing them as one number would bury a crash-reporting defect inside a file whose title
says "skipped rows", and would leave whoever fixes one believing the other was covered.
They are cross-referenced instead. **If someone lands a single carrying rule for both
drivers, close this into 1487 then** — with the evidence in hand, not by assuming it now.

## Fix direction

1. **Mirror the FAIL arm.** Echo `^(FAIL|FATAL)` under the NORESULT verdict, with the same
   `sed 's/^/         | /'` indent the other three echoes use.
2. **Consider naming the outcome.** `full_audit.sh` already classifies `*"FATAL: signal"*`
   as **CRASH**, so the vocabulary exists. A `CRASH |` verdict would make a death a named
   outcome rather than an exit code to interpret — which is CLAUDE.md's own rule (*"A
   stall must be a named outcome … never the absence of one"*) applied to a death.
3. ⚠ **Whatever is echoed must not be able to score.** Indent it, as the existing echoes
   do. A column-0 `FATAL` is `full_audit.sh`'s death marker **and** `run_regression.tcl`'s
   `^FATAL` counted shape, so an unindented echo would manufacture reds in whichever
   reader consumed the output next. This is 1487's own step-3 warning in a different
   driver.
4. **Pin it.** `tests/headless/test_audit_classifier.tcl` **section K** already locks the
   Tcl banner rule against `run_suites.sh`'s ERE and `full_audit.sh`'s two crash literals,
   so the file where this cannot silently regress already exists.
5. **Red-first fixture.** Any of the four suites in the 0227 family crashes deterministically
   under `env -u DISPLAY … --nogui`; `test_undo_selection` is the one measured above.

## Still open (3)

1. The NORESULT arm still discards the crash text.
2. A death has no named outcome — `NORESULT` covers a crash and an ordinary nonzero exit
   alike.
3. Nothing pins the echo, so it can be dropped again the way it was never added.

## Evidence

`doc/claude/stranger_reds_batch/receipts/B-verify.md` §4.6 (the measured verdict, the
405-suite sweep that found no crashes in a tree with four, finding 12 of 14);
`DECISIONS.md` **D6**. Source READ at `0eed8a1b`: the NORESULT and FAIL arms of
`tests/headless/run_suites.sh`, the two unconditional echoes below them, and
`nogui_tests` / the CRASH classifier in `tests/headless/full_audit.sh`.
