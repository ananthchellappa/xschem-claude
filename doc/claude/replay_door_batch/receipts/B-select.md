# RECEIPT B — the selection primitives log nothing (issue 1620)

**Stage:** B · **Crew:** 1 · **Date:** 2026-09-29 · **Tree:** `1041a87f`, branch `fluid-editing`
**State:** everything below is **UNCOMMITTED** in the working tree. I did not commit, push, stash,
or run a full T1.

## Headline

`select_all` and `unselect_all` now record themselves, so a recorded log can finally say "select
everything, then act" — **on both paths, which is the half that mattered**: a scripted
`xschem select_all` and a real Ctrl-A over the canvas each produce exactly one
`xschem select_all` line, and a record→replay round trip comes back byte-identical.

**The two log sites are in different places, and that asymmetry is the finding of this stage.**
`select_all()` self-logs at its **core**; `unselect_all()` must **not**, and logs at its
**scheduler branch** instead. I built the naive symmetric version to find out what it costs:
a child that drew two wires and deselected once produced **94 phantom `xschem unselect_all`
lines** (sabotage S3). That number is why the brief's literal instruction — *"make both
primitives self-log … guarded by `actionlog_suppress` exactly like every other self-logging
core"* — is right about one primitive and wrong about the other.

**Issue 1617 is untouched and provably so:** the CA* band of `test_wave_viewer.tcl` is
**byte-identical**, 30 rows, 0 FAIL, and the suite scores `ALL PASS (437 checks)` before and
after — because the core self-log made an edit to the Ctrl-A dispatch **unnecessary**. The only
change in `callback.c` is a comment.

**Seven sabotages, all caught, none survived.** One test-suite regression found, attributed by
bisecting the binary, and repaired: `test_select_at` rows SA5/SA7b had been passing by accident.

---

## 1. What I changed, by symbol

### `src/select.c` — `select_all()`

One line at the end of the function, after `rebuild_selected_array()`:

```c
 if(xctx->lastsel) log_action("xschem select_all");
```

plus the comment block that says why it is here and not at the verb. **Why the core:**
`select_all()` has exactly **two** callers — the Ctrl-A arm of the legacy `switch (key)` in
`handle_key_press()` and the `xschem select_all` branch of `scheduler.c` (which is what the
**Edit ▸ Select all** menu entry at `src/xschem.tcl` invokes) — and both are a user asking for
it, so one site covers key, menu and script. This is the arrangement
`select_grow_connected_step()` in the same file already documents in as many words
(*"Self-log at the CORE, not at the scheduler … All three callers funnel here"*).
`log_action()` itself returns early on `actionlog_suppress`, so "guarded by `actionlog_suppress`"
means *call `log_action`* — no extra guard exists to write, and sabotage S1 proves the guard is
load-bearing.

`if(xctx->lastsel)`: an empty drawing selects nothing and must not leave a replayable phantom
line — the rule this file already states twice.

### `src/scheduler.c` — the `unselect_all` verb branch

```c
      int had_sel;
      ...
      had_sel = ((xctx->ui_state & SELECTION) || xctx->lastsel || xctx->pin_sel_active) ? 1 : 0;
      if(argc > 2) {
        int dr = atoi(argv[2]);
        unselect_all(dr);
        if(had_sel) log_action("xschem unselect_all %d", dr);
      } else {
        unselect_all(1);
        if(had_sel) log_action("xschem unselect_all");
      }
```

