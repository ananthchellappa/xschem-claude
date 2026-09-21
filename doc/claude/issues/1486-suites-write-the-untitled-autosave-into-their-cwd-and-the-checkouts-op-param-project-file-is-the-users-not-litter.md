# 1486 — suites write xschem's untitled autosave into their cwd, and the checkout's op_param project file is the user's, not litter

**STAMP:** `v1 claim=partial tree=c84aee78 stamped=2026-09-20 fix=partial open=4 by=stranger-reds`

⚠ **Status: STILL OPEN, and more of it landed — `c84aee78`, 2026-09-20**, stranger-reds
batch item F. The product half is fixed (a discard no longer deletes a `~` this session
never wrote) and the three **shell** drivers redirect the autosave into a private `$PWD`.
**`tests/run_regression.tcl` was never armed, so T1 itself still writes
`tests/untitled~.sch` on a green run**, and 38 of the 405 suites swept still overwrite a
pre-existing one in whatever directory they were run from. Read **Resolution** at the foot
before acting on anything above it; `open=4` counts the items listed there.

**Originally filed 2026-09-18** by the outsider-fixes batch, stage F
(docs crew), from `doc/claude/outsider_fixes_batch/DECISIONS.md` D12 and D13.3. **Class**
harness writes outside its scratch. (`open=2` when filed; the count is **4** now — the
Resolution's list supersedes the "Still open" section below.)
**Related, read first:** **0609** (the `untitled~.sch` leak is 80 suites wide), **1480**
(nothing sweeps the `untitled*` residue class), **0673** and **0687** (two producers),
**0060** (why untitled buffers are backed up on purpose), **1381** Part 2 (a user's
op_param settings file destroyed as "litter" once already), **1273** (which directory is
the project).

⚠ **READ THE SECOND HALF BEFORE ACTING ON THE FIRST.** DECISIONS D12 listed the op_param
project tier, `.xschem/op_param_lists.conf`, under "suites write into the cwd", adding that
*"this checkout's root has carried one since 2026-09-09"*. **That file is the user's own
Save, not test litter**, and reading it as litter is how one was quarantined on
2026-09-07 (issue 1381). This issue files the D12 line **corrected**. It is not
evidence against the file.

---

## Half 1 — the untitled autosave (`untitled~.sch`), MEASURED

xschem backs up an unsaved untitled buffer as `untitled~.sch` **in the current
directory**, deliberately (issue 0060, `write_backup()` in `src/save.c`). A suite that
leaves an untitled buffer therefore drops the file wherever it was run from. The leak's
breadth is 0609's subject and its sweep is 1480's. What this batch added:

* **With cwd = the tester's HOME, a documented command destroyed the tester's own
  autosave.** MEASURED by the S2c safety refuter (`receipts/S2c_refute_r1.md`, runs
  `cwd2_*`): `run_suites.sh` run from `~` **overwrote** a pre-existing `~/untitled~.sch`
  (`test_signal_short_nohier_0230`) or **deleted** it (`test_crossview_paste`). That file
  is xschem's autosave of the tester's unsaved work. The R3 prover measured the unfixed
  base changing a seeded `~/untitled~.sch` from 101 B to 219 B
  (`receipts/S2c-R3-prove.md` §2).
* **Fixed for `run_suites.sh` and `gated_xschem.sh`** by D13.3 in `7a46275f`. Both now
  make their path arguments absolute and change to the repository root before running
  anything, as `full_audit.sh` already did. The R3 prover ran them from the canary home,
  seeded and empty, and found it byte-identical, `untitled~.sch` included (`rs_canary_fix2_*`
  and §10).
* **Still written in the checkout on every green T1.** `tests/untitled~.sch` has mtime
  **2026-09-18 19:14:29**, inside the stage-F gate's run (19:12:52–19:21:29, verdict
  `tests/results.1176485.log`; MEASURED by `stat`). That is 1480's measurement again, and
  it stays 1480's.

## Half 2 — the op_param project tier: the correction

