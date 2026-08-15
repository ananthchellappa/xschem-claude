# Item 14 — test_gui_gate_batch.sh leaks every panel it spawns, and its display with them

Verdict **[x]**. Base HEAD at close `0c104dac` (the item names 6ce8bf3d; five calculator commits landed between). No pixel payload — the deliverable is a process census, and a check can see it.

## 1. Files changed

```
 doc/claude/specs/dev_display.md 21 ++- | doc/claude/specs/gui_test_gate.md 189 ++++- | tests/headless/test_devdisplay.sh 91 ++-
 tests/headless/test_gui_gate_batch.sh 295 +++- | tests/headless/test_gui_gate_revive.sh 155 +++-   (5 files, 739 insertions(+), 12 deletions(-))
 tests/headless/spawn_reaper.sh 730 +++++ (new file)
```

## 2. Decisions, and the evidence for each

**The leak is reproduced, not inferred.** The pre-item file (`git show HEAD:…test_gui_gate_batch.sh`) on a display that OUTLIVES it: `RESULT fails=0`,
51 green checks, **5 live panels left behind**, control dirs `$TMP/{g1,g3,g4,g5,g6}` already deleted by the very `trap 'rm -rf "$TMP"' EXIT` that
spared them. On the old `xvfb-run` arm it only *looked* clean — the private server died and took its clients, incidental cleanup that evaporates in
exactly the case that produced the 21 strays.

**Four spawn sites** (item 1): gate panels `setsid wish gui_gate_widget.tcl <GATE_DIR>` from five throwaway control dirs via
`gate_start`→`_gate_ensure_widget` (deliberate — the suite tests the panel); three `widget_arm` `timeout 30 wish` (deliberate, self-exiting); the
brake's throwaway targets (already reaped); the private Xvfb of the `exec xvfb-run` re-exec. No WM. Only the third was reaped. **Identification is PID
REGISTRY + PROVENANCE, never a name** (item 3): `reaper_track` at the fork, plus any process whose command line names *this run's own* `mktemp -d`
root. `pkill -f gui_gate_widget.tcl` is rejected and caught — applied, R1/R2/R4 stay green and **R3 plus R11's negative control go red**.

