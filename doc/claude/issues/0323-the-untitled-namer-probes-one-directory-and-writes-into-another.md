# 0323 — the untitled namer probes one directory and writes into another, clobbering unsaved work

Status: **FIXED** 2026-08-12, by option 1 below. Filed while fixing **0322**.

Area: `get_unused_untitled_name()` (`src/xinit.c:170-182`) vs its two path-composing callers,
`load_schematic()` (`src/save.c:4413-4421`) and `clear_schematic()` (`src/actions.c:3946-3949`)
Tests: `tests/headless/test_untitled_name_dir_0323.tcl` (8 checks, pure headless; runs the two
arms in CHILD xschem processes because the property is decided by the child's startup cwd/`$PWD`)
Found: 2026-08-12, by the background sweep filed under 0322; verified directly
Related: **0322** (the litter this came out of), **0056** (the open-window arm of the same namer)

## The bug

`get_unused_untitled_name()` decides a name is free with a **relative** `stat()`:

```c
    if(n == 0) my_snprintf(name, namesize, "untitled.%s", ext);
    else my_snprintf(name, namesize, "untitled-%d.%s", n, ext);
    if(!stat(name, &buf)) continue;            /* exists on disk */
```

A relative path resolves against the **live process cwd**. But neither caller writes there. Both
compose the real path from a directory captured at startup:

- `src/save.c:4415-4421` — `getenv("PWD")`, falling back to `pwd_dir`
- `src/actions.c:3949` — `pwd_dir`, i.e. the `getcwd()` taken at `src/xinit.c:2934`

Tcl's `cd` changes the process cwd but does **not** update `env(PWD)`, and nothing refreshes
`pwd_dir`. So after any `cd`, the namer probes directory A while the file is written into
directory B. Two consequences, the second serious:

1. The file lands where the caller did not intend.
2. **The no-overwrite guarantee is void.** The whole point of the loop is that it never picks a
   name that already exists — but it checked the wrong directory, so it will happily choose a name
   that is occupied at the destination and silently overwrite it.

## Measured

Probe script: print cwd, `cd` elsewhere, `xschem clear force`, add a wire, `xschem save`.

```
launch cwd  = .../desync/launch
env PWD     = .../desync/launch
after cd    = .../desync/elsewhere
buffer path = .../desync/launch/untitled.sch
```

`elsewhere/` is empty afterwards; `launch/untitled.sch` is the file that appeared. The namer
consulted `elsewhere/`, the write went to `launch/`.

Now the destructive case — same script, but `launch/untitled.sch` already holds content:

```
before: PRECIOUS UNSAVED WORK
after : v {xschem version=3.4.8RC file_version=1.3}
        G {}
        ...
--- verdict ---
CLOBBERED
```

`elsewhere/` was empty, so slot 0 (`untitled.sch`) read as free and was taken. The occupied file
of the same name in the *actual* destination was overwritten without a prompt, a warning or an
undo entry.

## It is already happening in-tree

`tests/headless/test_descend_untitled_preserve.tcl:33` carries a comment that states the exact
intent this bug defeats:

```tcl
# cd into the work dir so the untitled buffer (and its ~ backup) resolve HERE, not the repo.
cd $work
```

They do not resolve there. `$work` is `/tmp/descend_untitled_work`, yet the artifacts land in the
tree: `tests/headless/untitled~.sch` (105 B, 2026-08-08) holds `C {descend_child.sym} …`, that
test's fixture body. `test_untitled_reuse.tcl` leaks the same way. Both were noted in 0322 as
"residual, deliberately not fixed" on the theory that the `~` file is harmless because it is
overwritten in place — **that reasoning was wrong**: the reason those two tests leak into the tree
at all is this bug, not a design decision.

## Exposure outside the tests

Every `cd` in the shipped Tcl is a save/restore pair around netlisting or simulation
(`src/xschem.tcl:138`, `:4079`, `:4236`, `:5483`, `:5506`; `src/ase.tcl:574`), so the window is
open only for the duration of that region — but netlist and simulation runs are exactly the long
operations during which an autosave or a scripted save can fire, and an error path that skips the
matching `cd $save` leaves the desync latched for the rest of the session. A user script or a
custom hook that `cd`s without restoring latches it immediately. **Not yet reproduced through the
GUI** — the proof above is scripted.

## The fix

Three options were on the table:

1. **Probe the directory the caller will actually use** — pass the destination in, `stat()` an
   absolute path.
2. **Resolve the directory at the namer** (`getcwd()` inside it), making the callers'
   `$PWD`/`pwd_dir` composition redundant. This would *relocate* untitled buffers after a `cd`.
3. **Keep `pwd_dir` fresh** — narrowest, and masks the class rather than closing it.

**Option 1 was taken.** It closes the data-loss path without changing where untitled buffers land;
option 2 additionally changes user-visible placement, which is a separate decision and not one this
issue needed to make.

`get_unused_untitled_name()` grows a leading `dir` argument (`src/xschem.h:2851`,
`src/xinit.c:170`) and probes `dir/name` instead of a bare relative basename. Both callers now
resolve the destination directory **before** naming: `src/save.c` hoists its
`getenv("PWD")`/`pwd_dir` choice above the call and passes `xctx->current_dirname`;
`src/actions.c` passes `pwd_dir`, the same variable it composes the path from two lines later. A
NULL/empty `dir` falls back to `pwd_dir`.

The `untitled_basename_open()` arm (issue 0056) was deliberately left directory-blind. Matching on
the basename alone can only make it skip a number it did not have to, never reuse one — it cannot
lose data, and narrowing it is how 0056 comes back.

## Verification

`tests/headless/test_untitled_name_dir_0323.tcl`, 8 checks, all passing. Sabotage-verified: with
the probe reverted to the relative form (`"%s"` instead of `"%s/%s"`), 3 of the 8 go red, including
the one that matters —

```
FAIL: B: clear-after-cd skips the occupied name -> {untitled.sch} (exp {untitled-1.sch}) : FAIL
FAIL: B: the occupied file SURVIVES (0323 data loss) -> {v {xschem version=3.4.8RC ...
FAIL: B: the new buffer was actually written -> {0} (exp {1}) : FAIL
```

Arm A passes under the sabotage by design (at startup cwd == `$PWD`, so there is nothing to
desync); it is there to catch a wrong `dir` argument at the `save.c` call site.

Regression arm, all green, no litter: `test_untitled_reuse`, `test_pristine_untitled_basename`,
`test_descend_untitled_preserve`, `test_pristine_untitled_viewer_0172` (41), `test_backup_file`,
`test_placement_wire_gate` (171), `test_descend_symbol`, `test_readonly`.

## What this does NOT change

Because option 1 preserves placement, a `cd` still does not move an untitled buffer — the path is
still composed from the startup directory. `test_untitled_reuse` and `test_descend_untitled_preserve`
therefore still each leave one `untitled~.sch` in the launch directory (measured after the fix).
That is gitignored, same name overwritten in place, and no longer dangerous now that the probe and
the write agree. `test_descend_untitled_preserve.tcl:32`'s comment claimed the `cd` relocated the
buffer; it never did, and it now says so and points at the child-process technique the 0323 test
uses to actually control the directory.
