# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The why behind these rules (measurements, incidents, dated corrections) is in
`doc/claude/claude_md_history.md`, this file verbatim at `a7d0876d` before it was
condensed; where the two differ, this file wins. A bare `D<n>` means a decision in
`doc/claude/outsider_fixes_batch/DECISIONS.md`; "row X" is a check in a suite.

## What this is

XSCHEM is a hierarchical schematic capture and netlisting EDA tool for VLSI/analog
custom design. It draws schematics and symbols and generates SPICE, Spectre, VHDL,
Verilog and tEDAx netlists. The drawing engine is plain C on top of Xlib primitives
(optionally Cairo for text/anti-aliasing); the GUI and the extension/scripting
language are Tcl/Tk.

## Build & run

```sh
./configure          # wraps scconfig; run from repo root. See ./configure --help
make                 # builds src/, xschem_library/, doc/, src/utile/
make install         # installs (honors DESTDIR=/tmp/pkg and PREFIX)
cd src && ./xschem   # run directly from the source tree, no install needed
```

- Build is **scconfig**-based (a self-contained ./configure system under `scconfig/`),
  not autotools. `configure` regenerates `Makefile.conf` and `config.h` from the
  `.in` templates — edit the `.in` files, not the generated ones (they carry a
  "DO NOT EDIT" header).
- Requires a C89 compiler, awk (mawk/gawk), Tcl/Tk 8.4–8.6, Xlib, Xpm, bison, flex.
  Optional: cairo, xcb, xrender.
- `src/Makefile` lists object files explicitly in `OBJ` — adding a new `.c` file
  means adding it to `OBJ` and adding an explicit compile rule (or regenerate from
  `Makefile.in`).
- A `CMakeLists.txt` exists as an alternative build but the Makefile path is canonical.
- **Editing `src/Makefile.in` obliges you to re-run `./configure`.** `src/Makefile`
  and `config.h` are generated and gitignored with no self-regeneration rule, so `make`
  never notices a stale `Makefile`. In-tree the miss is invisible (`XSCHEM_SHAREDIR`
  resolves to `src/`); installed, `xschem.tcl` sources a file `make install` never
  shipped and the binary segfaults at startup (exit 139; issues 0423, 0424). Verify with
  `/usr/bin/grep -c <newfile> src/Makefile`: expect 2, an install and an uninstall line.
- Concurrent `make` is unmeasured; nothing here declares it safe.

### Generated parsers (do not hand-edit the .c)
- `expandlabel.c`/`expandlabel.h` ← bison from `expandlabel.y` (bus/label expansion)
- `eval_expr.c` ← bison from `eval_expr.y`, prefix `kk` (expression evaluator)
- `parselabel.c` ← flex from `parselabel.l`

## Tests

Regression tests live in `tests/` and are driven by Tcl, comparing generated output
against golden files.

```sh
cd tests
tclsh run_regression.tcl        # T1: all cases (tcases, headless, display arm, xschemtest)
```

### Running T1 and single cases
- Each case is a `<name>.tcl` script that `run_regression.tcl` execs and scores into
  `results.log`. Run one case by sourcing it directly: `cd tests && tclsh open_close.tcl`.
- **Run T1 from `tests/`, never as `tclsh tests/run_regression.tcl` from the repo
  root**: that exits 1 without running (the nonzero exit says it never ran) and leaves
  the previous `results.log`, whose `T1-RUN-BEGIN` pid and start time give it away.
- **Your run's answer is `tests/results.<pid>.log`, not `results.log`.** Each run copies
  (never renames) its own onto `results.log` at the end, so that holds whichever run
  finished last. Case logs `<name>.<pid><suffix>` are published to `<name>.log` once
  scored, case output `<case>/results.<pid>` (scratch in `<case>/.work.<pid>`) to
  `<case>/results` at the end. A case run by hand keeps its plain log name
  (`open_close.log`): the pid tag rides in `T1_LOG_TAG`, and unset means the plain name.
- `tests/test_utility.tcl` resolves the binary as **`$XSCHEM` → in-tree `src/xschem` →
  `PATH`** (issue 0147) and runs it headless (`--pipe -q --script <file>`).
- **Always give the binary a path** (`./src/xschem`, `$XSCHEM`, `devdisplay.sh exec
  ./src/xschem`), never a bare `xschem`, which is not this tree. None was on PATH when
  checked (2026-09-17), so `command not found` in a transcript is not a broken harness;
  but one `make install` puts one back, and a build older than issue 0119 rewrites
  `~/.xschem/recent_files` despite `--pipe`/`--nogui`/`--norecent` (issue 0924). Test
  runs contain that with their throwaway HOME; a bare `xschem` at your prompt is not
  contained.
- **`create_save`, `open_close` and `netlisting` have no committed `gold/` baseline**:
  they report `NOGOLD` and verify nothing. Trust the headless cases
  (`tests/headless/gold/`), run as `tests/headless/run_suites.sh --nogui <t>` (drop
  `--nogui` for the display arm), which also echoes each `skip:` line under its verdict.
  The bare `./src/xschem` spelling works but is unarmed (see the throwaway test home).