**RULING — a panel may be swept when its orphanhood is a FACT ON DISK** (spec `gui_test_gate.md`, "Reaping contract" rule 6). A trap cannot cover a
SIGKILL, so the next run sweeps: dir under a temp root and **gone**, or dir present with a `.reaper_owner` stamp (pid + boot-unique start time, so a
recycled pid cannot lie) naming a **dead** run. `~/.claude/gui_test_gate` is excluded three times over — not under a temp root, it exists, no stamp;
and "no evidence" never means "kill it" (R11's second half). The driver's own criterion for the manual cleanup, automated.

**RULING — the gate self-tests start their OWN private Xvfb, not `exec xvfb-run`** (rule 5). Measured: xvfb-run's teardown is its own EXIT trap, and
its `clean_up` runs under `set -e` ending in `kill $XVFBPID`, so a session that correctly reaped its own server made xvfb-run exit 1 behind 57 green
checks. Careful teardown and an honest exit status could not both be had while xvfb-run owned the server.

**Item 4, both paths.** `reaper_own_xvfb` refuses `:0`, refuses whatever *either* devdisplay state file names, and refuses a server this run did not
start — the last holds when the first two are subverted. Probed live at close: `:0` → "the user's screen"; `:99` → "the persistent dev display", **and
still refused with `XSCHEM_DEVDISPLAY_DIR` redirected away** (the `$HOME` state file is now read unconditionally, because `test_devdisplay.sh` exports
exactly that redirection); `reaper_init` refuses `$HOME` and `/`. `reaper_sweep_orphan_xvfb` reclaims a dead run's private display and drops the stale
`/tmp/.X<n>-lock` that otherwise burns one of 60 numbers forever. X servers are identified **structurally** (argv[0] basename IS `Xvfb`, argv[1] IS
the display) — the substring version adopted, and TERM+KILLed, a plain `bash -c 'sleep 60; :' Xvfb :137`. Nothing may signal `$$` or an ancestor.

**Neighbours** (item 6). `test_gui_gate_revive.sh` — largely clean (`kill_panels` dir-scoped, G3b kills by pid), but a PENDING launch leaves no
`widget.pid`, so it got the reaper and an R arm. `test_devdisplay.sh` — clean, yet the exact shape of the leaked `Xvfb :95 1920x1080x24`+openbox pair
(devdisplay's defaults, no `-auth`, `:95` = `_free_num`'s second pick), so pid-tracked reaping + D16/D17. `xvfb_arm.sh` — **looked at, not changed**:
trap-covered only, still leaks under SIGKILL, and fixing it means dropping its `exec`, touching every armed suite in the tree.

## 3. Suites, check counts, verbatim RESULT lines

Run at close on `:99` (Xvfb pid 901342, openbox 901359 — the same pids before and after).

| suite | checks | verbatim RESULT |
|---|---|---|
| `test_gui_gate_batch.sh` | 66 | `RESULT fails=0` |
| `test_gui_gate_revive.sh` | 58 | `RESULT fails=5` |
| `test_devdisplay.sh` | 39 | `RESULT: ALL PASS (39 checks)` |
| `test_owed.sh` | 52 | `RESULT: ALL PASS (52 checks)` |
| `run_suites.sh test_calc_skeleton` | 503 | `RESULT: ALL PASS (503 checks)` / `RESULT: 1/1 runs passed` |

**Diff vs `00b-audit-baseline-2026-08-14.txt`, by name and status — NOTHING MOVED IN EITHER DIRECTION.** `test_calc_skeleton` PASS → PASS.
`test_owed`, `test_devdisplay`, `test_gui_gate_batch`, `test_gui_gate_revive` are **absent from the baseline** (it records the `.tcl` full_audit set;
three of these are `.sh`) — new, not regressions. `full_audit.sh` not run; the closing item owns it. `test_gui_gate_revive`'s 5 reds **predate this item, re-proved by the closer**: the unmodified `git show HEAD:` copy on the same display gives `RESULT fails=5`, 51 checks, the same five names
(X1 ×2, X2 ×3) — its `in_gate` hardcodes `DISPLAY=:99`, now the dev display, where `_gate_enabled` is false by design. One-word fix deliberately not
made: it changes 5 checks this item does not own.

**Census** (structural `/proc` scan; `pgrep -f` matches its own command line): before / immediately after all four suites / +30 s — panels **0 / 0 /
0**; X servers `:99` only; openbox 1; locks `.X99-lock` only. `:99` never restarted, stopped or signalled. `AUDIT_DISPLAY=:0` never used.

## 4. Sabotage table — one row per new check (26 new: 15 batch, 7 revive, 4 devdisplay)

| check | what was broken | red? | restored green? |
|---|---|---|---|
| batch R0 decoy panel is up | widget's `widget.pid` write disabled | yes (with R3, R10) | yes |
| batch R1 the run really left processes alive | `reaper_survivors` provenance scan `return 0` | yes, sole fail `(0)` | yes |
| batch R2 nothing this run started is alive | `_reaper_kill` `return 0` — every reap a no-op | yes `(got '5' want '0')` | yes |
| batch R3 the OTHER session's panel is untouched | `pkill -f 'gui_gate_widget[.]tcl'` prefix — THE FORBIDDEN FIX | yes; R1/R2/R4 green | yes |
| batch R4 still zero 3 s later | same no-op; and a re-appearing `lazyleak` fork, isolating R4 from R2 | yes | yes |
| batch R5 the private Xvfb is gone | `reaper_reap_xvfb` `return 0` | yes, sole fail | yes |
| batch R6 refuses `:0` | the `:0` refusal case deleted | yes, sole fail | yes |
| batch R7 refuses the dev display, state dir redirected | `$HOME` entry dropped from `_reaper_devdisplays` | yes, sole fail | yes |
| batch R8 `reaper_init` refuses `$HOME` | the refusing `*)` arm made `*) ;;` | yes, sole fail | yes |
| batch R9 an impostor naming `Xvfb :N` is not adopted | `_reaper_is_xvfb` restored to the substring form | yes, sole fail | yes |
| batch R10 decoy gone by the pid held at the fork | pidfile write disabled AND `reaper_track "$DPID"` removed | yes | yes |
| batch R11 dir SURVIVES but run is dead → swept | `gone\|dead)` narrowed to `gone)` — **closer re-ran it**: `RESULT fails=1`, sole fail | yes | yes, md5 `514fbb98…` |
| batch R11 a panel with no owner stamp is left alone | criterion widened to `gone\|dead\|unknown)` | yes, decoy died | yes |
| batch R12 a dead run's private display is reclaimed | `reaper_sweep_orphan_xvfb` `return 0` | yes, sole fail | yes |
| batch R12 the display this run is on still answers | the live-owner skip removed | yes `(:101) still answers` | yes |
| revive R0 decoy panel is up | pidfile write disabled | yes | yes |
| revive R1 the run really left processes alive | provenance scan disabled | yes `(1)` | yes |
| revive R2 nothing this run started is alive | `_reaper_kill` no-op | yes `(had 2)` — **closed coverage hole**, used to stay green | yes |
| revive R3 another session's panel untouched | `pkill -f` prefix | yes, only new fail | yes |
| revive R4 still zero 3 s later | `_reaper_kill` no-op | yes | yes |
| revive R5 the private Xvfb is gone | `reaper_reap_xvfb` `return 0` | yes, only new fail | yes |
| revive R10 decoy gone by its fork pid | pidfile off + `reaper_track` removed | yes | yes |
| devdisplay D16 the run started servers of its own | `reaper_track` `return 0` | yes `(0 tracked)`, sole fail | yes |
| devdisplay D16 nothing it started is alive | `kill -TERM $fpid` (D11's foreign Xvfb) → `:` | yes `{1} (exp {0})`, sole fail | yes |
| devdisplay D17 the sweep reclaims a dead run's server | `_reaper_kill "$p"` → `:` in `reaper_sweep_orphan_runs` | yes, sole fail | yes |
| devdisplay D17 leaves a CONCURRENT run's alone | the "provably dead" guard widened to any owner | yes `{0} (exp {1})`, sole fail | yes |

Every new check has a row. The closer independently re-ran batch R11 (byte-exact, md5-verified restore) and probed the five refusals live; the other
25 rows are the fixer's, run one at a time with verified reverts.

## 5. What was NOT verified

- **NOT RUN ON `:0`**, by policy — only `:0` runs the gate on a real screen, and R5's BORROWED branch was exercised only on a self-started `:151`.
  Ledger debts already recorded, not duplicated: `test_gui_gate_batch` ("FAILED on :0 — still owed"), `test_gui_gate_revive`, `test_devdisplay`. **No
  look debt — no pixels in this item.**
- **Two behaviours have no check.** (a) `_reaper_private_xvfb_teardown` drops `/tmp/.X<n>-lock` only when the kill succeeded (reviewer finding 8) —
  fixed, asserted by nothing. (b) The suites' `trap … EXIT/INT/TERM` **wiring**: the R arm calls `reaper_reap_procs` inline and measures after it, so
  deleting the trap line leaves all 66 checks green while every *aborted* run leaks again.
- **`xvfb_arm.sh` still leaks its Xvfb under SIGKILL** — read, not changed, no reproducer built; a reviewer could neither confirm nor refute it. **Pid
  reuse in the registry** likewise suspected and unproven: `reaper_reap_xvfb` re-checks identity in `/proc`, `_reaper_kill` does not, and `pid_max`
  4194304 made a wrap unforceable.
- **The forbidden-fix sabotage (R3) was not re-run by the closer** — it kills every panel on the machine, a concurrent agent's included; one reviewer
  refused it for the same reason, so it stands on the fixer's and verifier's evidence. **The sweep racing a concurrent run** (between another suite's
  `rm -rf $TMP` and its panels' death) was never constructed either, though two real bystander panels of a concurrent session survived every run in
  review.
- **Unstamped scratch dirs and unmarked X servers are never reclaimed** — by design (R11's negative control), so strays predating this change still
  need a human with a pid list. **Timing, not a defect**: the batch suite takes ~120–140 s (B5 waits out an interrupted fakesuite), so a 120 s tool
  timeout kills it mid-run and the exit looks self-inflicted.
