# S2c-R4 refute (safety): round 4 of Item 2 (crew r4v1)

**Verdict: NOT REFUTED on safety.** Nothing the harness killed or deleted was anything but
its own, and no documented command wrote under a canary home outside D13.2's scoped
exception and D9's bare-command exception, in any shape I ran. Every round-3 safety
recipe that refuted round 3 is now green on the round-4 code and still red on the base.
What I found beyond that is either identical in the committed base without Item 2
(`base0`) or a race window I read in the source and could not measure. Those are listed as
follow-ups.

Tags: **M** = measured, **R** = read from source, **I** = inferred.

## Setup (M)

| tree | what | build |
|---|---|---|
| `r4v1/fix` | main HEAD `32b6a9cd` + `r4b/r4.patch` (md5 `90ee1877…`) | rc 0 |
| `r4v1/base` | main HEAD `32b6a9cd`, which is round 3 committed | rc 0 |
| `r4v1/base0` | `32b6a9cd` with `r3b/final_item2_only.patch` reversed: HEAD without Item 2 | rc 0 |

* `fix` agrees with the builder's cumulative patch. All 33 files `final_item2_only.patch`
  touches (md5 `003df5ce…`) are byte-identical between `fix` and a clean `334dc0d5` with that
  patch applied (`r4v1/chk`).
* Every run used `tools/run.sh`:
  * `env -i`, with HOME = a seeded or EMPTY D11 canary;
  * a `find -printf` + md5 snapshot before and after, an inotify record, and a leftover scan.
* **Displays, all mine:**
  * `:190`, Xvfb + openbox, used as T1's DISPLAY;
  * `:192`, Xvfb + openbox with HOME=`r4v1/xhome2`, the victim display;
  * `DEVDISPLAY_NUM=193`;
  * `DEVDISPLAY_TEST_NUMS=194`, `FOREIGN=193`;
  * an xvfb-run shim that forces `-n 191 -a`.
* **Numbers the code under test chose:** T1's private arm took `:100` and `:101`, and
  test_home_isolation's fixtures took 150–169. `:99` was never started, probed or stopped.
* **A "zoo" of other people's things**, checked after every run (`tools/zoo.sh`):
  * 16 perl decoys, run under the names `Xvfb`, `openbox`, `env`, `x11vnc`, `xschem`,
    `wish gui_gate_widget.tcl` and `ngspice`;
  * among them, lookalikes carrying *another* `XSCHEM_TEST_T1_XVFB_TAG` and another
    `XSCHEM_TEST_XVFB_TAG`;
  * `/tmp/xschem-test-home.<live pid>.r4v1zooLive`: backdated to 2026-09-10, `.owner` naming
    a live pid, and `.xvfb.pid`/`wm.pid` naming decoys whose HOME is that dir;
  * `/tmp/devdisplay_test.r4v1zoo`, with a live `.reaper_owner`, naming decoys.

  **After every run below the zoo read `16 procs, 0 problems`.**

## Round-3 safety refuter's recipes (S2c_refute_r3.md), re-run

| # | recipe | fix | base / base0 |
|---|---|---|---|
| 1 | `devdisplay.sh stop` with a dead `xvfb.pid` and `wm.pid` = my live openbox on `:192` (M) | `not running (state cleaned)`; the openbox **alive** | both print `stopped :194` and **kill** it |
| 2 | stale `devdisplay_test.r4v1stale` (dead owner, display `:188`) naming my live `Xvfb :192` and its openbox, then the full `test_devdisplay.sh` (M) | ALL PASS (53); both **alive**; the stale dir removed | (builder: base killed both) |
| 3 | `winshot.sh shot.png -root` on EMPTY and seeded canaries (M) | canary identical, 0 events; the binary is in `tests/headless/.winshot-cache` | — |
| 4 | `xarm.sh one test_crossview_paste.tcl`, `suites …` and `mode`, EMPTY and seeded (M) | identical, 0 events, 0 processes, no panel. `one` OVERALL ok; `suites` 2/2 | — |
| 5 | G2's planted launchers (M, through T1) | G2 and G2b pass inside T1's `test_home_isolation` (116) | — |
| 6 | a custom HOME whose `.cache` links into the real home; one whose `simulations/{clean,short}.spice` are links (M) | refused: sh rc 2, Tcl rc 3; snapshot unchanged | — |
| 7 | a throwaway-shaped HOME directly under `/tmp` (live owner, `.xschem` → canary), in both languages (M) | `!! note … not reused`; a fresh arm; canary identical | — |
| 8 | D9 scope: `devdisplay.sh exec ./src/xschem --pipe -q --script test_crossview_paste.tcl` (M) | clipboard 103→201, geometry 5064→5300 | **base0 identical** (103→201, 5064→5300): F1 |