### Reading `results.log`
- **It is the only place the answer is.** Stdout carries progress and notices, never the
  verdict; a run that completes exits 0, pass or fail, and none is refused or exits 2
  for a live peer. The exit code never says what a run found or whether it finished
  (the repo-root spelling above excepted). Name every case whose `Total num fail:` isn't 0.
- **Counted lines** (`summarize_all`): ending `FAIL`, `GOLD?` or `RESULT?`, or starting
  `FATAL`.
- **Uncounted lines** (`summarize_all`): `NOGOLD`/`NODISPLAY` — the case verified nothing —
  and, since issue **1487**, every `skip:` line a case printed plus that case's last
  `RESULT:` line with its check count, both inside that case's own block. A `skip:` names a
  row that did **not** run and is never a failure. ⚠ **`counted_failures=0` is a claim about
  correctness, not about coverage**: read `skips=` with it, and `/usr/bin/grep -n '^skip:'`
  the verdict for the names. Before 1487 the verdict was the one file that could not say what
  had not been measured — the stage-F gate at `7a46275f` carried **8 `skip:` lines in its case
  logs and 0 in its verdict**, with `test_ase_converge_1459` reporting 70 checks where a home
  holding the fork ngspice gets 76. The counted arm is still tested **first**, so a `skip:`
  line whose reason happens to end in `FAIL` scores exactly as it did before (rows `V5a`–`V5f`,
  `test_regression_concurrency_1476.tcl`).
- **Read the trailer first**: `T1-RUN-BEGIN pid= script= start= planned_cases= verdict=
  home= binary= canonical=` (line-buffered; survives a kill) and `T1-RUN-END pid= cases=
  blocks= counted_failures= skips= elapsed= end=`. `home=` is `throwaway`, `real` or `custom`;
  `binary=` is the path `auto_execok` resolved (a PATH fallback shows). Both are
  sanitised (whitespace replaced, `T1-RUN-` → `T1_RUN_`) and precede `canonical=`, which
  stays last, so no value can end the header in a counted shape or plant a fake sentinel
  (D6, D13.10, D13.17); neither sentinel matches a counted shape (row `V4a`,
  `test_regression_concurrency_1476.tcl`). **No `T1-RUN-END` means the run did not
  finish**, whatever the contents; an unfamiliar pid or start time is someone else's run
  or a fossil.
- **Every prefix of a green run is green** (counted shapes need a line to exist): a run
  killed mid-write (an outer `timeout` on the driver, any kill) can score zero (row
  `V3c`). The missing `T1-RUN-END` exposes it, as does a block count short of cases − 1.
  A per-case `T1_CASE_TIMEOUT` is instead scored as a counted `FAIL`.
- **A stale file**: its header's pid and start time identify it; also check the mtime
  moved off its pre-run value, and treat an empty log after a run as a death, never a
  zero. Don't hash it: pids and timestamps make every md5 differ.
- `couldn't execute "xschem"` or `exit 127` anywhere: the binary never launched and
  nothing in that run is meaningful (issue 0016 Part 4 separates it from the benign
  rc=10 fall-through).
- **Cases, blocks and lines are three different numbers**; take `cases=`, `blocks=`,
  `counted_failures=` and `skips=` from `T1-RUN-END`. Cases = `Start` lines; blocks = `Total num
  fail:` lines = cases − 1 on a green run (`xschemtest.tcl` writes one only on failure);
  `wc -l` moves with the failure count — and, since issue **1487**, with the number of `skip:`
  and `RESULT:` lines the cases emitted — so never check it against an arithmetic figure.
  At `7a46275f`: 87 cases (3 `tcases` + 72 `hcases` + 11 `dcases` + `xschemtest`), 86
  blocks, `wc -l` 177 green, 185 with eight failures, on the **pre-1487** driver. Read off
  the gate verdict `tests/results.344048.log`, taken in a throwaway clone of `949cc585`
  built from scratch, where `test_input_line_inject_1352`, `test_preview_name_inject_1601`
  and `test_generator_paren_1604` are each registered in **both** lists: **94 cases**
  (3 + 76 + 14 + `xschemtest`), **93 blocks**, **`wc -l` 281 green** (`2` sentinels + `93`
  headers + `93` `Total num fail:` + `3` NOGOLD + **`8` `skip:`** + **`80` `RESULT:`** +
  **`2` banner-only counts**; trailer `cases=94 blocks=93 counted_failures=0 skips=8
  elapsed=579s`). **Four figures in three days**: `88/87/skips=5` (`results.2325750.log`,
  the 1487+1486 fixes), `90/89/skips=6` (`results.2825611.log`, 1352), `92/91/skips=7`
  (`results.3482374.log`, 1601) and `94/93/skips=8` here (1604) — **each step is two cases
  and one skip, from one commit**, because a suite registered in both lists costs two cases
  and reports one headless self-skip. Anyone checking against a figure written down
  anywhere, this file included, would have called three green runs red this week. Read the
  trailer. ⚠ Both new terms are
  **environment-dependent** — a home that cannot reach the fork ngspice adds three more
  `skip:` lines — so this figure is even less of a constant than it was. To count a list, find `set hcases
  [list` (not a line number) and pipe it through `/usr/bin/grep -o '"[^"]*"' | wc -l`;
  `grep -c '"headless/'` and `grep -cE '\.log$'` (it matches `canonical=results.log`)
  miscount.
