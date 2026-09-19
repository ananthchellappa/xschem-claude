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

---

# D13 — Round 2, after S2c's refuters (driver, 2026-09-18 06:30)

The integrated build (`/var/tmp/xschem_fixes/s2c_I/final.patch`) holds everywhere it was
aimed: T1, `run_suites.sh`, `full_audit.sh`, `gated_xschem.sh` and the tcases alone all leave a
seeded canary byte-identical, and every one of them was measured red first. The safety refuter
and the completeness critic still refuted the claim, and they were right, for these reasons. Each
item below amends D4–D11, and the contract is still shared by both languages.

1. **Arm the remaining documented entry points.**
   * `xvfb_arm.sh --arm` arms through `test_home.sh`, and the xvfb-run handoff applies. That
     covers the 7 standalone suites that re-exec through it.
   * `test_devdisplay.sh` arms directly.
   * `owed.sh drain` arms a throwaway **only around each shell debt it runs**, in a subshell.
     Its own ledger path is fixed from the real HOME **before** that switch.
   * `tests/headless/run.sh` and `run_nogui.sh` (T2) arm too.
   * `xschem --script xschemtest.tcl` is a bare binary invocation and stays with D9's
     exception. It is recorded, not armed.
2. **The developer shape is kept, and the claim is scoped to say so.** A tester who already has
   `~/.claude/xschem_dev_display` gets the persistent display auto-started with the real HOME,
   so the state dir and `~/.cache/openbox` are written. A tester who already has
   `~/.claude/gui_test_gate` gets the shared panel. Both are the developer's own standing setup,
   and the persistent display must outlive any one run. The done-claim reads: **nothing under
   the real HOME is touched except the dev-display state and the gate dir that the tester already
   set up.**
