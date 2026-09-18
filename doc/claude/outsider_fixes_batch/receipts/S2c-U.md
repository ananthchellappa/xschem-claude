# S2c-U — the suite side of Item 2 (D9, D10)

Crew: S2c-U, 2026-09-18. Clone `/var/tmp/xschem_fixes/s2c_U/tree`. Baseline clone for per-case
attribution: `/var/tmp/xschem_fixes/s2c_U/base`. Both are `fluid-editing` at **`bc61cd05`**, plus S1's
two issue-stamp files, built with `./configure && make -j8`.
Deliverable: `/var/tmp/xschem_fixes/s2c_U/final.patch`, md5 `9f049a4c895301d35d16e90acb067eaa`,
10 files. It applies cleanly to `bc61cd05` (`git apply --check` in a fresh clone).

Tags: **MEASURED** means I ran it and quote the output. **READ** means taken from source.
**INFERRED** means reasoned but not tested.

## What changed

| file | change |
|---|---|
| `tests/headless/scratch.tcl` | **D9.** `__scratch_home_armed` implements D9's rule exactly. A run is armed when HOME's basename matches `^xschem-test-home\.[0-9]+\..+$` and `XSCHEM_TEST_REAL_HOME` is set, or when `XSCHEM_TEST_HOME` is set. An empty value counts as unset. An un-armed run prints one line to stderr, once per process: `note: this suite is using your real HOME; tests/headless/run_suites.sh <name> gives it a throwaway one`. **D10.** `test_real_home` returns `XSCHEM_TEST_REAL_HOME` only when it is an absolute, existing directory, and otherwise returns HOME. It is for read-only lookups. |
| `test_ase_converge_1459.tcl`, `test_ase_sp_1452.tcl` | The fork is looked up via `[test_real_home]`. Their "no executable" lines now use the `skip: EE/<tag> -- …` / `skip: SE/<tag>` / `skip: SE3/<tag>` form. |
| `test_vcd_read.tcl` (A, RP), `test_vcd_time_base.tcl` (REF), `test_ase_cosim.tcl` (REF12) | Fixtures come from `[file join [test_real_home] .xschem simulations …]`. The old `SKIPPED:` and `note: group REF not run` lines are now `skip: <row> -- <path consulted> …`. |
| `test_launch_context.tcl` | When HOME is a harness throwaway (the pattern plus `XSCHEM_TEST_REAL_HOME`, and `XSCHEM_TEST_HOME` not set), the suite copies `$REAL/.xschem/geometry` into the throwaway's own `USER_CONF_DIR` and re-runs the product's `set_geom .`. The real file is only read, by that copy. The copy lands only inside the throwaway HOME, and otherwise the suite prints `skip: real-geometry -- …`. A custom `XSCHEM_TEST_HOME=<dir>` is never substituted. The size row's detail now says `from=<file or startup>`. |
| `spawn_reaper.sh` `_reaper_devdisplays` | Reads `${XSCHEM_TEST_REAL_HOME:-$HOME}/.claude/xschem_dev_display/display`, and still reads `$HOME`'s file too. |
| `test_gui_gate_batch.sh` | R8 refuses `${XSCHEM_TEST_REAL_HOME:-$HOME}`. It prints `skip: R8 -- …` when that path is itself under a temp root. R7's `DEVDPY` and the dev-display relocation guard (`:74`) read the real home. |
| **new** `test_scratch_home_note.tcl` | Locks D9 and D10 in 20 checks. **N1–N10** run an armed matrix in children with controlled env. **R1–R5** cover `test_real_home`. **C0–C4** feed the note a real child printed, plus each D10 suite's `skip:` template taken from its source with hostile values substituted, through each reader's own code: T1's `summarize_all` (extracted from `run_regression.tcl` and evaluated), `banner_rule.tcl`, `full_audit.sh`'s `classify` via `AUDIT_LIB_ONLY`, and `run_suites.sh`'s EREs (extracted). **Not registered in T1**, because `run_regression.tcl` belongs to crew T. The driver decides. |

## Proof

### Test setup

* **HOME:** `/var/tmp/xschem_fixes/s2c_U/homes/xschem-test-home.<pid>.<tag>`, created fresh with a mode-700 `.xschem` inside.
* **XSCHEM_TEST_REAL_HOME:** a seeded copy, `realcopy/`, holding:
  * `.xschem/geometry`, a copy of the real one (101 lines);
  * `.claude/xschem_dev_display/display` (`:99`);
  * `dev/ngspice`, a symlink to `/home/analog/dev/ngspice`.
* **Other environment:** DISPLAY unset, `TMPDIR` set to scratch, `XSCHEM_TEST_SCRATCH` lowercase (see deviations).

### Read-only proof

Every copy is recorded with `find -printf '%p %y %s %T@ %m %l'` plus an md5 of every file, before and after:

