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

---

# ITEM B2a — **ATTEMPTED, MEASURED, AND REVERTED**, 2026-09-03

> **STATUS: NOT FIXED. The code below was written, verified green, and then
> REVERSE-APPLIED out of the tree.** The item's adversary pass refuted the
> batch's central claim and the write-up agent reproduced three of its attacks
> independently, so item B2a is **[F]** and `src/op_param_lists.tcl`,
> `src/rdw.tcl` and both suites are byte-identical to commit `825cd3bd`.
>
> **The work is not lost and must not be retyped.** The full 2,506-line diff is
> preserved at `doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` and
> applies clean to `825cd3bd`. The next crew's job is
> **apply + fix the named holes + re-verify**, not reconstruct.
>
> Everything below this banner is a record of THE ATTEMPT — what it changed and
> what it measured. Read it as evidence, not as a description of the tree. The
> reasons for the revert are under **"Why this was reverted"** at the end of
> this section; the three defects that forced it are in issues 1277, 1281 and
> 1284, and 1276/1278/1279/1280/1282/1283 were reverted as **collateral**,
> because a 2,506-line diff is one unit and splitting it at write-up time would
> ship a code change no verifier ever saw.

## What the attempt did (item B2a — **FIXED**, 2026-09-03)


`src/op_param_lists.tcl`. Three new procs in front of `write_conf`, and four
lines inside it.

* **`_resolve_target {path}`** walks a symlink chain, bounded at 16 hops,
  returning the file the write should actually land on (or `{}` for a chain
  deeper than that, which is what a loop looks like from here).
* **`_target_why {path target}`** is the precondition, named once so it has a
  single sabotage point: `{}` when the resolved target may be written, and the
  sentence otherwise. It refuses a **directory** in plain English and says the
  file you already had is untouched.
* **`_path_tier {path}`** is issue 1281's, and shares the same block.

`write_conf` now resolves **before** the directory guard, before `file mkdir`,
before the permission capture and before `_tmpname`, because all three
measurements below say it must.

## ⚠ THIS ISSUE'S OWN RECOMMENDED ONE-LINER IS REFUTED, MEASURED

The sentence refuted is, verbatim from §5 above:

> resolve a symlink to its target before choosing `$tmp`:
> `if {![catch {file link $path}]} { set path [file normalize [file link $path]] }`

Measured on this tree for the **relative** target `real.conf` of a link living
at `<dir>/sub/link.conf`:

```
file normalize [file link $path]                                  -> <cwd>/real.conf          WRONG
file normalize [file join [file dirname $path] [file link $path]] -> <dir>/sub/real.conf      RIGHT
```

`file normalize` resolves against the **cwd**, not the link's own directory, and
a relative target is the natural spelling of the shared case
(`ln -s ../team/op_param_lists.conf .xschem/op_param_lists.conf`). Row **W7**
creates its link from a different cwd with a relative target precisely so the
one-liner reds there as loudly as no fix at all. Three more measured facts the
guard **order** depends on, all recorded in the code comment: `file normalize`
does not resolve a path's final component; a symlink to a **directory** answers
`file isdirectory` 1; and a **dangling** symlink answers exists=0/isfile=0/
isdirectory=0 while `file link` still succeeds.

## Red before green

| row | red on | green after |
|---|---|---|
| `W6` directory | `{1 1 0 0 w6dir.new 1 1}` (rc=1, zero reports, bytes at `<dir>/w6dir.new`) | `{1 0 1 1 {} 1 1}` |
| `W7` relative symlink | `{0 1 file 0 {} {}}` (link replaced, real file empty) | `{0 1 link 1 {} {}}` |
| `W7b` chain + dangling | `{0 0 1 file link 0 1 file 0}` | `{0 0 1 link link 1 1 link 1}` |

Sabotage, each red on its own fence with the fix in place:

* `SB-NO-SYMLINK-RESOLVE` (`_resolve_target` → identity) → **W7, W7b red**,
  `RESULT: 2 FAILED (54 passed)`.
* `SB-NO-TARGET-GUARD` (`_target_why` → `{}`) → **W6 red**,
  `RESULT: 1 FAILED (55 passed)`.

## Not fixed here, and why

`ase::sim_write_conf` (`src/ase.tcl:1999-2034`), the precedent this writer was
copied from, carries **both** holes structurally. It is another item's file, so
it is filed as issue **1286** rather than fixed here.

## Why this was reverted

**This issue's own fix was not refuted, and nothing below was measured wrong.**
It was reverted as **collateral**. Item B2a was implemented as one 2,506-line
diff across four files; the adversary pass refuted the batch's central claim on
three *other* issues — **1277**, **1281** and **1284** — and the write-up agent
reproduced all three independently before deciding. Splitting a diff that size
into a "sound" half and an "unsound" half at write-up time would have committed
a code change that no Measure, Verify-A, Verify-B or Verify-C pass had ever
seen, which is precisely the failure mode this batch has already paid for in
items B1, B2 and B3.

**The work is preserved and must not be retyped.**
`doc/claude/op_param_batch/B2a_working_tree_REVERTED.patch` applies clean to
`825cd3bd`. The next crew's job is **apply → fix the three named holes →
re-verify**, and this issue's portion should survive that pass unchanged.
