# 0497 — three silent or misreported under-emission channels in the S3 walk

STATUS: **OPEN.** Measured on branch `annotate`, step S3d, 2026-08-21, at
`d56283ec`. Found by the adversary pass; see 0494.
Related: 0494, 0496 (the warning that is false), 0488 (`_prefix_ok`),
0424 (a raising PDK procs file is a live possibility).

---

Decision **D10** made `* NOTE:` comment lines in the generated `.save` file the
**only** channel for telling a user that the walk emitted less than they expect.
Three paths reach the user with no note at all, or with a false one.

## (a) The channel is unreachable on the path that produces the most important warning

A design whose only device sits under a `spiceprefix`'d subcircuit trips
`_prefix_ok` (issue 0488), which suppresses that subtree — correctly, because
every card below it would be bogus and a fully-bogus block writes **no raw**.
The warning is generated. But the block is then **empty**, and
`write_save_file` returns `{}` *before writing anything*, so the `* NOTE:`
lines have no file to live in.

What the user sees instead is the menu's fallback alert:

> no device below this cell has an op_annot descriptor, or none of them is in
> the netlist

which is the opposite of what happened: the devices *are* there, they *do* have
descriptors, and the walk deliberately refused them.

Row **W26** enshrines the behaviour ("writes NO file when there is nothing to
save"), so the guardian agrees with the defect.

**Fix direction:** write the file whenever `last_warnings` is non-empty even if
the block is empty, or surface `last_warnings` in the alert. The second is
cheaper and does not create a `.save` file with no cards in it.

## (b) A raising devproc produces zero cards and zero warnings

`op_annot::devpath` catches a devproc raise and returns `{}`. `_miss_dev` only
increments when the devpath is **non-empty**. So a PDK whose `devproc` raises —
issue 0424 makes that reachable in an installed tree — yields `rc=0`, an empty
block, and an empty warning list. The feature reports success having done
nothing, for a reason that is entirely diagnosable.

**Fix direction:** count a raising devproc separately from a
descriptor-less instance, and say which PDK proc raised.

## (c) An unreadable or broken subcell is reported as "normal"

A child `.sch` that cannot be opened is folded into the same aggregate as a
behavioural cell:

> ... (spice_stop, spice_sym_def, an ignored or behavioural cell, or an empty
> block) - **normal for such cells**

The netlister prints `Can not open file ...` to stdout, which no user of a menu
item will ever see. The same sentence is what misreports issue 0496's parameter
specialisations.

**Fix direction:** the aggregate is doing too much work. Split it: *dropped by a
netlister rule* (genuinely normal), *not found in the deck* (a defect in the
walk — 0496), *could not be read* (a defect in the design or the library path).

## Still open

* All three are under-emission, i.e. blank rows, which invariant I3 prefers to
  wrong numbers. None of them can destroy a raw. They are filed because *silent*
  under-emission is precisely what let three previous attempts certify green
  while broken, not because a card is wrong.
* No row in the reverted acceptance covers any of the three.
