# Receipt — item A (issue 1485), VERIFY: the two adversarial reviews and what happened

Two verifiers (`reproduce`, `completeness`) returned **12 findings** against the implement
round. Every one was re-measured here before it was acted on. **7 applied, 1 applied by a
different mechanism than the one proposed, 1 applied in its "at minimum" form, 3 rejected**
(2 of them out of item A's scope and written down for the driver, 1 a nit the verifier
itself closed).

Fixer, 2026-09-20. Tree at start: `bbc9de1a` + the implement round's 7 uncommitted files.

The conditions used throughout — all three trees rebuilt from scratch
(`./configure`, `timeout 900 make -C src -j8`, rc 0, `src/xschem` 1 688 064 bytes in each,
byte-identical in size to the developer clone's):

| name | what it is |
|---|---|
| **export** | `git archive --format=tar HEAD \| tar -x` into an empty directory |
| **nogit** | `git clone --no-hardlinks`, then `rm -rf .git` |
| **clone** | `git clone --no-hardlinks`, `.git` KEPT — the throwaway checkout for the destructive git experiments, so the developer's own clone was never touched |
| **main** | `/home/analog/dev/xschem-claude`, the developer's clone — the no-regression baseline |
| **inner** | the export, inside a `git init`'d parent, with and without part of it `git add -f`'d |

⚠ **The trees are under `…/stranger_reds/a_fix/`, not the assigned `…/stranger_reds/A/`,
for the reason the implement receipt gives in its §1**: an uppercase letter in the checkout
path is **issue 1484** and reds `test_ase_sp_1452 SE1` and `test_ase_variant_1470 OT1` on
its own. Logs and scripts stayed under `A/`. This was re-confirmed by accident — see
finding R6 below.

Every suite run the way T1 runs an `hcase`:

```sh
AUDIT_DISPLAY=none GUI_GATE=0 SUITE_TIMEOUT=900 \
  timeout 1000 <tree>/tests/headless/run_suites.sh --nogui <suite>
```

---

## The verdict table

| # | from | sev | what it said | verdict |
|---|---|---|---|---|
| R1 | reproduce | blocker | the fs arm counts a user's own `.state`, so exact-count rows red | **APPLIED** — 4 rows floored |
| R2 | reproduce | must | `glob -nocomplain` raises on an unreadable directory; the suite dies | **APPLIED** — both globs caught |
| R3 | reproduce | should | git's non-empty answer trusted even when it is somebody else's repo's | **APPLIED, other mechanism** — the proposed union would have defeated C1 |
| R4 | reproduce | should | the `note:` never reaches `run_suites.sh` | **APPLIED** + the receipt claim narrowed |
| R5 | reproduce | should | symlinked directories silently dropped | **APPLIED in its "at minimum" form**; following them rejected |
| R6 | reproduce | should | a path with a SPACE reds 5 suites, 71 rows — issue 1484's real mechanism | **REJECTED for item A, FILED for the driver** (mechanism located) |
| R7 | reproduce | nit | a read-only checkout dies in `test_scratch`, not in the corpus | **REJECTED** — the verifier closed it itself; noted for the driver |
| C1 | completeness | must | "git listed nothing" masks a corpus that stopped being tracked | **APPLIED** |
| C2 | completeness | must | the two `ST1` rows assert exactly 104 | **APPLIED** (same edit as R1) |
| C3 | completeness | should | provenance invisible through the documented driver | **APPLIED** (same edit as R4) |
| C4 | completeness | should | the fs arm silently answers ZERO for dot-file patterns | **APPLIED** |
| C5 | completeness | nit | the git arm costs ~37× the code it replaced | **ACCEPTED AS IS**, and it now costs a little more |

---

## R1 + C2 — the exact-corpus assertions (blocker / must) · APPLIED

**Re-measured, and it is worse than the two rows C2 named.** Four rows, not two, and the
trigger is ordinary first use of the branch: open a shipped ASE-L testbench, save a
variant, run the tests.

In **nogit** (fs arm), with the implement-round code:

| what was added | measured |
|---|---|
| one `.state` copied to `tb_bandgap/my_debug/` (104 → 105 on disk) | `test_ase_variant_1470` `1 FAILED (75 passed)` — `ST1 … -> {105 {} 1 1} (exp {104 {} 1 1})`; `test_ase_simwin_variant_1471` `1 FAILED (11 passed)` — the same row. The other seven green. |
| the shipped `test_nmos` bench copied to a second run directory | `test_ase_predeck_1439` `1 FAILED (77)` — `RD10 … -> {6 0 6} (exp {5 0 5})` |
| the shipped `test_stdcells` bench copied to a second run directory | `test_ase_options_1437` `1 FAILED (74)` — `DL5 … -> {2 {acct list} 0} (exp {1 {acct list} 0})` |

**DL5 was the one the verifier asserted rather than measured, and it reproduces.** It needs
a *particular* shipped bench (the only one carrying an inert option), which is why the
first two copies did not move it.

**Applied**, in the form the verifier asked for — a floor on the count, the shape halves
left exact, matching the idiom `test_ase_core` CP1/CP7 and `test_ase_trnoise_1466` NC1
already use on purpose:

| row | was | is |
|---|---|---|
| `test_ase_variant_1470` ST1 | `{104 {} 1 1}` | `[expr {$tracked >= 104}] …` → `{1 {} 1 1}` |
| `test_ase_simwin_variant_1471` ST1 | `{104 {} 1 1}` | the same |
| `test_ase_predeck_1439` RD10 | `[list $n $bare $valued]` → `{5 0 5}` | `[list [expr {$n >= 5}] $bare [expr {$valued == $n}]]` → `{1 0 1}` |
| `test_ase_options_1437` DL5 | `[list $files …]` → `{1 {acct list} 0}` | `[list [expr {$files >= 1}] …]` → `{1 {acct list} 0}` |

**What is NOT weakened.** `bad` is still exactly `{}`, so a 105th file still has to
round-trip byte for byte. Both ST1 controls stay exact. RD10's `bare` stays exactly `0`
and `valued == $n` is *stronger* than `valued == 5` — it holds every bench to rendering
the value, not just five. DL5's option-name set stays exactly `{acct list}`, so a **new**
inert option anywhere still reds it, and `wn` stays exactly `0`.

⚠ **One thing IS given up, and it is DL5's.** The row no longer catches *a second bench
carrying the same two inert rows* — its "exactly one" became "at least one". The option
names and the wnflag count carry the rest of its meaning. The alternative was to branch the
row on `source`, which would have made the developer's condition and the stranger's
measure different things; that seemed worse than one named, bounded loss. **Recorded for
the driver rather than decided quietly.**

**Green after**, in nogit with all three stray benches present (107 on disk): all nine
`ALL PASS`, **1284 checks**, the same count as a clone.

---

## R2 — the walk could RAISE (must) · APPLIED

**Re-measured, exactly as reported.** One `chmod 000` directory at the top of the export:

```
PROBE RAISED: couldn't read directory ".../nogit/zz_unreadable/": permission denied
```

and at suite level, through the armed driver, on the implement-round code:

```
test_ase_core            NORESULT | test_ase_core         run 1/1 (exit 10 — binary never reported)
test_ase_variant_1470    NORESULT | test_ase_variant_1470 run 1/1 (exit 0 — binary never reported)
test_ase_sp_1452         NORESULT | test_ase_sp_1452      run 1/1 (exit 0 — binary never reported)
```

**This is the failure shape item A exists to remove, reintroduced by the fix's own new
code**, and for `test_ase_sp_1452` it was a *new* way to die (under the original defect
that suite only failed one row).

**Applied.** Both globs in `__corpus_walk` are now `catch`ed. An unreadable directory is
not a raise and not a silent hole either: it is appended to a `skipped` list that the dict
carries and the `note:` line names. After:

```
test_ase_core         PASS | ... ALL PASS (675 checks)
  | note: corpus-source -- ... -- 104 file(s) found, 1 directory not read or not followed (zz_unreadable)
```

all three `PASS`, full counts.

---

## C1 — "git listed nothing" masked a real defect (must) · APPLIED

**Re-measured.** In the built **clone**, after `git rm --cached -q -- '*.state'` (files
untouched on disk):

| code | result |
|---|---|
| **pre-item-A** (the tree at `HEAD`) | **10 counted failures across 5 suites** — `test_ase_core` `CP1 CP2 CP3 CP4 CP7 CP7c`, `test_ase_sp_1452` `SC1`, `test_ase_variant_1470` `ST1`, `test_ase_simwin_variant_1471` `ST1`, `test_ase_trnoise_1466` `NC1` |
| **implement round** | probe: `source=fs n=104`. Suites: **`ALL PASS (675 / 58 / 76 / 12 / 80)`** — every row whose name says "tracked" passing by measuring untracked files |
| **this round** | probe: `source=git n=0`. Suites: **the same 10 rows red**, and each verdict now carries `note: corpus-source -- … came from git, and git lists NOTHING: git tracks this checkout and lists NO file matching *.state -- the corpus is not tracked here` |

⚠ **The implement-round arm was measured, not assumed.** Its semantics were reconstructed
in the throwaway clone's copy of `scratch.tcl` alone (fall through to the walk when git
answers empty) and the five suites re-run; the file was restored by `sync` and md5-checked
afterwards.

