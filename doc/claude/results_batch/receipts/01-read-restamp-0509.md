# Item 1 — `raw read` re-stamps on the dedupe path (R110, R112) — closes 0509

## 1. Files changed

`git diff --numstat`: `src/save.c` +110/-2, `src/scheduler.c` +9/-3, `src/xschem.h` +18,
`doc/claude/specs/results_selection.md` +109, `doc/claude/issues/0509-*.md` +78/-1 — 324 insertions, 6 deletions.
**New:** `tests/headless/test_results_select.tcl` (434 lines) and this receipt.

`src/save.c` gains one static helper, `raw_restamp_design()`, called from **both** `what == 1` "file found: switch to
it" arms (non-spice = table/vcd, and spice): it refreshes `raw->schname`/`raw->level` from `xctx->sch[xctx->currsch]`
and re-primes the case-mode verdict, **nothing re-parsed**. **R112**: its header comment now states what the return
value MEANS for an already-loaded file and how a caller tells read from switched (compare `xctx->extra_raw_n`, as `raw
read -case` does). `src/xschem.h` adds `RAW_READ_REBIND` (bit 6 of `what`); `src/scheduler.c` sets it in the three
`read` verbs and records why `raw_case_reread()` does not. `raw switch` untouched (R111); `sch_waves_loaded()`
untouched (0509 candidate 2 — 52 call sites, explicitly not this item).

## 2. Decisions taken, and the evidence for each

All rulings are written into `doc/claude/specs/results_selection.md` §3.1 under R110 (per DECISIONS.md §C — no human
in the loop) and summarised in 0509's Resolution.

- **R110a — re-stamp only when the stamp does not already resolve against the stack.** R110's literal wording
  (unconditional refresh) was built and measured to create the same blindness the other way round: read at hidlib/top,
  descend, re-read (`raw_level` 0→1), ascend — top level `loaded=-1`, `raw index v(n1)` = -1. `sch_waves_loaded()`
  accepts ancestors (`draw.c:2831-2838`) and the descend path already pushes the stamp back UP with `xschem set
  raw_level` (`scheduler.c:12275-12297`). Group D, red without it (S3).
- **The guard still refreshes `raw->level`**, which could otherwise sit ABOVE `xctx->currsch` — refused outright by
  `xschem set raw_level` (`scheduler.c:12291`) and making four `ngspice::` builders (`xschem.tcl:4025/4071/4101/4126`)
  return "" where they owe `?`. Group I (S18).
- **R110b — the re-bind re-primes `raw_case_mode_schematic()`**, copying `raw_read()`'s own prime (`save.c:1391`);
  without it the descend arm (`save.c:2877-2883`) REPLAYS cell A's verdict as this design's answer — measured `fold`
  vs the hierarchy's own `unknown`. Group G (S17); the ruling had NO check until the fix round.
- **R110c — the re-bind is opt-in and only the `read` VERBS opt in.** Unconditional inside `extra_rawfile()`, the ~14
  `src/draw.c` graph walkers re-bound too: merely OPENING a schematic whose `autoload=` graph names a loaded raw
  blinded the cell the user read it under — 0509's symptom one door along, against driver ruling **U10**. Group F
  (S19).
