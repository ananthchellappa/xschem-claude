# 0364 — `get_unused_untitled_name()` stats a bare basename against the LIVE cwd while its caller assembles the path against `pwd_dir`, so File > New can hand you a name that already exists on disk

Status: **OPEN — filed, not fixed** (measured at HEAD while working item D3 / issue **0264** of
the 2026-08-09 backlog run; proven pre-existing by reverting the D3 sources and rebuilding).
Area: `src/xinit.c` — `get_unused_untitled_name()` (~:170); caller `src/actions.c` —
`clear_schematic()` (~:4029).
Tests: `tests/headless/test_descend_untitled_preserve.tcl` is **RED at HEAD** because of this
(`FAIL: fresh buffer is untitled (never saved)`), and it is not in `run_regression.tcl`'s case
list, so nothing gates it.
Related: **0056** (the "a blank window must not collide" guarantee this voids), **0353**
(`untitled*.sch` leaking into the repo root — the litter that makes this reachable).

## What it is

`get_unused_untitled_name()` picks the first free `untitled[-n].sch` **basename**:

```c
if(!stat(name, &buf)) continue;            /* exists on disk */
```

`stat()` on a bare basename resolves against the **live process cwd**. The caller then builds
the buffer's path against a *different* directory:

```c
my_mstrcat(_ALLOC_ID_, &xctx->sch[xctx->currsch], pwd_dir, "/", name, NULL);
```

`pwd_dir` is captured **once at startup** by `getcwd()` (`xinit.c:2937`, and from `env(PWD)` at
`:3644`). A Tcl script's `cd`, or any later working-directory change, desynchronizes the two:
the freeness test asks about directory A, the name is created in directory B.

## Measured

`tests/headless/test_descend_untitled_preserve.tcl` does `cd` into its work dir before
`xschem clear force`. The helper sees `untitled.sch` free in `/tmp/descend_untitled_work` and
returns it; the buffer becomes `/home/analog/dev/xschem-claude/untitled.sch`, which **exists**
(a stray untracked file in the repo root):

```
before clear: schname=/home/analog/dev/xschem-claude/untitled-70.sch
after  clear: schname=/home/analog/dev/xschem-claude/untitled.sch exists=1
              (the /tmp work dir is empty)
```

Independently reproduced during item D3's write-up with a script that `cd`s to a scratch dir:

```
cwd=/tmp/.../scratch_D3/wr/a12  files=
A0 fresh:   sch=/home/analog/dev/xschem-claude/untitled.sch modified=0
```

So issue 0056's guarantee ("a candidate is taken if a file with it exists in the current
directory") holds only while the process cwd equals `pwd_dir`. When it does not, File > New
silently adopts an existing file's name — the next save writes over a file the user never
opened.

## Sketch

Fix belongs in the helper, not the test: either `stat()` the **assembled** path, or take the
target directory as an argument and have both call sites (`save.c`'s empty-filename load and
`actions.c`'s discard) pass the directory they will actually use. Note the second freeness test
(`untitled_basename_open()`, issue 0056) compares basenames across windows and would need the
same directory awareness to stay honest.

`tests/headless/test_descend_untitled_preserve.tcl` is the ready-made witness — it is red today
and should go green with the fix, and it should be added to a gated list once it does.
