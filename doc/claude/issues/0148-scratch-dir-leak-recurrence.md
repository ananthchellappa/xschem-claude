# 0148 — per-pid scratch dirs leak into the working tree again (different cause)

**Status:** FIXED. Helper + audit detector + **all 66 call sites converted**;
`AUDIT_STRICT_SCRATCH` now defaults to fatal.
**Filed:** 2026-07-25
**Related:** cf57955c (2026-07-22, the first, narrower fix)

## Symptom

13 orphan directories in the repo root, all from 2026-07-24:

```
_ase_mig_verify_314965 _ase_mig_verify_315088 _ase_mig_verify_315213
_ase_mig_verify_316270 _ase_mig_verify_316365
_isrc_13114 _isrc_13436 _isrc_13706 _isrc_13887
_vpwl_6404 _vpwl_6489 _vpwl_6560 _vpwl_7846
```

plus 10 older ones under `tests/headless/` (2026-06-22 … 2026-07-13), the cwd
the tests were run from at the time.

`.gitignore` matches `_*_[0-9]*/`, so none of them show in `git status`. The pile
grows silently and is only noticed by eye.

## Root cause — NOT the 2026-07-22 one

cf57955c fixed tests that deleted their scratch dir only at *start* (defensive
re-create) and never at the end, so every single run leaked one. Those two tests
(`test_nh_angle_clamp.tcl`, `test_nh_angle_editor.tcl`) are still correct.

The new orphans come from code that **does** delete at the end, but as an
unprotected statement on the last line:

| dir | creator | delete |
|---|---|---|
| `_vpwl_*` | `tests/headless/test_vpwl.tcl:24` | line 81 |
| `_isrc_*` | `tests/headless/test_isources.tcl:23` | line 77 |
| `_ase_mig_verify_*` | `tools/migrate/ase_migrate.py` `_VERIFY_TCL` | last line of the driver |

Every path that does not reach that last line leaks:

* an early skip guard — `if {![file isdir $pdk]} { puts "SKIP: ..."; exit 0 }`
* an uncaught Tcl error mid-script (under `--script`, xschem does not unwind to
  the cleanup, it idles)
* a segfault, a `timeout` kill, Ctrl-C

The leaked contents confirm a mid-run abort rather than an exit-time re-create:
`_isrc_*/{tb.sch,tb.spice}`, `_vpwl_*/{tb.sch,tb~.sch,tb.spice}`,
`_ase_mig_verify_*/{before.log,<cell>.spice,library.defs}` — the last one has no
`run/` subdir, i.e. it died in the AFTER block, after the BEFORE ngspice run.

`ase_migrate.py` made it worse: its `finally` removed only the generated driver
`_verify_<pid>.tcl`, never the scratch dir, so any `subprocess.run(..., timeout=180)`
expiry or non-zero xschem exit orphaned one by construction.

The older `tests/headless/_nhangle_*/geometry` corpses are the *other* failure
mode, from before cf57955c: the dir was deleted, then xschem's exit-time geometry
write (`store_geom` → `USER_CONF_DIR`) re-created it.

## Systemic gap

cf57955c patched two files and added a `.gitignore` line. It introduced no shared
helper and no enforcement, while ~100 scripts each hand-roll
`set x [file join [pwd] _tag_[pid]]` + a bare `file delete` at the bottom. Every
new test re-implements the bug, and the `.gitignore` entry guarantees nobody
notices until the root is visibly cluttered.

## Fix

`tests/headless/scratch.tcl` — one helper, three guarantees:

```tcl
source [file join $here scratch.tcl]
set scratch [test_scratch vpwl]
```

1. **Out of the working tree.** The dir lives under `tests/headless/.scratch/`
   (gitignored), not the repo root, so a leak never litters what the developer
   looks at. `$env(XSCHEM_TEST_SCRATCH)` overrides.
2. **Cleanup on every exit path.** `exit` is wrapped once (`rename ::exit
   ::__scratch_real_exit`), so the failing-test `exit 1` and the early skip-guard
   `exit 0` both clean up. `store_geom` is no-op'd first so xschem's exit-time
   geometry write cannot re-create the dir (the cf57955c lesson, now central).
