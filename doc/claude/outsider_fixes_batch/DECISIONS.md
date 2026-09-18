# Decisions — outsider fixes batch

## D1 — Item 1 fixes the checker; other git-dependent suites are recorded, not swept in

The audit's F21 says a `git archive` export turns about ten T1 cases red because several suites
read their corpus through git. Item 1 is **the driver's own regression** — the checker it
registered in T1 on 2026-09-17 — and it is fixed completely: folder name, shallow clone, no
`.git`. Any other suite F21 names is attributed in S1's receipt and recorded as follow-up, not
fixed here, unless it shares the checker's exact root cause. Mixing a regression fix with an
unrelated sweep makes the regression fix harder to verify and to revert.

## D2 — A throwaway home is the DEFAULT, with an explicit opt-out

Item 2's default must protect the person who does nothing special, because that is who the
audit measured losing data. A developer who needs a run against their real configuration (to
reproduce a bug that depends on it) gets an explicit environment opt-out, named and documented,
never the default. The opt-out's name and the mechanism are settled in S2b from S2a's map.

## D3 — Proved with a canary, never assumed

"The tests no longer touch your home" is exactly the kind of sentence this project has written
confidently and been wrong about. Item 2 is proved by running the documented commands with the
**parent's** `HOME` set to a seeded canary directory and showing the canary byte-identical
afterwards — and by showing the canary **does** change with the fix reverted (red-first).

---

# S2b — the design for Item 2 (driver, 2026-09-18)

Inputs: S2a's map, redirect study and critic (workflow `wf_704cbd18-d5d`; the map and critic
are the basis; the critic's corrections are adopted wherever the two disagree). Every rule
below is a contract both languages implement identically. **The names are fixed here, and a
crew does not rename them.**

## D4 — Switch HOME for the whole driver process, through one helper per language

* **Tcl:** `proc t1_arm_home` in `tests/test_utility.tcl`, **called at source time**. That
  covers `cd tests && tclsh run_regression.tcl` *and* the documented single-case command
  `cd tests && tclsh netlisting.tcl`, which is the command F10 was measured with (critic,
  point 4). It must be idempotent and aware of nesting (D5). It does **not** go in a new file,
  because `test_regression_concurrency_1476` stages copies of `test_utility.tcl` by name.
  If `test_utility.tcl` is also sourced *inside* an xschem interpreter anywhere, arming there
  is a no-op: the crew checks for that and records what it finds.
* **Shell:** `tests/headless/test_home.sh`, sourced by `run_suites.sh`, `full_audit.sh` and
  `gated_xschem.sh` **before** `. xvfb_arm.sh`, so openbox on the private arm and the
  xvfb-run re-exec both inherit the throwaway.
* **Not** a per-exec `env HOME=` prefix: each new call site would have to remember it, which is
  the 1397 trap in another form.

## D5 — Nesting, ownership, cleanup (the dangerous lines, per the critic)

* The throwaway is `mktemp -d "${TMPDIR:-/tmp}/xschem-test-home.<ownerpid>.XXXXXX"`.
  Refuse and exit nonzero if mktemp fails, or if the result equals the real HOME or is an
  ancestor of it. **Never fall back to the real HOME.** A mixed-case suffix is fine (the critic
  measured it; the "lowercase only" rule applies to checkout paths, not HOME).
* It holds `.owner`, one line: the owner pid. `mkdir -m 700 "$TH/.xschem"` runs at creation
  (F25: 11/320 flakes down to 0/320).
* **Nested** means: HOME is an existing directory whose basename matches
  `xschem-test-home.<pid>.*`, its `.owner` names a live pid, **and** the variable
  `XSCHEM_TEST_REAL_HOME` is set. A nested run reuses HOME. It never creates and never deletes.
  Anything short of all three is a fresh arm.
* `XSCHEM_TEST_REAL_HOME` carries **a path and nothing else**: absolute, an existing directory,
  and not itself a throwaway. A value failing that is refused loudly, never read as a flag.
