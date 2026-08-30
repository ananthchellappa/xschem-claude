# 0939 — editing a simulator from a startup file takes it over for good, and says nothing

**Status: OPEN.** Measured on the `Setup > Simulators…` dialog that issue 0937
shipped.

## What the user does

Their `xschemrc` declares a simulator — say `rcsim`. They open
`Setup > Simulators…`, click its row, press `Edit…`, change only the Program
field, press OK.

## What happens

The entry stops being the startup file's and becomes theirs, permanently, and
nothing tells them:

```
P6 before: origin='rc'      … rcsim in saved list = 0
P6 after : origin='session' … rcsim in saved list = 1
```

The saved list now contains `ase::sim_register rcsim …` plus
`ase::sim_select rcsim`. The dialog says only *"The simulator named rcsim is the
one that will be used…"*.

**After that one gesture, editing the xschemrc no longer changes anything for
that simulator**, because the user's saved list is read afterwards and wins.
Recovery means hand-editing a file the user was never told now mentions the
entry.

## The writer's own comment says this must not happen

```
ENTRIES A STARTUP CONFIGURATION FILE DECLARES ARE DELIBERATELY NOT WRITTEN …
it would shadow a later edit to the rc, which is the one place the user would
think to make the change.
```

`ase::sim_write_conf` honours that for entries it merely *reads*. An Edit
launders the entry's `origin` from `rc` to `session` first, so by the time the
writer looks, the rule no longer applies to it.

**The code base already knows this distinction matters**: Remove has a dedicated
sentence for rc entries (*"it will be back the next time xschem starts"*). Edit
just ignores it.

## Why no row caught it

S9 is the Edit-path row and it uses **session-origin** entries only. No row in
either suite registers an rc-origin entry and edits it.

## What is still open

A decision, not just code. Either **refuse** to edit an rc-declared entry and
point the user at the file that declares it, or **allow** it and say plainly
that the entry has been taken over and the startup file no longer governs it.
The second is friendlier and needs a new minted sentence under **D5-4**; the
first is more honest about where the setting lives. Either way the silence is
the defect.