- **`Start`/`Finish` do not pair when the display arm cannot run.** Without a live dev
  display T1 runs the `dcases` on a private Xvfb from `:100` (D8). With no Xvfb (an
  uncounted `NODISPLAY:` per case) or one that won't start (a counted `HARNESS: <dc>
  display arm NOT RUN -- … : FAIL`), the `dcases` loop skips `Finish`. Count `Start`
  lines, or read `cases=`.

### Concurrent T1 runs
- **Two runs in one tree both proceed**; a live peer is announced (`another regression
  run is live in this tree (pid: …)`), so **zero such lines in your run's output is
  positive evidence it ran solo.** This exists so no crew is turned away, not for speed.
- The lock is only a publish mutex around the final copy. Knobs: `T1_LOG_LOCK_WAIT`
  (60 s), `T1_LOG_LOCK_TTL` (300 s), `T1_VERDICT_KEEP` (86400 s; sweeps dead runs'
  `results.<pid>.log`, never one whose `/proc/<pid>` exists). A stale lock is broken
  only on evidence (owner pid gone, or `/proc/<pid>/cmdline` no longer the script); one
  that can be neither taken nor broken lets the run proceed UNLOCKED with a warning.
- **Diagnose a T1 red by case, never by count.** A red can be a flake
  (`test_ase_optier_0963` has reddened solo, cause unexplained) or a real collision (a
  suite hand-run while T1 was live has reddened a gate run). Shared globals beyond
  `/tmp/xschem_emergencysave_*` are unswept.
- A T1 number taken before 2026-09-17 while another run was live is not evidence (runs
  then corrupted each other; `exit -1`, which no xschem writes, is the tell). A batch
  driver that serialises its crews is making its own scheduling choice, not the harness's.
- **Do not serialise on memory, or blame it for a short verdict** (15.35 GiB RAM + 4 GiB
  swap, measured 2026-09-17; concurrent T1s add no measurable peak; no OOM kill is
  recorded). "~7.8 GB" is a fossil this file overrides, also in briefs from
  `doc/claude/ledger/{crew,crew_annotate,crew_opfix}.js` and
  `doc/claude/op_param_batch/item_pipeline.js`; leave dated records carrying it
  (ledgers, session prompts, issue files) unedited, or you falsify the record.
- **Match shared namespaces by identity, never by pattern or count.** Never ask
  `pgrep -af run_regression` whether a run is live (`-f` matches your own shell). Like
  `t1_live_runs`, count a `results.<pid>.log` as live only if `/proc/<pid>` exists; or
  bracket a character (`'run_[r]egression'`), or match `ps -eo comm=`. Already written
  up (Lesson 5 of `doc/claude/code_analysis/gui_test_gate_tutorial.md`, and two
  others): file nothing new.

### Harness rules
- **No test harness builds.** `full_audit.sh` and every suite run `$REPO/src/xschem` as
  found, so a stale binary (e.g. after `git stash` → build → `git stash pop`) gives a
  plausible audit with wrong answers. **Rebuild before any audit meant as evidence**; on
  an unexpected red, check the binary before the code (`make -C src` recompiling
  everything means a header moved).
- **T1's baseline is ZERO counted failures.** A standing red is a defect, not
  furniture: if T1 is not at zero, say which case and why, per case; never carry a count
  forward. **Since 2026-09-22 the zero holds on BOTH display arms**, measured in a
  throwaway clone of `2bf05781`: `DISPLAY=:99` gives `cases=95 blocks=94
  counted_failures=0 skips=8` (`results.598045.log`) and `DISPLAY` **unset** gives the same
  (`results.658534.log`). Before that, four suites segfaulted with `DISPLAY` unset (issue
  1483, then 1492/1493), which is why every earlier figure in this file is a `DISPLAY`-set
  one. That class is closed at every site the headless-crashes batch could measure — and
  its receipts name the four blind spots its methods had, so "closed" means "closed where
  anyone has looked". **Green is per case, and coverage is a second number**: since issue 1487 the
  verdict carries each case's `skip:` lines and check count and the trailer states
  `skips=`, so read `counted_failures=0 skips=N` together — N > 0 means rows that did not
  run, named in the blocks. Measured 2026-09-22 in a throwaway clone of `949cc585`:
  `cases=94 blocks=93 counted_failures=0 skips=8` — five are `test_op_annot`'s display-only
  rows on the headless arm; the other three belong to `test_input_line_inject_1352`,
  `test_preview_name_inject_1601` and `test_generator_paren_1604`, which self-skip their
  behavioural rows there because all three drive real Tk dialogs and neither `toplevel`,
  `winfo`, `bind` nor `event generate` exists under `--nogui`. ⚠ **`skips=` is not a constant to check
  against**: a suite registered in both lists reports its skip on one arm and its rows on the
  other, so the number moves with what is registered, not only with the environment.
- **The banner rule lives in `tests/banner_rule.tcl`** (`banner_complete`,
  `banner_died`, `regression_case_failed`); `run_suites.sh` and `full_audit.sh` keep
  their own EREs (`/bin/sh` can't source Tcl), locked to it by section K of
  `tests/headless/test_audit_classifier.tcl`, except `full_audit.sh`'s prefix-anchored
  pass arm (issue 0805). A case passes only on **exit 0 AND a whole-line completion
  banner AND no column-0 death marker** (`--nogui --pipe` exits 0 on an uncaught Tcl
  error).
- `tests/xschemtest.tcl` is a broader functional/perf harness: from the repo root
  `./src/xschem --script tests/xschemtest.tcl`, then call `xschemtest`; `-d 3 -l log`
  logs allocations for leak checking. Run by hand it uses your real HOME and prints no
  note saying so.

### The throwaway test home (`t1_arm_home`, `tests/headless/test_home.sh`)
Every test driver (T1, each tcase run alone, the launchers below) runs with `HOME` set to
a fresh `${TMPDIR:-/tmp}/xschem-test-home.<pid>.XXXXXX`, deleted at exit by its creator,
sparing your clipboard, `~/.xschem/simulations` netlists and geometry.

* **Armed** (one `test home: throwaway … (your HOME is untouched; …)` line per run): T1
  and each tcase run alone with `tclsh` (`t1_arm_home`, on sourcing
  `tests/test_utility.tcl`); `run_suites.sh`, `full_audit.sh`, `gated_xschem.sh`, the
  standalone `test_*.sh` (via `xvfb_arm.sh --arm`), `test_devdisplay.sh`, each shell
  debt `owed.sh drain` runs, `run.sh`, `run_nogui.sh`, `lookshot.sh`,
  `tests/netlist_diff/netlist_diff.sh`, `tests/headless/wireedit/run_wireedit.sh`,
  `doc/claude/signal_browser_2pane_batch/xarm.sh`, `tools/migrate/test_ase_migrate.py`
  (`winshot.sh` builds into the gitignored `tests/headless/.winshot-cache/`). A nested
  driver reuses its parent's throwaway; only the owner deletes it.
* **Not armed:** the bare `./src/xschem … --script tests/headless/<t>.tcl` (D9: it keeps
  your real HOME; the `scratch.tcl` suites print a `note:` naming the armed spelling,
  other suites print nothing) and a hand-run `xschemtest.tcl`. **The armed spelling is
  `tests/headless/run_suites.sh [--nogui] <t>`.**
* **Enforced:** row **G2** of `test_home_isolation.tcl` (a T1 case) fails on any script
  that starts xschem (directly, via a variable, a PATH lookup or a Python/Tcl launcher)
  unless it is armed, runs inside xschem, or is on the path-keyed allowlist with a
  reason; a stale allowlist entry fails too. **A new launcher reddens T1 until you arm
  it** (`. test_home.sh; test_home_arm`, or source `test_utility.tcl`). G2 is textual;
  row **G2b** measures its blind spots.

| variable | meaning |
|---|---|
| `XSCHEM_TEST_HOME=real` | opt out: your real HOME, a loud `!! test home: REAL` banner on **every** run, header `home=real` |
| `XSCHEM_TEST_HOME=<abs dir>` | use that directory, never delete it (`home=custom`); refused if it resolves (symlinks included) to your real HOME, or its `.xschem` (two levels deep), `.cache` or `.claude` leads into it |
| `XSCHEM_TEST_KEEP_HOME=1` | keep the throwaway and print its path; `.keep` is written at arm time, so a killed run's is kept too |
| `XSCHEM_TEST_REAL_HOME` | **set by the arm**: your real HOME, for **read-only** fixture lookups (`test_real_home` in `scratch.tcl`: the fork ngspice, VCD fixtures, `test_launch_context`'s geometry); a row that finds nothing prints `skip:`, never a silent pass |

**What your real HOME still sees (D13.2):** the dev display itself, which writes
`~/.claude/xschem_dev_display` and `~/.cache/openbox` whether started by hand
(`devdisplay.sh start`) or by T1 (which attaches to or auto-starts it only if that state
dir exists), as a persistent display must outlive the run; likewise an existing
`~/.claude/gui_test_gate`. Neither is created for someone who lacks it (T1 then uses a
private Xvfb from `:100` and removes it). A `TMPDIR` inside your HOME puts the throwaway
there, and the banner says so instead of "untouched". Rules and reasons: D4–D20.

### The persistent dev display (`tests/headless/devdisplay.sh`)
Keeps GUI testing off your screen. A bare `./src/xschem --pipe -q --script
tests/headless/<t>.tcl` lands on it only if it inherits `DISPLAY=:99` (option 1 below).

```sh
tests/headless/devdisplay.sh start     # Xvfb :99 + openbox, ~0.3 s, idempotent
tests/headless/devdisplay.sh view      # x11vnc on localhost, to watch it
tests/headless/devdisplay.sh status|stop
```

- **The human does NOT want `DISPLAY=:99` in their interactive shell** (nor in
  `~/.bashrc`): a person launching xschem is launching it to use it. The armed drivers
  need nothing.
- For the assistant's own bare invocations: (1) **launch the session as `DISPLAY=:99
  claude`** (tool shells inherit it, the human's terminals don't; `~/.bashrc` can't,
  as it returns early for the non-interactive Bash tool shell); else (2)
  `tests/headless/devdisplay.sh exec ./src/xschem …`. **Only `run_suites.sh [--nogui]
  <t>` also arms HOME**: (1) and `devdisplay.sh exec` (which pins only `DISPLAY` and
  `GUI_GATE=0`) still write your clipboard, geometry and `simulations/`, so prefer it.
- `devdisplay.sh shellinit` is only for a terminal dedicated to hand-run tests; its
  export is conditional, as an unconditional one outlives the display (GUI programs then
  die with `cannot open display`). **The display does not survive a reboot**; re-run
  `start`.
- **`test_wave_markers` times out when `run_suites.sh` attaches to a dev display**
  (issue 1488, pre-existing): with `:99` up that `TIMEOUT` is not your change. It passes
  on the private `xvfb-run` display (dev display down); no knob goes private while
  `:99` is up.

### There are three X servers here, and `:0` is not the user's screen

| display | vendor string | what it is |
|---|---|---|
| `:0` | `Microsoft Corporation` | **Xwayland**, WSLg's own server |
| `$DISPLAY` = `<win-ip>:0` | `HC-Consult` | the **Windows X server** the user actually looks at, over TCP |
| `:99` | `The X.Org Foundation` | Xvfb, the persistent dev display |

- `$DISPLAY` comes from `~/.profile` (`export DISPLAY="$WINDOWS_IP:0"`); `~/.bashrc`
  would reset it to `:0` (`WAYLAND_DISPLAY` is set) but returns early for
  non-interactive shells, so tool shells keep the TCP display and interactive terminals
  may not. **Check `$DISPLAY`; don't assume.**
- **`AUDIT_DISPLAY=:0` exports the literal string `:0`**, not `$DISPLAY`: a `:0` figure
  taken through it, and every "run the suite on `:0`", means Xwayland. A **bare**
  `./src/xschem --script …` inherits `$DISPLAY`, the **user's real screen**: never run
  one there unless that screen is the point. A look debt "on the real VcXsrv screen"
  (issue 0413's) needs `AUDIT_DISPLAY=$DISPLAY` or a run by hand from a terminal.
- Do not "correct" WSLg to VcXsrv here: both exist, and the distinction is load-bearing.
- `_gate_enabled` is false on the dev display on purpose, or `_gate_attention` would
  relaunch the user's Pause panel where nobody can see it. `doc/claude/specs/dev_display.md`
  records two traps: under WSLg `/tmp/.X11-unix` lacks the sticky bit, so Xvfb binds
  only the abstract socket `@/tmp/.X11-unix/XN` and a `[ -S /tmp/.X11-unix/XN ]` poll is
  always false; and `xdpyinfo` on a dead display **hangs** on the TCP fallback, so check
  the listen state before probing.

### The owed ledger (`tests/headless/owed.sh`)
Record each debt on the user's attention the moment it is incurred; pay them in one batch.

```sh
owed.sh add rule  <id> [why] [--eyes]  # owes the USER a RULING (--eyes: needs pixels)
owed.sh add look  <what> [why]         # owes the USER's eyes (pixel deliverables)
owed.sh add suite <name> [why]         # owes a :0 run of a GUI feature's suite
owed.sh list | count | show            # `show` = the user's queue: rule + look
owed.sh drain                          # runs the SUITE debts, one batch, gate live
owed.sh clear <kind> <id>              # rule/look: ONLY when the USER says so
owed.sh add|clear … --repo <clone>     # ANOTHER clone's entry: path, basename, `here`
```

- **`rule` and `look` are the user's queue; `suite` is not.** A suite debt clears itself
  on a pass; a rule or look debt clears **only when the user says so**, and nothing
  converts one kind into another (`drain` never opens the other two lists).
- **One ledger (`~/.claude/xschem_owed/`) for every clone.** Entries are stamped with the
  filing clone; an `add` or `clear` that would write another clone's entry **refuses,
  exit 5**, saying what is there and what to type (`clear` also lists this tree's ids on
  that number), unless you pass `--repo <clone>` (issue 1400; `owed.md` §R6b). The stamp
  is an absolute path, so a moved or renamed clone sees its own entries as foreign;
  there is no re-stamp, only `--repo`.
- **An unstamped entry is evidence, not legacy**: another clone's older `owed.sh`
  overwrote something, so never claim it for this clone, whatever `owed.sh` offers. Find
  them with `/usr/bin/grep -L '^repo:' ~/.claude/xschem_owed/{rule,look,suite}/*`;
  `-h '^repo:' … | sort | uniq -c` splits entries by clone (re-run; never quote counts).
  **Read the mtimes first** (entries milliseconds apart are one filing), then
  `cleared.log` in the state dir root (append-only pre-images of this script's clears
  and overwrites; silence about a missing debt means the other clone did it). Known
  innocent: `rule/1357`, `look/hier_pdf_nav_1357_H6.…`, `suite/test_hier_pdf_links_1333`
  (one op-wcard filing) and `rule/1357@xschem-claude` (the collision guard working); a
  `ref:` to an op-wcard branch nobody here has is not evidence either.
- **Back up before any pass that touches the ledger** (`cp -r ~/.claude/xschem_owed …`).
  The guard lives in each clone's own `owed.sh` and a third clone would arrive
  unrepaired: re-check every clone's script rather than trust this paragraph.
- A rule entry is a pointer, not a copy: the options stay in
  `doc/claude/issues/NNNN-*.md`, and `add rule` resolves the path from the id. Spec:
  `doc/claude/specs/owed.md` (§6 for why `rule` exists).
- Never report a pixel deliverable "done" on a green suite: record a `look` and say
  "suites green, please look". Never leave an unratified user-visible decision only in a
  write-up: record a `rule`.

### The display arm: Xvfb by default (`tests/headless/xvfb_arm.sh`)
`full_audit.sh`, `run_suites.sh`, `gated_xschem.sh` and the window-mapping `test_*.sh`
suites run on the dev display if up, else a private Xvfb, never the screen they were
launched from (measured more reliable and faster than `:0`, and immune to the WSLg
Xwayland aborts that kill `:0` clients). Knobs: `AUDIT_DISPLAY=:0` (opt-in, Xwayland, for
its own defects; `=$DISPLAY` for the user's screen) or `=none` (GUI legs self-skip);
`AUDIT_SCREEN` (default `1920x1080x24`; **pin it**, never `1600x1200`, where
`test_fluid_bodyshove_guards_0132` fails); `AUDIT_XVFB_BASE` (first private display,
default 200, never below 100, since bare `xvfb-run -a` starts at the dev display's `:99`;
D17.8); `AUDIT_WM` (default `openbox`, `/usr/bin/openbox` 3.6.1 as checked 2026-09-17;
`none` = empty Xvfb).

- **`GUI_GATE=0` is forced on the Xvfb arm, not defaulted**: `_gate_enabled` only
  checks that `$DISPLAY` is non-empty, so `gate_start` → `_gate_attention` would move
  every session's live panel onto the invisible display and break Pause.
- Empty Xvfb doesn't reparent and silently no-ops `wm iconify`; a WM fixes both, so
  decoration, iconify, stacking and raise are no reason to use `:0`. **An absent WM
  falls back silently** (stderr warning only) and **`xfwm4` is not installed** (checked
  2026-09-17), so `command -v` a WM before naming it. A suite about reparenting, iconify,
  stacking or raise must report which WM was live, naming `AUDIT_WM=openbox` when it
  needs certainty. WM measurements from before 2026-08-23 were WM-less; re-measure.
- **Xvfb is not a substitute for `:0`** for a human eyeball or Xwayland quirks (one
  `wm geometry` gives 3 `<Configure>` events on `:0`, 1 on Xvfb). **Run a GUI feature's
  suite on `:0` once before calling it done**, and treat a `:0`-only bug as a test
  defect too: force the race deterministically (`test_calc_skeleton` S12).

### GUI-test control gate (`tests/headless/gui_gate.sh`)
Under a real/WSLg `$DISPLAY` a suite pops a control panel
(`tests/headless/gui_gate_widget.tcl` via `wish`): Proceed / Snooze 5·15·30 min before,
Pause/Resume and Stop during, since a GUI suite otherwise floods the display. It lives in
the harness: **do NOT reintroduce it as a Claude Code settings hook** (one died silently
with a `settings.local.json` rewrite). Control dir `~/.claude/gui_test_gate/` is shared
by every session, worktree and subagent, so one Pause pauses every suite. It **fails
open** (no `DISPLAY`, `GUI_GATE=0`, or a closed panel). Spec:
`doc/claude/specs/gui_test_gate.md`.

- The panel should be rare (it guards `AUDIT_DISPLAY=:0` runs); one popping for a
  routine suite means something bypassed `xvfb_arm.sh`.
- Press **`Allow 30m` / `Forever`** once rather than Proceed per run (each run otherwise
  costs a click, or a 2-minute autostart wait if nobody is there), or approve before
  launching a batch; Pause and Stop keep working.
- Enrol runs through `run_suites.sh` (preferred) or `gated_xschem.sh`, a drop-in for
  `./src/xschem`. A bare `./src/xschem` loop is listed `UNGATED`, and only **`Halt N
  xschem`** (SIGSTOP, resumable) reaches it.

### A hand-rolled suite loop also forfeits the timeout, and a stall then has no upper bound
- `run_suites.sh` wraps every arm in `timeout` (`SUITE_TIMEOUT`, default 200 s) and
  reports `TIMEOUT | <name> run i/n (after 200s)`; `full_audit.sh` uses `AUDIT_TIMEOUT`
  (default 300 s) and a `crash/timeout` column in `SUMMARY:` (a startup Tcl error popup
  hangs rather than failing). A private loop has neither
  (`doc/claude/code_analysis/a_hung_suite_and_an_unbounded_wait.md`).
- **Use `run_suites.sh`; extend it rather than replacing it.** Otherwise put
  `timeout <n>` on **each command** (rc 124 is a result) and a self-announcing deadline
  on every waiting loop. **A stall must be a named outcome** (`PASS` / `FAIL` /
  `TIMEOUT` / `NORESULT`), never silence. Give a suite's first run on an arm nothing has
  exercised a timeout, and watch it.
- Two bounds, neither replacing the other (issue 1403). **T1:** `t1_timeout`
  (`T1_CASE_TIMEOUT`, default 900 s, `0` disables) puts `timeout --kill-after=20` on all
  four `exec` sites and `t1_why` scores rc 124 as a counted `FAIL` saying `TIMED OUT`;
  on the display arm it goes *inside* `devdisplay.sh exec`, or xschem is orphaned on
  `:99`. **In-suite watchdog:** every suite sourcing `tests/headless/scratch.tcl`, bare
  runs included, arms `XSCHEM_SUITE_WATCHDOG_MS` (default 900000, above both drivers'
  caps; `0` disables), which exits 124 printing `###### WATCHDOG TIMEOUT ###### <suite>
  exceeded <n>ms -- last output: <line>` on both streams.
- **The watchdog is not a general timeout**: an `after` timer fires only in the event
  loop, so it catches a `vwait`/`tkwait` hang but not a blocking `exec` or busy Tcl loop
  (row W13 of `test_suite_watchdog_1403.tcl`). Bound those externally.
- **Do not gate a whole report on the last check**: report (and where appropriate
  commit) the verified majority, naming what is outstanding.

## Architecture

### The `xctx` global context
Almost all program state hangs off a single global `Xschem_ctx *xctx` (defined in
`xschem.h`, ~`Xschem_ctx` struct). It holds the current schematic's object arrays
(`wire`, `inst`, `sym`, `rect[layer]`, `line[layer]`, `poly`, `arc`, `text`),
the hierarchy stack (`sch[CADMAXHIER]`, `sch_path[]`, `currsch`), zoom/pan state,
selection (`sel_array`), spatial hash tables, undo slots, highlight/node tables, and
the drawing GCs/colors. When reading or modifying behavior, the relevant fields are
usually grouped in the struct with comments pointing to the owning `.c` file
(e.g. `/* move.c */`, `/* callback.c */`). Multiple open windows/tabs each have their
own context — see `get_save_xctx()` / `get_old_xctx()` and the tabbed-interface logic
in `xinit.c`.

Core object types (`xWire`, `xRect`, `xLine`, `xPoly`, `xArc`, `xText`, `xInstance`,
`xSymbol`) are all defined together near the top of `xschem.h`.

### The `xschem` Tcl command — central dispatcher
The C core exposes essentially all functionality through one Tcl command, `xschem`,
registered in `xinit.c` (`Tcl_CreateCommand(interp, "xschem", ...)`) and implemented
by the giant dispatcher `scheduler()` in `scheduler.c` (function `xschem(...)`). Tcl
scripts, menus, keybindings and tests all drive the editor by calling
`xschem <subcommand> ...` (e.g. `xschem load`, `xschem netlist`, `xschem hilight`,
`xschem get xorigin`, `xschem callback ...`). **When adding a new user-facing
operation, you add a branch in `scheduler.c` and usually wire it up from Tcl** rather
than inventing a new C entry point. GUI events are funneled in as
`xschem callback <win> <event> ...` → `callback()` in `callback.c`.

### Layering: C engine ↔ Tcl GUI
- `src/xschem.tcl` (~12k lines) is the Tcl GUI: menus, dialogs, simulation launchers,
  preferences. Many config variables are deliberately **mirrored between C and Tcl**
  (search `MIRRORED IN TCL` in `xschem.h`) — keep both sides in sync when changing one.
- Other `.tcl` files are loadable helpers (`mouse_bindings.tcl`, `place_pins.tcl`,
  `create_graph.tcl`, `*_backannotate.tcl`, custom menu/button hooks).
- The C side reads/writes Tcl variables via helpers like `tclgetvar`,
  `tclgetboolvar`, `tcleval`.

### Drawing
`draw.c` is the rendering core over Xlib (with `#if HAS_CAIRO` paths for text/images;
`svgdraw.c` and `psprint.c` produce SVG and PostScript/PDF output). `font.c` holds the
vector font. Spatial hash tables in `xctx` (`*_spatial_table[NBOXES][NBOXES]`)
accelerate hit-testing and selection.

