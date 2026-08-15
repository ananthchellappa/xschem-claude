# 0322 — a headless test drops an `untitled-<n>.sch` in the repo root on every run

Status: **FIXED** 2026-08-12. Found by the user, who asked why the repo root was full of
`untitled-<number>.sch` files. 69 of them had accumulated between 2026-08-08 13:01 and 2026-08-12.

Area: `tests/headless/test_placement_wire_gate.tcl` (the producer) vs `get_unused_untitled_name()`
(`src/xinit.c:170`) and the empty-filename branch of `load_schematic()` (`src/save.c:4407`)
Tests: `tests/headless/test_placement_wire_gate.tcl` itself (the fix is in the test)
Found: 2026-08-12, by the user eyeballing `git status`
Related: **0148** (scratch-dir leak discipline — the same class of leak, one shape down: 0148 is
leaked *directories*, this is leaked *files*, and `tests/headless/scratch.tcl`'s sweeper only
knows about the directories), **0056** (why the namer consults open windows too), **0060** (why an
untitled buffer gets a `~` backup at all)

## Symptom, as reported

```
$ ls untitled* | wc -l
69
$ git status --porcelain | grep -c '^?? untitled'
67
```

`untitled.sch`, `untitled-1.sch` … `untitled-66.sch` — 67 files, all byte-identical, 89 bytes, all
untracked and none matched by `.gitignore`. Plus two autosave companions, `untitled-67~.sch` and
`untitled~.sym`, which were **already** ignored by the long-standing `*~.sch` / `*~.sym` rules
(`.gitignore:54-56`) — that is the whole difference between 69 files on disk and 67 in
`git status`. The `.sym` companion means a *symbol*-view run does the same thing through the other
branch of `get_unused_untitled_name()`'s `symbol` argument, so the new rule covers both extensions
even though only `.sch` corpses were saved this time.

```
$ cat untitled-1.sch
v {xschem version=3.4.8RC file_version=1.3}
G {}
K {}
V {}
S {}
F {}
E {}
N 0 0 100 0 {}
```

An otherwise-empty schematic holding one wire from (0,0) to (100,0).

## Root cause

That content is the exact output of the local `reset` proc in `test_placement_wire_gate.tcl:37`:

```tcl
proc reset {} {
  xschem abort_operation ; xschem abort_operation
  xschem clear force ; xschem wire 0 0 100 0 ; xschem unselect_all
}
```

and section **E8** at line 311 saved it:

```tcl
# E8 -- the teardown must not touch the modify flag (issue 0244 is this bug on a sibling path).
reset ; xschem save
check "E8 saved doc is clean"            [xschem get modified] 0
```

The chain, with the file it lands in decided three steps earlier:

1. `xschem clear force` reaches `load_schematic()` with an empty filename. That branch
   (`src/save.c:4407`) calls `get_unused_untitled_name()` and composes the buffer path from
   **`$PWD`**:

   ```c
   get_unused_untitled_name(xctx->netlist_type == CAD_SYMBOL_ATTRS, name, S(name));
   my_strncpy(xctx->current_name, name, S(xctx->current_name));
   if(getenv("PWD")) {
     my_strncpy(xctx->current_dirname, getenv("PWD"), S(xctx->current_dirname));
   ...
   my_mstrcat(_ALLOC_ID_, &xctx->sch[xctx->currsch], xctx->current_dirname, "/", name, NULL);
   ```

2. `xschem wire 0 0 100 0` supplies the 89-byte body.
3. The bare `xschem save` at :311 has a non-empty `xctx->sch[currsch]`, so `scheduler.c:10628`
   takes the `save(0, fast)` branch rather than the `saveas(NULL, …)` dialog branch — it writes
   `$PWD/untitled-<n>.sch` with no prompt and no warning.
4. `$PWD` is the **repo root**, because that is where the file's own header tells you to run it
   from (`test_placement_wire_gate.tcl:17-19`), and it is the invocation CLAUDE.md documents as
   the trustworthy headless signal:

   ```
   ./src/xschem --nogui --pipe -q --script tests/headless/<t>.tcl
   ```

## Why 66 of them and not one overwritten file

`get_unused_untitled_name()` skips any candidate that already exists on disk
(`src/xinit.c:180`):

```c
for(n = 0;; ++n) {
  if(n == 0) my_snprintf(name, namesize, "untitled.%s", ext);
  else my_snprintf(name, namesize, "untitled-%d.%s", n, ext);
  if(!stat(name, &buf)) continue;            /* exists on disk */
  if(untitled_basename_open(name)) continue; /* open in another window */
  break;
}
```

So run *k* cannot reuse run *k-1*'s file: it takes the next free number. The pile is a **monotonic
counter of how many times the test ran from the repo root** — never a fixed-size mess.

Measured in an empty directory, three consecutive runs of the unmodified test:

```
run 1 -> untitled.sch    untitled-1~.sch
run 2 -> untitled-1.sch  untitled-2~.sch
run 3 -> untitled-2.sch  untitled-3~.sch
```

`md5sum` of each dropped `.sch` is `4ab664717a3bcc5dc1758b878f51a89a` — identical to all 66 in the
repo root. `untitled.sch` + `untitled-1..66` therefore records **67 runs**.

## The `~` file is a second, separate leak

`untitled-67~.sch` is not a stray save. `write_backup()` (`src/save.c:4063`) writes the autosave
`~` companion, and it **deliberately does so for untitled buffers** — issue 0060, where skipping
them lost the whole top level on descend+ascend from a new canvas:

```c
  /* Back up even when 'name' has no on-disk file yet (an untitled buffer): the backup
   * holds UNSAVED content, so whether the base file exists is irrelevant -- and descend
   * relies on it (go_back restores the parent from cellName~.sch). Skipping untitled here
   * lost the whole top level on descend+ascend from a new/pasted-into canvas (issue 0060). */
```

Every `reset` in the test modifies an untitled buffer, so every `reset` writes a `~`. Almost all
of them are cleaned up: `remove_backup()` (`src/save.c:4088`) drops the `~` on a real save, and
the *next* run's E8 save consumes that number as a real file and removes its backup. What survives
is exactly one stale `~`, at the highest number — which is why there is one `untitled-67~.sch` and
not sixty-seven `~` files. **The leak is one file per run either way**: even with the E8 save
removed, the `~` would keep landing in the cwd.

## Why the existing scratch discipline did not catch it

`tests/headless/scratch.tcl` already sweeps the repo root on first use, and its header names this
exact failure mode ("the corpses pile up there"). But `__scratch_sweep` (`scratch.tcl:69`) only
matches **directories**:

```tcl
foreach d [glob -nocomplain -directory $dir -type d {_*_[0-9]*}] {
```

`test_placement_wire_gate.tcl` never sources `scratch.tcl` at all, and the corpses it leaves are
files with a completely different name shape. Issue 0148's fix is intact; this is the sibling case
it does not reach.

## Fix

Three parts, because stopping production does not clean up what is already there, and neither one
protects against the next test that does this.

**(a) Stop producing them** — `tests/headless/test_placement_wire_gate.tcl`:

- `source scratch.tcl` and take a `test_scratch placegate` directory;
- turn `autosave_backup` off for the duration (precedent: `test_backup_file.tcl:57`), so no `~`
  companion is written into the cwd by the ~60 `reset` calls;
- replace the bare `xschem save` at E8 with
  `xschem saveas [file join $scratch e8.sch] schematic`, which writes into the scratch dir and
  still leaves the buffer clean — which is all E8 asserts.

Both settings are restored at the end of the file, next to the existing `$::infix_interface`
save/restore.

**(b) Ignore them** — nothing named `untitled*.sch`/`untitled*.sym` is tracked anywhere in the
repo (`git ls-files | grep -i untitled` returns only issue docs and test *scripts*), so the rule
is safe. Anchored to the root anyway, so a legitimate `untitled` fixture in a subdirectory would
still show up. This follows the `Xschem.log` precedent already in `.gitignore` — "Action log
(created at runtime in the cwd)". Only the four non-`~` patterns are added: the `~` companions
have been covered since `.gitignore:54-56`.

**(c) Delete the 69 existing files.** All untracked or ignored; the 67 `.sch` are byte-identical,
the two `~` companions are stale autosaves of buffers no process holds any more.

## The vector, caught live while this issue was being written

Between the inventory above and the cleanup, `untitled-67~.sch` disappeared and a fresh
`untitled~.sch` appeared, timestamped inside the session. Nobody edited a schematic: background
investigation agents had run headless tests from the repo root to check the finding. That is the
issue reproducing itself, unprompted, during an ordinary read-only investigation — the argument
for (b) being the durable half of the fix rather than (a) alone.

## Residual: two more tests leak a `~`, and they are NOT fixed here

Measured after the fix, each run alone in a clean root:

```
test_backup_file                         leaves: <none>
test_untitled_reuse                      leaves: untitled~.sch
test_pristine_untitled_basename          leaves: <none>
test_descend_untitled_preserve           leaves: untitled~.sch
```

Both tests exist to exercise untitled buffers, so `write_backup()` firing on them is the behaviour
under test. It does not pile up — the name comes from the same free-number scan, so with no
`untitled*.sch` on disk it is always the *same* `untitled~.sch`, overwritten in place — and
`*~.sch` has ignored it since long before this issue.

**But the reason it lands in the tree at all is a second, worse bug, filed as 0323.** Both tests
`cd` into a `/tmp` work dir first, and
`test_descend_untitled_preserve.tcl:33` says so explicitly:

```tcl
# cd into the work dir so the untitled buffer (and its ~ backup) resolve HERE, not the repo.
cd $work
```

That `cd` does not do what the comment claims. `get_unused_untitled_name()` `stat()`ed a *relative*
basename — against the live process cwd — while both callers compose the path from `$PWD` /
`pwd_dir` captured at startup, which Tcl's `cd` never updates. So the namer probed the work dir and
the file was written into the repo. The same split voided the loop's no-overwrite guarantee, and
0323 demonstrated it silently destroying an occupied `untitled.sch`.

0323 is now fixed, but by the option that closes the data-loss path **without** relocating untitled
buffers — so this residual survives on purpose: both tests still leave one `untitled~.sch` in the
launch directory, now harmlessly. The misleading comment is corrected there. Converting the two
tests to `test_scratch` would not help either; the only way to put the buffer somewhere else is to
launch xschem with that directory as its startup cwd, which is what
`tests/headless/test_untitled_name_dir_0323.tcl` does.

## Residual risk

`get_unused_untitled_name()` is unchanged, so **any** test or interactive session that saves an
untitled buffer while the cwd is the repo root will start the pile again from `untitled.sch`. A
sweep of `tests/` found no other script combining `xschem clear` with a bare `xschem save`, but
the `.gitignore` rule from (b) is the durable half of this fix: it stops the next one from being
invisible-until-it-is-68-files, at the cost of making it invisible in `git status` — check for
these files directly if the root starts feeling crowded.