3. **cwd.** `run_suites.sh` changes to the repository root before it runs anything, as
   `full_audit.sh` already does, after first making its path arguments absolute. `gated_xschem.sh`
   does the same, and it first rewrites to absolute paths any argument that names a path existing
   relative to the caller's cwd. That fixes the overwrite and delete of `~/untitled~.sch`
   (xschem's autosave) when a tester runs from their home. Litter in the checkout stays a D12
   item.
4. **TMPDIR inside the real HOME** is still honoured, but the banner must not claim *"your HOME is
   untouched"*. It says your `~/.xschem` is untouched and the throwaway lives under your HOME
   because TMPDIR does.
5. **`XSCHEM_TEST_HOME=<dir>` is fully resolved, including a symlink in the last component**,
   before it is compared. If it resolves to the real HOME it is refused, in both languages.
   (Tcl's `file normalize` leaves the last component unresolved.)
6. **`.owner` becomes `<pid> <boot_id> <pidns>`.** `boot_id` is
   `/proc/sys/kernel/random/boot_id`, and `pidns` is the link text of `/proc/<pid>/ns/pid`; each
   is `-` where unavailable. The owner counts as **dead** when either:
   * the boot_id differs from the current one;
   * or the boot_id **and** the pidns both match the sweeper's own, and the pid is not alive.

   A matching boot_id with a different pidns (a container, bwrap or flatpak) is never swept
   unless the entry is older than 7 days. Where a field is `-`, the old rule applies.
7. **The sweep kills only what it can identify.** A recorded Xvfb or openbox is killed only if
   its name matches **and** the `HOME` in its `/proc/<pid>/environ` is exactly the dead
   throwaway's path. A panel is identified by a cmdline naming that exact gate dir, as now.
8. **Handoff.** The re-exec'd script takes ownership only if the handoff pid is its parent or
   grandparent, it matches `.owner`, **and** `/proc/<handoff pid>/cmdline` shows that process is
   now running `xvfb-run`, meaning the exec really happened.
9. **`XSCHEM_TEST_KEEP_HOME=1` writes `.keep` at arm time**, not at exit, so a killed run's home
   is kept. This holds in both languages.
10. **`binary=`** carries the full path resolved through `auto_execok`, not the bare word.
11. **`run_suites.sh` prints every `skip:` line a suite emitted**, indented under its verdict
    line. Without that, D10's "skip loudly" is silent through the documented command.
12. **F14 is re-attributed.** The four suites segfault on exit **when DISPLAY is unset**, not
    because the clone is fresh; the critic measured them green with DISPLAY set. That is a product
    defect a headless CI box hits, and it is filed in stage F with the right cause. The stage-F
    gate runs in the shell's normal environment (DISPLAY inherited), the same as the 09-17
    baseline, so the comparison is like for like.
13. **The stage-F gate will restart the user's persistent `:99`.** The orphan is gone (the user
    killed it at 06:1x), and the real state dir names a dead pid, so T1's D8 step 2 starts it with
    the real HOME. That is exactly what T1 did before this batch (0891), and it restores the
    user's intended state. The driver accepts it knowingly. Crews still never do it.
14. **Identity, not number** (regression refuter, 1 red in 14 concurrent pairs). `test_home_isolation`
    row H1b checked `![file exists /tmp/.X$pnum-lock]`, so a concurrent run that re-took the freed
    number turned it red. Every "did it clean up" check compares the lock's **content** with the
    pid it started, as `stop_pid` does. This is the W12b class again.
15. **A private Xvfb must not outlive a killed owner by more than a few seconds.** When a private
    Xvfb and its openbox are started (T1's private arm, and `xvfb_arm.sh`'s private path), a
    detached reaper starts with them. It polls the owner pid every 5 s, kills them when the owner is
    gone, and then exits. The run-time sweep stays as the backstop.
16. **The "pre-switch environment" is a snapshot of the environment as it was before arming**,
    not the current environment with HOME swapped back. The persistent display and the shared
    panel therefore inherit none of the harness variables (`XSCHEM_TEST_*`, `GIT_CONFIG_*`, and a
    carried `XSCHEM_DEVDISPLAY_DIR` the tester had not set themselves).
17. **Header values are also stripped of `T1-RUN-`** (it becomes `T1_RUN_`), so no field can
    carry sentinel text even for an unanchored reader.

---

# D14 — Item 1 stops excusing a re-initialised history (driver, 2026-09-18)

Two consecutive rounds tried to keep a download that was then run through `git init && git
commit` green, and **each round opened a fail-open in the state that must be strict**:

* **S1-fix** used an anchor-absent test (`foreign`). A rewritten history and a corrupt clone
  then went green while verifying nothing.
* **S1-fix2** used a per-stamp date rule. The stamp's own unvalidated `stamped=` date became the
  evidence that exempted it, so a one-digit typo (`2016` for `2026`) turned a bogus `tree=` green
  in an ordinary full clone. Grafted, orphan-branch and root-date-rewritten histories failed open
  the same way.

The shape was never in Item 1's done-criteria. **Fail-closed beats convenient**, so:

* **There is no exemption for a history that has commits.** In a full history every
  unresolved revision is red, whatever its date and whatever the ancestry looks like. The date
  rule and the `foreign` state are removed.
* **The red explains itself.** When a revision does not resolve and HEAD's ancestry lacks the
  project's root commit `7fe79fb2`, the problem line says so. It names the likely cause (a
  re-initialised download, an orphan squash or a rewrite) and the cure (a real clone). That check
  only changes the **wording**; it never changes the verdict.
* **What stays from S1-fix2:**
  * `unborn`, which needs three pieces of evidence (HEAD does not verify, no refs, no commit
    object); with no commits, nothing can be verified, as with `none`;
  * H7's HAVE_GIT fix;
  * the fixture seal;
  * `%41` in paths;
  * no death before RESULT;
  * the S20c split.
* **A git warning on stderr is not a failure.** A deprecated setting in the tester's config turned a
  pristine clone `unreadable`, because Tcl's `exec` treats any stderr output as an error. Git
  calls are judged by their exit code alone.
* **A row asserts that no revision question skips in a full history** (an empty skip set), and a
  row plants a backdated bogus stamp in a full fixture and requires it RED.

---

# D15 — Round 4 of Item 1: shallow is a property of HEAD's history, and user text is never an argument (driver)