* **What is true (READ):** `op_param_lists::conf_path project` is
  `[file join [pwd] .xschem op_param_lists.conf]`, so the tier follows the cwd (the
  S2a map; `src/op_param_lists.tcl`'s header lists `<pwd>/.xschem/op_param_lists.conf` as
  "the project tier"). A Save with project scope from a suite whose cwd is X writes
  `X/.xschem/op_param_lists.conf`. `test_op_param_store_1245.tcl`'s comment above `CT1`
  records a probe that did exactly that into `/home/analog/.xschem/` with cwd `$HOME`, and
  was restored.
* **What the suites do about it (READ):** the three suites that exercise the tier
  (`test_op_param_store_1245`, `test_rdw_keys_1245` and `test_rdw_window_1245`) take the
  checkout file's identity (size and mtime, or `ABSENT`) before they run and compare it
  at a hygiene row (`H1`, `SD4`, `BT9`; issue 1381). Where they press Save, their comments
  say they move the cwd off the repository root: `test_op_param_store_1245`'s `CT` rows
  redirect both `::USER_CONF_DIR` and the cwd into scratch, and `test_rdw_window_1245`'s
  section says it "NEVER PRESSES SAVE AT THE REPO ROOT".
* **What nobody measured:** no crew in this batch observed a suite writing the project
  tier. The D12 line rests on the S2a map (READ) plus the presence of the file.
* **The file itself (MEASURED):** `<repo>/.xschem/op_param_lists.conf`, untracked, mtime
  **2026-09-09 09:58:51**, 19 non-comment rows beginning `version 2` and `list class mos
  summary`. Issue 1381 records the user's Save as "a nine-parameter summary list for
  class MOS", and `src/op_param_lists.tcl`'s DD-6 comment says *"the user has a real
  nine-row one at `<repo>/.xschem/op_param_lists.conf`"*. **It is theirs. Do not delete,
  move or "clean" it.**

## Still open — ⚠ as filed on 2026-09-18; SUPERSEDED by the Resolution's list at the foot

1. **A bare invocation from another cwd still writes `untitled~.sch` there.** D9 keeps
   the bare `./src/xschem … --script <t>.tcl` un-armed, and nothing changes its cwd. Typed
   as documented, from the repository root, it lands in the checkout (0609). Typed with
   absolute paths from `~`, it would land in the tester's home and overwrite their
   autosave, as the drivers did. INFERRED from D13.3's diagnosis, not re-measured after
   the fix.
2. **Suites run through `run_suites.sh` now always read the tester's project tier.**
   Since D13.3 the cwd is always the repository root, and `op_param_lists::load` reads
   `<pwd>/.xschem/op_param_lists.conf` at startup (issue 1380). A suite whose expectations
   assume the shipped default lists would see a tester's saved rows instead. INFERRED,
   not measured: every crew in this batch ran in clones without the file.

## Evidence

`doc/claude/outsider_fixes_batch/DECISIONS.md` D12 and D13.3,
`receipts/S2c_refute_r1.md` (safety refuter, measurement 5), `receipts/S2c-R3-prove.md`
§2 and §10, `receipts/S2a.md` (the project-tier map line), and issue 1381 Part 2.

---

## Resolution — partly landed in `c84aee78`, 2026-09-20 (stranger-reds batch, item F)

Receipts: `doc/claude/stranger_reds_batch/receipts/F-impl.md` (the land, with a fix-round
section appended) and `F-verify.md` (the one fix round). Batch decisions: that batch's
`DECISIONS.md` **D11** and **D13**.

### What was measured first

All **405** `tests/headless/test_*.tcl`, each in a private directory it owned with its own
empty HOME, seeded with an `untitled~.sch` canary. **353 CLEAN; 51 destroy a pre-existing
`untitled~.sch` — 34 by overwriting it, 17 by DELETING it**; one takes `untitled~.sym` too;
**0** leave any other file in their working directory. Two mechanisms, pinned by micro-probe:
`set_modify(1)` → `write_backup()` is the overwrite and is deliberate (issue **0060**), while
`clear_schematic()` → `remove_backup()` is the **delete**, and that one is a product defect —
File > New, with no edit anywhere, removes an `untitled~.sch` this session never wrote, i.e.
exactly the previous session's crash recovery that `xschem_recover_backup()` exists to offer
back.

