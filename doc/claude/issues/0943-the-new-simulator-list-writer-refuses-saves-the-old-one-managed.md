# 0943 — the new simulator list writer refuses saves the old one managed

**Status: OPEN.** The other half of the writer rewrite made during issue 0937
(see also **0942**). Reproduced first-hand.

**Worth stating plainly, because it shapes how the change should be read: the
rewrite was made to bring a test row within reach, not to fix a reported
defect.** The implement agent is candid about this — row S11 needed a save that
fails, and with the old truncate-in-place writer an already-existing
owner-writable file could not be made to fail by a read-only directory.

## What the user does

Has a conf directory they cannot write to holding a conf file they **can** write
to. This is the ordinary shape of an administered or read-only-skeleton home.

## What happens

The save is refused, where the previous writer succeeded:

```
F6 conf FILE writable by me? 1   conf DIR writable? 0
F6 NEW writer rv = 0
F6 NEW writer said: Your simulator list could not be saved to /tmp/wu0937/conf6/ase_simulators, so the simulators you added will be gone when xschem closes. Check that the folder exists and that you can write to it. The system said: couldn't open "/tmp/wu0937/conf6/ase_simulators.new": permission denied
F6 OLD writer (open $path w) rc = 0  -- it SUCCEEDED in this identical state
```

Writing beside the target and renaming needs **directory** write permission;
truncating in place needs only **file** write permission. The rewrite therefore
narrows who can save.

## Two further faults ride on the same path

1. **The sentence leaks an internal file the user has never seen and cannot act
   on** — `ase_simulators.new`. Under the user's standing **PLAIN ENGLISH**
   ruling a message must say what happened and what the user can do; a temporary
   file name that exists only inside the writer is neither. With no
   `::USER_CONF_DIR` set at all the sentence degenerates further, to *"could not
   be saved to , so …"* with an empty file name and an `error renaming ".new" to
   ""`.
2. **The dialog then says two opposite things at once.** The status line reads
   *"could not be saved … will be gone when xschem closes"* while the label
   directly under it still reads *"Your list is saved in … and comes back the
   next time xschem starts."* That label is built once when the dialog opens and
   is never refreshed, so it also shows a stale location.

## What the rewrite did buy, and what it did not

It is not all cost. The old writer's `open $path w` truncated the user's saved
list before a single line was written, so an interrupted or failing save
destroyed the list — a real defect, and one the dialog makes far more likely by
calling the writer on every gesture. **The durability promise now has a row**
(R11, added in the repair pass) and so does the permission restore (R12).

What has no row, and what this issue is about, is the **narrowing**: nothing
asserts that a save which the old writer could manage still succeeds.

## What is still open

Fall back to truncate-in-place when the directory is not writable but the file
is — keeping the atomic path as the preferred route — or accept the narrowing
deliberately and say so. Either way the `.new` leak into user-facing wording
must go, and the "where it is saved" label must be refreshed when a save fails.