S1-fix3's refuter confirmed D14 in `full` and `unreadable`: they never skip. It found the
shallow skip itself fails open. `--is-shallow-repository` is a flag on the whole repository.
One `git fetch --depth 1` of another branch, or a stranger's CI flow of
`clone --depth 1 -b main` followed by a fetch of this branch, sets it. HEAD's history then stays
complete (5818 commits, root `7fe79fb2`), yet a planted bogus `tree=` passed as "history absent".
That skip was introduced by S1 and is not in the committed checker, so it is fixed before any
commit. Rulings:

1. **`shallow` only when HEAD's own walk ends at a shallow boundary.** That means a root of
   `git --no-replace-objects rev-list --max-parents=0 HEAD` is listed in the shallow file, or its
   stored object carries a `parent` line. Otherwise the tree is `full`. Add a fixture with a
   boundary off HEAD's path and a planted bogus stamp, which must be RED.
2. **A `.git` that exists as a link but does not resolve is `unreadable`**, never `none`: test it
   with lstat, not `file exists`.
3. **No text from an issue file ever reaches git as an option.** Validate `quote=` with the same
   grammar as `tree=`, and pass `--end-of-options` (or an equivalent) on every git call that carries
   a value derived from the corpus. The refuter made the gate write a 21 KB file through
   `quote=--output=…`. This is a write hazard in T1 over the real corpus, and it is fixed here even
   though it predates the batch.
4. **A stamp's revision must be an ancestor of HEAD.** It is checked with
   `merge-base --is-ancestor`, and in a shallow history only up to the boundary, where it skips by
   name. That catches, in the author's own clone, a stamp whose commit was amended away, which
   today passes locally and turns T1 red for every stranger. **The current corpus is measured
   first.** If any of today's stamps names a non-ancestor, the crew reports it and falls back to
   "reachable from some ref", rather than turning the gate red.
5. **A `quote=` or `**STAMP:**` that the parser does not consume is a problem.** Examples are a
   quote in an indented, `~~~` or unclosed fence. It is never a silent pass.

---

# D16 — Round 5 of Item 1: the checker executes nothing with corpus text in it (driver)

S1-fix4's refuter confirmed every git-side claim, and then found the class D15.3 was meant to
close, **one exec over**. `assert_eval` runs `exec timeout … /usr/bin/grep -rn -- $pat $target`.
Tcl's `exec` parses any word that begins with `>`, `2>`, `<` or `|` as a redirection or a pipe,
**after `--` too**. Planted in one issue file:

* `pat=>` truncated a tracked file to 0 bytes;
* `pat=>/path` wrote a file outside the repository **and the run stayed green**;
* `pat=|` with `path=<script>` **ran a program**;
* `pat=2>/dev/null` turned a false assertion green.

It predates the batch, and it is live: 1219 is stamped and carries an `assert=` block, so T1's
D9 goes through that exec over the real corpus on every run. So:

1. **No `exec` ever carries a word derived from the corpus except git revisions** that have
   passed `rev_token` and sit behind `--end-of-options`. `assert=` search is done **in Tcl**: read
   the files and match with `string first` or `regexp` as the spec defines `pat=`. That removes
   the grep exec entirely, which dissolves the class instead of escaping it.
2. **`path=` is confined.** It must be relative, contain no `..` component, and not start with `-`
   or `/`. After normalisation it must resolve inside the checkout and never leave it through a
   symlink. Anything else is a named problem, and nothing is read.
3. **`shallow` means git cannot read a commit HEAD's walk needs.** Walk HEAD with the shallow file
   disregarded (the refuter measured `GIT_SHALLOW_FILE=/dev/null/none`; the crew confirms it on
   git 2.53 and uses the most robust spelling). If the walk completes, the store holds the whole
   history and the tree is `full`, whatever `.git/shallow` says. The trigger is a no-op
   `fetch --depth 1` of the branch itself or of an ancestor, which writes HEAD, or an ancestor, into
   the shallow file.
