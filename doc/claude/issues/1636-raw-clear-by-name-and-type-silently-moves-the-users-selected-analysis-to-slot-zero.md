# 1636 — `xschem raw clear <name> <type>` silently moves the user's selected analysis to slot 0

**STAMP:** `v1 claim=open tree=a90ffb98 stamped=2026-10-02 fix=none open=3 scope=caller`

Status: **OPEN as a documented hazard**, found 2026-10-02 by the calculator batch's recon stages
while establishing what a Calculator scratch-column cleanup is allowed to touch. Pre-existing; no
Calculator change caused it.

⚠ **This is filed as a hazard with a caller-side remedy, NOT as a defect to fix in the clear arm.**
`ase::attach_dbs` in `src/ase.tcl` depends on the reset — see *Why the obvious fix is wrong*,
below. `scope=caller` says where the claim does **not** reach: the clear arm itself is not being
claimed broken.

Area: the three `what == 3` (clear) arms of `extra_rawfile()` — `src/save.c` — reached from the
`clear` arm of the `raw` dispatcher in `xschem_cmds_r()`, `src/scheduler.c`. Read back through
`results::current` (`src/results.tcl`).
Found: `env -u DISPLAY ./src/xschem --pipe -q --nogui --script …`, three synthetic databases

## The defect

Both targeted clear arms — by index and by name+type — reset the registry cursor unconditionally
when they removed anything:

```c
if(found != 0) {
  xctx->extra_raw_n -= found;
  xctx->extra_idx = 0;
  xctx->extra_prev_idx = 0;
  if(xctx->extra_raw_n) {
    xctx->raw = xctx->extra_raw_arr[0];
  } else { … }
}
```

`extra_idx` is *which database the user selected*. `extra_prev_idx` is *where `xschem raw
switch_back` goes*. Clearing an **unrelated** database therefore moves the selection to slot 0 and
destroys the back-reference, with no message.

## Measured

Three databases; the user is on the **op** one, index 1; an unrelated **dc** database is cleared by
name and type:

```
info: 2 current | 0 t0.raw tran | 1 op1.raw op | 2 other.raw dc
--- select the op slot ---
info: 1 current | 0 t0.raw tran | 1 op1.raw op | 2 other.raw dc
results::current -> idx 1 path op1.raw type op cur 1 label {op1.raw (op)}
--- clear an UNRELATED database by name+type ---
xschem raw clear other.raw dc   ->  rc=1
info: 0 current | 0 t0.raw tran | 1 op1.raw op
results::current -> idx 0 path t0.raw type tran cur 1 label {t0.raw (tran)}
```

The op slot **still exists** at index 1 and is still named in `raw info`; the selection simply is
not on it any more. `results::current` — the accessor the result-selection surface answers
through — now reports a different path **and a different analysis type**. Nothing printed, nothing
returned a distinguishable code (`rc=1` is the same as a clear that removed the current database),
and the compaction is not the cause: index 1 did not move.

**The analysis type changing is the sharp edge.** A surface that was showing operating-point
annotations is now pointed at a transient; `op` and `tran` are read by different code paths
(`update_op()` is called only when switching *into* a one-point `op`/`dc`), so the user's next
action runs against a database they did not choose.

## Why the obvious fix is wrong

Deleting the two assignments, or making them conditional on the removed index being the current
one, **breaks `ase::attach_dbs`**, which relies on the reset by construction. Its own comment says
so:

> drop everything that is not the DB just read, HIGHEST INDEX FIRST: `raw clear <n>` compacts the
> array, so removing a larger index never disturbs a smaller one.

The loop is `foreach i [lsort -integer -decreasing [ase::raw_indices]] { if {$i == $cur} continue;
catch {xschem raw clear $i} }`. Every iteration resets `extra_idx` to 0; the loop is correct only
because when it finishes exactly one database remains and slot 0 is it. A conditional reset would
leave `extra_idx` pointing into the compacted-away tail on the iterations that remove a *lower*
index than the current one. `ase::attach_dbs` also issues a targeted
`catch {xschem raw clear $rawfile $sim_type}` **before** its read, for the reason its comment
gives — `xschem raw read` does not re-read a path already in the registry — and that call hits the
name+type arm measured above.

So the clear arm's cursor reset is load-bearing, and the remedy belongs with whoever cares about
the selection:

> **Restore by name and type, not by index, around any clear the user did not ask for** — read
> `results::current` before, and `xschem raw switch <name> <type>` after — **and fence it**. An
> index is not a stable identity across a clear, because the array compacts.

## Two more things measured on the same arms, both filed here because they are the same verb

* **`xschem raw clear` with NO argument clears the user's result.** It takes the clear-**all** arm
  (`!file`), frees every database, unsets `ngspice::ngspice_data`, and answers `rc=1`. Measured:
  three loaded, `xschem raw clear` → `raw info` answers the empty string. There is no "clear the
  current one" spelling; the argument-free spelling is the destructive one.
* **`xschem raw switch <name>` with no type IGNORES THE NAME and advances to the next database,
  answering 1.** The switch arm tests `file && type` first and `isonlydigit(file)` second; a bare
  name matches neither, so it falls into the `/* switch to next */` arm, which does
  `extra_idx = (extra_idx + 1) % extra_raw_n`. Measured on three databases from index 1:

  ```
  xschem raw switch op1.raw        -> rc=1, now 2 current
  xschem raw switch op1.raw        -> rc=1, now 0 current
  xschem raw switch nosuchfile.raw -> rc=1, now 1 current
  xschem raw switch op1.raw tran   -> rc=0, now 1 current   (name exists, wrong type: correctly refused)
  ```

  A **nonexistent** filename answers success and moves the selection. Only the two-argument form
  can fail, so `switch <name>` is not a weaker version of `switch <name> <type>` — it is a
  different verb wearing the same words.

## Open items

1. **The caller-side restore, plus the fence.** This is the item with the value in it, and it is
   the only one that does not change shipped C behaviour. A row that drives the measurement above —
   select a non-zero slot, clear an unrelated database, assert `results::current` is unchanged —
   would have caught this and would catch the next caller that forgets.
2. **`raw switch <name>` should refuse rather than advance.** A name that matches nothing cannot
   be a request to go to the next database. This one *is* a C change and it is small, but it is
   user-visible (a spelling that silently worked now returns 0), so it wants saying out loud.
3. **The clear arm should say something.** Whatever is decided about who restores, a clear that
   moved the selection off the database the user chose is worth one line through the same channel
   `results::_emit` uses — the surface already has a vocabulary for this.

## What this is NOT

Not an argument for changing `extra_idx = 0` in `extra_rawfile()`. See above; `ase::attach_dbs`
reads it as a contract.

Not a duplicate of issue 1634, which destroys the whole registry from the top-level `table_read`
verb. This one leaves every database loaded and moves only the cursor.
