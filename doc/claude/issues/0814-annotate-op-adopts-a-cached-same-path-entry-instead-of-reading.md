# 0814 — `annotate_op` adopts a cached same-path entry instead of reading, and reports success

> ⚠ **ATTEMPT 2 (2026-08-26) CLOSED THIS *BY CONSTRUCTION* AND WAS REVERTED BECAUSE OF IT.**
> Stashing the whole registry across the read means the rawfile+sim_type dedup has nothing
> to match, so all three fallback legs perform a **real** read and a cached `<path> tran`
> entry can no longer be published as this run's operating point. That worked (rows
> AA19/AA20). But a real read of the path ngspice is *currently writing* reads a
> well-formed `No. Points: 0` header, succeeds with zero points, and SIGSEGVs in
> `update_op()` — [0836](0836-update-op-segfaults-on-a-zero-point-database.md). At HEAD the
> dedup never opens that file, so HEAD cannot crash there. **Fixing 0814 therefore requires
> 0836 fixed in the same commit.** See 0807 §13 and constraint §11.7.
>
> ⚠ **AND THE FIXTURE MATTERS.** Attempt 2's row AA19 overwrote the path with 40 bytes of
> garbage. Garbage fails every leg and returns `0`, so that row passes on a tree that
> crashes. Any acceptance row for 0814 must use a **well-formed zero-point header**.


STATUS: **OPEN — measured 2026-08-25, filed not fixed.**
FOUND IN: `src/save.c`, `extra_rawfile()`'s spice rawfile+sim_type dedup loop
("file not already loaded: read it and switch to it" — the `else` arm takes the
cached entry with **no read**), reached from `src/scheduler.c`, the `annotate_op`
branch's op → dc → **tran** fallback.
RELATED: [0807](0807-annotate-op-destroys-the-attached-op-database-on-a-truncated-raw.md)
§12 (this is the acceptance hole that item could not close),
[0685](0685-annotate-op-reuses-a-stale-registry-database-at-the-same-path.md)
(the same stale-registry family, different entry point).

---

## 1. The defect

`annotate_op` falls back op → dc → tran. Each attempt goes through
`extra_rawfile(1, file, type, ...)`, whose dedup loop matches on
**rawfile + sim_type** and, on a hit, takes *"already loaded: switch to it"*
**without opening the file**.

So when the registry already holds a `<path> tran` entry and `annotate_op` is
called on that **same `<path>`**, a file that is truncated, corrupt or entirely
unreadable still ends in the tran fallback **matching the cached entry**. The
command switches to a stale database, publishes **point 0 of a transient as the
operating point**, and reports success. Nothing reads the file.

This is not a corner arrangement. It is the shipped one: `src/ase.tcl` and
`src/wave_viewer.tcl` load waveforms with `xschem raw read`, which **appends** to
the registry, and ngspice overwrites one stable path (`<rundir>/<cell>_ase.raw`)
on every run — so `<path> tran` cached plus `annotate_op <path>` is the ordinary
ASE flow, not an unlucky one.

## 2. The measurement

Write-up agent, 2026-08-25, `--nogui`. A 2-point transient raw at `Q.raw` with
`v(a) = 7.77` at point 0 is read; `Q.raw` is then **overwritten with 40 bytes of a
truncated header**, as ngspice does mid-rewrite; `annotate_op` is called on it:

```
WU2| read tran Q  rc=1
WU2| annotate TRUNCATED same-path -> result=<1>  sim_type=tran  v(a)=7.77
WU2| registry: 0 current | 0 /…/Q.raw tran
```

`v(a) = 7.77` is **the previous run's transient point 0, served as this run's
operating point**, from a file that is now 40 bytes of garbage. The read never
happened.

⚠ **Attribution, stated precisely.** This transcript was taken on the *attempt 1*
binary (0807), so the `result=<1>` string is attempt 1's return value; at HEAD the
same call returns `TCL_OK` with tcleval residue instead. **The substantive defect —
success reported, no read performed, a cached stale value published as the operating
point — is unchanged at HEAD**, because the dedup loop this rests on was **not
touched** by attempt 1 (verified against the reverted diff: the only `rawfile`
`strcmp` it added is inside the new `extra_rawfile_detach()`, not in this loop).
The adversary agent measured the same thing independently and likewise recorded
"same on HEAD, so not a regression". **A confirming HEAD run is owed once the tree
is rebuilt.**

## 3. Why it matters

Invariant **I3** and `save.c` RULING **D5-1** both say a plausible wrong number on a
schematic is worse than none. This produces exactly that, and it defeats a
swap-only-on-success fix from the far side: the swap is *correct* to swap, because
the read genuinely reported success — it simply never read anything.

It also means 0807's acceptance ("with a tran db **and** an op db attached, a failed
annotate must destroy neither") **is not met when the two share a path**, and no test
row that uses two *different* paths can see it. 0807's own rows Z5/Z6/Z7 use two
paths and are blind to this.

## 4. The shape of a fix (not implemented)

`annotate_op` should not be able to satisfy itself from the registry for the file it
was explicitly asked to (re)read. Either drop the `<path> op` / `<path> dc` /
`<path> tran` entries for that path before the attempt, or force a re-read for this
caller. Note the interaction with 0807's retry: whatever mechanism does the dropping
must **not free** what it drops until the new read succeeds, or it re-creates 0807.

Rejected as insufficient: stat-ing the file for a changed mtime/size. ngspice can
rewrite a raw to the same size within one clock tick, and it is exactly the
mid-rewrite window that this issue is about.

## 5. Still open

All of it, plus the owed HEAD-rebuild confirmation in §2.
