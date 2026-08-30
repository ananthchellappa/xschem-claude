# 0942 — saving your simulator list replaces a symlink with a plain file

**Status: OPEN.** A consequence of the writer rewrite that issue 0937 made (see
also **0943**, the other half of the same rewrite). Reproduced first-hand.

## What the user does

Points `~/.xschem/ase_simulators` at a shared or version-controlled list with a
symlink — the ordinary way to share one configuration across machines or
checkouts — then saves anything at all from `Setup > Simulators…` (an Add, an
Edit, a Remove, or just picking a different simulator).

## What happens

The link is replaced by a plain file. The shared file is silently orphaned and
stops receiving the user's list:

```
F5 before: conf entry is a symlink? 1
F5 sim_write_conf rv = 1
F5 after : conf entry type = file
F5 the SHARED file the user pointed at still says: # shared list
```

The save **reports success**. Nothing tells the user their link is gone, and the
next time they look at the shared file it is stale — with no indication of when
it stopped tracking.

## Why it happens

`ase::sim_write_conf` was rewritten during 0937 to write beside the target and
`file rename` the new file into place. `file rename` replaces the *link itself*,
not what it points at. The previous writer opened the path and wrote **through**
the link, which is the behaviour a user who made a symlink is asking for.

## What is still open

Resolve the link before writing — `file link`/`file normalize` the target and
write to the resolved path — so an atomic replace still happens, but on the real
file rather than on the user's link. Note this interacts with **0943**: the
temporary file must be created beside the *resolved* target, or a symlink
pointing across a filesystem makes the rename fail.