⚠ **The issue-0601 guard does not stop the delete.** `set ::autosave_backup 0` returns early
from `write_backup()` and has no effect on `remove_backup()`: four of the nine guarded suites
deleted the seeded canary **while carrying the guard**. `test_no_untitled_litter` cannot see
this — every one of its rows asks "did the suite leave anything behind", never "did a file
that was already there survive".

### What landed

* **Product.** A discard no longer deletes a backup this session did not write.
  `clear_schematic()` calls the new `drop_owned_backup()` and `go_back()`'s "No" arm the new
  `remove_backup_if_owned()`; `write_backup()` records what it wrote and `remove_backup()`
  clears that record only when it unlinks that same path. `remove_backup()` itself stays
  unconditional, because its other callers (`save_schematic()`, `xschem backup remove`) are a
  real save and an explicit instruction. **The bare `./src/xschem … --script <t>.tcl`, which
  no driver arms, gets this half too**, since it is in the product.
* **Harness.** New sourced library `tests/headless/suite_cwd.sh`; `run_suites.sh`,
  `full_audit.sh` and `gated_xschem.sh` arm a per-run private directory and pass
  `env "PWD=$_scwd"` on every site that starts the binary, then disarm — including on the
  early exits (`full_audit.sh`'s gate-stop, `gated_xschem.sh`'s "binary not executable"
  FATAL), which were measured leaving the directory behind.
* **`$PWD`, deliberately NOT the cwd.** xschem composes the untitled buffer's path from
  `$env(PWD)` in preference to `getcwd()`. Moving the **cwd** — issue **0609**'s stated fix
  direction — breaks suites: MEASURED, `test_reopen_readonly` dies with `error copying "":
  no such file or directory` because it globs `[file join [pwd] xschem_library …]`. Moving
  only `$PWD` leaves Tcl's `pwd` alone, and a shell child re-derives `PWD` at startup, so
  nothing downstream is misled.
* **A new guard suite**, `tests/headless/test_untitled_autosave_1486.tcl`, **13 checks**,
  registered by item E as the 73rd `hcases` entry, so T1 now covers this. Both its driver
  rows are **deltas, never existence tests** — another suite (or T1 itself, whose cwd is
  `tests/`) may have littered before the row ran, which is the defect that put
  `test_ase_core`'s `C11` in 13 recorded red audits.

### ⚠ The first fix regressed the product, and the adversarial round is what caught it

Item F's first cut tracked backup ownership as a **boolean** (`int backup_written`). That is
the wrong datum: **ownership needs the path**. `load_schematic()` cleared the flag, so any
load between the write and the discard made xschem forget its own `~` — and the next open of
that cell then offered, as crash recovery, edits the user had deliberately discarded.
MEASURED on two builds of the same tree, `load` → `instance` → `load` → `clear force`:

| build | `foo~.sch` exists after the clear |
|---|---|
| pre-1486 (`remove_backup()` unconditional) | **0** |
| item F's first fix (the boolean) | **1** ← the regression |
| the fix round (`char backup_owned[PATH_MAX]`, the path) | **0** |

The suite was `ALL PASS (10 checks)` throughout: `U3` has no load at all and `U4` has no
*intervening* load. Rows **U5**, **U6** and **U6b** were added for it and the suite is now
`ALL PASS (13 checks)`; sabotages S-A…S-E2 show each direction failing, and no pair can be
satisfied by "always remove" or "never remove". The receipt's claim that the fix
**strengthened** the B8 invariant was false and is corrected in all three places it appeared:
**B8 has two directions** — it is broken by deleting a `~` we did not write *and* by leaving
one we did — and the first cut broke the second while claiming to strengthen the first. The
cost of a one-slot record is stated in the struct comment: a session that writes a second
backup stops tracking the first, so **the failure direction is a leftover `~`, never a delete
of someone else's.**

`go_back()`'s "No" arm was the same defect one call site on, and it is now MEASURED rather
than read: with the issue-0601 guard on, it **deleted** a seeded foreign
`descend_child~.sch` — a previous session's crash recovery for a cell, destroyed by answering
"No" to a save prompt, in the condition nine suites in this repository run in.