### Netlisting
`netlist.c` is the shared hierarchy traversal and node-naming machinery; per-format
backends are separate files: `spice_netlist.c`, `spectre_netlist.c`,
`vhdl_netlist.c`, `verilog_netlist.c`, `tedax_netlist.c`. Label/bus expansion goes
through the bison/flex parsers. Highlighting and node tracing live in `hilight.c`,
`findnet.c`, `node_hash.c`.

### Editing pipeline
`actions.c` (largest file — high-level edit ops), `move.c`, `paste.c`, `clip.c`,
`select.c`, `editprop.c` (property/attribute editing), `store.c` (object allocation),
`save.c` (the `.sch`/`.sym` file format I/O), `check.c` (ERC/symbol consistency),
`in_memory_undo.c` (undo can be on-disk or in-memory; chosen via the `push_undo`/
`pop_undo` function pointers in `xctx`).

### awk scripts
The many `*.awk` scripts in `src/` are import/convert/flatten utilities (e.g.
`gschemtoxschem.awk`, `make_sym_from_spice.awk`, `flatten.awk`). They are part of the
shipped toolchain, invoked from Tcl, not build-time codegen.

## Symbol & schematic libraries
`xschem_library/` holds the standard device symbols (`devices/`) plus example
designs and generators. The library search path is configured in `Makefile.conf`
(`xschem_library_path`) and overridable in `~/.xschem/xschemrc` or a `./.xschemrc`.
`.sym` (symbol) and `.sch` (schematic) share the same text record format handled by
`save.c`; the format version is `XSCHEM_FILE_VERSION` in `xschem.h`.