* **Not the core.** `unselect_all()` is shared machinery: `/usr/bin/grep -rn "unselect_all("
  src/*.c` lists sites in `save.c` (×3), `netlist.c`, `paste.c`, `font.c` (×3), `in_memory_undo.c`,
  `hilight.c`, `editprop.c` (×2), `actions.c` (×6), `callback.c` (many, including
  `abort_operation()`'s ESC path) — a shipped comment in `callback.c` puts it at *"87 C call sites
  and 817 scripted ones, several inside netlisting"*. None of those is a user asking to deselect.
  This branch is the only deliberate spelling: the CIW, a script, and a custom rc binding — the
  `escape_deselects` note in `src/xschem.tcl` tells users to bind ESC to exactly this command.
* **`had_sel` is the core's own work gate** (`(ui_state & SELECTION) || lastsel`), plus
  `pin_sel_active` for a transient pin-only selection the core clears *outside* that gate. No
  phantom line when nothing was selected.
* **The `dr` argument is preserved in canonical form** so a replay is byte-identical instead of
  converging after one round — the same normalisation the `xschem undo` arm does (per the
  `test_selflog_grep_guard` manifest's own description of it).

### `src/callback.c` — the Ctrl-A arm: **comment only, no code**

No `log_action` was added and no dispatch was touched. The comment records (a) that the shipped
`/* select all */` label names the canvas meaning only — the same chord over a graph goes to
`graph.forward` / `waves_callback()` (issue 1617) — and (b) the invariant that this arm must
**not** log, because the core does.

### `tests/headless/test_select_log_1620.tcl` — NEW, 31 checks headless / 34 on the display arm

Bands `G*` (where the sites are and are not), `W*` (the scripted path, in children with their own
`--logdir`), `Z*` (the suppress seam), `R*` (the record→replay round trip both ways), `K*` (a real
Ctrl-A through `xschem callback .drw 2 … 97 0 0 4`, display arm only, uppercase `SKIPPED:`
headless). Prints `OVERALL: ok ($npass checks)` **before** its `RESULT:` line.

### `tests/headless/test_selflog_grep_guard.tcl` — the ratchet honoured, and the suite made registerable

Its header states the ratchet: *"adding a new C self-log means (a) adding its S1 manifest row and
(b) adding the verb to the S2 conflict set."* Done:

* **S1 manifest**, `src/select.c`: `{log_action\("xschem select_all"\)} 1`.
* **S1 manifest**, `src/scheduler.c`: `{log_action\("xschem unselect_all} 2` (both arg forms).
* **S2 `CVERBS`**: `select_all unselect_all` added.
* **S3 (branch-must-not-log)**: `select_all` added; **`unselect_all` deliberately NOT added**, with
  a comment saying that adding it would fail a correct tree. That is the one place in this suite
  where the two primitives must be treated differently, and it is now written down.
* **Registerability**: added `set ::npass 0` / `incr ::npass` to its `check` proc and an
  `OVERALL: ok ($::npass checks)` line above the `RESULT:` line. It previously printed neither a
  pass count nor the sentinel `banner_complete` requires.

### `tests/headless/test_select_at.tcl` — a row repair, not a fence addition (see §6)

`log_flush` helper + SA5 and SA7b now flush the absorb buffer and search with `lsearch -glob`
instead of reading `lindex … end`. SA8b already did exactly this and is the model.

### `tests/run_regression.tcl` — `test_select_log_1620` in **both** lists, `test_selflog_grep_guard` in `hcases`

With a comment block for each explaining the arm choice, what each arm measures, and — for
grep_guard — that its S5 runtime canary does **not** run in the gate.

### `doc/claude/specs/action_logging.md` — new section **2b**

States the rule the measurement produced: **a core may self-log only if every one of its callers
is a user asking for that action**, with the 94-phantom-line number as the evidence, plus the
no-op and `dr`-canonicalisation properties and each fencing row.

---

## 2. The red, verbatim

**Written and run before any product change.** `tests/headless/run_suites.sh --nogui
test_select_log_1620` against the unfixed tree:

```
FAIL     | test_select_log_1620         run 1/1  RESULT: 12 FAILED (18 passed)
         | FAIL: G1 select_all()'s CORE self-logs (src/select.c, one site) -> {0} (exp {1}) : FAIL
         | FAIL: G4 scheduler.c logs unselect_all in BOTH arg forms (bare + canonical %d) -> {0} (exp {2}) : FAIL
         | FAIL: G5 the self-log inventory names select_all (S1 manifest) -> {0} (exp {1}) : FAIL
         | FAIL: G5 ...and unselect_all (S1 manifest) -> {0} (exp {1}) : FAIL
         | FAIL: G5 ...and both are in its S2 CVERBS conflict set -> {0} (exp {1}) : FAIL
         | FAIL: W1b the log records exactly one `xschem select_all` -> {0} (exp {1}) : FAIL
         | FAIL: W2b the log records exactly one `xschem unselect_all` -> {0} (exp {1}) : FAIL
         | FAIL: W5 `xschem unselect_all 0` records its argument verbatim -> {0} (exp {1}) : FAIL
         | FAIL: W6 two select_alls are two lines (the gate is emptiness, not change) -> {0} (exp {2}) : FAIL
         | FAIL: Z1c after the pop the very next unselect_all logs again -> {0} (exp {1}) : FAIL
         | FAIL: R0 the recording holds exactly the three selection lines -> {} (exp {{xschem select_all} {xschem unselect_all} {xschem select_all}}) : FAIL
         | FAIL: R2 EFFECT: the seam replay re-established the selection (2 wires) -> {0} (exp {1}) : FAIL
RESULT: 0/1 runs passed
```

**And the display arm, which is the red that matters most** — `RESULT: 13 FAILED (20 passed)`,
with the same twelve plus:

```
         | FAIL: K2 the interactive chord records exactly one `xschem select_all` -> {0} (exp {1}) : FAIL
```

⚠ **`K1` — the EFFECT row — PASSED in that same red run.** Ctrl-A really did move the selection
0 → 2 and really did log nothing. That pairing is the whole answer to trap 1: without `K1` a
reader could not tell "not logged" from "nothing happened", which is the mistake Stage R made.
The standalone probe that established it first:

```
lastsel0=0
lastsel_ctrla=2
=== LOG ===
# xschem action log
# launch: ./src/xschem --pipe -q --logdir …
# cwd: /home/analog/dev/xschem-claude
MARK ctrla lastsel=2
```

**No row threw.** The suite failed 12/13 times and printed its verdict; the `q {}` /
`RAISED(...)` wrapper and the `NO-LOG(child said: …)` sentinel exist for that.

One red row was **my** bug, not the tree's, and it is worth recording because it is a trap for
anyone testing a suppress scope: my first `Z1a` wrote its effect marker with
`xschem log_action -noecho` **inside** the suppress scope, where that call is itself suppressed —
so the row read "the select_all did not happen" on every tree, fixed or not. The mark now goes
after the pop.

## 3. The green, quoted

| arm | before (unfixed tree) | after |
|---|---|---|
| `test_select_log_1620` `--nogui` | `RESULT: 12 FAILED (18 passed)` | `RESULT: ALL PASS (31 checks)` |
| `test_select_log_1620` display `:99` | `RESULT: 13 FAILED (20 passed)` | `RESULT: ALL PASS (34 checks)` |
| `test_selflog_grep_guard` `--nogui` | `RESULT: ALL PASS` (no count, no sentinel) | `RESULT: ALL PASS (390 checks)` |
| `test_selflog_grep_guard` `--logdir` (S5 live) | `RESULT: ALL PASS` | `RESULT: ALL PASS (394 checks)` |
| `test_select_at` `--logdir` | `RESULT: ALL PASS` | `RESULT: ALL PASS` (after the repair in §6) |

Under T1's **exact** `hcases` invocation (`env -u DISPLAY ./src/xschem --nogui --pipe -q --script`):

```
OVERALL: ok (390 checks)          OVERALL: ok (30 checks)
RESULT: ALL PASS (390 checks)     RESULT: ALL PASS (30 checks)
```

Scored with the tree's **own** reader rather than with `run_suites.sh`:

```
t1_test_selflog_grep_guard.txt: banner_complete=1 banner_died=0 case_failed=0
t1_test_select_log_1620.txt:    banner_complete=1 banner_died=0 case_failed=0
```

Counted shapes (`(FAIL|GOLD\?|RESULT\?)$` or `^FATAL`) in both outputs: **0**.
Lowercase `^skip:` lines in both: **0**.

Final verification set, all green (`run_suites.sh --nogui`): `test_select_log_1620` 31,
`test_selflog_grep_guard` 390, `test_home_isolation` 116, `test_scratch_home_note` 22,
`test_issue_stamp` 102, `test_replay_door_1619` 63, `test_ciw_actionlog_output` 25,
`test_actionlog_suppress_gate`, `test_perform_action_delete`, `test_deselect_mode` 9 →
`RESULT: 10/10 runs passed`. Display arm: `test_select_log_1620` 34, `test_wave_viewer` 437,
`test_home_isolation` 116 → `3/3`. The `--logdir` arm (`full_audit.sh`'s `logdir_tests` spelling):
`test_select_at`, `test_selflog_grep_guard` 394, `test_delete_cut_selflog`,
`test_descend_goback_selflog`, `test_save_reload_copy_selflog`, `test_dblclick_connected_grow`,
`test_gesture_end_log`, `test_select_same_net_by_label`, `test_action_log_dispatch` — all
`ALL PASS`.

**C89.** `gcc -fsyntax-only -std=c89 -pedantic -Wall -Wdeclaration-after-statement` over the three
touched files gives **37 diagnostics, and ZERO of them on a line I touched** (measured by filtering
the diagnostic list to the diff's own line ranges: `select.c` 2556-2583, `scheduler.c` 14869-14900,
`callback.c` 7610-7620 — empty). The 37 are pre-existing `-Wcomment` / `-Wmisleading-indentation`
and one `-Wdeclaration-after-statement` at `scheduler.c:13576`, all outside my hunks.

## 4. The CA* band of `test_wave_viewer.tcl` — before and after (required)

| | before | after |
|---|---|---|
| `run_suites.sh test_wave_viewer` | `PASS \| test_wave_viewer run 1/1 RESULT: ALL PASS (437 checks)` | **identical** |
| direct on `:99` | `RESULT: ALL PASS (440 checks)` | **identical** |
| CA rows present | **30** | **30** |
| CA rows failing | **0** | **0** |
| `diff` of the CA band, before vs after | — | **byte-identical** (`CA band IDENTICAL to baseline`) |

The 30 rows are `CA0`×3, `CA1`×2, `CA2`×2, `CA3`, `CA4`×2, `CA5`×2, `CA6`, `CA9`×5, `CA7`×5,
`CA8`×2 and the fixture rows — matching issue 1617's own "+30 rows" figure exactly.

**Why 1617 could not be broken here:** the core self-log means the legacy Ctrl-A arm needed **no
code change at all**. I verified the canvas chord is not in the binding table before relying on
that — `/usr/bin/grep -n "DEV_KEY,'a'" src/callback.c` returns exactly two rows, both
`ACTX_OVER_GRAPH` (`graph.forward`), so there is no `dispatch_input_action` wrapper on the canvas
path to double-log and none to disturb. I did **not** read that off the shipped comment; issue
1617's own scouting error was doing precisely that.

## 5. What I sabotaged, and what reddened

Seven sabotages, each applied to the real product files, rebuilt, run on **both** arms, then
restored from a backup taken before the first one. Patches at `<scratch>/B-select/s*.py`,
transcripts at `<scratch>/B-select/sab_S*_{h,d}.txt`.

| # | the plausible wrong implementation | headless | display | caught by |
|---|---|---|---|---|
| **S1** | **the `actionlog_suppress` guard bypassed** — a hand-rolled `fprintf(actionlog_fp, …)` instead of `log_action` | 3 FAILED | 3 FAILED | `G1`, **`Z1b`** (`{1}` exp `{0}`), **`R2`** (`{2 0}` exp `{0 0}` — the seam replay re-logs, so the round trip is no longer idempotent) |
| **S2** | **log at the scheduler branch instead of the core** (the naive reading; what the PLAN's wording invites) | 2 FAILED | 3 FAILED | `G1`, `G3`; **and `K2` on the display arm only** — every `W*` row stayed green, which is exactly the point |
| **S3** | **`unselect_all` self-logs at its core** (the naive symmetric reading) | 10 FAILED | 10 FAILED | `G2`, `G4`, `W2b` (**95**, exp 1), `W3` (**94**, exp 0), `W5`×2, `Z1c` (95), `R0` (a 98-element list), `R2`×2 |
| **S4** | the `had_sel` no-op gate dropped from `unselect_all` | 1 FAILED | 1 FAILED | **`W3`** only |
| **S5** | the `lastsel` no-op gate dropped from `select_all` | 1 FAILED | 1 FAILED | **`W4`** only |
| **S6** | the `dr` argument dropped (always log the bare form) | 2 FAILED | 2 FAILED | **`W5`**×2 |
| **S7** | the Ctrl-A arm logs **too**, alongside the core (a double-log) | 1 FAILED | 2 FAILED | `G3`'s callback.c row; **and `K2`** (`{2}` exp `{1}`) on the display arm |

**Nothing survived.** Three points worth more than the table:

1. **S3 is the measurement that settles the stage's design question.** The naive core self-log put
   **94 phantom `xschem unselect_all` lines** into a child that drew two wires and deselected once,
   and `R0`'s expected-vs-got is a three-element list against a 98-element one. The lines come from
   startup and machinery paths, before the suite's own actions. No amount of reasoning about "87
   call sites" is as persuasive as that number, which is why it is now in the spec.
2. **S2 and S7 are the two the display arm earns its case for.** S2 leaves every scripted row green
   and breaks only the interactive path; S7 leaves every scripted row green and *doubles* the
   interactive one. A scripted-only fence would have passed both.
3. **`G3`'s second row exists because of S7.** My first version scanned only `scheduler.c`, so a
   double-log added in `callback.c` would have been caught by `K2` alone — a display-arm row. The
   added row scans `callback.c` too, and S7 now reddens headless as well. I wrote the row *because*
   I could see the gap, and then confirmed it by measuring.

## 6. What I got wrong, and what corrected me

1. **I shipped a real regression in `test_select_at` and only found it by widening the net.** The
   brief did not ask me to run that suite. I ran the whole action-log family on the `--logdir` arm
   because that is where log suites can actually measure, got `RESULT: 3 FAILED`, and — crucially —
   **did not assume it was pre-existing**. I bisected the binary: with `select.c` at HEAD and my
   `scheduler.c` change in, 3 FAILED; with **both** C files at HEAD, `ALL PASS`. So it was mine, and
   specifically the `unselect_all` log.

   **The mechanism is a trap for anyone adding a log line anywhere in this tree.** A `select_at`
   line is *not written when the verb returns* — it sits in the single-slot holding area
   (`actionlog_pending`, `doc/claude/specs/action_log_absorb.md`) so a following `descend` can absorb
   it, and it reaches the file only when the **next** `log_action` flushes it. Rows `SA5` and `SA7b`
   read the log immediately after a click, so what they actually read was the **previous** row's
   held line, flushed by the very stash under test. Giving `xschem unselect_all` a line of its own
   flushed that held line one step earlier and both rows went to `{}`. The product was right; the
   rows were reading one operation behind. `SA8b` in the same file already did it correctly — it
   flushes with `xschem set cadsnap $cadsnap` and searches with `lsearch -glob` — and its comment
   explains why. I lifted that into a `log_flush` helper and applied it to both rows.

   **I verified the repair on BOTH trees**, because a test fix that only works on the fixed tree is
   not a fix: with pristine HEAD C files the repaired suite is `ALL PASS` with
   `SA5 … (line={xschem select_at 100 0})`, and with my change in it is `ALL PASS` too.

   ⚠ **Generalisable warning for the next stage: adding any log line changes the FLUSH TIMING of
   the pending `select_at`, and any row that reads "the last line of the log" after a click is
   therefore fragile.** Nothing else in the tree does this, but the technique is the kind a future
   suite will reach for.

2. **The brief's and the PLAN's scope sentence is wrong for `unselect_all`, and following it
   literally would have wrecked the log.** *"Make both primitives self-log … guarded by
   `actionlog_suppress` exactly like every other self-logging core, plus whatever the legacy-switch
   arm needs"* reads as three symmetric edits. The correct answer is asymmetric (core / branch /
   nothing), and the cost of the symmetric one is measured in §5 as 94 phantom lines. The signal was
   in the tree all along — a shipped comment in `callback.c` says *"WHY NOT INSIDE unselect_all(): 87
   C call sites and 817 scripted ones, several inside netlisting"* — about a different change, but
   naming exactly this hazard.

3. **The legacy `switch (key)` arm needed no code at all**, which is the opposite of what the brief
   expected (*"plus whatever the legacy-switch arm needs so the interactive path logs too"*). The
   answer is "nothing", because the core covers it — and that is also the safest possible outcome
   for issue 1617, since the arm I was warned about is unmodified apart from a comment.

4. **Issue 1617's own decision D11 is wrong as a general statement, and I nearly let it stop me.**
   It says *"selection gestures are not logged in this product — only mutations are"*. That is true
   inside the waveform namespace (none of `wave_viewer.tcl`'s 24 `log_action` sites is a selection),
   and **false on the schematic canvas**: `select_grow_connected_step()` and `select_same_net_cmd()`
   in `src/select.c` both `log_action`, and `select_object()` stashes a `select_at`. So this stage
   does not contradict D11 — it operates in the other half of the product — but a reader taking D11
   as a product-wide rule would have refused the whole issue.

5. **`xschem wire <coords>` logs nothing**, which surprised me and then turned out to be useful: it
   means my fixture leaves the log containing only what the band under test puts there. It matches
   the recon's list of 11 silent scripted verbs, and Stage A had already found the same thing (its
   `L1` band uses `xschem copy` as the log canary for exactly this reason). I re-used that canary.

6. **`xschem get has_x` is not a key** (returns empty). Display detection in the suite uses
   `[llength [info commands winfo]] && ![catch {winfo exists .}]`, Stage A's spelling.

7. I assumed `test_selflog_output`'s six flip/rotate failures might be mine. They are **not**: with
   both C files pristine at HEAD the failure list is **byte-identical** (`diff` clean). Pre-existing,
   unregistered, not touched. Likewise `test_context_menu_log` times out at 200 s and dies with
   `FATAL: signal 15` on both trees.

## 7. What I did NOT do, and why

* **I did not create `doc/claude/issues/1620-*.md`.** The PLAN reserves issue files and their
  `**STAMP:**` lines for the driver. `tclsh tests/headless/issue_stamp.tcl`-equivalent coverage:
  `test_issue_stamp` is `ALL PASS (102 checks)` with my tree as it stands.
* **I did not add a menu entry, a keybinding or an `actions.csv` row for "Unselect all".** There is
  no `Unselect all` entry today (Edit has only `Select all`), so in the shipped default config the
  only interactive route to a logged deselect is a custom rc binding — which the `escape_deselects`
  comment in `src/xschem.tcl` already recommends. Adding one is new user-visible surface and needs
  the user's wording; it is not in this stage's scope and I did not file a `rule` for it (see §9.4).
* **I did not make ESC log.** `escape_deselects 1` deselects through `abort_operation(1)`, which has
  24 call sites in `callback.c` alone plus 9 more in C and 10 in Tcl and is explicitly **not**
  suppress-wrapped (a shipped comment says why: its `STARTPOLYGON` arm completes a polygon and
  self-logs a real edit). A log there is the same 87-call-site mistake one level up.
* **I did not make the incidental click-deselect log.** Every plain canvas click deselects before
  selecting (`if(!intuitive && no_shift_no_ctrl) unselect_all(1)`), and the click itself is already
  logged as `xschem select_at x y`, whose replay *replaces* the selection (row `SA2` of
  `test_select_at`: "default mode replaces selection"). So the deselect is implied by the line that
  is recorded; logging it too would put an `unselect_all` in front of nearly every `select_at`.
* **I did not register the other 27 replay round-trip suites** (D2). Two suites, named in §8.
* **I did not refactor `test_selflog_grep_guard`'s S5 runtime canary** to host its own `--logdir`
  child. That means registering it in `hcases` gates its **static scans only**: T1 passes no
  `--logdir`, so S5 takes its "skipped: no --logdir" arm — and that arm is written as a **passing
  check**, not a lowercase `skip:` line, so the verdict cannot say it did not run. Pre-existing,
  named in the registration comment and in that suite's verdict comment, deliberately not fixed
  here. See §9.3.
* **I did not add `test_select_log_1620` to `full_audit.sh`'s `logdir_tests`.** It does not need the
  parent's log: every log-observing row spawns its own child with `--logdir`. `full_audit.sh` globs
  `test_*.tcl`, so it runs the suite already.
* **I did not run a full T1** (the driver's job; a second run would invalidate the live one). I did
  not touch `/tmp/gd19`.
* **I did not repair the pre-existing reds I found** (`test_selflog_output`'s six flip/rotate rows,
  `test_context_menu_log`'s timeout). Both attributed to HEAD by measurement; neither is registered.
* **Unverified:** the `pin_sel_active` term of `had_sel`. It is there so that clearing a transient
  pin-only selection (which the core handles *outside* its `lastsel` gate) also records a line, and
  no row covers it — the pin-selection gesture is a Ctrl+click on an instance pin, which I did not
  build a fixture for. Removing the term would not redden anything. Stated rather than papered over.

## 8. Fence choice and the T1 case movement

**Two suites**, which is what the PLAN budgeted:

* **`tests/headless/test_select_log_1620.tcl` — NEW, `hcases` AND `dcases`.** A new suite rather
  than rows in an existing one, because the natural homes are all wrong: `test_select_at` is about
  the coordinate form and is **structurally unregisterable in T1** (its first row is `action log
  open`, and T1 passes `--logdir` on no arm — note it *does* already print `OVERALL: ok`, so the
  sentinel is not what blocks it); `test_selflog_output` is a pre-existing red; the 28
  `test_perform_action_*` suites are the per-verb round-trip family and this is not a
  `perform_action` verb. Both arms measure something real, and the display arm is the **only** place
  the interactive chord can be driven — sabotages S2 and S7 show it catching two wrong
  implementations that every headless row passes.
* **`tests/headless/test_selflog_grep_guard.tcl` — `hcases`.** I added fence rows to it, so
  CLAUDE.md's bounded rule obliges registering it in the same change. It is also the tree's own
  executable inventory of the self-log migration — its header records that *"we logged verb X, but
  only from the menu, not the key"* recurred three or more times **after** being named, because
  human discipline does not hold — and it gated nothing at all until now. `hcases` only: every row
  is a static scan plus one runtime canary, and none opens a window.

**Expected T1 movement: `109 → 112` cases, `108 → 111` blocks, `skips=` UNCHANGED at 8.**
Measured, not assumed: `HEAD hcases: 87`, `HEAD dcases: 18`, `tcases: 3` (+ `xschemtest`) = 109/108,
which matches the brief; my tree is `hcases: 89`, `dcases: 19` = 3 + 89 + 19 + 1 = **112 cases, 111
blocks**. Counted with `awk '/set hcases \[list/,/\]$/' … | /usr/bin/grep -o '"[^"]*"' | wc -l`, the
spelling CLAUDE.md prescribes.

**Zero `skip:` lines added**, verified on the real output rather than reasoned: both suites print
`0` lowercase `^skip:` lines on the T1 arm. `test_select_log_1620`'s only display-dependent rows
(`K1`/`K2`) self-skip with an **uppercase** `SKIPPED:`, which `summarize_all` neither counts nor
counts as a skip; `test_selflog_grep_guard` prints none at all. ⚠ Per CLAUDE.md, this would be the
fifteenth consecutive `skips=8` and it is still a coincidence of what is registered, not a property.

`wc -l` of the verdict will move by more than three lines: two new `Start`/`Total num fail:` pairs
plus **three** new `RESULT:` lines (each registered case's last `RESULT:` line is published), so do
not check it against an arithmetic figure.

## 9. What the next stage must know

1. **A CORE MAY SELF-LOG ONLY IF EVERY ONE OF ITS CALLERS IS A USER ASKING.** This is the reusable
   rule and it is now in `doc/claude/specs/action_logging.md` §2b with the 94-line measurement
   behind it. The recon's phrase *"guarded by `actionlog_suppress` like every other core"* is about
   the *suppress* mechanism (which `log_action` handles for you) and says nothing about *where* the
   call belongs; those are two different questions and only the second one is hard. Before adding a
   self-log to any C function, count its callers and ask what each one is.
2. **Adding a log line moves the `select_at` flush boundary.** §6.1. Any row that reads "the last
   line of the log" right after a click is measuring one operation behind. `log_flush` in
   `test_select_at.tcl` is the pattern.
3. **`test_selflog_grep_guard` is now in the gate, and the gate runs its STATIC scans only.** T1
   passes no `--logdir`, and S5's "no --logdir" arm is a *passing check* rather than a `skip:` line,
   so the verdict cannot report that it did not run. Making S5 host its own `--logdir` child is a
   clean, bounded follow-on and would turn a silent pass into a measurement. I did not do it (§7).
4. **Two user-visible gaps this stage deliberately leaves open**, neither filed as a `rule` because
   neither is a change I made and the user's queue is for decisions they must take:
   (a) there is **no Edit ▸ Unselect all** entry and no default chord, so the newly logged verb has
   no interactive door — the symmetric counterpart of exactly the problem Stage A fixed for replay;
   (b) `unselect_all`'s scheduler log means the ~10 *internal Tcl* callers (`hi_descend_current`,
   `descend_hierarchy`, `property_form.tcl`, the `Compare schematics` checkbutton, the pin-type
   fallback) each add a line to the log when they deselect a live selection. Those lines are
   faithful and replayable, and the no-op gate removes the ones where nothing was selected, but a
   log recorded during heavy hierarchy navigation is noisier than before. If that becomes a
   complaint, the fix is a suppress scope around those composites, not the removal of the log.
5. **`xschem wire <coords>` and `xschem select_at` behave very differently as fixtures.** `wire` is
   silent (the scripted replay form), which makes it the ideal fixture for a log test; `select_at`
   is *held*, which makes it a bad one. `xschem copy` is the cheap unconditional log canary and both
   Stage A and this stage use it.
6. **`test_select_at` prints `OVERALL: ok` already but still cannot be registered**, because T1 has
   no `--logdir` arm at all. If anyone wants the coordinate-select family gated, the missing piece
   is an arm, not a sentinel. Same for `test_selflog_output`, `test_delete_cut_selflog`,
   `test_descend_goback_selflog`, `test_gesture_end_log` and the rest of `logdir_tests`.
7. **Pre-existing reds I measured against pristine HEAD, so nobody re-pays for them:**
   `test_selflog_output` fails six rows (`key Shift-F logs flip`, `Alt-F flip_in_place`,
   `Shift-R rotate`, `Alt-R rotate_in_place`, `Shift-V flipv`, `Alt-V flipv_in_place`) —
   byte-identical list at HEAD; `test_context_menu_log` times out at 200 s and dies
   `FATAL: signal 15` with an emergency-save; `test_selflog_output` and `test_action_log_dispatch`
   are `NORESULT` on both `run_suites.sh` arms (they need the `--logdir` arm). None is registered,
   so none can redden a gate.
8. **Leftovers in the tree that are not mine:** `?? .xschem/` and
   `?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/` — both untracked before this
   stage started, as Stage A's receipt §8 also records.

## 10. `git status --short` — proof I changed only what I meant to

```
 M doc/claude/specs/action_logging.md
 M src/callback.c
 M src/scheduler.c
 M src/select.c
 M tests/headless/test_select_at.tcl
 M tests/headless/test_selflog_grep_guard.tcl
 M tests/run_regression.tcl
?? .xschem/
?? sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/debug_st1/
?? tests/headless/test_select_log_1620.tcl
```

Seven modified files, all named in §1; one new file, the suite; two untracked leftovers that
predate the stage (§9.8). **No tracked schematic, symbol or library file is touched** — every
fixture in this stage is two `xschem wire` calls in a throwaway child, and no probe in it calls
`save` or `saveas` at all, so decision D9's incident has no surface here. `git diff --stat`:
200 insertions, 8 deletions across the seven.

Sabotage bookkeeping: the three C files were restored from a pre-sabotage backup and rebuilt, and
`/usr/bin/grep -c "sabotage S"` over them returns `select.c:0 scheduler.c:0 callback.c:1` — the one
hit being a pre-existing comment about issue 0262's sabotage S7, unrelated.