### What the measurements say after the fix

| | before | after |
|---|---|---|
| suites destroying a seeded `untitled~.sch` (bare runs) | **51** | **38** |
| … by DELETING it | **17** | **3** |
| … by OVERWRITING it | 34 | 35 |
| suites destroying `untitled~.sym` | 1 | **0** |

The three remaining deleters are correct — each writes the backup itself first, or deletes
its own. Through the armed drivers, the repo root's listing is byte-identical for the
five-suite list measured, where at HEAD the same list left `untitled~.sch` in it; the
corpus-wide verdict sweep (405 suites, three arms: baseline, `$PWD` redirect only, and the
full fix) found the redirect **inert** — one difference, a 120 s timeout artefact that passes
in both arms when given 400 s. 32 suites through the armed driver are green on the final
binary, the eleven-strong descend family included.

### ⚠ Still open — the list at the top of this file, updated. This issue is NOT closed.

1. **`tests/run_regression.tcl` — T1 — was never armed.** The three shell drivers each arm a
   private `$PWD`; the Tcl one does not, so **a T1 run still writes `untitled~.sch` into
   `tests/`**. MEASURED: `tests/untitled~.sch`, 571 bytes, mtime **2026-09-20 23:23:39**,
   inside the window of this batch's own E+F gate run (`T1-RUN-BEGIN … start=23:22:07`,
   `T1-RUN-END … end=23:30:59`, `tests/results.2325750.log`) — written by the very gate that
   proved the fix. Row `S1` of the new suite checks the three shell drivers only and is
   structurally blind to the Tcl one. Not fixed in a capped round: it needs a Tcl port of
   `suite_cwd.sh` or `env PWD=` on four `exec` sites, and changing `$PWD` for all 88 cases
   needs a sweep. **It belongs to 0609/1480 and is written up there** (0609, *"2026-09-20 —
   three of the four drivers are contained"*).
2. **38 of the 405 suites swept still overwrite a pre-existing `untitled~.sch`** in whatever
   directory a bare `./src/xschem … --script <t>.tcl` is typed from (the corpus is 406 files
   today, the 406th being this issue's own guard suite). That write **cannot** be fixed: the
   buffer really is `<cwd>/untitled.sch` and backing it up is what issue 0060 requires. The
   destructive half that *was* fixable — deleting a file we never wrote — is fixed in the
   product, so it holds for the bare command too. The armed spelling remains
   `tests/headless/run_suites.sh [--nogui] <t>`. `scratch.tcl` is not a way round it: only
   27 of the 51 offenders source it (MEASURED), so arming there would close half a class and
   create a second rule.
3. **Nine suites write a `cellName~.sch` into the checkout whatever `$PWD` says**, because
   `backup_file_name()` puts the `~` beside the **cell**, not in `$PWD`. The redirect
   structurally cannot reach them and the sweep — which watched only private working
   directories — was structurally blind to them. Re-measured in the fix round: with
   `tests/from_user/before_10~.sch` moved out of the tree, the **armed**
   `run_suites.sh --nogui test_fluid_bodyshove_guards_0132` put it back byte-identical. It is
   **not a regression** — the pre-fix binary leaves the same nine identically — and it
   belongs to **0609**/**1480**, where it is now recorded. The names are in
   `tests/headless/suite_cwd.sh`'s header.
4. **The op_param project tier (half 2 above) is untouched, on purpose.** The fix moves
   `$PWD` and not the cwd, so `op_param_lists::conf_path project` still resolves exactly
   where it did, and `<repo>/.xschem/op_param_lists.conf` was verified **not read, written,
   moved or deleted** across both rounds (mtime `2026-09-09 09:58:51`, 2236 bytes, md5
   unchanged). That item is a ruling about which directory is the project, not a bug to sweep
   past.

Two corrections to claims made on the way, both from the fix round: *"no suite leaves
anything else"* is true only **in its working directory** (item 3 above is the other class),
and *"nothing under `~` was written"* should read *"nothing under `~` other than
`~/.cache/openbox/openbox.log`"*, which any privately started openbox rewrites.