* **Only the owner deletes**: a Tcl owner after the `T1-RUN-END` trailer, a shell owner in an
  EXIT trap. The xvfb-run re-exec receives ownership explicitly: the pre-exec process exports
  `XSCHEM_TEST_HOME_HANDOFF=<its pid>`. The re-exec'd script takes ownership only if that pid is
  its grandparent or its parent, and it matches `.owner`. It then rewrites `.owner` and unsets
  the variable. The critic refuted "`$PPID == owner` may delete".
* The delete removes exactly the path that was created, after re-checking it is under the temp
  root, matches the pattern, and is not the real HOME.
* `XSCHEM_TEST_KEEP_HOME=1` keeps the directory and prints its path.
* **Sweep at arm time**: delete `xschem-test-home.*` entries in the temp root that are owned by
  this uid, whose `.owner` pid is dead, and that are older than 300 s. That is the same contract
  as `sweep_dead_run_dirs`. If `.xvfb.pid` is present and that pid is alive with an `Xvfb`
  cmdline, kill it first.

## D6 — Opt-out and what the run says about itself (D2 made concrete)

* `XSCHEM_TEST_HOME=real` leaves HOME alone and prints a loud banner **on every run**.
  `XSCHEM_TEST_HOME=<dir>` uses that directory as HOME and **never deletes it**; it is for
  reproducing a bug against a copy of someone's configuration.
* Each armed run prints one line:
  `test home: throwaway <TH> (your HOME is untouched; XSCHEM_TEST_HOME=real to opt out)`.
* `T1-RUN-BEGIN` gains `home=<throwaway|real|custom>` and `binary=<path>`, both **before**
  `canonical=`, which stays last. `binary=` is sanitised (whitespace replaced), so that no
  user-controlled value can end the line in a counted shape. The `test_regression_concurrency_1476` V rows are
  re-run.

## D7 — What is carried from the real home (each only if not already set)

| variable | value | condition |
|---|---|---|
| `XSCHEM_TEST_REAL_HOME` | the real HOME | always |
| `XSCHEM_DEVDISPLAY_DIR` | `$REAL/.claude/xschem_dev_display` | always (it is read; creating it is governed by D8) |
| `GUI_GATE_DIR` | `$REAL/.claude/gui_test_gate` | **only if that directory already exists** (critic, point 3); otherwise it resolves inside the throwaway |
| `XAUTHORITY` | `$REAL/.Xauthority` | only if that file exists |
| `XDG_{CACHE,CONFIG,DATA,STATE}_HOME` | repointed into the throwaway | **only if already set**. Unset ones stay unset and keep following HOME, which keeps the per-suite HOME switches of ~11 suites coherent (critic) |
| git `safe.directory` | `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=<repo root>` | always; command-scope, so it imports none of the tester's config (critic) |

**Long-lived processes are started with the environment from before the switch**
(`env HOME=$REAL` plus the original XDG_* values). That covers the persistent dev display
auto-start and the shared gate panel. Otherwise they would outlive a HOME that gets deleted,
which is exactly the orphan now holding `:99`.

## D8 — T1's display arm

1. Attach to the dev display through the carried state dir, as today.
2. Auto-start the persistent dev display (the 0891 behaviour) **only if the carried state
   dir already exists**, meaning the tester has used it before, and only with the pre-switch
   environment (D7).
3. Otherwise, or if the start fails (for example exit 4 because a foreign `:99` exists), run
   the 11 display cases on a **private Xvfb for this run only**. Start it with
   `Xvfb -displayfd`, or with numbers of 100 and up, never `xvfb-run -a`, which collides at
   `:99`. Record its pid in `$TH/.xvfb.pid`, set DISPLAY **per exec** and not in `::env`, and
   kill it at the end of T1.
4. NODISPLAY only when no Xvfb is installed.

This supersedes part of the 0891 ruling, *"goes on starting the persistent dev display"*, for
testers who have never used it. That is internal harness behaviour and the driver's call.
**Because it turns 11 uncounted NODISPLAY lines into 11 counted runs for strangers, it must be
measured green on the private arm before it lands.** (Baseline ZERO.)