3. **Self-healing across runs.** What survives a SIGKILL/segfault/timeout is
   swept by the *next* run: `test_scratch` deletes sibling `_<tag>_<pid>` dirs
   whose pid is gone, in `.scratch/`, the repo root, and `tests/headless/`.
   Guards: pid must be provably dead (`/proc/<pid>`; an unreadable answer counts
   as alive), and the dir must be older than 300 s, so a concurrent run is never
   touched.

`ase_migrate.py`: the scratch path is now baked into the driver from Python
(`@@SCRATCH@@`) and removed in the existing `finally`, so Python owns the
lifetime and a driver crash/timeout cannot leak.

`tests/headless/full_audit.sh`: snapshots `_*_<pid>` dirs in the repo root,
`tests/`, `tests/headless/` and `src/` before and after the suite, prints what
leaked, removes it, and reports the count in the summary. A leak is fatal by
default; `AUDIT_STRICT_SCRATCH=0` downgrades it to a warning.

## Verification

* `test_vpwl` 9/9, `test_isources` 6/6, both leaving `.scratch/` empty.
* Probe with an early `SKIP; exit 0` before the old cleanup point: dir removed.
* Sweep probe: dead-pid + old dirs planted in all three locations were removed;
  a dead-pid dir with a fresh mtime and an old dir owned by a *live* pid were
  both correctly kept.
* The 10 pre-existing `tests/headless/_*` corpses were swept automatically by the
  first run of a converted test — self-healing confirmed on real corpses.

## Conversion (all call sites)

66 files converted to `test_scratch`, verified against a pre-conversion baseline
of the same 58 headless tests: **55 pass / 3 fail before, 58 pass / 3 fail after
(61 tests), zero status changes on the 58 in common, 0 leaked dirs.** The 3
failures (`test_lib_sweep`, `test_reopen_readonly`, `test_wire_split`) are
pre-existing and unrelated — `test_wire_split` fails identically on an unmodified
tree under X and passes under `--nogui`.

Cases that needed judgement rather than the mechanical recipe:

* `test_ase_persist.tcl` asserts `check "cleanup: scratch removed"
  [file exists $scratch] 0`, so it uses `test_scratch_drop` rather than losing
  its delete.
* `test_sweep_diff.tcl` was the one dir NOT anchored at `[pwd]` — it built a
  sibling of the fixture via `[file dirname $fixroot]`, inside `tests/`. That
  derivation is gone; symbol refs resolve through the absolute `$fixroot` on
  `::XSCHEM_LIBRARY_PATH`, so relocation is common-mode.
* `test_wire_split.tcl` never deleted its dir at all — ~15 generated `.sch` per
  run, immortal in `/tmp` (never swept). Now helper-owned.
* `test_migrate_engine.tcl`, `test_lib_roundtrip.tcl` and `test_wire_split.tcl`
  move *into* the repo tree from `/tmp`: slower (real disk vs tmpfs) but now
  swept. `XSCHEM_TEST_SCRATCH` points the root back at a tmpfs if that matters.
* `test_perform_action_embed_rawfile.tcl` needs its `.raw` in `$HOME` (the
  behaviour under test); left there, removal made robust instead.
* Four per-pid `.sym` FILES in the repo root (`_awl_`, `_fh_`, `_iu_`,
  `_sch_add_pin_`) were never covered by the `.gitignore` dir pattern at all.
  Moved inside a `test_scratch` dir.

## Left open

* `test_save_as_cellview.tcl` and `test_save_as_form.tcl` end at `flush stdout`
  with no `exit`, so the wrapped-exit cleanup only fires if shutdown goes through
  Tcl's `exit`. Worst case they leave a dir in the gitignored `.scratch/`, swept
  next run — better than before, but not provably zero.
* `test_close_window_force.tcl` calls `xschem exit force`, which terminates the
  process from C. No Tcl `exit` wrapper can cover that; the sweeper is the
  backstop.
* `tests/test_utility.tcl:82,104` write `.parallel_jobs.<pid>` /
  `.cleanup_files.<pid>` in `[pwd]` as xargs input, deleted immediately after a
  `catch`'d exec. Same shape, negligible window, and it is the golden-suite
  harness — left alone deliberately.
