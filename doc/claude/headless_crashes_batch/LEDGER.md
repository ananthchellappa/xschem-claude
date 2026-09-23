# Ledger — headless crashes batch

| stage | item | crew | receipt | verdict | commit |
|---|---|---|---|---|---|
| setup | — | driver | PLAN.md | batch opened 2026-09-22 | `7e1e6a6f` |
| Map | A+B (1493, 0227/0834/0467) | workflow `headless-crashes-A-B` | pending | in flight | |

## Adjacent streams (D2) — not this batch's items, driven alongside it

These are recorded here because this was the live batch when the driver opened them, so
the record shows where the attention went. They have no batch directory of their own; the
issue files carry their full receipts.

| item | crew | what landed | T1 | commit |
|---|---|---|---|---|
| **1352** — `input_line`'s OK button ran what you typed as Tcl | input-line-inject-crew | `list`-quoted entry contents + an emptiness guard; `test_input_line_inject_1352` registered in **both** `hcases` and `dcases`, 7 checks headless / 34 on a display | `cases=90 blocks=89 counted_failures=0 skips=6`, `tests/results.2825611.log` | `2a22bfb7` |
| **1601** — a file NAME is a script in the Open and Insert preview bindings | driver (filing), fix crew in flight | filed from 1352's sibling survey; provenance measured — the shape is upstream by four years, one commit that touched it (`451a949c`) is ours | — | `f8647d8d`, `321f43c0` |
| **1600** — `test_ase_core`'s 5324-line unnamed file-scope `catch` | ase-core-catch-crew (own clone, `/var/tmp/x1600/tree`) | 15 named guards; worst single-raise span 5324 → 609 lines; 2 cascades found by the sabotage and hoisted out; the issue's own awk sweep returns zero on the file and 34 corpus-wide, from 35 | crew's clone at `e92a2abf`: `cases=88 blocks=87 counted_failures=0 skips=5` | `5a6da030` |
| **1600** follow-up — two holes the pass exposed | driver | item 3, the UNGUARDED stretches the sweep is blind to (319 of 675 rows, and a raise there yields no verdict at all); item 4, the denominator, with the obvious design rejected and the `else`-arm design recorded | — | `1c298398`, `06c6a6bc` |
| **combined gate** — 1352 + 1600 together | driver | a throwaway clone of `5a6da030` at `/var/tmp/xgate_5a6da030/tree`, built from scratch, `DISPLAY=:99` | **`T1-RUN-END pid=2983014 cases=90 blocks=89 counted_failures=0 skips=6 elapsed=553s`**, `tests/results.2983014.log`; 0 counted shapes by independent grep; 0 live-peer announcements, so it ran solo; all six `skip:` lines named — five `test_op_annot`, one the new suite's | — |
| **1601** — a file NAME is a script in the preview bindings | preview-name-inject-crew | measured first: the exploit **fired** through the shipped Open dialog, canary set by a file named `pwn[set ::CANARY …]ed.sch`. Four sites moved to `list`; the two `after` sites together, with the cancel-still-cancels proof done three ways. One claim in the driver's own filing **refuted** — the direct call is not an exposure | `cases=92 blocks=91 counted_failures=0 skips=7` in a shared tree, so re-gated | `6f4ee5cc` |
| **clean gate** — 1352 + 1600 + 1601 | driver | throwaway clone of `6f4ee5cc`, built from scratch, `DISPLAY=:99`, solo | **`cases=92 blocks=91 counted_failures=0 skips=7 elapsed=601s`**, `tests/results.3482374.log`; `274` lines = 2 + 91 + 91 + 3 + 7 + 78 + 2 | `f066cf9e` (baseline) |
| **1600** second file — `test_ase_dialogs` (5699 of 6380, 89%) | ase-dialogs-catch-crew (own clone) | 20 named guards, span → 659; **zero** unguarded rows; three rename-restores found by reading, which a head-raise sabotage cannot reach | crew clone at `d1db4c63`: `cases=90 blocks=89 counted_failures=0 skips=6` | `0aa50c3e` |
| **1604** — a parenthesis in a file name fails the xschem-file test | crew-1604 (own clone) | **the driver's prescribed fix was wrong** and the survey caught it; the grammar is `is_generator`'s ERE in `src/token.c`, now matched character for character, with row `S8` comparing the two files so they cannot drift | crew clone at `02187697`: `cases=94 blocks=93 counted_failures=0 skips=8` | `005abc87` |
| **1605** — the same pattern in C, unguarded, on the netlist provenance comment | driver (filing) | the loose end 1604's crew named and correctly declined; five netlisters write it into `sym_path:` / `sch_path:`. ⚠ what the line ends up saying is **not** measured | — | `c3ec73a3` |
| **1600** third file — `test_ase_persist` (992 of 1181, 83%) | ase-persist-catch-crew (own clone) | in flight | | |
| **1602** — the precision dialog accepts a value that breaks every number | precision-validate-crew (own clone) | in flight | | |
| T1 baseline | driver | `CLAUDE.md` moved from 88/87/skips=5 to 90/89/skips=6 | read off `results.2825611.log` | `4a74bc24` |
| owed-queue triage | queue-triage-crew | 248 entries → 69 retired, 179 survivors collapsing to 2 framing questions, 19 decisions, 22 sittings; store byte-untouched | — | `e92a2abf` |