## D9 — The bare suite command is NOT re-exec'd; it is pointed at

The redirect study's variant R made `scratch.tcl` re-exec xschem under a new HOME, and it
measured 0 writes. **It is rejected anyway**, because it:

* is Linux-only, through `/proc/<pid>/environ` and `cmdline`;
* runs the prelude twice in the 7 suites that source `scratch.tcl` late;
* needs `LC_ALL` restored by hand (4 suites went red without that);
* covers 187 of 402 suites;
* puts process-replacement machinery in the prelude of those 187 suites, for a command no
  driver runs.

Variant B (a Tcl-only redirect) is actively harmful, and variant C is a product change.
Instead:

* CLAUDE.md's documented single-suite spelling becomes the armed one,
  `tests/headless/run_suites.sh <name>`, which already exists for one name.
* `scratch.tcl` prints **one stderr line** when a suite runs un-armed (neither nested nor opted
  out): `note: this suite is using your real HOME; tests/headless/run_suites.sh <name> gives it
  a throwaway one`. The line must not match a counted shape. It is never printed under T1 or
  the shell drivers, because those are armed.

## D10 — Suites that read fixtures from HOME read them from the real home

These suites lose coverage silently under a throwaway, and each now reads from
`${XSCHEM_TEST_REAL_HOME:-$HOME}`:

* `test_ase_converge_1459` and `test_ase_sp_1452`, which locate the fork ngspice through the
  home: 6 lost checks, measured;
* `test_vcd_read`, `test_vcd_time_base` and `test_ase_cosim` REF12, which read fixtures;
* `test_launch_context`, whose whole purpose is the real `geometry`;
* `spawn_reaper.sh`'s guard, which reads the home unconditionally.

This is **read-only**. The crew proves that none of them writes through that path. A fixture
row that finds nothing prints `skip:` with a reason rather than passing silently.

## D11 — The proof (D3, refined by the critic)

* **Snapshot the whole canary.** Take `find -printf '%p %y %s %T@ %m\n'` plus an md5 of every
  regular file, before and after. An md5 manifest alone cannot see new files. Also record
  transients with the redirect study's `iwatch.py`. Take the reference time with
  `touch -d @<epoch>`, never a local-time string: that was measured 7 hours off.
* **Seed the canary** with `.xschem/` (a sentinel clipboard, `simulations/clean.spice` and
  `short.spice`, a 100-entry `geometry`, `recent_files`, `ase_simulators`), plus
  `.spiceinit`, `.ngspice_history` and `.gitconfig`.
* **Run these shapes:**
  1. T1;
  2. `run_suites.sh` on a sample that includes the clipboard, netlist and geometry writers;
  3. `full_audit.sh`, with its peak throwaway size measured;
  4. `tclsh netlisting.tcl`;
  5. cwd = the canary home, with the checkout outside it;
  6. an **attach variant**, with a seeded state dir pointing at a fixture Xvfb on a number
     ≠ 99, asserting that the dcases ran there and the state dir stayed byte-identical.
* **Red first:** `XSCHEM_TEST_HOME=real` must change the clipboard, `clean.spice` and
  `short.spice`.
* **Pass condition:** every shape leaves the canary byte-identical and leaves no process
  alive.

## D12 — Recorded, not fixed here

* The 9 git-dependent suites (F21).
* The 4 suites that segfault in a fresh clone (F14).
* An uppercase letter in the checkout path turns 5 ASE suites red. This is **a new stranger
  finding**, measured on `test_ase_sp_1452`; the redirect study infers that ngspice lowercases
  the unquoted `wrs2p` path.
* Suites write into the cwd: `untitled~.sch`, and the op_param project tier
  `.xschem/op_param_lists.conf`. This checkout's root has carried one since 2026-09-09.
* `summarize_all` does not carry `skip:` lines, so T1's verdict cannot show that a case
  skipped rows.
* `ngspice -p` writes `~/.ngspice_history`. Its origin is unknown, and nothing in the tree
  uses `-p`.

These go to issue files in stage F.
