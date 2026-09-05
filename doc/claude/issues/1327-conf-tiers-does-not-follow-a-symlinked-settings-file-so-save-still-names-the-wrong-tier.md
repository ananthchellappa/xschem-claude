# 1327 — `conf_tiers` does not follow a symlinked settings file, so Save can still name the wrong tier

✅ **FIXED 2026-09-04 by the DRIVER**, immediately after item B5-a landed and
before item B5-3 was dispatched — B5-a's own ledger row named this as a
precondition on B5-3, and it was right.

**The repair: device + inode, not a normalised string.** `_fid` is the one
identity builder; `conf_tiers` and `load` both use it. Device+inode is what the
filesystem itself uses, so it sees through symlinks, hardlinks and bind mounts
alike, where any amount of string normalisation sees through none of them.

```
STRINGS_EQUAL = 0             <- two different path strings
TIERS_OF_PROJ = user project  <- one file, and BOTH tiers named
TIERS_OF_USER = user project
```

⚠ **IT FALLS BACK TO THE NORMALISED STRING, DELIBERATELY.** A path that does not
exist yet has no inode, and the **first Save of a first run** is exactly that
case — a stat-only answer would make the most common path the broken one in
order to close a rare one. Row **SL3** holds that half.

Rows **SL0-SL3** of `tests/headless/test_op_param_store_1245.tcl` (110 → 114).
Two-sided sabotage, each reding exactly one row: string identity only → **SL2**;
inode with no fallback → **SL3**. **SL0** asserts the symlink fixture was really
created, so the rows above it cannot be silently skipped on a filesystem that
refuses symlinks.

Verified unmoved: `test_op_annot` 485, `test_rdw_seam_1245` 49,
`test_rdw_window_1245` 83, `test_rdw_keys_1245` 36 (`:99`),
`test_annot_declutter_1244` 134 (`:99`). T1 solo **zero**.

---

*Original filing follows.*

**Status: ~~FILED, NOT FIXED.~~** Found by item **B5-a**'s adversary (Verify-C) and
**reproduced independently by the write-up agent** before it was recorded.
Measured 2026-09-04 on `fluid-editing`, on the tree as item B5-a leaves it, with
`B5-2_working_tree_REFUTED.patch` applied on a scratch copy.

**Component:** `src/op_param_lists.tcl` — `conf_tiers` (new in B5-a),
`_resolve_target`, `write_conf` · `src/rdw.tcl` — `rdw::_do_save`,
`rdw::_tier_note` (both in the preserved patch).