4. **In a shallow history, an object that is present but not a commit is RED**, not skipped: that
   is positive evidence of a defect.
5. **Fences close the CommonMark way**: on the same character, at least as long as the opener.
   **Stray-stamp detection matches the stamp by content**, meaning `STAMP:` followed by
   `` `v1 `` in any emphasis spelling, including `__STAMP:__` and `<strong>`/`<b>`. It does not
   match only `**`.

---

# D17 — Round 3 of Item 2: stop finding entry points one at a time (driver)

Round 2 holds wherever it is aimed. Both refuters reproduced every armed measurement:
* T1 is 87/86/0 in the main-tree shape;
* the canary is byte-identical, and an **empty** canary stays empty;
* auto-start leaves no harness variable in the persistent display's environment;
* attach is byte-identical;
* concurrent pairs are green;
* all 84 shared case results are identical;
* the D10 suites keep their counts (converge 76, sp 61).

The refutations are edges:

1. **An xschem launcher guard.** Each round has found more documented scripts that start xschem
   under the tester's HOME: round 1 found the standalone `.sh` suites, `owed.sh drain` and
   `run_nogui.sh`; round 2 found `lookshot.sh`/`winshot.sh`, `tests/netlist_diff/netlist_diff.sh`
   and `wireedit/run_wireedit.sh`. **Whack-a-mole is the wrong shape.** A row in
   `test_home_isolation` enumerates every script under `tests/` that starts xschem (by `src/xschem`,
   `$XSCHEM`, `xschem_cmd`, `gated_xschem` or `xvfb_arm --arm`). It fails unless each one is
   armed or is on an **explicit allowlist with a one-line reason**. The known exception is the bare
   `./src/xschem --script` and `xschemtest.tcl`, for D9's reasons. The three found by round 2 are
   armed, and a `winshot` build cache goes into the throwaway.
2. **The proof includes a FRESH (empty) canary** for every newly armed entry point. A seeded canary
   cannot see first-run creation of `~/.xschem/xschemrc`.
3. **A relative `TMPDIR` is made absolute before `mktemp`**, in the shell. Tcl already
   normalises it.
4. **Nesting requires HOME to sit under the temp root**, as the fresh arm and the takeover do, in
   both languages. A forged `…/xschem-test-home.1.forged` inside the real home is refused.
5. **`XSCHEM_TEST_HOME=<dir>` whose `.xschem` resolves into the real HOME is refused**, in both
   languages.
6. **Nothing is killed on a recorded pid alone.**
   * `devdisplay.sh stop`/`_ours` kill a recorded pid only if `/proc/<pid>/cmdline` is the
     expected program for that display number (`Xvfb :N`, openbox, x11vnc), and they remove
     `/tmp/.X<N>-lock` only if it names that Xvfb.
   * `test_devdisplay.sh`'s cleanup removes a lock only by content.
   * **This matters for the user today:** their real state dir names pids 1116/1135, which are dead
     and low enough for a reboot to hand to unrelated processes, and `stop` would have killed them.
7. **No reaper window.** On the shell private path the reaper starts before `xvfb-run` or
   together with it, and the server's pid is recorded in the throwaway, so the sweep can kill it by
   identity. In Tcl the reaper starts immediately after the exec, not after the up-check. Recipe:
   a kill -9 within 100–140 ms of the Xvfb starting must leave nothing after about 10 s.
8. **The private arms never use `:99`.** `xvfb-run -a` in `xvfb_arm.sh`'s private path and in
   `test_devdisplay.sh` get `-n <base>` with a base of at least 100, so no run can hold the user's
   dev display number while it is down.
9. **Rows.**
   * A row makes an installed Xvfb that will not start a counted HARNESS FAIL, never NODISPLAY.
     The refuter's sabotage V3 went unnoticed.
   * Fixture displays in the suites use `-displayfd` (or a range that cannot run out under 4-way
     concurrency), so H3 stops skipping under load.
   * `owed.sh drain` prints the throwaway banner once.

---

# D18 — Item 1's threat model, written down so that rounds converge (driver)

Five refutation rounds on the issue-stamp checker have each found something. The early ones were
genuine fail-opens in shapes a stranger or an honest author hits (repository-wide shallow, a
typo'd date, amended-away commits) and genuine **safety** holes (corpus text reaching `exec`
wrote files and ran a program). Round 5 found, mostly, that **an author who deliberately
disguises a stamp** can hide it from the parser: a leading NBSP or ZWSP before `**STAMP:**`,
HTML with attributes, a table cell, a link or a task list. Chasing every markdown spelling does
not converge, and it guards against nothing real: **the person who can write the issue file can
simply leave the stamp out**. So the checker's contract is:

**A. Safety, absolute.** Running the checker or its suite on *any* corpus **never** writes
outside its scratch, runs a program, reads outside the checkout, hangs, or burns unbounded CPU.
Each such finding is a defect whatever the corpus looks like, adversarial or not.

**B. Honest mistakes, fail-closed.** In the canonical formats the spec defines, every genuine
defect an honest author could make is RED in a full clone. The canonical formats are a
column-0 `**STAMP:**` line, a column-0 backtick fence carrying `quote=` or `assert=`, and one
stamp per file. The defects are a bogus, typo'd, blob or amended-away `tree=`, a rotted
`quote=`, a false `assert=`, an unstamped new file and a malformed stamp. Near-miss spellings
that an honest author produces by accident, such as an indented or `~~~` fence, or
`__STAMP:__`, are named problems, never silent passes.

**C. Strangers, never falsely red.** Every shape in which HEAD's history is truly absent, as
opposed to merely flagged as absent, is green with each skipped item named. The shapes are a
renamed clone, a worktree, a shallow clone, an export, an export inside another repo, and an
unborn repository.

**Out of scope, recorded as a known limit:** deliberate disguise of a stamp or assertion through
invisible characters, HTML, or container markup (tables, links, task lists), and a second stamp
hidden that way. The checker is a hygiene tool against honest error, not a gate against its own
authors.

S1-fix6 therefore fixes:

* the non-UTF-8 filename skip, which is a regression, fail-closed: a path the scan cannot stat is
  a named problem;
* `assert=` in a fence the parser does not read, named as `quote=` already is, plus `assert=` in
  an unstamped file;
* an issue file that is not a regular file: a symlink or FIFO is a named problem and is not read
  (A);
* `md_strip`'s quadratic cost, made linear or with an over-long line refused by name (A);
* the spec now saying that `pat=` is a **literal** string, which is the safer semantics, since
  the checker has no regex engine exposed to corpus text.

---

# D19 — Commit the verified improvement now; round 7 closes the remaining in-scope findings (driver)

**Commit first.** Every round from S1-fix onward is strictly better than the committed checker.
That checker is red for strangers (F23/F24/F21) and still runs `grep` through Tcl `exec` with
corpus text, so it can write files and run a program. S1-fix6's refuter measured no **regression**
against it: every finding is also present in, or absent from, HEAD's checker. So S1-fix6's bytes
commit after a solo T1 gate in the main tree. That gate runs with `HOME` set to scratch, and with
`XSCHEM_DEVDISPLAY_DIR` and `DEVDISPLAY_NUM` pinned to scratch and `:141`, so neither the real
home nor `:99` is touched. The remaining findings go to S1-fix7 as a follow-up commit.
Holding verified work hostage to the next round converts a small uncertainty into zero delivered
value.

**S1-fix7 (in scope under D18):**
* **A. The corpus confinement applies to every reader.** `issues_dir_problem` is honoured by the
  suite's own corpus reads (B1, B4, the D9 census) and by `report`. `report`'s `grep -r` over the
  issues directory becomes a Tcl scan, which removes one more exec.
* **A. `GIT_NO_LAZY_FETCH=1` on every checker git call.** Otherwise a partial clone fetches over
  its remote and writes into `.git` because of corpus text.
* **A. A total budget for `assert=` scans per run.** Exhausting it is a named problem. Per-scan
  bounds do not bound 100 blocks.
* **B. A read fence's info string is fully parsed.** Any word that is not a recognised
  `key=value` (a multi-word `pat=`, for instance) is a named problem, never silently dropped.
* **B. A line carrying a stamp body (`` `v1 claim=``) that is not a valid stamp line is named.**
  That catches a stamp with its colon missing, and similar typos.