### What the 1352 receipt is worth reading for

Three things in it are method, not result, and the next crew should copy them:

1. **It named the rows that stayed green under sabotage** — `B7`, `B13a`, `B13b`, `B2`,
   `B12a`, `B12b`, `B14`, `B17a`, `S0`, `S3`, `S5` — so nobody counts them as coverage.
   They are guards on behaviour the defect did not break, and a receipt that omitted them
   would have read as eleven more discriminators than it has.
2. **It separated DRIVEN from REASONED** and put the reasoned list in writing: a hostile
   `$cmd`, Unicode, very long entry text, Windows, and the six C-side `{}` callers driven
   only by shape rather than through their own code paths.
3. **It stripped comments before grepping the product.** The fix's own comment quotes the
   defective line verbatim, so a raw-file structural row would have answered "still broken"
   for ever. Any structural row that greps a file its own fix documents needs this.

### One thing the 1352 crew flagged that the driver must not lose

`rule/1352` is **still open** and asks the user to choose between taking the one-line fix
tree-wide, surveying every caller first, or leaving it as an inherited sharp edge. The crew
did the survey **and** took the fix without that answer, which is the recommended shape
(`doc/claude/code_analysis/owed_queue_triage_2026-09-22.md`, D-1) — but the user is now
being asked to choose between options one of which has already shipped, and they have to be
told that when the question is put. A rule debt clears only when the user says so.

`rule/1601` was filed for the sibling sites and asks the same question about the same
published branch. **It rides with `rule/1352`; it is one conversation, not two.**


### What the three converted suites cost and bought, side by side

| | `test_ase_core` | `test_ase_dialogs` |
|---|---|---|
| unnamed catch | 5324 lines | 5699 of 6380 (89%) |
| guards added | 15 | 20 |
| worst single-raise span after | 609 lines | 659 lines |
| rows left **outside** every guard | **319 of 675** | **0 of 388** |
| check count before → after | 675 → 675 | 37/389 → 37/389 |

The last two rows are the ones to read together. **The check count does not move**, because
the idiom is failure-only — so neither conversion can be seen in a green run at all. And the
unguarded-row count is invisible to the issue's own awk sweep, which hunts for a `catch`
that is too big and is blind to a region with no `catch` at all. `test_ase_core` still has
319 rows in that state; `test_ase_dialogs` has none. **A zero-hit sweep on a file does not
mean that file is done**, and only a crew that goes looking will ever report it.

### The method, now paid for three times and worth stating once

1. Sabotage at the **head** of each guard. A head raise exposes cross-section coupling; a
   middle one only finds the rows below it.
2. Count rows as `^ok:` + `^FAIL:` over the whole run, **never** from `RESULT:`. A cascade
   that aborts the interpreter prints neither, and *a run with no `RESULT:` line is itself
   the finding*.
3. Scan mechanically for a variable read **below** the old arm: every column-0 `set` in the
   body grepped for `$name` after it, every `proc` grepped file-wide, each hit read to
   separate a real call from a mention in a comment.
4. Look for a **renamed or stubbed global**. `test_ase_dialogs` had three, and no head-raise
   sabotage can reach them. An unconditional `rename ase::foo {}` in a restore **deletes**
   the real proc.
5. Read the file's own comment wall for stale claims about coverage. `test_ase_dialogs`
   carried "runs this file on NEITHER arm — measured" at four sites, and it is in `hcases`.
   Wrong in the direction that costs coverage: it invites a reader to discount a real result.
6. ⚠ After **any** comment edit, re-run the suite. A comment inside a Tcl proc body sits in a
   brace-quoted word and Tcl counts braces before it notices the `#`. That broke the product
   twice on 2026-09-22 — once making every call raise, once aborting startup.

## Session close — 2026-09-22, where to pick this up

**Everything below is committed on `fluid-editing` and unpushed.** The user has not been
asked to push; that is the first thing to offer them.

### Landed this session

| issue | what | commit |
|---|---|---|
| **1352** | `input_line`'s OK button ran what you typed as Tcl | `2a22bfb7` |
| **1601** | four preview bindings ran a FILE NAME as Tcl; exploit driven through the shipped Open dialog before the fix | `6f4ee5cc` |
| **1604** | a parenthesis in a file name failed the xschem-file test; the driver's prescribed anchor was **wrong** and the survey caught it | `005abc87` |
| **1602** | the precision box refuses a value it cannot use and says why | `63558796` |
| **1600** | all four T1 cases converted: `test_ase_core` `5a6da030`, `test_ase_dialogs` `0aa50c3e`, `test_op_annot` `81386d97`, `test_ase_persist` `6c012d1d` | — |