**Related:** issue **1325** (*Save writes the user-global file while reporting a
project write*) — **this is the residual of 1325 and it reproduces 1325's own
title**; issue **1276** (`write_conf` reports success while writing somewhere
else — the issue `_resolve_target` was written for); issue **1273** (which
directory *is* the project — a live rule debt, the user's); ruling **DD-7** (*a
write touches one tier's own file*).

**⚠ It is a precondition on item B5-3**, which is the item that actually puts
Save in front of a user. Nothing in the tree emits the wrong sentence today,
because `rdw::_do_save` and `rdw::_tier_note` exist only inside the preserved
patch — so this is filed rather than hot-fixed. See *Why B5-a did not fix it*.

---

## What was measured

Item B5-a closed 1325's headline case: with the cwd at `$HOME`, `conf_path user`
and `conf_path project` are one path, and `conf_tiers` now says so. The
adversary attacked the same claim from the one direction no row covers — a
**project settings file that is a symlink to the user-global one**, which is
exactly the shape `write_conf`'s `_resolve_target` was deliberately written to
follow (issue 1276).

Independent reproduction by the write-up agent (`--nogui --pipe`, both
`::USER_CONF_DIR` and the cwd redirected into scratch, nothing written in the
repo and nothing written in `$HOME`):

```
USER_PATH   =</…/f/home/.xschem/op_param_lists.conf>
PROJ_PATH   =</…/f/proj/.xschem/op_param_lists.conf>      <- a symlink to USER_PATH
CONF_TIERS_OF_PROJ=<project>                              <- names ONE tier
USER_GLOBAL_FILE_CHANGED=<1>  (size 1627 -> 1689)         <- the bytes went there
PROJ_PATH_IS_STILL_A_LINK=<1>
GREP_zzz_IN_USER_GLOBAL=<1>                               <- the new row is in it
```

On the patched tree the adversary drove the same fixture through the real
button, and got 1325's title back verbatim:

```
Save: wrote the operating-point parameter lists to …/proj/.xschem/op_param_lists.conf
   -> the bytes landed in …/home/.xschem/op_param_lists.conf
   -> conf_tiers answered `project`, so the collision note never fired
```

## The mechanism

`file normalize` **does not resolve a path's final component**. That fact is
already recorded in this very file, twenty lines above `_resolve_target`, where
issue 1276's fix uses `file link` in a loop precisely because normalizing is not
enough.

* `write_conf` resolves the chain — `set target [_resolve_target $path]` — and
  writes to the **real** file. That is correct and must stay: a user who
  symlinks a project settings file at a shared one is doing something ordinary,
  and refusing would be the regression.
* `conf_tiers` compares `file normalize` of its argument against `file normalize`
  of each tier's `conf_path`. For a symlinked **final** component both sides
  stay unresolved, the two paths differ as strings, and the collision is
  invisible.
* `write_conf` therefore **computes the answer and throws it away**, and the
  caller reports the path it *asked for*.

### The bound — this is narrower than "conf_tiers is wrong about symlinks"

Measured, so nobody widens it or dismisses it:

| shape | `conf_tiers` | correct? |
|---|---|---|
| cwd collision (`$HOME`, no links) | `user project` | ✅ — 1325's headline case, fenced by `CT1` |
| `.xschem` itself a symlinked **directory** (an intermediate component) | `user project` | ✅ — `file normalize` resolves intermediate links |
| the `.conf` file itself a **symlink** (final component) | `project` | ❌ — **this issue** |
| genuinely distinct directories | one tier each | ✅ — fenced by `CT1`/`CT2` |

## Why no row catches it

`CT1`, `CT2`, `CT3` and the patch's `BE9` all build **plain directories**. Not
one fixture anywhere in the three suites creates a symlinked settings file, so
every row is green and the hole is untouched — the same "a green count is a
statement about the fence" failure this batch has now hit nine times. Store row
`BE5`'s sibling fixtures are plain directories too.

## Recommended fix

Two edits, and the store already computes half of it:

1. **Publish the resolution.** `_resolve_target` is private and `write_conf`
   discards its answer. Either have `write_conf` return the target it actually
   wrote, or publish a `resolved_conf_path {path}` verb beside `conf_tiers` —
   the `governs` / `conf_tiers` precedent of lifting a private scan into a
   published verb with a second reader.
2. **Make `conf_tiers` resolve both sides** through that same verb before
   comparing, so one rule keeps one definition (invariant **I1**) and the tier
   answer stops depending on how the path was spelled.

Then `rdw::_do_save` names the file the bytes landed in, and `rdw::_tier_note`
fires on the resolved path.

**Required fence, and it must be driven BOTH directions:** a store row whose
fixture is a symlinked `op_param_lists.conf` — with the link, the note fires and
the sentence names the **real** file; without it, the sentence is byte-identical
to today's. A row that only asserts the link case would pass with `conf_tiers`
replaced by *"always both tiers"*.

**Rejected:** refusing to write through a symlink, or making `write_conf` treat
a link as an error. Issue 1276 deliberately follows the chain, and a shared
settings file reached by a link is a legitimate setup — the defect is the
**report**, not the write.

## Why item B5-a did not fix it

Recorded so the next crew does not read this as an oversight:

* **Nothing user-visible ships wrong from B5-a's commit.** `rdw::_do_save` and
  `rdw::_tier_note` — the only callers of `conf_tiers` — live inside
  `B5-2_working_tree_REFUTED.patch`. `write_conf` itself is correct: it writes
  the real target. The wrong *sentence* cannot be seen until item B5-3 lands.
* **The fix needs its own fence and its own sabotage pass.** It was found by the
  adversary, i.e. after the sabotage matrix was run. Landing an unfenced store
  change in the write-up commit is precisely the failure mode this batch keeps
  paying for; the honest move is to file it and make it binding on the item that
  ships the caller.

## Still open

All of it. **Issue 1325 is downgraded from FIXED to PARTIALLY FIXED** on the
strength of this measurement: its headline case is closed and fenced, its title
still reproduces in the symlink shape.

**Item B5-3 must close this before it ships Save**, or record in writing why the
symlink shape is acceptable. It must not quote 1325 as closed.