## Conventions
- C89 throughout; the codebase targets both Unix and Windows (`XSchemWin/` holds the
  Windows config). Guard platform code with `__unix__`.
- Memory tracking: allocations use id-tagged wrappers (`my_malloc`, `my_realloc`,
  `my_strdup`, etc.) whose first arg is the placeholder macro `_ALLOC_ID_`. The
  `create_alloc_ids*.awk` / `get_malloc_id.awk` scripts rewrite those placeholders
  into unique numeric ids for leak tracing — write `_ALLOC_ID_`, don't hand-number.
  Debug logging via `dbg(level, ...)`.

## AI / planning docs
Design and working notes live under `doc/claude/` (not installed — `doc/Makefile`
ships only `*.svg/*.html/*.css/*.png`): `doc/claude/specs/` (feature specs),
`doc/claude/issues/` (numbered issue tracker, `NNNN-*.md`), `doc/claude/code_analysis/`
(analysis & decision write-ups), `doc/claude/suggestions/` (session prompts, plans), and
`doc/claude/FAQ.md` (a running design Q&A, newest entries on top).
Source comments reference these by their full path (e.g. `see doc/claude/specs/foo.md`).

**Cite code by symbol (proc or function name), not by bare `file:line`**: coordinates
rot, identity holds (`src/op_annot.tcl` does this on purpose). A line number that cannot
be avoided needs the commit it was measured at; re-grep before quoting it again.

