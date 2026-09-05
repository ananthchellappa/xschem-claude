# 1325 — Save writes the USER-GLOBAL settings file while reporting a project write

**Status:** FILED, NOT FIXED. Measured 2026-09-04 on `fluid-editing` at
`c940a5df`; the `conf_path` collision reproduces with **no item-B5-2 code**, and
the caller that hardcodes the tier was reverted with B5-2.
**Component:** `src/rdw.tcl` — `rdw::_do_save` (in the preserved patch,
`B5-2_working_tree_REFUTED.patch`) · `src/op_param_lists.tcl` — `conf_path`,
`load`.
**Related:** ruling **DD-7** (*Save is a read-modify-write of **one tier's own
file***), issue **1281** (the project file exports the author's user-global map),
issue **1276**, store-suite row **BE5**.

## The mechanism

`rdw::_do_save` picks its tier with a literal:

```tcl
catch {set path [::op_param_lists::conf_path project]}
```

The **project** tier resolves relative to the current working directory. xschem
is ordinarily launched from the user's home directory, and there the project
tier and the user tier are **the same file**.

## The measurement

With cwd `$HOME`, which is how the binary is normally started:

```
USER   =/home/analog/.xschem/op_param_lists.conf
PROJECT=/home/analog/.xschem/op_param_lists.conf
SAME=1
```

`op_param_lists::load` **already dedupes this case** — it knew the two tiers can
collide and refuses to read the same file twice. `_do_save` does not.

## The consequence

Pressing Save in a window about one design rewrites the settings that apply to
**every** design the user opens, while the status line reports a project write.
Two rulings and one suite row go vacuous in the common case:

* **DD-7's *"one tier's own file"*** — there is only one file.
* **DD-7's preserve-every-other-row promise** still holds mechanically (it is a
  read-modify-write of *that* file), but the user's mental model of which file
  they touched is wrong, which is the half DD-7 exists to protect.
* **Store row BE5** asserts *"the OTHER tier's file is not touched at all"*. It
  passes by writing and checking two paths that, in this configuration, are one
  path — so it can pass while proving nothing.

## Recommended fix

`_do_save` resolves both tiers and, when they are equal, **says so in the
sentence it already prints**: name the actual path and state that this tree has
no separate project file. The write itself is then correct and the report is
true. `load`'s existing dedupe is the precedent for detecting it.

The larger question — whether Save should default to project at all, or ask, or
follow the tier the governing row came from — is the **user's**, not a crew's,
and it is adjacent to issue 1281's unresolved provenance problem. Do not settle
it inside a fix for this.

Rejected alternative: **make `conf_path project` return empty when it collides
with the user tier.** That changes a shipped accessor used by `load` and
`write_conf` for the benefit of one caller.

## Still open

All of it, plus the suite consequence: **row BE5 must construct a project
directory that is genuinely not the home directory** before it can fence what its
title claims.