* **B. Grandfathering is by exact filename, not by number.** A new unstamped file under a colliding
  grandfathered number is RED; this project has real cross-clone collisions (1349–1353). Files in
  the issues directory that look like issue files but miss the canonical name pattern are named.

**Recorded as a limit, not fixed:** a checkout whose own path is not valid UTF-8. It is falsely red
in both locales, partly because this box's `timeout` (uutils) refuses non-UTF-8 argv. UTF-8 paths
(café, 日本, emoji) are green. It goes into the spec's limits section.

**After S1-fix7, only a finding in class A or a regression blocks a commit.** A new class-B
near-miss becomes a follow-up issue, because the committed state will already be far ahead of what
it replaces.

---

# D20 — Item 2 commits after round 3; round 4 takes the remaining kill-identity edges (driver)

**Round 3 stands.**
* The regression refuter could **not** refute it.
* The independent prover measured, on seeded and empty canaries, every documented entry point
  the G2 guard lists (22 armed launchers). T1 was 87/86/0, per case identical to baseline, and
  the canary stayed byte-identical in every shape except D13.2's scoped auto-start files.
* The kill-window recipe left 0 of 20 on both paths (r2base: 12 and 14 of 20).
* `devdisplay.sh stop` spares decoys.

The safety refuter's remaining findings are, by its own measurements, **present identically in
the committed base**. `devdisplay.sh stop` kills a recorded WM by argv[0] alone, and a dead
`xvfb.pid` still reaches the kills. `spawn_reaper`'s orphan sweep ignores the recorded display.
Its other findings were a lower-severity opt-in, forgeries (a custom dir's deeper symlinks; a
throwaway-shaped HOME planted under `/tmp`), `winshot.sh`'s standalone build cache in
`~/.cache`, and G2's textual and `tests/`-only scope (`doc/claude/…/xarm.sh`). So, by D19's
rule, Item 2 commits now, and round 4 follows.

