# RESUME — driver orchestration, branch `annotate`

Written 2026-08-30 18:55 MST, when item **S4c** was stopped mid-run so the user
could re-login on an account with tokens available. Read this first in the new
session.

## State of the tree, measured before stopping

* Last commit: **`bbca021b`** (item S4b).
* **Uncommitted and wanted — do NOT discard:**
  * `src/token.c` (+283 lines) — the issue **0980** fix
  * `tests/headless/test_unused_attr_0970.tcl` (21 -> 40 checks)
* `src/xschem` **is built from that source** (token.c 18:44:09, binary 18:44:12).
* `grep -rn SABOTAGE src/` is empty — the run did not stop inside its sabotage
  pass, so no deliberate defect is sitting in the tree.
* The suite passes on that binary: `RESULT: ALL PASS (40 checks)` / `OVERALL: ok`.
* Backup of the whole uncommitted diff, in case the tree is ever disturbed:
  `<scratchpad>/s4c_inflight.patch` (148 KB) — reapply with `git apply`.

**Nothing is committed for S4c and no ledger row was written.** That is correct,
not a loss: the crew commits in its write-up phase, which never ran.

## What S4c had finished, and what it had not

8 of ~12 agents returned. Scout, Measure, Plan, RED and Implement are spent and
on disk. **Verify x3, Sabotage, Write-up+commit and Ledger did not run.**

## Two ways to resume, in order of preference

**1. Same run, replaying the finished agents from cache.** Only works if the
run id is still visible to the session — the workflow journal lives under the
*session* directory, and the tool documents resume as same-session only. If
`/login` swapped the account without ending the session, this is still valid:

```
Workflow({scriptPath: "doc/claude/ledger/crew.js",
          resumeFromRunId: "wf_4b4abf31-e2b",
          args: {id: "S4c", brief: "<the S4c brief, VERBATIM>"}})
```

**`args` MUST be passed again on resume, and the brief must be byte-identical.**
Measured 2026-08-30: `resumeFromRunId` alone fails instantly with
`TypeError: undefined is not an object (evaluating 'args.id')` — the run id
restores the agent CACHE, not the script's inputs, and `crew.js` reads `args.id`
on its first line. The brief must match verbatim because it is interpolated into
every agent prompt, and the cache keys on `(prompt, opts)` — a reworded brief
silently re-runs all of them at full cost.

`crew.js` was edited after that run launched (the `must()` guard below), but only
outside the prompt strings, so the cached agents' `(prompt, opts)` are unchanged
and should still hit.

**2. If that fails, re-dispatch S4c fresh.** The brief is in the S4c section
below. Tell the crew what is already on disk so it does not redo the
implementation — the tree already holds the fix, built, with its suite grown and
green.

## Guard added while S4c was in flight

`crew.js` now halts rather than reporting work that did not happen. A workflow
`agent()` returns `null` when its subagent dies on a terminal API error, which is
what an exhausted quota looks like; the script was a straight line of awaits, so
a null used to walk all the way to the LEDGER agent and buy a plausible row over
nothing. Now: seven single-agent phases are wrapped in `must()`, and the Verify
fan-out requires all three verdicts to actually arrive — losing all three used to
leave `failed = []`, byte-identical to three passes. **The stopped S4c run parsed
the old script, so it was unguarded; every crew from here is guarded.**

## Queue after S4c

**S5 — issue 0799**, and its issue file is unusually complete; the brief is
mostly a pointer to it.

> Fix issue 0799. `library_new` (`src/library_defs.tcl:873`) checks three things
> — name non-empty, name not already registered, a writable `library.defs` to
> append to — and **never looks at the path**. So **Library manager > New
> library…** accepts the registry ROOT itself (every cell then lands loose among
> the real libraries, inside a git-tracked PDK tree) and accepts a folder that is
> already some registered library's own path (two DEFINEs for one directory,
> which is the fixture `vimport::symbols_path` already has a written-down defence
> against). `libmgr::do_new_library` (`library_manager.tcl:1051`) is a thin
> wrapper that adds no check, and `vimport::create_library` (`xschem.tcl:17777`)
> grew four guards for issue 0792 that live only on the import path. Section
> "What the fix has to be" in the issue file lists five numbered requirements —
> follow them, including requirement 4: a blank Directory means
> `<dirname of the primary library.defs>/<name>`, which is the ordinary correct
> case and must stay rc 0. Mutation-verify every check and make the ordinary
> blank-directory case a check in its own right, because it is what a wrong guard
> breaks first.

## The user's ruling queue — SEVEN items, none answered

These are the user's to settle. Do not answer them in a crew.

1. **S1** — one mistyped simulator path takes the working PATH ngspice out of
   service, because the first entry registered goes into force even when its file
   is bad. Should only a validated entry go into force, or is stopping every run
   the right answer?
2. **S2a** — a location that already names a real program on disk is now taken as
   that program's name instead of being refused, so what a location means depends
   on what is on the disk at the moment you add it. Keep, or go back to refusing?
3. **S2a / 0947** — an entry added before its setting existed still says the
   session does not know that setting after it is set. Three candidate fixes were
   offered.
4. **S3a / 0958** — a simulator that never answers costs a 30 s pause on EVERY Run
   press, not once (measured 3 x 30 s where the code it replaced cost 20 s once
   and then nothing). Re-probe each press, back off, or settle until the program
   file changes?
5. **S4 / 0964** — on a bench with an operating point and a transient, the
   operating point now runs LAST, so device numbers stop being recorded at all
   20,505 transient points (144.5 MB -> 69.6 MB, ~5 s off). Accept that reordering
   on the bandgap bench?
6. **S4 / 0967** — ticking the device-numbers box silently changed which analysis
   the Outputs Value column reads.
7. Earlier pair, still open — `xschem raw read` returns 0 when it finds nothing
   and leaves the previously loaded raw in place (0929 section 5); and the
   dirty-sheet refusal wording (0628/0632/0633), now urgent because 0927 made the
   message routine.

Look debts outstanding: the Command-window sentences, which plot the waveform
viewer opens on, the x5/x6 rows, and `sky130_mismatch`'s ten bussed transistors.

## Standing constraints, unchanged

* Never `git push`. Never open a PR. Never `git checkout` / `switch` /
  `reset --hard`. Commit on `annotate` and stop.
* Issue numbers: `0500-0599`, `0700-0799` and **`1000-1199`** are RESERVED. After
  0999 file **1200**. Read `doc/claude/issues/NUMBERING.md` for the next free
  number; do not trust a number written in a brief.
* One crew at a time — a concurrent `make` during a fan-out is the recorded OOM
  path on this ~7.8 GB box.
* T1's baseline is ZERO counted failures. If it is not zero, say which case and
  why, per case.
* Never a bare `./src/xschem --script` on `$DISPLAY` — that is the user's real
  screen. Route through `tests/headless/devdisplay.sh exec` or `run_suites.sh`.
* Never a bare `xschem` on PATH — it is a 3.4.6 Jan-2025 build that rewrites the
  user's `~/.xschem`.

## GUI gate

The pre-grant had expired (05:12 today); re-granted for 12 hours at 18:57 so a
batch of suites does not stop on a Proceed click with nobody at the desk. Only
`allow_until` was written — `control` is untouched, so Pause and Stop still work,
and the user can revoke at any time.
