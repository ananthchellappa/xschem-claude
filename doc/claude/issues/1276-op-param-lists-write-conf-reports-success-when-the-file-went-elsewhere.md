# 1276 — `op_param_lists::write_conf` returns success when the settings went somewhere else

**Status: MEASURED, FILED, NOT FIXED.** Found by item B2's adversary pass on
B2's own new code, 2026-09-03, before anything calls the writer. Two cases, one
proc, one fix site.

**Severity: this is the writer's headline contract failing in the direction
nobody tests for.** Issue 0937's whole lesson is that a *truncated* file is
worse than no write. This is worse still: the write reports **success**, the
user's Save line says the path it did not write, and the settings are gone with
no sentence anywhere.

## What is claimed

`src/op_param_lists.tcl`'s writer, copied in shape from `ase::sim_write_conf`
(`src/ase.tcl:1999-2036`), documents itself as *"Returns 1, or 0 with a report;
never raises."* Item B2's ACCEPT row is *"an interrupted write never
truncates"*, and that row **holds** — the failure here is on the other side of
the same contract.

## The measurement (2026-09-03, this tree, `src/op_param_lists.tcl` md5 `bf0230751de375be37e876aea53e8956`)

### Case 1 — the target path is a directory

```tcl
file mkdir $S/w/dirtarget
op_param_lists::set_list class mos annotation {{id ids 0}}
set rc [op_param_lists::write_conf $S/w/dirtarget]
```

```
DIRTARGET rc=1 reports=0 path_is_dir=1
$ ls $S/w/dirtarget/
-rw-r--r-- 1 analog analog 706 Sep  3 12:54 dirtarget.new
```

`file rename -force $tmp $path` with an existing **directory** destination does
not fail — Tcl moves the source *into* it. So the writer returns **1** with
**zero** reports while the settings land at `<path>/<basename>.new`, a name no
reader ever looks at. A following `load_conf` says *"no settings file at
`<path>`"* and the list is silently the PDK seed again.

### Case 2 — the settings file is a symlink

```
SYMLINK rc=1 link_still_link=0 real_size_before=0 real_size_after=0 link_size=706
$ ls -la
-rw-r--r-- 1 analog analog 706 Sep  3 12:54 link.conf     <-- was a symlink
-rw-r--r-- 1 analog analog   0 Sep  3 12:54 real.conf     <-- the intended target
```

The rename replaces the **link** with a regular file and leaves the real target
untouched. This is inherited from the copied `ase::sim_write_conf` shape and is
tolerable there; it is not tolerable here, because **symlinking the project
conf at a team-shared file in git is the obvious use of a file whose headline
feature is shareability** (the user's own words: *"shareable with teammates"*).

## Why the suite did not see it

`tests/headless/test_op_param_store_1245.tcl` row **W1** makes `$path.new` a
directory — it tests the *temp* being unopenable, which is the truncation arm.
Nothing in the suite makes the **target** a directory or a symlink:
`grep -c symlink` = 0, and the one `isdirectory` hit is W1's own trick. 39/39
green is a statement about that fence. (B1's lesson, one item later.)

## Recommended fix — one guard before the open, one after the rename

In `write_conf`, before `open $tmp w`:

```tcl
if {[file isdirectory $path]} {
  _say "cannot save the parameter lists to $path: it is a directory. The file you already had is untouched."
  return 0
}
```

and resolve a symlink to its target before choosing `$tmp`, so the temp is
written beside the **real** file and the rename replaces the real file:

```tcl
if {![catch {file link $path}]} { set path [file normalize [file link $path]] }
```

(resolve first, then take `[file dirname $path]` and `_tmpname`, so the
permission capture and the rename both act on the resolved path).

**Rejected: checking the rename's *result*.** `file rename` succeeded; there is
nothing to check. The guard has to be a precondition, not a postcondition.

**Rejected: refusing to follow symlinks at all.** That breaks the shared-file
use case this feature exists for.

## Acceptance rows this needs, in `test_op_param_store_1245.tcl` section W

* W5 — target is an existing directory: `write_conf` returns **0**, reports in
  plain English, and creates nothing inside the directory.
* W6 — target is a symlink to a regular file: the link is **still a link**
  afterwards and the **real** file carries the new bytes.
* W7 (counterweight) — an ordinary path in a directory that does not exist yet
  still succeeds, so the guard is not mistaken for a refusal (this is row W2
  today; keep it).

## Who inherits this

**Item B5**, which wires Save. Until this is fixed, B5's Save can tell a user
the file was written and be wrong. Fix it at B2's seam, not in the button.