**Issue numbers: `doc/claude/issues/NUMBERING.md` is authoritative about what a number
MEANS, and blind to what is free.** Tracked per branch, its `next free number` line is
a per-clone pointer, so two clones here have minted the same numbers for different
defects (issue 1400). Minting takes **two** checks, neither substituting for the other:
the **candidate** from this clone's `NUMBERING.md` (its pointer, and the **reserved-block
table at its head**: a band is a range no per-number grep can see), then a grep proving
no *other* checkout took it:

```sh
N=doc/claude/issues/NUMBERING.md                   # this clone's pointer AND bands
n=$(/usr/bin/grep 'next free number' "$N" | /usr/bin/grep -v '~~' | tail -n1 |
    /usr/bin/grep -o '[0-9][0-9]*' | tail -n1); echo "candidate $n"   # or n=1550
awk -v n="$n" -F'|' '/^\| \*\*[0-9]/{gsub(/[^0-9]/," ",$2); split($2,b," ")
  if (n>=b[1] && n<=b[2]) print "!! "n" is in RESERVED band "b[1]"-"b[2]}' "$N"

set -- ~/dev/*/doc/claude/issues/NUMBERING.md      # EVERY clone on this machine
[ -e "$1" ] || echo "!! glob matched nothing -- fix the path, not the number"
ls ~/dev/*/doc/claude/issues/"$n"-* 2>/dev/null    # a file in ANY checkout here
/usr/bin/grep -lw "$n" "$@"                        # or a reservation with no file
```