The round-1 and round-2 recipes, re-run on `fix` (M), all behave as round 3 recorded:
* **TMPDIR inside HOME** (sh, Tcl, relative TMPDIR, gated): only `./tmp` changes, and the
  note is printed.
* **`XSCHEM_TEST_HOME` = a symlink to the real home:** refused in both languages.
* **cwd = HOME holding `untitled~.sch`:** identical.
* **Relative TMPDIR with the cwd outside:** only `./tmp` appears in the cwd.
* **A throwaway forged inside HOME:** a note and a fresh arm, in both languages.
* **A custom `.xschem` or `simulations/` symlink:** refused in both languages.
* **`XSCHEM_TEST_HOME=real`**, red first: clipboard, `clean.spice`/`short.spice` and
  `.cache/openbox` change.
* **A dead throwaway under `/tmp` naming my live `Xvfb :192` and its openbox, backdated,
  in both languages:** swept, while my server, its WM and its lock were all spared.

## Documented commands on round 4 (M)

| run | result | canary / others |
|---|---|---|
| **T1**, a concurrent seeded + EMPTY pair (`cd tests && tclsh run_regression.tcl`, DISPLAY `:190`), alongside r4v2's two T1s | both `cases=87 blocks=86 counted_failures=0`, 720 s and 702 s; private `:100` and `:101`; test_home_isolation 116, `_sh` ALL PASS, 1476 0 fail | both byte-identical, 0 events; own throwaways deleted; leftovers = only r4v2's processes; zoo intact |
| **kill -9 of one of two concurrent T1 driver copies** in the middle of its display arm | the killed run's Xvfb `:101` and openbox are gone (the reaper); the other copy's `:100` survives and it ends with 0 counted failures | the dead throwaway is swept by the next arm after 300 s; nothing else touched |
| `run_suites.sh` private path, kill -9 at 0.3, 1.2 and 2.5 s | nothing of the run left | zoo intact |
| `test_devdisplay.sh`, TMPDIR=/tmp, zoo alive | ALL PASS (53) | the zoo's live `devdisplay_test` dir untouched |
| the same, plus decoys `Xvfb … :193`, `openbox` DISPLAY=:194, `x11vnc -display :194` (its own numbers) | ALL PASS (53) | all 3 decoys alive |
| devdisplay lifecycle on `:193` with a canary state dir: start, status, view, exec, stop | `stop` killed exactly its Xvfb, openbox and x11vnc | zoo intact |
| T1 driver copy, AUTO-START (dev canary) | pre-switch HOME, 0 `XSCHEM_TEST_*` in the server and WM; `devdisplay.sh stop` then kills both | only D13.2 files and `.cache/openbox` changed |
| two T1 copies auto-starting one state dir at once | both say `started`; `wm.pid` records the second, exiting, openbox | no leak after `stop` (openbox exits with its server) |
| T1 copy with `XSCHEM_TEST_HOME=<custom>` | a private arm; the run dir deleted | custom dir byte-identical |
| `tclsh tests/run_regression.tcl` from the repo root | rc 1, fix and base0 alike | EMPTY canary untouched |
| `tools/migrate/test_ase_migrate.py`, EMPTY and seeded | ALL PASS (151) | identical |
| **full_audit.sh**, EMPTY canary, cwd outside | `SUMMARY: 392 pass 11 fail 0 crash/timeout 2 skip (total 405)`, the same tally as round 3's prover; WIREEDIT PASS, SCRATCH 0, TREE 0/0; 1029 s | EMPTY canary still empty, 0 events, 0 processes left, its throwaway deleted, zoo intact |

## Follow-ups (not blocking: each is either identical in base0 or not measured)

* **F1 (M, identical in base0). D9's exception has a second documented spelling.**
  `devdisplay.sh exec ./src/xschem --pipe -q --script …`, which CLAUDE.md documents, writes
  the real clipboard and geometry: 103→201 and 5064→5300 on fix and on base0 alike. The
  done-claim's D9 exception should name it, as round 3's refuter already asked.