**The gate is run against a COPY of the real home, not the real one.** Running T1 with
`HOME=/home/analog` was refused by the session's permission check. That is a reasonable
place for the user to decide, so it is theirs to run or allow. The main-tree gate therefore
uses a canary copied from the real `~/.xschem`, `.gitconfig` and `.ngspice_history`, with
the dev display pinned to scratch `:141`. It must leave the canary byte-identical. **What
only a real-home run can show** is attach to and auto-start of the user's own `:99` through
their real state dir. It is recorded as owed to the user, with the exact command.

**Round 4 (S2c-R4):**
1. `devdisplay.sh`: kill a recorded WM only if its `/proc` environ `DISPLAY=:N` (and HOME) match
   the state; short-circuit on a dead `xvfb.pid` (`_pid_of` tests liveness). Rows for the
   round-3 regression refuter's S1 and S3 sabotages, which went green.
2. `spawn_reaper` orphan sweep: require the recorded display to match the killed process's
   `DISPLAY`/cmdline.
3. `winshot.sh` build cache goes to a gitignored directory in the checkout, not
   `~/.cache`.
4. Nesting applies D17.5's escape check, so a planted throwaway-shaped HOME whose `.xschem`
   leads out is refused. D17.5 also walks `.cache` and one more level of `.xschem`.
5. T1's private-arm residual window: the reaper can find the server before `.xvfb.pid` is
   written, by an inherited tag, as the shell does. S14 gets a deterministic row.
6. G2 widens its scope to the whole repository's scripts, and recognises a variable-held
   binary path, or records why it cannot. `doc/claude/signal_browser_2pane_batch/xarm.sh` is
   either armed or allowlisted, with its reason.
7. Recorded, not fixed: `test_wave_markers` hangs when `run_suites.sh` attaches to a persistent
   dev display (identically in base). It goes into CLAUDE.md.
