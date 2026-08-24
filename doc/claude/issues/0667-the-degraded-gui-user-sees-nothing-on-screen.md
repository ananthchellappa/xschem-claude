# 0667 — the degraded GUI user sees nothing on screen

Status: OPEN (measured, NOT fixed — a deliberate scope limit of issue 0658 that
deserves a second look)
Filed by: the 0658 crew, 2026-08-24, from the adversary leg.

## Measured

On `:99` with openbox live, a child whose `src/ciw.tcl` fails to source
(`--pipe -q --logdir`, share farm):

```
EXIT=0    .ciw absent    ciw_echo absent    ase::echo rc=0 res=1
[xschem get top_path].statusbar.12  EXISTS and is WRITABLE
  (a sentinel written with `configure -text` survived)
the bootstrap wrote NOTHING to it
```

The notice lives only in `Xschem.log` and on stderr.

## Why it matters

`ihp-sg13g2/sg13g2_procs.tcl:811` is this repo's standing example of a
`puts stderr` no GUI user ever sees, and issue 0658 cites it by name as the
reason its rejected alternative #2 stayed rejected. In the degraded state the
user is in exactly that position — except that **one visible sink was available
and went unused**.

## Why it shipped that way

0658's brief was explicit: the bootstrap must be visibly smaller than the
channel — *NO short form, NO 28-char clipping, NO statusbar, NO popup, NO latch,
NO remedy rendering* — because copying `notify_statusbar` out of `ciw.tcl` is
the I1 breach the whole item was written to avoid. That reasoning is sound for
*copying* the sink. It does not settle whether the bootstrap should write the
field **directly**, which is roughly three lines and shares no builder with
`ciw.tcl`:

```tcl
catch {[xschem get top_path].statusbar.12 configure -text $msg}
```

## The tension to resolve before implementing

* **For**: it is the only visible sink that exists when `ciw.tcl` is dead, and
  "the user reached nothing" is the silence this feature exists to end.
* **Against**: the field is 28 characters and shared with `*BUSY*`
  (`hilight.c:2201`), is cleared unconditionally by `propagate_logic()`
  (`hilight.c:2305`), is last-writer-wins and carries no remedy — issues **0654**
  and **0660**, both open. Writing an unclipped message there is issue 0656's
  defect wearing a different hat, and clipping it needs a short-form builder,
  which is the copy that was rejected.
* A third option: leave the field alone and put the announcement in the **window
  title** or a one-shot `tk_messageBox` at startup, which is a genuinely
  degraded-mode-only affordance with no shared builder at all.

This is a user-visible choice with no prior ratification, so it wants a ruling
rather than a unilateral implementation.

## Still open

All of it. Answer it together with **0654**, **0655** and **0660** — they are all
about which field a notice the user cannot miss should land in.