**Applied, but NOT by the discriminator the verifier proposed.** It suggested a second bare
`git ls-files` with no pathspec. That works for C1 and does nothing for R3. One check
serves both: **ask which repository git is answering about.**

```tcl
__corpus_git_scope $repo   ->  self | other | none      ;# cached per repo
```

`git -C $repo rev-parse --show-toplevel`, compared to `$repo` by normalized name and then
by device+inode.

* **`self`** — `$repo` IS the root of a checkout. git's answer is authoritative **including
  when it is empty**, which is C1's fix.
* **`other`** — git works but its toplevel is somebody else's, which is R3's fix.
* **`none`** — no `.git`, no git, or a refusal. Filesystem arm. This is the ZIP/tarball/
  `git archive` shape the whole item is about.

Measured across all six shapes:

| shape | before | after |
|---|---|---|
| export, no `.git` | `fs 104` | `fs 104` |
| nogit + 3 user benches | `fs 107` | `fs 107` |
| clone | `git 104` | `git 104` |
| clone, corpus untracked | `fs 104` ⚠ masked | **`git 0`** + loud note |
| export inside a repo tracking NOTHING of it (the implement round's §6) | `fs 104` | `fs 104` |
| export inside a repo tracking PART of it | **`git 50`** ⚠ silent | **`fs 104`** |
| clone, git refusing (`fatal: detected dubious ownership` shim on PATH) | `fs 104` | `fs 104`, reason names the refusal |

**Sabotage S3** proves the scope check is load-bearing: `__corpus_git_scope` forced to
answer `self`, in the partial inner-repo shape, reds `CP1 CP4 CP7`, `ST1` and `SC1` — the
item-A shape exactly. With the check, those rows pass.

---

## R3 — a partial answer from an enclosing repository (should) · APPLIED, other mechanism

**Re-measured**: outer repo `git init`, `git add -f export/sky130A` only →
`source=git n=50 reason={}`. 54 corpus files invisible, no note, and the suites then red
with nothing explaining why.

**The proposed fix was rejected and the defect fixed anyway.** The proposal — "also run the
walk and prefer the union, or take the fs answer when it is strictly larger" — **directly
defeats C1**, which is a `must`: in the untracked-corpus clone the walk answers 104 and the
union would mask the defect again, and C1's own text says a *partial* untrack still reds
today only because the list is non-empty. A union makes that red vanish too. The scope
check above handles both, and it costs one cached `exec` rather than a full walk on every
call.

Also applied from this finding: **`lsort -unique`** on the git arm, for the conflicted-index
half (an unmerged path is printed once per stage).

---

## R4 + C3 — the note never reached the documented driver (should) · APPLIED

**Re-measured, and the receipt's claim was wrong as written.** `run_suites.sh` captures the
suite's stdout and prints only `^skip:` lines, plus `^(FAIL|FATAL)` on a failure. A `note:`
on a PASS is discarded, so an export's log was:

```
PASS     | test_ase_core   run 1/1  RESULT: ALL PASS (675 checks)
```

— indistinguishable from a clone's.

**Applied**, in `run_suites.sh`, one line beside the `skip:` echo, with D13.11's own
argument applied to provenance. **The note's prefix changed to `note: corpus-source --`**,
because a bare `^note:` cannot be echoed: `note:` is this repo's general diagnostic prefix
and `test_ase_core` alone prints **17** of them, which would bury the verdict.

After, in the export:

```
PASS     | test_ase_core   run 1/1  RESULT: ALL PASS (675 checks)
         | note: corpus-source -- the committed .state corpus listed from the filesystem,
                 not git: no .git in <export> ... -- 104 file(s) found
```

**9 of 9** suites print it in the export; **0 of 9** in the clone. `test_home_isolation_sh`
row **S1**, which asserts the exact two lines after a verdict, still passes (`ALL PASS (90)`),
as does `test_audit_classifier` C44/K18, which pin `run_suites.sh`'s other regexps
(`ALL PASS (75)`).

**Not done, and named as not done:** C3's preferred form — provenance inside the `RESULT:`
banner, as `test_issue_stamp` does — would survive into `results.log` itself. It needs nine
banner edits under a rule (`banner_complete`) that three separate readers police, and it is
a bigger change than this round should make. **Filed for the driver.** The T1 per-case log
already carries the note today; the T1 *verdict* does not, which is issue **1487**'s
subject (item E).

---

## R5 — symlinked directories (should) · APPLIED in its "at minimum" form

**Re-measured**: an export whose `tests/` is a symlink to a sibling directory probes
`source=fs n=103` — one corpus file lives under `tests/headless/fixtures`.

**Applied: the walk now counts what it did not read or follow, and the note says so.**

```
note: corpus-source -- ... -- 103 file(s) found, 1 directory not read or not followed (tests)
```

**Rejected: actually following directory symlinks.** git does not follow one either —
`git ls-files` reads the index — so following would make the fs arm diverge from the git
arm in a *third* direction, and a loop-safe walk needs a visited-inode set whose failure
mode (wandering into a symlinked PDK) is worse than the miss. The verifier offered this
alternative itself and called the `tests/` case contrived. What matters is that a short
corpus is never silent, and now it is not.

---

## C4 — dot entries silently answered ZERO (should) · APPLIED

**Re-measured**, clone (git arm) vs export (fs arm), implement-round code:

| pattern | git | fs |
|---|---|---|
| `*.yaml` | 2 | **0** |
| `.github/*` | 2 | **0** |
| `*.gitignore` | 8 | **0** |
| `*.spiceinit` | 5 | **0** |
| `*.state` | 104 | 104 |

Two causes, of which the header documented only one: the explicit "skip every directory
starting with `.`", and Tcl's `glob *`, which never matches a dot **basename**.

**Applied.** Both globs now take `* .*`, drop `.` and `..`, and skip only `.git` and
`.scratch` **by name**. After the fix all five patterns agree exactly: `2/2 · 2/2 · 8/8 ·
5/5 · 104/104`. (`src/*.c` answers `37` git / `40` fs — the three bison/flex outputs a
build leaves behind. That is the declared superset, not a bug.)

No live caller moved: `*.state` is 104 either way, and the nine suites keep their 1284
checks.

---

## C5 — cost (nit) · ACCEPTED AS IS, and it went up

Measured, three consecutive calls in one process on the built trees:

| arm | call 1 | call 2 | call 3 |
|---|---|---|---|
| clone, git | 208 ms | 105 ms | 104 ms |
| export, fs | 198 ms | 88 ms | 87 ms |

The extra ~100 ms on the first call is the `rev-parse` scope probe, which is **cached per
repo**, so the second call in `test_ase_core` pays nothing for it. Roughly **+1 s over the
nine suites**; invisible in their wall times. The `timeout` fork remains the dominant cost
and the bound stays, for row `W13`'s reason.

---

## R6 — a path with a SPACE (should) · REJECTED for item A · **FILED FOR THE DRIVER**

Out of scope by the verifier's own words (*"Do not fix it inside item A"*) and by PLAN.md
criterion 4. Not fixed. **Independently re-confirmed here, twice over, and the mechanism is
now located** — which is what issue 1484 is missing.

* **Re-confirmed by accident.** The `S3` sabotage ran in a tree under
  `…/stranger_reds/**A**/inner/export` — one uppercase letter. The *unsabotaged* control
  run there was `test_ase_sp_1452` `2 FAILED` (`SE1/apt`, `SE1/fork`) and
  `test_ase_variant_1470` `1 FAILED` (`OT1`), while the **same code and the same binary**
  at the lowercase `…/a_fix/export` were `ALL PASS (58)` and `ALL PASS (76)`. Exactly the
  two rows issue 1485 records as "did not reproduce / UNKNOWN", and exactly the ones the
  implement receipt's §7.1 pinned on 1484. ⚠ Caveat: that tree was a `cp -a` of a tree
  built elsewhere, so it is corroboration, not a clean two-build experiment; the implement
  receipt's §7.1 is the clean one.
* **The mechanism.** `src/ase.tcl`, `ase::sp_export_lines` builds an ngspice control line
  as `"wrs2p [s2p_file $state $idx]"` — **the path is interpolated onto the control line
  with no quoting**. A space splits it into two arguments; ngspice's own case handling
  explains the uppercase variant. That makes 1484's inference concrete: the trigger is not
  "a capital letter", it is **an unquoted path on an ngspice control line**, of which a
  space is the cheaper and larger reproducer. Cite `ase::sp_export_lines` by name, not by
  line.

**Recommendation to the driver:** widen issue **1484** (item C) from "a capital letter" to
"an unquoted path on an ngspice control line", and add the space reproducer and
`ase::sp_export_lines` to it. A stranger who unpacks the ZIP under a directory with a space
in its name hits it.

---

## R7 — a read-only checkout (nit) · REJECTED · noted for the driver

Nothing for item A, as the verifier itself concluded. Re-stated for the record: the corpus
helper is read-only-safe (the fs arm answers 104 against a `chmod -R a-w` tree), and what
dies is `test_scratch` and `state_roundtrip.tcl`'s tmp file, both of which write inside the
checkout. A read-only tree also cannot be built, so nothing can run there anyway. If anyone
ever wants it, the scratch root and that tmp file move to `TMPDIR` — **a separate item**.

---

## What the driver still has to decide or file

1. **DL5 lost "exactly one bench"** (R1 above). Named, bounded, and the alternative was
   worse. A one-line ruling if the driver disagrees.
2. **Issue 1484 / item C should be widened** to "an unquoted path on an ngspice control
   line", with the space reproducer and `ase::sp_export_lines` (R6).
3. **Provenance in the `RESULT:` banner** rather than only under `run_suites.sh`'s verdict
   (C3's preferred form) — nine banner edits, adjacent to item E / issue 1487.
4. **A read-only checkout** needs the scratch root and `state_roundtrip.tcl`'s tmp file in
   `TMPDIR` (R7) — a separate item if anyone wants it.
5. **`full_audit.sh` does not echo the note either.** Not changed here: it is a different
   reader with its own EREs, and `test_audit_classifier` section K locks parts of it. Same
   one-line shape if the driver wants it.