- A free candidate prints only this clone's `NUMBERING.md` (its pointer line names it);
  an issue file or any other `NUMBERING.md` means taken (a reserved number often has no
  file yet). `n=1550` shows the band check catching what every grep misses.
- `~/dev/*` is every checkout today; add any clone living elsewhere. `[ -e "$1" ]`
  catches a glob matching nothing (grep would exit 2 with silent stdout, reading "free").
- **Use `/usr/bin/grep`, never the bare `grep`**: here `grep` is a function routing to
  ugrep, which misses forms like `-lE "(^|[^0-9])$n([^0-9]|$)"`.
- **`1500–1599` is reserved for the op-wcard branch: after 1499 the next number here
  is 1600.** `0500–0599` (fluid-editing, i.e. this branch) is a head-table band too;
  skip it like the rest. Trust the head table over any number quoted elsewhere,
  including here. Record the new number in `NUMBERING.md` in the same commit; a
  collision costs a renumbering.

**A NEW issue file must open with a valid stamp line, or T1 goes red.** Row `D9` of
`test_issue_stamp` (a T1 case) fails on an issue file with no `**STAMP:**` line unless
its **exact file name** is in `tests/headless/issue_stamp_baseline.txt` (grandfathering
is by name, not number). The line sits in the first 12 lines, on one physical line;
`tree=` is a commit abbreviation with an `a`–`f` letter (lengthen an all-decimal one)
that, in a full clone, resolves **to an ancestor of HEAD** (D15.4), not to a commit only
on another branch or clone, or amended away. Grammar and vocabulary:
`doc/claude/specs/issue_stamp.md` §2. Check with `tclsh tests/headless/issue_stamp.tcl`
→ `ok (0 problems)`. A stamp-shaped example anywhere else in an issue file is itself a red.

**Wiring work**: before touching anything that creates, moves, deletes, or reroutes wires
(move.c, the fluid passes, trim/break/merge, connected drag/rotate/flip), read
`doc/claude/WIRING.md` — data model, END pipeline, pass contracts, landmines, open risks.
Keep it updated when fixing wiring issues.
