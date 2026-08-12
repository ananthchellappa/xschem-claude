# 0323 — the untitled namer probes one directory and writes into another, clobbering unsaved work

Status: **OPEN** — filed 2026-08-12, found while fixing **0322**. Not fixed: 0322's scope was the
litter, and this is a C-side correctness bug that deserves its own decision.

Area: `get_unused_untitled_name()` (`src/xinit.c:170-182`) vs its two path-composing callers,
`load_schematic()` (`src/save.c:4413-4421`) and `clear_schematic()` (`src/actions.c:3946-3949`)
Tests: none yet
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

## Candidate fixes, not yet chosen

1. **Probe the directory the caller will actually use.** Give `get_unused_untitled_name()` the
   destination directory as an argument and `stat()` an absolute path built from it. Fixes the
   overwrite and the mislocation together; touches the two callers and `src/xinit.c`.
2. **Resolve the directory once, at the namer.** Have it call `getcwd()` itself and hand back an
   absolute path, making the callers' `$PWD`/`pwd_dir` composition redundant. Changes where
   untitled buffers land after a `cd`, which is arguably the *correct* behaviour but is a
   user-visible change.
3. **Keep `pwd_dir` fresh.** Narrowest, but only masks the class — any future caller that composes
   from a different base reopens it.

Option 1 preserves current placement semantics and closes the data-loss path, so it is the
conservative pick. Whichever is taken, the fix wants a regression test built on the probe above:
`cd` away, save an untitled buffer, assert both *where* it landed and that a pre-existing file of
that name at the destination was not overwritten. `test_descend_untitled_preserve.tcl:33`'s comment
must be corrected or its `cd` made effective at the same time.