* **`realcopy`:** byte-identical after every run (MEASURED `realcopy-IDENTICAL-final`).
* **`realcopy_vcd`:** byte-identical after two rounds of the vcd suites (MEASURED). It is `realcopy` plus a **synthetic** `counter.vcd` and a `tb_counter_wrapper_ase.raw` from ngspice, both built to the rows' contracts. The real home has neither file (MEASURED `ls`), and nowhere on the box has them (MEASURED `find /`).
* **`realcopy_poison`:** byte-identical (MEASURED).
* **`/dev/shm/s2cu_real`:** byte-identical after `gate_tree` and `gate_base` (MEASURED).
* **The fork's real tree:** `find /home/analog/dev/ngspice -newer <marker>` prints nothing, so nothing was written through the `dev/ngspice` symlink (MEASURED).

### Headless arm, armed shape: tree against base (base = the change reverted)

| suite | tree | base |
|---|---|---|
| converge_1459 | **ALL PASS (76)**, EE legs apt 6 + fork 6 | ALL PASS (70), `SKIPPED: EE fork leg` |
| sp_1452 | ALL PASS (58), apt + fork (fork2 deduped, same binary) | ALL PASS (58), apt + fork2 |
| vcd_read (no fixture / synthetic) | 156 / **187** (A 21 + RP 10 run) | 156 / 156 |
| vcd_time_base (no fixture / synthetic) | 112 / **124** (REF1–12) | 112 / 112 |
| ase_cosim (no fixture / synthetic) | 341 / **342** (REF12) | 341 / 341 |
| scratch_home_note | ALL PASS (20) | its files un-fixed: **18 FAILED (2 passed)** |

Every verdict is ALL PASS on both sides. The fixture rows grow only in the tree, so the counts drop with the change reverted. With the fixtures absent, the tree's `skip:` lines name the path they checked. For example: `skip: A -- no reference at /var/tmp/xschem_fixes/s2c_U/realcopy/.xschem/simulations/counter.vcd … so group A did not run`. The base's lines name the throwaway instead.

### GUI arm, on my fixture Xvfb `:170`

**test_launch_context**

| real geometry | tree | base |
|---|---|---|
| copy of the real file | ALL PASS, `from=…/realcopy/.xschem/geometry` | ALL PASS, from startup |
| **poisoned** (`untitled.sch 250x150+200+200`) | **1 FAILED** (`geom=250x150+200+200`) | ALL PASS (blind) |

In the poisoned row the suite catches the poisoned real config it exists for, and the base cannot see it. A custom `XSCHEM_TEST_HOME` holding the poisoned file gives `1 FAILED … from=startup`, which shows the custom home is honoured and not substituted (MEASURED).

**test_gui_gate_batch** (`GUI_GATE_DIR` set to scratch; the stand-in real home was `/dev/shm/s2cu_real`)

* **Tree:** `fails=1`. **R7 ok, R8 ok** (`(the real home, /dev/shm/s2cu_real)`).
* **Base:** `fails=3`. **R7 FAIL and R8 FAIL.** Under a throwaway HOME the dev-display guard goes blind, and `reaper_init "$HOME"` accepts the `/var/tmp` throwaway.
* **Sabotages:**
  * Only the reaper change reverted: **R7 FAIL**.
  * `reaper_init` sabotaged to accept `/dev/shm`: **R8 FAIL**. It also wrote a `.reaper_owner` into the stand-in real home. That is the hazard R8 guards against, and it is why the stand-in was not the real home. I deleted the stamp.
  * Real home under a temp root: `skip: R8 -- …`.
* The remaining red, V4/V7/V8, is identical on both sides (see open problems).

**test_gui_gate_revive** also sources the reaper. Tree and base are row-identical: `fails=5` each, all X1/X2 (MEASURED).

### T1 in the unarmed shape: tree against base, concurrent

**Setup:**

* HOME was a plain directory with no `XSCHEM_TEST_REAL_HOME`, so the note fires in the tree.
* The display arm ran on `:171` and `:172` through scratch `XSCHEM_DEVDISPLAY_DIR`s and was stopped afterwards (`devdisplay: stopped :171/:172`).

**Trailers:**

* tree: `T1-RUN-END … cases=85 blocks=84 counted_failures=10 elapsed=381s`
* base: `T1-RUN-END … cases=85 blocks=84 counted_failures=10 elapsed=382s`

**Per case, identical on both sides:**

* The 4 F14 segfault suites: `test_op_annot`, `test_ase_optier_0963`, `test_unused_attr_0970` and `test_auto_specialize_1201`, 2 lines each.
* `test_label_ride` W2. I caused this one: its W2 asserts that the scratch root is `.scratch`, and I pointed `XSCHEM_TEST_SCRATCH` elsewhere.

The two verdict bodies differ only in that W2 detail (`{t1_tree}` against `{t1_base}`).

**What the note did:** it was present in **50 hcase logs and all 11 dcase logs** of the tree and in 0 of the base. None of those lines was counted, and no gold comparison changed, since the netlisting cases' blocks are identical.