Filed and **not** fixed: **1603** (a symbol with no `type=` is a NULL `strcmp` in 28
places, one measured), **1605** (the same parenthesis pattern in C, unguarded, on the
netlist provenance comment), **1606** (an unbounded `sprintf` on `ev_precision` aborts
xschem, and `xschemrc` reaches it without the dialog gate).

### The one thing genuinely unfinished

**The `headless-crashes-A-B` workflow's Verify stage.** Its Implement stage landed edits to
`src/callback.c`, `src/draw.c`, `src/hilight.c`, `src/scheduler.c` and
`tests/headless/test_callback_argc.tcl` **in the main tree, uncommitted** (receipt
`receipts/A-impl.md`). Its gate run was then killed by another crew's `pkill -f` (D7), so
**its verdict is a partial that reads green by prefix and must not be quoted**. Whoever
picks this up: re-gate that work in a throwaway clone before committing any of it.

### Open for the user, in the order to ask

1. **A-0** — the Results Display Window: read the 54 recorded choices, or open the window
   once and say what jars? Recommendation: look first, then read the six load-bearing ones.
   (`doc/claude/code_analysis/owed_queue_triage_2026-09-22.md`, Part 1.)
2. **`rule/1352` and `rule/1601` ride together** — one conversation, not two. Both ask
   whether to diverge from upstream xschem on the branch the user publishes, and **the
   recommended shape has already shipped in both cases**. They have to be told that when
   the question is put.
3. **`look/precision_refusal_dialog_1602`** — the new refusal wording, verified on `:99`
   only, never on the real screen.
4. **`rule/1606`** — what an out-of-range `ev_precision` from a config file should do.
   1602's "refuse and say why" does not automatically carry to a file read before there is
   a window to put a message in.

### What to do next, if nobody says otherwise

**Issue 1600 item 3 outranks item 2, and the issue now says so.** `test_ase_core` still has
**319 of its 675 rows outside every guard**, and it **is** a T1 case; everything left in
item 2 is a suite that is not. The measurement is a brace-depth scan and takes a minute per
file — and the sweep that defines the issue is structurally blind to it, so nobody finds it
without going to look.

## The batch is closed — 2026-09-22, both arms at ZERO

| criterion | verdict |
|---|---|
| 1. the fix is in the product and is the cause | **met** — 271 sites enumerated by the compiler, 17 reached with `has_x == 0`, a backtrace per site |
| 2. measured both ways, full T1 at ZERO on **both** arms | **met** — `DISPLAY=:99`: `cases=95 blocks=94 counted_failures=0 skips=8` (`results.598045.log`); `DISPLAY` unset: identical (`results.658534.log`). Throwaway clone of `2bf05781`, built from scratch, each arm solo |
| 3. a guard that silently skips work is worse than the crash | **met, and it earned its place** — the fix round caught a violation the *implement* round had introduced: `grabscreen()`'s guard returned without clearing `ui_state & GRABSCREEN`, so one `XK_Print` keypress killed the event switch for the life of the process |
| 4. T1-visible | **met** — `test_callback_argc` 27 → 50 checks; new `dcases` entry `test_headless_guards_xarm_1492` |
| 5. rounds capped | **met** — one implement, one adversarial verify, one fix round |
| 6. scratch per crew, deleted by owner, peak reported | **met** — 239 MB (map), 1.5 GB (fix round), both deleted; 104 KB left under `/var/tmp/xhc` |

**What changed in the world:** before today, running T1 with no display gave four
segfaulting suites. It now gives the same zero as the display arm. `CLAUDE.md`'s rule that
the zero is a `DISPLAY`-set-only figure is retired with this commit.

**What "closed" does not mean.** The receipts name four blind spots in the methods used —
the preprocessor (five real dereferences excluded from this build, including the Windows
paths and a libjpeg-only one), shadowed locals of the same name, handles cached in `xctx`
rather than read from the global, and reachability bounded by the workload driven. Three of
the five crashes fixed here were in that third category, so it is not hypothetical. A full
"dies without a display" map is strictly larger than this one.

### Still owed from this batch's receipts, not lost

`receipts/A-verify.md` §6 lists what the driver still owns. Filed since: **1607** (the
`psprint.c` heap over-read, measured). **Not yet filed**, and the receipt holds the
measurements: §2.2 the `--svg` stub that writes 5 tags and calls it success, §2.3 the
missing `XSetIOErrorHandler`, §2.6 `fill_reset` refusing where it could work. Also §2.4:
**issue 0815 is 1492's older twin** and should be closed with it, and the resolution
sections for 0227, 0834, 0467, 1492 and 1493 are unwritten because `doc/claude/` was fenced
to the receipts while the crews ran.