- **Boundary, not a defect: R110 re-binds ONE ANALYSIS SLOT.** The key is `(rawfile, sim_type)`; a two-plot
  `multi.raw` is two slots, one result (U11). Reproduced: after re-reading `tran`, `raw switch multi.raw dc` still
  answers -1. `read` is analysis-level; the run-level gesture is item 3's `xschem raw select`. **R111 kept:** `raw
  switch` does not re-stamp — group C asserts it stays blind, and that a `read` one line later re-binds.

## 3. Test, check count, verbatim RESULT — and the audit diff

New suite `tests/headless/test_results_select.tcl`, **74 checks**, `SEL1`..`SEL74` (band measured free by grepping
`tests/headless/*.tcl`). Groups: A/B the two arms of T-B, C R111 + registry integrity, D the R110a guard, E the level
half, F R110c, G R110b, H the `sch[currsch]` half, I the level refresh.

```
PASS     | test_results_select          run 1/5  RESULT: ALL PASS (74 checks)
PASS     | test_raw_read_dispatch       run 2/5  RESULT: ALL PASS (51 checks)
PASS     | test_raw_case_mode           run 3/5  RESULT: ALL PASS (277 checks)
PASS     | test_raw_read_failure_0306   run 4/5  RESULT: ALL PASS (63 checks)
PASS     | test_wave_cursor_crossdb     run 5/5  RESULT: ALL PASS (93 checks)
RESULT: 5/5 runs passed
```

Driven by the closer: `git show HEAD:src/save.c` rebuilt in place gives `RESULT: 15 FAILED (59 passed)` — SEL11, 12,
13, 22, 23, 24, 33, 47, 48, 49, 67, 68, 69, 73, 74, i.e. reds in BOTH arms (11-13 spice, 22-24 non-spice). Restored
from a byte-exact backup (`md5sum -c` OK), rebuilt, `ALL PASS (74 checks)` again, `test_raw_case_mode` 277/277. At the
suite's original 49 checks the same drive gave `RESULT: 10 FAILED (39 passed)`.

**Audit** — `full_audit.sh`, `GUI_GATE=1`, dev display `:99`: **332 pass / 15 fail / 0 crash-timeout / 0 skip of
347**, against the baseline's 331/15/0/0 of 346. Diffed by NAME and STATUS against
`doc/claude/results_batch/baseline_2026-08-19_226302f9.txt`: **no status changed in either direction** — 0 green→red,
0 red→green across all 346 shared rows; nothing only in the baseline; only in this run `test_results_select` PASS,
which is the entire +1. The 15 reds are the baseline's 15 by name. WIREEDIT PASS, SCRATCH 0 leaked, TREE 0/0.

## 4. Sabotage

Break, name the reds, restore from a byte-exact backup (`cmp -s`, never `git checkout --`), rebuild, re-run — every
row below restored green. Rows are grouped **by drive**; **all 74 ids appear below, so no check is unsabotaged.**

| check ids | what was broken | went red? |
|---|---|---|
| SEL22,23,24 | **S1** — NON-SPICE arm's `if(user_read) raw_restamp_design();` removed | yes |
| SEL11,12,13,33,47,48,49,67,68,69,73,74 | **S2** — SPICE arm's call removed | yes |
| SEL39,41,42 | **S3** — the R110a guard removed | yes |
| SEL5,6,17,18,30,31,37,39,45,53,56,60,65 | **S4** — `sch_waves_loaded()` stamp compare forced true (`draw.c:2834`) | yes |
| SEL1,8,14,19,25,26,32,34,38,44,46,51,58,61,66,70,72 | **S5** — `raw read` rc forced to 0 | yes |
| SEL2,10,21,29 | **S6** — `raw rawfile` returns a literal | yes |
| SEL15 | **S7** — `raw sim_type` returns a literal | yes |
| SEL3,11,16,22,27,33,42,49,52,55,57,69 | **S8** — `raw index` forced to -1 | yes |
| SEL9 | **S9** — SPICE dedupe match disabled (every read appends) | yes |
| SEL20 | **S10** — NON-SPICE dedupe match disabled | yes |
| SEL7 | **S11** — `raw info` prints a literal, not the path | yes |
| SEL28,29,31 | **S12** — the `raw switch <file> <type>` arm returns 0 | yes |
| SEL40 | **S13** — `go_back()` disabled | yes |
| SEL4,5,12,17,23,31,35,37,41,45,48,53,54,56,60,65,68,71 | **S15** — `raw loaded` returns `sch_waves_loaded()+7` | yes |
| SEL36,43,44,62,64,67,68,70,71 | **S16** — bare `xschem descend` made a no-op | yes |
| SEL63 | **S17** — the R110b case-mode re-prime deleted | yes |
| SEL73,74 | **S18** — the level refresh removed from the guard path | yes |
| SEL53,54,55,56,57 | **S19** — `user_read = 1` (R110c defeated: the DRAW re-binds) | yes |
| SEL59 | **S21** — `raw_case_mode_schematic()` returns UNKNOWN always | yes |
| SEL67,68 | **X1** — stamp hardcoded to `sch[0]`/level 0, not `[currsch]` | yes |
| SEL50 | **X3** — a read silently truncates the registry to the matched slot | yes |

S1's and S2's red sets are **disjoint** — the proof both copies of the twice-written arm were fixed, which this item
required.

## 5. What was NOT verified

- **The table above is the implementer's and verifier's measurement**, coverage-checked but not re-driven row by row
  by the closer (21 sabotages are 21 rebuilds). What the closer did drive itself is the pristine-binary comparison in
  §3, which reds both arms, and a rebuild from the exact sources before every run.
- **Group F is real under X and VACUOUS under `--nogui`** (`xschem draw_graph` is `has_x`-gated, `scheduler.c:3401`);
  the canonical arms have X. Stated, not skipped: a skip line would make `full_audit.sh` discard the whole file.
- **`RAW_READ_REBIND` is set at three call sites** and only `raw read` is exercised: group B reaches the non-spice arm
  as `raw read <f> table`, not `raw table_read <f>` (there is no VCD fixture either). `test_raw_read_dispatch` (51,
  green) pins the verbs' dispatch.
- **"Nothing is re-parsed"** is asserted by no check — observed only as the absence of the `Raw file data read:` line
  on a re-read.
- **Raised, NOT confirmed, no code changed:** the third verbatim copy of the branch, in `new_rawfile()`
  (`save.c:1570-1577`), still does not re-stamp — different function, different contract (`0` = already loaded),
  outside scope. 0509 names it and 0509 is closing, so a follow-up issue is the driver's call; no reproducer was built
  either way.
- **Reviewer not-proven:** no leak trace (`-d 3 -l log`) around `raw_restamp_design()`; no multi-tab probe (tabs do
  not share a registry).
- **Scope note for the driver:** R110c required `src/xschem.h` and `src/scheduler.c` too — `extra_rawfile()` cannot
  tell a `read` verb from a graph walker without being told. **No eyeball owed:** the payload is a binding, not
  pixels; nothing added to `owed.sh`.