* **F2 (M, opt-out, base0 the same).** `XSCHEM_TEST_HOME=real` through `run_suites.sh` writes
  the real `~/.cache/openbox`: xvfb_arm's private openbox keeps the real HOME. T1's arm
  deliberately gives its openbox the run dir, *including under =real*. The two arms
  disagree.
* **F3 (M, identical in base0). `devdisplay.sh view --stop` has no "no server, no kills"
  gate.** With a dead `xvfb.pid` and `vnc.pid` = my live `x11vnc -display :194` decoy, both
  fix and base0 killed it and printed `viewer stopped (:194 still running)`. D20.1 closed this
  for `stop`, but not for its sibling.
* **F4 (R/I). Lock removal is check-then-remove in four places:**
  * the T1 reaper's phase 3 (`lk=…; … rm -f /tmp/.X$n-lock`);
  * `t1_home_kill_xvfb`;
  * devdisplay's `_rm_lock_if_names`;
  * test_devdisplay's D18/D19 lock plant (`[ ! -e ] && printf >`).

  A server that takes the number between the read and the `rm` (or the write) loses its
  lock. The window is milliseconds, and I did not measure it.
* **F5 (M, identical in base0). The orphan sweep cannot tell a live run in another pid
  namespace from a dead one.** spawn_reaper's `_reaper_owner_state` only asks whether that
  pid is alive here, unlike test_home's D13.6. Measured: a `devdisplay_test.*` dir whose
  `.reaper_owner` names a LIVE host `sleep`, swept by `reaper_sweep_orphan_runs` from
  inside `bwrap --unshare-pid`, was `rm -rf`'d, on fix and on base0 alike. So a concurrent
  `test_devdisplay.sh` in a container that shares TMPDIR loses its state dir. Its kills stay
  safe, because the recorded pids are ns-local and fail the argv[0]/display checks. By
  contrast, the throwaway sweeps got it right (M): a live `bwrap --unshare-pid` run's
  throwaway, backdated 1000 s, survived both host sweeps.
* **F6 (I).** Several cleanups kill by a started pid with no identity re-check:
  * `stop_pid` over `::started`;
  * test_devdisplay's `kill -9 $DECOYS $SWEEPPIDS` at exit, including pids a row already
    killed;
  * `_sh`'s `kill_all`.

  This is only theoretical here. Measured: about 590 pids/s against a `pid_max` of 4194304,
  so the pid counter takes about 2 h to wrap.
* **F7 (M, harmless).** Two T1s auto-starting one state dir record a dead `wm.pid`, as in
  the table above.

## Real home (M)
* **Marker:** `/var/tmp/xschem_fixes/r4v1s/marker_start`.
* **Manifest:** `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave rc 0 at the start, at
  mid-stage and at the end.
* **Find:** `find ~/.xschem ~/.claude/xschem_dev_display ~/.claude/gui_test_gate
  ~/.claude/xschem_owed ~/.cache -newer <marker>` printed nothing, at mid-stage and at the
  end.
* **No interactive xschem:** the newest `/tmp/Xschem.log*` is still `.4`.
* **HOME:** every command ran under `env -i` with HOME = a canary under `r4v1/canaries`.
  `XSCHEM_OWED_DIR` pointed into the canary. The real state dir was never passed to
  anything.
* **Kills:** only by pid, after checking `/proc` environ for my tag:
  * my fixtures `:190` and `:192`;
  * my decoys (`R4V1_DEC`, `R4V1_ZOO`);
  * my `full_audit` (the first, 8-minute attempt, stopped by its `timeout` pid; it was then
    re-run to completion).
* **No pkill.** Nothing was written in `~/dev/xschem-op-wcard`. The main tree was only read,
  apart from this receipt.
* **A deviation:** one decoy test first captured `setsid`'s pid instead of perl's, because
  the tool shell has job control. The decoys were found by their environ tag and killed,
  and the test was redone with a script (all 3 decoys alive).

Scratch for the driver to delete: `/var/tmp/xschem_fixes/r4v1` (trees fix, base, base0, chk;
canaries, runs, drv, aux, tools) and `/var/tmp/xschem_fixes/r4v1s`.
