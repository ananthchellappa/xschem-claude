# 0676 — `share_farm_child` reads only action-log slot 0, so every log-reading row can flake

Status: **OPEN** (measured once, not reproduced on demand — a TEST-HARNESS
fragility, not a product defect)
Filed by: the 0664+0665+0666 crew, 2026-08-24, from the Verify-A tier leg.

## What was seen

On the **first** of 20 `test_ase_core` runs in one session:

```
RESULT: 9 FAILED (163 passed)
   NTD1  NTD2  NTD3  NTD4  NTD6  NTD8  NTD9  NTD11  NTD12
```

Check **total was still 172**, so it is the same suite, not a different one.

**The failing set is diagnostic**: every failing row reads a spawned child's
`Xschem.log`; every row that reads the child's **stdout** passed (`NTD5`,
`NTD7`, `NTD10` green, and `NTD9`/`NTD12`'s own notes printed
`the DEGRADED line = {}`). All children exited status **0** and emitted their
full `NTD-MARK` stream. So the children **ran to completion and simply left no
readable `Xschem.log`** in their freshly-created `--logdir`.

`NTD1` is in the failing set, and it is a **pre-existing 0658 control row** whose
own comment reads *"GREEN BEFORE THE CHANGE… it proves the farm, the child and
the log reader all work"*. It was green in the 159-check baseline.

## Why it is not the 0664+0665+0666 change

The failure mode lives entirely in code that change did not touch:

* `git status --short -- tests/headless/sharefarm.tcl tests/headless/scratch.tcl
  src/util.c src/options.c` → **0 lines**;
* the action-log opener is **C** (`src/util.c:337-397`, `init_action_log`) in a
  binary whose mtime (Aug 24 12:33) **predates** all four `.tcl` edits
  (14:31-14:33);
* a pure-Tcl notify change cannot stop a child creating its log file.

## Suspected mechanism (UNPROVEN — this is the part that needs the work)

`init_action_log` picks the **first free slot** in `[0, ACTIONLOG_KEEP)`:

```c
/* src/util.c:280 */
if(n == 0) my_snprintf(out, sz, "%s/Xschem.log", dir);
else       my_snprintf(out, sz, "%s/Xschem.log.%d", dir, n);
```

```c
/* src/util.c:383-387 */
for(i = 0; i < ACTIONLOG_KEEP; ++i) {
  actionlog_name(fname, S(fname), dir, i);
  if(stat(fname, &buf)) { slot = i; break; }   /* free slot */
  ...
}
```

So **if an `Xschem.log` already exists in the logdir, the session silently
writes `Xschem.log.1`** — and the reader never looks there:

```tcl
## tests/headless/sharefarm.tcl:93-94
set lf [file join $dir Xschem.log]
if {[file exists $lf]} { ... }
```

Any path that leaves a stale or concurrently-held `Xschem.log` in a child's
logdir turns these rows red **while the child looks perfectly healthy**.

## Reproduction attempts — all negative

* 19 further `test_ase_core` runs green (a 5-run loop, a 12-run soak, plus 2);
* the exact run-1 sequence (`test_startup_guard_0663` then `test_ase_core` in one
  shell) green;
* a purpose-built hammer spawning the NTD child **60 times** through the real
  `share_farm_child` helper: **0 misses out of 60**. Standalone, the child writes
  `#! NTD-0658 an ASE refusal the user must see` into its `Xschem.log` every time.

## The fix

Per the brief's own rule — *"treat a bug that only an environment can reproduce
as a test defect too: the fix is to force the race deterministically"*:

1. `share_farm_child` should read the **newest `Xschem.log*`** in the dir rather
   than assuming slot 0, and
2. should **fail loudly** when the dir contains no `Xschem.log*` at all, so this
   presents as "the child wrote no log" instead of as nine unrelated content
   assertions;
3. optionally, assert the logdir is empty before the child launches.

## Acceptance

* a child whose logdir already contains an `Xschem.log` still has its real log
  read (a row that pre-creates one and proves the reader follows to `.1`);
* an absent log produces one explicit failure naming that fact, not N content
  failures;
* the NTD block survives a soak with a deliberately pre-seeded `Xschem.log`.