**run_suites.sh on the unarmed shape:** `run_suites.sh --nogui` with `AUDIT_DISPLAY=none` and a plain HOME, so the note is printed: `PASS test_vcd_read (156)`, `PASS test_ase_cosim (341)`, `RESULT: 2/2 runs passed`.

### Red-first sabotage of the new suite

Each sabotage was applied to a copy of the tree. The rows that went red:

| sabotage | red rows |
|---|---|
| no print | N1 N3 N4 N7 N8 N9 N10 C0 |
| unconditional print | N2 N5 N6 |
| print to stdout | N1 N3 N4 N7 N8 N9 N10 C0 |
| line ends `: FAIL` | N9 C1 |
| `FATAL` or `SKIP: no X connection` prefix | N rows + C0 |
| opt-out clause dropped | N5 N6 |
| once-guard dropped | N10 |
| `XSCHEM_TEST_REAL_HOME` term dropped | N3 |
| loose pattern | N8 |
| unvalidated real home | R3 R4 |
| a skip template ending in its variable | C1 |
| embedded `\nFAIL:` / `\nRESULT: SKIP` in a template | C3 C4 |
| embedded `\nFATAL: signal 11` | C1 C2 C3 C4 |

## Deviations

1. **HEAD was `bc61cd05`, not `4b9565ad`.** S1's patch hunk for `DECISIONS.md` no longer applies, so I applied only its `tests/*` hunks (`git apply --include='tests/*'`).
2. **The scratch root lives outside my stage dir**, at `/var/tmp/xschem_fixes/s2cu/`, set through `XSCHEM_TEST_SCRATCH`. The assigned dir name `s2c_U` has an uppercase letter, which trips D12's uppercase-path confound. MEASURED: under `s2c_U`, converge EE5 and sp SE1 are red in both tree and base, and in the lowercase root both are green.
3. **Existing skip lines were rewritten into D10's `skip:` form**, rather than new ones being added. The old lines already printed; the rewrite gives readers one shape to grep. Nothing in the tree reads the old wording (READ via grep).
4. **The reaper guard reads the real home's state file and `$HOME`'s**, a superset of D10's single path, so the guard can only get stricter.
5. **`test_scratch_home_note.tcl` is a new file.** It is outside my listed files, and it is the lock for D9 and D10.
6. **R8 gained a `skip:` branch** for when the real home is itself under a temp root.
7. **`test_launch_context` does not source `scratch.tcl`**, so it inlines D9's armed test. Its substitution excludes `XSCHEM_TEST_HOME`, deliberately.
8. **`test_gui_gate_batch` R12 starts and reaps its own Xvfb on `:160` and `:159`**, its own 150–160 band, which is outside my 170–179. That is built into the suite the task told me to run. R12 reaped both (`ok`).

## Open problems

* **test_gui_gate_batch V4/V7/V8 are red on this box on both sides, and the cause is not HOME.** `/usr/bin/sleep` links to uutils' multicall `/usr/lib/cargo/bin/coreutils/sleep`, so the `cp`'d `xschemselftest` exits in 0.1 s. There is then no brake target. MEASURED: `elapsed=.105794462` for `xschemselftest 2`. The fix is small, a `bash -c 'sleep N; :'` under `exec -a`, and I left it out of scope.
* **test_gui_gate_revive X1/X2 (5 rows) are red on both sides.** Not investigated.
* **Leaked children of those suites:** R9's impostor `sleep 60` and revive's `sleep 300` survive their reap. I killed them.
* **Suites hard-code `/home/analog/dev/ngspice`:** sp_1452 fork2, trnoise_1466/1467 and about 20 ASE suites (READ). This does not depend on HOME, but it is hostile to strangers.
* **`test_gui_gate_revive.sh:63` has the same `$HOME/.claude` fallback.** It is not mine, and it is harmless while D7 always carries `XSCHEM_DEVDISPLAY_DIR`.
* **`test_devdisplay.sh` was not run.** It also consumes the reaper, but it uses displays `:85`–`:96`.
* **15 `/tmp/xschem_emergencysave_*` appeared during my window, and I left them.** Paired timestamps inside my concurrent T1 window suggest the F14 segfaults made about 8 of them (INFERRED), but I cannot prove it.
* **A child given its own fake HOME under an armed parent would print the note**, because its HOME basename is not the pattern. READ: no HOME-switching suite's child sources `scratch.tcl` today.
* **Registering `test_scratch_home_note` in T1's `hcases` is for the driver or crew T.** It takes about 3 s.

## Real home

* `md5sum -c --quiet …/xschem_manifest_fixes.md5` gave **rc 0** before and after.
* `find /home/analog/.xschem /home/analog/.claude/xschem_dev_display /home/analog/.claude/gui_test_gate -newer START_MARKER` printed **nothing**. The marker was touched at 01:34:49 -0700.
* I did not touch `:99`, its state dir or the gate dir.
* No process with a HOME of mine is left. My `:170` Xvfb and the T1 dev displays on `:171` and `:172` were stopped, and their locks are gone.
* `/dev/shm/s2cu_real` was removed.
* Nothing was committed.
